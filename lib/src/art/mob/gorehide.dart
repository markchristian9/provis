import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../../core/noise.dart';
import '../../core/palette.dart';
import '../../core/shading.dart';
import '../../core/spline.dart';
import '../anatomy.dart';
import '../creature.dart';

/// 고어하이드 — 살덩이 파쇄자.
///
/// 거구를 크게만 그리면 뚱뚱한 사람이 된다. 위압감은 비율의 왜곡에서 온다.
/// 여기서는 머리를 인간의 2/3 크기로 줄이고 어깨 폭을 머리의 다섯 배로 늘려
/// "머리가 몸에 파묻힌" 실루엣을 만들었다. 관절은 전부 인간보다 낮게 두어
/// 팔이 무릎까지 늘어지게 했다.
class Gorehide extends Artist {
  @override
  String get id => 'gorehide';
  @override
  String get name => 'Gorehide';
  @override
  String get title => 'The Rendering Brute';
  @override
  String get blurb => '사슬에 감긴 팔로 성문을 부수는 고산의 식인귀.';
  @override
  Camp get camp => Camp.monster;
  @override
  Rect get framing => const Rect.fromLTWH(90, 130, 880, 1240);
  @override
  Sex? get sex => null;
  @override
  Color get accent => const Color(0xFF8FA36B);
  @override
  LightRig get light => const LightRig(
        dir: Offset(-0.62, -0.78),
        rimDir: Offset(0.84, -0.44),
        key: Color(0xFFFFE9C0),
        fill: Color(0xFF4A5C48),
        rim: Color(0xFFFFB871),
        bounce: Color(0xFF7A5A3A),
        ambient: Color(0xFF221E18),
      );
  @override
  List<Color> get moodSky => const [
        Color(0xFF181510),
        Color(0xFF3A2E20),
        Color(0xFF6B4A26),
      ];

  static const _hide = Color(0xFF6E7C54);
  static const _hideDark = Color(0xFF485238);
  static const _belly = Color(0xFF8B9668);
  static const _bone = Color(0xFFD6C9A4);
  static const _iron = Color(0xFF6E6A64);
  static const _rawhide = Color(0xFF4C3624);
  static const _wood = Color(0xFF5A4230);
  static const _wound = Color(0xFF9A3A32);

  Surface get _sHide => const Surface(_hide, Finish.skin,
      contrast: 1.32, sss: Color(0xFF8A5E38));
  Surface get _sHideDark => const Surface(_hideDark, Finish.skin,
      contrast: 1.38, sss: Color(0xFF63452A));
  Surface get _sBelly => const Surface(_belly, Finish.skin,
      contrast: 1.15, sss: Color(0xFFA07A52));
  Surface get _sBone => const Surface(_bone, Finish.bone, contrast: 1.1);
  Surface get _sIron => const Surface(_iron, Finish.metal, contrast: 1.25);
  Surface get _sRawhide => const Surface(_rawhide, Finish.leather);
  Surface get _sWood => const Surface(_wood, Finish.wood, contrast: 1.1);

  Ramp get _rHide => Ramp.of(_hide, contrast: 1.32);
  Ramp get _rBone => Ramp.of(_bone, contrast: 1.1);
  Ramp get _rIron => Ramp.of(_iron, contrast: 1.25);

  @override
  void paint(Canvas c, double t, {double detail = 1.0}) {
    final l = light;
    // 거구는 호흡이 느리고 진폭이 크다. 이 차이만으로 무게가 달라 보인다.
    final bob = breathe(t, speed: 0.55, amp: 7.0);
    final heave = breathe(t, speed: 0.55, amp: 5.0, phase: 0.7);

    groundShadow(c, const Offset(516, 1322), 350, 54, alpha: 0.72);

    _armBack(c, l, bob, detail);
    _legBack(c, l, detail);
    _legFront(c, l, detail);
    _torso(c, l, bob, heave, detail);
    _head(c, l, t, bob, detail);
    _armFront(c, l, t, bob, detail);

    if (detail > 0.5) {
      _flies(c, t);
    }
  }

