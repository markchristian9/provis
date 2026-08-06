import 'dart:math' as math;

import 'package:flutter/painting.dart';

import 'package:provis/provis.dart';

/// 베스퍼 — 진공을 걷는 측량사.
///
/// 판타지 넷과 정반대의 문제를 푸는 캐릭터다. 갑옷이나 로브는 인체를 따라
/// 흐르지만 여압복은 인체를 가둔다. 그래서 여기서는 "옷 안에 사람이 있다"는
/// 사실을 실루엣이 아니라 **바이저 하나**로 증명하기로 했다. 화면에서 맨살이
/// 보이는 곳은 헬멧 창 안쪽 한 뼘뿐이고, 나머지 전부 — 부풀린 사지, 주름진
/// 관절, 등에 진 생명유지 장치 — 는 그 한 뼘을 살려 두기 위한 장치다.
///
/// 실루엣은 셋으로 읽힌다. 구(球)형 헬멧, 어깨 뒤로 솟은 상자, 마디마다
/// 굵어졌다 잘록해지는 사지. 흰 슈트 한 벌로 칠하면 이 셋이 뭉개지므로
/// 상체는 흰색, 하체는 중간 회색, 장비는 차콜로 값을 세 층으로 갈랐다.
class Vesper extends Artist {
  @override
  String get id => 'vesper';
  @override
  String get name => 'Vesper';
  @override
  String get title => 'Voidwalker of the Kestrel';
  @override
  String get blurb => '진공의 침묵을 걸어 미답의 궤도를 재는 EVA 항행사.';
  @override
  Camp get camp => Camp.player;
  @override
  Sex get sex => Sex.female;
  @override
  CharacterBuild get build => CharacterBuild(
        archetype: Archetype.knight,
        sex: Sex.female,
        palette: paletteOf(
          skin: const Color(0xFFE0DAD6),
          hair: const Color(0xFF4A3128),
          cloth: const Color(0xFF16283E),
          accent: const Color(0xFF44E0FF),
          metal: const Color(0xFF9FB4C4),
        ),
        weapon: WeaponKind.spear,
        headGear: HeadGear.fullHelm,
        hasPauldrons: true,
        armorHeaviness: 0.85,
        glowRunes: true,
      );
  @override
  Color get accent => const Color(0xFF44E0FF);

  /// 우주의 조명은 극단적이다. 대기 산란이 없어 키라이트는 거의 순백으로
  /// 꽂히고 그림자는 검게 죽는다. 그 검정을 메우는 것이 발밑 행성에서
  /// 올라오는 푸른 반사광(어스샤인)이며, 이 캐릭터의 아랫면은 전부 그 색이다.
  @override
  LightRig get light => const LightRig(
        dir: Offset(-0.60, -0.80),
        rimDir: Offset(0.82, -0.57),
        key: Color(0xFFFFFAEF),
        fill: Color(0xFF294B7A),
        rim: Color(0xFF7FE3FF),
        bounce: Color(0xFF2E6EA8),
        ambient: Color(0xFF080D19),
      );
  @override
  List<Color> get moodSky => const [
        Color(0xFF03050C),
        Color(0xFF0B1730),
        Color(0xFF17436A),
      ];

  static const _suit = Color(0xFFE2E8F1); // 상체 외피 — 값 위계의 맨 위
  static const _suitLow = Color(0xFF7C8AA0); // 하체 외피 — 중간 값
  static const _suitDeep = Color(0xFF586375); // 주름 관절과 그늘 패널
  static const _hard = Color(0xFFF0F4F9); // 하드셸 — 헬멧·어깨·무릎
  static const _hull = Color(0xFF2C333F); // 생명유지 장치 — 값의 맨 아래
  static const _steel = Color(0xFF8494AA); // 회전 베어링과 결합 링
  static const _gold = Color(0xFFE9B455); // 바이저 금 코팅
  static const _visor = Color(0xFF0E2A3A); // 바이저 유리 본색
  static const _hose = Color(0xFF232833);
  static const _skin = Color(0xFFEBC7A8);
  static const _hair = Color(0xFF54332A);
  static const _hud = Color(0xFF44E0FF);
  static const _warn = Color(0xFFFF7A3C);

  Surface get _sSuit => const Surface(_suit, Finish.cloth, contrast: 0.9);

  /// 사지의 외피. 몸통과 같은 천이지만 [Finish.cloth] 의 세로 섬유결이 원통에
  /// 얹히면 줄무늬 옷으로 읽히므로, 사지만 결이 없는 가죽 마감으로 칠한다.
  Surface get _sLimb => const Surface(_suit, Finish.leather, contrast: 0.92);
  Surface get _sLimbLow =>
      const Surface(_suitLow, Finish.leather, contrast: 1.0);
  Surface get _sFlex => const Surface(_suitDeep, Finish.cloth, contrast: 1.1);
  Surface get _sShell => const Surface(_hard, Finish.scale, contrast: 0.95);
  Surface get _sHull => const Surface(_hull, Finish.metal, contrast: 1.3);
  Surface get _sSteel => const Surface(_steel, Finish.metal, contrast: 1.18);
  Surface get _sHose => const Surface(_hose, Finish.leather, contrast: 1.15);
  Surface get _sSkin => const Surface(_skin, Finish.skin, contrast: 0.85);
  Surface get _sHair => const Surface(_hair, Finish.hair, contrast: 1.0);

  Ramp get _rSuit => Ramp.of(_suit, contrast: 0.9);
  Ramp get _rFlex => Ramp.of(_suitDeep, contrast: 1.1);
  Ramp get _rHull => Ramp.of(_hull, contrast: 1.3);
  Ramp get _rSteel => Ramp.of(_steel, contrast: 1.18);
  Ramp get _rSkin => Ramp.of(_skin, contrast: 0.85);
  Ramp get _rShell => Ramp.of(_hard, contrast: 0.95);

  // 손에 든 조명탄의 명멸. 여러 주파수를 겹쳐 전기 아크처럼 불규칙하게 만든다.
  double _flicker(double t) =>
      0.82 + math.sin(t * 13.1) * 0.11 + math.sin(t * 29.7) * 0.07;

