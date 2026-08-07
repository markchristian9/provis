import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import '../core/noise.dart';
import '../core/palette.dart';
import '../core/scheme.dart';
import '../core/rng.dart';
import '../core/shading.dart';
import '../core/spline.dart';
import '../iso/world_scale.dart';
import 'prop.dart';
import 'prop_kit.dart';

/// 나무의 종류. 실루엣이 근본적으로 달라지므로 색이 아니라 형상이 갈린다.
enum TreeKind {
  /// 활엽수 — 잎 뭉치가 겹친 둥근 수관. 가장 흔한 배경 나무.
  broadleaf,

  /// 전나무 — 처진 바늘잎 층이 위로 좁아진다. 수직선을 만들어 화면을 잡아 준다.
  conifer,

  /// 소나무 — 굽은 줄기가 길게 드러나고 수관이 우산처럼 위에만 얹힌다.
  /// 전나무와 실루엣이 정반대라 둘을 섞어 심으면 숲의 밀도가 단번에 올라간다.
  pine,

  /// 고사목 — 잎이 없고 가지만 남았다. 실루엣 자체가 이야기를 한다.
  dead,

  /// 꽃나무(벚꽃) — 잎 대신 꽃. 색으로 시선을 끄는 강조용이며 꽃잎이 흩날린다.
  blossom,

  /// 수양버들 — 아래로 늘어지는 잎 가닥. 물가에 세운다.
  willow,

  /// 관목·풀나무 — 줄기가 거의 없는 낮은 덤불. 나무 밑동과 담장 아래를 메운다.
  bush,
}

/// 절차적으로 자라는 나무.
///
/// ## 나무가 나무로 읽히는 네 가지
///
/// 1. **실루엣이 잎을 말한다.** 매끄러운 타원에 초록을 칠하면 어떤 셰이딩을
///    얹어도 풍선이다. 수관 윤곽은 잎 뭉치가 만드는 울퉁불퉁한 선이어야 하고
///    ([leafCluster]), 가장자리에서 잎 몇 장이 삐져나와야 한다
///    ([scatterLeaves]).
/// 2. **빛이 잎을 통과한다.** 광원 반대쪽 잎이 그냥 어두우면 플라스틱이다.
///    얇은 잎은 빛을 투과시켜 그늘 쪽이 밝은 황록으로 뜬다 — [Finish.foliage]
///    와 [translucentBand] 가 이 한 겹을 담당한다.
/// 3. **덩어리 안에 덩어리가 있다.** 수관은 잎 뭉치 여럿이 겹친 것이라 단일
///    그라디언트로는 나오지 않는 뭉치 단위의 밝기 차가 있다([lobeLight]).
///    그리고 수관은 자기 줄기에 그림자를 드리운다.
/// 4. **바람에 위상차가 있다.** 덩어리마다 흔들림의 위상을 어긋나게 준다.
///    통째로 흔들면 판때기가 흔들린다.
class TreeProp extends Prop {
  TreeProp({
    required this.seed,
    this.kind = TreeKind.broadleaf,
    this.trunkHeight = 190,
    this.canopyColor,
    this.barkColor,
    this.wind = 1.0,
    this.scale = const WorldScale(),
  }) {
    final r = Rng(seed);
    _lean = r.signed(0.09);
    _trunkR = trunkHeight *
        switch (kind) {
          TreeKind.pine => r.range(0.048, 0.070),
          TreeKind.bush => r.range(0.030, 0.045),
          _ => r.range(0.052, 0.080),
        };
    _canopyR = trunkHeight *
        switch (kind) {
          TreeKind.conifer => r.range(0.40, 0.50),
          TreeKind.pine => r.range(0.52, 0.66),
          TreeKind.dead => r.range(0.30, 0.40),
          TreeKind.willow => r.range(0.52, 0.64),
          TreeKind.bush => r.range(0.62, 0.86),
          _ => r.range(0.56, 0.72),
        };
    _blobCount = switch (kind) {
      TreeKind.conifer => r.intRange(6, 9),
      TreeKind.pine => r.intRange(3, 5),
      TreeKind.dead => 0,
      TreeKind.bush => r.intRange(4, 6),
      _ => r.intRange(7, 10),
    };
    _branchCount = r.intRange(3, 6);
    _noise = Noise(seed * 31 + 7);

    // 색: 지정이 없으면 종류별 대역에서 뽑는다. 한 대역 안에서만 흔들어야
    // 숲 전체가 "같은 계절"로 읽힌다.
    final cr = r.branch(11);
    _bark = barkColor ??
        switch (kind) {
          // 자작·벚나무 계열은 껍질이 밝고 회색기가 돈다.
          TreeKind.blossom =>
            hsl(cr.range(22, 34), cr.range(0.08, 0.16), cr.range(0.24, 0.34)),
          TreeKind.pine =>
            hsl(cr.range(14, 26), cr.range(0.24, 0.40), cr.range(0.18, 0.27)),
          _ => hsl(cr.range(20, 34), cr.range(0.16, 0.32), cr.range(0.15, 0.24)),
        };
    _leaf = canopyColor ??
        switch (kind) {
          TreeKind.blossom =>
            hsl(cr.range(334, 352), cr.range(0.44, 0.62), cr.range(0.56, 0.68)),
          TreeKind.conifer =>
            hsl(cr.range(136, 162), cr.range(0.30, 0.46), cr.range(0.19, 0.28)),
          TreeKind.pine =>
            hsl(cr.range(118, 142), cr.range(0.26, 0.42), cr.range(0.22, 0.31)),
          TreeKind.willow =>
            hsl(cr.range(72, 94), cr.range(0.30, 0.46), cr.range(0.32, 0.42)),
          TreeKind.bush =>
            hsl(cr.range(84, 116), cr.range(0.30, 0.48), cr.range(0.24, 0.34)),
          _ => hsl(cr.range(84, 124), cr.range(0.28, 0.48), cr.range(0.26, 0.38)),
        };
    // 투과광 — 잎을 통과해 나오는 빛은 언제나 원색보다 노랗고 밝다.
    _through = _leaf.shiftHue(kind == TreeKind.blossom ? 6 : -14)
        .saturate(0.30)
        .lighten(kind == TreeKind.blossom ? 0.20 : 0.34);
    _litter = _bark.mix(_leaf, 0.30).darken(0.18);
  }

