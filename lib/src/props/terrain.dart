import 'dart:math' as math;
import 'dart:ui';

import '../core/noise.dart';
import '../core/palette.dart';
import '../core/rng.dart';
import '../core/scheme.dart';
import '../core/shading.dart';
import '../core/spline.dart';
import '../iso/world_scale.dart';
import 'prop.dart';
import 'prop_kit.dart';

/// 지면에서 솟은 둔덕·언덕.
///
/// ## 왜 언덕이 필요한가
///
/// 아이소 맵의 지면은 완벽한 평면이라, 기물을 아무리 놓아도 화면이 한 층에
/// 머문다. 둔덕 하나가 있으면 **지면 자체에 높이가 있다**는 사실이 전달되고,
/// 그 순간 맵이 판이 아니라 지형이 된다.
///
/// ## 언덕이 언덕으로 보이는 세 가지
///
/// 1. **잘린 옆면이 보인다.** 위에서 내려다보는 아이소 시점에서 솟은 지형은
///    상단 면(풀)과 옆면(흙)이 동시에 보인다. 옆면이 없으면 지면에 초록
///    얼룩을 칠한 것과 구별되지 않는다.
/// 2. **흙에 층이 있다.** 옆면에 수평 지층 몇 줄이면 흙이 쌓여 온 시간이
///    읽힌다. 단색 갈색 벽은 판때기다.
/// 3. **풀이 가장자리를 넘는다.** 상단 풀이 옆면 위로 조금 흘러내려야 두 면이
///    같은 땅이 된다. 경계가 칼로 자른 듯하면 케이크가 된다.
class MoundProp extends Prop {
  MoundProp({
    required this.seed,
    this.radius = 120,
    this.rise = 48,
    this.isoRatio = 0.5,
    this.grassColor,
    this.soilColor,
    this.walkOver = false,
    this.tufts = 8,
    this.scale = const WorldScale(),
  }) {
    final r = Rng(seed);
    _grass = grassColor ??
        hsl(r.range(86, 116), r.range(0.26, 0.42), r.range(0.26, 0.36));
    _soil = soilColor ??
        hsl(r.range(24, 42), r.range(0.20, 0.34), r.range(0.30, 0.40));
    _noise = Noise(seed * 61 + 13);
    final (b, t) = _buildRings();
    _base = b;
    _ring = t;
  }

  final int seed;

  /// 밑면 반경(px).
  final double radius;

  /// 솟은 높이(px).
  final double rise;

  final double isoRatio;
  final Color? grassColor;
  final Color? soilColor;

  /// 캐릭터가 위로 지나갈 수 있는가. 높이 처리가 없으므로 낮은 둔덕에만 켠다.
  final bool walkOver;

  /// 언덕 위에 심는 풀 포기 수.
  final int tufts;

  late final Color _grass;
  late final Color _soil;
  late final Noise _noise;
  late final List<Offset> _base;
  late final List<Offset> _ring;

  double get _planeK {
    final squash = math.sqrt(1 - isoRatio * isoRatio);
    return isoRatio / squash;
  }

  @override
  double get height => rise;

  @override
  bool get walkable => walkOver;

  /// 통행 판정을 타일로 옮길 때 쓰는 자.
  final WorldScale scale;

  /// 둔덕이 덮는 타일. `radius / 78` 이라는 상수를 쓰던 자리다 — 78 은 어떤
  /// 특정 타일 폭에서만 맞는 숫자여서 스케일이 바뀌면 즉시 어긋난다.
  @override
  Size get footprint {
    final n = (radius * 2 / scale.pxPerTile).ceilToDouble().clamp(1.0, 64.0);
    return Size(n, n);
  }

  /// 밑면과 상단 면의 윤곽.
  ///
  /// **상단이 밑면보다 좁아야 옆면이 경사면이 된다.** 두 링을 같은 크기로 두면
  /// 옆면이 수직 벽이 되어 언덕이 아니라 케이크가 나온다.
  (List<Offset>, List<Offset>) _buildRings() {
    const n = 18;
    final k = _planeK;
    final base = <Offset>[];
    final top = <Offset>[];
    for (var i = 0; i < n; i++) {
      final u = i / n;
      final a = u * math.pi * 2;
      final m = 1.0 + 0.24 * _noise.signed1(u * 5.0 + 3.1);
      base.add(Offset(
        math.cos(a) * radius * m,
        math.sin(a) * radius * k * m,
      ));
      // 정상은 한쪽으로 조금 치우쳐야 자연 지형으로 보인다.
      final t = 0.72 + 0.08 * _noise.signed1(u * 3.7 + 21);
      top.add(Offset(
        math.cos(a) * radius * m * t + radius * 0.02,
        math.sin(a) * radius * k * m * t - rise - radius * 0.02 * k,
      ));
    }
    return (base, top);
  }

