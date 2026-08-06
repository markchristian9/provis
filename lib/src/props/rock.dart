import 'dart:math' as math;
import 'dart:ui';

import '../core/palette.dart';
import '../core/rng.dart';
import '../core/scheme.dart';
import '../core/shading.dart';
import '../core/spline.dart';
import 'prop.dart';

/// 바위·암석 노두.
///
/// ## 왜 이렇게 그리는가
///
/// 바위를 둥근 덩어리 하나로 그리면 감자가 된다. 바위가 바위로 읽히는 이유는
/// **평면(facet)의 집합**이기 때문이다. 깨진 면들이 서로 다른 각도로 빛을
/// 받아 명도가 계단처럼 갈리고, 그 경계가 날카롭다.
///
/// 그래서 여기서는 실루엣만 스플라인으로 부드럽게 잡고, **내부는 직선 면으로
/// 쪼갠다**. 유기체는 곡선, 광물은 직선이라는 규칙의 전형적인 사례다.
class RockProp extends Prop {
  RockProp({
    required this.seed,
    this.size = 70,
    this.color,
    this.mossy = false,
    this.shards = 0,
  }) {
    final r = Rng(seed);
    _w = size * r.bell(0.9, 1.35);
    _h = size * r.bell(0.62, 0.95);
    _tone = color ??
        hsl(r.range(200, 235), r.range(0.04, 0.12), r.range(0.34, 0.46));
    _facets = r.intRange(3, 6);
    _outline = _buildOutline(r);
  }

  final int seed;

  /// 바위의 기준 반경(px).
  final double size;

  final Color? color;

  /// 이끼를 얹는다. 습한 지형·폐허에 쓴다.
  final bool mossy;

  /// 주변에 흩어진 파편 개수. 큰 바위 옆에 두면 풍화의 역사가 읽힌다.
  final int shards;

  late final double _w;
  late final double _h;
  late final Color _tone;
  late final int _facets;
  late final Path _outline;

  @override
  double get height => _h * 2;

  @override
  bool get walkable => false;

  List<Offset> _ring(Rng r) {
    // 실루엣은 부드럽게, 다만 완전한 타원은 피한다. 위쪽이 좁고 아래가 넓어야
    // 땅에 박힌 것으로 보인다.
    const n = 9;
    return [
      for (var i = 0; i < n; i++)
        () {
          final a = (i / n) * math.pi * 2;
          final up = -math.sin(a); // +1 위
          final rx = _w * (1.0 - 0.20 * math.max(0.0, up)) * r.range(0.86, 1.14);
          final ry = _h * r.range(0.88, 1.12);
          return Offset(math.cos(a) * rx, -math.sin(a) * ry - _h * 0.55);
        }(),
    ];
  }

  Path _buildOutline(Rng r) => smoothClosedPath(_ring(r), tension: 0.72);