  final int seed;
  final TreeKind kind;

  /// 밑동에서 수관 시작까지의 높이(px).
  final double trunkHeight;

  final Color? canopyColor;
  final Color? barkColor;

  /// 바람 세기 배율. 0 이면 완전히 정지한다.
  final double wind;

  /// 통행 판정을 타일로 옮길 때 쓰는 자. 그리기에는 영향을 주지 않는다.
  final WorldScale scale;

  late final double _lean;
  late final double _trunkR;
  late final double _canopyR;
  late final int _blobCount;
  late final int _branchCount;
  late final Color _bark;
  late final Color _leaf;
  late final Color _through;
  late final Color _litter;
  late final Noise _noise;

  @override
  double get height => switch (kind) {
        TreeKind.bush => _canopyR * 1.5,
        _ => trunkHeight + _canopyR * 1.6,
      };

  /// 통행을 막는 것은 **줄기**다.
  ///
  /// 예전에는 수관 반지름으로 판정했다. 나무가 제 크기를 찾자 그 규칙은
  /// 즉시 무너진다 — 다 자란 활엽수의 수관은 지름 5 m 를 넘으므로 사람이
  /// 걸어 들어갈 수 있는 나무 그늘이 통째로 벽이 된다. 실제로 몸이 걸리는
  /// 것은 줄기뿐이고, 그것은 어느 종이든 한 타일을 넘지 않는다.
  @override
  Size get footprint {
    final across =
        (_trunkR * 2 / scale.pxPerTile).ceilToDouble().clamp(1.0, 3.0);
    return Size(across, across);
  }

  @override
  bool get walkable => kind == TreeKind.bush;

  // ── 굽기 ────────────────────────────────────────────────────────────────
  //
  // 나무는 이 씬에서 가장 비싼 기물이다. 잎 덩어리 여럿 × 다패스 셰이딩 ×
  // 투과·림이라 그루당 6ms 가 들었고, 화면에 든 스물한 그루가 프레임의
  // 87.5% 를 먹었다.
  //
  // 그런데 나무의 **형상은 고정이다.** 바뀌는 것은 바람뿐이고, 바람은
  // `topX = (_lean + s) * trunkHeight` 로 들어간다 — 밑동은 제자리고 위로
  // 갈수록 옆으로 밀리는 것, 즉 **밑동을 축으로 한 전단**이다. 그러니
  // 형상은 한 번 구워 두고 전단만 매 프레임 걸면 그림이 그대로 재현된다.
  //
  // 잃는 것은 잎 덩어리마다 달랐던 위상차다. 150px 나무에서 그 차이는 몇
  // 픽셀이고, 얻는 것은 60fps 다.

