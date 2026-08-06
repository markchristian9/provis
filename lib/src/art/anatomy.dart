import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/painting.dart';

import '../core/noise.dart';
import '../core/palette.dart';
import '../core/shading.dart';
import '../core/spline.dart';

/// 인체 프리미티브.
///
/// 캐릭터를 자동 생성하는 "인체 시스템"은 일부러 만들지 않았다. 그런 식으로
/// 만든 캐릭터는 전부 형제처럼 닮아 버린다. 대신 여기에는 손으로 저작하기
/// 번거롭고 실수하기 쉬운 부분 — 두개골 곡선, 눈, 손, 흐르는 천 — 만 모아
/// 두고, 비율과 포즈는 각 캐릭터가 직접 결정한다.

/// 두개골 실루엣.
///
/// [turn] 은 -1(왼쪽 보기) ~ 1(오른쪽 보기) 의 얼굴 방향으로, 3/4 각도에서
/// 반대편 광대가 실루엣 밖으로 밀려 나오는 현상을 흉내 낸다.
Path headShape(
  Offset c,
  double w,
  double h, {
  double jaw = 0.74,
  double chin = 0.30,
  double turn = 0.0,
  double cheek = 1.0,
}) {
  final t = turn * 0.16;
  final pts = <Offset>[
    Offset(0.02 + t, -1.00), // 정수리
    Offset(-0.50 + t, -0.90),
    Offset(-0.85 + t * 0.6, -0.55),
    Offset(-0.97 * cheek + t * 0.3, -0.06), // 관자·광대
    Offset(-0.90 * cheek, 0.30),
    Offset(-jaw, 0.60), // 턱각
    Offset(-jaw * 0.62, 0.86),
    Offset(-chin, 1.00), // 턱끝
    Offset(chin, 1.00),
    Offset(jaw * 0.62, 0.86),
    Offset(jaw, 0.60),
    Offset(0.90 * cheek, 0.30),
    Offset(0.97 * cheek + t * 0.3, -0.06),
    Offset(0.85 + t * 0.6, -0.55),
    Offset(0.50 + t, -0.90),
  ];
  return smoothClosedPath(
    [for (final p in pts) c + Offset(p.dx * w, p.dy * h)],
    tension: 0.92,
  );
}

/// 몸통 실루엣. 어깨-가슴-허리-골반의 네 지름으로 체형이 결정된다.
Path torsoShape({
  required Offset chest,
  required Offset pelvis,
  required double shoulderW,
  required double chestW,
  required double waistW,
  required double hipW,
  double neckW = 0.0,
  double bust = 0.0,
}) {
  final dir = (pelvis - chest).normalized();
  final n = dir.perp;
  final len = (pelvis - chest).distance;

  Offset at(double t, double side) =>
      chest + dir * (len * t) + n * (side);

  final ring = <Offset>[
    at(-0.16, -neckW), // 목 밑동 왼쪽
    at(-0.10, -shoulderW * 0.86),
    at(0.06, -shoulderW),
    at(0.26, -chestW - bust),
    at(0.48, -waistW * 1.06),
    at(0.62, -waistW),
    at(0.82, -hipW),
    at(1.00, -hipW * 0.82),
    at(1.10, -hipW * 0.42),
    at(1.12, 0),
    at(1.10, hipW * 0.42),
    at(1.00, hipW * 0.82),
    at(0.82, hipW),
    at(0.62, waistW),
    at(0.48, waistW * 1.06),
    at(0.26, chestW + bust),
    at(0.06, shoulderW),
    at(-0.10, shoulderW * 0.86),
    at(-0.16, neckW),
  ];
  return smoothClosedPath(ring, tension: 0.85);
}

/// 팔·다리처럼 관절 두 개로 이어지는 사지.
Path limb(
  Offset a,
  Offset b,
  Offset c, {
  required double r0,
  required double r1,
  required double r2,
  double swell = 1.18,
}) {
  // 관절 사이 중간에 근육 부풀림을 넣는다. 일정한 두께의 튜브는 즉시
  // 마네킹처럼 보이므로, 상완/대퇴의 배는 항상 부풀려 준다.
  return tube(
    [a, lerpO(a, b, 0.55), b, lerpO(b, c, 0.45), c],
    [r0, r0 * swell, r1, r1 * 0.92, r2],
    samples: 26,
  );
}

