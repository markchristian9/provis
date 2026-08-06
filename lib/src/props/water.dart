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
/// 세 겹이 겹쳐 있기 때문이다.
///
/// 1. **깊이** — 가장자리는 바닥이 비쳐 밝고 탁하며, 가운데는 어둡고 푸르다.
/// 2. **하늘 반사** — 수면은 하늘을 비춘다. 조명의 림 색을 위쪽에 얹으면
///    물이 아래가 아니라 위를 향한 면이라는 사실이 전달된다.
/// 3. **잔물결** — 시간에 따라 흐르는 밝은 선. 정지한 물은 유리판이다.
///
/// [grounded] 가 `true` 이므로 지면 평면에 눕는다 — 원이 2:1 타원이 된다.
class WaterProp extends Prop {
  WaterProp({
    required this.seed,
    this.radius = 120,
    this.color,
    this.ripple = 1.0,
    this.shallow = false,
  }) {
    final r = Rng(seed);
    _tone = color ??
        hsl(r.range(190, 212), r.range(0.42, 0.62), r.range(0.28, 0.38));
    _noise = Noise(seed * 71 + 3);
    _shape = blob(
      Offset.zero,
      radius,
      radius * 0.94,
      points: 15,
      warp: (angle, u) => 1.0 + 0.20 * _noise.signed1(u * 6.0),
    );
  }

  final int seed;
  final double radius;
  final Color? color;

  /// 잔물결 세기. 0 이면 거울 같은 수면이 된다.
  final double ripple;

  /// 얕은 물. 캐릭터가 걸어 들어갈 수 있고 바닥이 더 많이 비친다.
  final bool shallow;

  late final Color _tone;
  late final Noise _noise;
  late final Path _shape;

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
    c.save();
    c.clipPath(_shape);

    // ① 깊이 — 가장자리가 밝고 중심이 어둡다.
    final b = _shape.getBounds();
    final edge = _tone.lighten(shallow ? 0.30 : 0.18).desaturate(0.25);
    final deep = _tone.darken(shallow ? 0.06 : 0.22);
    c.drawRect(
      b,
      Paint()
        ..isAntiAlias = true
        ..shader = Gradient.radial(
          b.center,
          b.width * 0.55,
          [deep, deep.mix(edge, 0.55), edge],
          const [0.0, 0.62, 1.0],
        ),
    );

    // ② 하늘 반사 — 수면이 위를 향한 면임을 말해 준다.
    c.drawRect(
      b,
      Paint()
        ..isAntiAlias = true
        ..blendMode = BlendMode.plus
        ..shader = Gradient.linear(
          b.topCenter,
          b.bottomCenter,
          [light.rim.fade(0.30), light.rim.fade(0.04)],
          const [0.0, 0.85],
        ),
    );

    // ③ 잔물결 — 흐르는 밝은 선. 위상이 다른 두 겹을 겹쳐야 반복이 안 보인다.
    if (ripple > 0.01 && detail > 0.3) {
      final lines = (detail > 0.6 ? 7 : 4);
      for (var i = 0; i < lines; i++) {
        final u = (i + 0.5) / lines;
        final phase = t * (0.35 + i * 0.07) + i * 1.7;
        final y = b.top + b.height * ((u + phase * 0.06) % 1.0);
        final amp = radius * 0.05 * ripple;
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
            ..strokeWidth = math.max(1.0, radius * 0.012)
            ..blendMode = BlendMode.plus
            ..color = light.rim.fade(0.16 * (1 - (u - 0.5).abs())),
        );
      }
    }

    c.restore();

    // 물가 — 젖은 테두리가 있어야 물이 땅에 파묻힌 것으로 보인다.
    c.drawPath(
      _shape,
      Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.5, radius * 0.035)
        ..color = _tone.darken(0.35).fade(0.55),
    );
    // 광원 쪽 가장자리에만 반짝임을 얹는다.
    c.drawPath(
      _shape,
      Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, radius * 0.015)
        ..blendMode = BlendMode.plus
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.02)
        ..shader = Gradient.linear(
          Offset(light.dir.dx * radius, light.dir.dy * radius),
          Offset(-light.dir.dx * radius, -light.dir.dy * radius),
          [light.key.fade(0.55), light.key.fade(0.0)],
        ),
    );
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
