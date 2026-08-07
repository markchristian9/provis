import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/painting.dart' show RadialGradient;

import '../core/noise.dart';
import '../core/palette.dart';
import '../core/spline.dart';
import '../iso/iso_view.dart';
import '../core/scheme.dart';
import '../core/shading.dart';
import '../rig/body.dart';
import '../rig/pose.dart';
import 'spec.dart';

/// [HumanoidSpec] 의 랜드마크 높이를 골격 치수로 옮긴다.
///
/// 명세는 "지면에서 무릎까지 몇 픽셀" 같은 절대 높이로 되어 있고, 골격은
/// "허벅지 길이" 같은 마디 길이로 되어 있다. 둘을 잇는 것은 이 함수 하나뿐이라
/// 명세가 바뀌어도 애니메이션과 렌더러는 손대지 않는다.
Body bodyOfSpec(HumanoidSpec s) => Body(
  height: s.height,
  hipHeight: s.hipY,
  torso: s.shoulderY - s.hipY,
  neck: s.neckY - s.shoulderY,
  headLen: s.headHeight,
  headWidth: s.headHeight * 0.74,
  shoulderHalf: s.shoulderWidth * 0.5,
  hipHalf: s.hipWidth * 0.5,
  upperArm: s.upperArm,
  foreArm: s.foreArm,
  hand: s.handLen,
  thigh: s.thigh,
  shin: s.shin,
  foot: s.footLen,
  bulk: 0.78 + s.muscle * 0.62,
  hunch: switch (s.archetype) {
    Archetype.berserker => 0.11,
    Archetype.knight || Archetype.paladin => 0.03,
    Archetype.assassin => 0.07,
    _ => 0.045,
  },
  depth: s.chestWidth / (s.height * 0.196),
);

/// 골격 구동 휴머노이드 렌더러.
///
/// 매 프레임 [Pose] 를 받아 관절을 풀고, 그 관절점에서 실루엣 [Path] 를 만든 뒤
/// [paintSurface] 로 칠한다. 스프라이트가 없으므로 어떤 포즈·어떤 방향에서도
/// 같은 코드가 같은 품질을 낸다 — 애니메이션을 하나 추가하는 데 드는 비용이
/// 그림 작업이 아니라 커브 몇 줄뿐이라는 것이 이 구조의 목적이다.
class HumanoidRenderer {
  HumanoidRenderer(
    this.spec, {
    Body? body,
    Palette? palette,
    this.beast = false,
    this.beastForm = BeastForm.brute,
  }) : body = body ?? bodyOfSpec(spec),
       pal = palette ?? spec.palette,
       _noise = Noise(spec.seed);

  final HumanoidSpec spec;

  /// 골격 치수. 짐승형은 명세를 그대로 두고 이것만 갈아 끼워, 같은 장비
  /// 규칙과 같은 애니메이션 클립이 전혀 다른 실루엣으로 재생되게 한다.
  final Body body;
  final Palette pal;

  /// 짐승형 여부. 뿔·꼬리·발톱처럼 인간형에 없는 파츠를 켠다.
  final bool beast;

  /// 짐승형의 주 실루엣. 색을 지워도 종과 전투 역할이 달라 보여야 한다.
  final BeastForm beastForm;

  final Noise _noise;

  /// 명세는 표준 키(180)를 기준으로 만들어져 있다. 골격을 갈아 끼우면 키가
  /// 달라지므로, 명세에서 온 모든 폭·두께를 이 비율로 되맞춘다. 그러지 않으면
  /// 짐승형에서 몸통만 가늘어진다.
  late final double _k = body.height / spec.height;
  late final double _h = body.height;

  late final double _armR = spec.armThickness * _k * (beast ? 1.30 : 1.0);
  late final double _legR = spec.legThickness * _k * (beast ? 1.24 : 1.0);
  late final double _hipW = spec.hipWidth * _k * (beast ? 1.10 : 1.0);
  late final double _waistW = spec.waistWidth * _k * (beast ? 1.18 : 1.0);
  late final double _chestW = spec.chestWidth * _k * (beast ? 1.30 : 1.0);
  late final double _shoulderW = spec.shoulderWidth * _k * (beast ? 1.22 : 1.0);
  late final double _neckW = spec.neckWidth * _k * (beast ? 1.55 : 1.0);
  late final double _depthOff = spec.depthOffset * _k;

  /// 갑옷 비중에 따라 사지를 덮는 재질이 달라진다. 이 한 값이 실루엣의
  /// 인상(무거운 판금 기사 ↔ 가벼운 암살자)을 결정한다.
  // 짐승형의 살은 몸통과 사지가 같은 재질이어야 한 마리로 읽힌다. chitin 은
  // rim 이 1.3 이라 던전 조명(청록 역광) 아래에서 사지만 형광으로 떠오른다.
  Surface get _beastSurface => switch (beastForm) {
    BeastForm.brute => Surface(pal.skin, Finish.skin),
    BeastForm.drake => Surface(pal.skin, Finish.scale, contrast: 1.12),
    BeastForm.wraith => Surface(
      pal.clothShade.mix(pal.glow, 0.28),
      Finish.slime,
      contrast: 1.08,
      alpha: 0.72,
      glow: 0.12,
      glowColor: pal.glow,
    ),
    BeastForm.arachnid => Surface(
      pal.metal.mix(pal.skin, 0.34),
      Finish.chitin,
      contrast: 1.26,
    ),
  };

  Surface get _beastHeadSurface => switch (beastForm) {
    BeastForm.brute => Surface(pal.skin, Finish.skin),
    BeastForm.drake => Surface(pal.skin, Finish.scale, contrast: 1.14),
    BeastForm.wraith => Surface(
      pal.glow.desaturate(0.58).lighten(0.18),
      Finish.bone,
      contrast: 1.12,
      alpha: 0.88,
      glow: 0.10,
      glowColor: pal.glow,
    ),
    BeastForm.arachnid => _plate,
  };

  Surface get _limbArmor => beast
      ? _beastSurface
      : spec.armorHeaviness > 0.52
      ? Surface(
          pal.metal,
          Finish.metal,
          contrast: 0.85 + 0.5 * (0.5 + 0.42 * spec.armorHeaviness),
        )
      : spec.armorHeaviness > 0.26
      ? Surface(pal.leather, Finish.leather)
      : Surface(pal.cloth, Finish.cloth);

  /// 다리의 **밑단**. 판금이어도 여기는 천이나 가죽이고, 그 위에 쿠이스와
  /// 그리브가 조각으로 얹힌다([_leg] 참고).
  Surface get _legUnder => beast
      ? _beastSurface
      : spec.armorHeaviness > 0.26
      ? Surface(pal.leather, Finish.leather)
      : Surface(pal.cloth, Finish.cloth);

  Surface get _plate => beast
      ? Surface(pal.metal, Finish.chitin, contrast: 1.22)
      : Surface(
          pal.metal,
          Finish.metal,
          contrast: 0.85 + 0.5 * (0.55 + 0.4 * spec.armorHeaviness),
        );

  Surface get _torsoSurface => beast
      ? _beastSurface
      : spec.armorHeaviness > 0.45
      ? _plate
      : spec.armorHeaviness > 0.2
      ? Surface(pal.leather, Finish.leather)
      : Surface(pal.cloth, Finish.cloth);

  /// 짐승형은 판금·망토를 걸치지 않는다. 장비 규칙을 종별로 흩어 두지 않고
  /// 여기 한 곳에서 끈다.
  bool get _wearsArmor => !beast && spec.armorHeaviness > 0.4;

  bool get _wearsCape => spec.hasCape && !beast;

  /// 한 프레임을 그린다. 캔버스 원점은 액터의 접지점이어야 한다.
  void paint(
    Canvas canvas, {
    required Pose pose,
    required LightRig light,
    Facing facing = const Facing(0.85),
    IsoView iso = kIso,
    double time = 0,
    double detail = 1.0,
    bool ranged = false,
  }) {
    // 골격을 방향과 함께 푼다. solve 가 시상면 스윙과 좌우 폭을 yaw 로
    // 섞으므로, 정면에서는 팔다리가 좌우로 벌어지고 스윙이 화면에서 사라진다.
    //
    // 캔버스를 미러할 방향이면 거울 반사한 yaw 를 넘긴다 — 그래야 뒤집은
    // 뒤에도 좌우 성분이 월드 기준으로 맞는다.
    final mirror = facing.nearSide < 0;
    final solveYaw = mirror ? math.pi - facing.yaw : facing.yaw;

    final b = body;
    final p = pose;
    var sk = solve(b, p, yaw: solveYaw);
    final low = _lowestFoot(sk);
    if (low > 0.5) {
      sk = solve(b, p.copyWith(rootY: p.rootY - low / b.height), yaw: solveYaw);
    }
    final airborne = low < 0 ? (-low / (b.height * 0.12)).clamp(0.0, 1.0) : 0.0;

    // ① 접지 그림자는 아이소 평면에 눕는다 — 세로 단축 바깥에서 그려야
    //    2:1 타원이 유지된다.
    paintIsoGroundShadow(
      canvas,
      iso,
      Offset(sk.groundContact.dx * 0.6, 0),
      b.shoulderHalf * 3.6,
      light,
      strength: 0.55,
      airborne: airborne,
    );

    // ② 몸은 지면 위에 세워진 카드다. 세로 단축은 여기 한 번만.
    canvas.save();
    canvas.scale(1, iso.squash);

    if (mirror) canvas.scale(-1, 1);
    // 캔버스를 뒤집으면 광원도 따라 뒤집히므로, 리그의 x 성분을 되돌려
    // 조명이 월드에 고정되게 한다.
    final lit = mirror ? light.mirrored : light;

    final dz = _depthOff * facing.depthSpread;
    final front = facing.toCamera;

    // ③ 뒤에서 앞으로. 큰 실루엣은 팔다리보다 먼저 깐다. 영웅은 직업 장비,
    // 몬스터는 날개·망토·여분의 다리가 색보다 먼저 정체를 말한다.
    if (beast) {
      _monsterBackSilhouette(canvas, sk, lit, iso, detail, time);
      if (beastForm == BeastForm.brute || beastForm == BeastForm.drake) {
        _tail(canvas, sk, lit, iso, detail, time);
      }
    } else {
      _heroBackSilhouette(canvas, sk, lit, iso, detail, time);
    }

    canvas.save();
    canvas.translate(-dz, 0);
    _leg(canvas, sk.legFar, lit, iso, detail, depth: 1);
    _arm(canvas, sk.armFar, lit, iso, detail, depth: 1, holdsBow: ranged);
    // 방패는 그것을 든 팔과 같은 깊이에 있다. 무기와 함께 맨 앞에 그리면
    // 가슴 위에 떠 보인다.
    if (spec.hasShield && !beast && !ranged) {
      _shield(canvas, sk, lit, iso, detail);
    }
    canvas.restore();

    if (front) _cape(canvas, sk, lit, iso, detail, time);
    _torso(canvas, sk, lit, iso, detail, facing);
    _head(canvas, sk, lit, iso, detail, facing);
    if (!front) _cape(canvas, sk, lit, iso, detail, time);

    _leg(canvas, sk.legNear, lit, iso, detail, depth: 0);
    _arm(canvas, sk.armNear, lit, iso, detail, depth: 0, holdsBow: false);

    _weapon(canvas, sk, lit, iso, detail, ranged: ranged);
    _fx(canvas, sk, lit, time);

    canvas.restore();
  }

  // ─────────────────────────────────────────────────────────── 포즈 보정

