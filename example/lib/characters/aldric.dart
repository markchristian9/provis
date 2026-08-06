import 'dart:math' as math;

import 'package:flutter/painting.dart';

import 'package:provis/provis.dart';

/// 알드릭 — 여명의 수호자.
///
/// 판금 갑옷의 매력은 형태가 아니라 반사에서 나온다. 그래서 이 캐릭터는
/// 파츠를 잘게 쪼개는 데 공을 들였다. 흉갑·폴드론·뱀브레이스·쿠이스·그리브가
/// 각자 다른 각도로 놓여 있으면, 같은 조명 아래에서도 저마다 다른 밴딩이
/// 생기고 그 차이가 곧 "금속으로 뒤덮인 사람"이라는 인상을 만든다.
class Aldric extends Artist {
  @override
  String get id => 'aldric';
  @override
  String get name => 'Aldric';
  @override
  String get title => 'Dawnward of the Seventh Vigil';
  @override
  String get blurb => '맹세로 벼려진 판금과 꺼지지 않는 새벽빛의 성기사.';
  @override
  Camp get camp => Camp.player;
  @override
  Sex get sex => Sex.male;
  @override
  CharacterBuild get build => CharacterBuild(
        archetype: Archetype.paladin,
        sex: Sex.male,
        palette: paletteOf(
          skin: const Color(0xFFFFCF95),
          hair: const Color(0xFF4A3220),
          cloth: const Color(0xFF7A2620),
          accent: const Color(0xFFE8B84B),
          metal: const Color(0xFFC9B48A),
        ),
        weapon: WeaponKind.sword,
        headGear: HeadGear.circlet,
        hasShield: true,
        hasCape: true,
        hasPauldrons: true,
        armorHeaviness: 1.0,
        muscle: 0.75,
        glowRunes: true,
      );
  @override
  Color get accent => const Color(0xFFE8B84B);
  @override
  LightRig get light => const LightRig(
        dir: Offset(-0.60, -0.80),
        rimDir: Offset(0.82, -0.52),
        rim: Color(0xFFFFE1A8),
        bounce: Color(0xFF9A7A52),
      );
  @override
  List<Color> get moodSky => const [
        Color(0xFF20263F),
        Color(0xFF3B3350),
        Color(0xFF6E4B39),
      ];

  static const _steel = Color(0xFF8E99AE);
  static const _steelDark = Color(0xFF5C6478);
  static const _gold = Color(0xFFD8A33F);
  static const _cloak = Color(0xFFA02330);
  static const _leather = Color(0xFF4B3524);
  static const _skin = Color(0xFFD8A57E);
  static const _hair = Color(0xFF5E4028);
  static const _holy = Color(0xFFFFD98A);

  Surface get _sSteel => const Surface(_steel, Finish.metal, contrast: 1.2);
  Surface get _sSteelDark =>
      const Surface(_steelDark, Finish.metal, contrast: 1.15);
  Surface get _sGold => const Surface(_gold, Finish.gold, contrast: 1.15);
  Surface get _sCloak => const Surface(_cloak, Finish.cloth, contrast: 1.05);
  Surface get _sLeather => const Surface(_leather, Finish.leather);
  Surface get _sSkin => const Surface(_skin, Finish.skin, contrast: 0.9);

  Ramp get _rSteel => Ramp.of(_steel, contrast: 1.2);
  Ramp get _rGold => Ramp.of(_gold, contrast: 1.15);
  Ramp get _rCloak => Ramp.of(_cloak, contrast: 1.05);
  Ramp get _rSkin => Ramp.of(_skin, contrast: 0.9);

  @override
  void paint(Canvas c, double t, {double detail = 1.0}) {
    final l = light;
    final bob = breathe(t, speed: 0.85, amp: 3.4);
    final sway = jitter(t, 2.3, amp: 2.2);

    groundShadow(c, const Offset(505, 1330), 250, 42, alpha: 0.6);

    _halo(c, t, detail);
    _cloak_(c, t, l, detail);
    _legs(c, l, bob, detail);
    _torso(c, l, bob, sway, detail);
    _arms(c, l, bob, detail);
    _head(c, l, t, bob, sway, detail);
    // 검은 몸통보다 앞이다. 뒤에 두면 다리 사이로 사라져 버린다.
    _sword(c, l, t, detail);
    _hands(c, l, bob);

    if (detail > 0.5) {
      drawMotes(
        c,
        const Rect.fromLTWH(300, 620, 420, 700),
        t,
        _holy,
        count: 18,
        size: 4.5,
        speed: 26,
        seed: 11,
      );
    }
  }

