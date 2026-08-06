import 'dart:math' as math;
import 'dart:ui';

import '../core/noise.dart';
import '../core/palette.dart';
import '../core/scheme.dart';
import '../core/rng.dart';
import '../core/shading.dart';
import '../core/spline.dart';
import 'prop.dart';

/// 나무의 종류. 실루엣이 근본적으로 달라지므로 색이 아니라 형상이 갈린다.
enum TreeKind {
  /// 활엽수 — 둥근 관목 덩어리. 가장 흔한 배경 나무.
  broadleaf,

  /// 침엽수 — 위로 갈수록 좁아지는 원뿔. 수직선을 만들어 화면을 잡아 준다.
  conifer,

  /// 고사목 — 잎이 없고 가지만 남았다. 실루엣 자체가 이야기를 한다.
  dead,

  /// 꽃나무 — 잎 대신 꽃. 색으로 시선을 끄는 강조용.
  blossom,

  /// 수양버들 — 아래로 늘어지는 가지. 물가에 세운다.
  willow,
}

/// 절차적으로 자라는 나무.
///
/// ## 왜 이렇게 그리는가
///
/// 나무를 "기둥 + 초록 원"으로 그리면 즉시 클립아트가 된다. 진짜 나무로
/// 읽히게 하는 것은 세 가지다.
///
/// 1. **잎 덩어리를 여러 겹으로 나눈다.** 뒤쪽 덩어리를 어둡고 차갑게, 앞쪽을
///    밝고 따뜻하게 칠하면 평면이던 수관에 부피가 생긴다. 한 덩어리로 그리면
///    아무리 잘 칠해도 종잇장이다.
/// 2. **가지가 잎 사이로 비친다.** 수관 안쪽에 가지 끝이 몇 개 보이면 잎이
///    가지에 달려 있다는 사실이 전달된다.
/// 3. **바람이 위상차를 갖는다.** 잎 덩어리마다 흔들림의 위상을 어긋나게 주면
///    나무가 살아 있는 것으로 보인다. 통째로 흔들면 판때기가 흔들린다.
class TreeProp extends Prop {
  TreeProp({
    required this.seed,
    this.kind = TreeKind.broadleaf,
    this.trunkHeight = 190,
    this.canopyColor,
    this.barkColor,
    this.wind = 1.0,
  }) {
    final r = Rng(seed);
    _lean = r.signed(0.10);
    _trunkR = trunkHeight * r.range(0.055, 0.085);
    _canopyR = trunkHeight * switch (kind) {
      TreeKind.conifer => r.range(0.42, 0.52),
      TreeKind.dead => r.range(0.30, 0.40),
      TreeKind.willow => r.range(0.52, 0.64),
      _ => r.range(0.55, 0.70),
    };
    _blobCount = switch (kind) {
      TreeKind.conifer => r.intRange(4, 7),
      TreeKind.dead => 0,
      _ => r.intRange(4, 7),
    };
    _branchCount = r.intRange(3, 6);
    _noise = Noise(seed * 31 + 7);

    // 색: 지정이 없으면 종류별 대역에서 뽑는다. 한 대역 안에서만 흔들어야
    // 숲 전체가 "같은 계절"로 읽힌다.
    final cr = r.branch(11);
    _bark = barkColor ??
        hsl(cr.range(20, 34), cr.range(0.18, 0.34), cr.range(0.16, 0.26));
    _leaf = canopyColor ??
        switch (kind) {
          TreeKind.blossom =>
            hsl(cr.range(330, 355), cr.range(0.45, 0.68), cr.range(0.62, 0.76)),
          TreeKind.conifer =>
            hsl(cr.range(140, 165), cr.range(0.32, 0.48), cr.range(0.20, 0.30)),
          TreeKind.willow =>
            hsl(cr.range(75, 95), cr.range(0.30, 0.45), cr.range(0.34, 0.44)),
          _ => hsl(cr.range(88, 122), cr.range(0.30, 0.50), cr.range(0.28, 0.40)),
        };
  }

  final int seed;
  final TreeKind kind;

  /// 밑동에서 수관 시작까지의 높이(px).
  final double trunkHeight;

  final Color? canopyColor;
  final Color? barkColor;

