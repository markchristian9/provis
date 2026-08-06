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

/// 바위·암석 노두.
///
/// ## 왜 이렇게 그리는가
///
/// 바위를 둥근 덩어리 하나로 그리면 감자가 된다. 바위가 바위로 읽히는 이유는
/// **평면(facet)의 집합**이기 때문이다 — 깨진 면들이 서로 다른 각도로 빛을
/// 받아 명도가 계단처럼 갈리고, 그 경계가 날카롭다.
///
/// 그래서 여기서는 반투명 오버레이로 명도를 흉내 내지 않고, **면을 실제로
/// 만들어 각각 칠한다**. 면마다 바깥을 향한 방향(법선의 근사)이 있고, 그것과
/// 광원 방향의 내적이 그 면의 밝기가 된다. 이 한 가지가 조약돌과 암석을
/// 가른다.
class RockProp extends Prop {
  RockProp({
    required this.seed,
    this.size = 70,
    this.color,
    this.mossy = false,
    this.shards = 0,
    this.buried = 0.22,
  }) {
    final r = Rng(seed);
    _w = size * r.bell(0.9, 1.35);
    _h = size * r.bell(0.62, 0.95);
    _tone = color ??
        hsl(r.range(200, 240), r.range(0.03, 0.11), r.range(0.36, 0.48));
    _noise = Noise(seed * 41 + 7);
    _facets = _buildFacets(r.branch(3));
    _outline = _buildOutline();
  }

  final int seed;

  /// 바위의 기준 반경(px).
  final double size;

  final Color? color;

  /// 이끼를 얹는다. 습한 지형·폐허에 쓴다.
  final bool mossy;

  /// 주변에 흩어진 파편 개수. 큰 바위 옆에 두면 풍화의 역사가 읽힌다.
  final int shards;

  /// 지면에 파묻힌 정도(0..1). 0.2 쯤이면 땅에서 솟은 노두로 보인다.
  final double buried;

  late final double _w;
  late final double _h;
  late final Color _tone;
  late final Noise _noise;

  /// (형상, 바깥을 향한 방향, 위를 향한 정도)
  late final List<(Path, Offset, double)> _facets;
  late final Path _outline;

  @override
  double get height => _h * 2;

  @override
  bool get walkable => false;

