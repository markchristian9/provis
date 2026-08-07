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
    // 화강암(회청)과 사암(황갈) 두 대역. 한 대역만 쓰면 맵의 바위가 전부
    // 같은 광물로 보인다.
    _tone = color ??
        (r.chance(0.55)
            ? hsl(r.range(196, 232), r.range(0.04, 0.10), r.range(0.36, 0.48))
            : hsl(r.range(28, 46), r.range(0.08, 0.18), r.range(0.34, 0.46)));
    _noise = Noise(seed * 41 + 7);
    final fr = r.branch(3);
    _ring = _buildRing(fr);
    _facets = _buildFacets(fr);
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
  late final List<Offset> _ring;

  /// (형상, 바깥을 향한 방향, 위를 향한 정도)
  late final List<(Path, Offset, double)> _facets;
  late final Path _outline;

  @override
  double get height => _h * 2;

  // 형상이 시간에 따라 바뀌지 않는다 — 한 번 굽고 재생만 한다.
  @override
  bool get bakeable => true;

  @override
  Rect get bakeBounds {
    final w = _w * 2.6 + size;
    return Rect.fromLTRB(-w, -(_h * 2.4 + size * 0.3), w, size * 0.9);
  }

  @override
  bool get walkable => false;

  /// 실루엣 정점. 아래가 넓고 위가 좁아야 땅에 박힌 덩어리로 보인다.
  List<Offset> _buildRing(Rng r) {
    const n = 9;
    return [
      for (var i = 0; i < n; i++)
        () {
          final a = (i / n) * math.pi * 2;
          final up = -math.sin(a); // +1 위
          final rx = _w * (1.0 - 0.34 * math.max(0.0, up)) * r.range(0.84, 1.14);
          final ry = _h * r.range(0.88, 1.12);
          return Offset(math.cos(a) * rx, -math.sin(a) * ry - _h * 0.80);
        }(),
    ];
  }

  /// 덩어리 하나를 면으로 쪼갠다.
  ///
  /// 다각형 여럿을 흩어 놓고 합치면 실루엣이 들쭉날쭉해 **깨진 접시**가 된다.
  /// 바위는 하나의 돌덩이고 면은 그 위에 새겨진 것이므로, 실루엣을 먼저 정하고
  /// 그 안을 능선에서 뻗어 나온 면으로 **빈틈없이** 채운다.
  List<(Path, Offset, double)> _buildFacets(Rng r) {
    final n = _ring.length;
    final center = Offset(0, -_h * 0.80);
    // 능선 두 점. 비대칭이라야 자연 암석으로 보인다.
    final peakA = Offset(-_w * r.range(0.20, 0.34), -_h * r.range(1.5, 1.8));
    final peakB = Offset(_w * r.range(0.14, 0.30), -_h * r.range(1.6, 1.95));
    final split = (peakA.dx + peakB.dx) * 0.5;

    final out = <(Path, Offset, double)>[];
    for (var i = 0; i < n; i++) {
      final p0 = _ring[i];
      final p1 = _ring[(i + 1) % n];
      final mid = lerpO(p0, p1, 0.5);
      // 위쪽 정점 사이는 능선 자체가 지나므로 면을 만들지 않는다.
      final peak = mid.dx < split ? peakA : peakB;
      final other = mid.dx < split ? peakB : peakA;
      final face = Path()
        ..moveTo(p0.dx, p0.dy)
        ..lineTo(p1.dx, p1.dy)
        ..lineTo(peak.dx, peak.dy);
      // 능선을 가로지르는 면은 사각형이 되어야 상단이 평평해진다.
      if ((p0.dx - split).sign != (p1.dx - split).sign) {
        face.lineTo(other.dx, other.dy);
      }
      face.close();

      final dir = (mid - center).normalized();
      final up = (-dir.dy).clamp(0.0, 1.0);
      out.add((face, dir, up));
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

    // ① 먼저 **덩어리 전체**를 한 번 칠한다. 면을 하나씩 불투명하게 칠하면
    //    조각들이 서로 떨어져 부서진 접시처럼 보인다. 바위는 하나의 돌덩이고,
    //    면은 그 위에 **새겨진** 것이다.
    paintSurface(
      c,
      _outline,
      Surface(_tone, Finish.stone, contrast: 1.2),
      light,
      detail: detail,
      seed: seed,
      rim: false,
    );

    // ② 그 위에 면마다 명도만 갈아 준다. 밝기는 면이 향한 방향과 광원의
    //    내적이다 — 이것이 조약돌과 암석을 가른다.
    c.save();
    c.clipPath(_outline);
    for (final facet in _facets) {
      final (shape, dir, up) = facet;
      final ndl =
          (dir.dx * light.dir.dx + dir.dy * light.dir.dy).clamp(-1.0, 1.0);
      final lit = 0.5 + 0.5 * ndl;
      final tone = _tone
          .lighten(0.30 * lit * (0.5 + 0.5 * up))
          .darken(0.32 * (1 - lit))
          .mix(light.ambient, 0.30 * (1 - lit));
      final sb = shape.getBounds();
      // 면 안에서도 광원 쪽이 조금 더 밝다. 완전 평면은 종이다.
      c.drawPath(
        shape,
        Paint()
          ..isAntiAlias = true
          ..shader = Gradient.linear(
            sb.center + Offset(light.dir.dx, light.dir.dy) * sb.width * 0.5,
            sb.center - Offset(light.dir.dx, light.dir.dy) * sb.width * 0.5,
            [tone.lighten(0.08).fade(0.80), tone.darken(0.08).fade(0.80)],
          ),
      );
      // 위를 향한 면만 하늘빛을 받는다.
      if (up > 0.5) {
        topPlane(c, shape, light, strength: 0.55 * up);
      }
      // 면 경계 — 광물의 날카로움은 이 선에서 나온다. 다만 진하면 조각이 된다.
      c.drawPath(
        shape,
        Paint()
          ..isAntiAlias = true
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(0.7, _w * 0.009)
          ..color = _tone.darken(0.42).fade(0.22),
      );
    }
    // ③ 아랫면은 하늘이 가려 어둡다. 덩어리를 하나로 묶는 마지막 한 겹.
    final ob = _outline.getBounds();
    c.drawRect(
      ob,
      Paint()
        ..isAntiAlias = true
        ..blendMode = BlendMode.multiply
        ..shader = Gradient.linear(
          Offset(ob.center.dx, ob.top),
          Offset(ob.center.dx, ob.bottom),
          [
            const Color(0xFFFFFFFF),
            const Color(0xFFFFFFFF),
            light.ambient.mix(const Color(0xFF6A7590), 0.5),
          ],
          const [0.0, 0.55, 1.0],
        ),
    );
    c.restore();

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
      final shard = Path();
      for (var j = 0; j < 5; j++) {
        final a = (j / 5) * math.pi * 2 + r.signed(0.3);
        final q = Offset(
          math.cos(a) * ss * r.range(0.7, 1.2),
          math.sin(a) * ss * 0.7 * r.range(0.7, 1.2) - ss * 0.45,
        );
        if (j == 0) {
          shard.moveTo(q.dx, q.dy);
        } else {
          shard.lineTo(q.dx, q.dy);
        }
      }
      shard.close();
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

  // 형상이 시간에 따라 바뀌지 않는다 — 한 번 굽고 재생만 한다.
  @override
  bool get bakeable => true;

  @override
  Rect get bakeBounds =>
      Rect.fromLTRB(-radius * 1.3, -radius * 0.9, radius * 1.3, radius * 0.9);

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
            tone.darken(0.38).fade(0.70),
            tone.darken(0.32).fade(0.42),
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