  /// 앞뒤로 흔드는 관절만 [k] 배로 줄인다. 굽힘(팔꿈치·무릎)은 화면 깊이와
  /// 무관하므로 건드리지 않는다 — 줄이면 다리가 펴져 걸음이 무너진다.
  // ignore: unused_element
  Pose _foreshorten(Pose p, double k) => p.copyWith(
    armNear: ArmPose(
      shoulder: p.armNear.shoulder * k + (1 - k) * 0.12,
      elbow: p.armNear.elbow,
      wrist: p.armNear.wrist,
    ),
    armFar: ArmPose(
      shoulder: p.armFar.shoulder * k + (1 - k) * 0.12,
      elbow: p.armFar.elbow,
      wrist: p.armFar.wrist,
    ),
    legNear: LegPose(
      hip: p.legNear.hip * k,
      knee: p.legNear.knee,
      ankle: p.legNear.ankle,
    ),
    legFar: LegPose(
      hip: p.legFar.hip * k,
      knee: p.legFar.knee,
      ankle: p.legFar.ankle,
    ),
  );

  double _lowestFoot(Skeleton sk) => [
    sk.legNear.c.dy,
    sk.legNear.d.dy,
    sk.legFar.c.dy,
    sk.legFar.d.dy,
  ].reduce(math.max);

  // ─────────────────────────────────────────────────────────── 파츠

  void _leg(
    Canvas canvas,
    Limb l,
    LightRig light,
    IsoView iso,
    double q, {
    required double depth,
  }) {
    final r = _legR;
    final occ = 0.18 + 0.32 * depth;

    // 허벅지에서 발목까지 하나의 관으로 뽑는다. 마디를 따로 그리면 무릎에
    // 이음매가 생기지만, 두께 프로파일 하나로 뽑으면 근육이 이어진다.
    final leg = tube(
      [l.a, lerpO(l.a, l.b, 0.45), l.b, lerpO(l.b, l.c, 0.5), l.c],
      [r * 0.98, r * 1.02, r * 0.76, r * 0.60, r * 0.50],
      samples: 24,
    );
    paintSurface(
      canvas,
      leg,
      _legUnder,
      light,
      detail: q,
      occlusion: occ,
      edgeRim: true,
      seed: spec.seed + depth.round(),
    );
    if (beast) _limbBands(canvas, leg, l.a, l.c, r, q, salt: depth.round());

    // 판금 다리는 **덧댄 조각**으로 그린다.
    //
    // 다리 전체를 금속 관 하나로 칠하면 허벅지가 거대한 흰 캡슐이 되어
    // 실루엣의 중심을 잡아먹는다 — 사람이 아니라 로봇 다리로 읽혔다. 실제
    // 판금도 쿠이스(허벅지)와 그리브(정강이)로 나뉘고 그 사이 관절에는 천이
    // 드러난다. 그 틈이 있어야 다리가 접히는 물건으로 보인다.
    if (!beast && spec.armorHeaviness > 0.52) {
      final cuisse = tube(
        [lerpO(l.a, l.b, 0.12), lerpO(l.a, l.b, 0.62)],
        [r * 1.00, r * 0.84],
        samples: 12,
      );
      paintSurface(canvas, cuisse, _plate, light, detail: q, occlusion: occ);
      if (depth == 0) paintTopPlane(canvas, cuisse, light, iso, strength: 0.34);
      // 쿠이스의 판 경계. 허벅지 금속이 한 장짜리 관으로 보이지 않게 한다.
      if (q > 0.55) {
        final across = (l.b - l.a).normalized().perp;
        final mid = lerpO(l.a, l.b, 0.40);
        canvas.save();
        canvas.clipPath(cuisse);
        panelLine(
          canvas,
          smoothOpenPath([
            mid - across * (r * 1.2),
            lerpO(l.a, l.b, 0.45),
            mid + across * (r * 1.2),
          ]),
          _plate.ramp,
          light,
          width: math.max(0.8, r * 0.09),
          alpha: 0.55,
        );
        canvas.restore();
      }

      final greave = tube(
        [lerpO(l.b, l.c, 0.22), lerpO(l.b, l.c, 0.92)],
        [r * 0.70, r * 0.54],
        samples: 12,
      );
      paintSurface(canvas, greave, _plate, light, detail: q, occlusion: occ);
    }

    // 발. 아이소에서는 발등이 보이므로 상단면 하이라이트를 얹는다.
    final toeDir = (l.d - l.c);
    final boot = tube(
      [l.c - Offset(0, r * 0.1), lerpO(l.c, l.d, 0.55), l.d],
      [r * 0.62, r * 0.58, r * 0.30],
      samples: 12,
    );
    paintSurface(
      canvas,
      boot,
      Surface(pal.leather, Finish.leather),
      light,
      detail: q,
      occlusion: occ + 0.2,
      edgeRim: true,
    );
    if (depth == 0) paintTopPlane(canvas, boot, light, iso, strength: 0.45);

    // 무릎 방어구. 판금 계열에서만.
    if (!beast && spec.armorHeaviness > 0.5) {
      final knee = blob(l.b, r * 0.86, r * 0.72, rotation: toeDir.angle);
      paintSurface(canvas, knee, _plate, light, detail: q, occlusion: occ);
      if (depth == 0) paintTopPlane(canvas, knee, light, iso, strength: 0.5);
    }
  }

  void _arm(
    Canvas canvas,
    Limb l,
    LightRig light,
    IsoView iso,
    double q, {
    required double depth,
    bool holdsBow = false,
  }) {
    final r = _armR;
    final occ = 0.16 + 0.34 * depth;

    final arm = tube(
      [l.a, lerpO(l.a, l.b, 0.45), l.b, lerpO(l.b, l.c, 0.5), l.c],
      [r * 1.15, r * 1.16, r * 0.86, r * 0.72, r * 0.62],
      samples: 22,
    );
    // 가까운 쪽 팔은 몸통 **위에** 겹쳐 그려진다. 갑옷이 무거우면 팔도 몸통도
    // 같은 판금이라 경계가 사라져 팔이 통째로 실종되고, 어깨와 손만 떠 있는
    // 그림이 된다. 팔 밑에 한 겹 어두운 윤곽을 깔아 떼어 놓는다.
    if (depth == 0) {
      canvas.drawPath(
        arm,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.40
          ..strokeJoin = StrokeJoin.round
          ..color = const Color(0xFF05070B).withValues(alpha: 0.34),
      );
    }
    paintSurface(
      canvas,
      arm,
      _limbArmor,
      light,
      detail: q,
      occlusion: occ,
      edgeRim: true,
      seed: spec.seed + 7 + depth.round(),
    );
    if (beast) _limbBands(canvas, arm, l.a, l.c, r, q, salt: 5 + depth.round());

    // 손.
    final hand = blob(
      lerpO(l.c, l.d, 0.45),
      r * 0.78,
      r * 0.66,
      rotation: (l.d - l.c).angle,
    );
    paintSurface(
      canvas,
      hand,
      Surface(pal.skin, Finish.skin),
      light,
      detail: q,
      occlusion: occ + 0.1,
      edgeRim: true,
    );

    // 발톱. 짐승형에게는 이것이 무기이므로 손끝에서 확실히 튀어나와야 한다.
    if (beast) {
      final dir = (l.d - l.c).normalized();
      final n = dir.perp;
      for (final k in [-1.0, 0.0, 1.0]) {
        final root = l.d + n * r * 0.45 * k;
        final claw = tube(
          [root, root + dir * r * 1.1 + n * r * 0.30 * k],
          [r * 0.24, r * 0.02],
          samples: 8,
        );
        paintSurface(
          canvas,
          claw,
          Surface(pal.metal, Finish.bone),
          light,
          detail: q,
          occlusion: occ,
        );
      }
    }

    // 어깨보호대. 아이소 뷰에서 실루엣의 상단을 지배하는 파츠이므로
    // 상단면 하이라이트를 반드시 준다.
    if (!beast && spec.hasPauldrons) {
      // 어깨 관절에 그대로 얹으면 목을 파고들어 머리와 겹친다. 팔이 뻗은
      // 방향으로 조금 밀어 어깨 **바깥**에 앉혀야 판금이 몸에 얹힌 것으로
      // 읽힌다. 크기도 팔 굵기의 1.5배면 충분하다 — 그 이상은 머리보다 커져
      // 실루엣이 사람이 아니라 덩어리가 된다.
      final ps = r * 1.52 * spec.pauldronScale;
      final outward = (l.b - l.a).normalized();
      final seat = l.a + outward * ps * 0.26 - Offset(0, ps * 0.30);
      final pauldron = blob(
        seat,
        ps * 0.92,
        ps * 0.74,
        points: 16,
        rotation: -0.15,
        warp: (a, t) => 1 + 0.12 * math.sin(a * 3 + spec.seed),
      );
      paintSurface(
        canvas,
        pauldron,
        _plate,
        light,
        detail: q,
        occlusion: occ * 0.6,
        edgeRim: true,
      );
      paintTopPlane(
        canvas,
        pauldron,
        light,
        iso,
        strength: depth == 0 ? 0.62 : 0.3,
      );
      if (spec.trimAccent) {
        trimBand(canvas, pauldron, pal.accent, light, width: 1.4, alpha: 0.55);
      }
    }
  }