  /// 각진 다각형 하나. 광물은 곡선이 아니라 직선으로 깨진다.
  Path _chunk(Offset at, double rx, double ry, int sides, Rng r) {
    final path = Path();
    final start = r.range(0, math.pi * 2);
    for (var i = 0; i < sides; i++) {
      final a = start + (i / sides) * math.pi * 2 + r.signed(0.28);
      final m = 0.72 + r.unit * 0.44;
      final p = at + Offset(math.cos(a) * rx * m, math.sin(a) * ry * m);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    return path;
  }

  /// 덩어리를 여러 면으로 조립한다.
  ///
  /// 아래쪽에 넓은 베이스 면 몇 개, 그 위에 작은 면 몇 개. 이 위계가 있어야
  /// 바위가 "쌓여서 깨진 것"으로 보이고, 크기가 같은 면을 늘어놓으면 자갈
  /// 무더기가 된다.
  List<(Path, Offset, double)> _buildFacets(Rng r) {
    final out = <(Path, Offset, double)>[];
    final baseY = -_h * 0.55;

    // 베이스 — 넓고 낮다.
    final baseCount = r.intRange(2, 4);
    for (var i = 0; i < baseCount; i++) {
      final t = baseCount == 1 ? 0.5 : i / (baseCount - 1);
      final at = Offset(
        (t - 0.5) * _w * 1.05,
        baseY + _h * r.range(-0.10, 0.22),
      );
      final rx = _w * r.range(0.52, 0.78);
      final ry = _h * r.range(0.62, 0.92);
      final dir = Offset(at.dx / _w, -0.35).normalized();
      out.add((_chunk(at, rx, ry, r.intRange(5, 7), r), dir, 0.25));
    }

    // 상단 — 좁고 위를 향한다. 하늘을 받으므로 가장 밝다.
    final topCount = r.intRange(2, 4);
    for (var i = 0; i < topCount; i++) {
      final at = Offset(
        r.signed(_w * 0.46),
        baseY - _h * r.range(0.42, 0.86),
      );
      final rx = _w * r.range(0.26, 0.46);
      final ry = _h * r.range(0.32, 0.54);
      final dir = Offset(at.dx / _w * 0.7, -1.0).normalized();
      out.add((_chunk(at, rx, ry, r.intRange(4, 6), r), dir, 0.9));
    }
    return out;
  }

  Path _buildOutline() {
    final p = Path()..fillType = PathFillType.nonZero;
    for (final (shape, _, _) in _facets) {
      p.addPath(shape, Offset.zero);
    }
    return p;
  }

  @override
  void paint(Canvas c, double t, LightRig light, {double detail = 1.0}) {
    propShadow(c, _w * 0.98, light, alpha: 0.44, stretch: 1.2);
    // 바위는 땅에 박혀 있다. 밑동 흙과 짙은 접촉이 그 사실을 말한다.
    if (detail > 0.3) {
      rootSkirt(c, _w * 0.92, _tone.mix(const Color(0xFF4A3B2A), 0.55), light,
          seed: seed, squash: 0.34, alpha: 0.5);
    }
    contactAO(c, _w * 0.72, alpha: 0.5);

    // 면을 하나씩 칠한다. 밝기는 면이 향한 방향과 광원의 내적으로 정한다 —
    // 반투명 오버레이로 흉내 내면 색이 탁해지고 경계가 흐려진다.
    for (final (i, facet) in _facets.indexed) {
      final (shape, dir, up) = facet;
      final ndl = (dir.dx * light.dir.dx + dir.dy * light.dir.dy).clamp(-1.0, 1.0);
      final lit = (0.5 + 0.5 * ndl);
      final tone = _tone
          .lighten(0.20 * lit * (0.5 + 0.5 * up))
          .darken(0.26 * (1 - lit))
          .mix(light.ambient, 0.30 * (1 - lit));
      paintSurface(
        c,
        shape,
        Surface(tone, Finish.stone, contrast: 1.25),
        light,
        detail: detail,
        seed: seed + i * 13,
        rim: false,
      );
      // 위를 향한 면만 하늘빛을 받는다.
      if (up > 0.5) {
        topPlane(c, shape, light, strength: 0.55 * up);
      }
      // 면 경계 — 광물의 날카로움은 이 선에서 나온다.
      c.drawPath(
        shape,
        Paint()
          ..isAntiAlias = true
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(0.9, _w * 0.012)
          ..color = _tone.darken(0.42).fade(0.45),
      );
    }

    // 균열 — 면을 가로지르는 깊은 금. 몇 줄이면 충분하다.
    if (detail > 0.45) {
      final r = Rng(seed * 97 + 5);
      c.save();
      c.clipPath(_outline);
      final crack = Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 3; i++) {
        final from = Offset(r.signed(_w * 0.8), -_h * r.range(0.3, 1.5));
        final pts = <Offset>[from];
        var p = from;
        final dir = Offset(r.signed(1), -r.range(0.2, 1.0)).normalized();
        for (var j = 0; j < 4; j++) {
          p = p + dir.rotated(r.signed(0.7)) * (_w * r.range(0.16, 0.34));
          pts.add(p);
        }
        final line = smoothOpenPath(pts, tension: 0.6);
        crack
          ..strokeWidth = math.max(0.8, _w * 0.016)
          ..color = _tone.darken(0.55).fade(0.55);
        c.drawPath(line, crack);
        crack
          ..strokeWidth = math.max(0.5, _w * 0.008)
          ..color = _tone.lighten(0.30).fade(0.35);
        c.drawPath(line.shift(-light.dir * _w * 0.014), crack);
      }
      c.restore();
    }

    if (mossy && detail > 0.4) _paintMoss(c, light, detail);

    // 실루엣 전체에 얹는 백라이트. 바위를 배경에서 떼어 놓는다.
    if (detail > 0.5) {
      rimBand(c, _outline, light, width: _w * 0.055, alpha: 0.52, blur: 2);
    }

    for (var i = 0; i < shards; i++) {
      final r = Rng(seed * 197 + i * 13);
      final sx = r.signed(_w * 1.6);
      final ss = _w * r.range(0.12, 0.26);
      c.save();
      c.translate(sx, -ss * 0.16);
      contactAO(c, ss * 1.1, alpha: 0.34);
      final shard = _chunk(Offset(0, -ss * 0.45), ss, ss * 0.7, 5, r);
      final ndl = light.dir.dy * -1;
      paintSurface(
        c,
        shard,
        Surface(_tone.lighten(0.06 * ndl).darken(0.05), Finish.stone,
            contrast: 1.2),
        light,
        detail: detail * 0.6,
        seed: seed + i,
        rim: false,
      );
      topPlane(c, shard, light, strength: 0.5);
      c.restore();
    }
  }

