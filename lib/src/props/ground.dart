import 'dart:math' as math;
import 'dart:ui';

import '../core/noise.dart';
import '../core/palette.dart';
import '../core/rng.dart';
import '../core/scheme.dart';
import '../core/shading.dart';
import '../core/spline.dart';
import 'prop.dart';

/// 지면을 덮는 식생·흙 패치.
///
/// 아이소 맵에서 빈 타일이 계속되면 화면이 격자무늬 장판이 된다. 이 기물은
/// 그 사이를 메워 **지면에 이야기를 준다** — 풀이 자란 곳, 흙이 드러난 곳,
/// 꽃이 핀 곳. 통행을 막지 않으므로 아무 데나 뿌려도 된다.
class GroundPatch extends Prop {
  GroundPatch({
    required this.seed,
    this.radius = 90,
    this.color,
    this.blades = 0,
    this.flowerColor,
  }) {
    final r = Rng(seed);
    _tone = color ?? hsl(r.range(88, 118), r.range(0.22, 0.40), r.range(0.24, 0.34));
    _noise = Noise(seed * 19 + 5);
    _shape = blob(Offset.zero, radius, radius * 0.9,
        points: 13, warp: (angle, u) => 1.0 + 0.26 * _noise.signed1(u * 5.0));
  }

  final int seed;
  final double radius;
  final Color? color;

  /// 삐져나온 풀잎 개수. 0 이면 평평한 패치.
  final int blades;

  /// 꽃 색. 주면 풀잎 끝에 점을 찍는다.
  final Color? flowerColor;

  late final Color _tone;
  late final Noise _noise;
  late final Path _shape;

  @override
  bool get grounded => true;

  @override
  double get height => 8;

  @override
  bool get walkable => true;

  @override
  void paint(Canvas c, double t, LightRig light, {double detail = 1.0}) {
    // 가장자리가 흐려야 지면에 스며든 것으로 보인다. 선명한 테두리를 두면
    // 스티커가 된다.
    c.save();
    c.clipPath(_shape);
    final b = _shape.getBounds();
    c.drawRect(
      b,
      Paint()
        ..isAntiAlias = true
        ..shader = Gradient.radial(
          b.center,
          b.width * 0.55,
          [_tone.fade(0.92), _tone.fade(0.70), _tone.fade(0.0)],
          const [0.0, 0.62, 1.0],
        ),
    );
    // 얼룩 — 단색 패치는 물감이다.
    if (detail > 0.4) {
      final r = Rng(seed * 29 + 7);
      for (var i = 0; i < 5; i++) {
        final p = Offset(r.signed(radius * 0.6), r.signed(radius * 0.5));
        final s = radius * r.range(0.18, 0.36);
        c.drawCircle(
          p,
          s,
          Paint()
            ..isAntiAlias = true
            ..color = (r.chance(0.5) ? _tone.lighten(0.10) : _tone.darken(0.10))
                .fade(0.35)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.6),
        );
      }
    }
    c.restore();

    if (blades > 0 && detail > 0.35) _paintBlades(c, light, t, detail);
  }

  void _paintBlades(Canvas c, LightRig l, double t, double detail) {
    final r = Rng(seed * 43 + 13);
    final n = (blades * (0.5 + 0.5 * detail)).round();
    final tip = _tone.lighten(0.22).saturate(0.15);
    for (var i = 0; i < n; i++) {
      final a = r.range(0, math.pi * 2);
      final d = radius * math.sqrt(r.unit) * 0.85;
      final root = Offset(math.cos(a) * d, math.sin(a) * d * 0.9);
      final h = radius * r.range(0.12, 0.26);
      final sway = math.sin(t * 1.3 + i * 0.9) * h * 0.18;
      // 풀잎은 지면 평면 위에 서지만, 이 Prop 은 grounded 라 세로가 눌린다.
      // 그래서 높이를 그만큼 부풀려 서 있는 느낌을 남긴다.
      final blade = smoothOpenPath([
        root,
        root + Offset(sway * 0.4, -h * 0.6),
        root + Offset(sway, -h),
      ]);
      c.drawPath(
        blade,
        Paint()
          ..isAntiAlias = true
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.0, radius * 0.012)
          ..strokeCap = StrokeCap.round
          ..color = _tone.darken(0.05).fade(0.85),
      );
      if (flowerColor != null && r.chance(0.28)) {
        c.drawCircle(
          root + Offset(sway, -h),
          radius * 0.022,
          Paint()
            ..isAntiAlias = true
            ..color = flowerColor!.fade(0.95),
        );
      } else if (r.chance(0.3)) {
        c.drawCircle(
          root + Offset(sway, -h),
          radius * 0.012,
          Paint()..color = tip.fade(0.6),
        );
      }
    }
  }
}

/// 흙길·포장로 한 구간.
///
/// 길은 맵에서 **동선을 눈으로 보여 주는 장치**다. 캐릭터가 어디로 가야 할지
/// 텍스트 없이 알려 준다. 타일을 따라 이어 붙여 쓴다.
class PathPatch extends Prop {
  PathPatch({
    required this.seed,
    this.tileWidth = 156,
    this.isoRatio = 0.5,
    this.width = 0.62,
    this.color,
    this.alongX = true,
  }) {
    final r = Rng(seed);
    _tone = color ?? hsl(r.range(28, 40), r.range(0.16, 0.28), r.range(0.30, 0.40));
    _noise = Noise(seed * 23 + 9);
  }

  final int seed;
  final double tileWidth;
  final double isoRatio;

  /// 타일 폭 대비 길 너비.
  final double width;

  final Color? color;

  /// 진행 방향. `true` 면 월드 x 축을 따라 뻗는다.
  final bool alongX;

  late final Color _tone;
  late final Noise _noise;

  @override
  bool get grounded => true;

  @override
  double get height => 2;

  @override
  bool get walkable => true;

  @override
  void paint(Canvas c, double t, LightRig light, {double detail = 1.0}) {
    // grounded 라 세로가 이미 눌린 상태다. 여기서는 타일 한 칸을 덮는
    // 마름모를 그리되, 가장자리를 노이즈로 흔들어 인공적인 직선을 없앤다.
    final u = tileWidth * 0.5;
    final half = u * width;
    final dir = alongX ? const Offset(1, 1) : const Offset(-1, 1);
    final nrm = Offset(-dir.dy, dir.dx);

    final pts = <Offset>[];
    const steps = 6;
    for (var i = 0; i <= steps; i++) {
      final s = (i / steps) * 2 - 1;
      final w = half * (1 + 0.22 * _noise.signed1(i * 1.7));
      pts.add(dir * (u * s) + nrm * w);
    }
    for (var i = steps; i >= 0; i--) {
      final s = (i / steps) * 2 - 1;
      final w = half * (1 + 0.22 * _noise.signed1(i * 2.3 + 50));
      pts.add(dir * (u * s) - nrm * w);
    }
    final road = smoothClosedPath(pts, tension: 0.8);

    c.save();
    c.clipPath(road);
    final b = road.getBounds();
    c.drawRect(b, Paint()..color = _tone.fade(0.9));
    if (detail > 0.4) {
      final r = Rng(seed * 31 + 3);
      for (var i = 0; i < 8; i++) {
        final p = Offset(r.signed(u * 0.9), r.signed(half * 0.8));
        final s = u * r.range(0.04, 0.10);
        c.drawCircle(
          p,
          s,
          Paint()
            ..isAntiAlias = true
            ..color = (r.chance(0.5) ? _tone.lighten(0.12) : _tone.darken(0.14))
                .fade(0.5),
        );
      }
    }
    c.restore();
  }
}
