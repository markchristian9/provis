import 'dart:math' as math;

import 'package:flutter/painting.dart';

import 'package:provis/provis.dart';

/// 모른 — 공허의 성가대.
///
/// 반투명한 존재를 그릴 때 가장 흔한 실패는 "그냥 흐린 캐릭터"가 되는 것이다.
/// 여기서는 몸 전체를 하나의 레이어로 합성한 뒤 아래쪽을 지워, 실체가 아래로
/// 갈수록 소멸하게 만들었다. 불투명한 것은 오직 뼈로 만든 가면과 사슬뿐이며,
/// 그 대비가 나머지를 유령으로 만든다.
class Mourne extends Artist {
  @override
  String get id => 'mourne';
  @override
  String get name => 'Mourne';
  @override
  String get title => 'The Hollow Choir';
  @override
  String get blurb => '천 개의 목소리로 애도하는 형체 없는 장례의 주인.';
  @override
  Camp get camp => Camp.monster;
  @override
  Sex? get sex => null;
  @override
  CharacterBuild get build => CharacterBuild(
        archetype: Archetype.mage,
        beast: true,
        palette: tintedPalette(const Color(0xFF8FE4FF), Rng(0x3E11), monster: true),
        weapon: WeaponKind.staff,
        armorHeaviness: 0.0,
        muscle: 0.15,
        glowRunes: true,
        heightScale: 1.1,
      );
  @override
  Color get accent => const Color(0xFF8FE4FF);
  @override
  LightRig get light => LightRig.spectral;
  @override
  List<Color> get moodSky => const [
        Color(0xFF060A14),
        Color(0xFF11223A),
        Color(0xFF244A5E),
      ];

  static const _ecto = Color(0xFF5FA8CC);
  static const _ectoDeep = Color(0xFF2E5E80);
  static const _rag = Color(0xFF27405C);
  static const _ragDeep = Color(0xFF16283C);
  static const _bone = Color(0xFFDCE8EE);
  static const _soul = Color(0xFFBFF3FF);
  static const _iron = Color(0xFF5A6470);

  Surface get _sEcto =>
      const Surface(_ecto, Finish.slime, contrast: 1.1, alpha: 0.62);
  Surface get _sEctoDeep =>
      const Surface(_ectoDeep, Finish.slime, contrast: 1.15, alpha: 0.55);
  Surface get _sRag => const Surface(_rag, Finish.cloth, contrast: 1.25);
  Surface get _sRagDeep =>
      const Surface(_ragDeep, Finish.cloth, contrast: 1.3);
  Surface get _sBone => const Surface(_bone, Finish.bone, contrast: 1.05);

  Ramp get _rRag => Ramp.of(_rag, contrast: 1.25);
  Ramp get _rBone => Ramp.of(_bone, contrast: 1.05);

  @override
  void paint(Canvas c, double t, {double detail = 1.0}) {
    final l = light;
    final drift = math.sin(t * 0.6) * 12;
    final bob = math.sin(t * 0.9 + 1.2) * 7;

    _underglow(c, t);
    _halo(c, t, detail);

    // 몸 전체를 하나의 레이어로 합성한 뒤 아래를 지워 소멸시킨다.
    c.saveLayer(
      const Rect.fromLTWH(-60, 0, 1120, 1400),
      Paint()..color = white.fade(0.92),
    );
    c.save();
    c.translate(0, drift);

    _rags(c, l, t, detail);
    _armLeft(c, l, t, bob, detail);
    _armRight(c, l, t, bob, detail);
    _torso(c, l, bob, detail);
    _chains(c, l, t);
    _head(c, l, t, bob, detail);

    c.restore();
    // 하단 소멸 마스크.
    c.drawRect(
      const Rect.fromLTWH(-60, 900, 1120, 500),
      Paint()
        ..blendMode = BlendMode.dstOut
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [white.fade(0.0), white.fade(0.55), white.fade(1.0)],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(const Rect.fromLTWH(-60, 900, 1120, 500)),
    );
    c.restore();

    _wisps(c, t, detail);
    if (detail > 0.4) {
      drawMotes(
        c,
        const Rect.fromLTWH(240, 500, 520, 780),
        t,
        _soul,
        count: 20,
        size: 4.5,
        speed: -22,
        seed: 13,
        drift: 1.1,
      );
    }
  }

