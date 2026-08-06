import 'dart:math' as math;
import 'dart:ui';

import '../core/palette.dart';
import '../core/rng.dart';
import '../core/scheme.dart';
import '../core/shading.dart';
import 'prop.dart';

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
}

/// 지붕 모양.
enum RoofStyle {
  /// 박공지붕 — 마루가 하나. 가장 흔하다.
  gable,

  /// 평지붕 — 옥상이 보인다. 요새·창고.
  flat,

  /// 원뿔 — 탑.
  cone,
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
    this.wallColor,
    this.roofColor,
    this.litWindows = true,
  }) {
    final r = Rng(seed);
    _storeyH = tileWidth * r.bell(0.34, 0.44);
    final cr = r.branch(11);
    _wallTone = wallColor ??
        switch (wall) {
          WallStyle.timber => hsl(cr.range(34, 44), cr.range(0.10, 0.20), cr.range(0.68, 0.80)),
          WallStyle.stone => hsl(cr.range(200, 225), cr.range(0.04, 0.10), cr.range(0.42, 0.54)),
          WallStyle.log => hsl(cr.range(24, 34), cr.range(0.22, 0.34), cr.range(0.32, 0.42)),
          WallStyle.brick => hsl(cr.range(8, 20), cr.range(0.28, 0.42), cr.range(0.34, 0.44)),
        };
    _roofTone = roofColor ??
        hsl(cr.range(5, 22), cr.range(0.22, 0.40), cr.range(0.22, 0.32));
    _beam = _wallTone.darken(0.55).saturate(0.2);
    _windowSeed = r.intRange(1, 999);
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
  final Color? wallColor;
  final Color? roofColor;

  /// 창문에 불을 켠다. 밤 조명에서 마을이 살아 있는 인상을 만든다.
  final bool litWindows;

  late final double _storeyH;
  late final Color _wallTone;
  late final Color _roofTone;
  late final Color _beam;
  late final int _windowSeed;

  @override
  Size get footprint => tiles;

  @override
  double get height => _storeyH * storeys + tileWidth * 0.5;

  @override
  bool get walkable => false;

  /// 바깥 squash 를 상쇄해 지면 평면 비율을 회복하는 계수.
  double get _planeK {
    final squash = math.sqrt(1 - isoRatio * isoRatio);
    return isoRatio / squash;
  }

  /// 밑면 마름모의 네 꼭짓점 (국소 좌표, 접지 중심 원점).
  ///
  /// 아이소 기저벡터를 그대로 쓴다 — 월드 x 축은 화면에서 오른쪽-아래로,
  /// y 축은 왼쪽-아래로 간다. 그래서 정사각 부지는 위/오른/아래/왼 꼭짓점을
  /// 가진 마름모가 된다.
  ///
  /// 반환 순서: 앞(남) · 오른(동) · 뒤(북) · 왼(서).
  (Offset, Offset, Offset, Offset) _diamond() {
    final hx = tiles.width * 0.5;
    final hy = tiles.height * 0.5;
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
    final top = storeys * _storeyH;
    final hx = tiles.width * 0.5 * tileWidth;
    final hy = tiles.height * 0.5 * tileWidth;

    _paintFoundationShadow(c, light, hx, hy, _planeK);
    _paintWalls(c, light, pF, pR, pL, top, detail);
    _paintRoof(c, light, pF, pR, pB, pL, top, hx, hy, _planeK, detail);
  }

  void _paintFoundationShadow(
      Canvas c, LightRig l, double hx, double hy, double k) {
    final r = math.max(hx, hy);
    propShadow(c, r * 1.02, l, alpha: 0.5, stretch: 1.1);
  }

  void _paintWalls(Canvas c, LightRig l, Offset pF, Offset pR, Offset pL,
      double top, double detail) {
    final up = Offset(0, -top);

    // 광원이 왼쪽에 있으면 왼쪽 벽이 밝다. dir 은 피사체→광원이므로 dx<0 이면
    // 광원이 왼쪽이다.
    final leftLit = l.dir.dx < 0;

    Path quad(Offset a, Offset b) => Path()
      ..moveTo(a.dx, a.dy)
      ..lineTo(b.dx, b.dy)
      ..lineTo(b.dx + up.dx, b.dy + up.dy)
      ..lineTo(a.dx + up.dx, a.dy + up.dy)
      ..close();

    final leftWall = quad(pL, pF);
    final rightWall = quad(pF, pR);

    final finish = switch (wall) {
      WallStyle.timber => Finish.cloth,
      WallStyle.stone => Finish.stone,
      WallStyle.log => Finish.wood,
      WallStyle.brick => Finish.stone,
    };

    // 두 벽의 명도를 확실히 가른다. 이 대비가 입체의 전부다.
    final litTone = _wallTone.lighten(0.06);
    final shadeTone = _wallTone.darken(0.20).mix(l.ambient, 0.28);

    paintSurface(c, leftWall,
        Surface(leftLit ? litTone : shadeTone, finish, contrast: 1.1), l,
        detail: detail, seed: seed, rim: false);
    paintSurface(c, rightWall,
        Surface(leftLit ? shadeTone : litTone, finish, contrast: 1.1), l,
        detail: detail, seed: seed + 5, rim: false);

    if (detail > 0.4) {
      _paintWallDetail(c, l, leftWall, pL, pF, up, leftLit, 0);
      _paintWallDetail(c, l, rightWall, pF, pR, up, !leftLit, 1);
    }

    // 벽이 만나는 모서리. 여기에 밝은 선이 서야 상자의 각이 산다.
    c.drawLine(
      pF,
      pF + up,
      Paint()
        ..isAntiAlias = true
        ..strokeWidth = math.max(1.0, top * 0.012)
        ..color = _wallTone.lighten(0.22).fade(0.7),
    );
  }

  void _paintWallDetail(Canvas c, LightRig l, Path wallPath, Offset a, Offset b,
      Offset up, bool lit, int face) {
    c.save();
    c.clipPath(wallPath);

    final r = Rng(_windowSeed + face * 31);
    final span = b - a;

    if (wall == WallStyle.timber) {
      // 목조 골조 — 회벽을 가로지르는 어두운 보. 중세 마을의 정체성이다.
      final beams = <Path>[];
      for (var s = 0; s < storeys; s++) {
        final y0 = -_storeyH * s;
        beams.add(Path()
          ..moveTo(a.dx, a.dy + y0)
          ..lineTo(b.dx, b.dy + y0));
      }
      for (var i = 1; i < 4; i++) {
        final u = i / 4;
        final p = a + span * u;
        beams.add(Path()
          ..moveTo(p.dx, p.dy)
          ..lineTo(p.dx + up.dx, p.dy + up.dy));
      }
      final w = math.max(1.5, _storeyH * 0.055);
      for (final bm in beams) {
        c.drawPath(
          bm,
          Paint()
            ..isAntiAlias = true
            ..style = PaintingStyle.stroke
            ..strokeWidth = w
            ..color = _beam.fade(0.85),
        );
      }
    } else if (wall == WallStyle.brick || wall == WallStyle.stone) {
      // 석재 줄눈 — 가로선만으로 충분하다. 세로까지 그리면 격자무늬가 된다.
      final rows = (storeys * 6).clamp(4, 18);
      for (var i = 1; i < rows; i++) {
        final y = -_storeyH * storeys * (i / rows);
        c.drawLine(
          Offset(a.dx, a.dy + y),
          Offset(b.dx, b.dy + y),
          Paint()
            ..isAntiAlias = true
            ..strokeWidth = 1
            ..color = _wallTone.darken(0.22).fade(0.35),
        );
      }
    } else {
      // 통나무 — 굵은 가로 원통이 쌓인다.
      final rows = (storeys * 5).clamp(3, 12);
      for (var i = 0; i < rows; i++) {
        final y = -_storeyH * storeys * (i / rows) - _storeyH * 0.05;
        c.drawLine(
          Offset(a.dx, a.dy + y),
          Offset(b.dx, b.dy + y),
          Paint()
            ..isAntiAlias = true
            ..strokeWidth = math.max(2.0, _storeyH * 0.09)
            ..color = _wallTone.darken(0.28).fade(0.5),
        );
      }
    }

    // 창문 — 밤에는 불이 켜진다. 마을이 살아 있다는 유일한 신호다.
    final cols = tiles.width.round().clamp(1, 2);
    for (var s = 0; s < storeys; s++) {
      for (var i = 1; i <= cols; i++) {
        if (!r.chance(0.6)) continue;
        final u = i / (cols + 1);
        final p = a + span * u;
        final y = -_storeyH * (s + 0.62);
        final ww = _storeyH * 0.13;
        final wh = _storeyH * 0.18;
        final rect = Rect.fromCenter(
            center: Offset(p.dx, p.dy + y), width: ww, height: wh);
        final on = litWindows && r.chance(0.65);
        c.drawRect(
          rect,
          Paint()
            ..isAntiAlias = true
            ..color = on
                ? const Color(0xFFFFCE7A)
                : _wallTone.darken(0.62).mix(l.ambient, 0.4),
        );
        if (on) {
          // 창에서 새어 나온 빛이 벽을 적신다. 발광체를 그렸으면 주변도
          // 밝혀야 광원이 장면에 속한 것으로 보인다.
          glowAt(c, rect.center, ww * 1.1, const Color(0xFFFFB347),
              intensity: 0.30);
        }
        c.drawRect(
          rect,
          Paint()
            ..isAntiAlias = true
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1.0, ww * 0.12)
            ..color = _beam.fade(0.9),
        );
      }
    }
    c.restore();
  }

  void _paintRoof(Canvas c, LightRig l, Offset pF, Offset pR, Offset pB,
      Offset pL, double top, double hx, double hy, double k, double detail) {
    final up = Offset(0, -top);
    final f = pF + up, rr = pR + up, b = pB + up, lf = pL + up;

    if (roof == RoofStyle.flat) {
      final deck = Path()
        ..moveTo(f.dx, f.dy)
        ..lineTo(rr.dx, rr.dy)
        ..lineTo(b.dx, b.dy)
        ..lineTo(lf.dx, lf.dy)
        ..close();
      paintSurface(c, deck, Surface(_roofTone.lighten(0.10), Finish.stone), l,
          detail: detail, seed: seed + 9);
      topPlane(c, deck, l, strength: 0.7, elevationSin: isoRatio);
      // 난간
      c.drawPath(
        deck,
        Paint()
          ..isAntiAlias = true
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.5, top * 0.02)
          ..color = _roofTone.darken(0.3).fade(0.8),
      );
      return;
    }

    if (roof == RoofStyle.cone) {
      final apex = Offset(0, -top - _storeyH * 1.15);
      final cone = Path()
        ..moveTo(lf.dx, lf.dy)
        ..lineTo(f.dx, f.dy)
        ..lineTo(apex.dx, apex.dy)
        ..close();
      final cone2 = Path()
        ..moveTo(f.dx, f.dy)
        ..lineTo(rr.dx, rr.dy)
        ..lineTo(apex.dx, apex.dy)
        ..close();
      final leftLit = l.dir.dx < 0;
      paintSurface(c, cone,
          Surface(leftLit ? _roofTone.lighten(0.1) : _roofTone.darken(0.16), Finish.stone), l,
          detail: detail, seed: seed + 11, rim: false);
      paintSurface(c, cone2,
          Surface(leftLit ? _roofTone.darken(0.16) : _roofTone.lighten(0.1), Finish.stone), l,
          detail: detail, seed: seed + 12, rim: false);
      return;
    }

    // 박공지붕 — 마루가 앞뒤 꼭짓점을 잇는다. 처마가 벽 밖으로 나와야
    // 건물이 지붕을 "쓰고" 있는 것으로 보인다.
    final eave = tileWidth * 0.06;
    final ridgeH = _storeyH * 0.62;
    final fe = f + Offset(0, eave * k);
    final re = rr + Offset(eave, 0);
    final le = lf - Offset(eave, 0);
    final ridgeF = Offset(0, f.dy - ridgeH + eave * k);
    final ridgeB = Offset(0, b.dy - ridgeH - eave * k);

    final leftLit = l.dir.dx < 0;
    final slopeL = Path()
      ..moveTo(le.dx, le.dy)
      ..lineTo(fe.dx, fe.dy)
      ..lineTo(ridgeF.dx, ridgeF.dy)
      ..lineTo(ridgeB.dx, ridgeB.dy)
      ..close();
    final slopeR = Path()
      ..moveTo(fe.dx, fe.dy)
      ..lineTo(re.dx, re.dy)
      ..lineTo(ridgeB.dx, ridgeB.dy)
      ..lineTo(ridgeF.dx, ridgeF.dy)
      ..close();

    paintSurface(
        c,
        leftLit ? slopeL : slopeR,
        Surface(_roofTone.lighten(0.12), Finish.stone, contrast: 1.1),
        l,
        detail: detail,
        seed: seed + 13,
        rim: false);
    paintSurface(
        c,
        leftLit ? slopeR : slopeL,
        Surface(_roofTone.darken(0.18).mix(l.ambient, 0.22), Finish.stone),
        l,
        detail: detail,
        seed: seed + 14,
        rim: false);

    // 기와 결. 경사면을 따라 흐르는 선이 지붕의 방향을 말해 준다.
    if (detail > 0.5) {
      for (final (idx, slope) in [slopeL, slopeR].indexed) {
        c.save();
        c.clipPath(slope);
        final steps = 7;
        for (var i = 1; i < steps; i++) {
          final u = i / steps;
          final a = Offset.lerp(idx == 0 ? le : fe, ridgeB, u)!;
          final bb = Offset.lerp(idx == 0 ? fe : re, ridgeF, u)!;
          c.drawLine(
            a,
            bb,
            Paint()
              ..isAntiAlias = true
              ..strokeWidth = 1
              ..color = _roofTone.darken(0.3).fade(0.35),
          );
        }
        c.restore();
      }
    }

    // 마루 능선 — 지붕에서 가장 밝은 선.
    c.drawLine(
      ridgeF,
      ridgeB,
      Paint()
        ..isAntiAlias = true
        ..strokeWidth = math.max(1.5, ridgeH * 0.035)
        ..color = _roofTone.lighten(0.3).fade(0.85),
    );
    rimBand(c, slopeL, l, width: 3, alpha: 0.35, blur: 2);
  }
}

