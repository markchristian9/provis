import 'dart:math' as math;
import 'dart:ui';

import '../core/noise.dart';
import '../core/palette.dart';
import '../core/rng.dart';
import '../core/scheme.dart';
import '../core/shading.dart';
import '../core/spline.dart';
import 'prop.dart';
import 'prop_kit.dart';

/// 지면을 덮는 식생·흙 패치.
///
/// 아이소 맵에서 빈 타일이 계속되면 화면이 격자무늬 장판이 된다. 이 기물은
/// 그 사이를 메워 **지면에 이야기를 준다** — 풀이 자란 곳, 흙이 드러난 곳,
/// 꽃이 핀 곳. 통행을 막지 않으므로 아무 데나 뿌려도 된다.
///
/// ## 흐릿한 초록 얼룩이 되지 않으려면
///
/// 패치를 방사 그라디언트 하나로 칠하면 지면에 초록 안개를 뿌린 것이 된다.
/// 세 가지가 함께 있어야 풀밭으로 읽힌다.
///
/// 1. **얼룩의 층위** — 큰 색 변주 위에 작은 뭉침. 단색은 물감이다.
/// 2. **서 있는 풀** — 채워진 테이퍼 형상이라야 풀이고, 선으로 그으면 철사다.
///    풀잎은 뿌리가 어둡고 끝이 밝다.
/// 3. **뭉쳐서 난다** — 균등하게 흩뿌린 풀은 잔디밭 텍스처가 된다. 실제 풀은
///    포기 단위로 뭉친다.
class GroundPatch extends Prop {
  GroundPatch({
    required this.seed,
    this.radius = 90,
    this.color,
    this.blades = 0,
    this.flowerColor,
  }) {
    final r = Rng(seed);
    _tone =
        color ?? hsl(r.range(86, 116), r.range(0.24, 0.42), r.range(0.22, 0.32));
    _noise = Noise(seed * 19 + 5);
    _shape = blob(Offset.zero, radius, radius * 0.9,
        points: 13, warp: (angle, u) => 1.0 + 0.26 * _noise.signed1(u * 5.0));
  }

  final int seed;
  final double radius;
  final Color? color;

  /// 삐져나온 풀잎 개수. 0 이면 평평한 패치.
  final int blades;

