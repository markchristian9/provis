import 'dart:math' as math;

import 'package:flutter/painting.dart';

import 'package:provis/provis.dart';

/// 카일런 — 재의 서약자.
///
/// 어두운 캐릭터의 함정은 전부 검게 뭉개진다는 것이다. 그래서 여기서는
/// 밝기 대신 색으로 층을 나눴다. 가죽은 자주빛 검정, 천은 남보라, 금속은
/// 푸른 회색으로 두고 그 위에 보라 림라이트 하나만 강하게 얹는다. 실루엣은
/// 오직 그 림과 발치의 안개가 만든다.
class Kaelen extends Artist {
  @override
  String get id => 'kaelen';
  @override
  String get name => 'Kaelen';
  @override
  String get title => 'Oathsworn of Ash';
  @override
  String get blurb => '그림자를 걸치고 숨소리마저 지운 이중 단검의 처형자.';
  @override
  Camp get camp => Camp.player;
  @override
  bool get facesLeft => true;
  @override
  Sex get sex => Sex.male;
  @override
  CharacterBuild get build => CharacterBuild(
        archetype: Archetype.assassin,
        sex: Sex.male,
        palette: paletteOf(
          skin: const Color(0xFFBFB6D6),
          hair: const Color(0xFF221A2A),
          cloth: const Color(0xFF3E3A56),
          accent: const Color(0xFF9A6BFF),
          metal: const Color(0xFF8C86A8),
        ),
        weapon: WeaponKind.daggers,
        headGear: HeadGear.hood,
        hasCape: true,
        armorHeaviness: 0.35,
        hairLength: 0.35,
        glowRunes: true,
      );
  @override
  Color get accent => const Color(0xFF9A6BFF);
  @override
  LightRig get light => const LightRig(
        dir: Offset(-0.62, -0.78),
        rimDir: Offset(0.80, -0.60),
        key: Color(0xFFCFD8FF),
        fill: Color(0xFF3A2F63),
        rim: Color(0xFFB98CFF),
        bounce: Color(0xFF4A3A78),
        ambient: Color(0xFF161228),
      );
  @override
  List<Color> get moodSky => const [
        Color(0xFF0C0A16),
        Color(0xFF201A38),
        Color(0xFF3A2A57),
      ];

  static const _leather = Color(0xFF2A2334);
  static const _leatherLit = Color(0xFF3B3049);
  static const _cloth = Color(0xFF2E2447);
  static const _steel = Color(0xFF7C879C);
  static const _dark = Color(0xFF4A5064);
  static const _skin = Color(0xFFC49B7C);
  static const _wrap = Color(0xFF6A6150);
  static const _arcane = Color(0xFF9A6BFF);

  Surface get _sLeather => const Surface(_leather, Finish.leather, contrast: 1.3);
  Surface get _sLeatherLit =>
      const Surface(_leatherLit, Finish.leather, contrast: 1.25);
  Surface get _sCloth => const Surface(_cloth, Finish.cloth, contrast: 1.25);
  Surface get _sSteel => const Surface(_steel, Finish.metal, contrast: 1.3);
  Surface get _sDark => const Surface(_dark, Finish.metal, contrast: 1.35);
  Surface get _sSkin => const Surface(_skin, Finish.skin, contrast: 1.0);
  Surface get _sWrap => const Surface(_wrap, Finish.cloth, contrast: 1.1);

  Ramp get _rLeather => Ramp.of(_leather, contrast: 1.3);
  Ramp get _rCloth => Ramp.of(_cloth, contrast: 1.25);
  Ramp get _rSteel => Ramp.of(_steel, contrast: 1.3);
  Ramp get _rSkin => Ramp.of(_skin);