  // 신성 후광. 캐릭터 뒤에서 도는 금빛 링과 룬.
  void _halo(Canvas c, double t, double detail) {
    const center = Offset(500, 330);
    c.save();
    c.drawCircle(
      center,
      210,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(
          colors: [
            _holy.fade(0.0),
            _holy.fade(0.16),
            _holy.fade(0.30),
            _holy.fade(0.0),
          ],
          stops: const [0.0, 0.62, 0.80, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: 210)),
    );

    final spin = t * 0.22;
    for (var ring = 0; ring < 2; ring++) {
      final r = 158.0 + ring * 26;
      final dir = ring.isEven ? 1.0 : -1.0;
      c.drawCircle(
        center,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = ring.isEven ? 3.2 : 1.6
          ..blendMode = BlendMode.plus
          ..color = _holy.fade(0.5 - ring * 0.2),
      );
      if (detail < 0.4) continue;
      final count = ring.isEven ? 14 : 22;
      for (var i = 0; i < count; i++) {
        final a = spin * dir + i / count * math.pi * 2;
        final p = center + Offset(math.cos(a), math.sin(a) * 0.34) * r;
        final depth = (math.sin(a) * 0.5 + 0.5);
        glowAt(c, p, 9 - ring * 3, _holy, intensity: 0.35 + depth * 0.5);
      }
    }
    c.restore();
  }

