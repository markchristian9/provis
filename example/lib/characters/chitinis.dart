import 'dart:math' as math;

import 'package:flutter/painting.dart';

import 'package:provis/provis.dart';

/// 키티니스 — 산란굴의 공포.
///
/// 절지동물의 공포는 대칭성과 반복에서 온다. 다리 여섯을 같은 함수로 찍되
/// 관절 각도만 조금씩 어긋나게 두면, 사람의 눈은 그것을 "같은 것이 여럿"으로
/// 읽고 즉시 불쾌해한다. 여기에 키틴 특유의 좁고 날카로운 하이라이트와
/// 이리데센스를 얹어, 젖은 껍질의 광택을 만들었다.
class Chitinis extends Artist {
  @override
  String get id => 'chitinis';
  @override
  String get name => 'Chitinis';
  @override
  String get title => 'Horror of the Spawning Deep';
  @override
  String get blurb => '여덟 개의 눈으로 어둠을 읽는 산란굴의 갑각 포식자.';
  @override
  Camp get camp => Camp.monster;
  @override
  bool get facesLeft => true;
  @override
  Rect get framing => const Rect.fromLTWH(90, 330, 880, 1030);
  @override
  Sex? get sex => null;
  @override
  Color get accent => const Color(0xFF8DFF4E);
  @override
  LightRig get light => const LightRig(
        dir: Offset(-0.56, -0.83),
        rimDir: Offset(0.78, -0.62),
        key: Color(0xFFD8E4FF),
        fill: Color(0xFF2A3A5C),
        rim: Color(0xFF9CFF6A),
        bounce: Color(0xFF3E7A2A),
        ambient: Color(0xFF101424),
      );
  @override
  List<Color> get moodSky => const [
        Color(0xFF080B14),
        Color(0xFF1A1430),
        Color(0xFF2A4A22),
      ];

  static const _shell = Color(0xFF2E2142);
  static const _shellDark = Color(0xFF1B1329);
  static const _joint = Color(0xFF4E2C60);
  static const _venom = Color(0xFF8DFF4E);
  static const _eye = Color(0xFFFF3A6A);
  static const _fang = Color(0xFF3A2A46);

  Surface get _sShell => const Surface(_shell, Finish.chitin, contrast: 1.35);
  Surface get _sShellDark =>
      const Surface(_shellDark, Finish.chitin, contrast: 1.4);
  Surface get _sJoint => const Surface(_joint, Finish.slime,
      contrast: 1.1, alpha: 0.95);
  Surface get _sFang => const Surface(_fang, Finish.chitin, contrast: 1.45);

  Ramp get _rShell => Ramp.of(_shell, contrast: 1.35);

  /// 다리 여섯. (부착점, 무릎, 발끝, 두께, 뒤쪽 여부).
  static const _legs = <(Offset, Offset, Offset, double, bool)>[
    (Offset(452, 782), Offset(286, 520), Offset(126, 1288), 26, true),
    (Offset(486, 762), Offset(566, 470), Offset(700, 1272), 24, true),
    (Offset(468, 812), Offset(322, 618), Offset(268, 1302), 30, false),
    (Offset(512, 792), Offset(650, 566), Offset(846, 1288), 28, true),
    (Offset(492, 842), Offset(392, 704), Offset(424, 1312), 32, false),
    (Offset(536, 826), Offset(700, 690), Offset(930, 1306), 29, false),
  ];

  @override
  void paint(Canvas c, double t, {double detail = 1.0}) {
    final l = light;
    // 몸통이 미세하게 앞뒤로 흔들린다. 거미가 자세를 고쳐 잡는 동작.
    final sway = math.sin(t * 1.1) * 5;
    final rise = math.sin(t * 0.85 + 0.6) * 6;

    groundShadow(c, const Offset(520, 1300), 400, 46, alpha: 0.66);

    // 뒤쪽 다리 먼저.
    for (final leg in _legs) {
      if (!leg.$5) continue;
      _leg(c, l, leg, t, detail, dim: true);
    }

    _abdomen(c, l, t, rise, detail);
    _thorax(c, l, sway, rise, detail);

    for (final leg in _legs) {
      if (leg.$5) continue;
      _leg(c, l, leg, t, detail, dim: false);
    }

    _scythe(c, l, t, detail, mirror: false);
    _head(c, l, t, sway, rise, detail);
    _scythe(c, l, t, detail, mirror: true);

    if (detail > 0.4) {
      _spores(c, t);
    }
  }

