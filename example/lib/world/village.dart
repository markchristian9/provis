import 'dart:ui';

import 'package:provis/provis.dart';

/// 마을 하나를 짓는다 — **게임과 테스트가 같은 함수를 쓴다.**
///
/// 맵 생성이 `FieldGame` 안에 갇혀 있으면 테스트가 실제 맵을 검사할 수 없고,
/// 그러면 "문 앞까지 걸어갈 수 있는가" 같은 질문은 사람이 눈으로 확인하는
/// 수밖에 없다. 눈으로 하는 검사는 회귀를 못 막는다.
///
/// ## 이 파일의 모든 치수는 미터다
///
/// 픽셀을 직접 고르지 않는다. [WorldScale] 이 한 번만 픽셀로 바꾼다. 이 규칙을
/// 어긴 자리가 정확히 "사람이 2층집보다 큰" 맵을 만들었다.
///
/// ## 타일 한 칸 = 1 m 가 배치에 주는 제약
///
/// 이전 맵은 15×15(=15 m×15 m) 위에 `Size(2,2)` 건물을 놓았다. 2 m×2 m 는
/// 집이 아니라 헛간 문짝이다. 사람 크기를 기준으로 삼으면 오두막은 최소
/// 5×6 m, 마당과 길을 합치면 마을 하나에 40 m 안팎이 필요하다.

/// 마을에 선 건물 한 채의 배치 정보.
class BuildingSpot {
  const BuildingSpot({
    required this.tile,
    required this.tiles,
    required this.entrance,
    required this.label,
  });

  /// 접지 **중심** 타일. `BuildingProp` 은 밑면을 `±tiles/2` 로 그린다.
  final Offset tile;

  /// 점유 타일 수.
  final Size tiles;

  /// 문 바로 앞의 통행 가능한 타일.
  ///
  /// `BuildingProp` 은 문을 언제나 `+y` 면(화면 왼쪽-아래로 향한 벽)에 낸다.
  /// 그러므로 진입 타일은 중심에서 `+y` 로 절반 깊이 + 반 칸이다. 이 값이
  /// 실제로 걸어갈 수 있는 칸인지는 `village_nav_test.dart` 가 확인한다.
  final Offset entrance;

  final String label;
}

/// 다 지어진 마을의 배치도.
class VillageLayout {
  const VillageLayout({
    required this.buildings,
    required this.heroSpawn,
    required this.mobSpawns,
    required this.cols,
    required this.rows,
  });

  final List<BuildingSpot> buildings;
  final Offset heroSpawn;
  final List<Offset> mobSpawns;
  final int cols;
  final int rows;
}

/// 마을 맵의 기본 크기(타일 = m).
///
/// 40 m×34 m. 오두막 5~9 m 짜리 일곱 채와 3 m 폭 길, 연못, 숲이 들어가는
/// 최소치다. 더 줄이면 건물이 서로 붙고, 더 키우면 기물 수가 프레임을 먹는다.
const int kVillageCols = 40;
const int kVillageRows = 34;

/// 길의 중심 y(타일)와 폭(m).
const double kRoadWidthM = 3.0;