  // 유령 자신이 광원이므로 발밑이 아니라 몸 전체 뒤가 밝다.
  void _underglow(Canvas c, double t) {
    final pulse = 0.75 + 0.25 * math.sin(t * 0.8);
    final rect = Rect.fromCenter(
      center: const Offset(500, 640),
      width: 900,
      height: 1100,
    );
    c.drawOval(
      rect,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(
          colors: [
            _soul.fade(0.13 * pulse),
            const Color(0xFF2A6A8C).fade(0.09 * pulse),
            _soul.fade(0.0),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(rect),
    );
    // 바닥에 번지는 냉기.
    final floor = Rect.fromCenter(
      center: const Offset(500, 1290),
      width: 620,
      height: 120,
    );
    c.drawOval(
      floor,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(
          colors: [_soul.fade(0.16), _soul.fade(0.0)],
        ).createShader(floor),
    );
  }

  // 부서진 후광. 조각들이 서로 다른 속도로 떠돈다.
  void _halo(Canvas c, double t, double detail) {
    const center = Offset(500, 300);
    for (var i = 0; i < 9; i++) {
      final a = t * 0.16 + i / 9 * math.pi * 2;
      final r = 176 + math.sin(t * 0.5 + i) * 10;
      final p = center + Offset(math.cos(a) * r, math.sin(a) * r * 0.42);
      final len = 26 + (i % 3) * 14.0;
      c.save();
      c.translate(p.dx, p.dy);
      c.rotate(a + math.pi / 2 + math.sin(t * 0.4 + i) * 0.2);
      final shard = smoothClosedPath([
        Offset(-len * 0.5, -5),
        Offset(len * 0.5, -3),
        Offset(len * 0.45, 4),
        Offset(-len * 0.5, 5),
      ], tension: 0.4);
      c.drawPath(shard, Paint()..color = _rBone.mid.fade(0.55));
      c.drawPath(
        shard,
        Paint()
          ..blendMode = BlendMode.plus
          ..color = _soul.fade(0.35),
      );
      c.restore();
      if (detail > 0.4) {
        glowAt(c, p, 16, _soul, intensity: 0.3);
      }
    }
  }

  // 넝마. 갈래마다 길이와 흔들림이 달라야 한 장의 천으로 보이지 않는다.
  void _rags(Canvas c, LightRig l, double t, double detail) {
    for (var i = 0; i < 7; i++) {
      final u = i / 6;
      final x = lerpD(346, 654, u);
      final len = 520 + math.sin(u * math.pi * 1.6) * 190;
      final spine = clothSpine(
        Offset(x, 620 + math.sin(u * math.pi) * -40),
        Offset((u - 0.5) * 0.5, 1.0),
        len,
        t,
        sway: 0.26,
        phase: i * 1.9,
        segments: 6,
        gravity: 0.18,
        flutter: 1.2,
      );
      final w = 58.0 - (u - 0.5).abs() * 40;
      final rag = tube(spine, [w, w * 1.05, w * 0.92, w * 0.7, w * 0.4, 6],
          samples: 24);
      paintSurface(c, rag, i.isOdd ? _sRagDeep : _sRag, l,
          detail: detail * 0.6, seed: 801 + i);
      rimBand(c, rag, l, width: 4, alpha: 0.45, color: _soul);
    }

    // 몸통 뒤로 넓게 퍼진 외투.
    final w = jitter(t, 6.6, amp: 1.6);
    final robe = smoothClosedPath([
      const Offset(452, 470),
      const Offset(548, 470),
      Offset(676 + w * 3, 600),
      Offset(730 + w * 5, 840),
      Offset(700 + w * 6, 1060),
      const Offset(560, 1180),
      const Offset(440, 1180),
      Offset(300 - w * 6, 1060),
      Offset(270 - w * 5, 840),
      Offset(324 - w * 3, 600),
    ], tension: 0.85);
    paintSurface(c, robe, _sRag, l, detail: detail, seed: 811);
    c.save();
    c.clipPath(robe);
    for (var i = 0; i < 8; i++) {
      final u = i / 7;
      c.drawPath(
        smoothOpenPath([
          Offset(lerpD(462, 538, u), 480),
          Offset(lerpD(340, 660, u) + math.sin(u * 6 + t) * 12, 820),
          Offset(lerpD(292, 708, u), 1160),
        ]),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 26 - (u - 0.5).abs() * 18
          ..color = _rRag.deep.fade(0.55)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
      );
    }
    // 옷 안쪽에서 새어 나오는 영혼빛.
    c.drawRect(
      robe.getBounds(),
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(
          center: const Alignment(0, -0.5),
          colors: [_soul.fade(0.22), _soul.fade(0.0)],
        ).createShader(robe.getBounds()),
    );
    c.restore();
    rimBand(c, robe, l, width: 6, alpha: 0.6, color: _soul);
  }

  void _torso(Canvas c, LightRig l, double bob, double detail) {
    final chest = Offset(500, 546 + bob);

    // 영체 몸통. 갈비뼈가 비쳐 보인다.
    final body = torsoShape(
      chest: chest,
      pelvis: chest + const Offset(0, 300),
      shoulderW: 118,
      chestW: 104,
      waistW: 74,
      hipW: 86,
      neckW: 30,
    );
    paintSurface(c, body, _sEcto, l, detail: detail, seed: 821);

    c.save();
    c.clipPath(body);
    for (var i = 0; i < 5; i++) {
      final y = chest.dy + 6 + i * 34.0;
      final wHalf = 96 - i * 7.0;
      c.drawPath(
        smoothOpenPath([
          Offset(chest.dx - wHalf, y + 16),
          Offset(chest.dx - wHalf * 0.4, y - 6),
          Offset(chest.dx, y - 10),
          Offset(chest.dx + wHalf * 0.4, y - 6),
          Offset(chest.dx + wHalf, y + 16),
        ]),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9
          ..strokeCap = StrokeCap.round
          ..color = _rBone.mid.fade(0.30),
      );
    }
    // 흉골.
    c.drawPath(
      smoothOpenPath([
        chest + const Offset(0, -6),
        chest + const Offset(2, 90),
        chest + const Offset(0, 150),
      ]),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 13
        ..strokeCap = StrokeCap.round
        ..color = _rBone.mid.fade(0.34),
    );
    // 심장 자리의 영혼핵.
    c.restore();

    final coreAt = chest + const Offset(0, 46);
    glowAt(c, coreAt, 76, _soul, intensity: 0.7, star: true);
    final core = Path()..addOval(Rect.fromCircle(center: coreAt, radius: 22));
    paintSurface(
      c,
      core,
      const Surface(_soul, Finish.energy, glow: 0.8, glowColor: _soul),
      l,
    );

    // 어깨의 뼈 갑주. 유일하게 실체가 있는 부위.
    for (final s in const [-1.0, 1.0]) {
      final p = chest + Offset(s * 118, 4);
      final pauldron = smoothClosedPath([
        p + Offset(-s * 40, -34),
        p + Offset(s * 34, -44),
        p + Offset(s * 62, 6),
        p + Offset(s * 40, 52),
        p + Offset(-s * 34, 40),
      ], tension: 0.8);
      paintSurface(c, pauldron, _sBone, l, detail: detail, seed: 823);
      // 갑주에 새겨진 균열.
      c.save();
      c.clipPath(pauldron);
      for (var i = 0; i < 3; i++) {
        c.drawPath(
          smoothOpenPath([
            p + Offset(s * (-30 + i * 22), -40),
            p + Offset(s * (-14 + i * 26), 12),
            p + Offset(s * (-26 + i * 20), 50),
          ]),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = _rBone.deep.fade(0.7),
        );
      }
      c.restore();
      rimBand(c, pauldron, l, width: 4, alpha: 0.7, color: _soul);
    }

    rimBand(c, body, l, width: 6, alpha: 0.7, color: _soul);
  }

  void _armLeft(Canvas c, LightRig l, double t, double bob, double detail) =>
      _arm(c, l, t, detail,
          shoulder: Offset(392, 560 + bob),
          elbow: const Offset(250, 652),
          wrist: const Offset(168, 556),
          mirrored: false,
          seed: 831);

  void _armRight(Canvas c, LightRig l, double t, double bob, double detail) =>
      _arm(c, l, t, detail,
          shoulder: Offset(608, 556 + bob),
          elbow: const Offset(752, 644),
          wrist: const Offset(834, 542),
          mirrored: true,
          seed: 841);

  void _arm(
    Canvas c,
    LightRig l,
    double t,
    double detail, {
    required Offset shoulder,
    required Offset elbow,
    required Offset wrist,
    required bool mirrored,
    required int seed,
  }) {
    // 소매: 팔보다 훨씬 넓게 늘어져 팔의 실체를 감춘다.
    final sleeve = tube(
      [shoulder, lerpO(shoulder, elbow, 0.55), elbow],
      const [58, 50, 40],
      samples: 16,
    );
    paintSurface(c, sleeve, _sRag, l, detail: detail, seed: seed);

    final drape = smoothClosedPath([
      elbow + const Offset(-42, -26),
      elbow + const Offset(40, -30),
      elbow + const Offset(56, 70),
      elbow + const Offset(14, 160),
      elbow + const Offset(-40, 92),
    ], tension: 0.8);
    paintSurface(c, drape, _sRagDeep, l, detail: detail, seed: seed + 1);

    final fore = tube(
      [elbow, lerpO(elbow, wrist, 0.5), wrist],
      const [26, 21, 15],
      samples: 14,
    );
    paintSurface(c, fore, _sEctoDeep, l, detail: detail, seed: seed + 2);

    // 손: 손가락이 길고 끝이 뾰족하다. 마디를 세 개로 꺾어 인간에서 멀어진다.
    final dir = (wrist - elbow).normalized();
    for (var i = 0; i < 4; i++) {
      final a = (i - 1.5) * 0.28;
      final d = dir.rotated(a);
      final tip = wrist + d * (62 + math.sin(i * 1.3) * 14);
      final finger = tube(
        [
          wrist,
          lerpO(wrist, tip, 0.42) + d.perp * 5,
          lerpO(wrist, tip, 0.78) - d.perp * 4,
          tip,
        ],
        const [9, 7.5, 5, 1.5],
        samples: 16,
      );
      paintSurface(c, finger, _sEcto, l, detail: 0.3, ao: false, seed: seed + 3);
      glowAt(c, tip, 14, _soul, intensity: 0.4);
    }
    final palm = blob(wrist + dir * 12, 22, 18,
        rotation: dir.angle, warp: (a, u) => 1 + math.cos(a * 2) * 0.12);
    paintSurface(c, palm, _sEcto, l, detail: detail, seed: seed + 4);

    rimBand(c, sleeve, l, width: 5, alpha: 0.6, color: _soul);
    rimBand(c, fore, l, width: 4, alpha: 0.65, color: _soul);
  }

  // 몸에 감긴 사슬. 유령을 이 세상에 묶어 두는 물건이라 유일하게 선명하다.
  void _chains(Canvas c, LightRig l, double t) {
    for (var k = 0; k < 2; k++) {
      final sag = 26 + math.sin(t * 0.7 + k) * 8;
      final path = [
        Offset(360 + k * 30.0, 620 + k * 60),
        Offset(500, 700 + sag + k * 70),
        Offset(640 - k * 30.0, 616 + k * 58),
      ];
      final poly = smoothPolyline(path, 26);
      for (var i = 0; i < poly.length - 1; i += 2) {
        final p = poly[i];
        final d = (poly[i + 1] - p).normalized();
        final flat = (i ~/ 2).isEven;
        c.save();
        c.translate(p.dx, p.dy);
        c.rotate(d.angle);
        final r = 11.0;
        final rect = Rect.fromCenter(
          center: Offset.zero,
          width: r * 2.1,
          height: flat ? r * 1.5 : r * 0.6,
        );
        c.drawOval(
          rect,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.42
            ..shader = LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Ramp.of(_iron).spec,
                Ramp.of(_iron).mid,
                Ramp.of(_iron).deep,
              ],
            ).createShader(rect),
        );
        c.restore();
      }
    }
  }