  /// 바람 세기 배율. 0 이면 완전히 정지한다.
  final double wind;

  late final double _lean;
  late final double _trunkR;
  late final double _canopyR;
  late final int _blobCount;
  late final int _branchCount;
  late final Color _bark;
  late final Color _leaf;
  late final Noise _noise;

  @override
  double get height => trunkHeight + _canopyR * 1.6;

  @override
  Size get footprint => _canopyR > 130 ? const Size(2, 2) : const Size(1, 1);

  @override
  bool get walkable => false;

  @override
  void paint(Canvas c, double t, LightRig light, {double detail = 1.0}) {
    final sway = wind * math.sin(t * 0.9 + seed * 0.37) * 0.028;
    final topX = (_lean + sway) * trunkHeight;
    final topY = -trunkHeight;

    propShadow(c, _canopyR * 0.62, light, alpha: 0.40);

    _paintTrunk(c, light, topX, topY, detail);

    if (kind == TreeKind.dead) {
      _paintBareBranches(c, light, topX, topY, sway, detail);
      return;
    }
    if (kind == TreeKind.conifer) {
      _paintConiferTiers(c, light, topX, topY, sway, detail);
      return;
    }
    _paintBranches(c, light, topX, topY, sway, detail);
    _paintCanopy(c, light, topX, topY, t, detail);
    if (kind == TreeKind.willow) {
      _paintWillowFall(c, light, topX, topY, t, detail);
    }
  }

  // ── 줄기 ────────────────────────────────────────────────────────────────
  void _paintTrunk(Canvas c, LightRig l, double topX, double topY, double detail) {
    // 밑동이 굵고 위가 가는 테이퍼. 뿌리 쪽이 살짝 벌어져야 땅에 박힌 것으로
    // 보인다. 직선 원기둥으로 그리면 전봇대가 된다.
    final spine = [
      Offset(0, 0),
      Offset(topX * 0.18, topY * 0.32),
      Offset(topX * 0.58, topY * 0.68),
      Offset(topX, topY),
    ];
    final trunk = tube(
      spine,
      [_trunkR * 1.55, _trunkR * 1.0, _trunkR * 0.78, _trunkR * 0.52],
      samples: 18,
      capStart: false,
    );
    paintSurface(c, trunk, Surface(_bark, Finish.wood, contrast: 1.05), l,
        detail: detail, seed: seed);

    // 뿌리 확장부 — 밑동에서 갈라져 나온 짧은 판. 접지를 단단하게 만든다.
    if (detail > 0.4) {
      final rr = Rng(seed * 7 + 3);
      for (var i = 0; i < 3; i++) {
        final a = rr.range(-2.6, -0.5);
        final len = _trunkR * rr.range(1.2, 2.0);
        final root = tube(
          [Offset.zero, Offset(math.cos(a) * len * 0.6, -math.sin(a).abs() * len * 0.2),
           Offset(math.cos(a) * len, -math.sin(a).abs() * len * 0.28)],
          [_trunkR * 0.9, _trunkR * 0.5, _trunkR * 0.16],
          samples: 8,
        );
        paintSurface(c, root, Surface(_bark.darken(0.06), Finish.wood), l,
            detail: detail * 0.6, seed: seed + i);
      }
    }
  }

  // ── 가지 ────────────────────────────────────────────────────────────────
  void _paintBranches(
      Canvas c, LightRig l, double topX, double topY, double sway, double detail) {
    final r = Rng(seed * 13 + 5);
    for (var i = 0; i < _branchCount; i++) {
      final up = r.range(0.45, 0.92);
      final side = r.chance(0.5) ? 1.0 : -1.0;
      final from = Offset(topX * up, topY * up);
      final len = _canopyR * r.range(0.55, 0.95);
      final ang = side * r.range(0.5, 1.25) + sway * 2;
      final to = from + Offset(math.cos(-ang) * len * side.abs() * side,
                               -math.sin(ang.abs()) * len * 0.72);
      final br = tube(
        [from, lerpO(from, to, 0.55) + Offset(0, -len * 0.10), to],
        [_trunkR * 0.55, _trunkR * 0.30, _trunkR * 0.10],
        samples: 10,
      );
      paintSurface(c, br, Surface(_bark.darken(0.1), Finish.wood), l,
          detail: detail * 0.7, seed: seed + i * 3);
    }
  }