  @override
  bool get bakeable => true;

  @override
  Rect get bakeBounds {
    // 넉넉하되 헤프지 않게. 투명한 여백은 그대로 오버드로가 되므로, 실제로
    // 그리는 것의 크기에서 잡는다 — 수관 반지름 + 기운 양 + 삐져나온 잎.
    final lean = (_lean.abs() + _maxSway) * trunkHeight;
    final w = _canopyR * 1.22 + lean + _trunkR * 2.2;
    // 접지 그림자는 `_canopyR * 0.66` 을 1.35배 늘여 그린다.
    final shadow = _canopyR * 0.66 * 1.35 * 0.5 + _trunkR * 2;
    return Rect.fromLTRB(
        -math.max(w, shadow), -(height + _canopyR * 0.12), math.max(w, shadow),
        _canopyR * 0.42 + _trunkR * 2);
  }

  /// 바람이 낼 수 있는 최대 전단량. [sway] 는 진폭 0.7 + 0.3 의 사인 합이다.
  double get _maxSway => wind * 0.030;

  @override
  void motion(Canvas c, double t) {
    // 구운 자세(t=0)로부터의 **차이**만 건다. 그래야 구운 그림이 기준이 된다.
    final s = wind *
        (sway(t, seed, speed: 0.85) - sway(0, seed, speed: 0.85)) *
        0.030;
    if (s.abs() < 1e-6) return;
    // x' = x - s·y. y 는 위로 갈수록 음수이므로 꼭대기가 +s·trunkHeight 만큼
    // 밀린다 — paint 의 topX 와 정확히 같은 값이다.
    c.transform(Float64List.fromList(<double>[
      1, 0, 0, 0, //
      -s, 1, 0, 0, //
      0, 0, 1, 0, //
      0, 0, 0, 1, //
    ]));
  }

  @override
  void paint(Canvas c, double t, LightRig light, {double detail = 1.0}) {
    final s = wind * sway(t, seed, speed: 0.85) * 0.030;
    final topX = (_lean + s) * trunkHeight;
    final topY = -trunkHeight;

    // ── 접지 세 겹 ──────────────────────────────────────────────────────
    // 드리운 그림자(넓고 옅다) → 밑동 흙(솟아 있다) → 접촉 코어(짙다).
    // 셋이 다 있어야 나무가 지면에 박힌 것으로 보인다.
    propShadow(c, _canopyR * 0.66, light, alpha: 0.38);
    if (detail > 0.3 && kind != TreeKind.bush) {
      rootSkirt(c, _trunkR * 3.4, _litter, light, seed: seed, alpha: 0.55);
    }
    contactAO(c, _trunkR * 1.9, alpha: 0.5);

    switch (kind) {
      case TreeKind.dead:
        _paintTrunk(c, light, topX, topY, detail);
        _paintBareBranches(c, light, topX, topY, s, detail);
      case TreeKind.conifer:
        _paintTrunk(c, light, topX, topY * 1.06, detail, taper: 0.30);
        _paintConiferTiers(c, light, topX, topY, t, detail);
      case TreeKind.pine:
        _paintTrunk(c, light, topX, topY, detail, curved: true);
        _paintPineCrown(c, light, topX, topY, t, detail);
      case TreeKind.bush:
        _paintBush(c, light, t, detail);
      case TreeKind.willow:
        _paintTrunk(c, light, topX, topY, detail);
        _paintBranches(c, light, topX, topY, s, detail);
        _paintCanopy(c, light, topX, topY, t, detail);
        _paintWillowFall(c, light, topX, topY, t, detail);
      case TreeKind.broadleaf:
      case TreeKind.blossom:
        _paintTrunk(c, light, topX, topY, detail);
        _paintBranches(c, light, topX, topY, s, detail);
        _paintCanopy(c, light, topX, topY, t, detail);
        if (kind == TreeKind.blossom && detail > 0.5) {
          _paintFallingPetals(c, t, detail);
        }
    }
  }

