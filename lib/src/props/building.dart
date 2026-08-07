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

/// 건물의 외벽 재질. 실루엣이 아니라 **분위기**를 가른다.
enum WallStyle {
  /// 회벽 + 목조 골조. 중세 마을.
  timber,

  /// 다듬은 석조. 성채·신전.
  stone,

  /// 통나무. 변경 지대.
  log,

  /// 벽돌. 도시.
  brick,

  /// 세로 널판. 헛간·창고·물레방앗간.
  plank,
}

/// 지붕 모양.
enum RoofStyle {
  /// 박공지붕 — 마루가 한 방향으로 뻗고 그 끝에 삼각 박공벽이 선다. 가장 흔하다.
  gable,

  /// 모임지붕(우진각) — 네 면이 모두 기운다. 마루가 짧아 안정적으로 보인다.
  hip,

  /// 평지붕 — 옥상이 보인다. 요새·창고.
  flat,

  /// 원뿔 — 탑.
  cone,

  /// 감베렐 — 한 면이 두 번 꺾인다. 헛간의 정체성.
  gambrel,
}

/// 지붕을 덮은 재료. 형상이 아니라 **표면**을 가른다.
enum RoofSkin {
  /// 나무 너와. 열마다 결이 굵고 색이 제각각이다.
  shingle,

  /// 기와. 반원 단면이 열을 이뤄 그림자가 규칙적으로 진다.
  tile,

  /// 초가. 두껍고 둥글며 처마가 무겁게 늘어진다.
  thatch,

  /// 판재. 골이 없는 긴 널. 헛간·창고.
  plank,
}

/// 아이소 맵에 서는 건물.
///
/// ## 왜 3면인가
///
/// 아이소 뷰에서 상자는 **왼쪽 벽·오른쪽 벽·지붕** 세 면이 동시에 보인다.
/// 이 셋의 명도가 확실히 갈리지 않으면 건물이 납작한 판으로 보인다. 실제
/// 밝기 순서는 언제나 **지붕(하늘을 정면으로 받음) > 광원 쪽 벽 > 반대쪽 벽**
/// 이며, 이 위계가 무너지면 아무리 텍스처를 얹어도 입체로 읽히지 않는다.
///
/// ## 집이 집으로 보이는 네 가지
///
/// 1. **마루가 한 축을 따라 뻗는다.** 지붕을 밑면 마름모 전체에 덮으면 벽이
///    지붕에 먹혀 버섯이 된다. 박공 마루는 월드 축 하나와 평행해야 하고,
///    그 결과 한쪽에는 **경사면**이, 다른 쪽에는 **삼각 박공벽**이 온다.
/// 2. **처마가 벽에 그림자를 드리운다.** 지붕이 벽 위에 그냥 얹히면 종이
///    두 장이다. 벽 상단의 어두운 띠 하나가 지붕을 앞으로 끌어낸다.
/// 3. **단위가 크기를 말한다.** 돌 한 장, 널 한 장, 기와 한 줄이 보여야 관객이
///    건물의 실제 규모를 읽는다. 단색 벽은 크기를 알 수 없다.
/// 4. **기단이 있다.** 벽이 흙에서 그냥 시작되면 상자를 얹어 둔 것이 된다.
///    낮은 석재 띠가 건물을 땅에 앉힌다.
///
/// ## squash 보정
///
/// [paintProp] 은 세워지는 기물에 `iso.squash`(≈0.866)를 건다. 그런데 건물의
/// 밑면·지붕 마름모는 **지면 평면에 누워야** 하므로 화면 비율이 타일과 같은
/// `tileHeight/tileWidth`(=0.5)여야 한다. 그래서 내부에서는 `0.5 / 0.866`
/// 으로 미리 부풀려 그려 두고, 바깥의 squash 를 통과한 뒤 정확히 0.5 가 되게
/// 한다. [isoRatio] 를 맵의 타일 비율과 맞추는 것이 중요하다.
class BuildingProp extends Prop {
  BuildingProp({
    required this.seed,
    this.tiles = const Size(2, 2),
    this.tileWidth = 156,
    this.isoRatio = 0.5,
    this.storeys = 1,
    this.wall = WallStyle.timber,
    this.roof = RoofStyle.gable,
    RoofSkin? skin,
    this.wallColor,
    this.roofColor,
    this.litWindows = true,
    this.ridgeAlongX = true,
    this.chimney = true,
    double? storeyHeightOverride,
  })  : _storeyOverride = storeyHeightOverride,
        skin = skin ??
            switch (wall) {
              WallStyle.stone => RoofSkin.tile,
              WallStyle.brick => RoofSkin.tile,
              WallStyle.log => RoofSkin.shingle,
              WallStyle.plank => RoofSkin.plank,
              WallStyle.timber => RoofSkin.thatch,
            } {
    final r = Rng(seed);
    // 층고는 **미터로 선언하고 한 번만 픽셀로 바꾼다.** 예전에는
    // `tileWidth * bell(0.32, 0.40)` 이었는데, 그 값은 층고 0.45~0.57 m —
    // 2층집이 사람보다 낮았다. 픽셀을 직접 고르면 반드시 이렇게 된다.
    //
    // 난수는 덮어쓸 때도 반드시 소비한다. 그러지 않으면 층고를 지정한 건물과
    // 아닌 건물의 벽색·창 배치가 달라져 비교 시트가 두 가지를 한꺼번에 바꾼다.
    final auto = _scale.px(r.bell(kStoreyHeightM * 0.92, kStoreyHeightM * 1.10));
    _storeyH = _storeyOverride ?? auto;
    final cr = r.branch(11);
    _wallTone = wallColor ??
        switch (wall) {
          WallStyle.timber => hsl(
              cr.range(36, 46), cr.range(0.12, 0.22), cr.range(0.66, 0.78)),
          WallStyle.stone => hsl(
              cr.range(30, 48), cr.range(0.06, 0.14), cr.range(0.42, 0.54)),
          WallStyle.log => hsl(
              cr.range(24, 34), cr.range(0.22, 0.34), cr.range(0.32, 0.42)),
          WallStyle.brick => hsl(
              cr.range(8, 20), cr.range(0.30, 0.44), cr.range(0.32, 0.42)),
          WallStyle.plank => hsl(
              cr.range(18, 30), cr.range(0.18, 0.32), cr.range(0.26, 0.36)),
        };
    _roofTone = roofColor ??
        switch (this.skin) {
          RoofSkin.thatch => hsl(
              cr.range(36, 48), cr.range(0.26, 0.40), cr.range(0.34, 0.44)),
          RoofSkin.tile => hsl(
              cr.range(6, 20), cr.range(0.26, 0.44), cr.range(0.24, 0.34)),
          RoofSkin.shingle => hsl(
              cr.range(22, 34), cr.range(0.14, 0.26), cr.range(0.20, 0.29)),
          RoofSkin.plank => hsl(
              cr.range(16, 28), cr.range(0.16, 0.28), cr.range(0.22, 0.31)),
        };
    _beam = wall == WallStyle.timber
        ? hsl(cr.range(22, 32), cr.range(0.30, 0.44), cr.range(0.14, 0.21))
        : _wallTone.darken(0.50).saturate(0.15);
    _plinth = hsl(cr.range(26, 46), cr.range(0.05, 0.12), cr.range(0.30, 0.40));
    _door = hsl(cr.range(18, 30), cr.range(0.28, 0.44), cr.range(0.16, 0.24));
    _windowSeed = r.intRange(1, 999);
    _noise = Noise(seed * 17 + 3);
  }

  final int seed;

  /// 점유 타일 수.
  final Size tiles;

  /// 맵의 타일 폭(px). 건물 크기의 기준이다.
  final double tileWidth;