  @override
  void paint(Canvas c, double t, {double detail = 1.0}) {
    final l = light;
    final bob = breathe(t, speed: 0.9, amp: 2.4);
    final sway = jitter(t, 3.7, amp: 1.6);

    groundShadow(c, const Offset(506, 1328), 236, 38, alpha: 0.62);

    _backpack(c, l, t, bob, detail);
    _leg(c, l, detail,
        hip: Offset(556 + sway * 0.3, 844),
        knee: const Offset(582, 1052),
        ankle: const Offset(598, 1236),
        toe: 1,
        dim: true,
        seed: 610);
    _arm(c, l, detail,
        shoulder: Offset(376 + sway * 0.4, 570 + bob * 0.7),
        elbow: Offset(318 + sway, 744 + bob * 0.3),
        wrist: Offset(342 + sway * 1.3, 898),
        gripAngle: math.pi * 0.44,
        capAngle: -0.3,
        grip: 0.55,
        dim: true,
        seed: 630);
    _torso(c, l, bob, sway, detail);
    _leg(c, l, detail,
        hip: Offset(452 + sway * 0.3, 848),
        knee: const Offset(430, 1058),
        ankle: const Offset(422, 1240),
        toe: -1,
        dim: false,
        seed: 650);
    _chestModule(c, l, t, bob, detail);
    _helmet(c, l, t, bob, sway, detail);
    _flareRod(c, l, bob);
    // 조명탄을 든 팔. 팔꿈치를 등의 장비 바깥까지 벌려야 상완과 전완이
    // 또렷한 V 를 이룬다 — 몸에 붙이면 팔 전체가 백팩에 먹힌다.
    _arm(c, l, detail,
        shoulder: Offset(618 + sway * 0.5, 566 + bob * 0.8),
        elbow: Offset(744 + sway * 0.8, 638 + bob * 0.4),
        wrist: Offset(744 + sway, 452 + bob * 0.2),
        gripAngle: -math.pi * 0.44,
        capAngle: 0.3,
        grip: 1.0,
        dim: false,
        seed: 670);
    _flareLight(c, t, _flicker(t), bob);

    if (detail > 0.4) {
      // 슈트에서 승화한 얼음 결정. 진공에서 수분이 곧장 기체가 되며 남는
      // 미세한 반짝임으로, 이 인물이 대기 밖에 있다는 유일한 환경 단서다.
      drawMotes(
        c,
        const Rect.fromLTWH(300, 560, 420, 760),
        t,
        _hud,
        count: 20,
        size: 4,
        speed: 30,
        seed: 17,
        drift: 0.8,
      );
    }
  }

  // ───────────────────────────────────────────── 생명유지 장치

  /// 어깨 뒤에 진 생명유지 장치.
  ///
  /// 이 캐릭터를 판타지 영웅과 갈라놓는 결정적인 덩어리다. 위치가 조금만
  /// 낮아도 "옆에 놓인 상자"로 읽히므로, 상단을 어깨선보다 확실히 높여
  /// 헬멧과 함께 하나의 상단 실루엣을 이루게 했다.
  void _backpack(Canvas c, LightRig l, double t, double bob, double detail) {
    final y = bob * 0.6;

    // 산소 탱크 두 개. 본체보다 먼저 그려 뒤로 물러나 보이게 한다.
    for (var i = 0; i < 2; i++) {
      final x = 668.0 + i * 28;
      final tank = tube(
        [Offset(x, 496 + y), Offset(x + 6, 620 + y), Offset(x + 8, 712 + y)],
        const [27, 29, 23],
        samples: 14,
      );
      paintSurface(c, tank, i == 0 ? _sSteel : _sHull, l,
          detail: detail, seed: 701 + i);
      rimBand(c, tank, l, width: 4, alpha: 0.5);
    }

    // 몸통 뒤 중앙에 얹는다. 오른쪽으로만 삐져나오되 왼쪽 어깨 뒤까지
    // 걸치게 해야 "등에 진 것"으로 읽힌다 — 옆에 붙이면 화물 상자가 된다.
    final body = smoothClosedPath([
      const Offset(444, 470),
      const Offset(566, 434),
      const Offset(664, 456),
      const Offset(700, 546),
      const Offset(698, 664),
      const Offset(648, 742),
      const Offset(534, 748),
      const Offset(438, 660),
    ], tension: 0.7);
    castShadow(c, body, offset: const Offset(-16, 18), blur: 26, alpha: 0.6);

    c.save();
    c.translate(0, y);
    paintSurface(c, body, _sHull, l, detail: detail, seed: 703);

    c.save();
    c.clipPath(body);
    // 방열판 핀. 등판 오른쪽의 얇은 판들이 상단 실루엣에 리듬을 준다.
    for (var i = 0; i < 5; i++) {
      final x = 600.0 + i * 20;
      panelLine(
        c,
        smoothOpenPath([Offset(x, 458), Offset(x + 8, 580), Offset(x + 6, 736)]),
        _rHull,
        l,
        width: 7,
        alpha: 0.8,
      );
    }
    // 상단 커버의 흰 패널. 차콜 덩어리를 그대로 두면 실루엣 안이 비어 보인다.
    final cover = smoothClosedPath([
      const Offset(448, 476),
      const Offset(564, 440),
      const Offset(656, 462),
      const Offset(630, 528),
      const Offset(458, 556),
    ], tension: 0.75);
    paintSurface(c, cover, _sShell, l, detail: detail, seed: 705);
    c.drawPath(
      cover,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = _rHull.deep.fade(0.75),
    );
    // 경고 스트라이프. 오렌지 한 줄이 흰색과 차콜 사이의 유일한 채도다.
    c.drawPath(
      smoothOpenPath([
        const Offset(474, 690),
        const Offset(576, 712),
        const Offset(682, 690),
      ]),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..color = _warn.fade(0.85),
    );
    // 상단면 하이라이트. 광원이 위에 있으므로 덮개의 윗면만 확실히 뜬다.
    c.drawOval(
      Rect.fromCenter(center: const Offset(552, 448), width: 210, height: 62),
      Paint()
        ..blendMode = BlendMode.plus
        ..color = l.key.fade(0.24)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
    );
    c.restore();

    // 통신 안테나. 상단 실루엣을 헬멧 밖으로 한 번 더 찢는다.
    final mast = tube(
      const [Offset(646, 452), Offset(682, 356), Offset(700, 276)],
      const [7, 5, 3.4],
      samples: 14,
    );
    paintSurface(c, mast, _sSteel, l, detail: 0.3, ao: false, seed: 707);
    final blink = math.sin(t * 2.6) * 0.5 + 0.5;
    glowAt(c, const Offset(702, 270), 20, _hud,
        intensity: 0.35 + blink * 0.55, star: blink > 0.7);

    // 자세 제어 노즐. 주기적으로 냉가스를 뿜어 정지 상태를 살린다.
    for (var i = 0; i < 2; i++) {
      final at = Offset(694.0, 604 + i * 56);
      final nozzle = smoothClosedPath([
        at + const Offset(-6, -12),
        at + const Offset(19, -18),
        at + const Offset(23, 18),
        at + const Offset(-6, 12),
      ]);
      paintSurface(c, nozzle, _sSteel, l, detail: detail, seed: 709 + i);

      final puff = (t * 0.42 + i * 0.5) % 1.0;
      if (puff < 0.22) {
        final k = puff / 0.22;
        final fade = math.sin(k * math.pi);
        c.drawPath(
          smoothClosedPath([
            at + Offset(21, -10 - k * 12),
            at + Offset(25 + k * 70, -6 - k * 26),
            at + Offset(23 + k * 84, 8 + k * 22),
            at + Offset(21, 10 + k * 12),
          ]),
          Paint()
            ..blendMode = BlendMode.plus
            ..color = _hud.fade(0.18 * fade)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 9 + k * 16),
        );
      }
    }

