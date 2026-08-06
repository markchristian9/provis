import 'dart:math' as math;

import 'package:flutter/painting.dart';

import 'package:provis/provis.dart';

/// 바엘모르스 — 잿불의 비룡.
///
/// 용은 파츠를 이어 붙이면 반드시 장난감이 된다. 그래서 목-몸통-꼬리를
/// 끊지 않고 하나의 스파인으로 뽑아 두께 곡선만 변조했다. 그 위를 비늘과
/// 용암 균열이 같은 곡선을 따라 흐르기 때문에, 파츠 경계가 아니라 근육의
/// 흐름이 먼저 읽힌다.
class Vaelmorth extends Artist {
  @override
  String get id => 'vaelmorth';
  @override
  String get name => 'Vaelmorth';
  @override
  String get title => 'Wyrm of the Cinder Vault';
  @override
  String get blurb => '갈라진 비늘 아래로 용암이 흐르는 잿불의 비룡.';
  @override
  Camp get camp => Camp.monster;
  @override
  bool get facesLeft => true;
  @override
  Rect get framing => const Rect.fromLTWH(110, 60, 890, 1290);
  @override
  Sex? get sex => null;
  @override
  CharacterBuild get build => CharacterBuild(
        archetype: Archetype.berserker,
        beast: true,
        palette: tintedPalette(const Color(0xFFFF6A1E), Rng(0x7AE1), monster: true),
        weapon: WeaponKind.greatsword,
        muscle: 1.0,
        glowRunes: true,
        heightScale: 1.35,
      );
  @override
  Color get accent => const Color(0xFFFF6A1E);
  @override
  LightRig get light => LightRig.infernal;
  @override
  List<Color> get moodSky => const [
        Color(0xFF160A0C),
        Color(0xFF3E1512),
        Color(0xFF8A2C0E),
      ];

  static const _scale = Color(0xFF4E252A);
  static const _scaleDark = Color(0xFF2E1519);
  static const _belly = Color(0xFF8A6A50);
  static const _horn = Color(0xFF2A2126);
  static const _membrane = Color(0xFF6B2A28);
  static const _lava = Color(0xFFFF6A1E);
  static const _emberEye = Color(0xFFFFC22A);

  Surface get _sScale => const Surface(_scale, Finish.scale, contrast: 1.25);
  Surface get _sScaleDark =>
      const Surface(_scaleDark, Finish.scale, contrast: 1.3);
  Surface get _sBelly => const Surface(_belly, Finish.scale, contrast: 1.0);
  Surface get _sHorn => const Surface(_horn, Finish.chitin, contrast: 1.4);
  Surface get _sMembrane => const Surface(_membrane, Finish.membrane,
      contrast: 1.1, sss: Color(0xFFFF9A4C), alpha: 0.94);

  Ramp get _rScale => Ramp.of(_scale, contrast: 1.25);
  Ramp get _rBelly => Ramp.of(_belly);

  /// 목-몸통-꼬리를 관통하는 단일 스파인.
  static const _spine = <Offset>[
    Offset(296, 402),
    Offset(342, 520),
    Offset(408, 646),
    Offset(486, 748),
    Offset(578, 812),
    Offset(672, 866),
    Offset(772, 938),
    Offset(864, 1044),
    Offset(926, 1168),
    Offset(958, 1288),
  ];
  static const _spineR = <double>[
    36, 48, 72, 112, 132, 116, 82, 52, 28, 9,
  ];

  @override
  void paint(Canvas c, double t, {double detail = 1.0}) {
    final l = light;
    final bob = breathe(t, speed: 0.62, amp: 6.0);

    groundShadow(c, const Offset(560, 1306), 360, 50, alpha: 0.66);
    _lavaFloor(c, t);

    _wing(c, l, t, detail, back: true);
    _legBack(c, l, bob, detail);
    _body(c, l, bob, t, detail);
    _wing(c, l, t, detail, back: false);
    _legFront(c, l, bob, detail);
    _foreLimb(c, l, bob, detail);
    _head(c, l, t, bob, detail);

    if (detail > 0.4) {
      drawMotes(
        c,
        const Rect.fromLTWH(120, 300, 800, 1000),
        t,
        _lava,
        count: 26,
        size: 5,
        speed: 46,
        seed: 17,
        drift: 0.9,
      );
    }
  }