  /// 타일 높이/폭. 2:1 아이소면 0.5.
  final double isoRatio;

  final int storeys;
  final WallStyle wall;
  final RoofStyle roof;
  final RoofSkin skin;
  final Color? wallColor;
  final Color? roofColor;

  /// 창문에 불을 켠다. 밤 조명에서 마을이 살아 있는 인상을 만든다.
  final bool litWindows;

  /// 마루가 월드 x 축을 따라 뻗는가. 마을에서 방향을 섞으면 지루함이 사라진다.
  final bool ridgeAlongX;

  /// 굴뚝과 연기를 세운다.
  final bool chimney;

  /// 층고를 미터 유도 대신 직접 지정한 값(국소 px). 보통은 `null` 이다.
  ///
  /// 옛 치수를 재현해 **고치기 전/후를 나란히 굽는** 대조 시트에 쓴다
  /// (`scale_shot_test.dart`). 일반 사용에서는 넘기지 않는다 — 넘기는 순간
  /// 그 건물만 마을의 자에서 벗어난다.
  final double? _storeyOverride;

  late final double _storeyH;
  late final Color _wallTone;
  late final Color _roofTone;
  late final Color _beam;
  late final Color _plinth;
  late final Color _door;
  late final int _windowSeed;
  late final Noise _noise;

  @override
  Size get footprint => tiles;

  /// 이 건물이 쓰는 미터 자. [tileWidth] 하나로 정해진다.
  WorldScale get _scale => WorldScale.ofTileWidth(tileWidth);

  /// 한 층의 높이(국소 px). 사람 키보다 크고 두 배보다 작아야 한다.
  double get storeyHeight => _storeyH;

  /// 출입문 안목 높이(국소 px). 사람이 고개를 숙이지 않고 지난다.
  ///
  /// 층고에 비례시키지 않는다 — 층고가 흔들리면 문이 따라 흔들려 사람이
  /// 못 들어가는 집이 생긴다. 문은 **사람 치수**에 매인다.
  double get doorHeight => _scale.px(kDoorHeightM);

  /// 출입문 너비(국소 px).
  double get doorWidth => _scale.px(kDoorWidthM);

  /// 지붕 마루가 처마에서 솟는 높이(국소 px).
  double get _roofRise => switch (roof) {
        RoofStyle.flat => 0.0,
        RoofStyle.cone => _storeyH * 1.35,
        RoofStyle.gambrel => _storeyH * 0.86,
        _ => _storeyH * 0.70,
      };

  /// 접지에서 지붕 꼭대기까지.
  ///
  /// 예전에는 지붕 몫을 `tileWidth * 0.5` 라는 상수로 때웠다. 그 값은 타일에만
  /// 매여 있어 층수·지붕 모양과 무관했고, 깊이 정렬과 컬링이 실제와 다른
  /// 높이를 쓰게 만들었다.
  @override
  double get height => _plinthH + _storeyH * storeys + _roofRise;

  // 형상이 시간에 따라 바뀌지 않는다 — 한 번 굽고 재생만 한다.
  @override
  bool get bakeable => true;

  @override
  Rect get bakeBounds {
    // 아이소 마름모의 가로 반폭은 (w+h)/2 × 타일폭/2 이고, 처마가 조금 더
    // 나온다. 아래로는 마름모의 앞 꼭짓점과 드리운 그림자가 퍼진다.
    final halfW = (tiles.width + tiles.height) * tileWidth * 0.25 + tileWidth * 0.5;
    final down = (tiles.width + tiles.height) * tileWidth * isoRatio * 0.25 +
        tileWidth * 0.35;
    return Rect.fromLTRB(-halfW, -(height + tileWidth * 0.35), halfW, down);
  }

  @override
  bool get walkable => false;

  /// 바깥 squash 를 상쇄해 지면 평면 비율을 회복하는 계수.
  double get _planeK {
    final squash = math.sqrt(1 - isoRatio * isoRatio);
    return isoRatio / squash;
  }

  /// 기단 높이.
  double get _plinthH => _storeyH * 0.12;

  /// 밑면 마름모의 네 꼭짓점 (국소 좌표, 접지 중심 원점).
  ///
  /// 아이소 기저벡터를 그대로 쓴다 — 월드 x 축은 화면에서 오른쪽-아래로,
  /// y 축은 왼쪽-아래로 간다. 그래서 정사각 부지는 위/오른/아래/왼 꼭짓점을
  /// 가진 마름모가 된다.
  ///
  /// 반환 순서: 앞(남) · 오른(동) · 뒤(북) · 왼(서).
  (Offset, Offset, Offset, Offset) _diamond([double grow = 0]) {
    final hx = tiles.width * 0.5 + grow;
    final hy = tiles.height * 0.5 + grow;
    final u = tileWidth * 0.5;
    final k = _planeK;
    return (
      Offset(u * (hx - hy), u * k * (hx + hy)), // 앞
      Offset(u * (hx + hy), u * k * (hx - hy)), // 오른
      Offset(u * (hy - hx), -u * k * (hx + hy)), // 뒤
      Offset(-u * (hx + hy), u * k * (hy - hx)), // 왼
    );
  }

  @override
  void paint(Canvas c, double t, LightRig light, {double detail = 1.0}) {
    final (pF, pR, pB, pL) = _diamond();
    final top = storeys * _storeyH + _plinthH;

    _paintGroundContact(c, light);
    _paintPlinth(c, light, detail);
    _paintWalls(c, light, pF, pR, pB, pL, top, detail);
    _paintRoof(c, light, pF, pR, pB, pL, top, detail, t);
  }

  // ── 접지 ────────────────────────────────────────────────────────────────
  void _paintGroundContact(Canvas c, LightRig l) {
    final hx = tiles.width * 0.5 * tileWidth;
    final hy = tiles.height * 0.5 * tileWidth;
    final r = math.max(hx, hy);
    propShadow(c, r * 1.05, l, alpha: 0.48, stretch: 1.12);
    contactAO(c, r * 0.92, alpha: 0.42, squash: _planeK);
  }

  /// 기단 — 벽이 흙에서 바로 시작하면 상자를 얹어 둔 것이 된다.
  void _paintPlinth(Canvas c, LightRig l, double detail) {
    final (gF, gR, _, gL) = _diamond(0.055);
    final up = Offset(0, -_plinthH);
    final leftLit = l.dir.dx < 0;

    Path quad(Offset a, Offset b) => Path()
      ..moveTo(a.dx, a.dy)
      ..lineTo(b.dx, b.dy)
      ..lineTo(b.dx + up.dx, b.dy + up.dy)
      ..lineTo(a.dx + up.dx, a.dy + up.dy)
      ..close();

    for (final (i, face) in [quad(gL, gF), quad(gF, gR)].indexed) {
      final lit = (i == 0) == leftLit;
      paintSurface(
        c,
        face,
        Surface(lit ? _plinth : _plinth.darken(0.22).mix(l.ambient, 0.25),
            Finish.stone, contrast: 1.15),
        l,
        detail: detail * 0.7,
        seed: seed + 60 + i,
        rim: false,
      );
    }
  }

