import 'package:flame/events.dart';
import 'package:flame/game.dart' hide mix;
import 'package:flutter/material.dart' hide Colors;
import 'package:flutter/material.dart' as m show Colors;
import 'package:provis/provis.dart';

import '../characters/roster.dart';

/// 게임 맵 — 선택한 캐릭터로 입장하고, 명부의 모든 몬스터가 한 마리씩 나온다.
///
/// 맵을 클릭하면 캐릭터가 나무와 건물을 피해 걸어간다.
class GameMapScreen extends StatefulWidget {
  const GameMapScreen({super.key, required this.hero});

  final Artist hero;

  @override
  State<GameMapScreen> createState() => _GameMapScreenState();
}

class _GameMapScreenState extends State<GameMapScreen> {
  late final FieldGame _game = FieldGame(hero: widget.hero);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF06080F),
      body: Stack(
        children: [
          GameWidget(game: _game),

          // ── 상단: 뒤로가기 + 선택한 캐릭터 ──────────────────────────────
          Positioned(
            left: 20,
            top: 18,
            child: Row(
              children: [
                _Chip(
                  label: '← 명부',
                  on: false,
                  onTap: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.hero.name.toUpperCase(),
                      style: TextStyle(
                        fontSize: 18,
                        letterSpacing: 4,
                        fontWeight: FontWeight.w700,
                        color: widget.hero.accent,
                      ),
                    ),
                    Text(
                      '맵을 클릭해 이동  ·  몬스터 ${monsters.length}종 출현',
                      style: TextStyle(
                        fontSize: 11,
                        color: m.Colors.white.withValues(alpha: 0.45),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── 우상단: 시각 프리셋 ─────────────────────────────────────────
          Positioned(
            right: 20,
            top: 16,
            child: Row(
              children: [
                for (final (i, name) in const [
                  (0, '정오'),
                  (1, '황혼'),
                  (2, '달빛'),
                  (3, '화톳불'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: _Chip(
                      label: name,
                      on: _game.preset == i,
                      onTap: () => setState(() => _game.setPreset(i)),
                    ),
                  ),
              ],
            ),
          ),

          // ── 하단: 맵 조작 ──────────────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 20,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Chip(
                    label: '맵 다시 생성',
                    on: false,
                    onTap: () => setState(_game.regenerate),
                  ),
                  const SizedBox(width: 10),
                  _Chip(
                    label: _game.showGrid ? '격자 끄기' : '격자 켜기',
                    on: _game.showGrid,
                    onTap: () => setState(_game.toggleGrid),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.on, required this.onTap});
  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: on
              ? const Color(0xFF57E8FF).withValues(alpha: 0.16)
              : m.Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: on
                ? const Color(0xFF57E8FF).withValues(alpha: 0.7)
                : m.Colors.white.withValues(alpha: 0.15),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            letterSpacing: 1,
            color: on ? const Color(0xFFBFF3FF) : m.Colors.white70,
          ),
        ),
      ),
    );
  }
}

/// 아이소 필드.
class FieldGame extends FlameGame with TapCallbacks {
  FieldGame({required this.hero});

  /// 명부에서 고른 캐릭터.
  final Artist hero;

  static const int cols = 15;
  static const int rows = 15;
  static const IsoView iso = IsoView(tileWidth: 150, tileHeight: 75);

  int preset = 1;
  int mapSeed = 20260806;

  bool get showGrid => _scene.showGrid;

  late final IsoSceneComponent _scene = IsoSceneComponent(
    iso: iso,
    grid: IsoGrid(cols: cols, rows: rows),
    light: LightRig.preset(1),
  )..marker = MoveMarker();

  late IsoController _heroCtrl;
  late RiggedIsoActor _heroActor;

  /// 몬스터와 각자의 배회 컨트롤러.
  final List<(RiggedIsoActor, IsoController)> _mobs = [];

  @override
  Color backgroundColor() => const Color(0xFF090D18);

  @override
  Future<void> onLoad() async {
    _recenter(size.toSize());
    _buildMap();
    await add(_scene);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _recenter(size.toSize());
  }

  void _recenter(Size view) {
    _scene.cameraOffset =
        isoCameraOffset(iso, cols, rows, view) + const Offset(0, 26);
  }

  void setPreset(int i) {
    preset = i;
    _scene.light = LightRig.preset(i);
  }

  void toggleGrid() => _scene.showGrid = !_scene.showGrid;

  void regenerate() {
    mapSeed = mapSeed * 31 + 17;
    _buildMap();
  }

  void _buildMap() {
    _scene.props.clear();
    _scene.grid?.clear();
    _scene.rigged.clear();
    _mobs.clear();
    _scene.groundSeed = mapSeed;
    final r = Rng(mapSeed);

    _buildTerrain(r);
    _buildVillage();
    _buildForest(r);
    _buildUndergrowth(r);
    _spawnActors();
  }

  // ── 밑풀 ──────────────────────────────────────────────────────────────
  //
  // 큰 기물만 놓으면 그 사이가 빈 장판으로 남는다. 발치의 작은 것들이
  // 화면의 밀도를 만든다 — 풀 포기·꽃·그루터기·쓰러진 통나무.
  void _buildUndergrowth(Rng r) {
    for (var i = 0; i < 26; i++) {
      final tile = Offset(r.range(0.4, cols - 0.4), r.range(0.4, rows - 0.4));
      _scene.addProp(PropInstance(
        prop: GrassTuft(seed: mapSeed + i * 31, size: r.range(24, 42)),
        tile: tile,
        timeOffset: r.range(0, 6),
      ));
    }
    for (var i = 0; i < 9; i++) {
      _scene.addProp(PropInstance(
        prop: FlowerBed(seed: mapSeed + i * 53, size: r.range(30, 46)),
        tile: Offset(r.range(0.4, cols - 0.4), r.range(0.4, rows - 0.4)),
        timeOffset: r.range(0, 6),
      ));
    }
    for (var i = 0; i < 3; i++) {
      _scene.addProp(PropInstance(
        prop: StumpProp(
          seed: mapSeed + i * 71,
          size: r.range(24, 34),
          isoRatio: iso.elevationSin,
        ),
        tile: Offset(r.range(0.5, cols - 0.5), r.range(6.5, rows - 0.5)),
      ));
    }
    for (var i = 0; i < 2; i++) {
      _scene.addProp(PropInstance(
        prop: LogProp(
          seed: mapSeed + i * 97,
          length: r.range(110, 150),
          isoRatio: iso.elevationSin,
          alongX: r.chance(0.5),
        ),
        tile: Offset(r.range(0.5, cols - 0.5), r.range(6.5, rows - 0.5)),
      ));
    }
  }

  // ── 지형 ──────────────────────────────────────────────────────────────
  void _buildTerrain(Rng r) {
    for (var i = 0; i < cols; i++) {
      _scene.addProp(PropInstance(
        prop: PathPatch(seed: mapSeed + i, tileWidth: iso.tileWidth),
        tile: Offset(i + 0.5, rows / 2 + 0.5),
      ));
    }
    for (var i = 0; i < 16; i++) {
      _scene.addProp(PropInstance(
        prop: GroundPatch(
          seed: mapSeed + i * 13,
          radius: r.range(60, 115),
          blades: 20,
          flowerColor: r.chance(0.35) ? hsl(r.range(300, 360), 0.6, 0.7) : null,
        ),
        tile: Offset(r.range(0.5, cols - 0.5), r.range(0.5, rows - 0.5)),
      ));
    }
    // 언덕 — 지면 자체에 높이가 있다는 사실이 맵을 판에서 지형으로 바꾼다.
    _scene.addProp(PropInstance(
      prop: MoundProp(
        seed: mapSeed + 3,
        radius: 150,
        rise: 34,
        isoRatio: iso.elevationSin,
      ),
      tile: const Offset(2.5, 10.5),
    ));
    _scene.addProp(PropInstance(
      prop: WaterProp(seed: mapSeed + 5, radius: 160),
      tile: const Offset(11.5, 11.5),
    ));
    _scene.addProp(PropInstance(
      prop: PebbleField(seed: mapSeed + 6, radius: 100),
      tile: const Offset(9.5, 12.5),
    ));
    for (var i = 0; i < 5; i++) {
      _scene.addProp(PropInstance(
        prop: RockProp(
          seed: mapSeed + i * 211,
          size: r.range(36, 60),
          mossy: r.chance(0.5),
          shards: r.intRange(0, 3),
        ),
        tile: Offset(r.range(0.5, cols - 0.5), r.range(7.5, rows - 0.5)),
      ));
    }
  }

  // ── 마을 ──────────────────────────────────────────────────────────────
  void _buildVillage() {
    // 마루 방향(ridgeAlongX)을 섞어야 마을이 한 방향으로 도열하지 않는다.
    const spots = <(Offset, Size, int, WallStyle, RoofStyle, bool)>[
      (Offset(2.0, 1.5), Size(2, 2), 2, WallStyle.timber, RoofStyle.gable, true),
      (Offset(6.5, 1.0), Size(1, 1), 1, WallStyle.log, RoofStyle.gable, false),
      (Offset(10.0, 2.0), Size(2, 2), 1, WallStyle.stone, RoofStyle.hip, true),
      (Offset(13.0, 5.0), Size(1, 1), 2, WallStyle.brick, RoofStyle.cone, true),
      // 헛간 — 감베렐 지붕과 판벽이 정체성이다.
      (Offset(5.0, 3.5), Size(2, 1), 1, WallStyle.plank, RoofStyle.gambrel, false),
    ];
    for (final (i, spot) in spots.indexed) {
      final (tile, tiles, storeys, wall, roof, alongX) = spot;
      _scene.addProp(PropInstance(
        prop: BuildingProp(
          seed: mapSeed + i * 101,
          tiles: tiles,
          tileWidth: iso.tileWidth,
          isoRatio: iso.elevationSin,
          storeys: storeys,
          wall: wall,
          roof: roof,
          ridgeAlongX: alongX,
        ),
        tile: tile,
      ));
    }
    for (var i = 0; i < 4; i++) {
      _scene.addProp(PropInstance(
        prop: WallProp(
          seed: mapSeed + i * 7,
          tileWidth: iso.tileWidth,
          isoRatio: iso.elevationSin,
          crenellated: true,
        ),
        tile: Offset(1.5 + i, 5.5),
      ));
    }
    // 울타리 — 돌담이 성의 경계라면 이쪽은 사람이 손으로 세운 경계다.
    for (var i = 0; i < 4; i++) {
      _scene.addProp(PropInstance(
        prop: FenceProp(
          seed: mapSeed + i * 19,
          tileWidth: iso.tileWidth,
          isoRatio: iso.elevationSin,
          alongX: false,
        ),
        tile: Offset(8.5, 3.5 + i),
      ));
    }
  }

  // ── 숲 ────────────────────────────────────────────────────────────────
  void _buildForest(Rng r) {
    final tiles = <Offset>[];
    for (var i = 0; i < 22; i++) {
      final tx = r.range(0.5, cols - 0.5);
      final ty = r.range(0.5, rows - 0.5);
      if ((ty - rows / 2).abs() < 1.3) continue; // 길 위에는 심지 않는다
      if (ty < 4.8 && tx < 13.0) continue; // 마을 자리도 비운다
      tiles.add(Offset(tx, ty));
    }
    _scene.addProps(plantForest(
      seed: mapSeed + 77,
      tiles: tiles,
      // 실루엣이 서로 다른 종을 섞어야 숲의 밀도가 올라간다 — 전나무의 수직선,
      // 소나무의 우산, 활엽수의 덩어리, 관목의 낮은 부피.
      kinds: const [
        TreeKind.broadleaf,
        TreeKind.conifer,
        TreeKind.pine,
        TreeKind.blossom,
        TreeKind.dead,
        TreeKind.bush,
      ],
      baseHeight: 150,
    ));
  }

  // ── 등장 인물 ─────────────────────────────────────────────────────────
  //
  // 선택한 캐릭터 하나와 **명부의 모든 몬스터가 한 마리씩** 나온다. 전부
  // RiggedIsoActor 이므로 걸을 때 다리가 교차하고 방향에 따라 몸이 돈다.
  void _spawnActors() {
    final start = _openTileNear(Offset(cols / 2 + 0.5, rows - 4.5));
    _heroCtrl = IsoController(tile: start, grid: _scene.grid, speed: 3.2);
    _heroActor = riggedFromArtist(hero, tile: start, height: 200);
    _scene.rigged.add(_heroActor);

    // 몬스터는 맵 곳곳에 흩어 놓고 각자 배회시킨다.
    for (final (i, m) in monsters.indexed) {
      final want = Offset(
        2.5 + (i % 2) * 9.0 + (i ~/ 2) * 2.0,
        2.5 + (i ~/ 2) * 8.0 + (i % 2) * 1.5,
      );
      final tile = _openTileNear(want);
      final actor = riggedFromArtist(m, tile: tile, height: 215);
      final ctrl = IsoController(
        tile: tile,
        grid: _scene.grid,
        speed: 1.2 + i * 0.28,
      );
      _scene.rigged.add(actor);
      _mobs.add((actor, ctrl));
    }
  }

  Offset _openTileNear(Offset wanted) {
    final g = _scene.grid!;
    final wx = wanted.dx.floor().clamp(0, cols - 1);
    final wy = wanted.dy.floor().clamp(0, rows - 1);
    if (g.isWalkable(wx, wy)) return Offset(wx + 0.5, wy + 0.5);
    for (var radius = 1; radius < 10; radius++) {
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

  @override
  void onTapDown(TapDownEvent event) {
    final target = _scene.tileAt(event.localPosition.toOffset());
    _heroCtrl.moveTo(target);
    _scene.marker?.ping(target);
  }

  int _wanderTick = 0;

  @override
  void update(double dt) {
    super.update(dt);

    _heroCtrl.update(dt);
    // follow 가 위치·방향·클립(대기/걷기/달리기)을 한 번에 맞춘다.
    _heroActor.follow(_heroCtrl, dt);

    // 몬스터 배회. 목적지에 닿으면 새 목적지를 고른다.
    _wanderTick++;
    final r = Rng(mapSeed ^ (_wanderTick * 2654435761));
    for (final (actor, ctrl) in _mobs) {
      if (!ctrl.isMoving && r.chance(0.02)) {
        ctrl.moveTo(Offset(
          r.range(0.5, cols - 0.5),
          r.range(0.5, rows - 0.5),
        ));
      }
      ctrl.update(dt);
      actor.follow(ctrl, dt);
    }
  }
}