  // 발밑에 고인 용암빛. 이 캐릭터의 바운스 라이트 근거를 화면에 보여 준다.
  void _lavaFloor(Canvas c, double t) {
    final rect = Rect.fromCenter(
      center: const Offset(560, 1300),
      width: 780,
      height: 130,
    );
    c.drawOval(
      rect,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(
          colors: [
            _lava.fade(0.30),
            const Color(0xFF8A2408).fade(0.14),
            _lava.fade(0.0),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(rect),
    );
    final n = Noise(23);
    for (var i = 0; i < 7; i++) {
      final x = 260 + n.at1(i * 3.1) * 620;
      final y = 1268 + n.at1(i * 6.7) * 60;
      final r = 24 + n.at1(i * 9.3) * 46;
      final pulse = 0.6 + 0.4 * math.sin(t * 1.3 + i);
      glowAt(c, Offset(x, y), r, _lava, intensity: 0.45 * pulse);
    }
  }

  void _body(Canvas c, LightRig l, double bob, double t, double detail) {
    final spine = [
      for (var i = 0; i < _spine.length; i++)
        _spine[i] + Offset(0, bob * (1 - i / _spine.length) * 0.8),
    ];
    final body = tube(spine, _spineR, samples: 44);

    castShadow(c, body, offset: const Offset(18, 20), blur: 28, alpha: 0.5);
    paintSurface(c, body, _sScale, l, detail: detail, seed: 701);

    c.save();
    c.clipPath(body);

    // 배: 스파인 아래쪽에 밝은 판을 깔고 가로 띠를 새긴다.
    final poly = smoothPolyline(spine, 60);
    final bellyRing = <Offset>[];
    for (var i = 8; i < poly.length - 6; i++) {
      final u = i / (poly.length - 1);
      final d = (poly[i + 1] - poly[i - 1]).normalized();
      final r = _radiusAt(u) * 0.92;
      bellyRing.add(poly[i] - d.perp * r);
    }
    for (var i = poly.length - 7; i >= 8; i--) {
      final u = i / (poly.length - 1);
      final d = (poly[i + 1] - poly[i - 1]).normalized();
      bellyRing.add(poly[i] - d.perp * (_radiusAt(u) * 0.30));
    }
    final belly = smoothClosedPath(bellyRing, tension: 0.85);
    paintSurface(c, belly, _sBelly, l, detail: detail, rim: false, seed: 703);
    c.save();
    c.clipPath(belly);
    for (var i = 10; i < poly.length - 8; i += 2) {
      final u = i / (poly.length - 1);
      final d = (poly[i + 1] - poly[i - 1]).normalized();
      final r = _radiusAt(u);
      c.drawPath(
        smoothOpenPath([
          poly[i] - d.perp * r * 1.05 - d * 4,
          poly[i] - d.perp * r * 0.28 + d * 4,
        ]),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..color = _rBelly.deep.fade(0.45),
      );
    }
    c.restore();

    // 비늘. 몸 전체에 균일하게 깔면 노이즈가 되므로 등 쪽에만 크게 얹는다.
    if (detail > 0.45) {
      _scales(c, poly, detail);
    }

    // 용암 균열. 비늘 사이가 벌어져 속이 비친다는 설정이라 스파인을
    // 가로지르는 방향으로 낸다.
    _cracks(c, poly, t);
    c.restore();

    // 등줄기 가시.
    for (var i = 3; i < poly.length - 8; i += 3) {
      final u = i / (poly.length - 1);
      final d = (poly[i + 1] - poly[i - 1]).normalized();
      final base = poly[i] + d.perp * (_radiusAt(u) * 0.94);
      final len = 26 + math.sin(u * math.pi) * 54;
      final spike = smoothClosedPath([
        base - d * (len * 0.34),
        base + d.perp * len - d * (len * 0.12),
        base + d * (len * 0.30),
      ], tension: 0.55);
      paintSurface(c, spike, _sHorn, l, detail: detail, seed: 705 + i);
      rimBand(c, spike, l, width: 3, alpha: 0.7, color: _lava.lighten(0.3));
    }

    rimBand(c, body, l, width: 9, alpha: 0.6, color: const Color(0xFFFF9040));
  }

  double _radiusAt(double u) {
    final x = u * (_spineR.length - 1);
    final i = x.floor().clamp(0, _spineR.length - 2);
    return lerpD(_spineR[i], _spineR[i + 1], x - i);
  }

  void _scales(Canvas c, List<Offset> poly, double detail) {
    final n = Noise(29);
    for (var i = 4; i < poly.length - 6; i += 2) {
      final u = i / (poly.length - 1);
      final d = (poly[i + 1] - poly[i - 1]).normalized();
      final r = _radiusAt(u);
      final rows = (r / 26).clamp(2, 7).toInt();
      for (var k = 0; k < rows; k++) {
        final v = (k + (i.isEven ? 0.0 : 0.5)) / rows;
        final p = poly[i] + d.perp * (r * (0.94 - v * 1.5));
        final s = r * 0.20 * (1 - v * 0.35);
        final scale = smoothClosedPath([
          p - d * s,
          p + d.perp * s * 0.9,
          p + d * s,
          p - d.perp * s * 0.5,
        ], tension: 0.8);
        final bright = 0.4 + n.at2(i * 0.7, k * 1.3) * 0.6;
        c.drawPath(
          scale,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = _rScale.deep.fade(0.5),
        );
        c.drawPath(
          scale.shift(-d.perp * s * 0.22),
          Paint()..color = _rScale.light.fade(0.16 * bright),
        );
      }
    }
  }

  void _cracks(Canvas c, List<Offset> poly, double t) {
    final n = Noise(59);
    for (var i = 6; i < poly.length - 8; i += 4) {
      final u = i / (poly.length - 1);
      final d = (poly[i + 1] - poly[i - 1]).normalized();
      final r = _radiusAt(u);
      final pulse = 0.55 + 0.45 * math.sin(t * 1.6 + i * 0.5);
      final pts = <Offset>[];
      for (var k = 0; k <= 5; k++) {
        final v = k / 5;
        pts.add(poly[i] +
            d.perp * (r * (0.9 - v * 1.7)) +
            d * (n.signed1(i * 2.1 + k * 3.3) * r * 0.35));
      }
      final crack = smoothOpenPath(pts);
      c.drawPath(
        crack,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 13
          ..strokeCap = StrokeCap.round
          ..blendMode = BlendMode.plus
          ..color = const Color(0xFF7A2004).fade(0.5 * pulse)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
      c.drawPath(
        crack,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..blendMode = BlendMode.plus
          ..color = _lava.fade(0.75 * pulse),
      );
      c.drawPath(
        crack,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round
          ..blendMode = BlendMode.plus
          ..color = const Color(0xFFFFE8B0).fade(0.8 * pulse),
      );
    }
  }

  /// 날개. 지골 사이의 막이 안쪽으로 오목하게 처지는 것이 핵심이다.
  void _wing(Canvas c, LightRig l, double t, double detail,
      {required bool back}) {
    final flap = math.sin(t * 0.55 + (back ? 0.6 : 0)) * 16;
    final k = back ? -1.0 : 1.0;
    final shoulder = Offset(back ? 612 : 548, (back ? 716 : 690) + flap * 0.2);
    final elbow = Offset(back ? 792 : 706, (back ? 498 : 372) + flap);
    final wrist = Offset(back ? 918 : 872, (back ? 566 : 288) + flap * 1.4);

    final tips = <Offset>[
      Offset(back ? 986 : 972, (back ? 806 : 452) + flap * 1.2),
      Offset(back ? 924 : 918, (back ? 906 : 646) + flap),
      Offset(back ? 836 : 828, (back ? 962 : 812) + flap * 0.8),
      Offset(back ? 742 : 716, (back ? 964 : 906) + flap * 0.5),
    ];
    final anchor = Offset(back ? 660 : 596, back ? 852 : 826);

    // 막: 손목 → 지골 끝 → (사이마다 오목한 점) → 몸통 부착점.
    final ring = <Offset>[shoulder, elbow, wrist];
    for (var i = 0; i < tips.length; i++) {
      ring.add(tips[i]);
      final next = i + 1 < tips.length ? tips[i + 1] : anchor;
      final mid = lerpO(tips[i], next, 0.5);
      final toWrist = (wrist - mid).normalized();
      ring.add(mid + toWrist * ((next - tips[i]).distance * 0.20));
    }
    final membrane = smoothClosedPath(ring, tension: 0.75);

    if (!back) {
      castShadow(c, membrane, offset: const Offset(20, 26), blur: 30, alpha: 0.4);
    }
    final surf = back ? _sMembrane.withAlpha(0.72) : _sMembrane;
    paintSurface(c, membrane, surf, l, detail: detail, seed: back ? 711 : 713);

    c.save();
    c.clipPath(membrane);
    // 막의 혈관. 지골에서 갈라져 나가는 방향이어야 자연스럽다.
    for (var i = 0; i < tips.length; i++) {
      final vein = smoothOpenPath([
        wrist,
        lerpO(wrist, tips[i], 0.45) + Offset(k * 12, 18),
        tips[i],
      ]);
      c.drawPath(
        vein,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..color = const Color(0xFF3A1210).fade(back ? 0.3 : 0.5),
      );
      for (var j = 1; j < 4; j++) {
        final p = lerpO(wrist, tips[i], j / 4.0);
        c.drawPath(
          smoothOpenPath([p, p + Offset(k * 40, 46 + j * 8)]),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.4
            ..color = const Color(0xFF3A1210).fade(back ? 0.2 : 0.35),
        );
      }
    }
    // 막을 통과하는 역광.
    c.drawRect(
      membrane.getBounds(),
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(
          center: const Alignment(0.4, -0.3),
          colors: [
            const Color(0xFFFF9A4C).fade(back ? 0.12 : 0.26),
            _lava.fade(0.0),
          ],
        ).createShader(membrane.getBounds()),
    );
    c.restore();

    // 지골. 막 위에 뼈대를 얹어야 막이 매달린 것으로 읽힌다.
    final boneS = back ? _sScaleDark : _sScale;
    for (var i = 0; i < tips.length; i++) {
      final finger = tube(
        [wrist, lerpO(wrist, tips[i], 0.5), tips[i]],
        [16.0 - i * 1.5, 11.0 - i, 3],
        samples: 16,
      );
      paintSurface(c, finger, boneS, l, detail: detail, seed: 715 + i);
      // 발톱.
      final d = (tips[i] - wrist).normalized();
      final claw = smoothClosedPath([
        tips[i] - d.perp * 6,
        tips[i] + d * 30 + d.perp * 8,
        tips[i] + d.perp * 6,
      ], tension: 0.5);
      paintSurface(c, claw, _sHorn, l, detail: 0.3, seed: 719);
    }
    final upperArm = tube(
      [shoulder, lerpO(shoulder, elbow, 0.5), elbow],
      const [34, 26, 20],
      samples: 14,
    );
    paintSurface(c, upperArm, boneS, l, detail: detail, seed: 721);
    final foreArm = tube(
      [elbow, lerpO(elbow, wrist, 0.5), wrist],
      const [20, 17, 14],
      samples: 14,
    );
    paintSurface(c, foreArm, boneS, l, detail: detail, seed: 723);

    if (!back) {
      rimBand(c, membrane, l, width: 6, alpha: 0.5, color: const Color(0xFFFF9040));
      rimBand(c, upperArm, l, width: 5, alpha: 0.6, color: const Color(0xFFFF9040));
    }
  }

  void _legBack(Canvas c, LightRig l, double bob, double detail) => _leg(
        c,
        l,
        detail,
        hip: Offset(688, 872 + bob * 0.3),
        knee: const Offset(772, 1018),
        ankle: const Offset(716, 1174),
        toe: const Offset(792, 1288),
        surf: _sScaleDark,
        seed: 731,
      );

  void _legFront(Canvas c, LightRig l, double bob, double detail) => _leg(
        c,
        l,
        detail,
        hip: Offset(560, 858 + bob * 0.4),
        knee: const Offset(468, 1024),
        ankle: const Offset(536, 1176),
        toe: const Offset(452, 1292),
        surf: _sScale,
        seed: 741,
      );

  /// 조족형 뒷다리. 무릎이 앞, 발목이 뒤로 꺾여 Z 자를 그린다.
  void _leg(
    Canvas c,
    LightRig l,
    double detail, {
    required Offset hip,
    required Offset knee,
    required Offset ankle,
    required Offset toe,
    required Surface surf,
    required int seed,
  }) {
    final thigh = limb(hip, lerpO(hip, knee, 0.5), knee,
        r0: 92, r1: 66, r2: 44, swell: 1.14);
    paintSurface(c, thigh, surf, l, detail: detail, seed: seed);

    final shank = limb(knee, lerpO(knee, ankle, 0.5), ankle,
        r0: 44, r1: 36, r2: 26, swell: 1.1);
    paintSurface(c, shank, surf, l, detail: detail, seed: seed + 1);

    final foot = limb(ankle, lerpO(ankle, toe, 0.5), toe,
        r0: 26, r1: 24, r2: 20, swell: 1.05);
    paintSurface(c, foot, surf, l, detail: detail, seed: seed + 2);

    // 세 발가락과 발톱.
    final d = (toe - ankle).normalized();
    for (var i = 0; i < 3; i++) {
      final a = (i - 1) * 0.42;
      final dir = d.rotated(a);
      final tip = toe + dir * (52 - (i - 1).abs() * 10);
      final digit = tube([toe, lerpO(toe, tip, 0.5), tip], const [17, 13, 7],
          samples: 12);
      paintSurface(c, digit, surf, l, detail: detail, seed: seed + 3 + i);
      final claw = smoothClosedPath([
        tip - dir.perp * 8,
        tip + dir * 34 + Offset(0, 8),
        tip + dir.perp * 8,
      ], tension: 0.5);
      paintSurface(c, claw, _sHorn, l, detail: 0.3, seed: seed + 7);
    }
    rimBand(c, thigh, l, width: 7, alpha: 0.5, color: const Color(0xFFFF9040));
  }

  // 가슴 앞의 작은 앞다리.
  void _foreLimb(Canvas c, LightRig l, double bob, double detail) {
    final shoulder = Offset(452, 786 + bob * 0.6);
    final elbow = Offset(392, 872);
    final wrist = Offset(438, 936);

    final arm = limb(shoulder, elbow, wrist, r0: 40, r1: 28, r2: 20);
    paintSurface(c, arm, _sScale, l, detail: detail, seed: 751);

    final d = (wrist - elbow).normalized();
    for (var i = 0; i < 3; i++) {
      final dir = d.rotated((i - 1) * 0.5);
      final tip = wrist + dir * 40;
      final digit =
          tube([wrist, tip], [11.0 - i, 4], samples: 10);
      paintSurface(c, digit, _sScale, l, detail: 0.4, seed: 753 + i);
      final claw = smoothClosedPath([
        tip - dir.perp * 5,
        tip + dir * 24,
        tip + dir.perp * 5,
      ], tension: 0.5);
      paintSurface(c, claw, _sHorn, l, detail: 0.3, seed: 757);
    }
  }

  void _head(Canvas c, LightRig l, double t, double bob, double detail) {
    final base = Offset(300, 404 + bob * 0.9);

    // 두개골에서 주둥이 끝까지 하나의 쐐기. 용의 얼굴은 길이가 곧 성격이다.
    final skull = smoothClosedPath([
      base + const Offset(24, -46),
      base + const Offset(-36, -52),
      base + const Offset(-104, -30),
      base + const Offset(-158, 4),
      base + const Offset(-176, 30),
      base + const Offset(-150, 48),
      base + const Offset(-92, 56),
      base + const Offset(-26, 64),
      base + const Offset(30, 52),
      base + const Offset(46, 6),
    ], tension: 0.86);
    paintSurface(c, skull, _sScale, l, detail: detail, seed: 761);

    // 아래턱. 살짝 벌어져 목구멍의 불빛이 새어 나온다.
    final jaw = smoothClosedPath([
      base + const Offset(-166, 40),
      base + const Offset(-96, 62),
      base + const Offset(-20, 78),
      base + const Offset(34, 70),
      base + const Offset(26, 96),
      base + const Offset(-38, 104),
      base + const Offset(-118, 78),
      base + const Offset(-168, 56),
    ], tension: 0.84);
    paintSurface(c, jaw, _sScaleDark, l, detail: detail, seed: 763);

    // 목구멍의 불빛.
    final maw = smoothClosedPath([
      base + const Offset(-160, 44),
      base + const Offset(-60, 62),
      base + const Offset(30, 68),
      base + const Offset(20, 82),
      base + const Offset(-64, 76),
      base + const Offset(-158, 52),
    ]);
    final pulse = 0.6 + 0.4 * math.sin(t * 1.9);
    c.drawPath(
      maw,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = LinearGradient(
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
          colors: [
            const Color(0xFFFFE9A8).fade(0.9 * pulse),
            _lava.fade(0.7 * pulse),
            _lava.darken(0.5).fade(0.2),
          ],
        ).createShader(maw.getBounds()),
    );
    glowAt(c, base + const Offset(-70, 66), 90, _lava,
        intensity: 0.45 * pulse);

    // 이빨. 위아래가 서로 어긋나게 물려 있어야 짐승답다.
    for (var i = 0; i < 7; i++) {
      final u = i / 6;
      final top = Offset(
        lerpD(base.dx - 152, base.dx + 10, u),
        lerpD(base.dy + 44, base.dy + 58, u),
      );
      final h = 14.0 + math.sin(u * math.pi) * 12;
      c.drawPath(
        smoothClosedPath([
          top + Offset(-6, 0),
          top + Offset(6, 0),
          top + Offset(2, h),
        ], tension: 0.4),
        Paint()..color = const Color(0xFFE8DCC0).fade(0.95),
      );
      if (i < 6) {
        final bot = Offset(
          lerpD(base.dx - 140, base.dx + 2, u),
          lerpD(base.dy + 64, base.dy + 78, u),
        );
        c.drawPath(
          smoothClosedPath([
            bot + Offset(-6, 0),
            bot + Offset(6, 0),
            bot + Offset(2, -h * 0.85),
          ], tension: 0.4),
          Paint()..color = const Color(0xFFD8CBAA).fade(0.92),
        );
      }
    }

    c.save();
    c.clipPath(skull);
    // 눈두덩 융기와 콧등의 능선.
    drawMuscleLine(
      c,
      [base + const Offset(-140, 14), base + const Offset(-70, -6), base + const Offset(-4, -18)],
      _rScale,
      width: 16,
      alpha: 0.45,
    );
    if (detail > 0.45) {
      final n = Noise(31);
      for (var i = 0; i < 30; i++) {
        final p = base +
            Offset(-170 + n.at1(i * 3.3) * 210, -40 + n.at1(i * 7.9) * 96);
        final s = 5 + n.at1(i * 5.1) * 7;
        c.drawPath(
          smoothClosedPath([
            p + Offset(-s, 0),
            p + Offset(0, -s * 0.7),
            p + Offset(s, 0),
            p + Offset(0, s * 0.7),
          ]),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..color = _rScale.deep.fade(0.45),
        );
      }
    }
    c.restore();

    // 콧구멍과 콧구멍에서 새는 연기빛.
    c.drawOval(
      Rect.fromCenter(
          center: base + const Offset(-146, 18), width: 22, height: 13),
      Paint()..color = const Color(0xFF160A0A).fade(0.9),
    );
    glowAt(c, base + const Offset(-152, 16), 26, _lava, intensity: 0.32 * pulse);

    // 뿔: 뒤로 크게 뻗은 한 쌍 + 작은 곁뿔.
    for (final rec in const [
      (Offset(18, -40), Offset(120, -70), Offset(214, -34), 26.0),
      (Offset(6, -20), Offset(96, -8), Offset(178, 30), 17.0),
    ]) {
      final horn = tube(
        [base + rec.$1, base + rec.$2, base + rec.$3],
        [rec.$4, rec.$4 * 0.6, 3],
        samples: 18,
      );
      paintSurface(c, horn, _sHorn, l, detail: detail, seed: 771);
      c.save();
      c.clipPath(horn);
      for (var i = 0; i < 6; i++) {
        final u = 0.1 + i * 0.15;
        final p = lerpO(base + rec.$1, base + rec.$3, u);
        c.drawPath(
          smoothOpenPath([p + const Offset(-6, -22), p + const Offset(6, 22)]),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5
            ..color = const Color(0xFF0E0A0C).fade(0.6),
        );
      }
      c.restore();
      rimBand(c, horn, l, width: 4, alpha: 0.7, color: const Color(0xFFFF8A38));
    }
    // 볼의 가시 프릴.
    for (var i = 0; i < 4; i++) {
      final root = base + Offset(-10 + i * 14.0, 26 + i * 12);
      final dir = Offset(0.7, 0.5).rotated(i * 0.22);
      final spine = tube(
        [root, root + dir * 46],
        [9.0 - i, 2],
        samples: 10,
      );
      paintSurface(c, spine, _sHorn, l, detail: 0.3, seed: 773 + i);
    }

    // 눈: 세로 동공의 파충류 눈. 홍채가 스스로 빛난다.
    final eye = base + const Offset(-58, -4);
    glowAt(c, eye, 44, _emberEye, intensity: 0.5);
    final socket = smoothClosedPath([
      eye + const Offset(-30, 4),
      eye + const Offset(-10, -16),
      eye + const Offset(20, -12),
      eye + const Offset(30, 4),
      eye + const Offset(6, 18),
      eye + const Offset(-18, 16),
    ], tension: 0.85);
    c.drawPath(socket, Paint()..color = const Color(0xFF2A1408));
    c.save();
    c.clipPath(socket);
    c.drawPath(
      socket,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.2, -0.2),
          colors: [
            const Color(0xFFFFF0B0),
            _emberEye,
            _emberEye.darken(0.5),
            const Color(0xFF3A1A04),
          ],
          stops: const [0.0, 0.35, 0.72, 1.0],
        ).createShader(socket.getBounds()),
    );
    // 세로 동공.
    c.drawPath(
      smoothClosedPath([
        eye + const Offset(-1, -18),
        eye + const Offset(5, 0),
        eye + const Offset(-1, 18),
        eye + const Offset(-7, 0),
      ]),
      Paint()..color = const Color(0xFF120602),
    );
    c.restore();
    c.drawCircle(eye + const Offset(-9, -8), 6,
        Paint()..color = white.fade(0.85));
    c.drawPath(
      socket,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = _rScale.deep.fade(0.85),
    );
    // 눈 위를 덮는 각질 눈썹.
    c.drawPath(
      smoothOpenPath([
        eye + const Offset(-36, -6),
        eye + const Offset(-6, -26),
        eye + const Offset(30, -16),
      ]),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 13
        ..strokeCap = StrokeCap.round
        ..color = _rScale.deep,
    );

    rimBand(c, skull, l, width: 6, alpha: 0.65, color: const Color(0xFFFF9040));
    rimBand(c, jaw, l, width: 5, alpha: 0.55, color: const Color(0xFFFF9040));
  }
}