  // ── 벽 ──────────────────────────────────────────────────────────────────
  void _paintWalls(Canvas c, LightRig l, Offset pF, Offset pR, Offset pB,
      Offset pL, double top, double detail) {
    final base = Offset(0, -_plinthH);
    final up = Offset(0, -(top - _plinthH));
    final aL = pL + base, aF = pF + base, aR = pR + base;

    // 광원이 왼쪽에 있으면 왼쪽 벽이 밝다. dir 은 피사체→광원이므로 dx<0 이면
    // 광원이 왼쪽이다.
    final leftLit = l.dir.dx < 0;

    Path quad(Offset a, Offset b) => Path()
      ..moveTo(a.dx, a.dy)
      ..lineTo(b.dx, b.dy)
      ..lineTo(b.dx + up.dx, b.dy + up.dy)
      ..lineTo(a.dx + up.dx, a.dy + up.dy)
      ..close();

    final leftWall = quad(aL, aF);
    final rightWall = quad(aF, aR);

    final finish = switch (wall) {
      WallStyle.timber => Finish.cloth,
      WallStyle.stone => Finish.stone,
      WallStyle.log => Finish.bark,
      WallStyle.brick => Finish.stone,
      WallStyle.plank => Finish.wood,
    };

    // 두 벽의 명도를 확실히 가른다. 이 대비가 입체의 전부다.
    final litTone = _wallTone.lighten(0.07);
    final shadeTone = _wallTone.darken(0.24).mix(l.ambient, 0.30);

    for (final (i, spec) in [
      (leftWall, aL, aF, leftLit),
      (rightWall, aF, aR, !leftLit),
    ].indexed) {
      final (path, a, b, lit) = spec;
      paintSurface(
        c,
        path,
        Surface(lit ? litTone : shadeTone, finish, contrast: 1.12),
        l,
        detail: detail,
        seed: seed + i * 5,
        rim: false,
      );
      if (detail > 0.3) {
        _paintWallSkin(c, l, path, a, b, up, lit, i, detail);
      }
      // 처마 그림자 — 지붕이 벽 앞으로 튀어나왔음을 알리는 한 줄.
      eaveShadow(
        c,
        path,
        a + up,
        b + up,
        depth: _storeyH * 0.34,
        alpha: 0.62,
        blur: _storeyH * 0.05,
      );
      if (detail > 0.35) {
        _paintOpenings(c, l, path, a, b, up, lit, i, detail);
      }
    }

    // 벽이 만나는 모서리. 여기에 밝은 선이 서야 상자의 각이 산다.
    c.drawLine(
      aF,
      aF + up,
      Paint()
        ..isAntiAlias = true
        ..strokeWidth = math.max(1.2, top * 0.014)
        ..color = _wallTone.lighten(0.26).fade(0.65),
    );
  }

  /// 벽 표면 — 단위가 반복되어야 크기가 읽힌다.
  void _paintWallSkin(Canvas c, LightRig l, Path face, Offset a, Offset b,
      Offset up, bool lit, int side, double detail) {
    c.save();
    c.clipPath(face);
    final tone = lit ? _wallTone.lighten(0.04) : _wallTone.darken(0.16);

    switch (wall) {
      case WallStyle.stone:
        courseTexture(c, a, b, up, tone, l,
            seed: seed + side * 31,
            courses: (storeys * 4).clamp(3, 14),
            perCourse: (tiles.width + tiles.height).round().clamp(3, 6),
            stagger: 0.5,
            mortar: 0.09,
            bevel: lit ? 0.42 : 0.22,
            variance: 0.20);
      case WallStyle.brick:
        courseTexture(c, a, b, up, tone, l,
            seed: seed + side * 31,
            courses: (storeys * 9).clamp(6, 22),
            perCourse: ((tiles.width + tiles.height) * 3).round().clamp(6, 14),
            stagger: 0.5,
            mortar: 0.14,
            bevel: lit ? 0.30 : 0.16,
            variance: 0.13);
      case WallStyle.log:
        _paintLogCourses(c, l, a, b, up, tone, side, detail);
      case WallStyle.plank:
        _paintPlanks(c, l, a, b, up, tone, side, detail);
      case WallStyle.timber:
        _paintHalfTimber(c, l, a, b, up, side);
    }
    c.restore();
  }

  /// 통나무 — 가로 원통이 쌓인다. 원통마다 위가 밝고 아래에 그림자가 진다.
  void _paintLogCourses(Canvas c, LightRig l, Offset a, Offset b, Offset up,
      Color tone, int side, double detail) {
    final rows = (storeys * 5).clamp(3, 12);
    final h = up.dy.abs() / rows;
    final paint = Paint()..isAntiAlias = true;
    for (var i = 0; i < rows; i++) {
      final y = up.dy * (i / rows);
      final v = _noise.at1(i * 2.7 + side * 11);
      final logRect = Path()
        ..moveTo(a.dx, a.dy + y)
        ..lineTo(b.dx, b.dy + y)
        ..lineTo(b.dx, b.dy + y - h)
        ..lineTo(a.dx, a.dy + y - h)
        ..close();
      final lb = logRect.getBounds();
      paint.shader = Gradient.linear(
        Offset(lb.center.dx, lb.bottom),
        Offset(lb.center.dx, lb.top),
        [
          tone.darken(0.30).fade(0.85),
          tone.lighten(0.05 + 0.10 * v).fade(0.5),
          tone.lighten(0.20).fade(0.35),
          tone.darken(0.10).fade(0.5),
        ],
        const [0.0, 0.34, 0.62, 1.0],
      );
      c.drawPath(logRect, paint);
    }
    paint.shader = null;
    // 모서리 마구리 — 통나무 끝이 교차해 튀어나온다. 오두막의 정체성이다.
    if (detail > 0.5) {
      for (var i = 0; i < rows; i += 2) {
        final y = up.dy * (i / rows) - h * 0.5;
        final at = side == 0 ? a : b;
        final out = (side == 0 ? (a - b) : (b - a)).normalized() * (h * 0.55);
        c.drawOval(
          Rect.fromCenter(
            center: at + out + Offset(0, y),
            width: h * 0.9,
            height: h * 0.7,
          ),
          paint..color = tone.lighten(0.16).fade(0.9),
        );
      }
    }
  }