  // ── 줄기 ────────────────────────────────────────────────────────────────
  void _paintTrunk(
    Canvas c,
    LightRig l,
    double topX,
    double topY,
    double detail, {
    double taper = 0.52,
    bool curved = false,
  }) {
    // 밑동이 굵고 위가 가는 테이퍼. 뿌리 쪽이 벌어져야 땅에 박힌 것으로
    // 보인다. 직선 원기둥으로 그리면 전봇대가 된다.
    final bend = curved ? _noise.signed1(seed * 0.7) * 0.22 : 0.0;
    final spine = [
      Offset(0, 0),
      Offset(topX * 0.18 + trunkHeight * bend * 0.35, topY * 0.32),
      Offset(topX * 0.58 + trunkHeight * bend * 0.55, topY * 0.68),
      Offset(topX, topY),
    ];
    final trunk = tube(
      spine,
      [_trunkR * 1.70, _trunkR * 1.02, _trunkR * 0.78, _trunkR * taper],
      samples: 20,
      capStart: false,
    );
    paintSurface(c, trunk, Surface(_bark, Finish.bark, contrast: 1.05), l,
        detail: detail, seed: seed, rim: false);

    // 뿌리 확장부 — 밑동에서 갈라져 나온 짧은 판. 접지를 단단하게 만든다.
    if (detail > 0.4) {
      final rr = Rng(seed * 7 + 3);
      for (var i = 0; i < 4; i++) {
        final a = rr.range(-2.9, -0.25);
        final len = _trunkR * rr.range(1.4, 2.4);
        final root = tube(
          [
            Offset(0, -_trunkR * 0.35),
            Offset(math.cos(a) * len * 0.6, -math.sin(a).abs() * len * 0.16),
            Offset(math.cos(a) * len, -math.sin(a).abs() * len * 0.22),
          ],
          [_trunkR * 1.0, _trunkR * 0.52, _trunkR * 0.14],
          samples: 8,
        );
        paintSurface(c, root, Surface(_bark.darken(0.08), Finish.bark), l,
            detail: detail * 0.5, seed: seed + i, rim: false);
      }
    }

    // 수관이 줄기에 드리우는 그림자. 잎 밑이 밝으면 수관이 떠 보인다.
    if (kind != TreeKind.dead) {
      c.save();
      c.clipPath(trunk);
      final top = topY * 0.55;
      c.drawRect(
        Rect.fromLTRB(-_trunkR * 3, topY * 1.2, _trunkR * 3, top),
        Paint()
          ..isAntiAlias = true
          ..blendMode = BlendMode.multiply
          ..shader = Gradient.linear(
            Offset(0, topY),
            Offset(0, top),
            [
              l.ambient.mix(const Color(0xFF000000), 0.30),
              const Color(0xFFFFFFFF),
            ],
          ),
      );
      c.restore();
    }
  }

  // ── 가지 ────────────────────────────────────────────────────────────────
  void _paintBranches(Canvas c, LightRig l, double topX, double topY,
      double swayAmt, double detail) {
    final r = Rng(seed * 13 + 5);
    for (var i = 0; i < _branchCount; i++) {
      final up = r.range(0.45, 0.92);
      final side = r.chance(0.5) ? 1.0 : -1.0;
      final from = Offset(topX * up, topY * up);
      final len = _canopyR * r.range(0.55, 0.95);
      final lift = r.range(0.35, 0.85);
      final mid = from + Offset(side * len * 0.45, -len * lift * 0.30);
      final to = mid + Offset(side * len * 0.55, -len * lift * 0.48);
      final br = tube(
        [from, mid, to],
        [_trunkR * 0.62, _trunkR * 0.32, _trunkR * 0.10],
        samples: 12,
      );
      paintSurface(c, br, Surface(_bark.darken(0.12), Finish.bark), l,
          detail: detail * 0.6, seed: seed + i * 3, rim: false);
    }
  }

  void _paintBareBranches(Canvas c, LightRig l, double topX, double topY,
      double swayAmt, double detail) {
    // 고사목은 가지가 곧 실루엣이다. 굵기 위계를 확실히 줘야 침 다발이 아니라
    // 나무로 읽힌다 — 굵은 주지 몇 개에서 잔가지가 갈라진다.
    final r = Rng(seed * 17 + 11);
    void limb(Offset from, Offset dir, double len, double thick, int depth) {
      final side = dir.dx.sign == 0 ? 1.0 : dir.dx.sign;
      final mid = from + dir * (len * 0.5) + Offset(0, -len * 0.12);
      final to = from + dir * len;
      final br = tube(
        [from, mid, to],
        [thick, thick * 0.55, thick * 0.14],
        samples: 10,
      );
      paintSurface(c, br, Surface(_bark.darken(0.10 + depth * 0.05), Finish.bark),
          l,
          detail: detail * 0.55,
          seed: seed + depth * 13 + len.round(),
          rim: false);
      if (depth >= 2 || len < _trunkR * 2.2) return;
      final n = r.intRange(2, 4);
      for (var i = 0; i < n; i++) {
        final a = dir.angle + side * r.range(-0.85, 0.85) - 0.25;
        limb(
          lerpO(mid, to, r.range(0.35, 0.9)),
          Offset(math.cos(a), math.sin(a)),
          len * r.range(0.42, 0.62),
          thick * 0.5,
          depth + 1,
        );
      }
    }

    for (var i = 0; i < 5; i++) {
      final up = r.range(0.42, 1.0);
      final side = r.chance(0.5) ? 1.0 : -1.0;
      final from = Offset(topX * up, topY * up);
      final a = -math.pi * 0.5 + side * r.range(0.35, 1.1);
      limb(
        from,
        Offset(math.cos(a), math.sin(a)),
        _canopyR * r.range(0.8, 1.4),
        _trunkR * 0.5,
        0,
      );
    }
  }

