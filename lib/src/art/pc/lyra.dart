import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../../core/noise.dart';
import '../../core/palette.dart';
import '../../core/shading.dart';
import '../../core/spline.dart';
import '../anatomy.dart';
import '../creature.dart';

/// 리라 — 가시덤불의 파수꾼.
///
/// 다른 셋과 달리 이 캐릭터는 정지 포즈가 아니라 "멈춘 동작"이다. 시위를
/// 끝까지 당긴 순간에는 몸 전체가 활과 함께 하나의 긴장된 곡선을 이루는데,
/// 그 곡선을 실루엣의 중심축으로 삼았다. 활대와 시위가 만드는 삼각형이
/// 화면의 절반을 차지하도록 배치해, 인물보다 먼저 자세가 읽히게 했다.
class Lyra extends Artist {
  @override
  String get id => 'lyra';
  @override
  String get name => 'Lyra';
  @override
  String get title => 'Warden of the Bramblewilds';
  @override
  String get blurb => '숨결 하나로 시위를 놓는 야생의 파수꾼.';
  @override
  Camp get camp => Camp.player;
  @override
  bool get facesLeft => true;
  @override
  Rect get framing => const Rect.fromLTWH(150, 90, 790, 1270);
  @override
  Sex get sex => Sex.female;
  @override
  Color get accent => const Color(0xFF8FE05A);
  @override
  LightRig get light => const LightRig(
        dir: Offset(-0.66, -0.75),
        rimDir: Offset(0.78, -0.62),
        key: Color(0xFFFFF2CE),
        fill: Color(0xFF4E7A5A),
        rim: Color(0xFFC8F49A),
        bounce: Color(0xFF6B7A44),
        ambient: Color(0xFF1C2A22),
      );
  @override
  List<Color> get moodSky => const [
        Color(0xFF101B16),
        Color(0xFF25402C),
        Color(0xFF5E6B33),
      ];

  static const _leaf = Color(0xFF4A5F38);
  static const _leather = Color(0xFF6B4A2C);
  static const _leatherDark = Color(0xFF44301D);
  static const _fur = Color(0xFF9A8B6E);
  static const _cloak = Color(0xFF2F4A3A);
  static const _shirt = Color(0xFFBCAE8E);
  static const _hair = Color(0xFFA8452A);
  static const _skin = Color(0xFFE4BA94);
  static const _wood = Color(0xFF7A5230);
  static const _wild = Color(0xFF8FE05A);

  Surface get _sLeaf => const Surface(_leaf, Finish.leather, contrast: 1.05);
  Surface get _sLeather => const Surface(_leather, Finish.leather);
  Surface get _sLeatherDark =>
      const Surface(_leatherDark, Finish.leather, contrast: 1.15);
  Surface get _sFur => const Surface(_fur, Finish.fur, contrast: 0.95);
  Surface get _sCloak => const Surface(_cloak, Finish.cloth, contrast: 1.1);
  Surface get _sShirt => const Surface(_shirt, Finish.cloth, contrast: 0.95);
  Surface get _sSkin => const Surface(_skin, Finish.skin, contrast: 0.9);
  Surface get _sHair => const Surface(_hair, Finish.hair, contrast: 1.1);
  Surface get _sWood => const Surface(_wood, Finish.wood, contrast: 1.05);

  Ramp get _rLeather => Ramp.of(_leather);
  Ramp get _rSkin => Ramp.of(_skin, contrast: 0.9);
  Ramp get _rHair => Ramp.of(_hair, contrast: 1.1);
  Ramp get _rCloak => Ramp.of(_cloak, contrast: 1.1);

  // 시위를 당긴 순간의 미세한 떨림. 활 전체가 이 값 하나로 살아난다.
  double _strain(double t) => math.sin(t * 9.3) * 1.4 + math.sin(t * 5.1) * 0.9;