  @override
  void paint(Canvas c, double t, LightRig light, {double detail = 1.0}) {
    propShadow(c, _w * 0.95, light, alpha: 0.45, stretch: 1.2);

    paintSurface(c, _outline, Surface(_tone, Finish.stone, contrast: 1.15), light,
        detail: detail, seed: seed);

    // 깨진 면. 실루엣 안쪽을 직선으로 갈라 각 면의 명도를 달리한다.
    if (detail > 0.35) {
      final r = Rng(seed * 41 + 17);
      c.save();
      c.clipPath(_outline);
      for (var i = 0; i < _facets; i++) {
        final ax = r.range(-1.0, 1.0) * _w;
        final ay = -_h * r.range(0.2, 1.4);
        final ang = r.range(-0.9, 0.9);
        final len = _w * 2.4;
        final n = Offset(math.cos(ang), math.sin(ang));
        final a = Offset(ax, ay) - n * len;
        final b = Offset(ax, ay) + n * len;
        // 면의 한쪽을 덮는 사다리꼴을 만들어 명도를 갈아 준다.
        final side = Path()
          ..moveTo(a.dx, a.dy)
          ..lineTo(b.dx, b.dy)
          ..lineTo(b.dx + n.perp.dx * len, b.dy + n.perp.dy * len)
          ..lineTo(a.dx + n.perp.dx * len, a.dy + n.perp.dy * len)
          ..close();
        final lit = r.chance(0.5);
        c.drawPath(
          side,
          Paint()
            ..isAntiAlias = true
            ..blendMode = lit ? BlendMode.plus : BlendMode.multiply
            ..color = (lit ? light.key : light.ambient)
                .fade(lit ? 0.055 : 0.16),
        );
        // 면 경계선. 광물의 날카로움은 이 선에서 나온다.
        c.drawLine(
          a,
          b,
          Paint()
            ..isAntiAlias = true
            ..strokeWidth = math.max(0.8, _w * 0.014)
            ..color = _tone.darken(0.3).fade(0.5),
        );
      }
      c.restore();
    }

    if (mossy && detail > 0.4) _paintMoss(c, light, detail);

    // 상단 능선 하이라이트 — 위를 향한 면이 하늘을 받는다.
    topPlane(c, _outline, light, strength: 0.55);
    if (detail > 0.5) {
      rimBand(c, _outline, light, width: _w * 0.06, alpha: 0.5, blur: 2);
    }

    for (var i = 0; i < shards; i++) {
      final r = Rng(seed * 97 + i * 13);
      final sx = r.signed(_w * 1.5);
      final ss = _w * r.range(0.12, 0.26);
      c.save();
      c.translate(sx, -ss * 0.2);
      final shard = smoothClosedPath([
        Offset(-ss, 0),
        Offset(-ss * 0.5, -ss * 0.9),
        Offset(ss * 0.4, -ss * 0.7),
        Offset(ss, 0),
      ], tension: 0.6);
      paintSurface(c, shard, Surface(_tone.darken(0.05), Finish.stone), light,
          detail: detail * 0.5, seed: seed + i);
      c.restore();
    }
  }

  void _paintMoss(Canvas c, LightRig l, double detail) {
    // 이끼는 위쪽 면과 북사면에 낀다. 아무 데나 뿌리면 물감 자국이 된다.
    final r = Rng(seed * 53 + 29);
    c.save();
    c.clipPath(_outline);
    final moss = hsl(r.range(85, 115), r.range(0.30, 0.48), r.range(0.26, 0.36));
    for (var i = 0; i < 4; i++) {
      final px = r.signed(_w * 0.8);
      final py = -_h * r.range(0.9, 1.6);
      final rad = _w * r.range(0.28, 0.5);
      final patch = blob(
        Offset(px, py),
        rad,
        rad * 0.45,
        points: 11,
        warp: (angle, u) => 1.0 + 0.3 * math.sin(u * 9 + i),
      );
      paintSurface(c, patch, Surface(moss, Finish.fur, contrast: 0.8), l,
          detail: detail * 0.6, seed: seed + i * 7, ao: false);
    }
    c.restore();
  }
}

/// 지면에 흩어진 자갈밭. 큰 바위 주변을 채워 지형에 이야기를 준다.
class PebbleField extends Prop {
  PebbleField({required this.seed, this.radius = 90, this.count = 12, this.color});

  final int seed;
  final double radius;
  final int count;
  final Color? color;

  @override
  bool get grounded => true;

  @override
  double get height => 6;

  @override
  bool get walkable => true;

  @override
  void paint(Canvas c, double t, LightRig light, {double detail = 1.0}) {
    final r = Rng(seed);
    final tone = color ?? hsl(r.range(200, 230), 0.06, 0.40);
    final n = (count * (0.4 + 0.6 * detail)).round();
    for (var i = 0; i < n; i++) {
      final a = r.range(0, math.pi * 2);
      final d = radius * math.sqrt(r.unit);
      final p = Offset(math.cos(a) * d, math.sin(a) * d);
      final s = radius * r.range(0.035, 0.085);
      final stone = blob(p, s, s * 0.8, points: 7,
          warp: (angle, u) => 1.0 + 0.2 * math.sin(u * 7 + i));
      c.drawPath(
        stone,
        Paint()
          ..isAntiAlias = true
          ..color = tone.lighten(r.range(0.0, 0.18)).fade(0.9),
      );
      // 광원 반대쪽에 얇은 그림자를 깔아 자갈이 지면에 놓인 것으로 만든다.
      c.drawPath(
        stone.shift(Offset(-light.dir.dx * s * 0.5, -light.dir.dy * s * 0.3)),
        Paint()
          ..isAntiAlias = true
          ..blendMode = BlendMode.multiply
          ..color = light.ambient.fade(0.22),
      );
    }
  }
}