  // 시체 냄새를 따라온 파리 떼. 캐릭터의 성격을 한 번에 설명한다.
  void _flies(Canvas c, double t) {
    final n = Noise(53);
    for (var i = 0; i < 11; i++) {
      final sp = 0.8 + n.at1(i * 3.3) * 1.4;
      final rx = 60 + n.at1(i * 7.1) * 180;
      final cx = 380 + n.at1(i * 2.9) * 300;
      final cy = 520 + n.at1(i * 5.7) * 420;
      final a = t * sp + i * 2.1;
      final p = Offset(
        cx + math.cos(a) * rx,
        cy + math.sin(a * 1.7) * rx * 0.35,
      );
      c.drawCircle(p, 3.2, Paint()..color = const Color(0xFF101008).fade(0.75));
    }
  }

  void _legBack(Canvas c, LightRig l, double detail) => _leg(
        c,
        l,
        detail,
        hip: const Offset(618, 962),
        knee: const Offset(700, 1130),
        ankle: const Offset(676, 1262),
        toe: 1,
        surf: _sHideDark,
      );

  void _legFront(Canvas c, LightRig l, double detail) => _leg(
        c,
        l,
        detail,
        hip: const Offset(402, 968),
        knee: const Offset(330, 1132),
        ankle: const Offset(360, 1258),
        toe: -1,
        surf: _sHide,
      );

  void _leg(
    Canvas c,
    LightRig l,
    double detail, {
    required Offset hip,
    required Offset knee,
    required Offset ankle,
    required double toe,
    required Surface surf,
  }) {
    // 짧고 굵은 다리. 무릎이 낮아 웅크린 인상을 준다.
    final thigh = limb(hip, lerpO(hip, knee, 0.5), knee,
        r0: 96, r1: 78, r2: 62, swell: 1.1);
    paintSurface(c, thigh, surf, l, detail: detail, seed: 601);

    final shin = limb(knee, lerpO(knee, ankle, 0.5), ankle,
        r0: 62, r1: 56, r2: 52, swell: 1.06);
    paintSurface(c, shin, surf, l, detail: detail, seed: 603);

    // 발: 세 개의 굵은 발가락과 누런 발톱.
    final foot = smoothClosedPath([
      ankle + Offset(-toe * 58, -30),
      ankle + Offset(toe * 62, -26),
      ankle + Offset(toe * 96, 34),
      ankle + Offset(toe * 90, 66),
      ankle + Offset(-toe * 70, 66),
      ankle + Offset(-toe * 84, 20),
    ], tension: 0.8);
    paintSurface(c, foot, surf, l, detail: detail, seed: 605);
    for (var i = 0; i < 3; i++) {
      final u = i / 2;
      final p = ankle + Offset(toe * (24 + u * 62), 48 - u * 6);
      final claw = smoothClosedPath([
        p + Offset(-toe * 16, -14),
        p + Offset(toe * 20, -6),
        p + Offset(toe * 34, 20),
        p + Offset(toe * 6, 18),
        p + Offset(-toe * 14, 12),
      ]);
      paintSurface(c, claw, _sBone, l, detail: detail, seed: 607 + i);
    }
    // 발가락 사이 골.
    c.save();
    c.clipPath(foot);
    for (var i = 0; i < 2; i++) {
      final x = ankle.dx + toe * (34 + i * 34);
      panelLine(
        c,
        smoothOpenPath([Offset(x, ankle.dy + 6), Offset(x + toe * 8, ankle.dy + 62)]),
        _rHide,
        l,
        width: 9,
      );
    }
    c.restore();
    rimBand(c, shin, l, width: 6, alpha: 0.5);
  }