  void _torso(
    Canvas canvas,
    Skeleton sk,
    LightRig light,
    IsoView iso,
    double q,
    Facing f,
  ) {
    final breath = 1 + sk.pose.breath * 0.035;
    // 정면일수록 몸통이 넓게, 측면일수록 앞뒤 두께로 보인다. 이 한 줄이
    // 방향 전환을 설득력 있게 만든다 — 폭이 그대로면 종이가 돌아가는 것처럼
    // 보인다.
    final w = lerpD(0.62, 1.0, 1 - f.profile);

    final torso = tube(
      [
        sk.pelvis + Offset(0, _hipW * 0.16),
        sk.pelvis,
        sk.waist,
        lerpO(sk.waist, sk.chest, 0.55),
        sk.chest,
      ],
      [
        _hipW * 0.40 * w,
        _hipW * 0.46 * w,
        _waistW * 0.46 * w,
        _chestW * 0.48 * w * breath,
        _chestW * 0.44 * w * breath,
      ],
      samples: 26,
    );
    paintSurface(
      canvas,
      torso,
      _torsoSurface,
      light,
      detail: q,
      occlusion: 0.14,
      edgeRim: true,
      seed: spec.seed,
    );
    paintTopPlane(canvas, torso, light, iso, strength: 0.3);

    // ── 재질별 매크로 텍스처 ─────────────────────────────────────────────
    //
    // 그라디언트 셰이딩만으로는 몸통이 "매끈한 관"이다. 재질마다 그 재질임을
    // 알리는 반복 단위·주름·경계가 한 겹 얹혀야 옷과 갑옷이 된다. 전부
    // 획과 채움뿐이다 — 매 프레임 도는 코드에 블러·Path.combine 을 넣으면
    // 래스터 예산이 무너진다는 것을 실측으로 배웠다.
    if (beast) {
      _hide(canvas, torso, sk, light, q);
    } else if (spec.armorHeaviness <= 0.2 && q > 0.45) {
      _clothFolds(canvas, torso, sk, q);
    } else if (spec.armorHeaviness <= 0.45 && q > 0.45) {
      _leatherStrap(canvas, torso, sk, light, q);
    }

    // 등가시. 짐승형의 실루엣 상단을 지배하는 파츠라 아이소에서 가장 먼저
    // 읽힌다.
    if (beast &&
        (beastForm == BeastForm.brute || beastForm == BeastForm.drake)) {
      final count = beastForm == BeastForm.drake ? 6 : 3;
      for (var i = 0; i < count; i++) {
        // 등 위쪽에 몰아준다. 골반까지 깔면 다리와 겹쳐 실루엣이 뭉갠다.
        final t = 0.30 + i * (0.64 / math.max(1, count - 1));
        final at = lerpO(sk.pelvis, sk.chest, t);
        final back = (sk.pelvis - sk.chest).normalized().perp;
        final size = _chestW * (0.14 + 0.18 * math.sin(t * math.pi));
        final spike = tube(
          [at, at + back * size * 1.25 - Offset(0, size * 0.8)],
          [size * 0.30, size * 0.02],
          samples: 8,
        );
        paintSurface(
          canvas,
          spike,
          Surface(pal.metal, Finish.bone),
          light,
          detail: q,
          occlusion: 0.2,
          edgeRim: true,
        );
        paintTopPlane(canvas, spike, light, iso, strength: 0.45);
      }
    }

    // 흉갑. 몸통 위에 한 겹 더 얹어야 판금이 "덧대어진" 것으로 읽힌다.
    if (_wearsArmor) {
      final chest = tube(
        [
          lerpO(sk.waist, sk.chest, 0.25),
          lerpO(sk.waist, sk.chest, 0.75),
          sk.chest,
        ],
        [_waistW * 0.44 * w, _chestW * 0.50 * w * breath, _chestW * 0.42 * w],
        samples: 16,
      );
      paintSurface(canvas, chest, _plate, light, detail: q, occlusion: 0.10);
      paintTopPlane(canvas, chest, light, iso, strength: 0.42);
      if (spec.trimAccent) {
        trimBand(canvas, chest, pal.accent, light, width: 1.6, alpha: 0.6);
      }

      // 판금의 패널 경계. 홈이 어둡고 그 위 모서리가 밝은 짝([panelLine])이
      // 있어야 한 장짜리 통조림이 아니라 조각을 이어 붙인 갑옷으로 읽힌다.
      if (q > 0.5) {
        final up = (sk.chest - sk.waist).normalized();
        final side = up.perp;
        final ramp = _plate.ramp;
        canvas.save();
        canvas.clipPath(chest);
        // 가슴 중앙의 세로 능선.
        panelLine(
          canvas,
          smoothOpenPath([
            lerpO(sk.waist, sk.chest, 0.30),
            lerpO(sk.waist, sk.chest, 0.66) + side * _chestW * 0.02,
            sk.chest + up * _h * 0.012,
          ]),
          ramp,
          light,
          width: math.max(1.0, _h * 0.0055),
          alpha: 0.8,
        );
        // 흉갑과 복부판을 가르는 가로 이음선.
        panelLine(
          canvas,
          smoothOpenPath([
            lerpO(sk.waist, sk.chest, 0.42) - side * _chestW * 0.30,
            lerpO(sk.waist, sk.chest, 0.52),
            lerpO(sk.waist, sk.chest, 0.42) + side * _chestW * 0.30,
          ]),
          ramp,
          light,
          width: math.max(0.8, _h * 0.0045),
          alpha: 0.6,
        );
        canvas.restore();
      }

      // 흉갑 아래로 드러나는 사슬 자락. 판 사이에 다른 재질이 비쳐야 갑옷이
      // "입은 것"이 된다. 고리는 점 두 개(테두리·반짝임)로 찍는다 — 블러도
      // saveLayer 도 없어 개수가 많아도 싸다.
      if (q > 0.6) {
        final up = (sk.waist - sk.pelvis).normalized();
        final side = up.perp;
        canvas.save();
        canvas.clipPath(torso);
        final rr = _waistW * 0.045;
        final ring = Paint()
          ..isAntiAlias = true
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(0.6, _h * 0.0016)
          ..color = pal.metal.darken(0.30).fade(0.7);
        final glint = Paint()..color = pal.metal.lighten(0.25).fade(0.45);
        for (var row = 0; row < 3; row++) {
          final base = lerpO(sk.pelvis, sk.waist, 0.60 - row * 0.21);
          final stagger = row.isOdd ? rr * 0.95 : 0.0;
          for (var i = -3; i <= 3; i++) {
            final at = base + side * (rr * 1.9 * i + stagger);
            canvas.drawCircle(at, rr, ring);
            canvas.drawCircle(at - light.dir * rr * 0.4, rr * 0.26, glint);
          }
        }
        canvas.restore();
      }
    }

    // 허리띠. 상·하체를 나누는 수평선은 실루엣에 리듬을 준다.
    if (!beast) {
      final beltDir = (sk.waist - sk.pelvis).normalized();
      final belt = tube(
        [sk.waist - beltDir * _h * 0.012, sk.waist + beltDir * _h * 0.012],
        [_waistW * 0.48 * w, _waistW * 0.46 * w],
        samples: 8,
      );
      paintSurface(
        canvas,
        belt,
        Surface(pal.leather, Finish.leather),
        light,
        detail: q,
        occlusion: 0.2,
      );
    }

    if (spec.glowRunes || beast) {
      final at = lerpO(sk.waist, sk.chest, 0.62);

      // 발광체는 자기만 빛나지 않는다. 주변 수광 파츠에 같은 색 반사광이
      // 얹혀야 룬이 **몸 위에 있는** 것이 되고, 그러지 않으면 가슴에 붙인
      // 스티커로 보인다. 채도 높은 강조색을 어두운 몸에 한 점 떨어뜨리는 것은
      // 60-30-10 의 10 이기도 하다 — 시선이 여기 멈춘다.
      canvas.save();
      canvas.clipPath(torso);
      canvas.drawCircle(
        at,
        _h * 0.085,
        Paint()
          ..isAntiAlias = true
          ..blendMode = BlendMode.plus
          ..shader = Gradient.radial(
            at,
            _h * 0.085,
            [pal.glow.fade(0.30), pal.glow.fade(0.09), const Color(0x00000000)],
            const [0.0, 0.42, 1.0],
          ),
      );
      canvas.restore();

      final rune = blob(at, _h * 0.017, _h * 0.017);
      paintSurface(
        canvas,
        rune,
        Surface(pal.glow, Finish.gem, glow: 0.9, glowColor: pal.glow),
        light,
        detail: q,
      );
      glowPath(canvas, rune, pal.glow, _h * 0.05, alpha: 0.8);
    }
  }

  /// 천 몸통의 주름과 밑단.
  ///
  /// 단색 관은 튜브지 옷이 아니다. 중력 방향으로 흐르는 주름 세 줄과 밑단의
  /// 어두운 띠 — 이 두 신호가 있어야 천이 몸에 **걸쳐진** 것으로 읽힌다.
  void _clothFolds(Canvas canvas, Path torso, Skeleton sk, double q) {
    final up = (sk.chest - sk.pelvis).normalized();
    final side = up.perp;
    canvas.save();
    canvas.clipPath(torso);

    final fold = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      // 천 마감의 _fiber 결이 이미 가는 세로선을 깔아 준다. 주름까지 진하면
      // 골판지가 되므로, 이쪽은 넓고 옅게 두 신호를 겹치지 않게 한다.
      ..strokeWidth = math.max(1.4, _waistW * 0.060)
      ..color = pal.clothShade.fade(0.20);
    for (final k in const [-0.32, 0.06, 0.36]) {
      // 주름은 곧은 선이 아니다 — 허리에서 한 번 꺾여야 천이 접힌 것이 된다.
      final swayK = _noise.signed1(k * 11 + spec.seed * 0.1) * _waistW * 0.07;
      canvas.drawPath(
        smoothOpenPath([
          lerpO(sk.waist, sk.chest, 0.70) + side * (_waistW * k * 0.75),
          sk.waist + side * (_waistW * k + swayK),
          lerpO(sk.pelvis, sk.waist, 0.10) + side * (_waistW * k * 1.15),
        ]),
        fold,
      );
    }

    // 밑단 그늘. 옷자락 끝은 몸에서 떨어져 그늘에 잠긴다.
    canvas.drawRect(
      torso.getBounds(),
      Paint()
        ..blendMode = BlendMode.multiply
        ..shader = Gradient.linear(
          sk.pelvis + up * (_h * 0.02),
          lerpO(sk.pelvis, sk.waist, 0.75),
          [pal.clothShade.fade(0.40), const Color(0x00FFFFFF)],
        ),
    );
    canvas.restore();
  }

  /// 가죽 갑주의 어깨끈·버클·스티치.
  ///
  /// 면에 반복 단위가 없으면 관객이 크기를 읽을 수 없다. 몸통을 가로지르는
  /// 끈 하나가 "이것은 장비다"를 만들고, 스티치 점이 스케일을 알려 준다.
  void _leatherStrap(
    Canvas canvas,
    Path torso,
    Skeleton sk,
    LightRig light,
    double q,
  ) {
    final up = (sk.chest - sk.pelvis).normalized();
    final side = up.perp;
    final a = sk.chest + side * (_chestW * 0.26) + up * (_h * 0.008);
    final b = lerpO(sk.pelvis, sk.waist, 0.42) - side * (_waistW * 0.34);
    final spine = [a, lerpO(a, b, 0.5), b];

    canvas.save();
    canvas.clipPath(torso);
    final strap = tube(spine, [
      _waistW * 0.075,
      _waistW * 0.068,
      _waistW * 0.075,
    ], samples: 10);
    paintSurface(
      canvas,
      strap,
      Surface(pal.leather.darken(0.18), Finish.leather),
      light,
      detail: q,
      rim: false,
      ao: false,
    );
    // 끈의 광원 쪽 모서리. 이 한 줄이 끈을 몸에서 떼어 놓는다.
    canvas.drawPath(
      smoothOpenPath(spine).shift(-light.dir * (_waistW * 0.045)),
      Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = math.max(0.8, _waistW * 0.018)
        ..color = pal.leather.lighten(0.30).fade(0.5),
    );
    // 스티치 점. 멀리서는 사라지고 초상 거리에서만 보인다.
    if (q > 0.65) {
      final dot = Paint()..color = pal.leather.lighten(0.38).fade(0.55);
      for (var i = 0; i < 5; i++) {
        canvas.drawCircle(
          lerpO(a, b, 0.14 + i * 0.18) + side * (_waistW * 0.055),
          math.max(0.6, _waistW * 0.009),
          dot,
        );
      }
    }
    canvas.restore();

    // 버클. 작아도 금속 하이라이트 하나가 끈에 무게를 준다.
    final buckle = blob(lerpO(a, b, 0.5), _waistW * 0.055, _waistW * 0.048);
    paintSurface(
      canvas,
      buckle,
      Surface(pal.metalWarm, Finish.metal, contrast: 1.0),
      light,
      detail: q,
      rim: false,
    );
  }