/// 눈.
///
/// 캐릭터의 인상은 거의 전부 눈에서 나온다. 흰자 → 홍채 굴절 → 동공 →
/// 각막 하이라이트 → 눈꺼풀 그림자 → 속눈썹의 6겹을 모두 그려야 유리구슬이
/// 아니라 살아 있는 눈이 된다.
void drawEye(
  Canvas c,
  Offset at,
  double w,
  double h, {
  required Color iris,
  LightRig light = LightRig.heroic,
  double open = 1.0,
  double look = 0.0,
  double tilt = 0.0,
  bool mirrored = false,
  Color? glow,
  Color scleraTint = const Color(0xFFEDE6DE),
  double lash = 1.0,
}) {
  c.save();
  c.translate(at.dx, at.dy);
  if (tilt != 0) c.rotate(tilt);
  if (mirrored) c.scale(-1, 1);

  final o = open.clamp(0.08, 1.4);

  // 안와 그림자: 눈이 두개골에 파묻혀 있다는 사실을 만든다.
  c.drawOval(
    Rect.fromCenter(center: Offset(0, -h * 0.1), width: w * 2.9, height: h * 3.2),
    Paint()
      ..color = const Color(0xFF2A1A18).fade(0.32)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, h * 0.9),
  );

  final sclera = smoothClosedPath([
    Offset(-w, h * 0.10),
    Offset(-w * 0.55, -h * 0.78 * o),
    Offset(w * 0.05, -h * 1.00 * o),
    Offset(w * 0.68, -h * 0.62 * o),
    Offset(w, h * 0.22),
    Offset(w * 0.50, h * 0.78),
    Offset(-w * 0.10, h * 0.92),
    Offset(-w * 0.62, h * 0.62),
  ], tension: 0.9);

  c.drawPath(
    sclera,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, 0.4),
        colors: [
          scleraTint,
          scleraTint.darken(0.16).mix(const Color(0xFF9C6A62), 0.35),
        ],
        stops: const [0.45, 1.0],
      ).createShader(sclera.getBounds()),
  );

  c.save();
  c.clipPath(sclera);

  final ir = h * 0.98;
  final ic = Offset(look * w * 0.30, -h * 0.04);

  if (glow != null) {
    // 발광하는 눈은 흰자까지 물들인다.
    c.drawCircle(
      ic,
      ir * 2.2,
      Paint()
        ..blendMode = BlendMode.plus
        ..color = glow.fade(0.5)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, ir * 0.8),
    );
  }

  // 홍채: 각막 굴절 때문에 위쪽은 눈꺼풀 그림자로 어둡고 아래쪽은 밝게 튄다.
  final irisRect = Rect.fromCircle(center: ic, radius: ir);
  c.drawCircle(
    ic,
    ir,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, 0.35),
        colors: [
          iris.lighten(0.42),
          iris,
          iris.darken(0.45),
          iris.darken(0.72),
        ],
        stops: const [0.0, 0.42, 0.82, 1.0],
      ).createShader(irisRect),
  );

  // 홍채 섬유.
  final fib = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = math.max(0.5, ir * 0.07)
    ..color = iris.darken(0.5).fade(0.55);
  for (var i = 0; i < 14; i++) {
    final a = i / 14 * math.pi * 2 + 0.2;
    c.drawLine(
      ic + Offset(math.cos(a), math.sin(a)) * (ir * 0.42),
      ic + Offset(math.cos(a), math.sin(a)) * (ir * 0.94),
      fib,
    );
  }
  c.drawCircle(
    ic,
    ir * 0.99,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = ir * 0.16
      ..color = iris.darken(0.78).fade(0.85),
  );

  // 동공.
  c.drawCircle(ic, ir * 0.40, Paint()..color = const Color(0xFF0A0508));
  c.drawCircle(
    ic,
    ir * 0.40,
    Paint()
      ..shader = RadialGradient(
        colors: [iris.darken(0.85).fade(0.0), const Color(0xFF000000)],
        stops: const [0.4, 1.0],
      ).createShader(Rect.fromCircle(center: ic, radius: ir * 0.4)),
  );

  // 위 눈꺼풀이 안구에 드리우는 그림자.
  c.drawRect(
    sclera.getBounds().inflate(w * 0.2),
    Paint()
      ..blendMode = BlendMode.multiply
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF6A5560),
          const Color(0xFFC9BEC4),
          const Color(0xFFFFFFFF),
        ],
        stops: const [0.0, 0.24, 0.62],
      ).createShader(sclera.getBounds()),
  );

  c.restore();

  // 각막 하이라이트. 큰 것 하나 + 반대편 작은 것 하나가 규칙이다.
  final hl = Offset(light.dir.dx, light.dir.dy) * (ir * 0.52);
  c.drawCircle(
    ic + hl,
    ir * 0.30,
    Paint()..color = white.fade(0.92),
  );
  c.drawCircle(
    ic - hl * 0.85 + Offset(0, ir * 0.15),
    ir * 0.14,
    Paint()..color = white.fade(0.42),
  );

  // 눈꺼풀 라인과 속눈썹.
  if (lash > 0) {
    final lidTop = smoothOpenPath([
      Offset(-w, h * 0.10),
      Offset(-w * 0.55, -h * 0.78 * o),
      Offset(w * 0.05, -h * 1.00 * o),
      Offset(w * 0.68, -h * 0.62 * o),
      Offset(w, h * 0.22),
    ], tension: 0.9);
    c.drawPath(
      lidTop,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = h * 0.30 * lash
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF150C10).fade(0.9),
    );
    final lidBot = smoothOpenPath([
      Offset(w * 0.92, h * 0.28),
      Offset(w * 0.45, h * 0.80),
      Offset(-w * 0.12, h * 0.93),
      Offset(-w * 0.66, h * 0.60),
    ], tension: 0.9);
    c.drawPath(
      lidBot,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = h * 0.11
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF2A1A1C).fade(0.55),
    );
    if (lash > 0.9) {
      final lp = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF120A0E);
      for (var i = 0; i < 5; i++) {
        final u = 0.12 + i * 0.20;
        final base = Offset(
          lerpD(-w * 0.92, w * 0.86, u),
          -h * (0.55 + 0.42 * math.sin(u * math.pi)) * o,
        );
        lp.strokeWidth = h * 0.11 * (1.1 - u * 0.4);
        c.drawLine(
          base,
          base + Offset(-w * 0.06 - u * w * 0.16, -h * 0.42 * lash),
          lp,
        );
      }
    }
  }

  c.restore();
}