  /// 주위를 떠도는 도깨비불. 각각이 하나의 목소리라는 설정이다.
  void _wisps(Canvas c, double t, double detail) {
    final n = Noise(67);
    final count = detail > 0.5 ? 7 : 4;
    for (var i = 0; i < count; i++) {
      final sp = 0.30 + n.at1(i * 3.1) * 0.42;
      final rx = 200 + n.at1(i * 5.7) * 220;
      final ry = 130 + n.at1(i * 8.3) * 180;
      final a = t * sp + i * 2.4;
      final p = Offset(
        500 + math.cos(a) * rx,
        620 + math.sin(a * 1.3 + i) * ry,
      );
      final s = 10 + n.at1(i * 2.7) * 10;
      glowAt(c, p, s * 3.4, _soul, intensity: 0.55, star: true);
      c.drawCircle(
        p,
        s * 0.5,
        Paint()
          ..blendMode = BlendMode.plus
          ..color = white.fade(0.75),
      );
      // 꼬리.
      for (var k = 1; k < 5; k++) {
        final pa = a - k * 0.10;
        final q = Offset(
          500 + math.cos(pa) * rx,
          620 + math.sin(pa * 1.3 + i) * ry,
        );
        c.drawCircle(
          q,
          s * 0.42 * (1 - k / 5),
          Paint()
            ..blendMode = BlendMode.plus
            ..color = _soul.fade(0.30 * (1 - k / 5)),
        );
      }
    }
  }