  // ── 수관 ────────────────────────────────────────────────────────────────
  void _paintCanopy(
      Canvas c, LightRig l, double topX, double topY, double t, double detail) {
    final r = Rng(seed * 23 + 9);
    final center = Offset(topX, topY - _canopyR * 0.34);

    // 덩어리를 뒤 → 앞 순서로 그린다. 크기에 위계를 줘야(큰 것 하나, 중간
    // 둘셋, 작은 여럿) 실루엣이 읽힌다 — 같은 크기를 늘어놓으면 포도송이다.
    final clumps = <(Offset, double, double)>[];
    for (var i = 0; i < _blobCount; i++) {
      final a = (i / _blobCount) * math.pi * 2 + r.signed(0.42);
      final dist = _canopyR * r.range(0.24, 0.62);
      // 첫 덩어리를 크게 잡아 주역으로 삼는다.
      final rad = _canopyR * (i == 0 ? r.range(0.60, 0.72) : r.range(0.30, 0.52));
      final depth = math.sin(a); // -1 뒤 … +1 앞
      clumps.add((
        center + Offset(math.cos(a) * dist, -math.sin(a) * dist * 0.52),
        rad,
        depth,
      ));
    }
    clumps.sort((a, b) => a.$3.compareTo(b.$3));

    for (final (i, clump) in clumps.indexed) {
      final (pos, rad, depth) = clump;
      // 잎 덩어리마다 위상이 다른 바람.
      final w = wind * sway(t, seed, phase: i * 1.7, speed: 1.35) * rad * 0.038;
      _paintLeafMass(
        c,
        l,
        pos + Offset(w, w * 0.3),
        rad,
        (depth + 1) * 0.5,
        seed + i * 11,
        detail,
      );
    }

    // 수관 가장자리에서 삐져나온 잎. 매끈한 윤곽을 깨뜨리는 마지막 한 겹이며,
    // 비용 대비 실루엣 개선 효과가 가장 크다.
    if (detail > 0.55) {
      scatterLeaves(
        c,
        center,
        _canopyR * 1.02,
        _canopyR * 0.86,
        kind == TreeKind.blossom ? _leaf.lighten(0.06) : _leaf.lighten(0.10),
        l,
        seed: seed * 3 + 5,
        count: (30 * detail).round(),
        size: kind == TreeKind.blossom ? 0.13 : 0.17,
        sway: wind * sway(t, seed, speed: 1.2) * 0.12,
      );
    }
  }

  /// 잎 뭉치 하나. 실루엣 → 재질 → 내부 요철 → 투과 → 림 순서로 쌓는다.
  void _paintLeafMass(Canvas c, LightRig l, Offset at, double rad, double lit,
      int massSeed, double detail) {
    final shape = leafCluster(
      at,
      rad,
      rad * 0.88,
      lobes: detail > 0.5 ? 8 : 5,
      lobeSize: 0.46,
      seed: massSeed,
    );

    // 뒤쪽은 어둡고 차갑게, 앞쪽은 밝고 따뜻하게. 이 대비가 부피를 만든다.
    final tone = _leaf
        .darken(0.26 * (1 - lit))
        .mix(l.ambient, 0.32 * (1 - lit))
        .lighten(0.07 * lit);

    paintSurface(
      c,
      shape,
      Surface(
        tone,
        Finish.foliage,
        contrast: 0.82 + 0.20 * lit,
        sss: _through.darken(0.20 * (1 - lit)),
      ),
      l,
      detail: detail,
      seed: massSeed,
    );

    // 뭉치 단위의 밝기 차 — 잎이 여러 겹으로 겹쳐 있다는 신호.
    if (detail > 0.4) {
      c.save();
      c.clipPath(shape);
      lobeLight(c, at, rad, rad * 0.88, tone, l,
          seed: massSeed, count: 3, strength: 0.55 + 0.55 * lit);
      c.restore();
    }

    // 투과와 림은 **앞쪽 덩어리에만** 얹는다. Path.combine 은 복합 형상에서
    // 비싸므로 덩어리마다 두 번씩 부르면 수관 하나에 열 번이 넘게 걸린다.
    // 뒤쪽 덩어리에서는 어차피 보이지도 않는다.
    if (lit > 0.55 && detail > 0.45) {
      translucentBand(
        c,
        shape,
        l,
        width: rad * 0.14,
        color: _through,
        alpha: (0.09 + 0.13 * lit) * l.intensity,
        blur: rad * 0.10,
      );
      rimBand(c, shape, l, width: rad * 0.07, alpha: 0.26 * lit, blur: rad * 0.05);
    }
  }