/// 눈썹.
void drawBrow(
  Canvas c,
  Offset at,
  double w,
  double thick,
  Color color, {
  double arch = 0.35,
  double angle = 0.0,
  bool mirrored = false,
}) {
  c.save();
  c.translate(at.dx, at.dy);
  c.rotate(angle);
  if (mirrored) c.scale(-1, 1);
  final path = smoothOpenPath([
    Offset(-w, thick * 0.6),
    Offset(-w * 0.35, -thick * arch * 2.2),
    Offset(w * 0.35, -thick * arch * 1.4),
    Offset(w, thick * 1.1),
  ]);
  c.drawPath(
    path,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thick * 2
      ..strokeCap = StrokeCap.round
      ..color = color,
  );
  c.restore();
}

/// 코. 콧대 하이라이트와 콧방울 그림자만으로 입체를 만든다.
void drawNose(
  Canvas c,
  Offset bridge,
  double w,
  double h,
  Ramp skin,
  LightRig l, {
  double turn = 0,
}) {
  final tip = bridge + Offset(turn * w * 0.35, h);
  c.drawPath(
    smoothOpenPath([
      bridge + Offset(-w * 0.1 + turn * w * 0.2, 0),
      bridge + Offset(-w * 0.22 + turn * w * 0.3, h * 0.55),
      tip + Offset(-w * 0.30, h * 0.06),
      tip + Offset(-w * 0.06, h * 0.20),
    ]),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.30
      ..strokeCap = StrokeCap.round
      ..color = skin.shadow.fade(0.55),
  );
  // 콧대 위 하이라이트.
  c.drawPath(
    smoothOpenPath([
      bridge + Offset(w * 0.06 + turn * w * 0.2, 0),
      bridge + Offset(w * 0.02 + turn * w * 0.3, h * 0.6),
      tip + Offset(-w * 0.02, -h * 0.02),
    ]),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.26
      ..strokeCap = StrokeCap.round
      ..color = skin.light.fade(0.5)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.18),
  );
  // 콧구멍 그림자.
  c.drawOval(
    Rect.fromCenter(
      center: tip + Offset(-w * 0.34, h * 0.16),
      width: w * 0.30,
      height: w * 0.20,
    ),
    Paint()..color = skin.deep.fade(0.7),
  );
  c.drawOval(
    Rect.fromCenter(
      center: tip + Offset(w * 0.30, h * 0.14),
      width: w * 0.26,
      height: w * 0.18,
    ),
    Paint()..color = skin.deep.fade(0.55),
  );
}

