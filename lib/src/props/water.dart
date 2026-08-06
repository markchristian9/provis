import 'dart:math' as math;
import 'dart:ui';

import '../core/noise.dart';
import '../core/palette.dart';
import '../core/rng.dart';
import '../core/scheme.dart';
import '../core/shading.dart';
import '../core/spline.dart';
import 'prop.dart';

/// 웅덩이·연못·개울.
///
/// ## 왜 이렇게 그리는가
///
/// 물을 파란 타원으로 칠하면 페인트 자국이 된다. 물이 물로 보이는 이유는
/// 여러 겹이 겹쳐 있기 때문이다.
///
/// 1. **물가가 먼저다.** 젖은 흙과 얕은 여울이 물과 땅 사이에 있어야 물이
///    지면에 파인 것으로 보인다. 이 띠가 없으면 파란 스티커를 붙인 것이 된다.
/// 2. **깊이** — 가장자리는 바닥이 비쳐 밝고 탁하며, 가운데는 어둡고 푸르다.
/// 3. **하늘 반사** — 수면은 하늘을 비춘다. 조명의 림 색을 위쪽에 얹으면
///    물이 아래가 아니라 위를 향한 면이라는 사실이 전달된다.
/// 4. **잔물결과 반짝임** — 흐르는 선 + 광원 쪽에 모이는 점광. 정지한 물은
///    유리판이다.
///
/// [grounded] 가 `true` 이므로 지면 평면에 눕는다 — 원이 2:1 타원이 된다.
class WaterProp extends Prop {
  WaterProp({
    required this.seed,
    this.radius = 120,
    this.color,
    this.ripple = 1.0,
    this.shallow = false,
    this.reeds = true,
  }) {
    final r = Rng(seed);
    _tone = color ??
        hsl(r.range(188, 210), r.range(0.34, 0.52), r.range(0.24, 0.34));
    _noise = Noise(seed * 71 + 3);
    _shape = blob(
      Offset.zero,
      radius,
      radius * 0.94,
      points: 15,
      warp: (angle, u) => 1.0 + 0.20 * _noise.signed1(u * 6.0),
    );
    _bank = blob(
      Offset.zero,
      radius * 1.16,
      radius * 1.10,
      points: 15,
      warp: (angle, u) => 1.0 + 0.22 * _noise.signed1(u * 5.2 + 11),
    );
  }

  final int seed;
  final double radius;
  final Color? color;

  /// 잔물결 세기. 0 이면 거울 같은 수면이 된다.
  final double ripple;

  /// 얕은 물. 캐릭터가 걸어 들어갈 수 있고 바닥이 더 많이 비친다.
  final bool shallow;

  /// 물가에 갈대를 세운다. 물과 지면의 경계를 자연스럽게 만든다.
  final bool reeds;

  late final Color _tone;
  late final Noise _noise;
  late final Path _shape;
  late final Path _bank;

  @override
  bool get grounded => true;

  @override
  double get height => 4;

  @override
  bool get walkable => shallow;

  @override
  Size get footprint =>
      Size((radius / 78).ceilToDouble(), (radius / 78).ceilToDouble());

  @override
  void paint(Canvas c, double t, LightRig light, {double detail = 1.0}) {
    _paintBank(c, light, detail);
    _paintSurface(c, light, t, detail);
    if (reeds && detail > 0.45) _paintReeds(c, light, t, detail);
  }

  /// 물가 — 젖은 흙과 모래. 물보다 먼저 그려야 물이 그 안에 담긴다.
  void _paintBank(Canvas c, LightRig l, double detail) {
    final bb = _bank.getBounds();
    final mud = _tone.mix(const Color(0xFF6B5335), 0.72).darken(0.10);
    c.drawPath(
      _bank,
      Paint()
        ..isAntiAlias = true
        ..shader = Gradient.radial(
          bb.center,
          bb.width * 0.5,
          [mud.fade(0.0), mud.fade(0.55), mud.fade(0.72), mud.fade(0.0)],
          const [0.60, 0.78, 0.90, 1.0],
        ),
    );
    // 물가 자갈 — 경계선을 흩어 놓는다.
    if (detail > 0.5) {
      final r = Rng(seed * 29 + 3);
      final paint = Paint()..isAntiAlias = true;
      for (var i = 0; i < 14; i++) {
        final a = r.range(0, math.pi * 2);
        final d = radius * r.range(0.98, 1.14);
        final p = Offset(math.cos(a) * d, math.sin(a) * d * 0.94);
        final s = radius * r.range(0.014, 0.032);
        paint.color = mud.lighten(r.range(0.14, 0.34)).fade(0.8);
        c.drawOval(
          Rect.fromCenter(center: p, width: s * 2.4, height: s * 1.5),
          paint,
        );
      }
    }
  }