  @override
  void paint(Canvas c, double t, {double detail = 1.0}) {
    final l = light;
    final tremor = _strain(t);
    final bob = breathe(t, speed: 1.15, amp: 1.8);

    groundShadow(c, const Offset(534, 1326), 260, 40, alpha: 0.6);

    _cloak_(c, t, l, detail);
    _quiver(c, l, detail);
    _legBack(c, l, detail);
    _bow(c, l, tremor, detail);
    _legFront(c, l, detail);
    _torso(c, l, bob, detail);
    _armBow(c, l, bob, tremor, detail);
    _braidBack(c, t, l, detail);
    _head(c, l, t, bob, detail);
    _armDraw(c, l, bob, tremor, detail);
    _arrow(c, l, tremor);

    if (detail > 0.4) {
      _leaves(c, t);
    }
  }

  // 바람에 감기는 잎사귀. 이 캐릭터가 어디에 속했는지를 말한다.
  void _leaves(Canvas c, double t) {
    final n = Noise(63);
    for (var i = 0; i < 16; i++) {
      final ph = n.at1(i * 4.7) * 6.28;
      final k = (t * 0.22 + n.at1(i * 2.3)) % 1.0;
      final r = 180 + n.at1(i * 8.1) * 220;
      final a = ph + k * 3.4;
      final p = Offset(
        520 + math.cos(a) * r,
        1320 - k * 900 + math.sin(a * 1.7) * 60,
      );
      final s = 9 + n.at1(i * 5.5) * 7;
      final fade = math.sin(k * math.pi).clamp(0.0, 1.0);
      c.save();
      c.translate(p.dx, p.dy);
      c.rotate(a * 2.1);
      final leaf = smoothClosedPath([
        Offset(-s, 0),
        Offset(0, -s * 0.5),
        Offset(s, 0),
        Offset(0, s * 0.5),
      ]);
      c.drawPath(
        leaf,
        Paint()..color = _wild.darken(0.25).fade(0.55 * fade),
      );
      c.drawPath(
        leaf,
        Paint()
          ..blendMode = BlendMode.plus
          ..color = _wild.fade(0.22 * fade),
      );
      c.restore();
    }
  }

  void _cloak_(Canvas c, double t, LightRig l, double detail) {
    final w = jitter(t, 4.4, amp: 1.2);
    final cape = smoothClosedPath([
      const Offset(470, 500),
      Offset(596, 486),
      Offset(700 + w * 3, 620),
      Offset(742 + w * 5, 860),
      Offset(716 + w * 6, 1080),
      Offset(660 + w * 4, 1210),
      const Offset(560, 1170),
      const Offset(512, 980),
      const Offset(496, 720),
    ], tension: 0.85);
    castShadow(c, cape, offset: const Offset(10, 14), blur: 22, alpha: 0.45);
    paintSurface(c, cape, _sCloak, l, detail: detail, seed: 501);

    c.save();
    c.clipPath(cape);
    for (var i = 0; i < 6; i++) {
      final u = i / 5;
      c.drawPath(
        smoothOpenPath([
          Offset(lerpD(500, 620, u), 500),
          Offset(lerpD(540, 716, u) + math.sin(u * 6 + t) * 10, 860),
          Offset(lerpD(556, 700, u), 1190),
        ]),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 22 - (u - 0.5).abs() * 14
          ..color = _rCloak.deep.fade(0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15),
      );
    }
    c.restore();
    rimBand(c, cape, l, width: 5, alpha: 0.5, color: const Color(0xFFC8F49A));
  }