  /// 세로 널판. 판 사이 틈이 어둡고 판마다 색이 조금씩 다르다.
  void _paintPlanks(Canvas c, LightRig l, Offset a, Offset b, Offset up,
      Color tone, int side, double detail) {
    final n = ((tiles.width + tiles.height) * 4).round().clamp(6, 20);
    final span = b - a;
    final fill = Paint()..isAntiAlias = true;
    final gap = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, span.distance / n * 0.10);
    for (var i = 0; i < n; i++) {
      final u0 = i / n, u1 = (i + 1) / n;
      final v = _noise.at1(i * 3.1 + side * 17);
      final p0 = a + span * u0, p1 = a + span * u1;
      final board = Path()
        ..moveTo(p0.dx, p0.dy)
        ..lineTo(p1.dx, p1.dy)
        ..lineTo(p1.dx + up.dx, p1.dy + up.dy)
        ..lineTo(p0.dx + up.dx, p0.dy + up.dy)
        ..close();
      fill.color = (v > 0.5 ? tone.lighten((v - 0.5) * 0.3) : tone.darken((0.5 - v) * 0.3))
          .fade(0.5);
      c.drawPath(board, fill);
      gap.color = tone.darken(0.45).fade(0.7);
      c.drawLine(p0, p0 + up, gap);
    }
    // 가로 띠장 — 헛간 판벽에는 반드시 있다.
    final band = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(2.0, _storeyH * 0.05)
      ..color = _beam.fade(0.75);
    for (final v in [0.18, 0.82]) {
      c.drawLine(a + up * v, b + up * v, band);
    }
  }

  /// 하프팀버 — 회벽을 가로지르는 골조. 대각 브레이스가 정체성이다.
  void _paintHalfTimber(
      Canvas c, LightRig l, Offset a, Offset b, Offset up, int side) {
    final r = Rng(_windowSeed + side * 31);
    final span = b - a;
    final w = math.max(1.8, _storeyH * 0.062);
    final beam = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.square
      ..color = _beam.fade(0.92);
    final hi = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.4
      ..color = _beam.lighten(0.34).fade(0.5);

    void line(Offset p0, Offset p1) {
      c.drawLine(p0, p1, beam);
      c.drawLine(p0 - l.dir * w * 0.5, p1 - l.dir * w * 0.5, hi);
    }

    // 층 사이 수평재와 처마·토대.
    for (var s = 0; s <= storeys; s++) {
      final v = s / storeys;
      line(a + up * v, b + up * v);
    }
    // 수직 기둥.
    final posts = (tiles.width + tiles.height).round().clamp(2, 5);
    for (var i = 1; i < posts; i++) {
      final u = i / posts;
      line(a + span * u, a + span * u + up);
    }
    // 대각 브레이스 — 칸마다 하나씩, 방향은 시드로 흔든다.
    for (var s = 0; s < storeys; s++) {
      for (var i = 0; i < posts; i++) {
        if (!r.chance(0.55)) continue;
        final u0 = i / posts, u1 = (i + 1) / posts;
        final v0 = s / storeys, v1 = (s + 1) / storeys;
        final flip = r.chance(0.5);
        line(
          a + span * (flip ? u0 : u1) + up * v0,
          a + span * (flip ? u1 : u0) + up * (v0 + (v1 - v0) * 0.72),
        );
      }
    }
  }

  /// 문과 창 — 사람이 드나든다는 유일한 증거.
  void _paintOpenings(Canvas c, LightRig l, Path face, Offset a, Offset b,
      Offset up, bool lit, int side, double detail) {
    c.save();
    c.clipPath(face);
    final r = Rng(_windowSeed + side * 137);
    final span = b - a;

    // ── 문 — 앞 모서리 쪽 한 면에만 낸다.
    if (side == 0) {
      final u = r.range(0.34, 0.62);
      // 사람 치수에 맞춘다. 층고에 비례시키면 집이 커질 때 문도 같이 커져
      // 대문 같은 문이 되고, 작아지면 사람이 못 들어간다.
      final dw = doorWidth;
      final dh = doorHeight;
      final foot = a + span * u;
      final dir = span.normalized();
      final p0 = foot - dir * dw * 0.5;
      final p1 = foot + dir * dw * 0.5;
      final door = Path()
        ..moveTo(p0.dx, p0.dy)
        ..lineTo(p1.dx, p1.dy)
        ..lineTo(p1.dx, p1.dy - dh * 0.82)
        // 상인방을 살짝 아치로. 직사각 구멍보다 훨씬 건물처럼 보인다.
        ..quadraticBezierTo(
            (p0.dx + p1.dx) * 0.5, p0.dy - dh, p0.dx, p0.dy - dh * 0.82)
        ..close();
      paintSurface(c, door, Surface(_door, Finish.wood, contrast: 1.2), l,
          detail: detail, seed: seed + 71, rim: false);
      // 문틀
      c.drawPath(
        door,
        Paint()
          ..isAntiAlias = true
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.5, dw * 0.10)
          ..color = _beam.fade(0.9),
      );
      // 문 안쪽 어둠 — 틈으로 보이는 실내.
      c.drawPath(
        door,
        Paint()
          ..isAntiAlias = true
          ..blendMode = BlendMode.multiply
          ..shader = Gradient.linear(
            Offset(p0.dx, p0.dy - dh),
            Offset(p0.dx, p0.dy),
            [const Color(0xFF3A3A46), const Color(0xFFFFFFFF)],
          ),
      );
      // 문지방 계단 — 접지를 단단히 한다.
      c.drawPath(
        Path()
          ..moveTo(p0.dx - dw * 0.12, p0.dy)
          ..lineTo(p1.dx + dw * 0.12, p1.dy)
          ..lineTo(p1.dx + dw * 0.12, p1.dy + _plinthH * 0.7)
          ..lineTo(p0.dx - dw * 0.12, p0.dy + _plinthH * 0.7)
          ..close(),
        Paint()
          ..isAntiAlias = true
          ..color = _plinth.lighten(0.12).fade(0.9),
      );
    }

    // ── 창 — 층마다 한두 개.
    final cols = (tiles.width + tiles.height).round().clamp(1, 3);
    for (var s = 0; s < storeys; s++) {
      for (var i = 1; i <= cols; i++) {
        if (!r.chance(0.66)) continue;
        final u = i / (cols + 1) + r.signed(0.05);
        final v = (s + 0.60) / storeys;
        final at = a + span * u + up * v;
        // 창도 사람 치수다 — 한 짝 0.85×1.20 m. 이 단위가 보여야 관객이
        // 건물의 실제 규모를 읽는다.
        final ww = _scale.px(kWindowWidthM);
        final wh = _scale.px(kWindowHeightM);
        final on = litWindows && r.chance(0.62);
        _paintWindow(c, l, at, span.normalized(), ww, wh, on, detail);
      }
    }
    c.restore();
  }

  void _paintWindow(Canvas c, LightRig l, Offset at, Offset dir, double ww,
      double wh, bool on, double detail) {
    final half = dir * (ww * 0.5);
    final glass = Path()
      ..moveTo(at.dx - half.dx, at.dy - half.dy)
      ..lineTo(at.dx + half.dx, at.dy + half.dy)
      ..lineTo(at.dx + half.dx, at.dy + half.dy - wh)
      ..lineTo(at.dx - half.dx, at.dy - half.dy - wh)
      ..close();
    final gb = glass.getBounds();

    // 유리 — 켜져 있으면 안쪽이 깊고 따뜻하게, 꺼져 있으면 하늘을 반사한다.
    c.drawPath(
      glass,
      Paint()
        ..isAntiAlias = true
        ..shader = Gradient.linear(
          gb.topCenter,
          gb.bottomCenter,
          on
              ? [
                  const Color(0xFFFFE7B0),
                  const Color(0xFFFFBB55),
                  const Color(0xFFC9762A),
                ]
              : [
                  l.rim.mix(const Color(0xFF14203A), 0.45),
                  const Color(0xFF0D1526),
                  const Color(0xFF161F32),
                ],
          const [0.0, 0.55, 1.0],
        ),
    );

    // 창살 — 십자 하나면 충분하다. 격자를 촘촘히 넣으면 모기장이 된다.
    final mull = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.8, ww * 0.09)
      ..color = _beam.fade(0.85);
    c.drawLine(Offset(gb.center.dx, gb.top), Offset(gb.center.dx, gb.bottom), mull);
    c.drawLine(
      Offset(gb.left, gb.center.dy),
      Offset(gb.right, gb.center.dy),
      mull,
    );

    // 창틀 + 창턱. 창턱이 있어야 창이 벽에 파인 구멍이 된다.
    c.drawPath(
      glass,
      Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.2, ww * 0.15)
        ..color = _beam.fade(0.95),
    );
    c.drawLine(
      Offset(gb.left - ww * 0.10, gb.bottom),
      Offset(gb.right + ww * 0.10, gb.bottom),
      Paint()
        ..isAntiAlias = true
        ..strokeWidth = math.max(1.4, wh * 0.10)
        ..color = _wallTone.lighten(0.28).fade(0.9),
    );

    if (on) {
      // 창에서 새어 나온 빛이 벽을 적신다. 발광체를 그렸으면 주변도 밝혀야
      // 광원이 장면에 속한 것으로 보인다.
      glowAt(c, gb.center, ww * 1.5, const Color(0xFFFFB347), intensity: 0.34);
      c.drawRect(
        Rect.fromCenter(
          center: gb.center.translate(0, wh * 0.5),
          width: ww * 2.6,
          height: wh * 2.4,
        ),
        Paint()
          ..isAntiAlias = true
          ..blendMode = BlendMode.plus
          ..shader = Gradient.radial(
            gb.center,
            ww * 1.6,
            [
              const Color(0xFFFFC46A).fade(0.20),
              const Color(0x00FFC46A),
            ],
          ),
      );
    }
  }

  // ── 지붕 ────────────────────────────────────────────────────────────────
  void _paintRoof(Canvas c, LightRig l, Offset pF, Offset pR, Offset pB,
      Offset pL, double top, double detail, double t) {
    final up = Offset(0, -top);
    final f = pF + up, rr = pR + up, b = pB + up, lf = pL + up;

    if (roof == RoofStyle.flat) {
      _paintFlatRoof(c, l, f, rr, b, lf, top, detail);
      return;
    }
    if (roof == RoofStyle.cone) {
      _paintConeRoof(c, l, f, rr, b, lf, top, detail);
      return;
    }

    // ── 박공·모임·감베렐 ─────────────────────────────────────────────────
    //
    // 마루는 **월드 축 하나와 평행**해야 한다. 밑면 마름모 전체를 지붕으로
    // 덮으면 벽이 지붕에 먹혀 버섯이 된다.
    //
    // ridgeAlongX 이면 마루는 L→F 변(월드 x 축)과 평행하고, 화면 왼쪽 아래
    // 면이 경사면, 오른쪽 아래 면이 삼각 박공벽이 된다.
    final eave = tileWidth * 0.075;
    final k = _planeK;
    final ridgeH = _storeyH * (roof == RoofStyle.gambrel ? 0.86 : 0.70);

    // 처마로 밀어낸 네 꼭짓점.
    final ex = Offset(eave, eave * k);
    final ey = Offset(-eave, eave * k);
    final eF = f + ex + ey;
    final eR = rr + ex - ey;
    final eB = b - ex - ey;
    final eL = lf - ex + ey;

    // 마루 양 끝 — 밑면 중심선의 두 끝점 위.
    final (mA, mB) = ridgeAlongX
        ? (lerpO(eF, eR, 0.5), lerpO(eL, eB, 0.5))
        : (lerpO(eF, eL, 0.5), lerpO(eR, eB, 0.5));
    // 모임지붕은 마루가 짧아 네 면이 모두 기운다.
    final shrink = roof == RoofStyle.hip ? 0.26 : 0.0;
    final ridgeA = lerpO(mA, mB, shrink) + Offset(0, -ridgeH);
    final ridgeB = lerpO(mB, mA, shrink) + Offset(0, -ridgeH);

    // 화면 앞쪽 두 면. (뒤쪽 두 면은 마루에 가려 보이지 않는다.)
    final (nearEaveA, nearEaveB) = ridgeAlongX ? (eL, eF) : (eF, eR);
    final (gableA, gableB) = ridgeAlongX ? (eF, eR) : (eL, eF);

    // **처마 끝과 마루 끝의 짝을 정확히 맞춘다.** 어긋나면 지붕면이 자기를
    // 가로질러 부채꼴로 뻗어 나간다 — 집이 아니라 찢어진 천이 된다.
    // mA 는 언제나 박공벽(gableA-gableB) 쪽 마루 끝이므로 nearEaveB 와 짝이고,
    // mB 는 그 반대쪽이라 nearEaveA 와 짝이다.
    final ridgeNearA = ridgeAlongX ? ridgeB : ridgeA;
    final ridgeNearB = ridgeAlongX ? ridgeA : ridgeB;

    final leftLit = l.dir.dx < 0;
    final slopeLit = ridgeAlongX ? leftLit : !leftLit;

    // ① 박공벽(또는 모임지붕의 측면) — 지붕보다 먼저, 벽 위에 얹는다.
    //    박공의 꼭짓점은 언제나 mA 쪽 마루 끝이다.
    if (roof == RoofStyle.hip) {
      final hipFace = Path()
        ..moveTo(gableA.dx, gableA.dy)
        ..lineTo(gableB.dx, gableB.dy)
        ..lineTo(ridgeA.dx, ridgeA.dy)
        ..close();
      _paintSlope(c, l, hipFace, gableA, gableB, ridgeA, ridgeA, !slopeLit,
          detail, seed + 21);
    } else {
      _paintGableEnd(c, l, gableA, gableB, ridgeA, top, detail);
    }

    // ② 경사면 — 화면에서 가장 넓은 면. 여기 텍스처가 지붕의 인상을 정한다.
    if (roof == RoofStyle.gambrel) {
      // 두 번 꺾인 면. 아래쪽이 가파르고 위쪽이 완만하다.
      final kneeA =
          lerpO(nearEaveA, ridgeNearA, 0.5) + Offset(0, -ridgeH * 0.22);
      final kneeB =
          lerpO(nearEaveB, ridgeNearB, 0.5) + Offset(0, -ridgeH * 0.22);
      final lower = Path()
        ..moveTo(nearEaveA.dx, nearEaveA.dy)
        ..lineTo(nearEaveB.dx, nearEaveB.dy)
        ..lineTo(kneeB.dx, kneeB.dy)
        ..lineTo(kneeA.dx, kneeA.dy)
        ..close();
      final upper = Path()
        ..moveTo(kneeA.dx, kneeA.dy)
        ..lineTo(kneeB.dx, kneeB.dy)
        ..lineTo(ridgeNearB.dx, ridgeNearB.dy)
        ..lineTo(ridgeNearA.dx, ridgeNearA.dy)
        ..close();
      _paintSlope(c, l, lower, nearEaveA, nearEaveB, kneeB, kneeA, slopeLit,
          detail, seed + 13);
      _paintSlope(c, l, upper, kneeA, kneeB, ridgeNearB, ridgeNearA, slopeLit,
          detail, seed + 14, tone: _roofTone.lighten(0.06));
    } else {
      final slope = Path()
        ..moveTo(nearEaveA.dx, nearEaveA.dy)
        ..lineTo(nearEaveB.dx, nearEaveB.dy)
        ..lineTo(ridgeNearB.dx, ridgeNearB.dy)
        ..lineTo(ridgeNearA.dx, ridgeNearA.dy)
        ..close();
      _paintSlope(c, l, slope, nearEaveA, nearEaveB, ridgeNearB, ridgeNearA,
          slopeLit, detail, seed + 13);
    }

    // ③ 처마 두께 — 지붕이 판때기가 아니라 **두께를 가진 구조**임을 알린다.
    _paintEaveBoard(c, l, nearEaveA, nearEaveB);

    // ④ 마루 — 지붕에서 가장 밝은 선. 마루기와를 얹는다.
    _paintRidgeCap(c, l, ridgeA, ridgeB, detail);

    if (chimney && detail > 0.4) {
      _paintChimney(c, l, lerpO(ridgeA, ridgeB, 0.28), top, detail, t);
    }
  }

  /// 경사면 하나 — 재질에 맞는 열 텍스처를 얹는다.
  void _paintSlope(Canvas c, LightRig l, Path face, Offset eaveA, Offset eaveB,
      Offset ridgeB, Offset ridgeA, bool lit, double detail, int faceSeed,
      {Color? tone}) {
    final base = tone ?? _roofTone;
    final surface = lit
        ? base.lighten(0.14)
        : base.darken(0.20).mix(l.ambient, 0.24);
    final finish = switch (skin) {
      RoofSkin.thatch => Finish.fur,
      RoofSkin.tile => Finish.stone,
      RoofSkin.shingle => Finish.wood,
      RoofSkin.plank => Finish.wood,
    };
    paintSurface(c, face, Surface(surface, finish, contrast: 1.15), l,
        detail: detail, seed: faceSeed, rim: false);
    topPlane(c, face, l, strength: lit ? 0.62 : 0.34, elevationSin: isoRatio);

    if (detail > 0.35) {
      c.save();
      c.clipPath(face);
      _paintRoofSkin(c, l, eaveA, eaveB, ridgeB, ridgeA, surface, faceSeed,
          detail);
      c.restore();
    }
    rimBand(c, face, l, width: 2.5, alpha: lit ? 0.34 : 0.18, blur: 2);
  }

  /// 지붕 표면의 반복 단위. 열이 보여야 지붕이 재료로 덮인 것이 된다.
  void _paintRoofSkin(Canvas c, LightRig l, Offset eaveA, Offset eaveB,
      Offset ridgeB, Offset ridgeA, Color tone, int faceSeed, double detail) {
    final n = Noise(faceSeed * 37 + 11);
    final rows = switch (skin) {
      RoofSkin.tile => (detail > 0.6 ? 9 : 6),
      RoofSkin.shingle => (detail > 0.6 ? 8 : 5),
      RoofSkin.thatch => 4,
      RoofSkin.plank => 3,
    };

    if (skin == RoofSkin.plank) {
      // 판재는 열이 아니라 **경사 방향**으로 흐른다.
      final cols = (detail > 0.6 ? 11 : 7);
      final gap = Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      for (var i = 1; i < cols; i++) {
        final u = i / cols;
        gap.color = tone.darken(0.34).fade(0.55);
        c.drawLine(lerpO(eaveA, eaveB, u), lerpO(ridgeA, ridgeB, u), gap);
      }
      return;
    }

    for (var i = 1; i <= rows; i++) {
      final v0 = (i - 1) / rows, v1 = i / rows;
      final a0 = lerpO(eaveA, ridgeA, v0), b0 = lerpO(eaveB, ridgeB, v0);
      final a1 = lerpO(eaveA, ridgeA, v1), b1 = lerpO(eaveB, ridgeB, v1);

      if (skin == RoofSkin.thatch) {
        // 초가 — 층이 두껍고 아래 가장자리가 둥글게 늘어진다.
        final drop = (b0 - b1).distance * 0.30;
        final pts = <Offset>[];
        const segs = 6;
        for (var j = 0; j <= segs; j++) {
          final u = j / segs;
          final p = lerpO(a0, b0, u);
          pts.add(p + Offset(0, drop * (0.5 + 0.5 * n.at1(u * 5 + i * 2.3))));
        }
        for (var j = segs; j >= 0; j--) {
          pts.add(lerpO(a1, b1, j / segs));
        }
        final layer = smoothClosedPath(pts, tension: 0.7);
        c.drawPath(
          layer,
          Paint()
            ..isAntiAlias = true
            ..shader = Gradient.linear(
              lerpO(a0, a1, 1.0),
              lerpO(a0, a1, 0.0),
              [tone.lighten(0.10).fade(0.5), tone.darken(0.34).fade(0.75)],
            ),
        );
        continue;
      }

      // 기와·너와 — 열의 아래 모서리에 그림자, 그 위에 밝은 턱.
      final shade = Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.4, (a1 - a0).distance * 0.34)
        ..color = tone.darken(0.42).fade(0.55);
      c.drawLine(a0, b0, shade);
      c.drawLine(
        a0 - l.dir * 1.6,
        b0 - l.dir * 1.6,
        Paint()
          ..isAntiAlias = true
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(0.9, (a1 - a0).distance * 0.16)
          ..color = tone.lighten(0.30).fade(0.55),
      );

      // 열 안의 개별 단위. 기와 한 장이 보여야 규모가 읽힌다.
      if (detail > 0.6) {
        final units = skin == RoofSkin.tile ? 10 : 7;
        final tick = Paint()
          ..isAntiAlias = true
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;
        for (var j = 0; j < units; j++) {
          final u = (j + (i.isOdd ? 0.5 : 0.0)) / units;
          if (u >= 1) continue;
          tick.color = tone.darken(0.30).fade(0.40);
          c.drawLine(lerpO(a0, b0, u), lerpO(a1, b1, u), tick);
        }
      }
    }
  }

  /// 박공벽 — 지붕 아래 삼각 벽. 여기에 다락창을 내면 단번에 살림집이 된다.
  void _paintGableEnd(Canvas c, LightRig l, Offset a, Offset b, Offset apex,
      double top, double detail) {
    final face = Path()
      ..moveTo(a.dx, a.dy)
      ..lineTo(b.dx, b.dy)
      ..lineTo(apex.dx, apex.dy)
      ..close();
    final leftLit = l.dir.dx < 0;
    final tone = (ridgeAlongX ? !leftLit : leftLit)
        ? _wallTone.lighten(0.04)
        : _wallTone.darken(0.26).mix(l.ambient, 0.30);
    final finish = switch (wall) {
      WallStyle.timber => Finish.cloth,
      WallStyle.log => Finish.wood,
      WallStyle.plank => Finish.wood,
      _ => Finish.stone,
    };
    paintSurface(c, face, Surface(tone, finish, contrast: 1.1), l,
        detail: detail, seed: seed + 33, rim: false);

    if (detail > 0.4) {
      c.save();
      c.clipPath(face);
      // 박공은 대개 판벽으로 마감한다 — 벽과 재질을 달리하면 층이 읽힌다.
      final cols = 8;
      final gap = Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = tone.darken(0.36).fade(0.5);
      for (var i = 1; i < cols; i++) {
        final p = lerpO(a, b, i / cols);
        c.drawLine(p, Offset(p.dx, p.dy - (top * 0.6)), gap);
      }
      c.restore();

      // 다락창 — 작은 원 또는 사각 하나.
      final mid = lerpO(lerpO(a, b, 0.5), apex, 0.52);
      final rad = (b - a).distance * 0.07;
      c.drawCircle(
        mid,
        rad,
        Paint()
          ..isAntiAlias = true
          ..shader = Gradient.radial(
            mid,
            rad,
            [const Color(0xFF0B1220), const Color(0xFF1A2440)],
          ),
      );
      c.drawCircle(
        mid,
        rad,
        Paint()
          ..isAntiAlias = true
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.2, rad * 0.22)
          ..color = _beam.fade(0.9),
      );
    }

    // 박공 널 — 경사변을 따라 두꺼운 테두리가 있어야 지붕과 벽이 분리된다.
    final barge = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(2.0, _storeyH * 0.055)
      ..strokeJoin = StrokeJoin.round
      ..color = _beam.lighten(0.10).fade(0.9);
    c.drawPath(
      Path()
        ..moveTo(a.dx, a.dy)
        ..lineTo(apex.dx, apex.dy)
        ..lineTo(b.dx, b.dy),
      barge,
    );
  }

  /// 처마 널 — 지붕의 두께. 이것이 없으면 지붕이 종잇장이다.
  void _paintEaveBoard(Canvas c, LightRig l, Offset a, Offset b) {
    final th = math.max(2.5, _storeyH * 0.085);
    final board = Path()
      ..moveTo(a.dx, a.dy)
      ..lineTo(b.dx, b.dy)
      ..lineTo(b.dx, b.dy + th)
      ..lineTo(a.dx, a.dy + th)
      ..close();
    final bb = board.getBounds();
    c.drawPath(
      board,
      Paint()
        ..isAntiAlias = true
        ..shader = Gradient.linear(
          bb.topCenter,
          bb.bottomCenter,
          [_roofTone.lighten(0.06), _roofTone.darken(0.48)],
        ),
    );
  }

  /// 마루기와 — 지붕에서 가장 밝은 선.
  void _paintRidgeCap(
      Canvas c, LightRig l, Offset a, Offset b, double detail) {
    final th = math.max(2.5, _storeyH * 0.075);
    final cap = Path()
      ..moveTo(a.dx, a.dy - th * 0.5)
      ..lineTo(b.dx, b.dy - th * 0.5)
      ..lineTo(b.dx, b.dy + th * 0.5)
      ..lineTo(a.dx, a.dy + th * 0.5)
      ..close();
    paintSurface(
      c,
      cap,
      Surface(_roofTone.lighten(0.20), Finish.stone, contrast: 1.2),
      l,
      detail: detail * 0.6,
      seed: seed + 44,
      rim: false,
    );
    c.drawLine(
      a - Offset(0, th * 0.45),
      b - Offset(0, th * 0.45),
      Paint()
        ..isAntiAlias = true
        ..strokeWidth = math.max(1.0, th * 0.28)
        ..color = _roofTone.lighten(0.44).fade(0.8),
    );
  }

  void _paintChimney(
      Canvas c, LightRig l, Offset at, double top, double detail, double t) {
    final w = _storeyH * 0.17;
    final h = _storeyH * 0.52;
    final k = _planeK;
    final leftLit = l.dir.dx < 0;

    // 아이소 상자 3면.
    final f = at + Offset(0, w * k);
    final rr = at + Offset(w, 0);
    final lf = at + Offset(-w, 0);
    final up = Offset(0, -h);

    Path quad(Offset p0, Offset p1) => Path()
      ..moveTo(p0.dx, p0.dy)
      ..lineTo(p1.dx, p1.dy)
      ..lineTo(p1.dx + up.dx, p1.dy + up.dy)
      ..lineTo(p0.dx + up.dx, p0.dy + up.dy)
      ..close();

    final tone = _plinth.darken(0.10);
    for (final (i, face) in [quad(lf, f), quad(f, rr)].indexed) {
      final lit = (i == 0) == leftLit;
      paintSurface(
        c,
        face,
        Surface(lit ? tone.lighten(0.06) : tone.darken(0.24).mix(l.ambient, 0.3),
            Finish.stone, contrast: 1.2),
        l,
        detail: detail * 0.6,
        seed: seed + 50 + i,
        rim: false,
      );
    }
    // 갓돌 — 굴뚝 꼭대기가 조금 넓어야 굴뚝으로 읽힌다.
    final capTop = Path()
      ..moveTo(f.dx, f.dy + up.dy)
      ..lineTo(rr.dx + w * 0.18, rr.dy + up.dy)
      ..lineTo(at.dx, at.dy + up.dy - w * k)
      ..lineTo(lf.dx - w * 0.18, lf.dy + up.dy)
      ..close();
    paintSurface(c, capTop, Surface(tone.lighten(0.16), Finish.stone), l,
        detail: detail * 0.5, seed: seed + 52);
    topPlane(c, capTop, l, strength: 0.8, elevationSin: isoRatio);

    // 연기는 굽지 않는다. 형상은 고정인데 연기만 움직이므로, 그 하나 때문에
    // 건물 전체를 매 프레임 다시 그리면 손해다. 자리만 기억해 두고 [live] 가
    // 텍스처 위에 얹는다.
    _smokeAt = at;
    _smokeW = w;
    _smokeH = h;
  }

  Offset? _smokeAt;
  double _smokeW = 0;
  double _smokeH = 0;

  @override
  void live(Canvas c, double t, LightRig light, {double detail = 1.0}) {
    // 연기 — 굴뚝이 살아 있다는 유일한 신호.
    final at = _smokeAt;
    if (at == null || detail <= 0.6) return;
    final w = _smokeW, h = _smokeH;
    final smoke = Paint()..isAntiAlias = true;
    for (var i = 0; i < 5; i++) {
      final phase = (t * 0.16 + i * 0.2) % 1.0;
      final rad = w * (0.5 + phase * 1.9);
      final at2 = Offset(
        at.dx + math.sin(t * 0.6 + i * 1.4) * w * (0.4 + phase),
        at.dy - h - phase * h * 2.2,
      );
      smoke.color = light
          .ambient
          .mix(const Color(0xFFBFC8DA), 0.55)
          .fade(0.22 * (1 - phase));
      smoke.maskFilter = MaskFilter.blur(BlurStyle.normal, rad * 0.5);
      c.drawCircle(at2, rad, smoke);
    }
  }

  void _paintFlatRoof(Canvas c, LightRig l, Offset f, Offset rr, Offset b,
      Offset lf, double top, double detail) {
    final deck = Path()
      ..moveTo(f.dx, f.dy)
      ..lineTo(rr.dx, rr.dy)
      ..lineTo(b.dx, b.dy)
      ..lineTo(lf.dx, lf.dy)
      ..close();
    paintSurface(c, deck, Surface(_roofTone.lighten(0.12), Finish.stone), l,
        detail: detail, seed: seed + 9);
    topPlane(c, deck, l, strength: 0.75, elevationSin: isoRatio);
    if (detail > 0.4) {
      c.save();
      c.clipPath(deck);
      courseTexture(c, lf, f, rr - f, _roofTone.lighten(0.10), l,
          seed: seed + 91,
          courses: 4,
          perCourse: 4,
          mortar: 0.06,
          bevel: 0.25,
          variance: 0.12);
      c.restore();
    }
    // 난간 — 옥상 가장자리가 서 있어야 옥상이다.
    final parapet = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(2.0, top * 0.022)
      ..strokeJoin = StrokeJoin.round
      ..color = _roofTone.lighten(0.24).fade(0.9);
    c.drawPath(deck, parapet);
  }

  void _paintConeRoof(Canvas c, LightRig l, Offset f, Offset rr, Offset b,
      Offset lf, double top, double detail) {
    final eave = tileWidth * 0.05;
    final k = _planeK;
    final ef = f + Offset(0, eave * k);
    final er = rr + Offset(eave, 0);
    final el = lf - Offset(eave, 0);
    final apex = Offset(0, -top - _storeyH * 1.35);
    final leftLit = l.dir.dx < 0;

    final coneL = Path()
      ..moveTo(el.dx, el.dy)
      ..lineTo(ef.dx, ef.dy)
      ..lineTo(apex.dx, apex.dy)
      ..close();
    final coneR = Path()
      ..moveTo(ef.dx, ef.dy)
      ..lineTo(er.dx, er.dy)
      ..lineTo(apex.dx, apex.dy)
      ..close();

    for (final (i, face) in [coneL, coneR].indexed) {
      final lit = (i == 0) == leftLit;
      _paintSlope(
        c,
        l,
        face,
        i == 0 ? el : ef,
        i == 0 ? ef : er,
        apex,
        apex,
        lit,
        detail,
        seed + 11 + i,
      );
    }
    _paintEaveBoard(c, l, el, ef);
    _paintEaveBoard(c, l, ef, er);

    // 첨탑 꼭대기 — 깃대 하나가 실루엣을 살린다.
    if (detail > 0.5) {
      c.drawLine(
        apex,
        apex - Offset(0, _storeyH * 0.30),
        Paint()
          ..isAntiAlias = true
          ..strokeWidth = math.max(1.2, _storeyH * 0.025)
          ..color = _beam.lighten(0.2).fade(0.9),
      );
      glowAt(c, apex - Offset(0, _storeyH * 0.30), _storeyH * 0.05,
          l.rim, intensity: 0.4);
    }
  }
}