  void _head(Canvas c, LightRig l, double t, double bob, double detail) {
    final hc = Offset(500, 352 + bob * 1.2);

    // 후드.
    final hood = smoothClosedPath([
      hc + const Offset(-104, 60),
      hc + const Offset(-112, -30),
      hc + const Offset(-64, -104),
      hc + const Offset(4, -126),
      hc + const Offset(72, -102),
      hc + const Offset(114, -26),
      hc + const Offset(108, 64),
      hc + const Offset(62, 130),
      hc + const Offset(-58, 132),
    ], tension: 0.84);
    paintSurface(c, hood, _sRagDeep, l, detail: detail, seed: 851);
    c.save();
    c.clipPath(hood);
    for (var i = 0; i < 6; i++) {
      final u = i / 5;
      c.drawPath(
        smoothOpenPath([
          hc + Offset(lerpD(-100, 104, u), 40),
          hc + Offset(lerpD(-58, 62, u), -108),
        ]),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 15
          ..color = _rRag.deep.fade(0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 11),
      );
    }
    c.restore();

    // 후드 안쪽의 공허. 완전한 검정이어야 가면이 떠 보인다.
    final voidPath = smoothClosedPath([
      hc + const Offset(-78, -34),
      hc + const Offset(0, -62),
      hc + const Offset(78, -30),
      hc + const Offset(68, 62),
      hc + const Offset(0, 104),
      hc + const Offset(-70, 60),
    ], tension: 0.86);
    c.drawPath(voidPath, Paint()..color = const Color(0xFF04070E));
    c.save();
    c.clipPath(voidPath);
    c.drawPath(
      voidPath,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(
          center: const Alignment(0, 0.4),
          colors: [_soul.fade(0.22), _soul.fade(0.0)],
        ).createShader(voidPath.getBounds()),
    );
    c.restore();

    // 뼈 가면. 위쪽 절반만 덮어 아래턱이 어둠 속에 남는다.
    final mask = smoothClosedPath([
      hc + const Offset(-62, -44),
      hc + const Offset(0, -60),
      hc + const Offset(62, -42),
      hc + const Offset(58, 16),
      hc + const Offset(34, 58),
      hc + const Offset(0, 74),
      hc + const Offset(-34, 56),
      hc + const Offset(-58, 14),
    ], tension: 0.88);
    paintSurface(c, mask, _sBone, l, detail: detail, seed: 853);

    c.save();
    c.clipPath(mask);
    // 눈구멍.
    for (final s in const [-1.0, 1.0]) {
      final e = hc + Offset(s * 30, -4);
      final socket = smoothClosedPath([
        e + Offset(-s * 24, -4),
        e + Offset(-s * 6, -18),
        e + Offset(s * 20, -8),
        e + Offset(s * 16, 16),
        e + Offset(-s * 12, 18),
      ], tension: 0.85);
      c.drawPath(socket, Paint()..color = const Color(0xFF05080F));
    }
    // 코 구멍.
    c.drawPath(
      smoothClosedPath([
        hc + const Offset(0, 12),
        hc + const Offset(11, 36),
        hc + const Offset(0, 44),
        hc + const Offset(-11, 36),
      ]),
      Paint()..color = const Color(0xFF05080F),
    );
    // 이빨 자국.
    for (var i = 0; i < 7; i++) {
      final x = hc.dx - 30 + i * 10.0;
      c.drawLine(
        Offset(x, hc.dy + 52),
        Offset(x, hc.dy + 72),
        Paint()
          ..strokeWidth = 3
          ..color = _rBone.deep.fade(0.75),
      );
    }
    // 가면의 균열. 안쪽에서 빛이 샌다.
    const cracks = [
      [Offset(-58, -30), Offset(-30, 4), Offset(-38, 44)],
      [Offset(24, -52), Offset(40, -10), Offset(30, 30)],
    ];
    for (final cr in cracks) {
      final p = smoothOpenPath([for (final o in cr) hc + o]);
      c.drawPath(
        p,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..color = const Color(0xFF16202C).fade(0.8),
      );
      c.drawPath(
        p,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..blendMode = BlendMode.plus
          ..color = _soul.fade(0.75),
      );
    }
    c.restore();

    // 눈구멍에서 타오르는 영혼불. 위로 흐르는 불꽃 세 갈래.
    for (final s in const [-1.0, 1.0]) {
      final e = hc + Offset(s * 30, 0);
      glowAt(c, e, 46, _soul, intensity: 0.85, star: true);
      for (var k = 0; k < 3; k++) {
        final ph = t * 3.4 + k * 2.1 + (s > 0 ? 1.1 : 0);
        final h = 30 + (math.sin(ph) * 0.5 + 0.5) * 44;
        final flame = smoothClosedPath([
          e + Offset(-9 + k * 2.0, 6),
          e + Offset(-4 + math.sin(ph) * 5, -h * 0.6),
          e + Offset(math.sin(ph * 1.3) * 8, -h),
          e + Offset(6 + math.sin(ph) * 4, -h * 0.5),
          e + Offset(9 - k * 2.0, 8),
        ], tension: 0.8);
        c.drawPath(
          flame,
          Paint()
            ..blendMode = BlendMode.plus
            ..color = (k == 0 ? white : _soul).fade(0.30 - k * 0.07)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4.0 + k * 3),
        );
      }
    }

    rimBand(c, mask, l, width: 5, alpha: 0.85, color: _soul);
    rimBand(c, hood, l, width: 6, alpha: 0.7, color: _soul);
  }
}
