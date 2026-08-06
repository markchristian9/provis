import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/painting.dart' show RadialGradient;

import '../core/noise.dart';
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
  })  : body = body ?? bodyOfSpec(spec),
        pal = palette ?? spec.palette,
        _noise = Noise(spec.seed);

  final HumanoidSpec spec;

  /// 골격 치수. 짐승형은 명세를 그대로 두고 이것만 갈아 끼워, 같은 장비
  /// 규칙과 같은 애니메이션 클립이 전혀 다른 실루엣으로 재생되게 한다.
  final Body body;
  final Palette pal;

  /// 짐승형 여부. 뿔·꼬리·발톱처럼 인간형에 없는 파츠를 켠다.
  final bool beast;

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
  Surface get _limbArmor => beast
      ? Surface(pal.skin, Finish.skin)
      : spec.armorHeaviness > 0.52
          ? Surface(pal.metal, Finish.metal, contrast: 0.85 + 0.5 * (0.5 + 0.42 * spec.armorHeaviness))
          : spec.armorHeaviness > 0.26
              ? Surface(pal.leather, Finish.leather)
              : Surface(pal.cloth, Finish.cloth);

  Surface get _plate => beast
      ? Surface(pal.metal, Finish.chitin)
      : Surface(pal.metal, Finish.metal, contrast: 0.85 + 0.5 * (0.55 + 0.4 * spec.armorHeaviness));

  Surface get _torsoSurface => beast
      ? Surface(pal.skin, Finish.skin)
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
    // 정면을 볼수록 사지의 앞뒤 스윙은 화면에서 단축된다. 포즈를 줄일 뿐
    // 치수는 건드리지 않으므로 IK 길이는 그대로다.
    final p = _foreshorten(pose, 0.34 + 0.66 * facing.profile);
    final b = body.scaledWidth(facing.shoulderScale);

    var sk = solve(b, p);
    final low = _lowestFoot(sk);
    if (low > 0.5) {
      sk = solve(b, p.copyWith(rootY: p.rootY - low / b.height));
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

    final mirror = facing.nearSide < 0;
    if (mirror) canvas.scale(-1, 1);
    // 캔버스를 뒤집으면 광원도 따라 뒤집히므로, 리그의 x 성분을 되돌려
    // 조명이 월드에 고정되게 한다.
    final lit = mirror
        ? light.mirrored
        : light;

    final dz = _depthOff * facing.depthSpread;
    final front = facing.toCamera;

    // ③ 뒤에서 앞으로. 후면에서는 망토가 몸을 덮는다.
    if (beast) _tail(canvas, sk, lit, detail, time);

    canvas.save();
    canvas.translate(-dz, 0);
    _leg(canvas, sk.legFar, lit, iso, detail, depth: 1);
    _arm(canvas, sk.armFar, lit, iso, detail, depth: 1, holdsBow: ranged);
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
      [r * 1.12, r * 1.18, r * 0.80, r * 0.62, r * 0.52],
      samples: 24,
    );
    paintSurface(canvas, leg, _limbArmor, light,
        detail: q, occlusion: occ, seed: spec.seed + depth.round());

    // 발. 아이소에서는 발등이 보이므로 상단면 하이라이트를 얹는다.
    final toeDir = (l.d - l.c);
    final boot = tube(
      [l.c - Offset(0, r * 0.1), lerpO(l.c, l.d, 0.55), l.d],
      [r * 0.62, r * 0.58, r * 0.30],
      samples: 12,
    );
    paintSurface(canvas, boot, Surface(pal.leather, Finish.leather), light,
        detail: q, occlusion: occ + 0.2);
    if (depth == 0) paintTopPlane(canvas, boot, light, iso, strength: 0.45);

    // 무릎 방어구. 판금 계열에서만.
    if (!beast && spec.armorHeaviness > 0.5) {
      final knee = blob(l.b, r * 0.86, r * 0.72, rotation: toeDir.angle);
      paintSurface(canvas, knee, _plate, light,
          detail: q, occlusion: occ);
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
    paintSurface(canvas, arm, _limbArmor, light,
        detail: q, occlusion: occ, seed: spec.seed + 7 + depth.round());

    // 손.
    final hand = blob(
      lerpO(l.c, l.d, 0.45),
      r * 0.78,
      r * 0.66,
      rotation: (l.d - l.c).angle,
    );
    paintSurface(canvas, hand, Surface(pal.skin, Finish.skin), light,
        detail: q, occlusion: occ + 0.1);

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
        paintSurface(canvas, claw, Surface(pal.metal, Finish.bone), light,
            detail: q, occlusion: occ);
      }
    }

    // 어깨보호대. 아이소 뷰에서 실루엣의 상단을 지배하는 파츠이므로
    // 상단면 하이라이트를 반드시 준다.
    if (!beast && spec.hasPauldrons) {
      final ps = r * 2.05 * spec.pauldronScale;
      final pauldron = blob(
        l.a - Offset(0, ps * 0.18),
        ps * 0.92,
        ps * 0.74,
        points: 16,
        rotation: -0.15,
        warp: (a, t) => 1 + 0.12 * math.sin(a * 3 + spec.seed),
      );
      paintSurface(canvas, pauldron, _plate, light,
          detail: q, occlusion: occ * 0.6);
      paintTopPlane(canvas, pauldron, light, iso, strength: depth == 0 ? 0.62 : 0.3);
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
    paintSurface(canvas, torso, _torsoSurface, light,
        detail: q,
        occlusion: 0.14,
        seed: spec.seed);
    paintTopPlane(canvas, torso, light, iso, strength: 0.3);

    // 등가시. 짐승형의 실루엣 상단을 지배하는 파츠라 아이소에서 가장 먼저
    // 읽힌다.
    if (beast) {
      for (var i = 0; i < 5; i++) {
        // 등 위쪽에 몰아준다. 골반까지 깔면 다리와 겹쳐 실루엣이 뭉갠다.
        final t = 0.30 + i * 0.16;
        final at = lerpO(sk.pelvis, sk.chest, t);
        final back = (sk.pelvis - sk.chest).normalized().perp;
        final size = _chestW * (0.14 + 0.18 * math.sin(t * math.pi));
        final spike = tube(
          [at, at + back * size * 1.25 - Offset(0, size * 0.8)],
          [size * 0.30, size * 0.02],
          samples: 8,
        );
        paintSurface(canvas, spike, Surface(pal.metal, Finish.bone), light,
            detail: q, occlusion: 0.2);
        paintTopPlane(canvas, spike, light, iso, strength: 0.45);
      }
    }

    // 흉갑. 몸통 위에 한 겹 더 얹어야 판금이 "덧대어진" 것으로 읽힌다.
    if (_wearsArmor) {
      final chest = tube(
        [lerpO(sk.waist, sk.chest, 0.25), lerpO(sk.waist, sk.chest, 0.75), sk.chest],
        [_waistW * 0.44 * w, _chestW * 0.50 * w * breath, _chestW * 0.42 * w],
        samples: 16,
      );
      paintSurface(canvas, chest, _plate, light,
          detail: q, occlusion: 0.10);
      paintTopPlane(canvas, chest, light, iso, strength: 0.42);
      if (spec.trimAccent) {
        trimBand(canvas, chest, pal.accent, light, width: 1.6, alpha: 0.6);
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
      paintSurface(canvas, belt, Surface(pal.leather, Finish.leather), light,
          detail: q, occlusion: 0.2);
    }

    if (spec.glowRunes || beast) {
      final rune = blob(lerpO(sk.waist, sk.chest, 0.62), _h * 0.017, _h * 0.017);
      paintSurface(canvas, rune, Surface(pal.glow, Finish.gem, glow: 0.9, glowColor: pal.glow), light,
          detail: q);
      glowPath(canvas, rune, pal.glow, _h * 0.05, alpha: 0.8);
    }
  }

  /// 꼬리. 몸통 뒤에서 나와 관성으로 늦게 따라온다 — 포즈의 흔들림을
  /// 그대로 쓰지 않고 시간 지연을 주어야 살아 있는 부속으로 읽힌다.
  void _tail(Canvas canvas, Skeleton sk, LightRig light, double q, double time) {
    final len = _h * 0.52;
    final back = (sk.pelvis - sk.chest).normalized().perp;
    final root = sk.pelvis + back * _hipW * 0.30;
    final drift = wobble(time * 2.1, spec.seed * 0.31);
    final lift = sk.pose.capeFlow * 0.6 + 0.2;

    final tail = tube(
      [
        root,
        root + back * len * 0.36 + Offset(0, len * (0.10 - lift * 0.18)),
        root + back * len * 0.72 + Offset(0, len * (0.22 - lift * 0.34) + drift * len * 0.10),
        root + back * len * 1.02 + Offset(0, len * (0.30 - lift * 0.50) + drift * len * 0.20),
      ],
      [_hipW * 0.30, _hipW * 0.22, _hipW * 0.13, _hipW * 0.03],
      samples: 24,
    );
    paintSurface(canvas, tail, Surface(pal.skin, Finish.skin), light,
        detail: q, occlusion: 0.34, seed: spec.seed + 21);
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
    paintSurface(canvas, neck, beast ? Surface(pal.skin, Finish.skin) : Surface(pal.skin, Finish.skin),
        light,
        detail: q, occlusion: 0.45);

    // 머리부터는 머리 로컬 좌표에서 그린다. 원점이 머리 중심, +x 가 전방,
    // -y 가 정수리 방향이므로 이목구비를 정면 기준으로 배치할 수 있다.
    final rot = sk.headAngle + math.pi / 2;
    canvas.save();
    canvas.translate(sk.headCenter.dx, sk.headCenter.dy);
    canvas.rotate(rot);
    final hLight = light.rotated(-rot);

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
    paintSurface(canvas, skull, beast ? Surface(pal.skin, Finish.skin) : Surface(pal.skin, Finish.skin),
        hLight,
        detail: q, occlusion: 0.12, seed: spec.seed + 3);
    paintTopPlane(canvas, skull, hLight, iso, strength: 0.34);

    // 짐승형의 아래턱. 벌린 입이 실루엣 밖으로 나가야 포효가 읽힌다.
    if (beast) {
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
      paintSurface(canvas, jaw, Surface(pal.skinDeep, Finish.skin), hLight,
          detail: q, occlusion: 0.3);
      // 이빨.
      for (var i = 0; i < 4; i++) {
        final t = 0.24 + i * 0.16;
        final at = Offset(hl * (0.02 + t * 0.55), hl * (0.20 + 0.28 * open));
        final fang = tube(
          [at, at - Offset(0, hl * 0.11)],
          [hl * 0.030, hl * 0.004],
          samples: 6,
        );
        paintSurface(canvas, fang, Surface(pal.metal, Finish.bone), hLight,
            detail: q);
      }
    }

    if (f.toCamera) {
      _face(canvas, hLight, hl, sk.pose, f, q);
    }

    if (beast) {
      _horns(canvas, hLight, iso, hl, q);
    } else {
      _hairAndHelm(canvas, hLight, iso, hl, q, f);
    }

    canvas.restore();
  }

  /// 뿔. 아이소에서는 머리 위가 실루엣의 왕좌이므로, 종을 알리는 정보를
  /// 여기에 몰아준다.
  void _horns(Canvas canvas, LightRig light, IsoView iso, double hl, double q) {
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
      paintSurface(canvas, horn, Surface(pal.metal, Finish.bone), light,
          detail: q, occlusion: 0.12, seed: spec.seed + 31);
      paintTopPlane(canvas, horn, light, iso, strength: 0.55);
    }
  }

  /// 이목구비. 아이소에서 머리는 작으므로 눈만 확실히 읽히면 된다 —
  /// 눈 사이 간격을 페이싱으로 좁혀 3/4 각도를 만든다.
  void _face(Canvas canvas, LightRig light, double hl, Pose pose, Facing f, double q) {
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

    // 가까운 눈은 얼굴 앞쪽, 먼 눈은 페이싱이 정면일수록 뒤로 벌어진다.
    final gap = hl * 0.26 * (1 - f.profile);
    for (final ex in [hl * 0.30, hl * 0.30 - gap]) {
      if (ex < hl * 0.30 - 1e-3 && gap < hl * 0.04) break;
      final eye = blob(Offset(ex, -hl * 0.05), hl * 0.075, hl * 0.055 * open);
      paintSurface(canvas, eye, Surface(pal.eye, Finish.gem, glow: 0.9, glowColor: pal.glow), light,
          detail: q);
      canvas.drawCircle(
        Offset(ex + hl * 0.012, -hl * 0.05),
        hl * 0.026 * open,
        Paint()..color = const Color(0xFF120E14).withValues(alpha: 0.85),
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
        ..color = pal.skinDeep.withValues(alpha: 0.5)
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
      Paint()..color = mix(pal.skinDeep, const Color(0xFF1A0C10), 0.55 + 0.3 * m),
    );
  }

  void _hairAndHelm(
    Canvas canvas,
    LightRig light,
    IsoView iso,
    double hl,
    double q,
    Facing f,
  ) {
    final s = spec;

    if (s.headGear == HeadGear.none || s.headGear == HeadGear.circlet) {
      final len = 0.35 + s.hairLength * 1.5;
      final hair = tube(
        [
          Offset(hl * 0.26, -hl * 0.30),
          Offset(-hl * 0.10, -hl * 0.52),
          Offset(-hl * 0.44, -hl * 0.22),
          Offset(-hl * 0.50, hl * 0.30 * len),
        ],
        [hl * 0.16, hl * 0.40, hl * 0.36, hl * 0.14],
        samples: 20,
      );
      paintSurface(canvas, hair, Surface(pal.hair, Finish.hair), light,
          detail: q, occlusion: 0.15, seed: s.seed + 5);
      paintTopPlane(canvas, hair, light, iso, strength: 0.4);
    }

    switch (s.headGear) {
      case HeadGear.none:
        break;
      case HeadGear.circlet:
        final band = tube(
          [Offset(hl * 0.36, -hl * 0.20), Offset(0, -hl * 0.40), Offset(-hl * 0.40, -hl * 0.18)],
          [hl * 0.05, hl * 0.06, hl * 0.05],
          samples: 14,
        );
        paintSurface(canvas, band, Surface(pal.metalWarm, Finish.metal, contrast: 0.85 + 0.5 * (0.9)), light,
            detail: q);
      case HeadGear.hood:
        final hood = blob(
          Offset(-hl * 0.10, -hl * 0.06),
          hl * 0.58,
          hl * 0.60,
          points: 16,
          warp: (a, t) => 1 + 0.16 * math.max(0.0, -math.cos(a)) + 0.08 * math.sin(a * 2),
        );
        paintSurface(canvas, hood, Surface(pal.clothShade, Finish.cloth), light,
            detail: q, occlusion: 0.1);
        paintTopPlane(canvas, hood, light, iso, strength: 0.5);
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
        paintSurface(canvas, helm, _plate, light,
            detail: q, occlusion: 0.08);
        paintTopPlane(canvas, helm, light, iso, strength: 0.66);
        if (s.trimAccent) {
          trimBand(canvas, helm, pal.accent, light, width: 1.5, alpha: 0.5);
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
            paintSurface(canvas, horn, Surface(pal.metal, Finish.bone), light,
                detail: q);
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
    final tail = top +
        backDir * len * (0.22 + 0.86 * flow) +
        Offset(0, len * (0.88 - 0.74 * flow) + sway);
    final mid = top +
        backDir * len * (0.10 + 0.45 * flow) +
        Offset(0, len * (0.46 - 0.34 * flow) + sway * 0.5);

    // 폭은 어깨를 넘지 않는다. 망토가 어깨보다 넓어지면 실루엣에서 몸이
    // 사라지고 보라색 덩어리만 남는다.
    final cape = tube(
      [
        top,
        lerpO(top, mid, 0.45),
        mid,
        tail,
      ],
      [
        _shoulderW * 0.28,
        _shoulderW * 0.36,
        _shoulderW * (0.34 - 0.10 * flow),
        _shoulderW * (0.18 - 0.13 * flow),
      ],
      samples: 26,
      capEnd: false,
    );
    paintSurface(canvas, cape, Surface(pal.cloth, Finish.cloth), light,
        detail: q, occlusion: 0.26, seed: spec.seed + 11);
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
    final pole = lerpO(up, Offset(math.cos(dir), math.sin(dir)), 0.20 + 0.62 * swing)
        .normalized();

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
        paintSurface(canvas, shaft, Surface(pal.leather, Finish.leather), light,
            detail: q);
        final orb = blob(b, _h * 0.030, _h * 0.030);
        paintSurface(canvas, orb, Surface(pal.glow, Finish.gem, glow: 0.9, glowColor: pal.glow), light,
            detail: q);
        glowPath(canvas, orb, pal.glow, _h * 0.09, alpha: 1.0);
      case WeaponKind.spear:
        final len = _h * 0.86;
        final a = grip - pole * len * 0.36;
        final b = grip + pole * len * 0.64;
        final shaft = tube([a, b], [_h * 0.009, _h * 0.008], samples: 10);
        paintSurface(canvas, shaft, Surface(pal.leather, Finish.leather), light,
            detail: q);
        final tip = tube(
          [b - pole * _h * 0.06, b],
          [_h * 0.020, _h * 0.002],
          samples: 8,
        );
        paintSurface(canvas, tip, Surface(pal.metal, Finish.metal, contrast: 0.85 + 0.5 * (0.95)), light,
            detail: q);
      case WeaponKind.axe:
        final len = _h * 0.42;
        final a = grip - Offset(math.cos(dir), math.sin(dir)) * len * 0.28;
        final b = grip + Offset(math.cos(dir), math.sin(dir)) * len * 0.72;
        final shaft = tube([a, b], [_h * 0.011, _h * 0.009], samples: 8);
        paintSurface(canvas, shaft, Surface(pal.leather, Finish.leather), light,
            detail: q);
        final n = Offset(math.cos(dir), math.sin(dir)).perp;
        final head = smoothClosedPath([
          b + n * _h * 0.012,
          b + n * _h * 0.085 - Offset(math.cos(dir), math.sin(dir)) * _h * 0.05,
          b + n * _h * 0.10 + Offset(math.cos(dir), math.sin(dir)) * _h * 0.03,
          b - n * _h * 0.012,
        ]);
        paintSurface(canvas, head, Surface(pal.metal, Finish.metal, contrast: 0.85 + 0.5 * (0.9)), light,
            detail: q);
        paintTopPlane(canvas, head, light, iso, strength: 0.5);
      case WeaponKind.daggers:
        _blade(canvas, grip, dir, _h * 0.20, _h * 0.014, light, q);
      case WeaponKind.sword:
        _blade(canvas, grip, dir, _h * 0.44, _h * 0.020, light, q);
      case WeaponKind.greatsword:
        _blade(canvas, grip, dir, _h * 0.66, _h * 0.030, light, q);
    }
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
    final hilt = tube([grip - f * len * 0.20, base], [halfWidth * 0.55, halfWidth * 0.5], samples: 8);
    paintSurface(canvas, hilt, Surface(pal.leather, Finish.leather), light,
        detail: q);
    final guard = tube(
      [base - n * halfWidth * 2.6, base + n * halfWidth * 2.6],
      [halfWidth * 0.45, halfWidth * 0.45],
      samples: 8,
    );
    paintSurface(canvas, guard, Surface(pal.metalWarm, Finish.metal, contrast: 0.85 + 0.5 * (0.85)), light,
        detail: q);

    // 검신. 끝으로 갈수록 좁아지는 각진 실루엣이 금속의 밴딩을 살린다.
    final blade = smoothClosedPath([
      base + n * halfWidth,
      lerpO(base, tip, 0.55) + n * halfWidth * 0.9,
      tip + n * halfWidth * 0.12,
      tip - n * halfWidth * 0.12,
      lerpO(base, tip, 0.55) - n * halfWidth * 0.9,
      base - n * halfWidth,
    ], tension: 0.4);
    paintSurface(canvas, blade, Surface(pal.metal, Finish.metal, contrast: 0.85 + 0.5 * (0.97)), light,
        detail: q, occlusion: 0.02);
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
    paintSurface(canvas, bow, Surface(pal.leather, Finish.leather), light,
        detail: q);

    // 시위. 당긴 손까지 삼각형으로 이어져 장력이 보인다.
    canvas.drawPath(
      Path()
        ..moveTo(limbTop.dx, limbTop.dy)
        ..lineTo(draw.dx, draw.dy)
        ..lineTo(limbBottom.dx, limbBottom.dy),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, _h * 0.004)
        ..color = mix(pal.leather, const Color(0xFFFFFFFF), 0.5).withValues(alpha: 0.85),
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
          ..color = mix(pal.glow, const Color(0xFFFFFFFF), 0.55)
              .withValues(alpha: (0.5 * p.weaponSwing).clamp(0.0, 1.0))
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
              const Color(0xFFFF6A4A).withValues(alpha: (0.34 * p.impact).clamp(0.0, 1.0)),
              const Color(0x00000000),
            ],
          ).createShader(b),
      );
    }
  }
}