  /// 꽃 색. 주면 풀 사이에 꽃을 피운다.
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
          [_tone.fade(0.90), _tone.fade(0.66), _tone.fade(0.0)],
          const [0.0, 0.62, 1.0],
        ),
    );

    // 얼룩 두 층 — 넓은 색 변주 위에 작은 뭉침.
    if (detail > 0.35) {
      final r = Rng(seed * 29 + 7);
      final paint = Paint()..isAntiAlias = true;
      for (var i = 0; i < 5; i++) {
        final p = Offset(r.signed(radius * 0.6), r.signed(radius * 0.5));
        final s = radius * r.range(0.20, 0.40);
        paint
          ..color = (r.chance(0.5)
                  ? _tone.lighten(0.12).saturate(0.10)
                  : _tone.darken(0.14))
              .fade(0.38)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.6);
        c.drawCircle(p, s, paint);
      }
      for (var i = 0; i < 9; i++) {
        final p = Offset(r.signed(radius * 0.82), r.signed(radius * 0.66));
        final s = radius * r.range(0.05, 0.13);
        paint
          ..color = _tone.darken(0.22).fade(0.30)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.7);
        c.drawCircle(p, s, paint);
      }
    }
    c.restore();

    if (blades > 0 && detail > 0.3) _paintBlades(c, light, t, detail);
  }

  void _paintBlades(Canvas c, LightRig l, double t, double detail) {
    final r = Rng(seed * 43 + 13);
    // 포기 단위로 뭉쳐 난다. 균등하게 흩뿌리면 잔디밭 텍스처가 된다.
    final clumps = (blades / 5).ceil().clamp(2, 10);
    final perClump = (5 * (0.5 + 0.5 * detail)).round();
    final paint = Paint()..isAntiAlias = true;

    for (var k = 0; k < clumps; k++) {
      final a = r.range(0, math.pi * 2);
      final d = radius * math.sqrt(r.unit) * 0.86;
      final at = Offset(math.cos(a) * d, math.sin(a) * d * 0.9);
      for (var i = 0; i < perClump; i++) {
        final root = at +
            Offset(r.signed(radius * 0.07), r.signed(radius * 0.035));
        // grounded 라 세로가 눌린다. 그만큼 높이를 부풀려 서 있는 인상을 남긴다.
        final h = radius * r.range(0.16, 0.34);
        final lean = r.signed(0.42) +
            math.sin(t * 1.3 + k * 1.7 + i) * 0.10;
        final blade = grassBlade(root, h, lean, width: r.range(0.10, 0.17));
        final bb = blade.getBounds();
        // 뿌리는 그늘에 잠기고 끝이 빛을 받는다. 이 세로 그라디언트가 풀을
        // 서 있게 만든다.
        paint.shader = Gradient.linear(
          Offset(bb.center.dx, bb.bottom),
          Offset(bb.center.dx, bb.top),
          [
            _tone.darken(0.30).mix(l.ambient, 0.28),
            _tone.lighten(0.06),
            _tone.lighten(0.30).saturate(0.16),
          ],
          const [0.0, 0.5, 1.0],
        );
        c.drawPath(blade, paint);
      }

      // 꽃 — 포기마다 한둘. 흩뿌리면 색 얼룩이 된다.
      if (flowerColor != null && r.chance(0.55)) {
        final n = r.intRange(1, 4);
        for (var i = 0; i < n; i++) {
          final h = radius * r.range(0.22, 0.36);
          final lean = r.signed(0.3);
          final root =
              at + Offset(r.signed(radius * 0.07), r.signed(radius * 0.03));
          final head = root + Offset(lean * h, -h);
          c.drawPath(
            grassBlade(root, h, lean, width: 0.05),
            Paint()
              ..isAntiAlias = true
              ..color = _tone.lighten(0.10).fade(0.9),
          );
          paintFlower(
            c,
            head,
            radius * r.range(0.045, 0.075),
            flowerColor!,
            flowerColor!.lighten(0.34).saturate(0.2),
            l,
            petals: 5,
            rotation: r.range(0, 2),
            // grounded 라 이미 눌려 있다 — 꽃은 정면을 보므로 덜 눌러 그린다.
            squash: 0.95,
          );
        }
      }
    }
    paint.shader = null;
  }
}

