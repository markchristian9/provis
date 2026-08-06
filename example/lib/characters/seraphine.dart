import 'dart:math' as math;

import 'package:flutter/painting.dart';

import 'package:provis/provis.dart';

/// 세라핀 — 심연을 읽는 자.
///
/// 마법사는 옷과 빛으로 완성된다. 이 캐릭터에서 실제 신체가 차지하는 화면
/// 면적은 1/4 도 되지 않는다. 나머지는 전부 흐르는 로브, 부유하는 머리카락,
/// 뒤에서 도는 마법진이다. 대신 그 광원들이 전부 캐릭터 자신에게서 나오도록
/// 조명을 짜서, 화려함이 인물에게 되돌아오게 만들었다.
class Seraphine extends Artist {
  @override
  String get id => 'seraphine';
  @override
  String get name => 'Seraphine';
  @override
  String get title => 'Archmage of the Verge';
  @override
  String get blurb => '세계의 가장자리를 읽어 내는 창궁빛 대마법사.';
  @override
  Camp get camp => Camp.player;
  @override
  Sex get sex => Sex.female;
  @override
  CharacterBuild get build => CharacterBuild(
        archetype: Archetype.mage,
        sex: Sex.female,
        palette: paletteOf(
          skin: const Color(0xFFE0B49C),
          hair: const Color(0xFFCFF6FF),
          cloth: const Color(0xFF2A4A72),
          accent: const Color(0xFF57E8FF),
          metal: const Color(0xFF9BB0C6),
        ),
        weapon: WeaponKind.staff,
        headGear: HeadGear.none,
        hasCape: true,
        armorHeaviness: 0.04,
        hairLength: 0.95,
        muscle: 0.25,
        glowRunes: true,
      );
  @override
  Color get accent => const Color(0xFF57E8FF);
  @override
  LightRig get light => const LightRig(
        dir: Offset(-0.52, -0.85),
        rimDir: Offset(0.74, -0.67),
        key: Color(0xFFE6F4FF),
        fill: Color(0xFF2C5C86),
        rim: Color(0xFF7FE9FF),
        bounce: Color(0xFF2F7E9B),
        ambient: Color(0xFF141F38),
      );
  @override
  List<Color> get moodSky => const [
        Color(0xFF07101F),
        Color(0xFF14304C),
        Color(0xFF1E5E74),
      ];

  static const _robe = Color(0xFF20406F);
  static const _robeDeep = Color(0xFF16294A);
  static const _teal = Color(0xFF2F8C9E);
  static const _gold = Color(0xFFDFB65E);
  static const _hair = Color(0xFFD6E4F2);
  static const _skin = Color(0xFFEBCFB6);
  static const _mana = Color(0xFF57E8FF);

  Surface get _sRobe => const Surface(_robe, Finish.cloth, contrast: 1.1);
  Surface get _sRobeDeep =>
      const Surface(_robeDeep, Finish.cloth, contrast: 1.2);
  Surface get _sTeal => const Surface(_teal, Finish.cloth, contrast: 1.05);
  Surface get _sGold => const Surface(_gold, Finish.gold, contrast: 1.1);
  Surface get _sSkin => const Surface(_skin, Finish.skin, contrast: 0.85);
  Surface get _sHair => const Surface(_hair, Finish.hair, contrast: 0.95);

  Ramp get _rRobe => Ramp.of(_robe, contrast: 1.1);
  Ramp get _rGold => Ramp.of(_gold, contrast: 1.1);
  Ramp get _rSkin => Ramp.of(_skin, contrast: 0.85);

  @override
  void paint(Canvas c, double t, {double detail = 1.0}) {
    final l = light;
    final float = math.sin(t * 0.7) * 9; // 지면에서 떠 있는 부유
    final bob = breathe(t, speed: 0.8, amp: 2.4);

    _sigil(c, t, detail);
    groundShadow(c, Offset(500, 1330), 210, 30, alpha: 0.42);
    _manaPool(c, t);

    c.save();
    c.translate(0, float);

    _hairBack(c, t, l, detail);
    _skirt(c, t, l, detail);
    _armLeft(c, l, t, bob, detail);
    _torso(c, l, bob, detail);
    _mantle(c, l, bob, detail);
    _head(c, l, t, bob, detail);
    _armRight(c, l, t, bob, detail);
    _hairFront(c, t, l, detail);

    c.restore();

    if (detail > 0.4) {
      drawMotes(
        c,
        const Rect.fromLTWH(280, 500, 440, 800),
        t,
        _mana,
        count: 26,
        size: 5,
        speed: 34,
        seed: 5,
        drift: 0.7,
      );
    }
  }