  void _torso(Canvas c, LightRig l, double bob, double heave, double detail) {
    final chest = Offset(506, 690 + bob * 0.4);
    const pelvis = Offset(516, 968);

    // 어깨에서 골반까지 역삼각이 아니라 통짜 원통. 허리가 없다.
    final body = torsoShape(
      chest: chest,
      pelvis: pelvis,
      shoulderW: 214,
      chestW: 206 + heave * 0.6,
      waistW: 188 + heave,
      hipW: 158,
      neckW: 74,
    );
    paintSurface(c, body, _sHide, l, detail: detail, seed: 611);

    // 등의 혹. 실루엣 위쪽을 부풀려 굽은 등을 만든다.
    final hump = blob(const Offset(596, 636), 140, 104,
        rotation: -0.3, warp: (a, u) => 1 + math.cos(a * 2) * 0.10);
    paintSurface(c, hump, _sHideDark, l, detail: detail, seed: 613);
    occlude(c, hump, const Offset(-0.6, 0.8), depth: 0.5, alpha: 0.55);

    c.save();
    c.clipPath(body);

    // 배: 밝고 늘어진 살. 몸통 아래쪽에 별도 톤을 깔아 지방층을 만든다.
    final gut = blob(
      Offset(470, 862 + heave * 0.5),
      166,
      126 + heave * 0.5,
      warp: (a, u) => 1 + math.sin(a * 3 + 1) * 0.06,
    );
    paintSurface(c, gut, _sBelly, l, detail: detail, rim: false, seed: 615);
    // 살의 접힘. 세 겹이면 충분히 무겁게 보인다.
    for (var i = 0; i < 3; i++) {
      final y = 820.0 + i * 44 + heave * 0.4;
      drawMuscleLine(
        c,
        [
          Offset(340, y + 14),
          Offset(430, y + 30 + i * 4),
          Offset(540, y + 22),
          Offset(614, y - 4),
        ],
        _rHide,
        width: 22,
        alpha: 0.42,
        lift: const Offset(-4, -9),
      );
    }
    // 가슴 근육.
    drawMuscleLine(
      c,
      [chest + const Offset(-150, -6), chest + const Offset(-70, 74), chest + const Offset(4, 86)],
      _rHide,
      width: 24,
      alpha: 0.45,
    );
    drawMuscleLine(
      c,
      [chest + const Offset(152, 2), chest + const Offset(76, 78), chest + const Offset(6, 88)],
      _rHide,
      width: 24,
      alpha: 0.4,
    );

    // 흉터. 방향이 제각각이어야 싸움의 이력처럼 보인다.
    if (detail > 0.45) {
      const scars = [
        [Offset(392, 700), Offset(470, 780), Offset(516, 892)],
        [Offset(556, 726), Offset(618, 782), Offset(640, 858)],
        [Offset(368, 852), Offset(430, 900)],
      ];
      for (final s in scars) {
        final p = smoothOpenPath(s);
        c.drawPath(
          p,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 9
            ..strokeCap = StrokeCap.round
            ..color = _wound.darken(0.35).fade(0.5),
        );
        c.drawPath(
          p.shift(const Offset(-3, -4)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4
            ..strokeCap = StrokeCap.round
            ..color = _wound.lighten(0.25).fade(0.55),
        );
      }
      // 사마귀와 굳은살.
      final n = Noise(83);
      for (var i = 0; i < 26; i++) {
        final p = Offset(
          330 + n.at1(i * 3.7) * 360,
          660 + n.at1(i * 8.3) * 300,
        );
        final r = 4 + n.at1(i * 5.1) * 9;
        c.drawCircle(p, r, Paint()..color = _rHide.deep.fade(0.35));
        c.drawCircle(p + Offset(-r * 0.3, -r * 0.35), r * 0.6,
            Paint()..color = _rHide.light.fade(0.3));
      }
    }
    c.restore();

    // 찢어진 가죽 하의.
    final loin = smoothClosedPath([
      const Offset(372, 936),
      const Offset(520, 916),
      const Offset(662, 940),
      const Offset(676, 1052),
      const Offset(608, 1016),
      const Offset(556, 1092),
      const Offset(500, 1020),
      const Offset(438, 1080),
      const Offset(390, 1008),
    ], tension: 0.75);
    paintSurface(c, loin, _sRawhide, l, detail: detail, seed: 617);
    c.save();
    c.clipPath(loin);
    for (var i = 0; i < 5; i++) {
      c.drawPath(
        smoothOpenPath([
          Offset(390 + i * 62.0, 924),
          Offset(400 + i * 62.0, 1080),
        ]),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 12
          ..color = Ramp.of(_rawhide).deep.fade(0.45)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }
    c.restore();

    // 허리에 두른 쇠사슬과 매달린 전리품 뼈.
    _chain(c, l, const [Offset(360, 942), Offset(500, 984), Offset(670, 934)], 15);
    for (var i = 0; i < 3; i++) {
      final x = 420 + i * 82.0;
      final bonePath = tube(
        [Offset(x, 966 + i * 6), Offset(x + 6, 1032 + i * 8)],
        const [9, 11],
        samples: 8,
      );
      paintSurface(c, bonePath, _sBone, l, detail: detail, seed: 619 + i);
      c.drawCircle(Offset(x + 8, 1038 + i * 8), 13,
          Paint()..color = _rBone.mid);
      c.drawCircle(Offset(x + 4, 1034 + i * 8), 6,
          Paint()..color = _rBone.deep.fade(0.7));
    }

    rimBand(c, body, l, width: 9, alpha: 0.6, color: const Color(0xFFFFC48A));
    rimBand(c, hump, l, width: 8, alpha: 0.55, color: const Color(0xFFFFC48A));
  }

  // 등 뒤로 늘어뜨린 팔. 주먹이 무릎 높이까지 내려온다.
  void _armBack(Canvas c, LightRig l, double bob, double detail) {
    const shoulder = Offset(694, 690);
    const elbow = Offset(806, 900);
    const wrist = Offset(768, 1092);

    final arm = limb(shoulder, elbow, wrist, r0: 92, r1: 68, r2: 54, swell: 1.22);
    paintSurface(c, arm, _sHideDark, l, detail: detail, seed: 621);

    final fist = blob(const Offset(772, 1152), 66, 60,
        warp: (a, u) => 1 + math.cos(a * 3) * 0.12);
    paintSurface(c, fist, _sHideDark, l, detail: detail, seed: 623);
    c.save();
    c.clipPath(fist);
    for (var i = 0; i < 3; i++) {
      panelLine(
        c,
        smoothOpenPath([
          Offset(722 + i * 6.0, 1120 + i * 26),
          Offset(824 - i * 4.0, 1128 + i * 24),
        ]),
        _rHide,
        l,
        width: 11,
      );
    }
    c.restore();
    _chain(c, l, const [Offset(742, 880), Offset(812, 930), Offset(798, 1010)], 13);
    rimBand(c, arm, l, width: 8, alpha: 0.55, color: const Color(0xFFFFB871));
  }

  // 앞으로 나온 팔이 곤봉을 어깨 위로 들어 올린다.
  void _armFront(Canvas c, LightRig l, double t, double bob, double detail) {
    final shoulder = Offset(320, 700 + bob * 0.5);
    final elbow = Offset(214, 900 + bob * 0.3);
    final wrist = Offset(266, 1076);

    // 곤봉을 먼저 그려 팔이 그 위에 얹히게 한다.
    _club(c, l, t, detail);

    final upper = limb(shoulder, lerpO(shoulder, elbow, 0.5), elbow,
        r0: 98, r1: 84, r2: 66, swell: 1.24);
    paintSurface(c, upper, _sHide, l, detail: detail, seed: 631);
    c.save();
    c.clipPath(upper);
    // 이두박근의 갈라짐.
    drawMuscleLine(
      c,
      [shoulder + const Offset(-10, 60), const Offset(238, 830), const Offset(226, 900)],
      _rHide,
      width: 20,
      alpha: 0.4,
    );
    c.restore();

    final fore = limb(elbow, lerpO(elbow, wrist, 0.5), wrist,
        r0: 70, r1: 62, r2: 52, swell: 1.1);
    paintSurface(c, fore, _sHide, l, detail: detail, seed: 633);

    // 팔뚝을 감은 사슬.
    _chain(c, l, [
      elbow + const Offset(-40, 24),
      lerpO(elbow, wrist, 0.4) + const Offset(46, 0),
      lerpO(elbow, wrist, 0.75) + const Offset(-34, 10),
      wrist + const Offset(40, -6),
    ], 16);

    // 곤봉 자루를 쥔 주먹.
    final fist = blob(const Offset(272, 1136), 70, 64,
        warp: (a, u) => 1 + math.cos(a * 3 + 0.6) * 0.13);
    paintSurface(c, fist, _sHide, l, detail: detail, seed: 635);
    c.save();
    c.clipPath(fist);
    for (var i = 0; i < 4; i++) {
      panelLine(
        c,
        smoothOpenPath([
          Offset(216, 1096 + i * 24.0),
          Offset(330, 1104 + i * 22.0),
        ]),
        _rHide,
        l,
        width: 10,
      );
    }
    c.restore();
    // 엄지.
    final thumb = tube(
      const [Offset(300, 1096), Offset(336, 1122)],
      const [22, 18],
      samples: 8,
    );
    paintSurface(c, thumb, _sHide, l, detail: detail, seed: 637);

    rimBand(c, upper, l, width: 9, alpha: 0.6, color: const Color(0xFFFFC48A));
    rimBand(c, fore, l, width: 7, alpha: 0.55, color: const Color(0xFFFFB871));
  }

  /// 통나무 곤봉. 나뭇결과 박아 넣은 쇠못, 그리고 말라붙은 피.
  void _club(Canvas c, LightRig l, double t, double detail) {
    final tilt = math.sin(t * 0.5) * 0.012;
    c.save();
    c.translate(272, 1140);
    c.rotate(-0.06 + tilt);
    c.translate(-272, -1140);

    final shaft = tube(
      const [Offset(272, 1200), Offset(252, 900), Offset(234, 620), Offset(214, 402)],
      const [34, 44, 66, 78],
      samples: 26,
    );
    castShadow(c, shaft, offset: const Offset(16, 14), blur: 20, alpha: 0.5);
    paintSurface(c, shaft, _sWood, l, detail: detail, seed: 641);

    // 머리 쪽이 뭉툭하게 벌어진 옹이.
    final head = blob(const Offset(206, 352), 96, 108,
        rotation: -0.1, warp: (a, u) => 1 + math.cos(a * 3 + 1.2) * 0.14);
    paintSurface(c, head, _sWood, l, detail: detail, seed: 643);

    c.save();
    c.clipPath(Path.combine(PathOperation.union, shaft, head));
    // 세로로 갈라진 나뭇결.
    final n = Noise(97);
    for (var i = 0; i < 9; i++) {
      final x0 = 170 + i * 22.0;
      c.drawPath(
        smoothOpenPath([
          Offset(x0 + n.signed1(i * 2.3) * 12, 250),
          Offset(x0 + 14 + n.signed1(i * 3.9) * 16, 700),
          Offset(x0 + 40 + n.signed1(i * 1.7) * 10, 1200),
        ]),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..color = Ramp.of(_wood).deep.fade(0.45),
      );
    }
    // 말라붙은 피.
    c.drawPath(
      smoothClosedPath([
        const Offset(140, 300),
        const Offset(250, 268),
        const Offset(290, 360),
        const Offset(236, 452),
        const Offset(146, 410),
      ]),
      Paint()
        ..color = _wound.darken(0.45).fade(0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    c.restore();

    // 박아 넣은 쇠못. 못마다 그림자를 줘 표면에서 튀어나오게 한다.
    if (detail > 0.35) {
      const spikes = [
        (Offset(140, 320), -2.5),
        (Offset(268, 300), -0.6),
        (Offset(120, 420), -2.9),
        (Offset(280, 410), -0.2),
        (Offset(196, 246), -1.6),
        (Offset(238, 520), 0.2),
        (Offset(158, 540), -2.8),
      ];
      for (final s in spikes) {
        final base = s.$1;
        final a = s.$2;
        final d = Offset(math.cos(a), math.sin(a));
        final spike = smoothClosedPath([
          base - d.perp * 15,
          base + d * 54,
          base + d.perp * 15,
        ], tension: 0.5);
        castShadow(c, spike, offset: const Offset(5, 7), blur: 6, alpha: 0.5);
        paintSurface(c, spike, _sIron, l, detail: 0.3, seed: 645);
        c.drawCircle(base, 13, Paint()..color = _rIron.shadow);
        c.drawCircle(base + const Offset(-4, -4), 6,
            Paint()..color = _rIron.light.fade(0.8));
      }
    }
    rimBand(c, head, l, width: 6, alpha: 0.5, color: const Color(0xFFFFB871));
    c.restore();
  }

  /// 쇠사슬. 고리를 번갈아 눕혀 그려야 사슬로 읽힌다.
  void _chain(Canvas c, LightRig l, List<Offset> path, double r) {
    final poly = smoothPolyline(path, 30);
    for (var i = 0; i < poly.length - 1; i += 2) {
      final p = poly[i];
      final d = (poly[math.min(i + 1, poly.length - 1)] - p).normalized();
      final flat = (i ~/ 2).isEven;
      c.save();
      c.translate(p.dx, p.dy);
      c.rotate(d.angle);
      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: r * 2.1,
        height: flat ? r * 1.5 : r * 0.62,
      );
      c.drawOval(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.44
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_rIron.spec, _rIron.mid, _rIron.deep],
          ).createShader(rect),
      );
      c.restore();
    }
  }

  void _head(Canvas c, LightRig l, double t, double bob, double detail) {
    final hc = Offset(500, 566 + bob * 0.7);

    // 목이랄 것이 거의 없다. 두개골이 바로 어깨에 박혀 있다.
    final neck = tube(
      [hc + const Offset(10, 40), hc + const Offset(16, 120)],
      const [66, 88],
      samples: 10,
    );
    paintSurface(c, neck, _sHideDark, l, detail: detail, seed: 651);

    // 두개골: 이마가 좁고 턱이 넓은 역사다리꼴.
    final head = smoothClosedPath([
      hc + const Offset(-8, -74),
      hc + const Offset(-58, -62),
      hc + const Offset(-84, -14),
      hc + const Offset(-92, 34),
      hc + const Offset(-64, 76),
      hc + const Offset(-10, 96),
      hc + const Offset(48, 88),
      hc + const Offset(86, 46),
      hc + const Offset(92, -6),
      hc + const Offset(62, -58),
    ], tension: 0.86);
    paintSurface(c, head, _sHide, l, detail: detail, seed: 653);

    c.save();
    c.clipPath(head);
    // 눈두덩. 깊게 파여 눈이 그늘에 잠긴다.
    c.drawPath(
      smoothClosedPath([
        hc + const Offset(-80, -34),
        hc + const Offset(0, -46),
        hc + const Offset(84, -30),
        hc + const Offset(76, 4),
        hc + const Offset(-2, -8),
        hc + const Offset(-74, 2),
      ]),
      Paint()
        ..color = _rHide.deep.fade(0.62)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    // 이마와 콧등의 주름.
    for (var i = 0; i < 3; i++) {
      drawMuscleLine(
        c,
        [
          hc + Offset(-64 + i * 4.0, -52 + i * 12),
          hc + Offset(0, -62 + i * 12),
          hc + Offset(64 - i * 4.0, -50 + i * 12),
        ],
        _rHide,
        width: 11,
        alpha: 0.4,
      );
    }
    c.restore();

    // 아래턱. 위턱보다 앞으로 튀어나와 엄니가 드러난다.
    final jaw = smoothClosedPath([
      hc + const Offset(-72, 30),
      hc + const Offset(0, 22),
      hc + const Offset(76, 34),
      hc + const Offset(70, 92),
      hc + const Offset(0, 118),
      hc + const Offset(-66, 90),
    ], tension: 0.82);
    paintSurface(c, jaw, _sHide, l, detail: detail, seed: 655);
    occlude(c, jaw, const Offset(0, -1), depth: 0.42, alpha: 0.55);

    // 입: 벌어진 틈과 이빨.
    final maw = smoothClosedPath([
      hc + const Offset(-58, 44),
      hc + const Offset(0, 36),
      hc + const Offset(60, 46),
      hc + const Offset(46, 74),
      hc + const Offset(0, 84),
      hc + const Offset(-48, 72),
    ], tension: 0.8);
    c.drawPath(maw, Paint()..color = const Color(0xFF2A100F));
    c.save();
    c.clipPath(maw);
    for (var i = 0; i < 6; i++) {
      final x = hc.dx - 50 + i * 20.0;
      c.drawPath(
        smoothClosedPath([
          Offset(x - 8, hc.dy + 38),
          Offset(x + 8, hc.dy + 38),
          Offset(x + 4, hc.dy + 60),
          Offset(x - 4, hc.dy + 60),
        ]),
        Paint()..color = _rBone.mid.fade(0.92),
      );
    }
    c.restore();

    // 아래 엄니 두 개. 실루엣 밖으로 삐져나와야 위협적이다.
    for (final s in const [-1.0, 1.0]) {
      final root = hc + Offset(s * 48, 62);
      final tusk = tube(
        [root, root + Offset(s * 8, -34), root + Offset(s * 22, -78)],
        const [16, 12, 3],
        samples: 14,
      );
      paintSurface(c, tusk, _sBone, l, detail: detail, seed: 657);
      rimBand(c, tusk, l, width: 3, alpha: 0.7, color: const Color(0xFFFFE6C0));
    }

    // 뿔: 관자놀이에서 뒤로 휘어 오른다.
    for (final s in const [-1.0, 1.0]) {
      final root = hc + Offset(s * 76, -30);
      final horn = tube(
        [
          root,
          root + Offset(s * 40, -58),
          root + Offset(s * 42, -122),
          root + Offset(s * 8, -168),
        ],
        const [26, 20, 13, 3],
        samples: 20,
      );
      paintSurface(c, horn, _sBone, l, detail: detail, seed: 659);
      c.save();
      c.clipPath(horn);
      for (var i = 0; i < 5; i++) {
        final u = 0.15 + i * 0.17;
        final p = root + Offset(s * (40 * u + 20 * u * u), -58 * u - 64 * u * u);
        c.drawPath(
          smoothOpenPath([p + Offset(-s * 22, -4), p + Offset(s * 22, 6)]),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 6
            ..color = _rBone.deep.fade(0.5),
        );
      }
      c.restore();
      rimBand(c, horn, l, width: 4, alpha: 0.6, color: const Color(0xFFFFE0B0));
    }

    // 코뚜레.
    final ringC = hc + const Offset(4, 16);
    c.drawCircle(
      ringC + const Offset(0, 22),
      26,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_rIron.spec, _rIron.mid, _rIron.deep],
        ).createShader(Rect.fromCircle(center: ringC, radius: 26)),
    );

    // 작고 붉은 눈. 크기를 줄일수록 짐승에 가까워진다.
    for (final s in const [-1.0, 1.0]) {
      final e = hc + Offset(s * 40, -12);
      glowAt(c, e, 26, const Color(0xFFFF5A2A), intensity: 0.5);
      drawEye(c, e, 17, 9,
          iris: const Color(0xFFFF6A2E),
          light: l,
          open: 0.85,
          look: -0.2 * s,
          mirrored: s > 0,
          glow: const Color(0xFFFF5A2A),
          scleraTint: const Color(0xFFB8A184),
          lash: 0.3);
    }

    // 콧구멍.
    for (final s in const [-1.0, 1.0]) {
      c.drawOval(
        Rect.fromCenter(
            center: hc + Offset(s * 20, 14), width: 20, height: 14),
        Paint()..color = _rHide.deep.darken(0.4).fade(0.85),
      );
    }

    // 침. 아래턱에서 늘어진 한 줄이 생기를 만든다.
    if (detail > 0.5) {
      final drip = 0.5 + 0.5 * math.sin(t * 1.1);
      final path = tube(
        [hc + const Offset(-14, 82), hc + Offset(-10, 110 + drip * 46)],
        const [4, 2],
        samples: 8,
      );
      c.drawPath(
        path,
        Paint()
          ..color = const Color(0xFFD8E4D0).fade(0.55)
          ..blendMode = BlendMode.plus,
      );
      c.drawCircle(hc + Offset(-10, 112 + drip * 46), 5,
          Paint()..color = const Color(0xFFE0ECD8).fade(0.6));
    }

    rimBand(c, head, l, width: 7, alpha: 0.6, color: const Color(0xFFFFB871));
    rimBand(c, jaw, l, width: 6, alpha: 0.5, color: const Color(0xFFFFB871));
  }
}