  void _paintSurface(Canvas c, LightRig light, double t, double detail) {
    c.save();
    c.clipPath(_shape);
    final b = _shape.getBounds();

    // ① 깊이 — 가장자리는 바닥이 비쳐 밝고 탁하며 중심이 어둡다.
    final edge = _tone
        .lighten(shallow ? 0.34 : 0.22)
        .mix(const Color(0xFF7A6A45), shallow ? 0.34 : 0.18);
    final deep = _tone.darken(shallow ? 0.08 : 0.28);
    c.drawRect(
      b,
      Paint()
        ..isAntiAlias = true
        ..shader = Gradient.radial(
          b.center,
          b.width * 0.55,
          [deep, deep.mix(edge, 0.5), edge],
          const [0.0, 0.62, 1.0],
        ),
    );

    // ② 바닥 — 얕은 물에서는 돌과 모래가 비쳐 보인다.
    if (detail > 0.45) {
      final r = Rng(seed * 37 + 11);
      final bedPaint = Paint()..isAntiAlias = true;
      final n = shallow ? 12 : 6;
      for (var i = 0; i < n; i++) {
        final a = r.range(0, math.pi * 2);
        final d = radius * math.sqrt(r.unit) * 0.9;
        final p = Offset(math.cos(a) * d, math.sin(a) * d * 0.94);
        final s = radius * r.range(0.03, 0.075);
        // 물을 통과해 보이는 것은 대비가 낮고 색이 물 쪽으로 밀린다.
        bedPaint
          ..color = _tone.mix(const Color(0xFF8C7A55), 0.55).fade(0.22)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.5);
        c.drawOval(
          Rect.fromCenter(center: p, width: s * 2.2, height: s * 1.3),
          bedPaint,
        );
      }
    }

    // ③ 하늘 반사 — 수면이 위를 향한 면임을 말해 준다.
    c.drawRect(
      b,
      Paint()
        ..isAntiAlias = true
        ..blendMode = BlendMode.plus
        ..shader = Gradient.linear(
          b.topCenter,
          b.bottomCenter,
          [light.rim.fade(0.26), light.rim.fade(0.03)],
          const [0.0, 0.85],
        ),
    );

    // ④ 잔물결 — 흐르는 밝은 선. 위상이 다른 여러 겹을 겹쳐야 반복이 안 보인다.
    if (ripple > 0.01 && detail > 0.3) {
      final lines = detail > 0.6 ? 8 : 4;
      for (var i = 0; i < lines; i++) {
        final u = (i + 0.5) / lines;
        final phase = t * (0.30 + i * 0.06) + i * 1.7;
        final y = b.top + b.height * ((u + phase * 0.05) % 1.0);
        final amp = radius * 0.045 * ripple;
        final pts = <Offset>[
          for (var j = 0; j <= 8; j++)
            Offset(
              b.left + b.width * (j / 8),
              y + math.sin(phase + j * 0.9) * amp,
            ),
        ];
        c.drawPath(
          smoothOpenPath(pts),
          Paint()
            ..isAntiAlias = true
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1.0, radius * 0.013)
            ..strokeCap = StrokeCap.round
            ..blendMode = BlendMode.plus
            ..color = light.rim.fade(0.15 * (1 - (u - 0.5).abs())),
        );
      }
    }

    // ⑤ 반짝임 — 광원 쪽에 몰린 점광. 수면에 방향을 준다.
    if (detail > 0.55) {
      final r = Rng(seed * 53 + 7);
      for (var i = 0; i < 10; i++) {
        final phase = math.sin(t * 1.6 + i * 2.3) * 0.5 + 0.5;
        if (phase < 0.35) continue;
        final p = Offset(
              light.dir.dx * radius * 0.42,
              light.dir.dy * radius * 0.30,
            ) +
            Offset(r.signed(radius * 0.62), r.signed(radius * 0.42));
        glowAt(c, p, radius * 0.028 * phase, light.key,
            intensity: 0.55 * phase);
      }
    }

    c.restore();

    // ⑥ 물가 선 — 젖은 테두리가 있어야 물이 땅에 파묻힌 것으로 보인다.
    c.drawPath(
      _shape,
      Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.5, radius * 0.030)
        ..color = _tone.darken(0.42).fade(0.5),
    );
    // 광원 쪽 가장자리에만 반짝임을 얹는다.
    c.drawPath(
      _shape,
      Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, radius * 0.016)
        ..blendMode = BlendMode.plus
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.02)
        ..shader = Gradient.linear(
          Offset(light.dir.dx * radius, light.dir.dy * radius),
          Offset(-light.dir.dx * radius, -light.dir.dy * radius),
          [light.key.fade(0.55), light.key.fade(0.0)],
        ),
    );
  }

  /// 갈대 — 물과 지면의 경계를 자연스럽게 만든다. 물가에만, 뭉쳐서 심는다.
  void _paintReeds(Canvas c, LightRig l, double t, double detail) {
    final r = Rng(seed * 83 + 13);
    final green = hsl(r.range(74, 100), r.range(0.28, 0.44), r.range(0.30, 0.40));
    final clumps = detail > 0.6 ? 4 : 2;
    final stalk = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (var k = 0; k < clumps; k++) {
      final a = r.range(0, math.pi * 2);
      final d = radius * r.range(0.92, 1.06);
      final at = Offset(math.cos(a) * d, math.sin(a) * d * 0.94);
      final n = r.intRange(4, 8);
      for (var i = 0; i < n; i++) {
        // grounded 라 세로가 눌린다. 그만큼 높이를 부풀려 서 있는 인상을 남긴다.
        final h = radius * r.range(0.24, 0.46);
        final lean = r.signed(0.5);
        final w = math.sin(t * 1.1 + k * 2.0 + i) * h * 0.10;
        final root = at + Offset(r.signed(radius * 0.06), r.signed(radius * 0.03));
        final blade = smoothOpenPath([
          root,
          root + Offset(lean * h * 0.20 + w * 0.4, -h * 0.55),
          root + Offset(lean * h * 0.55 + w, -h),
        ]);
        stalk
          ..strokeWidth = math.max(1.0, radius * 0.011)
          ..color = green
              .darken(0.10 * (i % 3))
              .mix(l.ambient, 0.16)
              .fade(0.88);
        c.drawPath(blade, stalk);
      }
    }
  }
}