  // 등 뒤의 마법진. 세 겹의 링이 서로 다른 속도로 돈다.
  void _sigil(Canvas c, double t, double detail) {
    const center = Offset(500, 520);
    c.save();
    c.drawCircle(
      center,
      330,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(
          colors: [
            _mana.fade(0.0),
            _mana.fade(0.05),
            _mana.fade(0.14),
            _mana.fade(0.0),
          ],
          stops: const [0.0, 0.55, 0.82, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: 330)),
    );

    for (var ring = 0; ring < 3; ring++) {
      final r = 190.0 + ring * 58;
      final spin = t * (0.18 - ring * 0.07) * (ring.isEven ? 1 : -1);
      c.save();
      c.translate(center.dx, center.dy);
      c.rotate(spin);
      c.drawCircle(
        Offset.zero,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = ring == 1 ? 3.0 : 1.4
          ..blendMode = BlendMode.plus
          ..color = _mana.fade(0.40 - ring * 0.09),
      );
      if (detail > 0.35) {
        final glyphs = 8 + ring * 6;
        for (var i = 0; i < glyphs; i++) {
          final a = i / glyphs * math.pi * 2;
          final p = Offset(math.cos(a), math.sin(a)) * r;
          c.save();
          c.translate(p.dx, p.dy);
          c.rotate(a + math.pi / 2);
          // 룬 한 글자. 선 세 개로 충분히 "문자"로 읽힌다.
          final gp = Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.4
            ..blendMode = BlendMode.plus
            ..color = _mana.fade(0.45 + math.sin(t * 2 + i) * 0.25);
          final s = 9.0 + ring * 2;
          c.drawLine(Offset(-s * 0.5, -s), Offset(s * 0.5, -s * 0.2), gp);
          c.drawLine(Offset(s * 0.5, -s * 0.2), Offset(-s * 0.4, s * 0.6), gp);
          c.drawLine(Offset(-s * 0.4, s * 0.6), Offset(s * 0.3, s), gp);
          c.restore();
        }
      }
      c.restore();
    }
    c.restore();
  }