  void _spores(Canvas c, double t) {
    drawMotes(
      c,
      const Rect.fromLTWH(200, 700, 640, 600),
      t,
      _venom,
      count: 18,
      size: 4,
      speed: 20,
      seed: 71,
      drift: 0.9,
    );
  }

  /// 다리 하나. 대퇴가 위로 솟고 경절이 아래로 꺾이는 아치가 절지의 인상이다.
  void _leg(
    Canvas c,
    LightRig l,
    (Offset, Offset, Offset, double, bool) spec,
    double t,
    double detail, {
    required bool dim,
  }) {
    final base = spec.$1;
    final thick = spec.$4;
    // 다리마다 위상을 달리한 미세 떨림.
    final ph = base.dx * 0.03;
    final wob = Offset(math.sin(t * 1.7 + ph) * 4, math.cos(t * 1.3 + ph) * 3);
    final knee = spec.$2 + wob;
    final foot = spec.$3 + wob * 0.4;

    final surf = dim ? _sShellDark : _sShell;

    // 기절(基節): 몸통에 붙는 짧고 굵은 마디.
    final coxa = tube(
      [base, lerpO(base, knee, 0.16)],
      [thick * 1.5, thick * 1.15],
      samples: 8,
    );
    paintSurface(c, coxa, _sJoint, l, detail: detail, seed: 901);

    // 대퇴.
    final femur = tube(
      [lerpO(base, knee, 0.1), lerpO(base, knee, 0.55), knee],
      [thick * 1.2, thick * 0.95, thick * 0.72],
      samples: 18,
    );
    paintSurface(c, femur, surf, l, detail: detail, seed: 903);

    // 경절: 발끝으로 갈수록 급격히 가늘어져 바늘이 된다.
    final tibia = tube(
      [knee, lerpO(knee, foot, 0.45), lerpO(knee, foot, 0.8), foot],
      [thick * 0.78, thick * 0.5, thick * 0.26, thick * 0.10],
      samples: 22,
    );
    paintSurface(c, tibia, surf, l, detail: detail, seed: 905);

    // 무릎 관절구.
    final ball = blob(knee, thick * 0.9, thick * 0.82,
        warp: (a, u) => 1 + math.cos(a * 2) * 0.1);
    paintSurface(c, ball, _sJoint, l, detail: detail, seed: 907);
    rimBand(c, ball, l, width: 3, alpha: 0.6, color: _venom);

    // 경절의 강모. 실루엣에서 삐죽삐죽함이 절지동물을 만든다.
    if (detail > 0.4) {
      final n = Noise(base.dx.toInt());
      final d = (foot - knee).normalized();
      final nn = d.perp;
      for (var i = 0; i < 7; i++) {
        final u = 0.1 + i * 0.12;
        final p = lerpO(knee, foot, u);
        final side = i.isEven ? 1.0 : -1.0;
        final len = 16 + n.at1(i * 3.1) * 18;
        c.drawLine(
          p,
          p + (nn * side + d * 0.4).normalized() * len,
          Paint()
            ..strokeWidth = 3.0 - u * 1.6
            ..strokeCap = StrokeCap.round
            ..color = _rShell.deep.fade(0.85),
        );
      }
      // 대퇴의 강모.
      final d2 = (knee - base).normalized();
      for (var i = 0; i < 4; i++) {
        final p = lerpO(base, knee, 0.25 + i * 0.18);
        c.drawLine(
          p,
          p + (d2.perp + d2 * 0.2).normalized() * (20 + i * 4),
          Paint()
            ..strokeWidth = 3.4
            ..strokeCap = StrokeCap.round
            ..color = _rShell.deep.fade(0.8),
        );
      }
    }

    // 발톱.
    final d = (foot - knee).normalized();
    final claw = smoothClosedPath([
      foot - d.perp * (thick * 0.12),
      foot + d * 26 - d.perp * 4,
      foot + d.perp * (thick * 0.12),
    ], tension: 0.5);
    paintSurface(c, claw, _sFang, l, detail: 0.3, seed: 909);

    if (!dim) {
      rimBand(c, femur, l, width: 4, alpha: 0.6, color: _venom.fade(0.8));
      rimBand(c, tibia, l, width: 3, alpha: 0.55, color: _venom.fade(0.7));
    }
  }