/// 담장·성벽 한 구간.
///
/// 건물과 달리 **한 방향으로만 길게 이어지므로**, 타일을 따라 여러 개를 붙여
/// 놓는 것을 전제로 만들었다. 끝단 기둥이 있어야 이어 붙인 티가 안 난다.
class WallProp extends Prop {
  WallProp({
    required this.seed,
    this.tileWidth = 156,
    this.isoRatio = 0.5,
    this.wallHeight = 52,
    this.thickness = 0.16,
    this.color,
    this.crenellated = false,
    this.alongX = true,
  });

  final int seed;
  final double tileWidth;
  final double isoRatio;
  final double wallHeight;

  /// 타일 폭 대비 두께.
  final double thickness;

  final Color? color;

  /// 성가퀴(총안)를 낸다. 성벽·요새에 쓴다.
  final bool crenellated;

  /// 진행 방향. `true` 면 월드 x 축을 따라 뻗는다.
  final bool alongX;

  @override
  double get height => wallHeight;

  @override
  bool get walkable => false;

  double get _planeK {
    final squash = math.sqrt(1 - isoRatio * isoRatio);
    return isoRatio / squash;
  }

  @override
  void paint(Canvas c, double t, LightRig light, {double detail = 1.0}) {
    final r = Rng(seed);
    final tone = color ?? hsl(r.range(205, 228), 0.05, r.range(0.40, 0.50));
    final k = _planeK;
    final half = tileWidth * 0.5;
    final th = tileWidth * thickness;

    propShadow(c, half * 0.9, light, alpha: 0.42, stretch: 1.05);

    // 벽의 밑선: 진행 방향 ±half, 두께 방향 ±th/2 인 마름모.
    final dir = alongX ? Offset(half, half * k) : Offset(-half, half * k);
    final nrm = alongX ? Offset(th * 0.5, -th * 0.5 * k) : Offset(th * 0.5, th * 0.5 * k);

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

    paintSurface(c, faceSide,
        Surface(tone.darken(0.18).mix(light.ambient, 0.2), Finish.stone), light,
        detail: detail, seed: seed + 1, rim: false);
    paintSurface(c, faceFront,
        Surface(leftLit ? tone.lighten(0.05) : tone.darken(0.08), Finish.stone),
        light,
        detail: detail, seed: seed, rim: false);

    // 윗면 — 하늘을 정면으로 받아 가장 밝다.
    final cap = Path()
      ..moveTo(a.dx + up.dx, a.dy + up.dy)
      ..lineTo(b.dx + up.dx, b.dy + up.dy)
      ..lineTo(bb.dx + up.dx, bb.dy + up.dy)
      ..lineTo(aa.dx + up.dx, aa.dy + up.dy)
      ..close();
    paintSurface(c, cap, Surface(tone.lighten(0.16), Finish.stone), light,
        detail: detail, seed: seed + 2);
    topPlane(c, cap, light, strength: 0.75, elevationSin: isoRatio);

    if (crenellated) {
      // 총안 — 윗면 위에 짧은 블록을 띄엄띄엄 올린다.
      final n = 4;
      for (var i = 0; i < n; i++) {
        if (i.isOdd) continue;
        final u0 = i / n, u1 = (i + 0.7) / n;
        final p0 = Offset.lerp(a + up, b + up, u0)!;
        final p1 = Offset.lerp(a + up, b + up, u1)!;
        final ch = wallHeight * 0.22;
        final merlon = Path()
          ..moveTo(p0.dx, p0.dy)
          ..lineTo(p1.dx, p1.dy)
          ..lineTo(p1.dx, p1.dy - ch)
          ..lineTo(p0.dx, p0.dy - ch)
          ..close();
        paintSurface(c, merlon, Surface(tone.lighten(0.02), Finish.stone), light,
            detail: detail * 0.6, seed: seed + 20 + i, rim: false);
      }
    }

    if (detail > 0.4) {
      c.save();
      c.clipPath(faceFront);
      for (var i = 1; i < 6; i++) {
        final y = -wallHeight * (i / 6);
        c.drawLine(
          Offset(a.dx, a.dy + y),
          Offset(b.dx, b.dy + y),
          Paint()
            ..isAntiAlias = true
            ..strokeWidth = 1
            ..color = tone.darken(0.25).fade(0.4),
        );
      }
      c.restore();
    }
  }
}
