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

/// 서 있는 풀 포기.
///
/// [GroundPatch] 의 풀은 지면에 눕는 패치의 장식이라 세로가 절반으로 눌린다.
/// 이쪽은 **세워지는 기물**이므로 캐릭터 발목 높이로 실제로 선다. 나무 밑동,
/// 담장 아래, 길가처럼 시선이 지면 가까이 머무는 곳에 놓으면 맵의 밀도가
/// 단번에 올라간다.
class GrassTuft extends Prop {
  GrassTuft({
    required this.seed,
    this.size = 34,
    this.color,
    this.blades = 14,
    this.wind = 1.0,
  }) {
    final r = Rng(seed);
    _tone =
        color ?? hsl(r.range(82, 116), r.range(0.28, 0.46), r.range(0.24, 0.36));
  }

  final int seed;

  /// 풀 포기의 높이(px).
  final double size;

  final Color? color;
  final int blades;
  final double wind;

  late final Color _tone;

  @override
  double get height => size;

  @override
  bool get walkable => true;

  @override
  void paint(Canvas c, double t, LightRig light, {double detail = 1.0}) {
    contactAO(c, size * 0.42, alpha: 0.34, squash: 0.4);

    final r = Rng(seed * 17 + 3);
    final n = (blades * (0.45 + 0.55 * detail)).round();
    final paint = Paint()..isAntiAlias = true;

    // 뒤쪽 잎부터 그린다. 앞쪽이 밝아야 포기에 부피가 생긴다.
    final list = <(Offset, double, double, double)>[];
    for (var i = 0; i < n; i++) {
      final x = r.signed(size * 0.34);
      final depth = r.unit; // 0 뒤 … 1 앞
      final h = size * r.range(0.55, 1.05) * (0.8 + 0.3 * depth);
      final lean = r.signed(0.55);
      list.add((Offset(x, -depth * size * 0.05), h, lean, depth));
    }
    list.sort((a, b) => a.$4.compareTo(b.$4));

    for (final (i, item) in list.indexed) {
      final (root, h, lean, depth) = item;
      final w = wind * sway(t, seed, phase: i * 0.9, speed: 1.5) * 0.14;
      final blade = grassBlade(root, h, lean + w, width: r.range(0.09, 0.16));
      final bb = blade.getBounds();
      paint.shader = Gradient.linear(
        Offset(bb.center.dx, bb.bottom),
        Offset(bb.center.dx, bb.top),
        [
          _tone.darken(0.34 + 0.16 * (1 - depth)).mix(light.ambient, 0.30),
          _tone.darken(0.10 * (1 - depth)),
          _tone.lighten(0.28 * depth).saturate(0.14),
        ],
        const [0.0, 0.5, 1.0],
      );
      c.drawPath(blade, paint);
    }
    paint.shader = null;
  }
}

/// 꽃밭 한 포기.
///
/// 꽃은 색으로 시선을 끄는 강조 장치다. 맵에서 가장 작은 기물이지만, 길가와
/// 물가에 몇 포기만 놓아도 화면이 단번에 살아난다. 꽃잎이 갈라져 있어야
/// 꽃이고, 점을 찍으면 색 얼룩이다.
class FlowerBed extends Prop {
  FlowerBed({
    required this.seed,
    this.size = 40,
    this.petalColor,
    this.count = 6,
    this.wind = 1.0,
  }) {
    final r = Rng(seed);
    _petal = petalColor ??
        hsl(
          r.pick(const [352.0, 42.0, 276.0, 200.0, 18.0]) + r.signed(12),
          r.range(0.55, 0.80),
          r.range(0.58, 0.72),
        );
    _heart = _petal.shiftHue(-20).saturate(0.3).lighten(0.22);
    _leaf = hsl(r.range(86, 116), r.range(0.30, 0.46), r.range(0.26, 0.34));
  }

  final int seed;
  final double size;
  final Color? petalColor;
  final int count;
  final double wind;

  late final Color _petal;
  late final Color _heart;
  late final Color _leaf;

  @override
  double get height => size;

  @override
  bool get walkable => true;