  /// 복부. 속에서 독이 발광해 껍질의 무늬를 투과시킨다.
  void _abdomen(Canvas c, LightRig l, double t, double rise, double detail) {
    final at = Offset(736, 862 + rise);
    final pulse = 0.55 + 0.45 * math.sin(t * 1.35);

    final body = blob(
      at,
      190,
      160,
      rotation: -0.22,
      warp: (a, u) => 1 + math.cos(a * 2 - 0.6) * 0.10 + math.sin(a * 3) * 0.04,
    );
    castShadow(c, body, offset: const Offset(16, 20), blur: 26, alpha: 0.5);
    paintSurface(c, body, _sShell, l, detail: detail, seed: 911);

    c.save();
    c.clipPath(body);
    // 속에서 번지는 독광.
    c.drawCircle(
      at + const Offset(30, 40),
      170,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(
          colors: [
            _venom.fade(0.42 * pulse),
            _venom.darken(0.4).fade(0.16 * pulse),
            _venom.fade(0.0),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromCircle(center: at + const Offset(30, 40), radius: 170)),
    );
    // 껍질의 판 분할과 그 사이로 새는 빛.
    for (var i = 0; i < 5; i++) {
      final u = i / 4;
      final seam = smoothOpenPath([
        at + Offset(-176 + u * 40, -60 + u * 76),
        at + Offset(-40 + u * 30, -120 + u * 190),
        at + Offset(90 + u * 20, -104 + u * 176),
        at + Offset(172 - u * 30, -40 + u * 70),
      ]);
      c.drawPath(
        seam,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9
          ..color = _rShell.deep.fade(0.8),
      );
      c.drawPath(
        seam,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..blendMode = BlendMode.plus
          ..color = _venom.fade(0.35 * pulse),
      );
    }
    // 등판 무늬. 좌우 대칭 얼룩이 경고색 역할을 한다.
    for (var i = 0; i < 4; i++) {
      final y = at.dy - 96 + i * 52.0;
      for (final s in const [-1.0, 1.0]) {
        final mark = smoothClosedPath([
          Offset(at.dx + s * (30 + i * 8), y),
          Offset(at.dx + s * (86 + i * 10), y - 16 + i * 4),
          Offset(at.dx + s * (104 + i * 6), y + 18),
          Offset(at.dx + s * (48 + i * 6), y + 26),
        ], tension: 0.8);
        c.drawPath(mark, Paint()..color = const Color(0xFF0E0A16).fade(0.55));
        c.drawPath(
          mark,
          Paint()
            ..blendMode = BlendMode.plus
            ..color = _venom.fade(0.10 * pulse),
        );
      }
    }
    c.restore();

    // 등 가시.
    for (var i = 0; i < 5; i++) {
      final a = -2.5 + i * 0.36;
      final dir = Offset(math.cos(a), math.sin(a));
      final root = at + dir * 150;
      final len = 44 + math.sin(i * 1.1) * 22;
      final spike = smoothClosedPath([
        root - dir.perp * 13,
        root + dir * len,
        root + dir.perp * 13,
      ], tension: 0.5);
      paintSurface(c, spike, _sFang, l, detail: detail, seed: 913 + i);
      rimBand(c, spike, l, width: 3, alpha: 0.7, color: _venom);
    }

    glowPath(c, body, _venom, 26, alpha: 0.22 * pulse);
    rimBand(c, body, l, width: 7, alpha: 0.6, color: _venom);
  }

  /// 흉부. 다리 여섯이 모두 여기에 박혀 있다.
  void _thorax(Canvas c, LightRig l, double sway, double rise, double detail) {
    final at = Offset(468 + sway, 806 + rise);
    final shell = blob(
      at,
      170,
      134,
      rotation: -0.1,
      warp: (a, u) => 1 + math.cos(a * 2 + 0.4) * 0.12,
    );
    castShadow(c, shell, offset: const Offset(12, 16), blur: 20, alpha: 0.5);
    paintSurface(c, shell, _sShell, l, detail: detail, seed: 921);

    c.save();
    c.clipPath(shell);
    // 등껍질 중앙의 홈과 방사형 근육 자국.
    panelLine(
      c,
      smoothOpenPath([
        at + const Offset(-120, -18),
        at + const Offset(0, -34),
        at + const Offset(118, -6),
      ]),
      _rShell,
      l,
      width: 9,
    );
    for (var i = 0; i < 6; i++) {
      final a = math.pi * (0.15 + i * 0.14);
      final d = Offset(math.cos(a), math.sin(a));
      panelLine(
        c,
        smoothOpenPath([at + d * 40, at + d * 140]),
        _rShell,
        l,
        width: 6,
        alpha: 0.8,
      );
    }
    c.restore();

    // 다리 부착부의 관절막.
    for (final leg in _legs) {
      final p = leg.$1 + Offset(sway, rise);
      final socket = blob(p, leg.$4 * 1.35, leg.$4 * 1.1);
      paintSurface(c, socket, _sJoint, l, detail: detail, rim: false, seed: 923);
    }

    rimBand(c, shell, l, width: 6, alpha: 0.65, color: _venom);
  }

  /// 낫처럼 치켜든 포획 앞다리.
  void _scythe(Canvas c, LightRig l, double t, double detail,
      {required bool mirror}) {
    final k = mirror ? 1.0 : -1.0;
    final twitch = math.sin(t * 1.6 + (mirror ? 1.4 : 0)) * 9;
    final base = Offset(mirror ? 384 : 336, mirror ? 790 : 816);
    final elbow = Offset(
      base.dx + k * 40 - 60,
      base.dy - 210 + twitch,
    );
    final tip = Offset(
      elbow.dx + k * 150 - 40,
      elbow.dy - 190 - twitch * 0.6,
    );

    final upper = tube(
      [base, lerpO(base, elbow, 0.5), elbow],
      const [34, 27, 21],
      samples: 16,
    );
    paintSurface(c, upper, mirror ? _sShell : _sShellDark, l,
        detail: detail, seed: 931);

    final joint = blob(elbow, 26, 23);
    paintSurface(c, joint, _sJoint, l, detail: detail, seed: 933);

    // 낫날: 안쪽이 오목하고 바깥이 볼록한 초승달.
    final dir = (tip - elbow).normalized();
    final n = dir.perp;
    final blade = smoothClosedPath([
      elbow - n * k * 20,
      elbow + dir * 90 - n * k * 44,
      elbow + dir * 170 - n * k * 30,
      tip,
      elbow + dir * 150 + n * k * 6,
      elbow + dir * 70 + n * k * 16,
      elbow + n * k * 18,
    ], tension: 0.8);
    paintSurface(c, blade, _sFang, l, detail: detail, seed: 935);

    c.save();
    c.clipPath(blade);
    // 날 안쪽의 톱니.
    for (var i = 0; i < 7; i++) {
      final u = 0.12 + i * 0.12;
      final p = lerpO(elbow, tip, u) + n * k * (14 - u * 6);
      c.drawPath(
        smoothClosedPath([
          p - dir * 10,
          p + n * k * 16,
          p + dir * 10,
        ], tension: 0.4),
        Paint()..color = _rShell.light.fade(0.5),
      );
    }
    c.restore();
    rimBand(c, blade, l, width: 4, alpha: 0.85, color: _venom.lighten(0.2));

    // 날 끝에 맺힌 독액.
    if (detail > 0.4) {
      final drip = (t * 0.5 + (mirror ? 0.5 : 0)) % 1.0;
      final p = tip + Offset(0, drip * 90);
      final drop = blob(p, 7 - drip * 3, 11 - drip * 4);
      paintSurface(
        c,
        drop,
        const Surface(_venom, Finish.slime, glow: 0.6, glowColor: _venom),
        l,
      );
      glowAt(c, tip, 22, _venom, intensity: 0.5);
    }
  }

  void _head(Canvas c, LightRig l, double t, double sway, double rise,
      double detail) {
    final hc = Offset(284 + sway * 1.4, 846 + rise * 0.8);

    // 두흉부 앞쪽. 눈이 박히는 판.
    final face = smoothClosedPath([
      hc + const Offset(-110, -26),
      hc + const Offset(-56, -88),
      hc + const Offset(36, -96),
      hc + const Offset(102, -48),
      hc + const Offset(110, 28),
      hc + const Offset(48, 88),
      hc + const Offset(-40, 86),
      hc + const Offset(-106, 36),
    ], tension: 0.86);
    paintSurface(c, face, _sShell, l, detail: detail, seed: 941);

    // 협각과 독니.
    for (final s in const [-1.0, 1.0]) {
      final root = hc + Offset(s * 34, 52);
      final cheli = tube(
        [root, root + Offset(s * 10, 44), root + Offset(-s * 6, 92)],
        const [30, 24, 12],
        samples: 14,
      );
      paintSurface(c, cheli, _sShellDark, l, detail: detail, seed: 943);
      final fang = tube(
        [
          root + Offset(-s * 6, 88),
          root + Offset(-s * 26, 124),
          root + Offset(-s * 38, 154),
        ],
        const [11, 6, 1.5],
        samples: 12,
      );
      paintSurface(c, fang, _sFang, l, detail: detail, seed: 945);
      rimBand(c, fang, l, width: 3, alpha: 0.8, color: _venom);
      if (detail > 0.5) {
        glowAt(c, root + Offset(-s * 38, 154), 16, _venom, intensity: 0.45);
      }
    }

    // 촉지(작은 더듬이 다리).
    for (final s in const [-1.0, 1.0]) {
      final root = hc + Offset(s * 74, 40);
      final palp = tube(
        [
          root,
          root + Offset(s * 46, 6 + math.sin(t * 2 + s) * 8),
          root + Offset(s * 88, 52),
        ],
        const [15, 11, 6],
        samples: 12,
      );
      paintSurface(c, palp, _sShellDark, l, detail: detail, seed: 947);
    }

    // 여덟 개의 눈. 앞줄 큰 두 개 + 나머지 여섯 개.
    const eyes = <(Offset, double)>[
      (Offset(-30, -14), 20),
      (Offset(26, -12), 20),
      (Offset(-62, -34), 11),
      (Offset(-8, -46), 10),
      (Offset(50, -40), 11),
      (Offset(-46, 16), 9),
      (Offset(10, 22), 8),
      (Offset(62, 8), 9),
    ];
    for (final e in eyes) {
      final p = hc + e.$1;
      final r = e.$2;
      glowAt(c, p, r * 3.2, _eye, intensity: 0.55);
      // 반구형 홑눈: 아래쪽이 밝고 위가 어둡다.
      c.drawCircle(
        p,
        r,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.3, 0.4),
            colors: [
              _eye.lighten(0.5),
              _eye,
              _eye.darken(0.55),
              const Color(0xFF160408),
            ],
            stops: const [0.0, 0.32, 0.74, 1.0],
          ).createShader(Rect.fromCircle(center: p, radius: r)),
      );
      c.drawCircle(
        p,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.22
          ..color = _rShell.deep.fade(0.9),
      );
      c.drawCircle(
        p + Offset(-r * 0.32, -r * 0.34),
        r * 0.30,
        Paint()..color = white.fade(0.9),
      );
    }

    // 눈 위를 덮는 각질 융기.
    c.drawPath(
      smoothOpenPath([
        hc + const Offset(-84, -30),
        hc + const Offset(-10, -66),
        hc + const Offset(74, -38),
      ]),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 16
        ..strokeCap = StrokeCap.round
        ..color = _rShell.deep,
    );

    rimBand(c, face, l, width: 5, alpha: 0.7, color: _venom);
  }
}