  void _manaPool(Canvas c, double t) {
    // 발밑에 고인 마력. 부유 중임을 알려 주는 단서.
    final rect = Rect.fromCenter(
      center: const Offset(500, 1318),
      width: 420,
      height: 90,
    );
    c.drawOval(
      rect,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(
          colors: [_mana.fade(0.22), _mana.fade(0.07), _mana.fade(0.0)],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(rect),
    );
    for (var i = 0; i < 3; i++) {
      final k = (t * 0.4 + i / 3) % 1.0;
      c.drawOval(
        Rect.fromCenter(
          center: const Offset(500, 1318),
          width: 120 + k * 320,
          height: 26 + k * 68,
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..blendMode = BlendMode.plus
          ..color = _mana.fade(0.30 * (1 - k)),
      );
    }
  }

  // 종 모양으로 퍼지는 로브 하단. 밑단이 바닥에 닿지 않고 흩어진다.
  void _skirt(Canvas c, double t, LightRig l, double detail) {
    final w = jitter(t, 1.9, amp: 1.0);
    final hem = <Offset>[];
    const n = 9;
    for (var i = 0; i <= n; i++) {
      final u = i / n;
      final x = lerpD(298, 702, u);
      final y = 1272 +
          math.sin(u * math.pi * 3 + t * 1.1) * 26 +
          math.sin(u * math.pi + t * 0.6) * 14;
      hem.add(Offset(x, y));
    }
    final ring = <Offset>[
      const Offset(436, 700),
      Offset(392 + w * 3, 830),
      Offset(340 + w * 5, 1010),
      Offset(300 + w * 6, 1190),
      ...hem,
      Offset(700 - w * 6, 1190),
      Offset(660 - w * 5, 1010),
      Offset(608 - w * 3, 830),
      const Offset(564, 700),
    ];
    final skirt = smoothClosedPath(ring, tension: 0.85);

    castShadow(c, skirt, offset: const Offset(8, 12), blur: 24, alpha: 0.45);
    paintSurface(c, skirt, _sRobe, l, detail: detail, seed: 401);

    c.save();
    c.clipPath(skirt);
    // 주름. 허리 한 점에서 방사되어 밑단에서 벌어진다.
    for (var i = 0; i < 11; i++) {
      final u = i / 10;
      final fold = smoothOpenPath([
        Offset(lerpD(444, 556, u), 710),
        Offset(lerpD(360, 640, u) + math.sin(u * 7 + t) * 12, 1000),
        Offset(lerpD(304, 696, u) + w * (u - 0.5) * 16, 1290),
      ]);
      c.drawPath(
        fold,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 30 - (u - 0.5).abs() * 22
          ..color = _rRobe.deep.fade(0.45)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
      );
      c.drawPath(
        fold.shift(const Offset(-13, 0)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 11
          ..color = _rRobe.light.fade(0.28)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
      );
    }
    // 밑단이 빛으로 흩어진다.
    c.drawRect(
      const Rect.fromLTWH(280, 1120, 440, 240),
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_mana.fade(0.0), _mana.fade(0.30)],
        ).createShader(const Rect.fromLTWH(280, 1120, 440, 240)),
    );
    c.restore();

    // 금 자수 밑단.
    c.drawPath(
      smoothOpenPath(hem),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..color = _rGold.mid.fade(0.75),
    );
    rimBand(c, skirt, l, width: 6, alpha: 0.55, color: _mana);
  }

  void _torso(Canvas c, LightRig l, double bob, double detail) {
    final chest = Offset(500, 524 + bob);
    final pelvis = Offset(500, 754 + bob * 0.3);

    // 목과 쇄골이 드러나는 상의.
    final neck = tube(
      [chest + const Offset(0, -122), chest + const Offset(0, -58)],
      const [24, 34],
      samples: 10,
    );
    paintSurface(c, neck, _sSkin, l, detail: detail, seed: 403);
    occlude(c, neck, const Offset(0, -1), depth: 0.55, alpha: 0.6);

    drawJawShadow(c, chest + const Offset(0, -104), 96, 42, _rSkin,
        alpha: 0.5);

    final bodice = torsoShape(
      chest: chest,
      pelvis: pelvis,
      shoulderW: 96,
      chestW: 88,
      waistW: 60,
      hipW: 92,
      neckW: 26,
      bust: 16,
    );
    paintSurface(c, bodice, _sRobeDeep, l, detail: detail, seed: 405);

    c.save();
    c.clipPath(bodice);
    // 가슴 아래와 허리의 접힘. 여성 실루엣의 잘록함을 음영으로 보강한다.
    drawMuscleLine(
      c,
      [chest + const Offset(-64, 40), chest + const Offset(0, 62), chest + const Offset(64, 40)],
      _rRobe,
      width: 16,
      alpha: 0.5,
    );
    for (var i = 0; i < 5; i++) {
      final u = i / 4;
      c.drawPath(
        smoothOpenPath([
          chest + Offset(lerpD(-58, 58, u), 90),
          chest + Offset(lerpD(-40, 40, u), 190),
        ]),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9
          ..color = _rRobe.deep.fade(0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }
    c.restore();

    // 가슴 중앙의 금 자수 패널.
    final panel = smoothClosedPath([
      chest + const Offset(0, -34),
      chest + const Offset(34, 40),
      chest + const Offset(22, 176),
      chest + const Offset(0, 200),
      chest + const Offset(-22, 176),
      chest + const Offset(-34, 40),
    ]);
    paintSurface(c, panel, _sTeal, l, detail: detail, seed: 407);
    c.drawPath(
      panel,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = _rGold.mid.fade(0.85),
    );
    for (var i = 0; i < 4; i++) {
      final y = chest.dy + 20 + i * 42.0;
      c.drawCircle(
        Offset(chest.dx, y),
        7,
        Paint()..color = _rGold.light.fade(0.9),
      );
    }

    // 허리띠.
    final sash = tube(
      [pelvis + const Offset(-92, -22), pelvis + const Offset(0, -8), pelvis + const Offset(92, -22)],
      const [15, 19, 15],
      samples: 14,
    );
    paintSurface(c, sash, _sGold, l, detail: detail, seed: 409);
    // 늘어뜨린 띠 끝.
    final tail = tube(
      [pelvis + const Offset(56, -6), pelvis + const Offset(76, 90), pelvis + const Offset(60, 190)],
      const [13, 10, 4],
      samples: 16,
    );
    paintSurface(c, tail, _sTeal, l, detail: detail, seed: 411);

    rimBand(c, bodice, l, width: 5, alpha: 0.6, color: _mana);
  }

  // 어깨 망토. 목 뒤에서 팔 위로 덮이며 상체 실루엣을 넓힌다.
  void _mantle(Canvas c, LightRig l, double bob, double detail) {
    final y = 470 + bob;
    final mantle = smoothClosedPath([
      Offset(500, y - 44),
      Offset(596, y - 20),
      Offset(648, y + 44),
      Offset(636, y + 96),
      Offset(560, y + 70),
      Offset(500, y + 84),
      Offset(440, y + 70),
      Offset(364, y + 96),
      Offset(352, y + 44),
      Offset(404, y - 20),
    ], tension: 0.86);
    paintSurface(c, mantle, _sTeal, l, detail: detail, seed: 413);
    c.drawPath(
      mantle,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = _rGold.mid.fade(0.8),
    );
    c.save();
    c.clipPath(mantle);
    for (var i = 0; i < 7; i++) {
      final u = i / 6;
      c.drawPath(
        smoothOpenPath([
          Offset(lerpD(430, 570, u), y - 30),
          Offset(lerpD(360, 640, u), y + 92),
        ]),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..color = Ramp.of(_teal).deep.fade(0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
      );
    }
    c.restore();
    // 어깨 브로치.
    for (final s in const [-1.0, 1.0]) {
      final p = Offset(500 + s * 112, y + 26);
      c.drawCircle(p, 19, Paint()..color = _rGold.mid);
      c.drawCircle(p, 19,
          Paint()..style = PaintingStyle.stroke..strokeWidth = 3..color = _rGold.deep);
      c.drawCircle(p, 10, Paint()..color = _mana.fade(0.9));
      glowAt(c, p, 26, _mana, intensity: 0.5);
    }
    rimBand(c, mantle, l, width: 5, alpha: 0.6, color: _mana);
  }

  // 위로 들어 올린 오른팔과 그 위에 떠 있는 오브.
  void _armRight(Canvas c, LightRig l, double t, double bob, double detail) {
    final shoulder = Offset(590, 528 + bob);
    final elbow = Offset(676, 424 + bob * 0.6);
    final wrist = Offset(700, 296 + bob * 0.4);

    final sleeve = tube(
      [shoulder, lerpO(shoulder, elbow, 0.5), elbow],
      const [38, 32, 26],
      samples: 18,
    );
    paintSurface(c, sleeve, _sRobe, l, detail: detail, seed: 415);

    final fore = limb(elbow, lerpO(elbow, wrist, 0.5), wrist,
        r0: 26, r1: 22, r2: 17, swell: 1.05);
    paintSurface(c, fore, _sSkin, l, detail: detail, seed: 417);

    // 소매 끝 나팔. 팔 방향과 반대로 흘러내려 중력을 드러낸다.
    final cuff = smoothClosedPath([
      elbow + const Offset(-30, -10),
      elbow + const Offset(28, -14),
      elbow + const Offset(46, 62),
      elbow + const Offset(6, 92),
      elbow + const Offset(-40, 52),
    ], tension: 0.82);
    paintSurface(c, cuff, _sRobe, l, detail: detail, seed: 419);
    c.drawPath(
      smoothOpenPath([
        elbow + const Offset(-40, 52),
        elbow + const Offset(6, 92),
        elbow + const Offset(46, 62),
      ]),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = _rGold.mid.fade(0.8),
    );

    final hand = handShape(wrist, -1.25, 46, grip: 0.15, mirrored: true);
    paintSurface(c, hand, _sSkin, l, detail: detail, seed: 421);
    c.save();
    c.clipPath(hand);
    drawKnuckles(c, wrist, -1.25, 46, _rSkin, l, mirrored: true);
    c.restore();

    _orb(c, wrist + const Offset(12, -74), t);
  }

  void _armLeft(Canvas c, LightRig l, double t, double bob, double detail) {
    final shoulder = Offset(410, 532 + bob);
    final elbow = Offset(342, 668 + bob * 0.6);
    final wrist = Offset(330, 806 + bob * 0.3);

    final sleeve = tube(
      [shoulder, lerpO(shoulder, elbow, 0.5), elbow],
      const [38, 34, 28],
      samples: 18,
    );
    paintSurface(c, sleeve, _sRobe, l, detail: detail, seed: 423);

    final fore = limb(elbow, lerpO(elbow, wrist, 0.5), wrist,
        r0: 26, r1: 22, r2: 17, swell: 1.05);
    paintSurface(c, fore, _sSkin, l, detail: detail, seed: 425);

    // 아래로 늘어진 넓은 소매.
    final drape = smoothClosedPath([
      elbow + const Offset(-36, -22),
      elbow + const Offset(26, -18),
      elbow + const Offset(40, 74),
      elbow + const Offset(66, 168),
      elbow + const Offset(12, 192),
      elbow + const Offset(-48, 96),
    ], tension: 0.82);
    paintSurface(c, drape, _sRobe, l, detail: detail, seed: 427);
    c.save();
    c.clipPath(drape);
    for (var i = 0; i < 4; i++) {
      c.drawPath(
        smoothOpenPath([
          elbow + Offset(-30 + i * 22.0, -10),
          elbow + Offset(-10 + i * 26.0, 210),
        ]),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 12
          ..color = _rRobe.deep.fade(0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
      );
    }
    c.restore();
    rimBand(c, drape, l, width: 4, alpha: 0.5, color: _mana);

    // 손바닥을 위로 펼친 손과 그 위의 작은 룬.
    final hand = handShape(wrist, 1.5, 44, grip: 0.1);
    paintSurface(c, hand, _sSkin, l, detail: detail, seed: 429);
    if (detail > 0.4) {
      for (var i = 0; i < 3; i++) {
        final a = t * 1.4 + i / 3 * math.pi * 2;
        final p = wrist + Offset(math.cos(a) * 34, 40 + math.sin(a) * 12);
        glowAt(c, p, 13, _mana, intensity: 0.55 + math.sin(a) * 0.2);
      }
    }
  }

  /// 부유하는 마력 구체. 코어·궤도·잔광의 3층으로 만든다.
  void _orb(Canvas c, Offset at, double t) {
    final pulse = 0.5 + 0.5 * math.sin(t * 2.2);
    glowAt(c, at, 120, _mana, intensity: 0.42 + pulse * 0.18, star: true);

    // 궤도 링. 원근을 주려고 y 축을 눌러 그린다.
    for (var i = 0; i < 3; i++) {
      final a = t * (0.9 + i * 0.4) + i * 2.1;
      c.save();
      c.translate(at.dx, at.dy);
      c.rotate(a * 0.4 + i);
      c.drawOval(
        Rect.fromCenter(
            center: Offset.zero, width: 132 - i * 18, height: 46 - i * 8),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..blendMode = BlendMode.plus
          ..color = _mana.fade(0.55 - i * 0.12),
      );
      c.restore();
      final p = at +
          Offset(math.cos(a) * (60 - i * 8), math.sin(a) * (22 - i * 4));
      glowAt(c, p, 12, const Color(0xFFCFF6FF), intensity: 0.8);
    }

    final core = Path()..addOval(Rect.fromCircle(center: at, radius: 42));
    paintSurface(
      c,
      core,
      Surface(_mana, Finish.energy, glow: 0.9, glowColor: _mana),
      light,
    );
    c.drawCircle(
      at + const Offset(-13, -14),
      12,
      Paint()
        ..blendMode = BlendMode.plus
        ..color = white.fade(0.85),
    );
  }

  void _hairBack(Canvas c, double t, LightRig l, double detail) {
    // 뒤로 흐르는 큰 머리 덩어리. 부유감의 절반이 여기서 나온다.
    for (var i = 0; i < 5; i++) {
      final u = i / 4;
      final root = Offset(lerpD(432, 568, u), 300);
      final strand = hairStrand(
        root,
        Offset(lerpD(-0.55, 0.55, u), 0.82),
        330 + math.sin(u * math.pi) * 130,
        34 - (u - 0.5).abs() * 16,
        t,
        phase: i * 1.9,
        curl: 0.42,
        flutter: 0.9,
      );
      paintSurface(c, strand, _sHair, l, detail: detail * 0.5, seed: 431 + i);
      rimBand(c, strand, l, width: 4, alpha: 0.45, color: _mana);
    }
  }

  void _hairFront(Canvas c, double t, LightRig l, double detail) {
    for (var i = 0; i < 4; i++) {
      final u = i / 3;
      final side = i < 2 ? -1.0 : 1.0;
      final root = Offset(500 + side * lerpD(46, 74, (u * 2) % 1), 292);
      final strand = hairStrand(
        root,
        Offset(side * 0.34, 0.94),
        220 + u * 90,
        18 - u * 5,
        t,
        phase: i * 2.7 + 1.1,
        curl: 0.30,
        flutter: 0.7,
      );
      paintSurface(c, strand, _sHair, l, detail: detail * 0.5, seed: 441 + i);
      rimBand(c, strand, l, width: 3, alpha: 0.5, color: _mana);
    }
  }

  void _head(Canvas c, LightRig l, double t, double bob, double detail) {
    final hc = Offset(500, 346 + bob * 1.2);
    const hw = 66.0;
    const hh = 86.0;

    final head = headShape(hc, hw, hh,
        jaw: 0.60, chin: 0.24, turn: -0.05, cheek: 0.96);
    paintSurface(c, head, _sSkin, l, detail: detail, seed: 451);

    c.save();
    c.clipPath(head);
    // 부드러운 광대. 남성 캐릭터보다 음영을 얕게 둔다.
    drawMuscleLine(
      c,
      [hc + const Offset(-54, 10), hc + const Offset(-34, 44), hc + const Offset(-12, 58)],
      _rSkin,
      width: 14,
      alpha: 0.22,
    );
    drawMuscleLine(
      c,
      [hc + const Offset(54, 10), hc + const Offset(34, 44), hc + const Offset(12, 58)],
      _rSkin,
      width: 14,
      alpha: 0.2,
    );
    // 볼의 홍조.
    for (final s in const [-1.0, 1.0]) {
      c.drawCircle(
        hc + Offset(s * 42, 26),
        24,
        Paint()
          ..color = const Color(0xFFE08A7A).fade(0.22)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
      );
    }
    c.restore();

    final eyeY = hc.dy - 2;
    drawEye(c, Offset(hc.dx - 32, eyeY), 27, 16,
        iris: const Color(0xFF48D8E0),
        light: l,
        tilt: 0.06,
        glow: _mana.fade(0.5));
    drawEye(c, Offset(hc.dx + 33, eyeY), 27, 16,
        iris: const Color(0xFF48D8E0),
        light: l,
        tilt: -0.06,
        mirrored: true,
        glow: _mana.fade(0.5));
    drawBrow(c, Offset(hc.dx - 33, eyeY - 32), 27, 3.6,
        const Color(0xFF9BB0C6), arch: 0.5, angle: 0.06);
    drawBrow(c, Offset(hc.dx + 34, eyeY - 32), 27, 3.6,
        const Color(0xFF9BB0C6), arch: 0.5, angle: -0.06, mirrored: true);

    drawNose(c, Offset(hc.dx, eyeY + 8), 19, 34, _rSkin, l);
    drawMouth(c, Offset(hc.dx, hc.dy + 56), 22,
        skin: _rSkin, lip: const Color(0xFFC96A72), smile: 0.18);

    for (final s in const [-1.0, 1.0]) {
      final ear = earShape(Offset(hc.dx + s * 64, eyeY + 12), 13, 22,
          mirrored: s < 0, point: 0.35);
      paintSurface(c, ear, _sSkin, l, detail: detail, rim: false, seed: 453);
    }

    // 앞머리. 이마를 반쯤 덮어 서클렛 위로 흐른다.
    final fringe = smoothClosedPath([
      hc + const Offset(-70, 4),
      hc + const Offset(-74, -56),
      hc + const Offset(-34, -94),
      hc + const Offset(16, -100),
      hc + const Offset(62, -84),
      hc + const Offset(76, -34),
      hc + const Offset(70, 20),
      hc + const Offset(46, -22),
      hc + const Offset(6, -44),
      hc + const Offset(-30, -26),
      hc + const Offset(-56, -40),
    ], tension: 0.88);
    paintSurface(c, fringe, _sHair, l, detail: detail, seed: 455);

    // 서클렛과 이마의 보석.
    final circlet = smoothOpenPath([
      hc + const Offset(-72, -22),
      hc + const Offset(-36, -44),
      hc + const Offset(0, -50),
      hc + const Offset(36, -44),
      hc + const Offset(72, -22),
    ]);
    c.drawPath(
      circlet,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round
        ..color = _rGold.mid,
    );
    c.drawPath(
      circlet.shift(const Offset(-2, -3)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = _rGold.spec.fade(0.85),
    );
    final gem = Path()
      ..addOval(Rect.fromCenter(
          center: hc + const Offset(0, -50), width: 26, height: 32));
    paintSurface(c, gem, const Surface(_mana, Finish.gem, glow: 0.7), l);
    glowAt(c, hc + const Offset(0, -50), 40, _mana,
        intensity: 0.55 + math.sin(t * 1.7) * 0.15);

    rimBand(c, fringe, l, width: 5, alpha: 0.7, color: _mana);
    rimBand(c, head, l, width: 4, alpha: 0.5, color: _mana.lighten(0.2));
  }
}