/// 담장·성벽 한 구간.
///
/// 건물과 달리 **한 방향으로만 길게 이어지므로**, 타일을 따라 여러 개를 붙여
/// 놓는 것을 전제로 만들었다. 돌 하나하나가 보이지 않으면 회색 상자가 된다.
class WallProp extends Prop {
  WallProp({
    required this.seed,
    this.tileWidth = 156,
    this.isoRatio = 0.5,
    double? wallHeight,
    this.thickness = 0.16,
    this.color,
    this.crenellated = false,
    this.alongX = true,
    this.mossy = true,
  }) {
    // 기본값 52 px 는 이 타일 크기에서 0.49 m — 사람 발목 높이의 "성벽"이었다.
    this.wallHeight =
        wallHeight ?? WorldScale.ofTileWidth(tileWidth).px(kWallHeightM);
  }

  final int seed;
  final double tileWidth;
  final double isoRatio;

  /// 담 높이(국소 px). 생략하면 [kWallHeightM] 에서 유도한다.
  late final double wallHeight;

  /// 타일 폭 대비 두께.
  final double thickness;

  final Color? color;

  /// 성가퀴(총안)를 낸다. 성벽·요새에 쓴다.
  final bool crenellated;

  /// 진행 방향. `true` 면 월드 x 축을 따라 뻗는다.
  final bool alongX;