  @override
  void paint(Canvas c, double t, LightRig light, {double detail = 1.0}) {
    contactAO(c, size * 0.40, alpha: 0.32, squash: 0.4);

    final r = Rng(seed * 23 + 7);
    final n = (count * (0.5 + 0.5 * detail)).round().clamp(2, count);
    final paint = Paint()..isAntiAlias = true;

    // 잎 — 꽃만 있으면 공중에 뜬 색점이 된다. 밑에 잎이 깔려야 한다.
    for (var i = 0; i < n; i++) {
      final a = r.range(-2.7, -0.4);
      final len = size * r.range(0.22, 0.40);
      final at = Offset(r.signed(size * 0.24), 0);
      paint.color = _leaf
          .darken(0.10 * (i % 3))
          .mix(light.ambient, 0.18)
          .fade(0.92);
      c.drawPath(leafBlade(at, len, a, width: 0.46), paint);
    }

    // 꽃대와 꽃. 키를 흩어 놓아야 다발로 보인다.
    final stems = <(Offset, double, double)>[];
    for (var i = 0; i < n; i++) {
      stems.add((
        Offset(r.signed(size * 0.30), 0),
        size * r.range(0.55, 1.0),
        r.signed(0.34),
      ));
    }
    stems.sort((a, b) => a.$2.compareTo(b.$2));

    for (final (i, stem) in stems.indexed) {
      final (root, h, lean) = stem;
      final w = wind * sway(t, seed, phase: i * 1.1, speed: 1.3) * 0.12;
      final head = root + Offset((lean + w) * h, -h);
      paint.color = _leaf.lighten(0.06).fade(0.95);
      c.drawPath(grassBlade(root, h, lean + w, width: 0.055), paint);
      final lit = 0.4 + 0.6 * (i / math.max(1, stems.length - 1));
      paintFlower(
        c,
        head,
        size * r.range(0.12, 0.20),
        _petal.darken(0.16 * (1 - lit)).mix(light.ambient, 0.18 * (1 - lit)),
        _heart,
        light,
        petals: r.intRange(5, 7),
        rotation: r.range(0, 2),
        squash: 0.9,
      );
    }
  }
}

/// 그루터기. 베어 낸 나무의 밑동.
///
/// 맵에 이야기를 주는 가장 값싼 기물이다 — 누군가 이 숲에서 나무를 베었다는
/// 사실 하나로 공간에 사람의 흔적이 생긴다. 절단면의 나이테가 정체성이다.
class StumpProp extends Prop {
  StumpProp({
    required this.seed,
    this.size = 34,
    this.isoRatio = 0.5,
    this.color,
    this.mossy = true,
  }) {
    final r = Rng(seed);
    _tone = color ??
        hsl(r.range(20, 34), r.range(0.18, 0.32), r.range(0.16, 0.25));
    _core = _tone.lighten(0.42).saturate(0.12);
    _h = size * r.range(0.6, 1.1);
    _noise = Noise(seed * 29 + 3);
  }

  final int seed;
  final double size;
  final double isoRatio;
  final Color? color;
  final bool mossy;

  late final Color _tone;
  late final Color _core;
  late final double _h;
  late final Noise _noise;

  double get _planeK {
    final squash = math.sqrt(1 - isoRatio * isoRatio);
    return isoRatio / squash;
  }

  @override
  double get height => _h;

  @override
  bool get walkable => false;