/// 입.
void drawMouth(
  Canvas c,
  Offset at,
  double w, {
  required Ramp skin,
  Color? lip,
  double smile = 0.0,
  double open = 0.0,
  double turn = 0,
}) {
  final l = lip ?? skin.mid.mix(const Color(0xFF9E4A4A), 0.45).darken(0.05);
  final cx = at.dx + turn * w * 0.18;
  final line = smoothOpenPath([
    Offset(cx - w, at.dy - smile * w * 0.16),
    Offset(cx - w * 0.35, at.dy + w * 0.09 - smile * w * 0.1),
    Offset(cx + w * 0.35, at.dy + w * 0.08 - smile * w * 0.1),
    Offset(cx + w, at.dy - smile * w * 0.14),
  ]);

  if (open > 0.02) {
    final mouth = smoothClosedPath([
      Offset(cx - w * 0.9, at.dy),
      Offset(cx, at.dy - w * 0.05),
      Offset(cx + w * 0.9, at.dy),
      Offset(cx, at.dy + w * open * 0.9),
    ]);
    c.drawPath(mouth, Paint()..color = const Color(0xFF2A0E12));
  }

  c.drawPath(
    line,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.16
      ..strokeCap = StrokeCap.round
      ..color = skin.deep.fade(0.8),
  );
  // 아랫입술: 빛을 받아 도톰하게 튀어나온다.
  c.drawPath(
    smoothOpenPath([
      Offset(cx - w * 0.72, at.dy + w * 0.12),
      Offset(cx, at.dy + w * 0.34),
      Offset(cx + w * 0.72, at.dy + w * 0.10),
    ]),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.30
      ..strokeCap = StrokeCap.round
      ..color = l.fade(0.55)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.14),
  );
  c.drawPath(
    smoothOpenPath([
      Offset(cx - w * 0.4, at.dy + w * 0.20),
      Offset(cx + w * 0.1, at.dy + w * 0.26),
    ]),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.13
      ..strokeCap = StrokeCap.round
      ..color = skin.spec.fade(0.4)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.1),
  );
}

/// 귀.
Path earShape(Offset at, double w, double h, {bool mirrored = false, double point = 0}) {
  final s = mirrored ? -1.0 : 1.0;
  return smoothClosedPath([
    at + Offset(0, -h),
    at + Offset(s * w * (0.9 + point), -h * (0.9 + point * 0.9)),
    at + Offset(s * w * 1.05, 0),
    at + Offset(s * w * 0.7, h * 0.75),
    at + Offset(s * w * 0.1, h),
    at + Offset(-s * w * 0.15, h * 0.3),
  ]);
}

/// 손. 주먹/펼침을 [grip] 으로 오간다.
Path handShape(
  Offset wrist,
  double angle,
  double size, {
  double grip = 1.0,
  bool mirrored = false,
}) {
  final dir = Offset(math.cos(angle), math.sin(angle));
  final n = dir.perp * (mirrored ? -1.0 : 1.0);
  final palm = wrist + dir * size * 0.62;
  final ring = <Offset>[
    wrist - n * size * 0.36,
    wrist + dir * size * 0.18 - n * size * 0.48,
    palm - n * size * 0.52,
    palm + dir * size * 0.42 - n * size * (0.42 - grip * 0.12),
    palm + dir * size * (0.62 - grip * 0.18),
    palm + dir * size * 0.40 + n * size * (0.46 - grip * 0.1),
    palm + n * size * 0.50,
    wrist + dir * size * 0.30 + n * size * 0.58, // 엄지 두덩
    wrist + n * size * 0.34,
  ];
  return smoothClosedPath(ring, tension: 0.85);
}

/// 손가락 마디. 손 실루엣 위에 얹어 손가락을 읽히게 한다.
void drawKnuckles(
  Canvas c,
  Offset wrist,
  double angle,
  double size,
  Ramp r,
  LightRig l, {
  bool mirrored = false,
  int count = 4,
}) {
  final dir = Offset(math.cos(angle), math.sin(angle));
  final n = dir.perp * (mirrored ? -1.0 : 1.0);
  final palm = wrist + dir * size * 0.66;
  for (var i = 0; i < count; i++) {
    final u = (i / (count - 1)) - 0.5;
    final a = palm + n * (u * size * 0.86) + dir * (size * 0.18);
    final b = a + dir * size * (0.34 - u.abs() * 0.16);
    panelLine(c, smoothOpenPath([a, b]), r, l, width: size * 0.11, alpha: 0.7);
  }
}