  /// 밑동에 이끼를 앉힌다. 담장이 오래된 것으로 보인다.
  final bool mossy;

  @override
  double get height => wallHeight;
  @override
  bool get walkable => false;

  /// 담은 시간을 전혀 쓰지 않는다 — 구워도 그림이 한 픽셀도 달라지지 않는다.
  ///
  /// 실측에서 담장 20장이 프레임당 31.7 ms 를 먹었다(나무 다음으로 큰 항목).
  /// 마을 경계를 두르느라 개수가 많아진 탓이라 개당 비용을 없애는 편이 옳다.
  @override
  bool get bakeable => true;

  /// 담은 **옆으로 길다.** 기본 경계는 높이에서 상자를 잡으므로 진행 방향
  /// 끝이 잘린다 — 타일 폭까지 넉넉히 넓힌다.
  @override
  Rect get bakeBounds {
    final w = tileWidth * 0.75;
    return Rect.fromLTRB(-w, -wallHeight * 1.35, w, tileWidth * 0.45);
  }

  double get _planeK {
    final squash = math.sqrt(1 - isoRatio * isoRatio);
    return isoRatio / squash;
  }

  @override
  void paint(Canvas c, double t, LightRig light, {double detail = 1.0}) {
    final r = Rng(seed);
    final tone = color ??
        hsl(r.range(28, 52), r.range(0.04, 0.10), r.range(0.40, 0.50));
    final k = _planeK;
    final half = tileWidth * 0.5;
    final th = tileWidth * thickness;

    propShadow(c, half * 0.92, light, alpha: 0.42, stretch: 1.05);
    contactAO(c, half * 0.8, alpha: 0.40, squash: k);

    // 벽의 밑선: 진행 방향 ±half, 두께 방향 ±th/2 인 마름모.
    final dir = alongX ? Offset(half, half * k) : Offset(-half, half * k);
    final nrm =
        alongX ? Offset(th * 0.5, -th * 0.5 * k) : Offset(th * 0.5, th * 0.5 * k);

    final a = -dir - nrm, b = dir - nrm, bb = dir + nrm, aa = -dir + nrm;
    final up = Offset(0, -wallHeight);

    Path quad(Offset p0, Offset p1) => Path()
      ..moveTo(p0.dx, p0.dy)
      ..lineTo(p1.dx, p1.dy)
      ..lineTo(p1.dx + up.dx, p1.dy + up.dy)
      ..lineTo(p0.dx + up.dx, p0.dy + up.dy)
      ..close();

    final faceFront = quad(a, b);
    final faceSide = quad(b, bb);
    final leftLit = light.dir.dx < 0;

    paintSurface(
        c,
        faceSide,
        Surface(tone.darken(0.24).mix(light.ambient, 0.24), Finish.stone,
            contrast: 1.15),
        light,
        detail: detail,
        seed: seed + 1,
        rim: false);
    paintSurface(
        c,
        faceFront,
        Surface(leftLit ? tone.lighten(0.06) : tone.darken(0.10), Finish.stone,
            contrast: 1.2),
        light,
        detail: detail,
        seed: seed,
        rim: false);

    // 돌 하나하나. 이 단위가 보이지 않으면 회색 상자다.
    if (detail > 0.3) {
      c.save();
      c.clipPath(faceFront);
      courseTexture(c, a, b, up, tone, light,
          seed: seed + 7,
          courses: 4,
          perCourse: 5,
          stagger: 0.5,
          mortar: 0.10,
          bevel: leftLit ? 0.45 : 0.26,
          variance: 0.22);
      c.restore();
    }

    // 윗면 갓돌 — 하늘을 정면으로 받아 가장 밝다. 살짝 넓어야 갓돌이다.
    final capOut = Offset(th * 0.10, -th * 0.10 * k);
    final cap = Path()
      ..moveTo(a.dx + up.dx - capOut.dx, a.dy + up.dy - capOut.dy)
      ..lineTo(b.dx + up.dx - capOut.dx, b.dy + up.dy - capOut.dy)
      ..lineTo(bb.dx + up.dx + capOut.dx, bb.dy + up.dy + capOut.dy)
      ..lineTo(aa.dx + up.dx + capOut.dx, aa.dy + up.dy + capOut.dy)
      ..close();
    paintSurface(c, cap, Surface(tone.lighten(0.18), Finish.stone), light,
        detail: detail, seed: seed + 2);
    topPlane(c, cap, light, strength: 0.8, elevationSin: isoRatio);

    if (crenellated) {
      // 총안 — 윗면 위에 짧은 블록을 띄엄띄엄 올린다.
      const n = 4;
      for (var i = 0; i < n; i++) {
        if (i.isOdd) continue;
        final u0 = i / n, u1 = (i + 0.7) / n;
        final p0 = lerpO(a + up, b + up, u0);
        final p1 = lerpO(a + up, b + up, u1);
        final q0 = lerpO(aa + up, bb + up, u0);
        final q1 = lerpO(aa + up, bb + up, u1);
        final ch = wallHeight * 0.26;
        final merlon = Path()
          ..moveTo(p0.dx, p0.dy)
          ..lineTo(p1.dx, p1.dy)
          ..lineTo(p1.dx, p1.dy - ch)
          ..lineTo(p0.dx, p0.dy - ch)
          ..close();
        paintSurface(
            c,
            merlon,
            Surface(leftLit ? tone.lighten(0.04) : tone.darken(0.12),
                Finish.stone, contrast: 1.2),
            light,
            detail: detail * 0.6,
            seed: seed + 20 + i,
            rim: false);
        final top = Path()
          ..moveTo(p0.dx, p0.dy - ch)
          ..lineTo(p1.dx, p1.dy - ch)
          ..lineTo(q1.dx, q1.dy - ch)
          ..lineTo(q0.dx, q0.dy - ch)
          ..close();
        paintSurface(c, top, Surface(tone.lighten(0.20), Finish.stone), light,
            detail: detail * 0.5, seed: seed + 30 + i);
        topPlane(c, top, light, strength: 0.75, elevationSin: isoRatio);
      }
    }

    // 밑동 이끼 — 돌담이 오래되었다는 신호. 아래쪽에만 앉힌다.
    if (mossy && detail > 0.45) {
      c.save();
      c.clipPath(faceFront);
      final mr = Rng(seed * 53 + 9);
      final moss =
          hsl(mr.range(86, 116), mr.range(0.28, 0.44), mr.range(0.24, 0.32));
      for (var i = 0; i < 4; i++) {
        final u = mr.range(0.05, 0.95);
        final p = lerpO(a, b, u);
        final rad = tileWidth * mr.range(0.05, 0.11);
        c.drawOval(
          Rect.fromCenter(
            center: p.translate(0, -wallHeight * mr.range(0.02, 0.22)),
            width: rad * 2.2,
            height: rad * 1.1,
          ),
          Paint()
            ..isAntiAlias = true
            ..color = moss.fade(0.45)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, rad * 0.45),
        );
      }
      c.restore();
    }
  }
}