  // ── 전나무 ──────────────────────────────────────────────────────────────
  void _paintConiferTiers(
      Canvas c, LightRig l, double topX, double topY, double t, double detail) {
    // 처진 바늘잎 층을 아래에서 위로 쌓는다. **위층이 아래층에 드리우는
    // 그림자**가 이 나무의 입체를 만드는 전부다 — 그것이 없으면 초록 삼각형이
    // 겹친 것에 지나지 않는다.
    final tiers = _blobCount;
    final shapes = <Path>[];
    final tones = <Color>[];

    for (var i = 0; i < tiers; i++) {
      final u = i / (tiers - 1); // 0 아래 … 1 위
      final y = topY * (0.24 + 0.80 * u) - _canopyR * 0.05;
      final halfW = _canopyR * (1.0 - 0.78 * u) * (0.92 + 0.16 * _noise.at1(i * 3.1));
      final drop = _canopyR * (0.50 - 0.16 * u);
      final w = wind * sway(t, seed, phase: i * 0.8, speed: 1.1) * halfW * 0.045;
      final cx = topX * (0.24 + 0.80 * u) + w;

      shapes.add(coniferTier(
        Offset(cx, y - drop * 0.9),
        halfW,
        drop,
        teeth: detail > 0.5 ? 7 : 5,
        seed: seed + i * 7,
        sag: 0.36,
      ));
      tones.add(_leaf.lighten(0.16 * u).mix(l.ambient, 0.18 * (1 - u)));
    }

    for (var i = 0; i < tiers; i++) {
      paintSurface(
        c,
        shapes[i],
        Surface(tones[i], Finish.foliage,
            contrast: 1.05, sss: _through.darken(0.28 * (1 - i / tiers))),
        l,
        detail: detail,
        seed: seed + i * 7,
      );

      // 위층 그림자. 아래층 위쪽 절반이 눌려야 층이 겹쳐 보인다.
      if (i + 1 < tiers) {
        c.save();
        c.clipPath(shapes[i]);
        final ub = shapes[i + 1].getBounds();
        c.drawPath(
          shapes[i + 1].shift(Offset(0, ub.height * 0.34)),
          Paint()
            ..isAntiAlias = true
            ..blendMode = BlendMode.multiply
            ..color = l.ambient.mix(const Color(0xFF05070E), 0.30).fade(0.62)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, ub.width * 0.06),
        );
        c.restore();
      }

      // 위쪽 층에만 투과·림을 얹는다. 아래층은 그늘에 잠겨 보이지 않는다.
      if (detail > 0.5 && i >= tiers - 3) {
        translucentBand(c, shapes[i], l,
            width: _canopyR * 0.06,
            color: _through,
            alpha: 0.09 * l.intensity,
            blur: _canopyR * 0.05);
        rimBand(c, shapes[i], l,
            width: _canopyR * 0.030, alpha: 0.22, blur: 2);
      }
    }
  }

  // ── 소나무 ──────────────────────────────────────────────────────────────
  void _paintPineCrown(
      Canvas c, LightRig l, double topX, double topY, double t, double detail) {
    // 소나무는 줄기가 길게 드러나고 수관이 위에만 우산처럼 얹힌다. 가지가
    // 옆으로 뻗고 그 끝에서 잎 다발이 판판하게 퍼진다.
    final r = Rng(seed * 19 + 3);
    final tufts = <(Offset, double, double)>[];

    for (var i = 0; i < _blobCount; i++) {
      final side = i.isEven ? 1.0 : -1.0;
      final u = 0.72 + (i / _blobCount) * 0.34;
      final from = Offset(topX * u, topY * u);
      final len = _canopyR * r.range(0.55, 1.0);
      final rise = r.range(0.18, 0.42);
      final to = from + Offset(side * len, -len * rise);

      final br = tube(
        [from, lerpO(from, to, 0.55) + Offset(0, len * 0.10), to],
        [_trunkR * 0.60, _trunkR * 0.32, _trunkR * 0.12],
        samples: 12,
      );
      paintSurface(c, br, Surface(_bark.darken(0.10), Finish.bark), l,
          detail: detail * 0.6, seed: seed + i * 5, rim: false);

      tufts.add((to, _canopyR * r.range(0.36, 0.54), side));
    }

    // 잎 다발은 판판하게(가로로 넓게) 퍼진다. 이 납작함이 소나무의 정체성이다.
    tufts.sort((a, b) => a.$1.dy.compareTo(b.$1.dy));
    for (final (i, tuft) in tufts.indexed) {
      final (at, rad, side) = tuft;
      final w = wind * sway(t, seed, phase: i * 1.3, speed: 1.2) * rad * 0.05;
      final shape = leafCluster(
        at + Offset(w + side * rad * 0.12, 0),
        rad * 1.35,
        rad * 0.56,
        lobes: detail > 0.5 ? 7 : 4,
        lobeSize: 0.40,
        spread: 0.94,
        seed: seed + i * 13,
      );
      final lit = 0.35 + 0.65 * (i / math.max(1, tufts.length - 1));
      final tone =
          _leaf.darken(0.20 * (1 - lit)).mix(l.ambient, 0.26 * (1 - lit));
      paintSurface(
        c,
        shape,
        Surface(tone, Finish.foliage, contrast: 1.0, sss: _through),
        l,
        detail: detail,
        seed: seed + i * 13,
      );
      if (detail > 0.4) {
        c.save();
        c.clipPath(shape);
        lobeLight(c, at, rad * 1.3, rad * 0.55, tone, l,
            seed: seed + i, count: 2, strength: 0.7);
        c.restore();
      }
      if (detail > 0.5 && lit > 0.55) {
        translucentBand(c, shape, l,
            width: rad * 0.11,
            color: _through,
            alpha: 0.11 * l.intensity,
            blur: rad * 0.09);
      }
      if (detail > 0.55) {
        scatterLeaves(c, at, rad * 1.35, rad * 0.58, tone.lighten(0.10), l,
            seed: seed + i * 29, count: (12 * detail).round(), size: 0.16);
      }
    }
  }

  // ── 관목 ────────────────────────────────────────────────────────────────
  void _paintBush(Canvas c, LightRig l, double t, double detail) {
    final r = Rng(seed * 37 + 5);
    final clumps = <(Offset, double, double)>[];
    for (var i = 0; i < _blobCount; i++) {
      final a = (i / _blobCount) * math.pi * 2 + r.signed(0.5);
      final dist = _canopyR * r.range(0.20, 0.46);
      final rad = _canopyR * (i == 0 ? r.range(0.56, 0.68) : r.range(0.34, 0.50));
      clumps.add((
        Offset(math.cos(a) * dist, -_canopyR * 0.42 - math.sin(a) * dist * 0.38),
        rad,
        math.sin(a),
      ));
    }
    clumps.sort((a, b) => a.$3.compareTo(b.$3));

    // 잔가지가 몇 개 비쳐야 덤불이 흙에서 자란 것으로 읽힌다.
    if (detail > 0.45) {
      for (var i = 0; i < 3; i++) {
        final a = -math.pi * 0.5 + r.range(-0.7, 0.7);
        final len = _canopyR * r.range(0.4, 0.7);
        final stem = tube(
          [Offset.zero, Offset(math.cos(a) * len, math.sin(a) * len)],
          [_trunkR * 0.9, _trunkR * 0.2],
          samples: 6,
        );
        paintSurface(c, stem, Surface(_bark, Finish.bark), l,
            detail: detail * 0.4, seed: seed + i, rim: false);
      }
    }

    for (final (i, clump) in clumps.indexed) {
      final (pos, rad, depth) = clump;
      final w = wind * sway(t, seed, phase: i * 1.9, speed: 1.5) * rad * 0.035;
      _paintLeafMass(c, l, pos + Offset(w, 0), rad, (depth + 1) * 0.5,
          seed + i * 17, detail);
    }
    if (detail > 0.55) {
      scatterLeaves(c, Offset(0, -_canopyR * 0.45), _canopyR * 0.95,
          _canopyR * 0.62, _leaf.lighten(0.12), l,
          seed: seed * 5 + 3, count: (22 * detail).round(), size: 0.20);
    }
  }

  // ── 버드나무 ────────────────────────────────────────────────────────────
  void _paintWillowFall(
      Canvas c, LightRig l, double topX, double topY, double t, double detail) {
    // 늘어지는 가닥은 선이 아니라 **잎이 달린 띠**여야 한다. 얇은 선으로
    // 그리면 국수 다발이 된다.
    final r = Rng(seed * 29 + 13);
    final n = detail > 0.5 ? 24 : 12;
    for (var i = 0; i < n; i++) {
      final a = r.range(-1.0, 1.0);
      final from = Offset(
        topX + a * _canopyR * 1.15,
        topY - _canopyR * 0.10 + r.range(-0.30, 0.30) * _canopyR,
      );
      final len = _canopyR * r.range(1.0, 2.0);
      final w = wind * sway(t, seed, phase: i * 0.8, speed: 1.0) * len * 0.14 +
          a * len * 0.22;
      final lit = 0.45 + 0.55 * r.unit;
      final tone = _leaf
          .lighten(0.10 * lit)
          .darken(0.16 * (1 - lit))
          .mix(l.ambient, 0.18 * (1 - lit));

      final strand = tube(
        [
          from,
          from + Offset(w * 0.4, len * 0.45),
          from + Offset(w, len * 0.92),
        ],
        [_canopyR * 0.022, _canopyR * 0.016, _canopyR * 0.004],
        samples: 12,
      );
      paintSurface(
        c,
        strand,
        Surface(tone, Finish.foliage, contrast: 0.95, sss: _through),
        l,
        detail: detail * 0.6,
        seed: seed + i,
        rim: false,
      );
      // 가닥 끝에 잎을 몇 장 달아 윤곽을 깨뜨린다.
      if (detail > 0.55) {
        final tip = from + Offset(w, len * 0.92);
        scatterLeaves(c, tip, _canopyR * 0.12, _canopyR * 0.16, tone.lighten(0.1),
            l, seed: seed + i * 7, count: 4, size: 0.55);
      }
    }
  }

  // ── 꽃잎 ────────────────────────────────────────────────────────────────
  void _paintFallingPetals(Canvas c, double t, double detail) {
    // 흩날리는 꽃잎. 정지한 벚나무는 조화(造花)다.
    final r = Rng(seed * 61 + 7);
    final paint = Paint()..isAntiAlias = true;
    final n = (10 * detail).round();
    for (var i = 0; i < n; i++) {
      final phase = (t * r.range(0.18, 0.34) + r.unit) % 1.0;
      final x = _canopyR * r.range(-1.1, 1.1) +
          math.sin(t * 1.6 + i * 2.1) * _canopyR * 0.16;
      final y = -trunkHeight * (1.02 - phase * 0.95) + _canopyR * 0.2;
      final sz = _canopyR * r.range(0.022, 0.040);
      final spin = t * 2.2 + i;
      paint.color = _leaf.lighten(0.14).fade(0.85 * (1 - phase * 0.55));
      c.save();
      c.translate(x, y);
      c.scale(1.0, 0.35 + 0.65 * math.sin(spin).abs());
      c.drawOval(
        Rect.fromCenter(center: Offset.zero, width: sz * 2.2, height: sz * 1.5),
        paint,
      );
      c.restore();
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
  double? baseHeight,
  WorldScale scale = const WorldScale(),
}) {
  final r = Rng(seed);
  // 밑동에서 수관 시작까지 [kTreeTrunkM]. 픽셀을 직접 고르면 카메라를 바꿀
  // 때마다 숲이 사람과 다른 비율로 자란다.
  final trunk = baseHeight ?? scale.px(kTreeTrunkM);
  return [
    for (final (i, tile) in tiles.indexed)
      () {
        final kind = r.pick(kinds);
        return PropInstance(
          prop: TreeProp(
            seed: seed + i * 977,
            kind: kind,
            scale: scale,
            // 관목은 나무 키로 만들면 화면을 덮는다. 종류별 기준을 따로 둔다.
            trunkHeight: trunk *
                r.bell(0.82, 1.18) *
                switch (kind) {
                  TreeKind.bush => 0.34,
                  TreeKind.pine => 1.18,
                  TreeKind.conifer => 1.10,
                  _ => 1.0,
                },
          ),
          tile: tile,
          facesLeft: r.chance(0.5),
          timeOffset: r.range(0, 6),
          scale: r.bell(0.9, 1.12),
        );
      }(),
  ];
}