  @override
  void paint(Canvas c, double t, LightRig light, {double detail = 1.0}) {
    final k = _planeK;
    propShadow(c, size * 0.9, light, alpha: 0.38);
    rootSkirt(c, size * 1.25, _tone.mix(const Color(0xFF4A3A28), 0.5), light,
        seed: seed, alpha: 0.5);
    contactAO(c, size * 0.72, alpha: 0.45, squash: k);

    // 옆면 — 밑동이 넓게 벌어져야 뿌리가 박힌 것으로 보인다.
    final side = Path()
      ..moveTo(-size * 1.16, -_h * 0.10)
      ..cubicTo(-size * 1.0, -_h * 0.62, -size * 0.94, -_h * 0.90, -size * 0.86,
          -_h)
      ..lineTo(size * 0.86, -_h)
      ..cubicTo(size * 0.94, -_h * 0.90, size * 1.0, -_h * 0.62, size * 1.16,
          -_h * 0.10)
      ..cubicTo(size * 0.6, size * k * 0.30, -size * 0.6, size * k * 0.30,
          -size * 1.16, -_h * 0.10)
      ..close();
    paintSurface(c, side, Surface(_tone, Finish.bark, contrast: 1.2), light,
        detail: detail, seed: seed, rim: false);

    // 절단면 — 지면과 평행한 타원. 여기가 가장 밝다.
    final top = Rect.fromCenter(
      center: Offset(0, -_h),
      width: size * 1.72,
      height: size * 1.72 * k,
    );
    final topPath = Path()..addOval(top);
    paintSurface(
      c,
      topPath,
      Surface(_core, Finish.wood, contrast: 1.0),
      light,
      detail: detail,
      seed: seed + 3,
      rim: false,
    );
    topPlane(c, topPath, light, strength: 0.8, elevationSin: isoRatio);

    // 나이테 — 중심이 살짝 치우쳐야 자연스럽다.
    if (detail > 0.35) {
      c.save();
      c.clipPath(topPath);
      final cx = top.center.translate(size * 0.10, -size * 0.04 * k);
      final ring = Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke;
      final rings = detail > 0.6 ? 7 : 4;
      for (var i = 1; i <= rings; i++) {
        final u = i / rings;
        ring
          ..strokeWidth = math.max(0.7, size * 0.022 * (0.6 + u))
          ..color = (i.isEven ? _core.darken(0.30) : _core.darken(0.14))
              .fade(0.55);
        c.drawOval(
          Rect.fromCenter(
            center: cx,
            width: top.width * u * 0.92 * (1 + 0.05 * _noise.signed1(i * 2.1)),
            height: top.height * u * 0.92,
          ),
          ring,
        );
      }
      // 방사 균열 — 마른 나무는 반드시 갈라진다.
      final crack = Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.8, size * 0.03)
        ..color = _core.darken(0.52).fade(0.6);
      final r = Rng(seed * 41 + 5);
      for (var i = 0; i < 3; i++) {
        final a = r.range(0, math.pi * 2);
        c.drawLine(
          cx,
          cx + Offset(math.cos(a) * top.width * 0.5, math.sin(a) * top.height * 0.5),
          crack,
        );
      }
      c.restore();
    }

    // 껍질 테두리 — 절단면과 옆면 사이의 짙은 링.
    c.drawOval(
      top,
      Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.4, size * 0.09)
        ..color = _tone.darken(0.18).fade(0.9),
    );

    if (mossy && detail > 0.45) {
      final r = Rng(seed * 59 + 7);
      final moss = hsl(r.range(88, 118), 0.38, 0.30);
      c.save();
      c.clipPath(side);
      for (var i = 0; i < 3; i++) {
        final p = Offset(r.signed(size * 0.9), -_h * r.range(0.05, 0.55));
        final rad = size * r.range(0.18, 0.34);
        c.drawOval(
          Rect.fromCenter(center: p, width: rad * 2, height: rad * 1.1),
          Paint()
            ..isAntiAlias = true
            ..color = moss.fade(0.5)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, rad * 0.5),
        );
      }
      c.restore();
    }
  }
}

/// 쓰러진 통나무.
///
/// 가로로 누운 원통은 아이소 맵에서 드문 **수평 선**이라, 서 있는 것들 사이에
/// 하나만 놓아도 리듬이 생긴다. 양 끝 마구리와 나이테가 보여야 통나무다.
class LogProp extends Prop {
  LogProp({
    required this.seed,
    this.length = 130,
    this.isoRatio = 0.5,
    this.color,
    this.alongX = true,
    this.mossy = true,
  }) {
    final r = Rng(seed);
    _tone = color ??
        hsl(r.range(20, 34), r.range(0.18, 0.30), r.range(0.18, 0.27));
    _rad = length * r.range(0.13, 0.19);
    _noise = Noise(seed * 31 + 11);
  }

  final int seed;
  final double length;
  final double isoRatio;
  final Color? color;
  final bool alongX;
  final bool mossy;

  late final Color _tone;
  late final double _rad;
  late final Noise _noise;

  double get _planeK {
    final squash = math.sqrt(1 - isoRatio * isoRatio);
    return isoRatio / squash;
  }

  @override
  double get height => _rad * 2;

  @override
  bool get walkable => false;