  void _paintMoss(Canvas c, LightRig l, double detail) {
    // 이끼는 위쪽 면과 그늘진 북사면에 낀다. 아무 데나 뿌리면 물감 자국이 된다.
    final r = Rng(seed * 53 + 29);
    c.save();
    c.clipPath(_outline);
    final moss = hsl(r.range(84, 116), r.range(0.30, 0.46), r.range(0.24, 0.34));
    for (var i = 0; i < 4; i++) {
      final px = r.signed(_w * 0.75);
      final py = -_h * r.range(0.9, 1.7);
      final rad = _w * r.range(0.26, 0.48);
      final patch = blob(
        Offset(px, py),
        rad,
        rad * 0.42,
        points: 11,
        warp: (angle, u) => 1.0 + 0.32 * _noise.signed1(u * 6 + i * 3.1),
      );
      paintSurface(c, patch, Surface(moss, Finish.foliage, contrast: 0.85), l,
          detail: detail * 0.6, seed: seed + i * 7, ao: false, rim: false);
      // 이끼 가장자리의 잔털. 매끈한 얼룩은 페인트다.
      if (detail > 0.6) {
        scatterLeaves(c, Offset(px, py), rad, rad * 0.42, moss.lighten(0.10), l,
            seed: seed + i * 31, count: 8, size: 0.22);
      }
    }
    c.restore();
  }
}

/// 지면에 흩어진 자갈밭. 큰 바위 주변을 채워 지형에 이야기를 준다.
class PebbleField extends Prop {
  PebbleField({
    required this.seed,
    this.radius = 90,
    this.count = 12,
    this.color,
  });

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
    final tone = color ?? hsl(r.range(200, 236), 0.06, 0.42);
    final n = (count * (0.4 + 0.6 * detail)).round();

    // 자갈이 깔린 흙바닥. 자갈만 띄엄띄엄 그리면 공중에 뜬다.
    final bed = blob(Offset.zero, radius, radius * 0.9,
        points: 11, warp: (a, u) => 1.0 + 0.22 * math.sin(u * 7 + seed));
    final bb = bed.getBounds();
    c.drawPath(
      bed,
      Paint()
        ..isAntiAlias = true
        ..shader = Gradient.radial(
          bb.center,
          bb.width * 0.5,
          [
            tone.darken(0.35).fade(0.42),
            tone.darken(0.30).fade(0.22),
            tone.fade(0.0),
          ],
          const [0.0, 0.6, 1.0],
        ),
    );

    for (var i = 0; i < n; i++) {
      final a = r.range(0, math.pi * 2);
      final d = radius * math.sqrt(r.unit);
      final p = Offset(math.cos(a) * d, math.sin(a) * d);
      final s = radius * r.range(0.035, 0.095);
      final stone = blob(p, s, s * 0.72,
          points: 7, warp: (angle, u) => 1.0 + 0.22 * math.sin(u * 7 + i));
      // 광원 반대쪽 그림자를 먼저 — 자갈이 그 위에 놓인 것으로 보인다.
      c.drawPath(
        stone.shift(Offset(-light.dir.dx * s * 0.55, -light.dir.dy * s * 0.30)),
        Paint()
          ..isAntiAlias = true
          ..color = const Color(0xFF05070E).fade(0.30)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.35),
      );
      final sb = stone.getBounds();
      c.drawPath(
        stone,
        Paint()
          ..isAntiAlias = true
          ..shader = Gradient.linear(
            sb.center + Offset(light.dir.dx * s, light.dir.dy * s),
            sb.center - Offset(light.dir.dx * s, light.dir.dy * s),
            [
              tone.lighten(0.30 + r.range(0.0, 0.16)),
              tone.darken(0.18).mix(light.ambient, 0.3),
            ],
          ),
      );
    }
  }
}