  void _paintBareBranches(
      Canvas c, LightRig l, double topX, double topY, double sway, double detail) {
    // 고사목은 가지가 곧 실루엣이다. 더 많이, 더 멀리, 더 날카롭게 뻗는다.
    final r = Rng(seed * 17 + 11);
    for (var i = 0; i < 9; i++) {
      final up = r.range(0.35, 1.0);
      final side = r.chance(0.5) ? 1.0 : -1.0;
      final from = Offset(topX * up, topY * up);
      final len = _canopyR * r.range(0.7, 1.5);
      final lift = r.range(0.3, 1.1);
      final mid = from + Offset(side * len * 0.45, -len * lift * 0.35);
      final to = mid + Offset(side * len * 0.5, -len * lift * 0.5);
      final br = tube(
        [from, mid, to],
        [_trunkR * 0.48, _trunkR * 0.22, _trunkR * 0.03],
        samples: 12,
      );
      paintSurface(c, br, Surface(_bark.darken(0.14), Finish.wood), l,
          detail: detail * 0.6, seed: seed + i);
      // 잔가지
      if (detail > 0.5 && r.chance(0.7)) {
        final tw = tube(
          [mid, lerpO(mid, to, 0.6) + Offset(side * len * 0.18, -len * 0.14)],
          [_trunkR * 0.16, _trunkR * 0.02],
          samples: 6,
        );
        paintSurface(c, tw, Surface(_bark.darken(0.2), Finish.wood), l,
            detail: 0.3, seed: seed + i * 5);
      }
    }
  }

  // ── 수관 ────────────────────────────────────────────────────────────────
  void _paintCanopy(
      Canvas c, LightRig l, double topX, double topY, double t, double detail) {
    final r = Rng(seed * 23 + 9);
    final center = Offset(topX, topY - _canopyR * 0.30);

    // 덩어리를 뒤 → 앞 순서로 그린다. 뒤쪽은 어둡고 차갑게, 앞쪽은 밝고
    // 따뜻하게. 이 대비 하나가 수관에 부피를 만든다.
    final clumps = <(Offset, double, double)>[];
    for (var i = 0; i < _blobCount; i++) {
      final a = (i / _blobCount) * math.pi * 2 + r.signed(0.4);
      final dist = _canopyR * r.range(0.20, 0.52);
      final rad = _canopyR * r.range(0.46, 0.72);
      final depth = math.sin(a); // -1 뒤 … +1 앞
      clumps.add((
        center + Offset(math.cos(a) * dist, -math.sin(a) * dist * 0.55),
        rad,
        depth,
      ));
    }
    clumps.sort((a, b) => a.$3.compareTo(b.$3));

    for (final (i, clump) in clumps.indexed) {
      final (pos, rad, depth) = clump;
      // 잎 덩어리마다 위상이 다른 바람.
      final w = wind * math.sin(t * 1.4 + i * 1.7 + seed * 0.29) * rad * 0.035;
      final wobbled = pos + Offset(w, w * 0.35);

      final lit = (depth + 1) * 0.5; // 0 뒤 … 1 앞
      final tone = _leaf
          .darken(0.22 * (1 - lit))
          .mix(l.ambient, 0.30 * (1 - lit))
          .lighten(0.08 * lit);

      final shape = blob(
        wobbled,
        rad,
        rad * 0.88,
        points: 13,
        warp: (angle, u) => 1.0 + 0.16 * _noise.signed1(u * 5.0 + i * 3.1),
      );
      paintSurface(
        c,
        shape,
        Surface(tone, kind == TreeKind.blossom ? Finish.cloth : Finish.fur,
            contrast: 0.95 + 0.2 * lit),
        l,
        detail: detail,
        seed: seed + i * 11,
      );

      // 앞쪽 덩어리 위에만 림을 얹어 수관 상단이 하늘과 만나는 선을 살린다.
      if (lit > 0.6 && detail > 0.5) {
        rimBand(c, shape, l, width: rad * 0.10, alpha: 0.45 * lit, blur: rad * 0.06);
      }
    }
  }