/// 용암·독성 늪처럼 스스로 빛나는 액체.
///
/// 물과 달리 **자신이 광원**이므로 하늘 반사가 아니라 자체 발광으로 그린다.
/// 발광체를 그렸으면 주변 기물에도 같은 색 반사광을 반영해야 장면에 속한다.
class LavaProp extends Prop {
  LavaProp({
    required this.seed,
    this.radius = 120,
    this.hot = const Color(0xFFFF7A2E),
    this.crust = const Color(0xFF2A1410),
  }) {
    _noise = Noise(seed * 37 + 11);
    _shape = blob(Offset.zero, radius, radius * 0.92,
        points: 15, warp: (angle, u) => 1.0 + 0.22 * _noise.signed1(u * 5.5));
  }

  final int seed;
  final double radius;
  final Color hot;
  final Color crust;

  late final Noise _noise;
  late final Path _shape;

  @override
  bool get grounded => true;

  @override
  double get height => 4;

  @override
  bool get walkable => false;

  @override
  void paint(Canvas c, double t, LightRig light, {double detail = 1.0}) {
    // 바깥으로 새어 나가는 열기. 클립 이전에 그려야 형상 밖으로 번진다.
    c.drawPath(
      _shape,
      Paint()
        ..isAntiAlias = true
        ..blendMode = BlendMode.plus
        ..color = hot.fade(0.30)
        ..maskFilter = MaskFilter.blur(BlurStyle.outer, radius * 0.35),
    );

    c.save();
    c.clipPath(_shape);
    final b = _shape.getBounds();

    // 굳은 표면 — 어둡다. 그 사이로 갈라진 틈에서 빛이 샌다.
    c.drawRect(b, Paint()..color = crust);

    // 판(plate) — 굳은 표면은 한 장이 아니라 조각들이 떠 있는 것이다.
    if (detail > 0.4) {
      final r = Rng(seed * 61 + 5);
      final plate = Paint()..isAntiAlias = true;
      for (var i = 0; i < 7; i++) {
        final p = Offset(r.signed(radius * 0.85), r.signed(radius * 0.72));
        final s = radius * r.range(0.18, 0.36);
        final poly = Path();
        final sides = r.intRange(5, 7);
        for (var j = 0; j < sides; j++) {
          final a = (j / sides) * math.pi * 2 + r.signed(0.3);
          final q = p + Offset(math.cos(a) * s, math.sin(a) * s * 0.8);
          if (j == 0) {
            poly.moveTo(q.dx, q.dy);
          } else {
            poly.lineTo(q.dx, q.dy);
          }
        }
        poly.close();
        plate.color = crust.lighten(r.range(0.04, 0.16)).fade(0.9);
        c.drawPath(poly, plate);
      }
    }

    final veins = detail > 0.5 ? 6 : 3;
    for (var i = 0; i < veins; i++) {
      final phase = t * 0.25 + i * 2.1;
      final pts = <Offset>[
        for (var j = 0; j <= 7; j++)
          Offset(
            b.left + b.width * (j / 7),
            b.center.dy +
                math.sin(phase + j * 1.1 + i) * radius * 0.30 +
                (i - veins / 2) * radius * 0.16,
          ),
      ];
      final vein = smoothOpenPath(pts);
      c.drawPath(
        vein,
        Paint()
          ..isAntiAlias = true
          ..style = PaintingStyle.stroke
          ..strokeWidth = radius * (0.05 + 0.02 * math.sin(phase * 1.7))
          ..blendMode = BlendMode.plus
          ..color = hot.fade(0.85)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.04),
      );
      c.drawPath(
        vein,
        Paint()
          ..isAntiAlias = true
          ..style = PaintingStyle.stroke
          ..strokeWidth = radius * 0.018
          ..blendMode = BlendMode.plus
          ..color = const Color(0xFFFFF0C0).withValues(alpha: 0.9),
      );
    }
    c.restore();
  }
}