  // 등에 멘 화살통. 깃털 다발이 어깨 위로 삐져나온다.
  void _quiver(Canvas c, LightRig l, double detail) {
    final body = tube(
      const [Offset(660, 454), Offset(700, 602), Offset(720, 744)],
      const [40, 44, 38],
      samples: 16,
    );
    paintSurface(c, body, _sLeatherDark, l, detail: detail, seed: 503);
    c.save();
    c.clipPath(body);
    for (var i = 0; i < 3; i++) {
      final y = 500.0 + i * 84;
      panelLine(
        c,
        smoothOpenPath([Offset(618 + i * 12.0, y), Offset(726 + i * 6.0, y + 14)]),
        _rLeather,
        l,
        width: 8,
      );
    }
    c.restore();

    // 화살대와 깃.
    for (var i = 0; i < 5; i++) {
      final x = 628 + i * 13.0;
      final y = 452 - i * 6.0;
      c.drawLine(
        Offset(x, y),
        Offset(x + 14, y - 86),
        Paint()
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..color = _wood.darken(0.2),
      );
      final feather = smoothClosedPath([
        Offset(x + 14, y - 86),
        Offset(x + 26, y - 68),
        Offset(x + 20, y - 40),
        Offset(x + 8, y - 52),
      ]);
      c.drawPath(
        feather,
        Paint()..color = (i.isEven ? const Color(0xFFCE6A45) : const Color(0xFFE4D6B8)),
      );
      c.drawPath(
        feather,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = const Color(0xFF3A2A1E).fade(0.6),
      );
    }
    rimBand(c, body, l, width: 4, alpha: 0.45);
  }

  void _legBack(Canvas c, LightRig l, double detail) => _leg(
        c,
        l,
        detail,
        hip: const Offset(572, 800),
        knee: const Offset(640, 1058),
        ankle: const Offset(676, 1282),
        toe: 1,
        dim: true,
      );

  void _legFront(Canvas c, LightRig l, double detail) => _leg(
        c,
        l,
        detail,
        hip: const Offset(478, 806),
        knee: const Offset(422, 1064),
        ankle: const Offset(398, 1288),
        toe: -1,
        dim: false,
      );