/// 마을을 짓고 배치도를 돌려준다.
///
/// [scene] 의 기물과 격자를 **지우지 않는다** — 호출부가 정리한다.
VillageLayout buildVillage({
  required IsoSceneComponent scene,
  required int seed,
  required WorldScale scale,
  int cols = kVillageCols,
  int rows = kVillageRows,
  int mobCount = 6,
}) {
  final r = Rng(seed);
  final roadY = rows / 2;

  // ── 길 ───────────────────────────────────────────────────────────────
  //
  // 마을의 뼈대다. 길을 먼저 놓아야 건물이 길을 향해 정렬된다. `PathPatch` 는
  // 눕는 기물이라 통행을 막지 않는다.
  for (var x = 0; x < cols; x++) {
    scene.addProp(PropInstance(
      prop: PathPatch(
        seed: seed + x,
        tileWidth: scale.iso.tileWidth,
        isoRatio: scale.iso.elevationSin,
        width: kRoadWidthM / scale.metersPerTile * 0.62,
      ),
      tile: Offset(x + 0.5, roadY),
    ));
  }

  // ── 건물 ─────────────────────────────────────────────────────────────
  //
  // 길 북쪽과 남쪽에 한 줄씩. 문은 언제나 +y 면에 나므로, 북쪽 집들은 길을
  // 마주보고 남쪽 집들은 등을 돌린다 — 실제 마을도 그렇게 생겼다.
  const northY = 10.0;
  const southY = 24.0;
  final plan = <(String, Offset, Size, int, WallStyle, RoofStyle, bool)>[
    ('오두막', const Offset(6.0, northY), const Size(5, 6), 1,
        WallStyle.timber, RoofStyle.gable, true),
    ('회관', const Offset(16.5, northY - 0.5), const Size(7, 8), 2,
        WallStyle.stone, RoofStyle.hip, true),
    ('헛간', const Offset(28.0, northY), const Size(9, 6), 1,
        WallStyle.plank, RoofStyle.gambrel, false),
    ('망루', const Offset(35.5, northY + 0.5), const Size(5, 5), 2,
        WallStyle.brick, RoofStyle.cone, true),
    ('민가', const Offset(8.0, southY), const Size(6, 6), 1,
        WallStyle.log, RoofStyle.gable, false),
    ('대장간', const Offset(19.0, southY), const Size(6, 7), 1,
        WallStyle.stone, RoofStyle.gable, true),
    ('창고', const Offset(31.0, southY), const Size(7, 6), 2,
        WallStyle.timber, RoofStyle.gable, false),
  ];

  final buildings = <BuildingSpot>[];
  for (final (i, spot) in plan.indexed) {
    final (label, tile, tiles, storeys, wallStyle, roofStyle, alongX) = spot;
    scene.addProp(PropInstance(
      prop: BuildingProp(
        seed: seed + i * 101,
        tiles: tiles,
        tileWidth: scale.iso.tileWidth,
        isoRatio: scale.iso.elevationSin,
        storeys: storeys,
        wall: wallStyle,
        roof: roofStyle,
        ridgeAlongX: alongX,
      ),
      tile: tile,
    ));
    buildings.add(BuildingSpot(
      tile: tile,
      tiles: tiles,
      // 문 앞 한 칸. +y 면 바깥으로 반 칸 더 나간다.
      entrance: Offset(tile.dx, tile.dy + tiles.height / 2 + 0.5),
      label: label,
    ));
  }

  // ── 담과 울타리 ──────────────────────────────────────────────────────
  //
  // 마을의 경계. 길은 비워 두어야 밖에서 걸어 들어올 수 있다.
  for (var y = 0; y < rows; y++) {
    if ((y - roadY).abs() < kRoadWidthM) continue; // 길목은 열어 둔다
    scene.addProp(PropInstance(
      prop: WallProp(
        seed: seed + y * 7,
        tileWidth: scale.iso.tileWidth,
        isoRatio: scale.iso.elevationSin,
        crenellated: true,
        alongX: false,
      ),
      tile: Offset(0.5, y + 0.5),
    ));
  }
  for (var i = 0; i < 6; i++) {
    scene.addProp(PropInstance(
      prop: FenceProp(
        seed: seed + i * 19,
        tileWidth: scale.iso.tileWidth,
        isoRatio: scale.iso.elevationSin,
        alongX: true,
      ),
      tile: Offset(11.5 + i, southY - 4.5),
    ));
  }

  // ── 지형 ─────────────────────────────────────────────────────────────
  //
  // **남쪽 건물 줄보다 더 남쪽에만 놓는다.** 연못은 발자국이 6~7 타일이라
  // 아무 데나 놓으면 집 안으로 파고들고, 그러면 그 집 문 앞이 물에 잠겨
  // 영영 들어갈 수 없다. 실제로 창고의 문 앞이 연못에 먹혔었다 —
  // `village_nav_test.dart` 가 잡았다.
  //
  // 남쪽 건물 줄은 y ≈ 24 이고 깊이 7 을 넘지 않으므로 y ≥ 28 이면 안전하다.
  const terrainY = southY + 7.0;
  scene.addProp(PropInstance(
    prop: WaterProp(seed: seed + 5, radius: scale.px(2.8), scale: scale),
    tile: Offset(cols - 6.0, terrainY),
  ));
  scene.addProp(PropInstance(
    prop: MoundProp(
      seed: seed + 3,
      radius: scale.px(3.5),
      rise: scale.px(1.15),
      isoRatio: scale.iso.elevationSin,
      scale: scale,
      walkOver: true,
    ),
    tile: Offset(4.0, terrainY),
  ));
  scene.addProp(PropInstance(
    prop: PebbleField(seed: seed + 6, radius: scale.px(2.2)),
    tile: Offset(cols - 11.0, terrainY - 1.0),
  ));
  for (var i = 0; i < 22; i++) {
    scene.addProp(PropInstance(
      prop: GroundPatch(
        seed: seed + i * 13,
        radius: scale.px(r.range(0.8, 1.8)),
        blades: 20,
        flowerColor: r.chance(0.35) ? hsl(r.range(300, 360), 0.6, 0.7) : null,
      ),
      tile: Offset(r.range(0.5, cols - 0.5), r.range(0.5, rows - 0.5)),
    ));
  }
  for (var i = 0; i < 7; i++) {
    scene.addProp(PropInstance(
      prop: RockProp(
        seed: seed + i * 211,
        // 사람 무릎에서 허리 사이. height ≈ size × 1.7 이다.
        size: scale.px(r.range(0.30, 0.65)),
        mossy: r.chance(0.5),
        shards: r.intRange(0, 3),
      ),
      tile: _offRoad(r, cols, rows, roadY, buildings),
    ));
  }

  // ── 숲 ───────────────────────────────────────────────────────────────
  //
  // 마을 바깥에만 심는다. 길과 건물 자리를 비우지 않으면 숲이 마을을 삼킨다.
  final forest = <Offset>[];
  // 표본을 넉넉히 던진다. 길과 부지를 걸러내면 절반 이상이 탈락하므로,
  // 원하는 그루 수만큼만 던지면 숲이 앙상해진다.
  for (var i = 0; i < 130; i++) {
    final t = Offset(r.range(1.5, cols - 1.5), r.range(1.5, rows - 1.5));
    if ((t.dy - roadY).abs() < kRoadWidthM) continue;
    if (_insideVillage(t, buildings)) continue;
    forest.add(t);
  }
  scene.addProps(plantForest(
    seed: seed + 77,
    tiles: forest,
    scale: scale,
    kinds: const [
      TreeKind.broadleaf,
      TreeKind.conifer,
      TreeKind.pine,
      TreeKind.blossom,
      TreeKind.dead,
      TreeKind.bush,
    ],
  ));

  // ── 밑풀 ─────────────────────────────────────────────────────────────
  //
  // 큰 기물만 놓으면 사이가 빈 장판으로 남는다. 화면의 밀도는 발치의 작은
  // 것들이 만든다.
  for (var i = 0; i < 60; i++) {
    scene.addProp(PropInstance(
      prop: GrassTuft(seed: seed + i * 31, size: scale.px(r.range(0.30, 0.50))),
      tile: Offset(r.range(0.4, cols - 0.4), r.range(0.4, rows - 0.4)),
      timeOffset: r.range(0, 6),
    ));
  }
  for (var i = 0; i < 18; i++) {
    scene.addProp(PropInstance(
      prop: FlowerBed(seed: seed + i * 53, size: scale.px(r.range(0.35, 0.55))),
      tile: Offset(r.range(0.4, cols - 0.4), r.range(0.4, rows - 0.4)),
      timeOffset: r.range(0, 6),
    ));
  }
  for (var i = 0; i < 5; i++) {
    scene.addProp(PropInstance(
      prop: StumpProp(
        seed: seed + i * 71,
        size: scale.px(r.range(0.45, 0.62)),
        isoRatio: scale.iso.elevationSin,
      ),
      tile: _offRoad(r, cols, rows, roadY, buildings),
    ));
  }
  for (var i = 0; i < 4; i++) {
    scene.addProp(PropInstance(
      prop: LogProp(
        seed: seed + i * 97,
        length: scale.px(r.range(2.2, 3.0)),
        isoRatio: scale.iso.elevationSin,
        alongX: r.chance(0.5),
      ),
      tile: _offRoad(r, cols, rows, roadY, buildings),
    ));
  }

  // ── 등장 위치 ────────────────────────────────────────────────────────
  //
  // 길 위에서 시작한다. 길은 반드시 뚫려 있으므로 갇힌 채로 시작할 수 없다.
  final heroSpawn = _openNear(scene, Offset(2.5, roadY), cols, rows);
  final mobSpawns = <Offset>[];
  for (var i = 0; i < mobCount; i++) {
    final want = Offset(
      6.0 + (i % 3) * 11.0 + r.signed(1.5),
      roadY + (i.isEven ? -1 : 1) * (5.0 + (i ~/ 3) * 4.0),
    );
    mobSpawns.add(_openNear(scene, want, cols, rows));
  }

  return VillageLayout(
    buildings: buildings,
    heroSpawn: heroSpawn,
    mobSpawns: mobSpawns,
    cols: cols,
    rows: rows,
  );
}