  /// 짐승 가죽의 얼룩과 등의 어둠.
  ///
  /// 매끈한 살덩이는 풍선이다. 등줄기가 배보다 어둡고(원통의 신호), 가죽에
  /// 얼룩이 번져 있어야(재질의 신호) 생물로 읽힌다. 가장자리는 블러 대신
  /// 방사 그라디언트로 풀어 준다 — 결과는 비슷하고 비용은 수십 분의 일이다.
  void _hide(Canvas canvas, Path torso, Skeleton sk, LightRig light, double q) {
    if (q <= 0.4) return;
    final b = torso.getBounds();
    if (b.isEmpty) return;
    final back = (sk.pelvis - sk.chest).normalized().perp;

    canvas.save();
    canvas.clipPath(torso);

    // ① 카운터셰이딩 — 등은 어둡고 배는 밝다.
    //
    // 실제 동물의 보편적 무늬이며, 여기서는 그 이상의 일을 한다. 그레이스케일
    // 감사에서 몬스터는 명도가 한 덩어리로 뭉친 **검은 구멍**이었다. 몸 하나에
    // 밝은 구역과 어두운 구역이 갈려 있어야 관객이 부피를 읽고, 그 위에 올린
    // 얼룩과 주름도 비로소 보인다. 등의 어둠만으로는 대비가 생기지 않는다 —
    // 반드시 배를 함께 올려야 한다.
    canvas.drawRect(
      b,
      Paint()
        ..blendMode = BlendMode.multiply
        ..shader = Gradient.linear(
          b.center + back * (b.width * 0.5),
          b.center - back * (b.width * 0.5),
          [
            pal.skinDeep.mix(light.ambient, 0.30).fade(0.50),
            const Color(0x00FFFFFF),
          ],
          const [0.0, 0.62],
        ),
    );
    canvas.drawRect(
      b,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = Gradient.linear(
          b.center - back * (b.width * 0.52),
          b.center + back * (b.width * 0.30),
          [pal.skin.lighten(0.40).fade(0.26), const Color(0x00000000)],
          const [0.0, 0.85],
        ),
    );

    // ② 가죽 얼룩. 크기와 자리를 노이즈로 흩뜨려야 물방울무늬가 안 된다.
    final patch = Paint()
      ..isAntiAlias = true
      ..blendMode = BlendMode.multiply;
    final count = q > 0.7 ? 6 : 4;
    for (var i = 0; i < count; i++) {
      final u = (i + 0.5) / count;
      final at =
          lerpO(sk.pelvis, sk.chest, 0.10 + 0.82 * u) +
          Offset(
                _noise.signed1(u * 7.3 + spec.seed * 0.03),
                _noise.signed1(u * 4.1 - spec.seed * 0.02),
              ) *
              (_chestW * 0.24);
      final rx = _chestW * (0.15 + 0.14 * _noise.at1(u * 5.7 + 3));
      patch.shader = Gradient.radial(at, rx, [
        pal.skinDeep.fade(0.32),
        pal.skinDeep.fade(0.0),
      ]);
      canvas.drawOval(
        Rect.fromCenter(center: at, width: rx * 2.2, height: rx * 1.7),
        patch,
      );
    }
    canvas.restore();
  }

  /// 사지를 두르는 가죽 주름 띠. 짐승 전용.
  ///
  /// 팔다리 관에 가로 띠 몇 줄이 생기면 살이 접히는 두께가 보인다.
  void _limbBands(
    Canvas canvas,
    Path limb,
    Offset a,
    Offset b,
    double r,
    double q, {
    int salt = 0,
  }) {
    if (q <= 0.5) return;
    final dir = (b - a).normalized();
    final across = dir.perp;
    final stroke = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = math.max(1.0, r * 0.30)
      ..color = pal.skinDeep.fade(0.18);
    canvas.save();
    canvas.clipPath(limb);
    for (final t in const [0.34, 0.62, 0.84]) {
      final at = lerpO(a, b, t + 0.05 * _noise.signed1(t * 9.0 + salt));
      canvas.drawLine(
        at - across * (r * 1.3),
        at + across * (r * 1.3) + dir * (r * 0.22),
        stroke,
      );
    }
    canvas.restore();
  }