  // 진홍 망토. 어깨에서 흘러내려 지면에 닿으며 접힌다.
  void _cloak_(Canvas c, double t, LightRig l, double detail) {
    final w = jitter(t, 5.1, amp: 1.0);
    final outline = smoothClosedPath([
      const Offset(392, 528),
      Offset(322 + w * 3, 700),
      Offset(292 + w * 5, 950),
      Offset(286 + w * 7, 1180),
      Offset(330 + w * 6, 1318),
      const Offset(500, 1344),
      Offset(668 - w * 6, 1316),
      Offset(714 - w * 7, 1178),
      Offset(706 - w * 5, 948),
      Offset(676 - w * 3, 698),
      const Offset(612, 530),
      const Offset(500, 560),
    ], tension: 0.9);

    castShadow(c, outline, offset: const Offset(10, 16), blur: 22, alpha: 0.5);
    paintSurface(c, outline, _sCloak, l, detail: detail, seed: 21);

    c.save();
    c.clipPath(outline);
    // 주름은 어깨의 두 정점에서 방사한다. 접힘의 근원을 하나로 두면
    // 천이 실제로 매달려 있는 것처럼 읽힌다.
    for (var i = 0; i < 9; i++) {
      final u = i / 8;
      final top = Offset(lerpD(400, 604, u), lerpD(548, 552, u));
      final bottomX = lerpD(310, 690, u) + w * (u - 0.5) * 14;
      final fold = smoothOpenPath([
        top,
        Offset(lerpD(top.dx, bottomX, 0.4) + math.sin(u * 6.1) * 16, 880),
        Offset(bottomX, 1320),
      ]);
      c.drawPath(
        fold,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 26 - (u - 0.5).abs() * 18
          ..color = _rCloak.deep.fade(0.42)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
      );
      c.drawPath(
        fold.shift(const Offset(-14, 0)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 12
          ..color = _rCloak.light.fade(0.26)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
      );
    }
    // 안감. 젖혀진 부분에서 어두운 뒷면이 보인다.
    c.drawPath(
      smoothClosedPath([
        const Offset(392, 528),
        const Offset(430, 700),
        const Offset(452, 980),
        const Offset(430, 1290),
        const Offset(330, 1318),
        const Offset(300, 1000),
        const Offset(330, 690),
      ]),
      Paint()..color = _rCloak.deep.darken(0.25).fade(0.55),
    );
    c.restore();

    inkOutline(c, outline, _rCloak.deep.darken(0.4), 3, alpha: 0.5);
    rimBand(c, outline, l, width: 6, alpha: 0.5, color: const Color(0xFFFFB27A));
  }

  void _legs(Canvas c, LightRig l, double bob, double detail) {
    for (final side in const [-1, 1]) {
      final s = side.toDouble();
      final hip = Offset(500 + s * 50, 812 + bob * 0.3);
      final knee = Offset(500 + s * 66, 1062);
      final ankle = Offset(500 + s * 78, 1268);

      // 대퇴 갑옷(쿠이스).
      final thigh = limb(hip, lerpO(hip, knee, 0.5), knee,
          r0: 62, r1: 56, r2: 42, swell: 1.05);
      paintSurface(c, thigh, _sSteelDark, l, detail: detail, seed: 31 + side);

      // 정강이(그리브).
      final shin = limb(knee, lerpO(knee, ankle, 0.5), ankle,
          r0: 40, r1: 34, r2: 27, swell: 1.12);
      paintSurface(c, shin, _sSteel, l, detail: detail, seed: 41 + side);

      // 무릎 커터: 반구 + 금 테두리. 관절을 명확히 하는 실루엣 포인트.
      final knee1 = blob(knee + const Offset(0, -4), 46, 42,
          warp: (a, u) => 1 + math.cos(a * 2) * 0.10);
      paintSurface(c, knee1, _sSteel, l, detail: detail, seed: 51 + side);
      c.drawPath(
        knee1,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..color = _rGold.mid.fade(0.9),
      );
      c.save();
      c.clipPath(knee1);
      c.drawPath(
        smoothOpenPath([
          knee + Offset(-s * 30, 6),
          knee + Offset(0, -18),
          knee + Offset(s * 30, 6),
        ]),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..color = _rSteel.deep.fade(0.7),
      );
      c.restore();

      // 사바톤(강철 신발).
      final boot = bootShape(ankle + const Offset(0, 34), s, 78, heel: 0.42);
      paintSurface(c, boot, _sSteelDark, l, detail: detail, seed: 61 + side);
      c.save();
      c.clipPath(boot);
      for (var i = 0; i < 3; i++) {
        panelLine(
          c,
          smoothOpenPath([
            ankle + Offset(s * (18 + i * 22), 12 + i * 6),
            ankle + Offset(s * (26 + i * 24), 60),
          ]),
          _rSteel,
          l,
          width: 4,
        );
      }
      c.restore();

      // 그리브 세로 능선과 발목 이음매.
      c.save();
      c.clipPath(shin);
      panelLine(
        c,
        smoothOpenPath([knee + Offset(s * 4, 30), ankle + Offset(s * 6, -14)]),
        _rSteel,
        l,
        width: 5,
      );
      c.drawPath(
        smoothOpenPath([
          ankle + const Offset(-30, -18),
          ankle + const Offset(30, -14),
        ]),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..color = _rSteel.deep.fade(0.75),
      );
      c.restore();
    }

    // 태싯: 허리에서 대퇴를 덮는 판. 다리 위에 얹혀 골반을 넓게 만든다.
    for (final side in const [-1, 1]) {
      final s = side.toDouble();
      for (var i = 0; i < 3; i++) {
        final y = 828.0 + i * 34;
        final wHalf = 66.0 + i * 6;
        final plate = smoothClosedPath([
          Offset(500 + s * 14, y - 18),
          Offset(500 + s * (wHalf + 22), y - 6),
          Offset(500 + s * (wHalf + 26), y + 30),
          Offset(500 + s * 16, y + 40),
        ], tension: 0.7);
        paintSurface(c, plate, _sSteel, l, detail: detail, seed: 71 + i * 3);
        c.drawPath(
          plate,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = _rGold.shadow.fade(0.7),
        );
      }
    }
  }

  void _torso(Canvas c, LightRig l, double bob, double sway, double detail) {
    final chest = Offset(500 + sway * 0.3, 548 + bob);
    final pelvis = Offset(500, 815);

    // 사슬 갑옷 언더레이어. 판금 틈으로 보이는 층이 있어야 두께가 생긴다.
    final mail = torsoShape(
      chest: chest + const Offset(0, -14),
      pelvis: pelvis + const Offset(0, 26),
      shoulderW: 146,
      chestW: 132,
      waistW: 108,
      hipW: 118,
      neckW: 40,
    );
    paintSurface(c, mail, const Surface(Color(0xFF3A404E), Finish.metal),
        l, detail: detail, seed: 81);
    if (detail > 0.55) {
      c.save();
      c.clipPath(mail);
      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = const Color(0xFF9AA6BC).fade(0.35);
      for (var y = 520.0; y < 860; y += 11) {
        for (var x = 356.0; x < 650; x += 11) {
          c.drawCircle(
            Offset(x + (((y / 11).round()).isEven ? 0 : 5.5), y),
            4.4,
            ringPaint,
          );
        }
      }
      c.restore();
    }

    // 흉갑.
    final cuirass = torsoShape(
      chest: chest,
      pelvis: pelvis,
      shoulderW: 132,
      chestW: 126,
      waistW: 92,
      hipW: 100,
      neckW: 34,
    );
    paintSurface(c, cuirass, _sSteel, l, detail: detail, seed: 91);

    c.save();
    c.clipPath(cuirass);

    // 가슴 근육을 따라가는 판 분할. 중앙 능선이 빛을 갈라 놓는다.
    panelLine(
      c,
      smoothOpenPath([
        chest + const Offset(0, -18),
        chest + const Offset(2, 90),
        chest + const Offset(0, 190),
      ]),
      _rSteel,
      l,
      width: 7,
    );
    for (final s in const [-1.0, 1.0]) {
      panelLine(
        c,
        smoothOpenPath([
          chest + Offset(s * 122, -6),
          chest + Offset(s * 96, 74),
          chest + Offset(s * 22, 118),
        ]),
        _rSteel,
        l,
        width: 6,
      );
    }
    // 복부 라멜라.
    for (var i = 0; i < 4; i++) {
      final y = chest.dy + 150 + i * 30.0;
      panelLine(
        c,
        smoothOpenPath([
          Offset(500 - 96 + i * 5, y - 4),
          Offset(500, y + 6),
          Offset(500 + 96 - i * 5, y - 4),
        ]),
        _rSteel,
        l,
        width: 6,
      );
    }

    // 태양 문장. 이 캐릭터가 무엇을 섬기는지를 말하는 한 점.
    final emblem = chest + const Offset(0, 58);
    c.drawCircle(
      emblem,
      42,
      Paint()
        ..shader = RadialGradient(
          colors: [_rGold.spec, _rGold.mid, _rGold.deep],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromCircle(center: emblem, radius: 42)),
    );
    for (var i = 0; i < 12; i++) {
      final a = i / 12 * math.pi * 2;
      final d = Offset(math.cos(a), math.sin(a));
      c.drawPath(
        Path()
          ..moveTo(emblem.dx + d.dx * 40, emblem.dy + d.dy * 40)
          ..lineTo(emblem.dx + d.perp.dx * 9 + d.dx * 62,
              emblem.dy + d.perp.dy * 9 + d.dy * 62)
          ..lineTo(emblem.dx - d.perp.dx * 9 + d.dx * 62,
              emblem.dy - d.perp.dy * 9 + d.dy * 62)
          ..close(),
        Paint()..color = _rGold.mid.fade(0.92),
      );
    }
    c.drawCircle(emblem, 22, Paint()..color = _rGold.deep.fade(0.7));
    glowAt(c, emblem, 54, _holy, intensity: 0.4);

    c.restore();

    // 벨트.
    final belt = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: const Offset(500, 806), width: 214, height: 34),
        const Radius.circular(10),
      ));
    paintSurface(c, belt, _sLeather, l, detail: detail, seed: 101);
    final buckle = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: const Offset(500, 806), width: 62, height: 46),
        const Radius.circular(8),
      ));
    paintSurface(c, buckle, _sGold, l, detail: detail, seed: 103);

    // 목의 고짓.
    final gorget = smoothClosedPath([
      const Offset(432, 474),
      const Offset(500, 458),
      const Offset(568, 474),
      const Offset(574, 516),
      const Offset(500, 534),
      const Offset(426, 516),
    ]);
    paintSurface(c, gorget, _sSteelDark, l, detail: detail, seed: 105);

    inkOutline(c, cuirass, _rSteel.deep.darken(0.5), 2.4, alpha: 0.45);
  }

  void _arms(Canvas c, LightRig l, double bob, double detail) {
    for (final side in const [-1, 1]) {
      final s = side.toDouble();
      final shoulder = Offset(500 + s * 126, 566 + bob * 0.8);
      final elbow = Offset(500 + s * 168, 730);
      final wrist = Offset(500 + s * 42, 790 + (s > 0 ? 62 : 0));

      final upper = tube(
        [shoulder, lerpO(shoulder, elbow, 0.48), elbow],
        const [48, 42, 34],
        samples: 16,
      );
      paintSurface(c, upper, _sSteelDark, l, detail: detail, seed: 111 + side);

      // 뱀브레이스: 팔뚝을 감싸는 원통. 세로 하이라이트가 원통성을 만든다.
      final fore = tube(
        [elbow, lerpO(elbow, wrist, 0.5), wrist],
        [38, 32, 26],
        samples: 18,
      );
      paintSurface(c, fore, _sSteel, l, detail: detail, seed: 121 + side);
      c.save();
      c.clipPath(fore);
      panelLine(
        c,
        smoothOpenPath([
          lerpO(elbow, wrist, 0.1),
          lerpO(elbow, wrist, 0.9),
        ]),
        _rSteel,
        l,
        width: 5,
      );
      c.restore();

      // 폴드론: 3단 라멜라. 어깨는 실루엣에서 가장 크게 읽히는 곳이라
      // 여기에만 층을 세 겹 준다.
      for (var i = 0; i < 3; i++) {
        final r = 74.0 - i * 12;
        final cen = Offset(500 + s * (128 + i * 4), 556 + i * 30 + bob * 0.8);
        final plate = blob(
          cen,
          r,
          r * 0.74,
          rotation: s * 0.22,
          warp: (a, u) => 1 + math.cos(a + s * 0.5) * 0.12,
        );
        paintSurface(c, plate, i == 0 ? _sSteel : _sSteelDark, l,
            detail: detail, seed: 131 + i * 7 + side);
        c.drawPath(
          plate,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4 - i * 0.8
            ..color = _rGold.mid.fade(0.85 - i * 0.2),
        );
        if (i == 0) {
          rimBand(c, plate, l, width: 5, alpha: 0.65);
          // 폴드론 위 금색 날개 장식.
          final wing = smoothClosedPath([
            cen + Offset(-s * 40, -46),
            cen + Offset(s * 6, -78),
            cen + Offset(s * 54, -66),
            cen + Offset(s * 30, -40),
            cen + Offset(-s * 8, -34),
          ]);
          paintSurface(c, wing, _sGold, l, detail: detail, seed: 141 + side);
        }
      }
    }
  }

  void _hands(Canvas c, LightRig l, double bob) {
    // 위쪽 손(캐릭터의 오른손)이 자루 머리를, 아래쪽 손이 그립을 잡는다.
    final upper = handShape(const Offset(560, 790), math.pi * 0.86, 72,
        grip: 1.0, mirrored: true);
    final lower = handShape(const Offset(446, 862), math.pi * 0.12, 70,
        grip: 1.0);
    for (final rec in [
      (upper, const Offset(560, 790), math.pi * 0.86, true),
      (lower, const Offset(446, 862), math.pi * 0.12, false),
    ]) {
      paintSurface(c, rec.$1, _sSteel, l, seed: 151);
      c.save();
      c.clipPath(rec.$1);
      drawKnuckles(c, rec.$2, rec.$3, 70, _rSteel, l, mirrored: rec.$4);
      c.restore();
      inkOutline(c, rec.$1, _rSteel.deep.darken(0.4), 2.2, alpha: 0.5);
    }
    // 손목 이음쇠.
    for (final p in const [Offset(560, 790), Offset(446, 862)]) {
      c.drawCircle(p, 20, Paint()..color = _rGold.shadow.fade(0.8));
      c.drawCircle(
        p,
        20,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = _rGold.light.fade(0.8),
      );
    }
  }

  void _sword(Canvas c, LightRig l, double t, double detail) {
    const axis = 500.0;
    // 날. 중앙 풀러(홈) 때문에 하이라이트가 두 줄로 갈라진다.
    final blade = Path()
      ..moveTo(axis - 44, 906)
      ..lineTo(axis - 34, 1232)
      ..lineTo(axis, 1344)
      ..lineTo(axis + 34, 1232)
      ..lineTo(axis + 44, 906)
      ..close();
    castShadow(c, blade, offset: const Offset(14, 8), blur: 16, alpha: 0.4);
    paintSurface(c, blade, const Surface(Color(0xFFC3CEE0), Finish.metal, contrast: 1.35),
        l, detail: detail, seed: 161);
    c.save();
    c.clipPath(blade);
    c.drawRect(
      const Rect.fromLTRB(axis - 12, 900, axis + 12, 1340),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0x00000000), Color(0x99202838), Color(0x00000000)],
        ).createShader(const Rect.fromLTRB(axis - 12, 900, axis + 12, 1340)),
    );
    c.drawRect(
      const Rect.fromLTRB(axis - 48, 900, axis - 24, 1344),
      Paint()
        ..blendMode = BlendMode.plus
        ..color = const Color(0xFFFFF6E0).fade(0.40),
    );
    // 날에 새겨진 신성 룬.
    if (detail > 0.5) {
      for (var i = 0; i < 6; i++) {
        final y = 960.0 + i * 46;
        final pulse = 0.5 + 0.5 * math.sin(t * 1.8 - i * 0.6);
        c.drawCircle(
          Offset(axis, y),
          6,
          Paint()
            ..blendMode = BlendMode.plus
            ..color = _holy.fade(0.35 + pulse * 0.45),
        );
        c.drawLine(
          Offset(axis - 10, y + 10),
          Offset(axis + 10, y + 10),
          Paint()
            ..blendMode = BlendMode.plus
            ..strokeWidth = 3
            ..color = _holy.fade(0.2 + pulse * 0.3),
        );
      }
    }
    c.restore();
    rimBand(c, blade, l, width: 3.5, alpha: 0.8, color: const Color(0xFFFFF2D0));

    // 십자 가드.
    final guard = smoothClosedPath([
      const Offset(axis - 118, 898),
      const Offset(axis - 40, 880),
      const Offset(axis + 40, 880),
      const Offset(axis + 118, 898),
      const Offset(axis + 96, 918),
      const Offset(axis, 906),
      const Offset(axis - 96, 918),
    ], tension: 0.7);
    paintSurface(c, guard, _sGold, l, detail: detail, seed: 171);
    inkOutline(c, guard, _rGold.deep.darken(0.4), 2.4, alpha: 0.6);

    // 그립.
    final grip = tube(
      const [Offset(axis, 770), Offset(axis, 830), Offset(axis, 884)],
      const [17, 19, 17],
      samples: 12,
    );
    paintSurface(c, grip, _sLeather, l, detail: detail, seed: 181);
    c.save();
    c.clipPath(grip);
    for (var y = 776.0; y < 884; y += 13) {
      c.drawLine(
        Offset(axis - 22, y),
        Offset(axis + 22, y + 7),
        Paint()
          ..strokeWidth = 3
          ..color = const Color(0xFF20160F).fade(0.6),
      );
    }
    c.restore();

    // 폼멜과 그 안의 보석.
    final pommel = blob(const Offset(axis, 754), 30, 28,
        warp: (a, u) => 1 + math.cos(a * 4) * 0.05);
    paintSurface(c, pommel, _sGold, l, detail: detail, seed: 191);
    final gemP = Path()
      ..addOval(Rect.fromCenter(
          center: const Offset(axis, 752), width: 26, height: 30));
    paintSurface(c, gemP,
        const Surface(Color(0xFF3FA9FF), Finish.gem, glow: 0.6), l);
    glowAt(c, const Offset(axis, 752), 34, const Color(0xFF7CD0FF),
        intensity: 0.55);
  }

  void _head(Canvas c, LightRig l, double t, double bob, double sway,
      double detail) {
    final hc = Offset(500 + sway, 358 + bob * 1.2);
    const hw = 80.0;
    const hh = 102.0;

    // 목.
    final neck = tube(
      [hc + const Offset(2, 58), hc + const Offset(0, 112)],
      const [36, 46],
      samples: 10,
    );
    paintSurface(c, neck, _sSkin, l, detail: detail, seed: 201);
    occlude(c, neck, const Offset(0, -1), depth: 0.5, alpha: 0.6);
    drawJawShadow(c, hc + const Offset(2, 102), hw * 1.6, hh * 0.50, _rSkin,
        alpha: 0.62);
    // 승모근. 목이 어깨에서 솟았다는 연결을 만든다.
    for (final s in const [-1.0, 1.0]) {
      c.drawPath(
        smoothOpenPath([
          hc + Offset(s * 30, 96),
          hc + Offset(s * 66, 118),
          hc + Offset(s * 100, 138),
        ]),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 20
          ..strokeCap = StrokeCap.round
          ..color = _rSkin.shadow.fade(0.45)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
    }

    final head = headShape(hc, hw, hh, jaw: 0.82, chin: 0.36, turn: 0.12);
    paintSurface(c, head, _sSkin, l, detail: detail, seed: 211);

    c.save();
    c.clipPath(head);
    // 광대뼈와 턱 그림자로 남성적인 각을 만든다.
    drawMuscleLine(
      c,
      [hc + const Offset(-62, 4), hc + const Offset(-40, 42), hc + const Offset(-16, 58)],
      _rSkin,
      width: 18,
      alpha: 0.46,
    );
    drawMuscleLine(
      c,
      [hc + const Offset(62, 4), hc + const Offset(42, 44), hc + const Offset(18, 60)],
      _rSkin,
      width: 18,
      alpha: 0.40,
    );
    // 수염 자국.
    c.drawPath(
      smoothClosedPath([
        hc + const Offset(-56, 34),
        hc + const Offset(0, 26),
        hc + const Offset(56, 36),
        hc + const Offset(46, 76),
        hc + const Offset(0, 96),
        hc + const Offset(-46, 74),
      ]),
      Paint()
        ..color = const Color(0xFF3A2A22).fade(0.30)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );
    c.restore();

    // 눈.
    final eyeY = hc.dy + 4;
    drawEye(c, Offset(hc.dx - 34, eyeY), 27, 14,
        iris: const Color(0xFFC98A32), light: l, look: 0.12, tilt: 0.05);
    drawEye(c, Offset(hc.dx + 36, eyeY), 26, 13.5,
        iris: const Color(0xFFC98A32),
        light: l,
        look: 0.12,
        tilt: -0.05,
        mirrored: true);
    drawBrow(c, Offset(hc.dx - 36, eyeY - 32), 33, 4.4,
        const Color(0xFF4A3220), arch: 0.30, angle: 0.10);
    drawBrow(c, Offset(hc.dx + 38, eyeY - 33), 32, 4.2,
        const Color(0xFF4A3220), arch: 0.30, angle: -0.10, mirrored: true);

    drawNose(c, Offset(hc.dx + 2, eyeY + 8), 30, 48, _rSkin, l, turn: 0.15);
    drawMouth(c, Offset(hc.dx + 2, hc.dy + 70), 25,
        skin: _rSkin, smile: -0.10, turn: 0.15);

    // 귀.
    for (final s in const [-1.0, 1.0]) {
      final ear = earShape(Offset(hc.dx + s * 72, eyeY + 12), 15, 24,
          mirrored: s < 0);
      paintSurface(c, ear, _sSkin, l, detail: detail, rim: false, seed: 221);
    }

    // 머리카락: 덩어리 하나 + 가닥 몇 개. 이마 라인을 살짝 M 자로 판다.
    final hairMass = smoothClosedPath([
      hc + const Offset(-76, 6),
      hc + const Offset(-80, -58),
      hc + const Offset(-42, -100),
      hc + const Offset(6, -108),
      hc + const Offset(58, -96),
      hc + const Offset(80, -54),
      hc + const Offset(76, 8),
      hc + const Offset(58, -30),
      hc + const Offset(30, -44),
      hc + const Offset(-4, -36),
      hc + const Offset(-38, -46),
      hc + const Offset(-62, -26),
    ], tension: 0.86);
    paintSurface(c, hairMass, const Surface(_hair, Finish.hair, contrast: 1.15),
        l, detail: detail, seed: 231);
    if (detail > 0.4) {
      for (var i = 0; i < 7; i++) {
        final u = i / 6;
        final root = hc +
            Offset(lerpD(-58, 58, u), -56 - math.sin(u * math.pi) * 30);
        final strand = hairStrand(
          root,
          Offset(lerpD(-0.92, 0.92, u), 0.62 + math.sin(u * math.pi) * 0.30),
          46 + math.sin(u * math.pi) * 26,
          8.5,
          t,
          phase: i * 1.4,
          curl: 0.22,
          flutter: 0.22,
        );
        paintSurface(
            c, strand, Surface(_hair.lighten(0.08), Finish.hair), l,
            detail: 0, rim: false, ao: false);
      }
    }
    rimBand(c, hairMass, l, width: 5, alpha: 0.6, color: const Color(0xFFFFD9A0));
    rimBand(c, head, l, width: 4, alpha: 0.45, color: const Color(0xFFFFCF95));
  }
}