    rimBand(c, body, l, width: 6, alpha: 0.65, color: const Color(0xFFA8ECFF));
    c.restore();
  }

  // ───────────────────────────────────────────── 몸통

  void _torso(Canvas c, LightRig l, double bob, double sway, double detail) {
    final chest = Offset(504 + sway * 0.4, 566 + bob);
    final pelvis = Offset(498 + sway * 0.2, 846);

    // 여압복 몸통. 실제 EVA 슈트의 경성 흉곽은 잘록하지 않지만, 그렇게 그리면
    // 인물이 통 안에 든 화물처럼 읽힌다. 허리를 확실히 조이고 골반을 넓혀
    // 사람의 몸이 그 안에 있다는 것을 실루엣만으로 알 수 있게 했다.
    final suit = torsoShape(
      chest: chest,
      pelvis: pelvis,
      shoulderW: 130,
      chestW: 124,
      waistW: 72,
      hipW: 124,
      neckW: 48,
      bust: 12,
    );
    paintSurface(c, suit, _sSuit, l, detail: detail, seed: 611);

    c.save();
    c.clipPath(suit);
    // 옆구리의 그늘 패널. 원통형 몸통의 좌우 끝이 말려 들어가게 만든다.
    for (final s in const [-1.0, 1.0]) {
      c.drawPath(
        smoothOpenPath([
          chest + Offset(s * 116, 4),
          chest + Offset(s * 92, 130),
          chest + Offset(s * 108, 262),
        ]),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 36
          ..color = _rSuit.shadow.fade(0.55)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20),
      );
    }
    // 가슴 위 어깨끈. 흰 덩어리를 가로질러 상하를 나눈다.
    for (final s in const [-1.0, 1.0]) {
      c.drawPath(
        smoothOpenPath([
          chest + Offset(s * 96, -24),
          chest + Offset(s * 50, 60),
          chest + Offset(s * 26, 150),
        ]),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 21
          ..color = _suitDeep.fade(0.6),
      );
    }
    // 중앙 지퍼선.
    panelLine(
      c,
      smoothOpenPath([
        chest + const Offset(-4, 40),
        chest + const Offset(-12, 150),
        chest + const Offset(-6, 244),
      ]),
      _rSuit,
      l,
      width: 5,
    );
    c.restore();

    // 허리의 회전 베어링. 상체와 하체가 따로 도는 슈트의 구조를 드러내는
    // 동시에, 몸통에서 가장 잘록한 지점을 가로질러 허리를 명시한다.
    final waistRing = tube(
      [
        pelvis + const Offset(-72, -104),
        pelvis + const Offset(0, -98),
        pelvis + const Offset(72, -102),
      ],
      const [19, 22, 19],
      samples: 14,
    );
    paintSurface(c, waistRing, _sSteel, l, detail: detail, seed: 613);
    c.save();
    c.clipPath(waistRing);
    for (var i = 0; i < 9; i++) {
      final x = pelvis.dx - 66 + i * 17;
      c.drawLine(
        Offset(x, pelvis.dy - 124),
        Offset(x, pelvis.dy - 76),
        Paint()
          ..strokeWidth = 4
          ..color = _rSteel.deep.fade(0.55),
      );
    }
    c.restore();

    // 골반 브리프. 다리 두 개가 몸통에서 갈라지는 지점을 하드셸로 덮는다.
    final brief = smoothClosedPath([
      pelvis + const Offset(-108, -42),
      pelvis + const Offset(0, -50),
      pelvis + const Offset(108, -42),
      pelvis + const Offset(100, 26),
      pelvis + const Offset(42, 54),
      pelvis + const Offset(-44, 52),
      pelvis + const Offset(-102, 22),
    ], tension: 0.78);
    paintSurface(c, brief, _sLimbLow, l, detail: detail, seed: 615);
    occlude(c, brief, const Offset(0, -1), depth: 0.34, alpha: 0.5);
    c.save();
    c.clipPath(brief);
    // 허벅지가 갈라지는 사타구니 홈. 하체가 통짜로 읽히지 않게 한다.
    c.drawPath(
      smoothOpenPath([
        pelvis + const Offset(0, -18),
        pelvis + const Offset(2, 30),
        pelvis + const Offset(0, 58),
      ]),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..color = Ramp.of(_suitLow).deep.fade(0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    c.restore();

    // 임무 패치와 이름표. 크기 위계의 맨 아래 — 가까이 봤을 때만 보이는 층.
    if (detail > 0.5) {
      final patch = blob(chest + const Offset(78, 112), 25, 25,
          warp: (a, u) => 1 + math.cos(a * 5) * 0.06);
      paintSurface(c, patch, const Surface(Color(0xFF1B2C4A), Finish.cloth), l,
          detail: detail, rim: false, seed: 619);
      c.drawPath(
        patch,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = _hud.fade(0.75),
      );
      c.drawCircle(
        chest + const Offset(78, 112),
        10,
        Paint()
          ..blendMode = BlendMode.plus
          ..color = _hud.fade(0.4),
      );
      for (var i = 0; i < 3; i++) {
        c.drawLine(
          chest + Offset(-104, 150 + i * 9.0),
          chest + Offset(-104 + (i == 2 ? 30.0 : 46.0), 150 + i * 9.0),
          Paint()
            ..strokeWidth = 4
            ..color = _rSuit.deep.fade(0.45),
        );
      }
    }

    rimBand(c, suit, l, width: 5, alpha: 0.5, color: const Color(0xFF9FE9FF));
  }

  /// 가슴의 제어 모듈과 백팩에서 넘어오는 급기 호스.
  ///
  /// 헬멧 다음으로 시선을 붙잡는 곳이다. 흰 덩어리 한가운데에 유일하게
  /// 어둡고 복잡한 영역을 두어 대비를 만들되, 허리를 덮지 않도록 위로 붙였다.
  void _chestModule(Canvas c, LightRig l, double t, double bob, double detail) {
    final y = bob;

    // 호스 두 가닥. 어깨 위를 넘어 앞으로 돌아 들어온다.
    for (var i = 0; i < 2; i++) {
      final sag = math.sin(t * 1.1 + i * 1.9) * 4;
      final spine = [
        Offset(596 + i * 22.0, 502 + y),
        Offset(622 + i * 16.0, 548 + y + sag),
        Offset(576 + i * 12.0, 592 + y + sag),
        Offset(516 + i * 24.0, 608 + y),
      ];
      final hosePath = tube(spine, const [14, 15, 14, 12], samples: 20);
      castShadow(c, hosePath, offset: const Offset(-6, 10), blur: 12, alpha: 0.45);
      paintSurface(c, hosePath, _sHose, l, detail: detail, seed: 721 + i);
      c.save();
      c.clipPath(hosePath);
      // 주름 호스의 마디. 굵기가 일정한 관은 즉시 플라스틱 빨대로 보인다.
      final poly = smoothPolyline(spine, 26);
      for (var j = 1; j < poly.length - 1; j += 2) {
        final d = (poly[j + 1] - poly[j - 1]).normalized();
        final n = d.perp;
        c.drawLine(
          poly[j] - n * 18,
          poly[j] + n * 18,
          Paint()
            ..strokeWidth = 3.2
            ..color = Ramp.of(_hose, contrast: 1.15).deep.fade(0.75),
        );
      }
      c.restore();
      rimBand(c, hosePath, l, width: 3, alpha: 0.45);
    }

    // 제어 모듈 본체.
    final box = smoothClosedPath([
      Offset(428, 596 + y),
      Offset(552, 588 + y),
      Offset(564, 626 + y),
      Offset(558, 676 + y),
      Offset(490, 692 + y),
      Offset(430, 678 + y),
      Offset(418, 630 + y),
    ], tension: 0.72);
    castShadow(c, box, offset: const Offset(4, 12), blur: 16, alpha: 0.55);
    paintSurface(c, box, _sHull, l, detail: detail, seed: 723);

    c.save();
    c.clipPath(box);
    // 상태 디스플레이. 스캔라인이 위아래로 흐른다.
    final screen = Rect.fromLTWH(438, 606 + y, 74, 36);
    c.drawRRect(
      RRect.fromRectAndRadius(screen, const Radius.circular(5)),
      Paint()..color = const Color(0xFF06202C),
    );
    c.drawRRect(
      RRect.fromRectAndRadius(screen, const Radius.circular(5)),
      Paint()
        ..blendMode = BlendMode.plus
        ..color = _hud.fade(0.22),
    );
    for (var i = 0; i < 3; i++) {
      final w = 22.0 + (i * 17) % 36;
      c.drawLine(
        Offset(444, 615 + y + i * 10.0),
        Offset(444 + w, 615 + y + i * 10.0),
        Paint()
          ..strokeWidth = 3
          ..blendMode = BlendMode.plus
          ..color = _hud.fade(0.7),
      );
    }
    final scan = (t * 0.6 % 1.0) * 36;
    c.drawLine(
      Offset(438, 606 + y + scan),
      Offset(512, 606 + y + scan),
      Paint()
        ..strokeWidth = 2
        ..blendMode = BlendMode.plus
        ..color = _hud.fade(0.5),
    );

    // 스위치와 게이지. 손으로 조작하는 물건이라는 것을 알리는 층.
    for (var i = 0; i < 3; i++) {
      final at = Offset(528 + (i % 2) * 24.0, 608 + y + (i ~/ 2) * 24.0);
      c.drawCircle(at, 8.5, Paint()..color = _rSteel.mid);
      c.drawCircle(
        at,
        8.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = _rHull.deep.fade(0.8),
      );
      c.drawLine(
        at,
        at + const Offset(0, -6).rotated(i * 1.1),
        Paint()
          ..strokeWidth = 2.6
          ..color = _rSteel.deep,
      );
    }
    for (var i = 0; i < 4; i++) {
      final at = Offset(444 + i * 20.0, 664 + y);
      final on = ((t * 1.7).floor() + i) % 4 != 0;
      c.drawCircle(at, 5.5, Paint()..color = const Color(0xFF10161F));
      c.drawCircle(
        at,
        4,
        Paint()
          ..blendMode = BlendMode.plus
          ..color = (i == 3 ? _warn : _hud).fade(on ? 0.9 : 0.25),
      );
    }
    c.restore();

    inkOutline(c, box, _rHull.deep.darken(0.35), 2.6, alpha: 0.55);
    rimBand(c, box, l, width: 4, alpha: 0.6, color: const Color(0xFFA8ECFF));
  }

  // ───────────────────────────────────────────── 사지

  /// 여압복의 주름 관절.
  ///
  /// 부풀린 슈트가 굽을 수 있는 유일한 방법이며, 이 링 무늬가 없으면 팔다리가
  /// 그냥 두꺼운 소매로 읽힌다. 관절 위치를 눈에 보이게 만드는 장치이기도 하다.
  Path _joint(
    Canvas c,
    LightRig l,
    Offset a,
    Offset b,
    double r,
    int rings,
    double detail,
    int seed, {
    bool dim = false,
  }) {
    final p = tube(
      [a, lerpO(a, b, 0.5), b],
      [r * 0.94, r * 1.05, r * 0.94],
      samples: 16,
    );
    final s = dim ? _sFlex.tinted(const Color(0xFF0A1020), 0.3) : _sFlex;
    paintSurface(c, p, s, l, detail: detail, seed: seed);

    c.save();
    c.clipPath(p);
    final d = (b - a).normalized();
    final n = d.perp;
    for (var i = 0; i < rings; i++) {
      final u = (i + 0.5) / rings;
      final q = lerpO(a, b, u);
      // 홈은 어둡고, 그 바로 위 마루는 빛을 받는다. 두 줄이 한 쌍이다.
      c.drawPath(
        smoothOpenPath([
          q - n * (r * 1.35),
          q + d * (r * 0.10),
          q + n * (r * 1.35),
        ]),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.28
          ..color = _rFlex.deep.fade(0.7),
      );
      c.drawPath(
        smoothOpenPath([
          q - n * (r * 1.3) - d * (r * 0.20),
          q - d * (r * 0.10),
          q + n * (r * 1.3) - d * (r * 0.20),
        ]),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.15
          ..color = _rFlex.light.fade(0.5)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.12),
      );
    }
    c.restore();
    return p;
  }

  /// 팔 하나. 어깨 하드셸까지 여기서 그려야 팔과 캡이 절대 어긋나지 않는다.
  void _arm(
    Canvas c,
    LightRig l,
    double detail, {
    required Offset shoulder,
    required Offset elbow,
    required Offset wrist,
    required double gripAngle,
    required double capAngle,
    required double grip,
    required bool dim,
    required int seed,
  }) {
    Surface shade(Surface s) =>
        dim ? s.tinted(const Color(0xFF0A1020), 0.32) : s;

    // 상완. 어깨 쪽이 굵고 팔꿈치로 갈수록 좁아진다.
    final upperEnd = lerpO(shoulder, elbow, 0.66);
    final upper = tube(
      [shoulder, lerpO(shoulder, elbow, 0.35), upperEnd],
      const [44, 40, 34],
      samples: 16,
    );
    // 앞팔은 등의 장비 위를 지난다. 그림자를 깔지 않으면 팔과 백팩이 한
    // 덩어리로 붙어 어디까지가 팔인지 읽히지 않는다.
    if (!dim) {
      castShadow(c, upper, offset: const Offset(-12, 16), blur: 18, alpha: 0.5);
    }
    paintSurface(c, upper, shade(_sLimb), l, detail: detail, seed: seed);

    _joint(c, l, upperEnd, lerpO(elbow, wrist, 0.16), 33, 4, detail, seed + 1,
        dim: dim);

    // 전완.
    final foreStart = lerpO(elbow, wrist, 0.14);
    final foreEnd = lerpO(elbow, wrist, 0.88);
    final fore = tube(
      [foreStart, lerpO(foreStart, foreEnd, 0.5), foreEnd],
      const [32, 30, 27],
      samples: 16,
    );
    paintSurface(c, fore, shade(_sLimb), l, detail: detail, seed: seed + 2);

    // 팔뚝의 체크리스트 커프. 실제 EVA 에서 손목에 차는 작업 순서표다.
    if (!dim && detail > 0.4) {
      final cuff = tube(
        [lerpO(elbow, wrist, 0.40), lerpO(elbow, wrist, 0.66)],
        const [29, 27],
        samples: 10,
      );
      paintSurface(c, cuff, _sShell, l, detail: detail, seed: seed + 3);
      c.save();
      c.clipPath(cuff);
      final d = (wrist - elbow).normalized();
      final n = d.perp;
      for (var i = 0; i < 4; i++) {
        final q = lerpO(elbow, wrist, 0.43 + i * 0.06);
        c.drawLine(
          q - n * 21,
          q + n * 15,
          Paint()
            ..strokeWidth = 3
            ..color = _rShell.deep.fade(0.6),
        );
      }
      c.restore();
    }

    // 손목 결합 링과 장갑.
    final ring = tube(
      [lerpO(elbow, wrist, 0.90), wrist],
      const [28, 26],
      samples: 10,
    );
    paintSurface(c, ring, shade(_sSteel), l, detail: detail, seed: seed + 4);

    final glove = handShape(wrist, gripAngle, 46, grip: grip, mirrored: dim);
    paintSurface(c, glove, shade(_sShell), l, detail: detail, seed: seed + 5);
    c.save();
    c.clipPath(glove);
    drawKnuckles(c, wrist, gripAngle, 46, _rShell, l, mirrored: dim);
    // 손바닥의 그립 패드.
    c.drawCircle(
      wrist + Offset(math.cos(gripAngle), math.sin(gripAngle)) * 24,
      13,
      Paint()..color = _rHull.shadow.fade(0.65),
    );
    c.restore();

    // 어깨 하드셸. 상완 위에 얹어 팔과 몸통의 이음매를 덮는다. 조금만 높이
    // 붙여도 즉시 몸에서 떨어진 견장으로 보이므로 어깨 관절에 바싹 앉힌다.
    final at = shoulder + Offset(capAngle * 24, -12);
    final cap = blob(at, 56, 44,
        rotation: capAngle * 0.7, warp: (a, u) => 1 + math.cos(a * 2) * 0.10);
    paintSurface(c, cap, shade(_sShell), l, detail: detail, seed: seed + 6);
    c.save();
    c.clipPath(cap);
    // 상단면. 어깨 윗면이 하늘을 향하므로 여기만 확실히 밝다.
    c.drawOval(
      Rect.fromCenter(center: at + const Offset(-4, -26), width: 130, height: 44),
      Paint()
        ..blendMode = BlendMode.plus
        ..color = l.key.fade(dim ? 0.12 : 0.26)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
    );
    c.drawPath(
      smoothOpenPath([
        at + const Offset(-42, 0),
        at + const Offset(0, 10),
        at + const Offset(42, -2),
      ]),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..color = (dim ? _warn : _hud).fade(dim ? 0.55 : 0.8),
    );
    c.restore();
    // 캡 아래로 떨어지는 접촉 그림자. 이 한 겹이 없으면 팔이 종이처럼 붙는다.
    occlude(c, upper, const Offset(0, -1), depth: 0.28, alpha: 0.5);

    rimBand(c, cap, l, width: 4.5, alpha: dim ? 0.35 : 0.6,
        color: const Color(0xFFCFF2FF));
    rimBand(c, fore, l, width: 4, alpha: dim ? 0.35 : 0.55,
        color: const Color(0xFFA8ECFF));
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
    required int seed,
  }) {
    Surface shade(Surface s) =>
        dim ? s.tinted(const Color(0xFF0A1020), 0.34) : s;

    final thighEnd = lerpO(hip, knee, 0.70);
    final thigh = tube(
      [hip, lerpO(hip, knee, 0.36), thighEnd],
      const [48, 43, 36],
      samples: 16,
    );
    paintSurface(c, thigh, shade(_sLimbLow), l, detail: detail, seed: seed);

    _joint(c, l, thighEnd, lerpO(knee, ankle, 0.12), 36, 3, detail, seed + 1,
        dim: dim);

    // 무릎 보호대. 관절 앞면만 덮어 실루엣에 각을 하나 만든다.
    final pad = smoothClosedPath([
      knee + Offset(toe * 8 - 40, -26),
      knee + Offset(toe * 28 + 14, -32),
      knee + Offset(toe * 34 + 20, 20),
      knee + Offset(toe * 8 - 34, 26),
    ], tension: 0.7);
    paintSurface(c, pad, shade(_sShell), l, detail: detail, seed: seed + 2);
    c.save();
    c.clipPath(pad);
    c.drawPath(
      smoothOpenPath([
        knee + Offset(toe * 6 - 26, 6),
        knee + Offset(toe * 12, -10),
        knee + Offset(toe * 24 + 12, 6),
      ]),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = _rShell.deep.fade(0.6),
    );
    c.restore();

    final shinStart = lerpO(knee, ankle, 0.10);
    final shin = tube(
      [shinStart, lerpO(shinStart, ankle, 0.5), ankle],
      const [34, 31, 27],
      samples: 16,
    );
    paintSurface(c, shin, shade(_sLimbLow), l, detail: detail, seed: seed + 3);

    // 발목 링.
    final ankleRing = tube(
      [lerpO(knee, ankle, 0.92), ankle + const Offset(0, 8)],
      const [28, 26],
      samples: 10,
    );
    paintSurface(c, ankleRing, shade(_sSteel), l, detail: detail, seed: seed + 4);

    // 부츠. 밑창을 두껍게 잡아 지면과의 접촉면을 확실히 만든다.
    final boot = bootShape(ankle + const Offset(0, 40), toe, 78, heel: 0.46);
    paintSurface(c, boot, shade(_sShell), l, detail: detail, seed: seed + 5);
    c.save();
    c.clipPath(boot);
    c.drawRect(
      Rect.fromLTRB(ankle.dx - 90, ankle.dy + 68, ankle.dx + 90, ankle.dy + 100),
      Paint()..color = _rHull.shadow,
    );
    for (var i = 0; i < 5; i++) {
      final x = ankle.dx + toe * (8 + i * 13.0);
      c.drawLine(
        Offset(x, ankle.dy + 70),
        Offset(x, ankle.dy + 94),
        Paint()
          ..strokeWidth = 4
          ..color = _rHull.deep.fade(0.85),
      );
    }
    // 발등의 상단면 하이라이트.
    c.drawOval(
      Rect.fromCenter(
        center: ankle + Offset(toe * 22, 40),
        width: 80,
        height: 26,
      ),
      Paint()
        ..blendMode = BlendMode.plus
        ..color = l.key.fade(dim ? 0.10 : 0.20)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
    c.restore();

    rimBand(c, boot, l, width: 4, alpha: dim ? 0.3 : 0.5);
    rimBand(c, shin, l, width: 4.5, alpha: dim ? 0.32 : 0.5,
        color: const Color(0xFF9FE9FF));
  }

  // ───────────────────────────────────────────── 헬멧

  /// 헬멧과 그 안의 얼굴.
  ///
  /// 이 캐릭터의 전부다. 유리는 반투명이어야 하고, 그 안쪽 얼굴은 그늘지되
  /// 읽혀야 하며, 유리 표면의 반사는 얼굴을 지우지 않을 만큼만 있어야 한다.
  /// 세 조건이 서로를 잡아먹기 때문에 레이어 순서가 곧 결과다.
  void _helmet(
      Canvas c, LightRig l, double t, double bob, double sway, double detail) {
    final hc = Offset(508 + sway * 0.6, 330 + bob * 1.2);

    // 넥 댐. 헬멧과 어깨를 잇는 원뿔형 칼라로, 이것이 없으면 헬멧이 목 위에
    // 떠 있는 풍선으로 보인다. 판타지 캐릭터에는 없는 이 캐릭터만의 문제다.
    final dam = smoothClosedPath([
      hc + const Offset(-56, 82),
      hc + const Offset(56, 78),
      hc + const Offset(94, 196),
      hc + const Offset(0, 218),
      hc + const Offset(-90, 200),
    ], tension: 0.72);
    paintSurface(c, dam, _sSuit, l, detail: detail, seed: 639);
    occlude(c, dam, const Offset(0, -1), depth: 0.42, alpha: 0.6);

    // 목 결합 링. 헬멧이 슈트에 잠기는 지점.
    final collar = tube(
      [
        hc + const Offset(-58, 96),
        hc + const Offset(0, 104),
        hc + const Offset(58, 94),
      ],
      const [24, 28, 24],
      samples: 14,
    );
    paintSurface(c, collar, _sSteel, l, detail: detail, seed: 641);

    // 하드셸. 뒤통수 쪽이 살짝 부푼 구.
    final shell = blob(
      hc,
      116,
      120,
      warp: (a, u) => 1 + math.cos(a - math.pi) * 0.05 - math.cos(a * 2) * 0.03,
    );
    castShadow(c, shell, offset: const Offset(6, 16), blur: 20, alpha: 0.5);
    paintSurface(c, shell, _sShell, l, detail: detail, seed: 643);

    c.save();
    c.clipPath(shell);
    // 셸 상단면. 구의 윗면이 하늘을 향하므로 여기서 가장 밝다.
    c.drawOval(
      Rect.fromCenter(
          center: hc + const Offset(-14, -96), width: 176, height: 72),
      Paint()
        ..blendMode = BlendMode.plus
        ..color = l.key.fade(0.30)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 26),
    );
    // 셸 이음매.
    panelLine(
      c,
      smoothOpenPath([
        hc + const Offset(-114, -6),
        hc + const Offset(-36, -112),
        hc + const Offset(54, -116),
      ]),
      _rShell,
      l,
      width: 6,
    );
    c.restore();

    // ── 바이저 개구부 ──────────────────────────────────────────────
    final visor = smoothClosedPath([
      hc + const Offset(-56, -62),
      hc + const Offset(6, -82),
      hc + const Offset(64, -56),
      hc + const Offset(84, 0),
      hc + const Offset(68, 52),
      hc + const Offset(20, 80),
      hc + const Offset(-40, 66),
      hc + const Offset(-70, 10),
    ], tension: 0.85);

    // 개구부 안쪽. 헬멧 내부는 그림자다.
    c.drawPath(visor, Paint()..color = const Color(0xFF0A141F));

    c.save();
    c.clipPath(visor);
    _face(c, l, t, hc + const Offset(10, 4), detail);
    // 내부 상단 그림자. 얼굴이 헬멧 안에 파묻혀 있다는 사실을 만든다.
    c.drawRect(
      visor.getBounds().inflate(20),
      Paint()
        ..blendMode = BlendMode.multiply
        ..shader = RadialGradient(
          center: const Alignment(0.05, 0.1),
          radius: 1.05,
          colors: const [
            Color(0xFFFFFFFF),
            Color(0xFFD2DAE6),
            Color(0xFF6C7A93),
          ],
          stops: const [0.0, 0.58, 1.0],
        ).createShader(visor.getBounds()),
    );
    c.restore();

    // ── 유리 ───────────────────────────────────────────────────────
    c.save();
    c.clipPath(visor);
    // 유리 본체의 청록 틴트. 얼굴을 지우지 않을 만큼만 얹는다.
    c.drawRect(visor.getBounds(), Paint()..color = _visor.fade(0.16));
    // 상단 금 코팅. 태양광 차단막이라 위에서부터 내려오며 사라진다.
    c.drawRect(
      visor.getBounds(),
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_gold.fade(0.46), _gold.fade(0.14), _gold.fade(0.0)],
          stops: const [0.0, 0.24, 0.48],
        ).createShader(visor.getBounds()),
    );
    // 아래쪽에 낀 행성 반사광. 발밑에서 올라오는 푸른빛이 유리에 맺힌다.
    c.drawRect(
      visor.getBounds(),
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = LinearGradient(
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
          colors: [l.bounce.fade(0.34), l.bounce.fade(0.0)],
          stops: const [0.0, 0.5],
        ).createShader(visor.getBounds()),
    );
    // 유리 표면의 반사 스트라이프. 큰 것 하나 + 작은 것 하나가 규칙이며,
    // 둘 다 얼굴의 왼쪽 바깥으로 비껴 두어 이목구비를 덮지 않게 했다.
    c.drawPath(
      smoothClosedPath([
        hc + const Offset(-62, -22),
        hc + const Offset(-30, -76),
        hc + const Offset(-8, -74),
        hc + const Offset(-44, -10),
      ]),
      Paint()
        ..blendMode = BlendMode.plus
        ..color = white.fade(0.30)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
    c.drawPath(
      smoothClosedPath([
        hc + const Offset(-52, 22),
        hc + const Offset(-32, -4),
        hc + const Offset(-20, 2),
        hc + const Offset(-42, 34),
      ]),
      Paint()
        ..blendMode = BlendMode.plus
        ..color = white.fade(0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    // 유리에 비친 별 몇 점. 이 인물이 무엇을 마주 보고 있는지 말한다.
    if (detail > 0.5) {
      final n = Noise(83);
      for (var i = 0; i < 6; i++) {
        final p = hc +
            Offset(n.signed1(i * 3.7) * 62 - 6, n.signed1(i * 6.1 + 9) * 46 - 24);
        c.drawCircle(
          p,
          1.2 + n.at1(i * 2.9) * 1.4,
          Paint()
            ..blendMode = BlendMode.plus
            ..color = white.fade(0.45 + n.at1(i * 4.3) * 0.3),
        );
      }
    }
    // HUD 눈금. 유리 안쪽에 투영된 항법 정보.
    if (detail > 0.4) {
      final hudPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..blendMode = BlendMode.plus
        ..color = _hud.fade(0.4);
      c.drawCircle(hc + const Offset(58, -34), 17, hudPaint);
      c.drawLine(hc + const Offset(41, -34), hc + const Offset(48, -34), hudPaint);
      c.drawLine(hc + const Offset(68, -34), hc + const Offset(75, -34), hudPaint);
      final drift = math.sin(t * 0.8) * 8;
      c.drawLine(
        hc + Offset(38, 46 + drift),
        hc + Offset(70, 46 + drift),
        hudPaint..color = _hud.fade(0.28),
      );
    }
    c.restore();

    // 바이저 테. 유리와 셸의 경계를 금속으로 못 박는다.
    c.drawPath(
      visor,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..color = _rSteel.shadow,
    );
    c.drawPath(
      visor.shift(-l.dir * 3),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.4
        ..color = _rSteel.light.fade(0.8),
    );

    // ── 헬멧 부착물 ────────────────────────────────────────────────
    // 작업등 두 개. 바이저 위 좌우에 달려 앞을 비춘다.
    for (var i = 0; i < 2; i++) {
      final at = hc + Offset(-48 + i * 98.0, -96 + i * 10.0);
      final lamp = blob(at, 19, 14, rotation: -0.2);
      paintSurface(c, lamp, _sHull, l, detail: detail, seed: 645 + i);
      c.drawCircle(
        at + const Offset(0, 2),
        8,
        Paint()..color = const Color(0xFFFFF3D2),
      );
      glowAt(c, at + const Offset(0, 2), 24, const Color(0xFFFFE9B0),
          intensity: 0.5);
    }
    // 측면 통신 패널.
    final commPanel = smoothClosedPath([
      hc + const Offset(-106, -12),
      hc + const Offset(-82, -24),
      hc + const Offset(-74, 12),
      hc + const Offset(-98, 22),
    ], tension: 0.7);
    paintSurface(c, commPanel, _sHull, l, detail: detail, seed: 647);
    c.drawCircle(
      hc + const Offset(-90, 0),
      5,
      Paint()
        ..blendMode = BlendMode.plus
        ..color = _hud.fade(0.85),
    );

    rimBand(c, shell, l, width: 7, alpha: 0.75, color: const Color(0xFFCFF4FF));
  }

  /// 바이저 안쪽의 얼굴. 화면에서 유일하게 사람인 부분이다.
  ///
  /// 헬멧 그늘이라 조명은 약하게 주되, 이목구비까지 어두워지면 캐릭터가 통째로
  /// 죽는다. 그래서 피부는 살짝만 식히고 눈 주변에만 빛을 남겼다.
  void _face(Canvas c, LightRig l, double t, Offset fc, double detail) {
    final inner = l.copyWith(intensity: 0.7);

    // 목.
    final neck = tube(
      [fc + const Offset(2, 44), fc + const Offset(-2, 96)],
      const [21, 27],
      samples: 10,
    );
    paintSurface(c, neck, _sSkin.tinted(const Color(0xFF0E1B2E), 0.4), inner,
        detail: 0.3, rim: false, ao: false, seed: 653);

    // 옆머리는 얼굴보다 **먼저** 그린다. 위에 얹으면 볼 안쪽으로 한 겹만
    // 들어와도 그늘진 바이저 안에서 그림자와 구분되지 않아 얼굴이 더러워진다.
    final hairShade = _sHair.tinted(const Color(0xFF16283E), 0.2);
    for (final s in const [-1.0, 1.0]) {
      final side = tube(
        [
          fc + Offset(s * 50, -56),
          fc + Offset(s * 64, -12),
          fc + Offset(s * 56, 34),
        ],
        s < 0 ? const [14, 16, 7] : const [12, 14, 6],
        samples: 14,
      );
      paintSurface(c, side, hairShade, inner,
          detail: detail, rim: false, seed: 657 + s.toInt());
    }

    final head = headShape(fc, 54, 60,
        jaw: 0.58, chin: 0.24, turn: 0.5, cheek: 0.96);
    paintSurface(c, head, _sSkin.tinted(const Color(0xFF16283E), 0.07), inner,
        detail: detail, rim: false, seed: 651);
    occlude(c, head, const Offset(0, -1), depth: 0.2, alpha: 0.3);

    // 눈. 3/4 우향이므로 관찰자에게 가까운 왼쪽 눈이 크고 먼 쪽이 압축된다.
    final eyeY = fc.dy - 4;
    drawEye(c, Offset(fc.dx - 23, eyeY), 20, 11,
        iris: const Color(0xFF3FA8C4),
        light: inner,
        open: 0.96,
        look: 0.45,
        tilt: -0.05,
        scleraTint: const Color(0xFFE0DAD6));
    drawEye(c, Offset(fc.dx + 21, eyeY + 3), 16.5, 9.2,
        iris: const Color(0xFF3FA8C4),
        light: inner,
        open: 0.92,
        look: 0.45,
        tilt: 0.04,
        mirrored: true,
        scleraTint: const Color(0xFFE0DAD6));
    // 눈썹은 얇고 높게. 굵게 깔면 그늘진 바이저 안에서 눈과 뭉쳐 인상이
    // 통째로 굳어 버린다 — 이 얼굴에서 가장 예민한 두 획이다.
    drawBrow(c, Offset(fc.dx - 25, eyeY - 32), 21, 2.5,
        const Color(0xFF4A3128), arch: 1.25, angle: -0.14);
    drawBrow(c, Offset(fc.dx + 23, eyeY - 30), 17, 2.1,
        const Color(0xFF4A3128), arch: 1.2, angle: 0.12, mirrored: true);

    drawNose(c, Offset(fc.dx + 4, eyeY + 6), 13, 20, _rSkin, inner, turn: 0.45);
    drawMouth(c, Offset(fc.dx + 6, fc.dy + 36), 18,
        skin: _rSkin, lip: const Color(0xFFB85F5C), smile: 0.12, turn: 0.45);

    // 헬멧 안이라 머리카락은 이마와 관자놀이에만 남는다. 눈썹까지 내려오면
    // 바이저 그늘과 겹쳐 두 획이 하나의 검은 띠가 되고 인상이 죽는다.
    // 앞머리는 이마 위쪽만. 안쪽 윤곽을 눈썹에서 30px 이상 띄운다.
    final fringe = smoothClosedPath([
      fc + const Offset(-52, -50),
      fc + const Offset(-58, -70),
      fc + const Offset(-24, -86),
      fc + const Offset(24, -86),
      fc + const Offset(58, -68),
      fc + const Offset(56, -48),
      fc + const Offset(32, -62),
      fc + const Offset(-2, -68),
      fc + const Offset(-30, -60),
    ], tension: 0.88);
    paintSurface(c, fringe, hairShade, inner,
        detail: detail, rim: false, seed: 655);
    if (detail > 0.4) {
      // 흘러내린 잔머리는 양 끝에서만, 그것도 바깥으로 흐르게 한다.
      for (final s in const [-1.0, 1.0]) {
        final strand = hairStrand(
          fc + Offset(s * 46, -60),
          Offset(s * 0.8, 0.6),
          34,
          5,
          t,
          phase: s * 1.9,
          curl: 0.22,
          flutter: 0.12,
        );
        paintSurface(c, strand, hairShade, inner,
            detail: 0, rim: false, ao: false);
      }
    }

    // 통신 마이크. 턱선을 따라 입가로 뻗은 얇은 붐.
    c.drawPath(
      smoothOpenPath([
        fc + const Offset(-48, 6),
        fc + const Offset(-40, 40),
        fc + const Offset(-18, 50),
      ]),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.4
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF1B2432),
    );
    c.drawCircle(
      fc + const Offset(-16, 51),
      5.5,
      Paint()..color = const Color(0xFF2A3446),
    );

    // 얼굴 오른쪽 가장자리의 약한 림. 유리 반사에 얼굴이 먹히지 않게 붙든다.
    rimBand(c, head, inner, width: 3, alpha: 0.45, color: const Color(0xFF9FE9FF));
  }

  // ───────────────────────────────────────────── 조명탄

  /// 조명탄의 몸체. 손보다 먼저 그려야 손가락이 봉을 감아쥔 것으로 읽힌다.
  void _flareRod(Canvas c, LightRig l, double bob) {
    final grip = Offset(746, 452 + bob * 0.2);
    final tip = Offset(772, 296 + bob * 0.2);
    final rod = tube(
      [grip + const Offset(-6, 40), grip, lerpO(grip, tip, 0.6), tip],
      const [9, 10, 8, 7],
      samples: 18,
    );
    paintSurface(c, rod, _sSteel, l, detail: 0.4, seed: 681);
    c.save();
    c.clipPath(rod);
    for (var i = 0; i < 3; i++) {
      final q = lerpO(grip + const Offset(-6, 40), grip, i / 3);
      c.drawLine(
        q + const Offset(-12, 0),
        q + const Offset(12, -2),
        Paint()
          ..strokeWidth = 3
          ..color = _rSteel.deep.fade(0.7),
      );
    }
    c.restore();
  }

  /// 조명탄의 빛. 두 번째 광원이자 이 정지 포즈의 목적이다.
  ///
  /// 광원을 그려 놓고 피사체가 반응하지 않으면 조명탄은 화면에 붙은 스티커가
  /// 된다. 그래서 발광 직후 오른쪽 상반신에 따뜻한 되비침을 얹어 둘을 잇는다.
  void _flareLight(Canvas c, double t, double flick, double bob) {
    final grip = Offset(746, 452 + bob * 0.2);
    final tip = Offset(772, 296 + bob * 0.2);

    final core = tube(
      [lerpO(grip, tip, 0.72), tip + const Offset(4, -16)],
      const [11, 8],
      samples: 12,
    );
    paintSurface(
      c,
      core,
      const Surface(_warn, Finish.energy, glow: 1.0, glowColor: _warn),
      light,
      detail: 0.3,
      ao: false,
    );
    glowAt(c, tip + const Offset(2, -8), 92, _warn,
        intensity: 0.85 * flick, star: true);
    glowAt(c, tip + const Offset(2, -8), 32, const Color(0xFFFFD9A8),
        intensity: 0.95 * flick);

    // 떨어져 나오는 불티.
    final n = Noise(29);
    for (var i = 0; i < 10; i++) {
      final k = (t * 0.9 + n.at1(i * 5.3)) % 1.0;
      final p = tip +
          Offset(
            n.signed1(i * 3.1) * 32 + k * 26,
            -8 + k * 88 - n.at1(i * 7.7) * 18,
          );
      final fade = math.sin(k * math.pi).clamp(0.0, 1.0);
      c.drawCircle(
        p,
        1.6 + n.at1(i * 2.3) * 2.0,
        Paint()
          ..blendMode = BlendMode.plus
          ..color = _warn.lighten(0.3).fade(0.7 * fade * flick),
      );
    }

    // 슈트에 되비친 빛.
    final at = tip + const Offset(-150, 116);
    c.drawCircle(
      at,
      200,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(
          colors: [
            _warn.fade(0.15 * flick),
            _warn.fade(0.05 * flick),
            _warn.fade(0.0),
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(Rect.fromCircle(center: at, radius: 200)),
    );
  }
}