/// 부츠·발.
Path bootShape(Offset ankle, double toeDir, double size, {double heel = 0.5}) {
  final s = toeDir.sign == 0 ? 1.0 : toeDir.sign;
  return smoothClosedPath([
    ankle + Offset(-s * size * 0.34, -size * 0.30),
    ankle + Offset(s * size * 0.36, -size * 0.24),
    ankle + Offset(s * size * 0.62, size * 0.24),
    ankle + Offset(s * size * 0.98, size * 0.52),
    ankle + Offset(s * size * 0.86, size * 0.70),
    ankle + Offset(-s * size * 0.52 * heel * 2, size * 0.70),
    ankle + Offset(-s * size * 0.62, size * 0.34),
  ], tension: 0.8);
}

/// 흐르는 천의 스파인. 중력과 바람, 그리고 캐릭터의 호흡에 반응한다.
List<Offset> clothSpine(
  Offset anchor,
  Offset dir,
  double len,
  double t, {
  double sway = 0.22,
  double phase = 0,
  int segments = 6,
  double gravity = 0.55,
  double flutter = 1.0,
}) {
  final pts = <Offset>[anchor];
  final d = dir.normalized();
  final n = d.perp;
  for (var i = 1; i <= segments; i++) {
    final u = i / segments;
    final w = wobble(t * 1.35 + phase + u * 2.6, phase * 3.1) * sway * u * flutter;
    final g = gravity * u * u;
    pts.add(anchor +
        d * (len * u) +
        n * (len * w) +
        Offset(0, len * g * 0.35));
  }
  return pts;
}

/// 머리카락 한 다발. 뿌리에서 굵고 끝에서 가늘어진다.
Path hairStrand(
  Offset root,
  Offset dir,
  double len,
  double thick,
  double t, {
  double phase = 0,
  double curl = 0.35,
  double flutter = 0.5,
}) {
  final spine = clothSpine(
    root,
    dir,
    len,
    t,
    sway: curl,
    phase: phase,
    segments: 5,
    gravity: 0.3,
    flutter: flutter,
  );
  return tube(spine, [thick, thick * 0.95, thick * 0.7, thick * 0.35, 0.5],
      samples: 18);
}

/// 호흡. 정지 포즈를 살아 있게 만드는 최소한의 움직임.
double breathe(double t, {double speed = 1.0, double amp = 1.0, double phase = 0}) =>
    math.sin(t * speed * 1.6 + phase) * amp;

/// 미세 요동. 여러 주파수를 섞어 반복이 눈에 띄지 않게 한다.
double jitter(double t, double seed, {double amp = 1.0}) =>
    wobble(t, seed) * amp;

/// 근육 결. 몸통·팔의 볼륨을 보강하는 부드러운 음영선.
void drawMuscleLine(
  Canvas c,
  List<Offset> pts,
  Ramp r, {
  double width = 6,
  double alpha = 0.5,
  bool highlight = true,
  Offset lift = const Offset(-3, -4),
}) {
  final p = smoothOpenPath(pts);
  c.drawPath(
    p,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..color = r.deep.fade(alpha)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, width * 0.55),
  );
  if (!highlight) return;
  c.drawPath(
    p.shift(lift),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width * 0.6
      ..strokeCap = StrokeCap.round
      ..color = r.light.fade(alpha * 0.6)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, width * 0.5),
  );
}

/// 상승하는 입자. 마력·재·포자 등 캐릭터 주변의 공기를 표현한다.
void drawMotes(
  Canvas c,
  Rect area,
  double t,
  Color color, {
  int count = 24,
  double size = 5,
  double speed = 40,
  int seed = 3,
  bool glow = true,
  double drift = 0.4,
}) {
  final n = Noise(seed);
  for (var i = 0; i < count; i++) {
    final sx = n.at1(i * 3.71);
    final sy = n.at1(i * 7.13 + 40);
    final life = (t * speed / area.height + sy) % 1.0;
    final x = area.left +
        area.width * sx +
        math.sin(t * 0.9 + i * 1.7) * area.width * drift * 0.12;
    final y = area.bottom - area.height * life;
    final a = math.sin(life * math.pi).clamp(0.0, 1.0);
    final r = size * (0.45 + n.at1(i * 11.3) * 0.9);
    if (glow) {
      glowAt(c, Offset(x, y), r * 3.2, color, intensity: 0.42 * a);
    }
    c.drawCircle(
      Offset(x, y),
      r * 0.55,
      Paint()
        ..blendMode = BlendMode.plus
        ..color = color.lighten(0.4).fade(0.85 * a),
    );
  }
}