  @override
  void paint(Canvas c, double t, LightRig light, {double detail = 1.0}) {
    final k = _planeK;
    final half = length * 0.5;
    // 통나무는 지면에 누워 있으므로 축이 아이소 평면을 따라 기운다.
    final axis = alongX ? Offset(half, half * k) : Offset(-half, half * k);

    propShadow(c, half * 0.9, light, alpha: 0.42, stretch: 1.15);
    contactAO(c, half * 0.8, alpha: 0.42, squash: 0.42);

    final a = -axis + Offset(0, -_rad);
    final b = axis + Offset(0, -_rad);
    final body = tube([a, lerpO(a, b, 0.5), b], [_rad, _rad * 1.04, _rad],
        samples: 14);
    paintSurface(c, body, Surface(_tone, Finish.bark, contrast: 1.2), light,
        detail: detail, seed: seed, rim: false);

    // 원통의 상단 하이라이트 — 축을 따라 흐르는 띠. 이것이 원통을 만든다.
    c.save();
    c.clipPath(body);
    final bb = body.getBounds();
    c.drawRect(
      bb,
      Paint()
        ..isAntiAlias = true
        ..blendMode = BlendMode.plus
        ..shader = Gradient.linear(
          Offset(bb.center.dx, bb.top),
          Offset(bb.center.dx, bb.bottom),
          [
            _tone.lighten(0.44).fade(0.30),
            _tone.lighten(0.20).fade(0.10),
            const Color(0x00000000),
          ],
          const [0.0, 0.34, 0.75],
        ),
    );
    c.restore();

    // 마구리 — 잘린 끝면. 나이테가 보여야 통나무다.
    for (final (i, end) in [b, a].indexed) {
      final face = Rect.fromCenter(
        center: end,
        width: _rad * 1.5,
        height: _rad * 2.0,
      );
      final path = Path()..addOval(face);
      paintSurface(
        c,
        path,
        Surface(_tone.lighten(0.40).saturate(0.10), Finish.wood),
        light,
        detail: detail * 0.7,
        seed: seed + i,
        rim: false,
      );
      if (detail > 0.4) {
        c.save();
        c.clipPath(path);
        final ring = Paint()
          ..isAntiAlias = true
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(0.6, _rad * 0.07);
        for (var j = 1; j <= 4; j++) {
          ring.color = _tone.lighten(0.10).fade(0.5);
          c.drawOval(
            Rect.fromCenter(
              center: face.center,
              width: face.width * j / 4.5,
              height: face.height * j / 4.5,
            ),
            ring,
          );
        }
        c.restore();
      }
      c.drawOval(
        face,
        Paint()
          ..isAntiAlias = true
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.0, _rad * 0.13)
          ..color = _tone.darken(0.24).fade(0.9),
      );
    }

    // 껍질 결 — 축을 따라 흐르는 갈라짐.
    if (detail > 0.5) {
      c.save();
      c.clipPath(body);
      final grain = Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.8, _rad * 0.09);
      for (var i = 0; i < 5; i++) {
        final off = (i / 4 - 0.5) * _rad * 1.5;
        final pts = [
          for (var j = 0; j <= 5; j++)
            lerpO(a, b, j / 5) +
                Offset(0, off + _noise.signed1(i * 3.1 + j * 0.7) * _rad * 0.12)
        ];
        grain.color = _tone.darken(0.30).fade(0.35);
        c.drawPath(smoothOpenPath(pts), grain);
      }
      c.restore();
    }

    if (mossy && detail > 0.5) {
      final r = Rng(seed * 43 + 3);
      final moss = hsl(r.range(88, 116), 0.40, 0.32);
      c.save();
      c.clipPath(body);
      for (var i = 0; i < 4; i++) {
        final p = lerpO(a, b, r.unit) + Offset(0, -_rad * r.range(0.1, 0.5));
        final rad = _rad * r.range(0.5, 0.95);
        c.drawOval(
          Rect.fromCenter(center: p, width: rad * 2.2, height: rad * 0.9),
          Paint()
            ..isAntiAlias = true
            ..color = moss.fade(0.48)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, rad * 0.5),
        );
      }
      c.restore();
      // 통나무 위에 돋은 풀 — 오래 누워 있었다는 신호.
      for (var i = 0; i < 5; i++) {
        final p = lerpO(a, b, r.range(0.15, 0.85)) + Offset(0, -_rad * 0.85);
        c.drawPath(
          grassBlade(p, _rad * r.range(0.6, 1.2), r.signed(0.4), width: 0.14),
          Paint()
            ..isAntiAlias = true
            ..color = moss.lighten(0.14).fade(0.85),
        );
      }
    }
  }
}