  void _paintConiferTiers(
      Canvas c, LightRig l, double topX, double topY, double sway, double detail) {
    // 침엽수는 원뿔을 층으로 쌓는다. 아래 층이 넓고 위로 갈수록 좁아지며,
    // 층 사이가 조금씩 겹쳐야 나뭇가지 단이 읽힌다.
    final tiers = _blobCount + 2;
    for (var i = tiers - 1; i >= 0; i--) {
      final u = i / (tiers - 1); // 0 아래 … 1 위
      final y = topY * (0.28 + 0.78 * u) - _canopyR * 0.1;
      final halfW = _canopyR * (1.0 - 0.72 * u);
      final h = _canopyR * (0.42 - 0.14 * u);
      final w = wind * math.sin(sway * 8 + i * 0.9 + seed * 0.3) * halfW * 0.05;
      final cx = topX * (0.28 + 0.78 * u) + w;

      final tier = smoothClosedPath([
        Offset(cx, y - h * 1.5),
        Offset(cx + halfW * 0.55, y - h * 0.15),
        Offset(cx + halfW, y + h * 0.55),
        Offset(cx + halfW * 0.42, y + h * 0.35),
        Offset(cx, y + h * 0.62),
        Offset(cx - halfW * 0.42, y + h * 0.35),
        Offset(cx - halfW, y + h * 0.55),
        Offset(cx - halfW * 0.55, y - h * 0.15),
      ], tension: 0.75);

      final tone = _leaf.lighten(0.14 * u).mix(l.ambient, 0.16 * (1 - u));
      paintSurface(c, tier, Surface(tone, Finish.fur, contrast: 1.05), l,
          detail: detail, seed: seed + i * 7);
      if (detail > 0.5 && u > 0.35) {
        rimBand(c, tier, l, width: halfW * 0.08, alpha: 0.4, blur: 2);
      }
    }
  }

  void _paintWillowFall(
      Canvas c, LightRig l, double topX, double topY, double t, double detail) {
    // 늘어지는 가지. 끝으로 갈수록 가늘어지고 바람에 크게 흔들린다.
    final r = Rng(seed * 29 + 13);
    final n = detail > 0.5 ? 14 : 7;
    for (var i = 0; i < n; i++) {
      final a = r.range(-1.0, 1.0);
      final from = Offset(topX + a * _canopyR * 0.85,
                          topY - _canopyR * 0.1 + r.range(-0.2, 0.2) * _canopyR);
      final len = _canopyR * r.range(0.8, 1.5);
      final w = wind * math.sin(t * 1.1 + i * 0.8) * len * 0.10;
      final strand = tube(
        [
          from,
          from + Offset(w * 0.4, len * 0.45),
          from + Offset(w, len * 0.9),
        ],
        [_trunkR * 0.14, _trunkR * 0.09, _trunkR * 0.02],
        samples: 10,
      );
      paintSurface(c, strand, Surface(_leaf.darken(0.05 * (i % 3)), Finish.fur), l,
          detail: detail * 0.5, seed: seed + i);
    }
  }
}

/// 한 자리에 나무를 심는다. 숲을 만들 때 개체 변주를 자동으로 준다.
///
/// 같은 [TreeProp] 을 여러 타일에 재사용하면 형상 계산을 공유해 저렴하지만
/// 숲이 복제 인간처럼 보인다. 이 함수는 시드마다 종류·크기·기울기를 흔들어
/// 그 문제를 없앤다.
List<PropInstance> plantForest({
  required int seed,
  required List<Offset> tiles,
  List<TreeKind> kinds = const [TreeKind.broadleaf, TreeKind.conifer],
  double baseHeight = 190,
}) {
  final r = Rng(seed);
  return [
    for (final (i, tile) in tiles.indexed)
      PropInstance(
        prop: TreeProp(
          seed: seed + i * 977,
          kind: r.pick(kinds),
          trunkHeight: baseHeight * r.bell(0.82, 1.18),
        ),
        tile: tile,
        facesLeft: r.chance(0.5),
        timeOffset: r.range(0, 6),
        scale: r.bell(0.9, 1.12),
      ),
  ];
}