/// 통행을 막는 기물(바위·그루터기·통나무)을 놓아도 되는 자리.
///
/// 길과 **건물 마당**을 함께 피한다. 마당을 빼먹으면 바위 하나가 문 앞에
/// 떨어져 그 집에 영영 들어갈 수 없게 된다 — `village_nav_test.dart` 의
/// "모든 건물의 문 앞까지 걸어갈 수 있다" 가 실제로 이걸 잡아냈다.
Offset _offRoad(
  Rng r,
  int cols,
  int rows,
  double roadY,
  List<BuildingSpot> buildings,
) {
  for (var attempt = 0; attempt < 48; attempt++) {
    final t = Offset(r.range(1.5, cols - 1.5), r.range(1.5, rows - 1.5));
    if ((t.dy - roadY).abs() < kRoadWidthM) continue;
    if (_insideVillage(t, buildings)) continue;
    return t;
  }
  // 48번을 실패하면 맵이 꽉 찼다는 뜻이다. 막히는 기물을 억지로 끼워 넣느니
  // 지도 구석의 빈 자리를 쓴다.
  return Offset(cols - 2.5, rows - 2.5);
}

/// 건물 부지 안인가. 숲이 집 안에서 자라는 것을 막는다.
bool _insideVillage(Offset t, List<BuildingSpot> buildings) {
  for (final b in buildings) {
    // 마당 한 칸까지 여유를 준다 — 벽에 나무가 붙으면 문이 막힌다.
    final hx = b.tiles.width / 2 + 1.5;
    final hy = b.tiles.height / 2 + 1.5;
    if ((t.dx - b.tile.dx).abs() < hx && (t.dy - b.tile.dy).abs() < hy) {
      return true;
    }
  }
  return false;
}

/// [want] 에서 가장 가까운 통행 가능한 타일 중심.
Offset _openNear(IsoSceneComponent scene, Offset want, int cols, int rows) {
  final g = scene.grid;
  final wx = want.dx.floor().clamp(0, cols - 1);
  final wy = want.dy.floor().clamp(0, rows - 1);
  if (g == null || g.isWalkable(wx, wy)) return Offset(wx + 0.5, wy + 0.5);
  for (var radius = 1; radius < 14; radius++) {
    for (var dy = -radius; dy <= radius; dy++) {
      for (var dx = -radius; dx <= radius; dx++) {
        if (g.isWalkable(wx + dx, wy + dy)) {
          return Offset(wx + dx + 0.5, wy + dy + 0.5);
        }
      }
    }
  }
  return Offset(wx + 0.5, wy + 0.5);
}