/// 나무 울타리 한 구간.
///
/// 담장이 돌로 된 경계라면 울타리는 **사람이 손으로 세운 경계**다. 밭·마당·
/// 목장의 가장자리에 이어 붙여 쓴다. 기둥이 조금씩 기울어야 손으로 박은
/// 것으로 보인다 — 자로 잰 듯 반듯하면 공장 제품이 된다.
class FenceProp extends Prop {
  FenceProp({
    required this.seed,
    this.tileWidth = 156,
    this.isoRatio = 0.5,
    this.fenceHeight = 46,
    this.color,
    this.alongX = true,
    this.rails = 2,
    this.posts = 3,
  }) {
    final r = Rng(seed);
    _tone = color ??
        hsl(r.range(24, 40), r.range(0.14, 0.28), r.range(0.28, 0.40));
  }

  final int seed;
  final double tileWidth;
  final double isoRatio;
  final double fenceHeight;
  final Color? color;
  final bool alongX;
  final int rails;
  final int posts;

  late final Color _tone;

  double get _planeK {
    final squash = math.sqrt(1 - isoRatio * isoRatio);
    return isoRatio / squash;
  }

  @override
  double get height => fenceHeight;

  @override
  bool get walkable => false;

  @override
  void paint(Canvas c, double t, LightRig light, {double detail = 1.0}) {
    final k = _planeK;
    final half = tileWidth * 0.5;
    final dir = alongX ? Offset(half, half * k) : Offset(-half, half * k);
    final r = Rng(seed * 13 + 7);

    propShadow(c, half * 0.7, light, alpha: 0.30, stretch: 1.1);

    final postAt = <Offset>[];
    for (var i = 0; i < posts; i++) {
      final u = posts == 1 ? 0.5 : i / (posts - 1);
      postAt.add(dir * (u * 2 - 1));
    }

    // 가로대 먼저 — 기둥이 그 앞에 와야 못질된 것으로 보인다.
    final railPaint = Paint()..isAntiAlias = true;
    for (var j = 0; j < rails; j++) {
      final v = fenceHeight * (0.34 + 0.40 * (j / math.max(1, rails - 1)));
      final sag = fenceHeight * 0.04;
      for (var i = 0; i + 1 < posts; i++) {
        final p0 = postAt[i] + Offset(0, -v);
        final p1 = postAt[i + 1] + Offset(0, -v);
        final mid = lerpO(p0, p1, 0.5) + Offset(0, sag);
        final rail = tube([p0, mid, p1],
            [fenceHeight * 0.055, fenceHeight * 0.062, fenceHeight * 0.055],
            samples: 8);
        paintSurface(
          c,
          rail,
          Surface(_tone.darken(0.06 * j), Finish.wood, contrast: 1.15),
          light,
          detail: detail * 0.7,
          seed: seed + j * 7 + i,
          rim: false,
        );
        railPaint.color = _tone.lighten(0.34).fade(0.35);
      }
    }

    // 기둥 — 조금씩 기울고 높이가 다르다.
    for (final (i, at) in postAt.indexed) {
      final h = fenceHeight * r.range(0.92, 1.10);
      final lean = r.signed(0.10);
      contactAO(c, fenceHeight * 0.20, alpha: 0.42, squash: 0.42, at: at);
      final post = tube(
        [at, at + Offset(lean * h * 0.5, -h * 0.55), at + Offset(lean * h, -h)],
        [fenceHeight * 0.085, fenceHeight * 0.072, fenceHeight * 0.058],
        samples: 10,
        capStart: false,
      );
      paintSurface(c, post, Surface(_tone, Finish.wood, contrast: 1.2), light,
          detail: detail, seed: seed + i * 11, rim: false);
      // 기둥 꼭대기 — 도끼로 친 경사면.
      final topAt = at + Offset(lean * h, -h);
      final cap = Path()
        ..addOval(Rect.fromCenter(
          center: topAt,
          width: fenceHeight * 0.13,
          height: fenceHeight * 0.13 * k,
        ));
      paintSurface(c, cap, Surface(_tone.lighten(0.34), Finish.wood), light,
          detail: detail * 0.5, seed: seed + i, rim: false);
      topPlane(c, cap, light, strength: 0.7, elevationSin: isoRatio);
    }
  }
}