  @override
  void paint(Canvas c, double t, {double detail = 1.0}) {
    final l = light;
    final bob = breathe(t, speed: 1.35, amp: 2.6);
    final sway = jitter(t, 7.7, amp: 1.8);

    _shadowAura(c, t, detail);
    groundShadow(c, const Offset(510, 1322), 280, 44, alpha: 0.72);

    _cape(c, t, l, detail);
    _legBack(c, l, detail);
    _armBack(c, l, t, bob, detail);
    _legFront(c, l, detail);
    _torso(c, l, bob, sway, detail);
    _head(c, l, t, bob, sway, detail);
    _armFront(c, l, t, bob, detail);
    _scarf(c, t, l, detail);

    if (detail > 0.4) {
      _mist(c, t);
      drawMotes(
        c,
        const Rect.fromLTWH(300, 860, 420, 460),
        t,
        _arcane,
        count: 14,
        size: 4,
        speed: 18,
        seed: 29,
        drift: 0.8,
      );
    }
  }

  // 등 뒤에서 피어오르는 그림자. 캐릭터의 실루엣을 넓혀 위압감을 만든다.
  void _shadowAura(Canvas c, double t, double detail) {
    final n = Noise(41);
    for (var i = 0; i < 5; i++) {
      final ph = i * 1.7;
      final x = 500 + math.sin(t * 0.5 + ph) * 90 + (n.at1(i * 3.1) - 0.5) * 160;
      final y = 900 - i * 90.0 + math.cos(t * 0.42 + ph) * 40;
      final r = 190.0 + i * 34;
      c.drawCircle(
        Offset(x, y),
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFF3B1F6B).fade(0.30),
              const Color(0xFF1A0E33).fade(0.16),
              const Color(0xFF000000).fade(0.0),
            ],
            stops: const [0.0, 0.5, 1.0],
          ).createShader(Rect.fromCircle(center: Offset(x, y), radius: r)),
      );
    }
    if (detail < 0.4) return;
    // 잔상: 본체보다 한 박자 늦게 따라오는 반투명 실루엣.
    c.save();
    c.translate(-46 + math.sin(t * 1.1) * 8, 6);
    c.drawPath(
      smoothClosedPath([
        const Offset(470, 300),
        const Offset(610, 520),
        const Offset(640, 900),
        const Offset(690, 1300),
        const Offset(430, 1300),
        const Offset(360, 880),
        const Offset(390, 520),
      ]),
      Paint()
        ..color = const Color(0xFF2A1550).fade(0.30)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 26),
    );
    c.restore();
  }

  void _mist(Canvas c, double t) {
    final n = Noise(77);
    for (var i = 0; i < 9; i++) {
      final ph = n.at1(i * 5.3);
      final x = 330 + n.at1(i * 2.7) * 360 + math.sin(t * 0.6 + ph * 6) * 30;
      final y = 1200 + n.at1(i * 9.1) * 130;
      final rx = 70 + n.at1(i * 4.4) * 90;
      final rect = Rect.fromCenter(
          center: Offset(x, y), width: rx * 2, height: rx * 0.66);
      c.drawOval(
        rect,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = RadialGradient(
            colors: [
              _arcane.fade(0.14),
              _arcane.darken(0.4).fade(0.06),
              _arcane.fade(0.0),
            ],
            stops: const [0.0, 0.5, 1.0],
          ).createShader(rect),
      );
    }
  }

  void _cape(Canvas c, double t, LightRig l, double detail) {
    final w = jitter(t, 3.3, amp: 1.4);
    // 밑단이 찢겨 갈라진 망토. 갈라짐 자체가 이 캐릭터의 성격이다.
    final tips = <double>[1290, 1330, 1250, 1344, 1268, 1320];
    final ring = <Offset>[
      const Offset(392, 596),
      Offset(300 + w * 4, 780),
      Offset(268 + w * 6, 1020),
    ];
    for (var i = 0; i < tips.length; i++) {
      final u = i / (tips.length - 1);
      ring.add(Offset(288 + u * 430 + w * (4 - u * 8), tips[i]));
      if (i < tips.length - 1) {
        ring.add(Offset(310 + (u + 0.08) * 430, 1180 - (i.isEven ? 30 : 0)));
      }
    }
    ring.addAll([
      Offset(742 - w * 6, 1010),
      Offset(706 - w * 4, 776),
      const Offset(606, 600),
      const Offset(500, 640),
    ]);
    final cape = smoothClosedPath(ring, tension: 0.8);

    castShadow(c, cape, offset: const Offset(12, 14), blur: 26, alpha: 0.55);
    paintSurface(c, cape, _sCloth, l, detail: detail, seed: 301);

    c.save();
    c.clipPath(cape);
    for (var i = 0; i < 8; i++) {
      final u = i / 7;
      final fold = smoothOpenPath([
        Offset(lerpD(404, 596, u), 606),
        Offset(lerpD(320, 690, u) + math.sin(u * 5.4) * 18, 960),
        Offset(lerpD(292, 726, u) + w * (u - 0.5) * 18, 1300),
      ]);
      c.drawPath(
        fold,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 28 - (u - 0.5).abs() * 20
          ..color = _rCloth.deep.fade(0.55)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
      );
      c.drawPath(
        fold.shift(const Offset(-12, 0)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9
          ..color = _arcane.fade(0.14)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
    }
    c.restore();
    rimBand(c, cape, l, width: 5, alpha: 0.55, color: _arcane.lighten(0.25));
  }

  void _legBack(Canvas c, LightRig l, double detail) {
    _leg(c, l, detail,
        hip: const Offset(550, 864),
        knee: const Offset(628, 1078),
        ankle: const Offset(648, 1286),
        toe: 1,
        dim: true);
  }

  void _legFront(Canvas c, LightRig l, double detail) {
    _leg(c, l, detail,
        hip: const Offset(464, 868),
        knee: const Offset(412, 1090),
        ankle: const Offset(400, 1296),
        toe: -1,
        dim: false);
  }

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
    final surf = dim ? _sLeather : _sLeatherLit;
    final thigh = limb(hip, lerpO(hip, knee, 0.5), knee,
        r0: 48, r1: 40, r2: 30, swell: 1.12);
    paintSurface(c, thigh, surf, l, detail: detail, seed: 311);

    final shin = limb(knee, lerpO(knee, ankle, 0.5), ankle,
        r0: 30, r1: 26, r2: 19, swell: 1.1);
    paintSurface(c, shin, surf, l, detail: detail, seed: 313);

    // 정강이 보호대: 가죽 스트랩 위에 얹은 좁은 강철 판.
    final guard = tube(
      [lerpO(knee, ankle, 0.12), lerpO(knee, ankle, 0.52), lerpO(knee, ankle, 0.86)],
      const [26, 23, 17],
      samples: 14,
    );
    paintSurface(c, guard, _sDark, l, detail: detail, seed: 317);
    c.save();
    c.clipPath(guard);
    for (var i = 0; i < 3; i++) {
      final u = 0.2 + i * 0.28;
      final p0 = lerpO(knee, ankle, u);
      final d = (ankle - knee).normalized().perp;
      panelLine(c, smoothOpenPath([p0 - d * 30, p0 + d * 30]), _rSteel, l,
          width: 5);
    }
    c.restore();

    final boot = bootShape(ankle + const Offset(0, 26), toe, 74, heel: 0.36);
    paintSurface(c, boot, _sLeather, l, detail: detail, seed: 319);
    c.save();
    c.clipPath(boot);
    for (var i = 0; i < 3; i++) {
      final y = ankle.dy + 14 + i * 14.0;
      c.drawLine(
        Offset(ankle.dx - toe * 44, y),
        Offset(ankle.dx + toe * 52, y - 4),
        Paint()
          ..strokeWidth = 4
          ..color = _rLeather.deep.fade(0.7),
      );
    }
    c.restore();
    rimBand(c, boot, l, width: 3.5, alpha: 0.4, color: _arcane);

    // 허벅지 스트랩과 투척 단검.
    if (!dim) {
      final strap = tube(
        [lerpO(hip, knee, 0.42) + const Offset(-46, 0),
          lerpO(hip, knee, 0.42) + const Offset(46, 4)],
        const [11, 11],
        samples: 8,
      );
      paintSurface(c, strap, _sWrap, l, detail: detail, seed: 321);
      for (var i = 0; i < 3; i++) {
        final base = lerpO(hip, knee, 0.34) + Offset(-40 + i * 26.0, -8);
        final knife = Path()
          ..moveTo(base.dx - 5, base.dy)
          ..lineTo(base.dx + 5, base.dy)
          ..lineTo(base.dx + 3, base.dy + 46)
          ..lineTo(base.dx, base.dy + 56)
          ..lineTo(base.dx - 3, base.dy + 46)
          ..close();
        paintSurface(c, knife, _sSteel, l, detail: 0, ao: false, seed: 323);
      }
    }
  }

  void _torso(Canvas c, LightRig l, double bob, double sway, double detail) {
    final chest = Offset(492 + sway * 0.4, 620 + bob);
    const pelvis = Offset(508, 868);

    final body = torsoShape(
      chest: chest,
      pelvis: pelvis,
      shoulderW: 120,
      chestW: 108,
      waistW: 82,
      hipW: 96,
      neckW: 32,
    );
    paintSurface(c, body, _sLeather, l, detail: detail, seed: 331);

    // 가슴을 가로지르는 가죽 하네스. 세 방향으로 뻗은 스트랩이 몸통의
    // 원통형 볼륨을 읽히게 해 준다.
    for (final rec in const [
      (Offset(-108, -34), Offset(96, 96)),
      (Offset(104, -30), Offset(-92, 100)),
    ]) {
      final strap = tube(
        [
          chest + rec.$1,
          chest + (rec.$1 + rec.$2) * 0.5 + const Offset(0, 6),
          chest + rec.$2,
        ],
        const [17, 19, 16],
        samples: 14,
      );
      paintSurface(c, strap, _sLeatherLit, l, detail: detail, seed: 333);
      occlude(c, strap, const Offset(0, -1), depth: 0.4, alpha: 0.5);
    }

    // 흉부 중앙의 룬 버클. 유일한 발광점이라 시선이 여기로 모인다.
    final buckle = smoothClosedPath([
      chest + const Offset(0, 22),
      chest + const Offset(30, 52),
      chest + const Offset(0, 86),
      chest + const Offset(-30, 52),
    ]);
    paintSurface(c, buckle, _sDark, l, detail: detail, seed: 335);
    c.drawPath(
      buckle,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..blendMode = BlendMode.plus
        ..color = _arcane.fade(0.85),
    );
    glowAt(c, chest + const Offset(0, 54), 40, _arcane, intensity: 0.55);

    // 허리띠와 파우치.
    final belt = Path()
      ..addRRect(RRect.fromRectAndCorners(
        Rect.fromCenter(center: pelvis + const Offset(0, -10), width: 196, height: 30),
        topLeft: const Radius.circular(12),
        topRight: const Radius.circular(12),
        bottomLeft: const Radius.circular(6),
        bottomRight: const Radius.circular(6),
      ));
    paintSurface(c, belt, _sLeatherLit, l, detail: detail, seed: 337);
    final pouch = blob(pelvis + const Offset(-74, 22), 30, 34,
        warp: (a, u) => 1 + math.sin(a * 3) * 0.06);
    paintSurface(c, pouch, _sLeather, l, detail: detail, seed: 339);

    c.save();
    c.clipPath(body);
    drawMuscleLine(c, [
      chest + const Offset(-70, 118),
      chest + const Offset(-20, 150),
      chest + const Offset(30, 150),
      chest + const Offset(74, 116),
    ], _rLeather, width: 12, alpha: 0.45);
    c.restore();

    inkOutline(c, body, const Color(0xFF0B0812), 3, alpha: 0.6);
    rimBand(c, body, l, width: 6, alpha: 0.6, color: _arcane.lighten(0.3));
  }

  void _armBack(Canvas c, LightRig l, double t, double bob, double detail) {
    final shoulder = Offset(600, 646 + bob * 0.7);
    final elbow = Offset(706, 726 + bob * 0.4);
    final wrist = Offset(686, 664 + bob * 0.2);

    final arm = limb(shoulder, elbow, wrist, r0: 38, r1: 28, r2: 20);
    paintSurface(c, arm, _sLeather, l, detail: detail, seed: 341);
    _bracer(c, l, elbow, wrist, detail, 343);

    // 역수로 쥔 단검이 팔뚝을 따라 아래로 뻗는다.
    _dagger(c, l, t, wrist + const Offset(-4, 8), 2.5, 1.18, detail);
    final hand = handShape(wrist, 1.9, 52, grip: 1.0, mirrored: true);
    paintSurface(c, hand, _sWrap, l, detail: detail, seed: 345);
    _shoulderPlate(c, l, shoulder, 1, detail);
  }

  void _armFront(Canvas c, LightRig l, double t, double bob, double detail) {
    final shoulder = Offset(384, 638 + bob * 0.7);
    final elbow = Offset(296, 776 + bob * 0.4);
    final wrist = Offset(372, 862 + bob * 0.2);

    final arm = limb(shoulder, elbow, wrist, r0: 40, r1: 30, r2: 21);
    paintSurface(c, arm, _sLeatherLit, l, detail: detail, seed: 351);
    _bracer(c, l, elbow, wrist, detail, 353);

    _dagger(c, l, t, wrist + const Offset(4, 10), 1.62, 1.28, detail);
    final hand = handShape(wrist, 0.9, 54, grip: 1.0);
    paintSurface(c, hand, _sWrap, l, detail: detail, seed: 355);
    c.save();
    c.clipPath(hand);
    drawKnuckles(c, wrist, 0.9, 54, Ramp.of(_wrap), l);
    c.restore();
    _shoulderPlate(c, l, shoulder, -1, detail);
  }

  void _bracer(
      Canvas c, LightRig l, Offset elbow, Offset wrist, double detail, int seed) {
    // 팔뚝 붕대 위에 강철 뱀브레이스.
    final wrapPath = tube(
      [lerpO(elbow, wrist, 0.42), lerpO(elbow, wrist, 0.96)],
      const [24, 20],
      samples: 10,
    );
    paintSurface(c, wrapPath, _sWrap, l, detail: detail, seed: seed);
    c.save();
    c.clipPath(wrapPath);
    final d = (wrist - elbow).normalized();
    final n = d.perp;
    for (var i = 0; i < 5; i++) {
      final p = lerpO(elbow, wrist, 0.46 + i * 0.11);
      c.drawLine(
        p - n * 28 - d * 4,
        p + n * 28 + d * 4,
        Paint()
          ..strokeWidth = 4
          ..color = Ramp.of(_wrap).deep.fade(0.55),
      );
    }
    c.restore();
    final plate = tube(
      [lerpO(elbow, wrist, 0.36), lerpO(elbow, wrist, 0.72)],
      const [25, 21],
      samples: 10,
    );
    paintSurface(c, plate, _sDark, l, detail: detail, seed: seed + 1);
    rimBand(c, plate, l, width: 3, alpha: 0.5, color: _arcane);
  }

  void _shoulderPlate(Canvas c, LightRig l, Offset at, double s, double detail) {
    final plate = blob(
      at + Offset(s * 12, -14),
      54,
      42,
      rotation: s * 0.3,
      warp: (a, u) => 1 + math.cos(a * 2 + s) * 0.14,
    );
    paintSurface(c, plate, _sDark, l, detail: detail, seed: 361);
    // 판 위의 각인. 얇은 선 세 줄이면 충분히 "장비"로 읽힌다.
    c.save();
    c.clipPath(plate);
    for (var i = 0; i < 3; i++) {
      c.drawPath(
        smoothOpenPath([
          at + Offset(s * (-30 + i * 8), -34 + i * 12),
          at + Offset(s * (34 - i * 6), -18 + i * 14),
        ]),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..blendMode = BlendMode.plus
          ..color = _arcane.fade(0.45 - i * 0.1),
      );
    }
    c.restore();
    rimBand(c, plate, l, width: 4, alpha: 0.7, color: _arcane.lighten(0.2));
  }

  /// 역수로 쥔 단검. [angle] 은 날이 향하는 방향(라디안).
  void _dagger(Canvas c, LightRig l, double t, Offset grip, double angle,
      double scale, double detail) {
    c.save();
    c.translate(grip.dx, grip.dy);
    c.rotate(angle);
    c.scale(scale);

    // 손잡이(뒤로), 가드, 날(앞으로).
    final handle = tube(
      const [Offset(-8, 0), Offset(-58, 0)],
      const [13, 11],
      samples: 8,
    );
    paintSurface(c, handle, _sLeather, l, detail: detail, seed: 371);

    final guard = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(2, 0), width: 16, height: 56),
        const Radius.circular(5),
      ));
    paintSurface(c, guard, _sDark, l, detail: detail, seed: 373);

    final blade = Path()
      ..moveTo(10, -15)
      ..lineTo(120, -9)
      ..lineTo(168, 0)
      ..lineTo(120, 10)
      ..lineTo(10, 16)
      ..close();
    paintSurface(c, blade, const Surface(Color(0xFF95A2BC), Finish.metal, contrast: 1.5),
        l, detail: detail, seed: 375);
    c.save();
    c.clipPath(blade);
    c.drawRect(
      const Rect.fromLTRB(0, -4, 170, 4),
      Paint()
        ..blendMode = BlendMode.plus
        ..color = const Color(0xFFDCE6FF).fade(0.35),
    );
    // 날에 흐르는 룬. 시간에 따라 밝기가 흐른다.
    for (var i = 0; i < 5; i++) {
      final x = 30.0 + i * 26;
      final pulse = 0.5 + 0.5 * math.sin(t * 2.4 - i * 0.8);
      c.drawCircle(
        Offset(x, 0),
        4,
        Paint()
          ..blendMode = BlendMode.plus
          ..color = _arcane.fade(0.3 + pulse * 0.55),
      );
    }
    c.restore();
    rimBand(c, blade, l, width: 2.5, alpha: 0.9, color: _arcane.lighten(0.4));
    glowPath(c, blade, _arcane, 14, alpha: 0.35);

    c.restore();
  }

  void _head(Canvas c, LightRig l, double t, double bob, double sway,
      double detail) {
    final hc = Offset(466 + sway, 412 + bob * 1.1);
    const hw = 68.0;
    const hh = 88.0;

    final neck = tube(
      [hc + const Offset(6, 56), hc + const Offset(16, 128)],
      const [30, 38],
      samples: 10,
    );
    paintSurface(c, neck, _sSkin, l, detail: detail, seed: 381);
    occlude(c, neck, const Offset(0, -1), depth: 0.6, alpha: 0.7);

    drawJawShadow(c, hc + const Offset(8, 92), hw * 1.5, hh * 0.48, _rSkin,
        alpha: 0.55);

    final head = headShape(hc, hw, hh, jaw: 0.72, chin: 0.28, turn: -0.25);
    paintSurface(c, head, _sSkin, l, detail: detail, seed: 383);

    // 얼굴 아래쪽을 덮는 복면.
    final mask = smoothClosedPath([
      hc + const Offset(-64, 16),
      hc + const Offset(0, 6),
      hc + const Offset(64, 18),
      hc + const Offset(58, 62),
      hc + const Offset(0, 96),
      hc + const Offset(-56, 60),
    ], tension: 0.85);
    paintSurface(c, mask, _sCloth, l, detail: detail, seed: 385);
    c.save();
    c.clipPath(mask);
    for (var i = 0; i < 4; i++) {
      c.drawPath(
        smoothOpenPath([
          hc + Offset(-60, 26 + i * 15.0),
          hc + Offset(0, 34 + i * 17.0),
          hc + Offset(60, 26 + i * 15.0),
        ]),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = _rCloth.deep.fade(0.6),
      );
    }
    c.restore();

    // 눈. 후드 그림자 속에서 발광한다.
    final eyeY = hc.dy - 6;
    drawEye(c, Offset(hc.dx - 32, eyeY), 25, 12,
        iris: const Color(0xFFB79BFF),
        light: l,
        look: -0.25,
        tilt: 0.08,
        glow: _arcane,
        scleraTint: const Color(0xFFBFB6D6));
    drawEye(c, Offset(hc.dx + 34, eyeY + 2), 23, 11,
        iris: const Color(0xFFB79BFF),
        light: l,
        look: -0.25,
        tilt: -0.06,
        mirrored: true,
        glow: _arcane,
        scleraTint: const Color(0xFFBFB6D6));
    drawBrow(c, Offset(hc.dx - 34, eyeY - 26), 30, 5,
        const Color(0xFF221A2A), arch: 0.18, angle: 0.16);
    drawBrow(c, Offset(hc.dx + 36, eyeY - 25), 28, 4.6,
        const Color(0xFF221A2A), arch: 0.18, angle: -0.14, mirrored: true);

    // 후드. 머리 뒤로 크게 돌아 목까지 이어진다.
    final hood = smoothClosedPath([
      hc + const Offset(-96, 26),
      hc + const Offset(-104, -52),
      hc + const Offset(-58, -116),
      hc + const Offset(14, -134),
      hc + const Offset(86, -104),
      hc + const Offset(110, -34),
      hc + const Offset(116, 58),
      hc + const Offset(76, 116),
      hc + const Offset(30, 92),
      hc + const Offset(48, 10),
      hc + const Offset(10, -48),
      hc + const Offset(-48, -34),
      hc + const Offset(-72, 24),
      hc + const Offset(-62, 96),
    ], tension: 0.82);
    paintSurface(c, hood, _sCloth, l, detail: detail, seed: 387);

    c.save();
    c.clipPath(hood);
    // 후드 안쪽 그늘. 얼굴 위로 떨어지는 어둠이 이 캐릭터의 정체성이다.
    c.drawPath(
      smoothClosedPath([
        hc + const Offset(-78, -30),
        hc + const Offset(10, -60),
        hc + const Offset(80, -20),
        hc + const Offset(60, 40),
        hc + const Offset(-56, 44),
      ]),
      Paint()
        ..color = const Color(0xFF090612).fade(0.62)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
    );
    for (var i = 0; i < 5; i++) {
      final u = i / 4;
      c.drawPath(
        smoothOpenPath([
          hc + Offset(lerpD(-96, 100, u), lerpD(20, 34, u)),
          hc + Offset(lerpD(-58, 70, u) * 1.1, -100 + u * 28),
        ]),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14
          ..color = _rCloth.deep.fade(0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
    }
    c.restore();

    // 얼굴 위로 드리운 후드 그늘을 한 겹 더. 눈만 남기고 잠긴다.
    c.save();
    c.clipPath(head);
    c.drawRect(
      head.getBounds(),
      Paint()
        ..blendMode = BlendMode.multiply
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF3E3A56),
            const Color(0xFF8C86A8),
            const Color(0xFFFFFFFF),
          ],
          stops: const [0.0, 0.34, 0.6],
        ).createShader(head.getBounds()),
    );
    c.restore();

    rimBand(c, hood, l, width: 6, alpha: 0.75, color: _arcane.lighten(0.35));
    inkOutline(c, hood, const Color(0xFF0A0714), 2.6, alpha: 0.6);
  }

  void _scarf(Canvas c, double t, LightRig l, double detail) {
    // 목에서 뒤로 날리는 천. 정지 포즈에 움직임을 넣는 유일한 요소다.
    for (var i = 0; i < 2; i++) {
      final spine = clothSpine(
        Offset(520 + i * 10.0, 560 + i * 14.0),
        Offset(0.86, -0.24 + i * 0.34),
        250 + i * 60.0,
        t,
        sway: 0.34,
        phase: i * 2.3,
        segments: 6,
        gravity: 0.5,
        flutter: 1.4,
      );
      final band = tube(
        spine,
        [26.0 - i * 6, 24.0 - i * 5, 20.0 - i * 4, 14.0 - i * 3, 8, 3],
        samples: 22,
      );
      paintSurface(c, band, _sCloth, l, detail: detail, seed: 391 + i);
      rimBand(c, band, l, width: 4, alpha: 0.6, color: _arcane.lighten(0.3));
    }
  }
}