  void _leg(
    Canvas c,
    LightRig l,
    double detail, {
    required Offset hip,
    required Offset knee,
    required Offset ankle,
    required double toe,
    required bool dim,
  }) {
    final tone = dim ? 0.7 : 1.0;
    final thigh = limb(hip, lerpO(hip, knee, 0.5), knee,
        r0: 50, r1: 40, r2: 30, swell: 1.14);
    paintSurface(c, thigh, _sLeatherDark.tinted(const Color(0xFF000000), 1 - tone),
        l, detail: detail, seed: 511);

    final shin = limb(knee, lerpO(knee, ankle, 0.5), ankle,
        r0: 30, r1: 25, r2: 18, swell: 1.1);
    paintSurface(c, shin, _sLeatherDark.tinted(const Color(0xFF14100A), 0.2 + (1 - tone) * 0.3),
        l, detail: detail, seed: 513);

    // 무릎까지 오는 가죽 부츠와 감아 올린 끈.
    final bootTop = lerpO(knee, ankle, 0.06);
    final boot = tube(
      [bootTop, lerpO(bootTop, ankle, 0.55), ankle + const Offset(0, 8)],
      const [30, 26, 21],
      samples: 14,
    );
    paintSurface(c, boot, _sLeather, l, detail: detail, seed: 515);
    final foot = bootShape(ankle + const Offset(0, 26), toe, 72, heel: 0.4);
    paintSurface(c, foot, _sLeather, l, detail: detail, seed: 517);

    c.save();
    c.clipPath(boot);
    final d = (ankle - bootTop).normalized();
    final n = d.perp;
    for (var i = 0; i < 5; i++) {
      final p = lerpO(bootTop, ankle, i / 4 * 0.9 + 0.05);
      c.drawLine(
        p - n * 34 - d * 6,
        p + n * 34 + d * 6,
        Paint()
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFF2E2014).fade(0.75),
      );
    }
    c.restore();
    rimBand(c, boot, l, width: 3, alpha: 0.4);
  }

  void _torso(Canvas c, LightRig l, double bob, double detail) {
    final chest = Offset(560, 542 + bob);
    const pelvis = Offset(536, 802);

    // 안에 받쳐 입은 리넨 셔츠.
    final shirt = torsoShape(
      chest: chest + const Offset(0, -10),
      pelvis: pelvis + const Offset(0, 10),
      shoulderW: 104,
      chestW: 98,
      waistW: 72,
      hipW: 98,
      neckW: 28,
      bust: 12,
    );
    paintSurface(c, shirt, _sShirt, l, detail: detail, seed: 521);

    // 가죽 코르셋. 몸통의 잘록함을 만드는 주 파츠.
    final corset = torsoShape(
      chest: chest + const Offset(0, 34),
      pelvis: pelvis + const Offset(0, -14),
      shoulderW: 92,
      chestW: 90,
      waistW: 66,
      hipW: 88,
      neckW: 40,
      bust: 10,
    );
    paintSurface(c, corset, _sLeaf, l, detail: detail, seed: 523);

    c.save();
    c.clipPath(corset);
    // 코르셋 끈. 가운데 X 자 교차가 이 옷의 정체성이다.
    for (var i = 0; i < 6; i++) {
      final y = chest.dy + 62 + i * 26.0;
      final wHalf = 40 - (i - 2.5).abs() * 3;
      c.drawLine(
        Offset(chest.dx - wHalf, y),
        Offset(chest.dx + wHalf, y + 16),
        Paint()
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFF2A1E12).fade(0.8),
      );
      c.drawLine(
        Offset(chest.dx + wHalf, y),
        Offset(chest.dx - wHalf, y + 16),
        Paint()
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFF3A2A18).fade(0.8),
      );
    }
    panelLine(
      c,
      smoothOpenPath([
        chest + const Offset(-84, 30),
        chest + const Offset(-64, 130),
        chest + const Offset(-58, 210),
      ]),
      Ramp.of(_leaf),
      l,
      width: 6,
    );
    panelLine(
      c,
      smoothOpenPath([
        chest + const Offset(82, 26),
        chest + const Offset(62, 130),
        chest + const Offset(56, 208),
      ]),
      Ramp.of(_leaf),
      l,
      width: 6,
    );
    c.restore();

    // 허리 벨트와 주머니.
    final belt = tube(
      [pelvis + const Offset(-86, -30), pelvis + const Offset(0, -18), pelvis + const Offset(86, -26)],
      const [16, 18, 16],
      samples: 12,
    );
    paintSurface(c, belt, _sLeather, l, detail: detail, seed: 525);
    final pouch = blob(pelvis + const Offset(-72, 20), 30, 32,
        warp: (a, u) => 1 + math.sin(a * 3) * 0.08);
    paintSurface(c, pouch, _sLeatherDark, l, detail: detail, seed: 527);

    // 모피 숄더. 활을 잡은 쪽 어깨만 크게 덮어 비대칭을 만든다.
    final furMass = smoothClosedPath([
      const Offset(444, 488),
      const Offset(514, 462),
      const Offset(594, 472),
      const Offset(638, 514),
      const Offset(610, 568),
      const Offset(514, 578),
      const Offset(438, 554),
      const Offset(412, 514),
    ], tension: 0.8);
    paintSurface(c, furMass, _sFur, l, detail: detail, seed: 529);
    if (detail > 0.4) {
      // 모피 가장자리의 삐죽삐죽한 털. 실루엣이 부드러우면 모피로 안 읽힌다.
      final n = Noise(91);
      for (var i = 0; i < 26; i++) {
        final u = i / 25;
        final a = math.pi * (0.15 + u * 1.2);
        final base = Offset(514 + math.cos(a + math.pi) * 112,
            518 + math.sin(a + math.pi) * 56);
        final len = 14 + n.at1(i * 3.3) * 16;
        final dir = (base - const Offset(514, 518)).normalized();
        c.drawLine(
          base,
          base + dir * len + Offset(0, n.signed1(i * 2.1) * 5),
          Paint()
            ..strokeWidth = 4.5
            ..strokeCap = StrokeCap.round
            ..color = (i.isEven ? Ramp.of(_fur).light : Ramp.of(_fur).shadow)
                .fade(0.8),
        );
      }
    }
    rimBand(c, furMass, l, width: 6, alpha: 0.6, color: const Color(0xFFE8F5B0));
    rimBand(c, corset, l, width: 5, alpha: 0.5, color: const Color(0xFFC8F49A));
  }

  // 활을 쥔 왼팔. 어깨부터 손목까지 일직선으로 뻗어 시위의 장력을 받는다.
  void _armBow(
      Canvas c, LightRig l, double bob, double tremor, double detail) {
    final shoulder = Offset(468, 550 + bob);
    final elbow = Offset(376, 506 + bob * 0.6 + tremor * 0.3);
    final wrist = Offset(292, 470 + bob * 0.4 + tremor * 0.6);

    final upper = tube(
      [shoulder, lerpO(shoulder, elbow, 0.5), elbow],
      const [40, 34, 27],
      samples: 16,
    );
    paintSurface(c, upper, _sShirt, l, detail: detail, seed: 531);

    final fore = limb(elbow, lerpO(elbow, wrist, 0.5), wrist,
        r0: 26, r1: 22, r2: 17, swell: 1.08);
    paintSurface(c, fore, _sSkin, l, detail: detail, seed: 533);

    // 팔뚝 보호대. 시위가 스치는 자리라 반드시 있어야 하는 장비.
    final bracer = tube(
      [lerpO(elbow, wrist, 0.30), lerpO(elbow, wrist, 0.92)],
      const [25, 20],
      samples: 12,
    );
    paintSurface(c, bracer, _sLeather, l, detail: detail, seed: 535);
    c.save();
    c.clipPath(bracer);
    final d = (wrist - elbow).normalized();
    final n = d.perp;
    for (var i = 0; i < 4; i++) {
      final p = lerpO(elbow, wrist, 0.36 + i * 0.16);
      c.drawLine(p - n * 26, p + n * 26,
          Paint()..strokeWidth = 4..color = _rLeather.deep.fade(0.7));
    }
    c.restore();

    final hand = handShape(wrist, math.pi, 46, grip: 1.0);
    paintSurface(c, hand, _sSkin, l, detail: detail, seed: 537);
    c.save();
    c.clipPath(hand);
    drawKnuckles(c, wrist, math.pi, 46, _rSkin, l);
    c.restore();
    rimBand(c, fore, l, width: 4, alpha: 0.55, color: const Color(0xFFD8F7A8));
  }

  // 시위를 당긴 오른팔. 팔꿈치가 뒤로 높이 들려야 장력이 읽힌다.
  void _armDraw(
      Canvas c, LightRig l, double bob, double tremor, double detail) {
    final shoulder = Offset(640, 548 + bob);
    final elbow = Offset(754, 500 + bob * 0.7 + tremor * 0.4);
    final wrist = Offset(606, 446 + bob * 0.5 + tremor);

    final upper = tube(
      [shoulder, lerpO(shoulder, elbow, 0.5), elbow],
      const [40, 35, 28],
      samples: 16,
    );
    paintSurface(c, upper, _sShirt, l, detail: detail, seed: 541);

    final fore = limb(elbow, lerpO(elbow, wrist, 0.5), wrist,
        r0: 27, r1: 23, r2: 18, swell: 1.1);
    paintSurface(c, fore, _sSkin, l, detail: detail, seed: 543);
    c.save();
    c.clipPath(fore);
    drawMuscleLine(
      c,
      [lerpO(elbow, wrist, 0.2), lerpO(elbow, wrist, 0.55), lerpO(elbow, wrist, 0.85)],
      _rSkin,
      width: 9,
      alpha: 0.3,
    );
    c.restore();

    final hand = handShape(wrist, math.pi * 0.92, 44, grip: 1.0, mirrored: true);
    paintSurface(c, hand, _sSkin, l, detail: detail, seed: 545);
    rimBand(c, hand, l, width: 3.5, alpha: 0.6, color: const Color(0xFFD8F7A8));
    rimBand(c, upper, l, width: 5, alpha: 0.5, color: const Color(0xFFC8F49A));
  }

  /// 활. 리커브 형태의 활대와 팽팽한 시위.
  void _bow(Canvas c, LightRig l, double tremor, double detail) {
    final nock = Offset(602, 444 + tremor);
    const upperTip = Offset(268, 132);
    const lowerTip = Offset(268, 812);
    const grip = Offset(274, 468);

    // 활대: 손잡이에서 양 끝으로 갈수록 뒤로 젖혀지는 곡선.
    final limbUp = tube(
      const [grip, Offset(232, 330), Offset(238, 210), upperTip],
      const [17, 14, 11, 6],
      samples: 26,
    );
    final limbDown = tube(
      const [grip, Offset(230, 606), Offset(238, 726), lowerTip],
      const [17, 14, 11, 6],
      samples: 26,
    );
    for (final p in [limbUp, limbDown]) {
      castShadow(c, p, offset: const Offset(8, 10), blur: 14, alpha: 0.4);
      paintSurface(c, p, _sWood, l, detail: detail, seed: 551);
      rimBand(c, p, l, width: 3, alpha: 0.5, color: const Color(0xFFE6D08A));
    }

    // 활대에 감긴 금속 밴드와 룬.
    for (final y in const [258.0, 690.0]) {
      final band = Path()
        ..addRRect(RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(236, y), width: 34, height: 22),
          const Radius.circular(6),
        ));
      paintSurface(c, band, const Surface(Color(0xFF9AA36F), Finish.metal),
          l, detail: detail, seed: 553);
      glowAt(c, Offset(236, y), 22, _wild, intensity: 0.35);
    }

    // 손잡이 가죽.
    final gripWrap = tube(
      const [Offset(276, 424), Offset(274, 512)],
      const [21, 21],
      samples: 10,
    );
    paintSurface(c, gripWrap, _sLeatherDark, l, detail: detail, seed: 555);
    c.save();
    c.clipPath(gripWrap);
    for (var y = 428.0; y < 512; y += 11) {
      c.drawLine(Offset(250, y), Offset(300, y + 6),
          Paint()..strokeWidth = 3..color = const Color(0xFF1E1409).fade(0.65));
    }
    c.restore();

    // 시위. 장력을 받아 노킹 포인트에서 꺾인다.
    final string = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.4
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFEDE2C4).fade(0.92);
    c.drawLine(upperTip, nock, string);
    c.drawLine(lowerTip, nock, string);
    c.drawLine(
      upperTip,
      nock,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..blendMode = BlendMode.plus
        ..color = const Color(0xFFFFF8DC).fade(0.6),
    );
    c.drawLine(
      lowerTip,
      nock,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..blendMode = BlendMode.plus
        ..color = const Color(0xFFFFF8DC).fade(0.6),
    );
  }

  /// 시위에 걸린 화살. 촉 끝에 자연 마력이 맺힌다.
  void _arrow(Canvas c, LightRig l, double tremor) {
    final nock = Offset(600, 446 + tremor);
    const tip = Offset(196, 476);
    final shaft = tube(
      [nock, lerpO(nock, tip, 0.5), tip],
      const [5.5, 5.5, 4.5],
      samples: 14,
    );
    paintSurface(c, shaft, _sWood, l, detail: 0.3, ao: false, seed: 561);

    // 촉.
    final head = Path()
      ..moveTo(tip.dx - 46, tip.dy + 1)
      ..lineTo(tip.dx + 16, tip.dy - 13)
      ..lineTo(tip.dx + 22, tip.dy + 1)
      ..lineTo(tip.dx + 16, tip.dy + 15)
      ..close();
    paintSurface(c, head,
        const Surface(Color(0xFFAEB8C6), Finish.metal, contrast: 1.4), l);
    glowAt(c, Offset(tip.dx - 30, tip.dy), 34, _wild, intensity: 0.55, star: true);

    // 깃.
    for (var i = 0; i < 3; i++) {
      final off = (i - 1) * 9.0;
      final base = nock + Offset(-34, off * 0.5);
      c.drawPath(
        smoothClosedPath([
          base,
          base + Offset(-30, -12 + off * 0.4),
          base + Offset(-54, -6 + off * 0.3),
          base + Offset(-40, 8 + off * 0.3),
        ]),
        Paint()..color = (i == 1 ? const Color(0xFFCE6A45) : const Color(0xFFE4D6B8))
            .fade(0.95),
      );
    }
  }

  void _braidBack(Canvas c, double t, LightRig l, double detail) {
    // 뒤로 넘어간 굵은 땋은 머리. 마디마다 좌우로 부풀려 꼬임을 만든다.
    final spine = clothSpine(
      const Offset(600, 368),
      const Offset(0.62, 0.78),
      420,
      t,
      sway: 0.16,
      phase: 1.3,
      segments: 6,
      gravity: 0.42,
      flutter: 0.5,
    );
    final braid = tube(spine, const [40, 38, 33, 27, 19, 8], samples: 24);
    paintSurface(c, braid, _sHair, l, detail: detail, seed: 571);

    if (detail > 0.4) {
      c.save();
      c.clipPath(braid);
      final poly = smoothPolyline(spine, 40);
      for (var i = 2; i < poly.length - 2; i += 3) {
        final p = poly[i];
        final d = (poly[i + 1] - poly[i - 1]).normalized();
        final n = d.perp;
        final u = i / poly.length;
        final r = 42 * (1 - u * 0.8);
        c.drawPath(
          smoothOpenPath([p - n * r - d * r * 0.5, p + n * r + d * r * 0.5]),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 7
            ..color = _rHair.deep.fade(0.5)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
        c.drawPath(
          smoothOpenPath([p - n * r * 0.6 - d * r * 0.2, p + n * r * 0.6 + d * r * 0.2]),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4
            ..color = _rHair.light.fade(0.35)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
        );
      }
      c.restore();
    }
    // 끝을 묶은 가죽 끈.
    final tail = smoothPolyline(spine, 40).last;
    c.drawCircle(tail + const Offset(-6, -10), 11,
        Paint()..color = _leatherDark.lighten(0.1));
    rimBand(c, braid, l, width: 5, alpha: 0.55, color: const Color(0xFFFFD9A0));
  }

  void _head(Canvas c, LightRig l, double t, double bob, double detail) {
    final hc = Offset(566, 350 + bob * 1.1);
    const hw = 64.0;
    const hh = 84.0;

    final neck = tube(
      [hc + const Offset(6, 56), hc + const Offset(14, 124)],
      const [25, 32],
      samples: 10,
    );
    paintSurface(c, neck, _sSkin, l, detail: detail, seed: 581);
    occlude(c, neck, const Offset(0, -1), depth: 0.5, alpha: 0.55);

    drawJawShadow(c, hc + const Offset(6, 92), hw * 1.5, hh * 0.48, _rSkin,
        alpha: 0.5);

    final head = headShape(hc, hw, hh,
        jaw: 0.62, chin: 0.24, turn: -0.55, cheek: 0.94);
    paintSurface(c, head, _sSkin, l, detail: detail, seed: 583);

    c.save();
    c.clipPath(head);
    drawMuscleLine(
      c,
      [hc + const Offset(-52, 8), hc + const Offset(-32, 42), hc + const Offset(-10, 56)],
      _rSkin,
      width: 13,
      alpha: 0.26,
    );
    // 주근깨. 이 캐릭터를 야외에 살게 하는 한 줌의 디테일.
    if (detail > 0.5) {
      final n = Noise(37);
      for (var i = 0; i < 22; i++) {
        final p = hc +
            Offset((n.at1(i * 3.1) - 0.5) * 110, (n.at1(i * 7.7) - 0.35) * 60 + 18);
        c.drawCircle(
          p,
          1.6 + n.at1(i * 5.3) * 1.4,
          Paint()..color = const Color(0xFF9A5A38).fade(0.4),
        );
      }
    }
    c.restore();

    // 시위를 당긴 순간이라 눈이 가늘게 좁혀져 있다.
    final eyeY = hc.dy;
    drawEye(c, Offset(hc.dx - 38, eyeY), 25, 13,
        iris: const Color(0xFF77C24A),
        light: l,
        open: 0.72,
        look: -0.55,
        tilt: 0.08);
    drawEye(c, Offset(hc.dx + 26, eyeY + 3), 22, 11.5,
        iris: const Color(0xFF77C24A),
        light: l,
        open: 0.70,
        look: -0.55,
        tilt: -0.04,
        mirrored: true);
    drawBrow(c, Offset(hc.dx - 40, eyeY - 26), 28, 4.4,
        const Color(0xFF6E3320), arch: 0.16, angle: 0.2);
    drawBrow(c, Offset(hc.dx + 28, eyeY - 24), 24, 4.0,
        const Color(0xFF6E3320), arch: 0.16, angle: -0.16, mirrored: true);

    drawNose(c, Offset(hc.dx - 6, eyeY + 8), 19, 32, _rSkin, l, turn: -0.5);
    drawMouth(c, Offset(hc.dx - 8, hc.dy + 54), 20,
        skin: _rSkin, lip: const Color(0xFFC0675E), smile: -0.05, turn: -0.5);

    final ear = earShape(Offset(hc.dx + 62, eyeY + 10), 13, 21, point: 0.2);
    paintSurface(c, ear, _sSkin, l, detail: detail, rim: false, seed: 585);

    // 앞머리와 옆으로 흘러내린 잔머리.
    final fringe = smoothClosedPath([
      hc + const Offset(-70, 0),
      hc + const Offset(-76, -54),
      hc + const Offset(-36, -92),
      hc + const Offset(20, -98),
      hc + const Offset(64, -76),
      hc + const Offset(74, -20),
      hc + const Offset(66, 40),
      hc + const Offset(44, -14),
      hc + const Offset(0, -40),
      hc + const Offset(-34, -22),
      hc + const Offset(-58, -44),
    ], tension: 0.88);
    paintSurface(c, fringe, _sHair, l, detail: detail, seed: 587);
    if (detail > 0.4) {
      for (var i = 0; i < 5; i++) {
        final u = i / 4;
        final strand = hairStrand(
          hc + Offset(lerpD(-66, 60, u), lerpD(-34, -40, math.sin(u * math.pi))),
          Offset(lerpD(-0.7, 0.5, u), 0.72),
          70 + math.sin(u * math.pi) * 40,
          8,
          t,
          phase: i * 1.7,
          curl: 0.5,
          flutter: 0.45,
        );
        paintSurface(c, strand, _sHair, l, detail: 0, rim: false, ao: false);
      }
    }

    // 머리에 두른 가죽 끈과 깃털 장식.
    c.drawPath(
      smoothOpenPath([
        hc + const Offset(-72, -16),
        hc + const Offset(-20, -46),
        hc + const Offset(44, -36),
        hc + const Offset(72, -6),
      ]),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..color = _leatherDark.lighten(0.12),
    );
    final plume = smoothClosedPath([
      hc + const Offset(66, -12),
      hc + const Offset(96, -58),
      hc + const Offset(112, -104),
      hc + const Offset(98, -66),
      hc + const Offset(84, -18),
    ]);
    c.drawPath(plume, Paint()..color = const Color(0xFF6E8F4A));
    c.drawPath(
      plume,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFF3A4A22).fade(0.8),
    );

    rimBand(c, fringe, l, width: 5, alpha: 0.7, color: const Color(0xFFFFD9A0));
    rimBand(c, head, l, width: 4, alpha: 0.5, color: const Color(0xFFFFE0B0));
  }
}