/// 흙길·포장로 한 구간.
///
/// 길은 맵에서 **동선을 눈으로 보여 주는 장치**다. 캐릭터가 어디로 가야 할지
/// 텍스트 없이 알려 준다. 타일을 따라 이어 붙여 쓴다.
///
/// 흙을 갈색으로 칠한 마름모는 장판이다. 길이 길로 보이는 이유는 **다닌
/// 흔적** 때문이다 — 바퀴자국 두 줄, 가운데 남은 잡초, 가장자리에 밀린 자갈.
class PathPatch extends Prop {
  PathPatch({
    required this.seed,
    this.tileWidth = 156,
    this.isoRatio = 0.5,
    this.width = 0.62,
    this.color,
    this.alongX = true,
    this.ruts = true,
  }) {
    final r = Rng(seed);
    _tone =
        color ?? hsl(r.range(26, 40), r.range(0.18, 0.30), r.range(0.28, 0.38));
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

  /// 수레바퀴 자국을 낸다.
  final bool ruts;

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
    // 띠를 그리되, 가장자리를 노이즈로 흔들어 인공적인 직선을 없앤다.
    final u = tileWidth * 0.5;
    final half = u * width;
    final dir = alongX ? const Offset(1, 1) : const Offset(-1, 1);
    final nrm = Offset(-dir.dy, dir.dx);

    final pts = <Offset>[];
    const steps = 6;
    for (var i = 0; i <= steps; i++) {
      final s = (i / steps) * 2 - 1;
      final w = half * (1 + 0.24 * _noise.signed1(i * 1.7));
      pts.add(dir * (u * s) + nrm * w);
    }
    for (var i = steps; i >= 0; i--) {
      final s = (i / steps) * 2 - 1;
      final w = half * (1 + 0.24 * _noise.signed1(i * 2.3 + 50));
      pts.add(dir * (u * s) - nrm * w);
    }
    final road = smoothClosedPath(pts, tension: 0.8);

    c.save();
    c.clipPath(road);
    final b = road.getBounds();

    // 노면 — 가운데가 밟혀 밝고 단단하며, 가장자리가 어둡고 축축하다.
    // **가장자리에서 알파를 떨어뜨린다.** 불투명한 띠로 끝나면 지면 위에 붙인
    // 갈색 테이프가 되고, 흙길이 땅에 스며든 것으로 보이지 않는다.
    c.drawRect(
      b,
      Paint()
        ..isAntiAlias = true
        ..shader = Gradient.linear(
          b.center - nrm * half,
          b.center + nrm * half,
          [
            _tone.darken(0.24).fade(0.0),
            _tone.darken(0.20).fade(0.72),
            _tone.lighten(0.06).fade(0.94),
            _tone.darken(0.20).fade(0.72),
            _tone.darken(0.24).fade(0.0),
          ],
          const [0.0, 0.18, 0.5, 0.82, 1.0],
        ),
    );

    if (detail > 0.35) {
      final r = Rng(seed * 31 + 3);
      final paint = Paint()..isAntiAlias = true;

      // 흙 얼룩.
      for (var i = 0; i < 8; i++) {
        final p = Offset(r.signed(u * 0.9), r.signed(half * 0.8));
        final s = u * r.range(0.05, 0.12);
        paint
          ..color = (r.chance(0.5) ? _tone.lighten(0.14) : _tone.darken(0.16))
              .fade(0.45)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.5);
        c.drawCircle(p, s, paint);
      }
      paint.maskFilter = null;

      // 바퀴자국 — 길에 방향과 역사를 준다.
      if (ruts) {
        final rut = Paint()
          ..isAntiAlias = true
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.5, half * 0.10)
          ..strokeCap = StrokeCap.round;
        for (final side in [-1.0, 1.0]) {
          final line = <Offset>[
            for (var i = 0; i <= 5; i++)
              dir * (u * ((i / 5) * 2 - 1)) +
                  nrm * (half * side * (0.42 + 0.10 * _noise.signed1(i * 3.1)))
          ];
          final p = smoothOpenPath(line);
          rut.color = _tone.darken(0.38).fade(0.55);
          c.drawPath(p, rut);
          rut
            ..color = _tone.lighten(0.20).fade(0.30)
            ..strokeWidth = math.max(0.9, half * 0.05);
          c.drawPath(p.shift(-light.dir * half * 0.06), rut);
        }
      }

      // 박힌 자갈 — 길이 다져졌음을 알린다.
      for (var i = 0; i < 7; i++) {
        final p = Offset(r.signed(u * 0.9), r.signed(half * 0.85));
        final s = u * r.range(0.012, 0.030);
        paint.color = _tone.lighten(r.range(0.18, 0.38)).fade(0.75);
        c.drawOval(
          Rect.fromCenter(center: p, width: s * 2.4, height: s * 1.4),
          paint,
        );
      }
    }
    c.restore();

    // 길가에 밀려난 풀 — 길과 지면의 경계를 자연스럽게 만든다.
    if (detail > 0.5) {
      final r = Rng(seed * 67 + 11);
      final grass = hsl(r.range(84, 110), 0.32, 0.28);
      final paint = Paint()..isAntiAlias = true;
      for (var i = 0; i < 10; i++) {
        final s = r.range(-1.0, 1.0);
        final side = r.chance(0.5) ? 1.0 : -1.0;
        final at = dir * (u * s) + nrm * (half * side * r.range(0.92, 1.10));
        final h = u * r.range(0.06, 0.13);
        paint.color = grass
            .lighten(r.range(0.0, 0.18))
            .mix(light.ambient, 0.18)
            .fade(0.85);
        c.drawPath(grassBlade(at, h, r.signed(0.4), width: 0.14), paint);
      }
    }
  }
}