  @override
  void paint(Canvas c, double t, LightRig light, {double detail = 1.0}) {
    // 언덕은 지면 위에 놓인 물건이 아니라 **지형 자체**다. 드리운 그림자를
    // 주면 자기 밑면 밖으로 삐져나와 검은 초승달이 생긴다. 밑면 둘레의 옅은
    // 그늘만으로 충분하다.
    contactAO(c, radius * 1.02, alpha: 0.20, squash: _planeK * 0.92);

    // ── 옆면 — 화면 앞쪽(아래) 절반만 보인다. 상단 링에서 밑면 링으로
    //    벌어지는 **경사면**이며, 수직 벽으로 그리면 케이크가 된다.
    final front = <Offset>[];
    final skirt = <Offset>[];
    for (final (i, p) in _ring.indexed) {
      // 상단 링에서 화면 아래쪽(y 가 큰) 절반이 옆면의 위 가장자리다.
      if (math.sin(i / _ring.length * math.pi * 2) >= -0.08) {
        front.add(p);
        skirt.add(_base[i]);
      }
    }
    if (front.length >= 2) {
      // 흙 경사면은 각진 절벽이 아니다. 위·아래 가장자리를 모두 스플라인으로
      // 잇는다 — 직선으로 이으면 나무 그릇이 된다.
      final side = Path()
        ..addPath(smoothOpenPath(front), Offset.zero)
        ..extendWithPath(smoothOpenPath(skirt.reversed.toList()), Offset.zero)
        ..close();

      // 흙의 명암 폭은 좁다. 대비를 크게 주면 그늘 쪽이 검게 죽어 언덕 옆에
      // 검은 초승달이 생긴다.
      paintSurface(
        c,
        side,
        Surface(_soil.mix(light.ambient, 0.12), Finish.soil, contrast: 0.72),
        light,
        detail: detail,
        seed: seed,
        rim: false,
      );
      // 지면에서 되튀는 반사광 — 흙 경사면의 아랫부분을 데운다.
      final sb = side.getBounds();
      c.save();
      c.clipPath(side);
      c.drawRect(
        sb,
        Paint()
          ..isAntiAlias = true
          ..blendMode = BlendMode.plus
          ..shader = Gradient.linear(
            Offset(sb.center.dx, sb.bottom),
            Offset(sb.center.dx, sb.top),
            [light.bounce.fade(0.14), light.bounce.fade(0.0)],
          ),
      );
      c.restore();

      // 지층 — 흙이 쌓여 온 시간. 두세 줄이면 충분하다.
      if (detail > 0.35) {
        c.save();
        c.clipPath(side);
        final strata = Paint()
          ..isAntiAlias = true
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.2, rise * 0.06);
        for (var i = 1; i < 3; i++) {
          final v = i / 3;
          final pts = [
            for (var j = 0; j < front.length; j++)
              lerpO(front[j], skirt[j], v) +
                  Offset(0, _noise.signed1(j * 0.7 + i) * rise * 0.05)
          ];
          strata.color = _soil.darken(0.26).fade(0.26);
          c.drawPath(smoothOpenPath(pts), strata);
          strata.color = _soil.lighten(0.18).fade(0.14);
          c.drawPath(smoothOpenPath(pts).shift(Offset(0, -rise * 0.03)), strata);
        }
        // 박힌 돌 몇 개 — 흙벽이 단조롭지 않게.
        if (detail > 0.55) {
          final r = Rng(seed * 29 + 5);
          final stone = Paint()..isAntiAlias = true;
          for (var i = 0; i < 5; i++) {
            final p = Offset(
              r.signed(radius * 0.85),
              -rise * r.range(0.1, 0.85),
            );
            final s = rise * r.range(0.10, 0.22);
            stone.color = _soil.lighten(r.range(0.18, 0.34)).fade(0.7);
            c.drawOval(
              Rect.fromCenter(center: p, width: s * 2.2, height: s * 1.4),
              stone,
            );
            stone.color = const Color(0xFF06080F).fade(0.28);
            c.drawOval(
              Rect.fromCenter(
                center: p.translate(-light.dir.dx * s * 0.4, s * 0.5),
                width: s * 2.0,
                height: s * 0.8,
              ),
              stone,
            );
          }
        }
        c.restore();
      }

    }