  /// A class-readable secondary silhouette for heroes.
  ///
  /// These are intentionally large, sparse shapes. At the game camera a
  /// quiver or a split scarf survives; buckles and embroidery do not.
  void _heroBackSilhouette(
    Canvas canvas,
    Skeleton sk,
    LightRig light,
    IsoView iso,
    double q,
    double time,
  ) {
    final up = (sk.chest - sk.pelvis).normalized();
    final side = up.perp;
    switch (spec.archetype) {
      case Archetype.knight:
        // A dark diagonal scabbard keeps the knight's back view armed even
        // when the sword itself is hidden by the torso.
        final a = sk.pelvis - side * _h * 0.08;
        final b = sk.chest + side * _h * 0.17 + up * _h * 0.10;
        final sheath = tube([a, b], [_h * 0.017, _h * 0.013], samples: 10);
        paintSurface(
          canvas,
          sheath,
          Surface(pal.leather, Finish.leather),
          light,
          detail: q,
          occlusion: 0.32,
          edgeRim: true,
        );
      case Archetype.berserker:
        final mantle = blob(
          sk.chest + up * _h * 0.005,
          _shoulderW * 0.60,
          _h * 0.075,
          points: 22,
          warp: (a, t) =>
              1 + 0.14 * math.sin(a * 7 + spec.seed) + 0.06 * math.sin(a * 13),
        );
        paintSurface(
          canvas,
          mantle,
          Surface(pal.leather.lighten(0.08), Finish.fur, contrast: 1.18),
          light,
          detail: q,
          occlusion: 0.22,
          edgeRim: true,
          seed: spec.seed + 91,
        );
      case Archetype.ranger:
        final root = sk.chest - side * _shoulderW * 0.34;
        final end = root - up * _h * 0.23 + side * _h * 0.025;
        final quiver = tube(
          [root + up * _h * 0.08, end],
          [_h * 0.040, _h * 0.055],
          samples: 12,
        );
        paintSurface(
          canvas,
          quiver,
          Surface(pal.leather, Finish.leather),
          light,
          detail: q,
          occlusion: 0.28,
          edgeRim: true,
        );
        for (var i = -1; i <= 2; i++) {
          final shaftRoot = root + side * (_h * 0.012 * i);
          final shaftEnd = shaftRoot + up * _h * (0.22 + i.abs() * 0.012);
          final shaft = tube(
            [shaftRoot, shaftEnd],
            [_h * 0.0045, _h * 0.003],
            samples: 6,
          );
          paintSurface(
            canvas,
            shaft,
            Surface(pal.leather, Finish.wood),
            light,
            detail: q,
            occlusion: 0.24,
          );
          final tip = tube(
            [shaftEnd - up * _h * 0.018, shaftEnd + up * _h * 0.014],
            [_h * 0.012, _h * 0.001],
            samples: 6,
          );
          paintSurface(
            canvas,
            tip,
            Surface(pal.metal, Finish.metal),
            light,
            detail: q,
            occlusion: 0.20,
          );
        }
      case Archetype.mage:
        // A pointed arcane collar creates a broad-shoulder/narrow-body read
        // without making the lightly armored caster look physically bulky.
        final collar = smoothClosedPath([
          sk.chest - side * _h * 0.18,
          sk.chest - side * _h * 0.29 + up * _h * 0.09,
          sk.neckTop - side * _h * 0.06,
          sk.neckTop + side * _h * 0.06,
          sk.chest + side * _h * 0.29 + up * _h * 0.09,
          sk.chest + side * _h * 0.18,
          sk.chest + up * _h * 0.015,
        ], tension: 0.42);
        paintSurface(
          canvas,
          collar,
          Surface(pal.clothShade, Finish.cloth, contrast: 1.16),
          light,
          detail: q,
          occlusion: 0.24,
          edgeRim: true,
        );
        trimBand(canvas, collar, pal.accent, light, width: 1.2, alpha: 0.55);
      case Archetype.assassin:
        final flow = math.sin(time * 2.2 + spec.seed) * _h * 0.025;
        for (final sign in [-1.0, 1.0]) {
          final root = sk.neckTop + side * sign * _h * 0.035;
          final scarf = smoothClosedPath([
            root,
            sk.chest + side * sign * _h * 0.09,
            sk.pelvis + side * sign * (_h * 0.14 + flow),
            sk.pelvis + side * sign * (_h * 0.07 + flow) - up * _h * 0.22,
            sk.chest + side * sign * _h * 0.035,
          ], tension: 0.52);
          paintSurface(
            canvas,
            scarf,
            Surface(pal.accent.darken(0.22), Finish.cloth),
            light,
            detail: q,
            occlusion: 0.30,
            edgeRim: true,
          );
        }
      case Archetype.paladin:
        final center = sk.headCenter - up * body.headLen * 0.10;
        final halo = Paint()
          ..isAntiAlias = true
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.2, _h * 0.010)
          ..color = pal.metalWarm.lighten(0.22).fade(0.88);
        canvas.drawCircle(center, body.headLen * 0.72, halo);
        for (var i = 0; i < 8; i++) {
          final a = i * math.pi / 4 + time * 0.05;
          final d = Offset(math.cos(a), math.sin(a));
          final ray = tube(
            [
              center + d * body.headLen * 0.76,
              center + d * body.headLen * (i.isEven ? 1.02 : 0.91),
            ],
            [body.headLen * 0.035, body.headLen * 0.005],
            samples: 6,
          );
          paintSurface(
            canvas,
            ray,
            Surface(
              pal.metalWarm,
              Finish.metal,
              glow: 0.12,
              glowColor: pal.glow,
            ),
            light,
            detail: q,
            occlusion: 0.20,
          );
        }
    }
  }

  void _monsterBackSilhouette(
    Canvas canvas,
    Skeleton sk,
    LightRig light,
    IsoView iso,
    double q,
    double time,
  ) {
    switch (beastForm) {
      case BeastForm.brute:
        _bruteTrophy(canvas, sk, light, iso, q);
      case BeastForm.drake:
        _drakeWings(canvas, sk, light, iso, q, time);
      case BeastForm.wraith:
        _wraithMantle(canvas, sk, light, q, time);
      case BeastForm.arachnid:
        _arachnidRear(canvas, sk, light, iso, q, time);
    }
  }

  void _bruteTrophy(
    Canvas canvas,
    Skeleton sk,
    LightRig light,
    IsoView iso,
    double q,
  ) {
    final up = (sk.chest - sk.pelvis).normalized();
    final side = up.perp;
    final plate = blob(
      sk.chest - side * _shoulderW * 0.42 + up * _h * 0.025,
      _h * 0.095,
      _h * 0.075,
      points: 14,
      warp: (a, t) => 1 + 0.18 * math.sin(a * 3 + 0.7),
    );
    paintSurface(
      canvas,
      plate,
      Surface(pal.metal, Finish.bone, contrast: 1.22),
      light,
      detail: q,
      occlusion: 0.24,
      edgeRim: true,
    );
    paintTopPlane(canvas, plate, light, iso, strength: 0.45);
    for (var i = 0; i < 3; i++) {
      final root = sk.chest - side * (_h * (0.09 + i * 0.025));
      final spike = tube(
        [root, root + up * _h * (0.15 + i * 0.025) - side * _h * 0.035],
        [_h * 0.026, _h * 0.002],
        samples: 8,
      );
      paintSurface(
        canvas,
        spike,
        Surface(pal.metal, Finish.bone),
        light,
        detail: q,
        occlusion: 0.18,
        edgeRim: true,
      );
    }
  }

  void _drakeWings(
    Canvas canvas,
    Skeleton sk,
    LightRig light,
    IsoView iso,
    double q,
    double time,
  ) {
    final up = (sk.chest - sk.pelvis).normalized();
    final side = up.perp;
    final flex = math.sin(time * 1.4 + spec.seed) * _h * 0.018;
    for (final sign in [-1.0, 1.0]) {
      final root = sk.chest + side * sign * _h * 0.055;
      final knuckle = root + side * sign * (_h * 0.32 + flex) + up * _h * 0.22;
      final tip = root + side * sign * (_h * 0.46 + flex) + up * _h * 0.42;
      final low = sk.pelvis + side * sign * (_h * 0.32 + flex) - up * _h * 0.10;
      final membrane = smoothClosedPath([
        root,
        knuckle,
        tip,
        lerpO(tip, low, 0.38) - up * _h * 0.08,
        lerpO(tip, low, 0.68) + side * sign * _h * 0.025,
        low,
        sk.pelvis + side * sign * _h * 0.05,
      ], tension: 0.35);
      paintSurface(
        canvas,
        membrane,
        Surface(
          pal.skinDeep.mix(pal.accent, 0.22),
          Finish.membrane,
          contrast: 1.18,
          alpha: sign < 0 ? 0.68 : 0.82,
        ),
        light,
        detail: q,
        occlusion: sign < 0 ? 0.34 : 0.22,
        edgeRim: true,
      );
      for (final end in [knuckle, tip, low]) {
        final spar = tube([root, end], [_h * 0.016, _h * 0.006], samples: 10);
        paintSurface(
          canvas,
          spar,
          Surface(pal.metal, Finish.bone),
          light,
          detail: q,
          occlusion: 0.18,
          edgeRim: true,
        );
      }
      paintTopPlane(canvas, membrane, light, iso, strength: 0.20);
    }
  }

  void _wraithMantle(
    Canvas canvas,
    Skeleton sk,
    LightRig light,
    double q,
    double time,
  ) {
    final up = (sk.chest - sk.pelvis).normalized();
    final side = up.perp;
    final drift = math.sin(time * 1.3 + spec.seed * 0.1) * _h * 0.025;
    final mantle = smoothClosedPath([
      sk.chest - side * _h * 0.15 + up * _h * 0.05,
      sk.pelvis - side * _h * 0.19,
      sk.groundContact - side * _h * 0.22 + Offset(drift, -_h * 0.03),
      sk.groundContact - side * _h * 0.07 - up * _h * 0.10,
      sk.groundContact + side * _h * 0.06 + up * _h * 0.01,
      sk.groundContact + side * _h * 0.18 - up * _h * 0.08 + Offset(drift, 0),
      sk.pelvis + side * _h * 0.18,
      sk.chest + side * _h * 0.15 + up * _h * 0.05,
    ], tension: 0.50);
    paintSurface(
      canvas,
      mantle,
      Surface(
        pal.clothShade.mix(pal.glow, 0.16),
        Finish.cloth,
        contrast: 1.12,
        alpha: 0.72,
      ),
      light,
      detail: q,
      occlusion: 0.25,
      edgeRim: true,
    );
    glowPath(canvas, mantle, pal.glow, _h * 0.045, alpha: 0.28);
  }

  void _arachnidRear(
    Canvas canvas,
    Skeleton sk,
    LightRig light,
    IsoView iso,
    double q,
    double time,
  ) {
    final up = (sk.chest - sk.pelvis).normalized();
    final side = up.perp;
    final abdomenCenter = sk.pelvis - up * _h * 0.07;
    final abdomen = blob(
      abdomenCenter,
      _h * 0.155,
      _h * 0.125,
      points: 20,
      rotation: side.angle,
      warp: (a, t) => 1 + 0.08 * math.sin(a * 4 + spec.seed),
    );
    paintSurface(
      canvas,
      abdomen,
      _plate,
      light,
      detail: q,
      occlusion: 0.28,
      edgeRim: true,
      seed: spec.seed + 73,
    );
    paintTopPlane(canvas, abdomen, light, iso, strength: 0.48);

    final pulse = math.sin(time * 1.8 + spec.seed) * _h * 0.012;
    for (final sign in [-1.0, 1.0]) {
      for (var row = 0; row < 2; row++) {
        final root =
            lerpO(sk.pelvis, sk.chest, 0.20 + row * 0.22) +
            side * sign * _h * 0.05;
        final knee =
            root +
            side * sign * (_h * (0.22 + row * 0.055) + pulse) +
            up * _h * (0.04 + row * 0.08);
        final foot =
            sk.groundContact +
            side * sign * (_h * (0.30 + row * 0.09)) +
            Offset(0, -row * _h * 0.018);
        final leg = tube(
          [root, knee, foot],
          [_h * 0.025, _h * 0.018, _h * 0.004],
          samples: 16,
        );
        paintSurface(
          canvas,
          leg,
          _plate,
          light,
          detail: q,
          occlusion: row == 0 ? 0.34 : 0.24,
          edgeRim: true,
          seed: spec.seed + 80 + row,
        );
      }
    }
  }

  /// 꼬리. 몸통 뒤에서 나와 관성으로 늦게 따라온다 — 포즈의 흔들림을
  /// 그대로 쓰지 않고 시간 지연을 주어야 살아 있는 부속으로 읽힌다.
  void _tail(
    Canvas canvas,
    Skeleton sk,
    LightRig light,
    IsoView iso,
    double q,
    double time,
  ) {
    final drake = beastForm == BeastForm.drake;
    final len = _h * (drake ? 0.82 : 0.42);
    final back = (sk.pelvis - sk.chest).normalized().perp;
    final root = sk.pelvis + back * _hipW * 0.30;
    final drift = wobble(time * 2.1, spec.seed * 0.31);
    final lift = sk.pose.capeFlow * 0.6 + 0.2;

    final tail = tube(
      [
        root,
        root + back * len * 0.36 + Offset(0, len * (0.10 - lift * 0.18)),
        root +
            back * len * 0.72 +
            Offset(0, len * (0.22 - lift * 0.34) + drift * len * 0.10),
        root +
            back * len * 1.02 +
            Offset(0, len * (0.30 - lift * 0.50) + drift * len * 0.20),
      ],
      [
        _hipW * (drake ? 0.34 : 0.30),
        _hipW * (drake ? 0.25 : 0.22),
        _hipW * (drake ? 0.14 : 0.13),
        _hipW * 0.03,
      ],
      samples: 24,
    );
    paintSurface(
      canvas,
      tail,
      _beastSurface,
      light,
      detail: q,
      occlusion: 0.34,
      edgeRim: true,
      seed: spec.seed + 21,
    );
    if (drake) {
      final tip =
          root +
          back * len * 1.02 +
          Offset(0, len * (0.30 - lift * 0.50) + drift * len * 0.20);
      final blade = tube(
        [tip - back * _h * 0.045, tip + back * _h * 0.075],
        [_h * 0.032, _h * 0.002],
        samples: 8,
      );
      paintSurface(
        canvas,
        blade,
        Surface(pal.metal, Finish.bone),
        light,
        detail: q,
        occlusion: 0.22,
        edgeRim: true,
      );
      paintTopPlane(canvas, blade, light, iso, strength: 0.35);
    }
  }

  void _head(
    Canvas canvas,
    Skeleton sk,
    LightRig light,
    IsoView iso,
    double q,
    Facing f,
  ) {
    final hl = body.headLen;

    // 목.
    final neck = tube(
      [sk.chest, sk.neckTop],
      [_neckW * 0.52, _neckW * 0.46],
      samples: 8,
    );
    paintSurface(
      canvas,
      neck,
      beast ? _beastHeadSurface : Surface(pal.skin, Finish.skin),
      light,
      detail: q,
      occlusion: 0.45,
    );

    // 머리부터는 머리 로컬 좌표에서 그린다. 원점이 머리 중심, +x 가 전방,
    // -y 가 정수리 방향이므로 이목구비를 정면 기준으로 배치할 수 있다.
    final rot = sk.headAngle + math.pi / 2;
    canvas.save();
    canvas.translate(sk.headCenter.dx, sk.headCenter.dy);
    canvas.rotate(rot);
    final hLight = light.rotated(-rot);

    // 뒷머리를 두개골 **앞에** 깐다.
    //
    // 예전에는 머리카락을 통째로 얼굴 뒤에 그렸는데, 그 덩어리가 두개골보다
    // 커서 눈·코·입을 전부 덮어 버렸다 — 게임 액터의 머리가 매끈한 공으로
    // 보이던 원인이 이것이다. 뒤통수 볼륨은 얼굴보다 먼저, 앞머리는 얼굴보다
    // 나중에 그려야 둘 다 살아난다.
    if (!beast) _hairBack(canvas, hLight, iso, hl, q);

    // 두개골. 뒤통수가 크고 얼굴 쪽이 좁은 계란형이 사람으로 읽히는 최소 조건.
    final skull = blob(
      Offset(-hl * 0.06, 0),
      hl * 0.44,
      hl * 0.48,
      points: 18,
      warp: (a, t) {
        final front = math.cos(a);
        final down = math.sin(a);
        // 턱은 앞아래로 좁아지고, 뒤통수는 뒤로 부푼다.
        return 1 +
            0.10 * (1 - front) * 0.5 -
            0.16 * clamp01(front * down) +
            0.05 * _noise.signed1(a * 2 + spec.seed * 0.01);
      },
    );
    paintSurface(
      canvas,
      skull,
      beast ? _beastHeadSurface : Surface(pal.skin, Finish.skin),
      hLight,
      detail: q,
      occlusion: 0.12,
      edgeRim: true,
      seed: spec.seed + 3,
    );
    paintTopPlane(canvas, skull, hLight, iso, strength: 0.34);

    // 얼굴을 화면에서 가장 대비가 센 곳으로 만든다.
    //
    // 캐릭터 디자인의 통칙이다 — 시선은 대비가 가장 강한 곳에 멈추므로, 그
    // 자리가 얼굴이 아니면 관객은 갑옷이나 무기를 먼저 본다. 그레이스케일
    // 감사에서 이 렌더러의 머리는 몸통과 같은 중간 명도 덩어리였고, 그래서
    // 여섯 캐릭터가 전부 "얼굴 없는 실루엣"으로 읽혔다.
    //
    // 광원 쪽 이마·광대에 좁은 하이라이트를 얹어 명도의 위쪽 끝을 여기에
    // 몰아준다. 파츠를 더 그리는 것이 아니라 **이미 있는 형태를 밝히는**
    // 것이므로 실루엣은 그대로다.
    canvas.save();
    canvas.clipPath(skull);
    final keyAt = Offset(hLight.dir.dx, hLight.dir.dy) * (hl * 0.30);
    final faceBase = beast ? _beastHeadSurface.base : pal.skin;
    canvas.drawCircle(
      keyAt,
      hl * 0.46,
      Paint()
        ..isAntiAlias = true
        ..blendMode = BlendMode.plus
        ..shader = Gradient.radial(
          keyAt,
          hl * 0.46,
          [
            faceBase.lighten(0.34).fade(0.30),
            faceBase.lighten(0.20).fade(0.10),
            const Color(0x00000000),
          ],
          const [0.0, 0.45, 1.0],
        ),
    );
    // 반대쪽 턱선은 반대로 눌러 준다. 밝은 쪽만 올리면 머리가 커 보이고,
    // 어두운 쪽을 함께 내려야 대비가 생긴다.
    canvas.drawCircle(
      -keyAt,
      hl * 0.42,
      Paint()
        ..isAntiAlias = true
        ..blendMode = BlendMode.multiply
        ..shader = Gradient.radial(
          -keyAt,
          hl * 0.42,
          [
            pal.skinDeep.mix(hLight.ambient, 0.35).fade(0.34),
            const Color(0x00FFFFFF),
          ],
          const [0.0, 1.0],
        ),
    );
    canvas.restore();

    // 짐승형의 아래턱. 벌린 입이 실루엣 밖으로 나가야 포효가 읽힌다.
    if (beast &&
        beastForm != BeastForm.wraith &&
        beastForm != BeastForm.arachnid) {
      final open = sk.pose.mouth.clamp(0.0, 1.0);
      final jaw = tube(
        [
          Offset(-hl * 0.10, hl * 0.22),
          Offset(hl * 0.20, hl * (0.30 + 0.26 * open)),
          Offset(hl * 0.50, hl * (0.24 + 0.40 * open)),
        ],
        [hl * 0.22, hl * 0.17, hl * 0.07],
        samples: 14,
      );
      paintSurface(
        canvas,
        jaw,
        Surface(pal.skinDeep, Finish.skin),
        hLight,
        detail: q,
        occlusion: 0.3,
      );
      // 이빨.
      for (var i = 0; i < 4; i++) {
        final t = 0.24 + i * 0.16;
        final at = Offset(hl * (0.02 + t * 0.55), hl * (0.20 + 0.28 * open));
        final fang = tube(
          [at, at - Offset(0, hl * 0.11)],
          [hl * 0.030, hl * 0.004],
          samples: 6,
        );
        paintSurface(
          canvas,
          fang,
          Surface(pal.metal, Finish.bone),
          hLight,
          detail: q,
        );
      }
    }

    // 얼굴은 방향에 따라 서서히 사라진다. toCamera 로 끊으면 3/4 를 지나는
    // 순간 이목구비가 통째로 없어져 캐릭터가 껌뻑인다.
    if (f.faceVisible > 0.02) {
      _face(canvas, hLight, hl, sk.pose, f, q);
    }
    // 측면·후면에서는 코와 턱이 실루엣 밖으로 나와야 옆얼굴로 읽힌다.
    if (f.profileJut > 0.15) {
      _profileFeatures(canvas, hLight, hl, f, q);
    }

    if (beast) {
      _beastCrown(canvas, hLight, iso, hl, q);
    } else {
      _hairAndHelm(canvas, hLight, iso, hl, q, f);
    }

    canvas.restore();
  }

  /// The head carries each monster's secondary read: horns for the brute,
  /// swept antlers for the drake, a broken crown for the wraith, and a low
  /// eye/mandible cluster for the brood creature.
  void _beastCrown(
    Canvas canvas,
    LightRig light,
    IsoView iso,
    double hl,
    double q,
  ) {
    switch (beastForm) {
      case BeastForm.brute:
        final curl = 0.6 + _noise.at1(spec.seed * 0.11) * 1.2;
        for (final side in [1.0, 0.55]) {
          final horn = tube(
            [
              Offset(-hl * 0.14, -hl * 0.34),
              Offset(-hl * 0.34 * side, -hl * 0.70),
              Offset(-hl * 0.16 * side, -hl * 0.98),
              Offset(hl * (0.16 * curl) * side, -hl * 1.02),
            ],
            [hl * 0.19, hl * 0.13, hl * 0.08, hl * 0.015],
            samples: 20,
          );
          paintSurface(
            canvas,
            horn,
            Surface(pal.metal, Finish.bone),
            light,
            detail: q,
            occlusion: 0.12,
            edgeRim: true,
            seed: spec.seed + 31,
          );
          paintTopPlane(canvas, horn, light, iso, strength: 0.55);
        }
      case BeastForm.drake:
        for (final sign in [-1.0, 1.0]) {
          final horn = tube(
            [
              Offset(-hl * 0.18, -hl * 0.28 + sign * hl * 0.10),
              Offset(-hl * 0.50, -hl * 0.50 + sign * hl * 0.18),
              Offset(-hl * 0.88, -hl * 0.46 + sign * hl * 0.24),
              Offset(-hl * 1.18, -hl * 0.28 + sign * hl * 0.28),
            ],
            [hl * 0.14, hl * 0.10, hl * 0.055, hl * 0.008],
            samples: 18,
          );
          paintSurface(
            canvas,
            horn,
            Surface(pal.metal, Finish.bone),
            light,
            detail: q,
            occlusion: sign < 0 ? 0.20 : 0.08,
            edgeRim: true,
            seed: spec.seed + 41 + sign.round(),
          );
          paintTopPlane(canvas, horn, light, iso, strength: 0.48);
        }
      case BeastForm.wraith:
        final halo = Paint()
          ..isAntiAlias = true
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.0, hl * 0.075)
          ..color = pal.glow.fade(0.72);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(-hl * 0.18, -hl * 0.30),
            width: hl * 1.55,
            height: hl * 0.72,
          ),
          halo,
        );
        for (var i = 0; i < 5; i++) {
          final x = (i - 2) * hl * 0.18;
          final root = Offset(x - hl * 0.18, -hl * 0.42);
          final shard = tube(
            [
              root,
              root + Offset(x * 0.18, -hl * (0.34 + (i.isEven ? 0.07 : 0.0))),
            ],
            [hl * 0.055, hl * 0.006],
            samples: 7,
          );
          paintSurface(
            canvas,
            shard,
            Surface(pal.metal, Finish.bone, glow: 0.22, glowColor: pal.glow),
            light,
            detail: q,
            occlusion: 0.12,
            edgeRim: true,
          );
        }
      case BeastForm.arachnid:
        // Eight eyes form one bright, low cluster instead of a human face.
        for (var row = 0; row < 2; row++) {
          for (var i = 0; i < 4; i++) {
            final eye = Offset(
              hl * (0.06 + i * 0.13),
              hl * (-0.14 + row * 0.13 + (i.isOdd ? 0.025 : 0)),
            );
            final r = hl * (row == 0 ? 0.052 : 0.043);
            canvas.drawCircle(
              eye,
              r * 1.9,
              Paint()..color = pal.glow.fade(0.16),
            );
            canvas.drawCircle(eye, r, Paint()..color = pal.eye.lighten(0.22));
            canvas.drawCircle(
              eye + Offset(r * 0.20, -r * 0.22),
              r * 0.28,
              Paint()..color = const Color(0xFFFFFFFF).fade(0.80),
            );
          }
        }
        for (final sign in [-1.0, 1.0]) {
          final mandible = tube(
            [
              Offset(hl * 0.22, hl * (0.12 + sign * 0.10)),
              Offset(hl * 0.52, hl * (0.26 + sign * 0.22)),
              Offset(hl * 0.66, hl * (0.12 + sign * 0.15)),
            ],
            [hl * 0.10, hl * 0.07, hl * 0.008],
            samples: 12,
          );
          paintSurface(
            canvas,
            mandible,
            _plate,
            light,
            detail: q,
            occlusion: 0.10,
            edgeRim: true,
          );
        }
    }
  }

  /// 이목구비. 아이소에서 머리는 작으므로 눈만 확실히 읽히면 된다 —
  /// 눈 사이 간격을 페이싱으로 좁혀 3/4 각도를 만든다.
  void _face(
    Canvas canvas,
    LightRig light,
    double hl,
    Pose pose,
    Facing f,
    double q,
  ) {
    final open = pose.eyeOpen.clamp(0.0, 1.0);
    if (open < 0.06) {
      // 감긴 눈은 선 하나로. 죽음·피격에서 이 한 줄이 표정을 만든다.
      final lid = Path()
        ..moveTo(hl * 0.16, -hl * 0.06)
        ..lineTo(hl * 0.34, -hl * 0.05);
      canvas.drawPath(
        lid,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = hl * 0.035
          ..strokeCap = StrokeCap.round
          ..color = shiftColor(pal.skinDeep, dl: -0.08),
      );
      return;
    }

    // 눈 두 개. 정면일수록 좌우로 벌어지고, 3/4 를 지나면 **먼 쪽 눈이 얼굴
    // 윤곽에 가려** 사라진다. 이 가림이 없으면 옆얼굴에 눈이 둘 다 붙어
    // 있어 즉시 가짜로 보인다.
    final vis = f.faceVisible;
    final gap = hl * 0.30 * (1 - f.profile);
    final eyes = <(double, double)>[
      (hl * 0.30, 1.0), // 가까운 눈 — 항상 보인다
      (hl * 0.30 - gap, f.bothEyes), // 먼 눈 — 3/4 를 지나면 가린다
    ];
    for (final (ex, weight) in eyes) {
      final a = (weight * vis).clamp(0.0, 1.0);
      if (a < 0.04) continue;
      final eye = blob(Offset(ex, -hl * 0.05), hl * 0.075, hl * 0.055 * open);
      paintSurface(
        canvas,
        eye,
        Surface(pal.eye, Finish.gem, glow: 0.9, glowColor: pal.glow, alpha: a),
        light,
        detail: q,
      );
      canvas.drawCircle(
        Offset(ex + hl * 0.012, -hl * 0.05),
        hl * 0.026 * open,
        Paint()..color = const Color(0xFF120E14).withValues(alpha: 0.85 * a),
      );
    }

    // 눈썹 능선. 눈 위 그림자 하나로 얼굴에 골격이 생긴다.
    canvas.drawPath(
      Path()
        ..moveTo(hl * 0.10, -hl * 0.13)
        ..quadraticBezierTo(hl * 0.28, -hl * 0.19, hl * 0.40, -hl * 0.11),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = hl * 0.05
        ..strokeCap = StrokeCap.round
        ..color = pal.skinDeep.withValues(alpha: 0.5 * vis)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, hl * 0.03),
    );

    // 입. 벌린 정도가 공격의 기합과 죽음의 신음을 만든다.
    final m = pose.mouth.clamp(0.0, 1.0);
    final mouth = Rect.fromCenter(
      center: Offset(hl * 0.31, hl * 0.20),
      width: hl * (0.10 + 0.05 * m),
      height: hl * (0.02 + 0.16 * m),
    );
    canvas.drawOval(
      mouth,
      Paint()
        ..color = mix(
          pal.skinDeep,
          const Color(0xFF1A0C10),
          0.55 + 0.3 * m,
        ).withValues(alpha: vis),
    );
  }

  /// 옆얼굴의 코·턱 실루엣.
  ///
  /// 측면에서 얼굴이 밋밋한 타원으로 남으면 사람 머리로 안 보인다. 실루엣
  /// 밖으로 나온 코 하나가 방향을 확정한다 — 정면에서는 0, 완전 측면에서 최대.
  void _profileFeatures(
    Canvas canvas,
    LightRig light,
    double hl,
    Facing f,
    double q,
  ) {
    final jut = f.profileJut;
    final back = f.showBack;
    // 후면에서는 코가 반대쪽(화면 뒤)이므로 그리지 않는다.
    if (back) return;

    final nose = smoothClosedPath([
      Offset(hl * 0.40, -hl * 0.10),
      Offset(hl * (0.40 + 0.16 * jut), -hl * 0.02),
      Offset(hl * (0.40 + 0.13 * jut), hl * 0.04),
      Offset(hl * 0.40, hl * 0.08),
    ], tension: 0.8);
    paintSurface(
      canvas,
      nose,
      Surface(pal.skin, Finish.skin),
      light,
      detail: q,
      rim: false,
    );

    // 턱 — 코보다 덜 나오되 같은 방향으로. 둘이 함께 옆얼굴을 만든다.
    final chin = smoothClosedPath([
      Offset(hl * 0.34, hl * 0.22),
      Offset(hl * (0.34 + 0.10 * jut), hl * 0.30),
      Offset(hl * 0.30, hl * 0.38),
      Offset(hl * 0.24, hl * 0.30),
    ], tension: 0.8);
    paintSurface(
      canvas,
      chin,
      Surface(pal.skin, Finish.skin),
      light,
      detail: q,
      rim: false,
    );
  }

  /// 뒷머리 — 얼굴보다 **먼저** 그린다.
  ///
  /// 뒤통수를 감싸는 볼륨과 늘어뜨린 길이를 맡는다. 두개골 뒤에 깔리므로
  /// 아무리 두꺼워도 이목구비를 가리지 않는다. 실루엣에서 머리 부피를 만드는
  /// 것이 이쪽이고, 앞머리([_hairFront])는 이마 위만 덮는 얇은 층이다.
  void _hairBack(
    Canvas canvas,
    LightRig light,
    IsoView iso,
    double hl,
    double q,
  ) {
    final s = spec;

    // 후드의 **뒤통수 부분**도 여기서 그린다. 얼굴보다 먼저 깔아야 두건이
    // 머리를 감싼 것으로 읽힌다 — 통째로 얼굴 위에 그리면 마법사가 파란 공을
    // 뒤집어쓴 것처럼 보인다.
    if (s.headGear == HeadGear.hood) {
      final cowl = blob(
        Offset(-hl * 0.18, -hl * 0.04),
        hl * 0.60,
        hl * 0.62,
        points: 16,
        warp: (a, t) =>
            1 + 0.18 * math.max(0.0, -math.cos(a)) + 0.08 * math.sin(a * 2),
      );
      paintSurface(
        canvas,
        cowl,
        Surface(pal.clothShade, Finish.cloth),
        light,
        detail: q,
        occlusion: 0.12,
        edgeRim: true,
      );
      paintTopPlane(canvas, cowl, light, iso, strength: 0.5);
    }

    // 완전히 덮는 투구를 쓰면 머리카락은 보이지 않는다. 반투구·서클릿·후드는
    // 뒤통수가 드러나므로 그린다.
    if (s.headGear == HeadGear.fullHelm || s.headGear == HeadGear.hornedHelm) {
      return;
    }

    // 늘어뜨린 길이. 0 이면 뒤통수까지, 1 이면 어깨를 지난다.
    final len = s.hairLength.clamp(0.0, 1.0);
    final drop = hl * (0.10 + 1.35 * len);

    final hair = tube(
      [
        // 정수리 앞쪽에서 시작해 뒤통수를 돌아 등으로 떨어진다.
        Offset(hl * 0.12, -hl * 0.44),
        Offset(-hl * 0.22, -hl * 0.42),
        Offset(-hl * 0.44, -hl * 0.02),
        Offset(-hl * 0.40, drop * 0.55),
        Offset(-hl * 0.34, drop),
      ],
      [
        hl * 0.30,
        hl * 0.40,
        hl * 0.38,
        hl * (0.30 - 0.10 * (1 - len)),
        hl * 0.12,
      ],
      samples: 24,
    );
    paintSurface(
      canvas,
      hair,
      Surface(pal.hair, Finish.hair),
      light,
      detail: q,
      occlusion: 0.18,
      edgeRim: true,
      seed: s.seed + 5,
    );
    paintTopPlane(canvas, hair, light, iso, strength: 0.4);
  }

  /// 앞머리 — 얼굴보다 **나중에** 그린다.
  ///
  /// 이마에서 관자놀이까지만 덮는다. 눈(y ≈ -0.05hl)보다 위에 머물러야 하므로
  /// 아래로 내려오는 끝점도 -0.10hl 을 넘지 않는다. 이 한 층이 있어야 머리가
  /// 두개골에 가발을 씌운 것처럼 보이지 않는다.
  void _hairFront(
    Canvas canvas,
    LightRig light,
    IsoView iso,
    double hl,
    double q,
  ) {
    final s = spec;
    if (s.headGear != HeadGear.none && s.headGear != HeadGear.circlet) return;

    final fringe = tube(
      [
        Offset(hl * 0.34, -hl * 0.20),
        Offset(hl * 0.16, -hl * 0.40),
        Offset(-hl * 0.16, -hl * 0.44),
      ],
      [hl * 0.10, hl * 0.20, hl * 0.26],
      samples: 16,
    );
    paintSurface(
      canvas,
      fringe,
      Surface(pal.hair, Finish.hair),
      light,
      detail: q,
      occlusion: 0.10,
      seed: s.seed + 6,
    );
    paintTopPlane(canvas, fringe, light, iso, strength: 0.46);
  }

  void _hairAndHelm(
    Canvas canvas,
    LightRig light,
    IsoView iso,
    double hl,
    double q,
    Facing f,
  ) {
    _hairFront(canvas, light, iso, hl, q);

    final s = spec;

    switch (s.headGear) {
      case HeadGear.none:
        break;
      case HeadGear.circlet:
        final band = tube(
          [
            Offset(hl * 0.36, -hl * 0.20),
            Offset(0, -hl * 0.40),
            Offset(-hl * 0.40, -hl * 0.18),
          ],
          [hl * 0.05, hl * 0.06, hl * 0.05],
          samples: 14,
        );
        paintSurface(
          canvas,
          band,
          Surface(pal.metalWarm, Finish.metal, contrast: 0.85 + 0.5 * (0.9)),
          light,
          detail: q,
        );
      case HeadGear.hood:
        // 두건의 **앞테두리**만. 뒤통수는 이미 [_hairBack] 이 깔아 두었고,
        // 여기서는 이마를 가로지르는 천만 얹어 얼굴을 남긴다. 후드의 인상은
        // 얼굴을 가리는 데서 오는 게 아니라 **얼굴에 드리운 그늘**에서 온다.
        final brim = tube(
          [
            Offset(hl * 0.36, -hl * 0.06),
            Offset(hl * 0.30, -hl * 0.34),
            Offset(-hl * 0.04, -hl * 0.52),
          ],
          [hl * 0.12, hl * 0.15, hl * 0.20],
          samples: 16,
        );
        paintSurface(
          canvas,
          brim,
          Surface(pal.cloth, Finish.cloth),
          light,
          detail: q,
          occlusion: 0.08,
        );
        paintTopPlane(canvas, brim, light, iso, strength: 0.5);

        // 두건 안쪽 그늘. 이목구비 위에 얹어 얼굴이 어둠 속에 있게 한다.
        canvas.drawPath(
          blob(Offset(hl * 0.10, -hl * 0.10), hl * 0.34, hl * 0.30),
          Paint()
            ..color = pal.clothShade.withValues(alpha: 0.42)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, hl * 0.10),
        );
      case HeadGear.halfHelm:
      case HeadGear.fullHelm:
      case HeadGear.hornedHelm:
        final full = s.headGear != HeadGear.halfHelm;
        final helm = blob(
          Offset(-hl * 0.04, full ? -hl * 0.02 : -hl * 0.16),
          hl * 0.50,
          full ? hl * 0.54 : hl * 0.38,
          points: 16,
          warp: (a, t) => 1 + 0.07 * math.sin(a * 2 + 0.6),
        );
        paintSurface(
          canvas,
          helm,
          _plate,
          light,
          detail: q,
          occlusion: 0.08,
          edgeRim: true,
        );
        paintTopPlane(canvas, helm, light, iso, strength: 0.66);
        if (s.trimAccent) {
          trimBand(canvas, helm, pal.accent, light, width: 1.5, alpha: 0.5);
        }

        // 바이저 슬릿. 얼굴을 가리는 투구는 이 틈 하나가 없으면 매끈한 금속
        // 알이고, 그 안에 사람이 있다는 증거가 사라진다. 틈 안쪽에서 눈빛이
        // 새어 나와야 시선의 방향까지 읽힌다.
        if (full && f.faceVisible > 0.02) {
          final vis = f.faceVisible;
          final slit = tube(
            [Offset(hl * 0.02, -hl * 0.08), Offset(hl * 0.40, -hl * 0.04)],
            [hl * 0.075, hl * 0.055],
            samples: 8,
          );
          canvas.drawPath(
            slit,
            Paint()
              ..color = const Color(0xFF0A0910).withValues(alpha: 0.88 * vis),
          );
          final spark = blob(
            Offset(hl * 0.26, -hl * 0.055),
            hl * 0.075,
            hl * 0.030,
          );
          paintSurface(
            canvas,
            spark,
            Surface(
              pal.eye,
              Finish.energy,
              glow: 1.0,
              glowColor: pal.glow,
              alpha: vis,
            ),
            light,
            detail: q,
          );
          glowPath(canvas, spark, pal.glow, hl * 0.16, alpha: 0.7 * vis);
        }
        if (s.headGear == HeadGear.hornedHelm) {
          for (final side in [1.0, -1.0]) {
            final horn = tube(
              [
                Offset(-hl * 0.10, -hl * 0.34),
                Offset(-hl * 0.30 * side - hl * 0.05, -hl * 0.62),
                Offset(-hl * 0.52 * side, -hl * 0.86),
              ],
              [hl * 0.13, hl * 0.09, hl * 0.02],
              samples: 14,
            );
            paintSurface(
              canvas,
              horn,
              Surface(pal.metal, Finish.bone),
              light,
              detail: q,
            );
            paintTopPlane(canvas, horn, light, iso, strength: 0.5);
          }
        }
    }
  }

  /// 망토. 베를레 시뮬 대신 포즈의 [Pose.capeFlow] 를 곡률에 직접 먹인다 —
  /// 뷰어는 임의의 클립을 즉시 갈아 끼우므로, 상태를 갖는 물리보다 포즈에서
  /// 결정되는 편이 전환이 깔끔하다.
  void _cape(
    Canvas canvas,
    Skeleton sk,
    LightRig light,
    IsoView iso,
    double q,
    double time,
  ) {
    if (!_wearsCape) return;
    final flow = sk.pose.capeFlow.clamp(0.0, 1.0);
    final len = _h * (0.30 + 0.30 * spec.capeLength);

    // 몸이 기울어도 "등 뒤"가 따라오도록, 척추 축을 90° 돌려 뒤 방향을 만든다.
    final up = (sk.chest - sk.pelvis).normalized();
    final backDir = Offset(up.dy, -up.dx);
    final top = sk.chest + Offset(0, _h * 0.012);

    final sway = wobble(time * 1.6, spec.seed * 0.7) * _h * 0.010;
    // 정지 상태에서는 중력으로 곧게 늘어지고, 흐름이 강할수록 뒤로 들린다.
    final tail =
        top +
        backDir * len * (0.22 + 0.86 * flow) +
        Offset(0, len * (0.88 - 0.74 * flow) + sway);
    final mid =
        top +
        backDir * len * (0.10 + 0.45 * flow) +
        Offset(0, len * (0.46 - 0.34 * flow) + sway * 0.5);

    // 폭은 어깨를 넘지 않는다. 망토가 어깨보다 넓어지면 실루엣에서 몸이
    // 사라지고 보라색 덩어리만 남는다.
    final cape = tube(
      [top, lerpO(top, mid, 0.45), mid, tail],
      [
        _shoulderW * 0.28,
        _shoulderW * 0.36,
        _shoulderW * (0.34 - 0.10 * flow),
        _shoulderW * (0.18 - 0.13 * flow),
      ],
      samples: 26,
      capEnd: false,
    );
    paintSurface(
      canvas,
      cape,
      Surface(pal.cloth, Finish.cloth),
      light,
      detail: q,
      occlusion: 0.26,
      edgeRim: true,
      seed: spec.seed + 11,
    );
    paintTopPlane(canvas, cape, light, iso, strength: 0.22);
    if (spec.trimAccent) {
      trimBand(canvas, cape, pal.accent, light, width: 1.2, alpha: 0.4);
    }
  }

  // ─────────────────────────────────────────────────────────── 무기

  void _weapon(
    Canvas canvas,
    Skeleton sk,
    LightRig light,
    IsoView iso,
    double q, {
    required bool ranged,
  }) {
    // 짐승형의 무기는 발톱과 이빨이다. 명세의 무기 항목은 무시한다.
    if (beast) return;

    final s = spec;
    final hand = sk.armNear;
    final grip = lerpO(hand.c, hand.d, 0.5);
    final dir = hand.angleCD;

    if (ranged) {
      _bow(canvas, sk, light, q);
      return;
    }

    // 장병기는 손목 각도를 그대로 따르지 않는다. 팔을 내린 순간 손 방향은
    // 아래를 가리키므로, 그대로 쓰면 창끝이 지면을 뚫는다. 평소에는 몸의
    // 수직축에 가깝게 세워 쥐고, 휘두르는 순간에만 손을 따라간다.
    final up = (sk.chest - sk.pelvis).normalized();
    final swing = sk.pose.weaponSwing.clamp(0.0, 1.0);
    final pole = lerpO(
      up,
      Offset(math.cos(dir), math.sin(dir)),
      0.20 + 0.62 * swing,
    ).normalized();

    // 도검류는 장병기만큼 세우지는 않는다 — 늘어뜨린 검이 자연스럽다. 다만
    // 손목 방향을 그대로 쓰면 신장의 절반짜리 칼날이 지면을 뚫으므로, 쉴
    // 때는 앞아래로 모으고 휘두를 때만 손을 따라간다.
    final handDir = Offset(math.cos(dir), math.sin(dir));
    final edge = lerpO(
      lerpO(up, handDir, 0.62).normalized(),
      handDir,
      swing,
    ).normalized();
    final edgeDir = edge.angle;

    switch (s.weapon) {
      case WeaponKind.none:
        return;
      case WeaponKind.bow:
        _bow(canvas, sk, light, q);
      case WeaponKind.staff:
        final len = _h * 0.72;
        final a = grip - pole * len * 0.34;
        final b = grip + pole * len * 0.66;
        final shaft = tube([a, b], [_h * 0.010, _h * 0.008], samples: 10);
        paintSurface(
          canvas,
          shaft,
          Surface(pal.leather, Finish.leather),
          light,
          detail: q,
        );
        final orb = blob(b, _h * 0.030, _h * 0.030);
        paintSurface(
          canvas,
          orb,
          Surface(pal.glow, Finish.gem, glow: 0.9, glowColor: pal.glow),
          light,
          detail: q,
        );
        glowPath(canvas, orb, pal.glow, _h * 0.09, alpha: 1.0);
      case WeaponKind.spear:
        final len = _h * 0.86;
        final a = grip - pole * len * 0.36;
        final b = grip + pole * len * 0.64;
        final shaft = tube([a, b], [_h * 0.009, _h * 0.008], samples: 10);
        paintSurface(
          canvas,
          shaft,
          Surface(pal.leather, Finish.leather),
          light,
          detail: q,
        );
        final tip = tube(
          [b - pole * _h * 0.06, b],
          [_h * 0.020, _h * 0.002],
          samples: 8,
        );
        paintSurface(
          canvas,
          tip,
          Surface(pal.metal, Finish.metal, contrast: 0.85 + 0.5 * (0.95)),
          light,
          detail: q,
        );
      case WeaponKind.axe:
        final len = _h * 0.42;
        final a = grip - edge * len * 0.28;
        final b = grip + edge * len * 0.72;
        final shaft = tube([a, b], [_h * 0.011, _h * 0.009], samples: 8);
        paintSurface(
          canvas,
          shaft,
          Surface(pal.leather, Finish.leather),
          light,
          detail: q,
        );
        final n = edge.perp;
        final head = smoothClosedPath([
          b + n * _h * 0.012,
          b + n * _h * 0.085 - edge * _h * 0.05,
          b + n * _h * 0.10 + edge * _h * 0.03,
          b - n * _h * 0.012,
        ]);
        paintSurface(
          canvas,
          head,
          Surface(pal.metal, Finish.metal, contrast: 0.85 + 0.5 * (0.9)),
          light,
          detail: q,
        );
        paintTopPlane(canvas, head, light, iso, strength: 0.5);
      case WeaponKind.daggers:
        _blade(canvas, grip, edgeDir, _h * 0.20, _h * 0.014, light, q);
      case WeaponKind.sword:
        _blade(canvas, grip, edgeDir, _h * 0.42, _h * 0.020, light, q);
      case WeaponKind.greatsword:
        _blade(canvas, grip, edgeDir, _h * 0.62, _h * 0.030, light, q);
    }
  }

  /// 방패. 먼 쪽 팔에 채운다.
  ///
  /// 명세에 `hasShield` 가 있는데도 오랫동안 그려지지 않아, 방패병으로 선언한
  /// 캐릭터가 맨손으로 걸어 다녔다.
  ///
  /// 방패는 손에 매달리는 물건이 아니라 **팔뚝에 고정**된다. 그래서 손목
  /// 각도를 따르지 않고 몸의 수직축에 세운다 — 팔을 흔들어도 방패면이
  /// 팔랑거리지 않아야 무게가 실린다.
  void _shield(
    Canvas canvas,
    Skeleton sk,
    LightRig light,
    IsoView iso,
    double q,
  ) {
    final arm = sk.armFar;
    final up = (sk.chest - sk.pelvis).normalized();
    final grip = lerpO(arm.c, arm.d, 0.4);

    // 아이소에서는 방패면이 화면 정면을 향할 때 가장 크게 읽힌다. 몸 바깥으로
    // 살짝 밀어 몸통에 완전히 가려지지 않게 한다.
    final outward = (arm.b - sk.chest).normalized();
    final r = _h * 0.105 * (0.9 + 0.35 * spec.armorHeaviness);
    final center = grip + outward * r * 0.32 - up * r * 0.18;

    final face = blob(
      center,
      r * 0.86,
      r,
      points: 18,
      rotation: up.perp.angle,
      // 아래로 살짝 뾰족한 연 방패. 완전한 원보다 방향이 읽힌다.
      warp: (a, t) => 1 + 0.10 * math.sin(a) - 0.06 * math.cos(a * 2),
    );
    paintSurface(
      canvas,
      face,
      _plate,
      light,
      detail: q,
      occlusion: 0.16,
      edgeRim: true,
    );
    paintTopPlane(canvas, face, light, iso, strength: 0.42);
    trimBand(canvas, face, pal.accent, light, width: 2.0, alpha: 0.6);

    // 보스(중앙 돌기). 평평한 판에 하이라이트 하나가 더 생겨 금속으로 읽힌다.
    final boss = blob(center, r * 0.24, r * 0.26);
    paintSurface(
      canvas,
      boss,
      Surface(pal.metalWarm, Finish.metal, contrast: 1.15),
      light,
      detail: q,
    );
  }

  void _blade(
    Canvas canvas,
    Offset grip,
    double dir,
    double len,
    double halfWidth,
    LightRig light,
    double q,
  ) {
    final s = spec;
    final f = Offset(math.cos(dir), math.sin(dir));
    final n = f.perp;
    final base = grip + f * len * 0.14;
    final tip = grip + f * len;

    // 자루와 폼멜.
    final hilt = tube(
      [grip - f * len * 0.20, base],
      [halfWidth * 0.55, halfWidth * 0.5],
      samples: 8,
    );
    paintSurface(
      canvas,
      hilt,
      Surface(pal.leather, Finish.leather),
      light,
      detail: q,
    );
    final guard = tube(
      [base - n * halfWidth * 2.6, base + n * halfWidth * 2.6],
      [halfWidth * 0.45, halfWidth * 0.45],
      samples: 8,
    );
    paintSurface(
      canvas,
      guard,
      Surface(pal.metalWarm, Finish.metal, contrast: 0.85 + 0.5 * (0.85)),
      light,
      detail: q,
    );

    // 검신. 끝으로 갈수록 좁아지는 각진 실루엣이 금속의 밴딩을 살린다.
    final blade = smoothClosedPath([
      base + n * halfWidth,
      lerpO(base, tip, 0.55) + n * halfWidth * 0.9,
      tip + n * halfWidth * 0.12,
      tip - n * halfWidth * 0.12,
      lerpO(base, tip, 0.55) - n * halfWidth * 0.9,
      base - n * halfWidth,
    ], tension: 0.4);
    paintSurface(
      canvas,
      blade,
      Surface(pal.metal, Finish.metal, contrast: 0.85 + 0.5 * (0.97)),
      light,
      detail: q,
      occlusion: 0.02,
    );
    if (s.glowRunes) {
      glowPath(canvas, blade, pal.glow, halfWidth * 3, alpha: 0.5);
    }
  }

  void _bow(Canvas canvas, Skeleton sk, LightRig light, double q) {
    // 활은 지지하는 손(먼 쪽 팔)에 들리고, 시위는 당기는 손으로 이어진다.
    final hold = lerpO(sk.armFar.c, sk.armFar.d, 0.5);
    final draw = lerpO(sk.armNear.c, sk.armNear.d, 0.5);
    final len = _h * 0.52;
    final up = (sk.headTop - sk.pelvis).normalized();
    final away = (hold - draw).normalized();

    final limbTop = hold + up * len * 0.5 + away * len * 0.10;
    final limbBottom = hold - up * len * 0.5 + away * len * 0.10;
    final bow = tube(
      [limbTop, hold + away * len * 0.06, limbBottom],
      [_h * 0.004, _h * 0.010, _h * 0.004],
      samples: 20,
    );
    paintSurface(
      canvas,
      bow,
      Surface(pal.leather, Finish.leather),
      light,
      detail: q,
    );

    // 시위. 당긴 손까지 삼각형으로 이어져 장력이 보인다.
    canvas.drawPath(
      Path()
        ..moveTo(limbTop.dx, limbTop.dy)
        ..lineTo(draw.dx, draw.dy)
        ..lineTo(limbBottom.dx, limbBottom.dy),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, _h * 0.004)
        ..color = mix(
          pal.leather,
          const Color(0xFFFFFFFF),
          0.5,
        ).withValues(alpha: 0.85),
    );

    // 화살.
    final arrowDir = (limbTop + limbBottom) * 0.5 - draw;
    if (arrowDir.distance > 1) {
      final d = arrowDir.normalized();
      canvas.drawLine(
        draw,
        draw + d * len * 0.8,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.0, _h * 0.006)
          ..color = pal.leather,
      );
    }
  }

  // ─────────────────────────────────────────────────────────── 이펙트

  void _fx(Canvas canvas, Skeleton sk, LightRig light, double time) {
    final p = sk.pose;

    // 무기 궤적. 임팩트 순간에만 짧게 남아 속도를 읽히게 한다.
    if (p.weaponSwing > 0.02) {
      final hand = sk.armNear;
      final grip = lerpO(hand.c, hand.d, 0.5);
      final reach = _h * 0.5;
      final dir = hand.angleCD;
      final path = Path();
      const steps = 14;
      for (var i = 0; i <= steps; i++) {
        final a = dir + (i / steps - 1) * 1.5;
        final pt = grip + Offset(math.cos(a), math.sin(a)) * reach;
        if (i == 0) {
          path.moveTo(pt.dx, pt.dy);
        } else {
          path.lineTo(pt.dx, pt.dy);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _h * 0.030 * p.weaponSwing
          ..strokeCap = StrokeCap.round
          ..blendMode = BlendMode.plus
          ..color = mix(
            pal.glow,
            const Color(0xFFFFFFFF),
            0.55,
          ).withValues(alpha: (0.5 * p.weaponSwing).clamp(0.0, 1.0))
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, _h * 0.02),
      );
    }

    // 피격 섬광. 실루엣 전체를 순간적으로 태워 타격감을 만든다.
    if (p.impact > 0.02) {
      final b = sk.bounds;
      canvas.drawRect(
        b,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = RadialGradient(
            colors: [
              const Color(
                0xFFFF6A4A,
              ).withValues(alpha: (0.34 * p.impact).clamp(0.0, 1.0)),
              const Color(0x00000000),
            ],
          ).createShader(b),
      );
    }
  }
}