    // ── 상단 면 — 하늘을 정면으로 받아 가장 밝다.
    final top = smoothClosedPath(_ring, tension: 0.85);
    paintSurface(
      c,
      top,
      Surface(_grass.darken(0.08), Finish.foliage, contrast: 0.85),
      light,
      detail: detail,
      seed: seed + 7,
      rim: false,
    );
    topPlane(c, top, light, strength: 0.34, elevationSin: isoRatio);

    // 상단 가장자리에 잎을 흩뿌려 윤곽을 깨뜨린다. 매끈한 타원은 젤리다.
    if (detail > 0.5) {
      scatterLeaves(
        c,
        Offset(radius * 0.02, -rise),
        radius * 0.74,
        radius * 0.74 * _planeK,
        _grass.lighten(0.12),
        light,
        seed: seed * 7 + 3,
        count: (18 * detail).round(),
        size: 0.10,
      );
    }

    // 상단 얼룩 — 단색 초록 판은 물감이다.
    if (detail > 0.4) {
      c.save();
      c.clipPath(top);
      final r = Rng(seed * 37 + 3);
      final paint = Paint()..isAntiAlias = true;
      for (var i = 0; i < 6; i++) {
        final p = Offset(
          r.signed(radius * 0.7),
          -rise + r.signed(radius * _planeK * 0.6),
        );
        final s = radius * r.range(0.16, 0.34);
        paint
          ..color = (r.chance(0.5) ? _grass.lighten(0.12) : _grass.darken(0.14))
              .fade(0.38)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.6);
        c.drawCircle(p, s, paint);
      }
      c.restore();
    }

    // 풀이 가장자리를 넘어 흘러내린다. 두 면을 같은 땅으로 묶는 한 겹.
    if (detail > 0.4) {
      final r = Rng(seed * 43 + 11);
      final paint = Paint()..isAntiAlias = true;
      for (final p in front) {
        final n = r.intRange(3, 7);
        for (var i = 0; i < n; i++) {
          final at = p + Offset(r.signed(radius * 0.08), r.signed(2));
          final h = rise * r.range(0.22, 0.52);
          paint.color = _grass
              .lighten(0.10 * r.unit)
              .mix(light.ambient, 0.10)
              .fade(0.9);
          // 경사면을 덮으며 흘러내리는 풀. 아래를 향한 방추형이라야 잎이 된다 —
          // 풀잎 형상에 음수 높이를 주면 위아래가 뒤집혀 톱니가 된다.
          c.drawPath(
            leafBlade(at, h, math.pi * 0.5 + r.signed(0.55), width: 0.30),
            paint,
          );
        }
      }
    }

    // 언덕 위의 풀 포기 — 상단이 실제로 땅이라는 신호.
    if (tufts > 0 && detail > 0.45) {
      final r = Rng(seed * 53 + 17);
      final paint = Paint()..isAntiAlias = true;
      for (var i = 0; i < tufts; i++) {
        final a = r.range(0, math.pi * 2);
        final d = radius * math.sqrt(r.unit) * 0.8;
        final at = Offset(
          math.cos(a) * d,
          math.sin(a) * d * _planeK - rise,
        );
        for (var j = 0; j < 5; j++) {
          final h = radius * r.range(0.05, 0.11);
          final root = at + Offset(r.signed(radius * 0.05), r.signed(2));
          final blade = grassBlade(
            root,
            h,
            r.signed(0.4) + math.sin(t * 1.2 + i + j) * 0.08,
            width: r.range(0.10, 0.16),
          );
          final bb = blade.getBounds();
          paint.shader = Gradient.linear(
            Offset(bb.center.dx, bb.bottom),
            Offset(bb.center.dx, bb.top),
            [
              _grass.darken(0.30).mix(light.ambient, 0.26),
              _grass.lighten(0.26).saturate(0.14),
            ],
          );
          c.drawPath(blade, paint);
        }
      }
      paint.shader = null;
    }
  }
}
