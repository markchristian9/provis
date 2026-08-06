import 'package:flame/events.dart';
import 'package:flame/game.dart' hide mix;
import 'package:flutter/material.dart';
import 'package:provis/provis.dart';


/// provis 종합 데모 — 아이소 필드.
///
///   flutter run -t lib/main.dart
///
/// 보여 주는 것:
/// - 절차적 맵 기물 (나무·바위·건물·담장·물웅덩이·길·풀)
/// - 손으로 만든 캐릭터가 같은 씬에 서고, 기물과 **하나의 깊이 정렬**을 거친다
/// - 클릭 이동 — 8방향 A*, 나무와 건물을 피해 걷는다
/// - 조명 프리셋 전환 시 화면 전체가 한꺼번에 반응한다
void main() {
  runApp(const ProvisDemoApp());
}

class ProvisDemoApp extends StatelessWidget {
  const ProvisDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'provis — Isometric Field',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const _Screen(),
    );
  }
}

class _Screen extends StatefulWidget {
  const _Screen();

  @override
  State<_Screen> createState() => _ScreenState();
}

class _ScreenState extends State<_Screen> {
  late final FieldGame _game = FieldGame();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF05070C),
      body: Stack(
        children: [
          GameWidget(game: _game),
          Positioned(
            left: 24,
            top: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('PROVIS',
                    style: TextStyle(
                        fontSize: 22,
                        letterSpacing: 6,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('맵을 클릭하면 영웅이 나무와 건물을 피해 걸어갑니다',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.55))),
              ],
            ),
          ),
          Positioned(
            right: 24,
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
          Positioned(
            left: 0,
            right: 0,
            bottom: 22,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Chip(
                      label: '맵 다시 생성',
                      on: false,
                      onTap: () => setState(_game.regenerate)),
                  const SizedBox(width: 10),
                  _Chip(
                      label: _game.showGrid ? '격자 끄기' : '격자 켜기',
                      on: _game.showGrid,
                      onTap: () => setState(_game.toggleGrid)),
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
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: on
                  ? const Color(0xFF57E8FF).withValues(alpha: 0.7)
                  : Colors.white.withValues(alpha: 0.15)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                letterSpacing: 1,
                color: on ? const Color(0xFFBFF3FF) : Colors.white70)),
      ),
    );
  }
}

/// 아이소 필드 게임.
class FieldGame extends FlameGame with TapCallbacks {
  static const int cols = 14;
  static const int rows = 14;
  static const IsoView iso = IsoView(tileWidth: 150, tileHeight: 75);

  int preset = 1;
  int mapSeed = 20260806;

  bool get showGrid => _scene.showGrid;

  late final IsoSceneComponent _scene = IsoSceneComponent(
    iso: iso,
    grid: IsoGrid(cols: cols, rows: rows),
    light: LightRig.preset(1),
  )..marker = MoveMarker();

  late IsoController _hero;
  late RiggedIsoActor _heroActor;
  final List<(RiggedIsoActor, IsoController)> _wanderers = [];

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
        isoCameraOffset(iso, cols, rows, view) + const Offset(0, 30);
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

  /// 맵을 생성한다.
  ///
  /// 기물을 `addProp` 으로 넣으면 통행 격자도 함께 막히므로, 화면에 보이는
  /// 것과 캐릭터가 피해 가는 것이 언제나 일치한다.
  void _buildMap() {
    _scene.props.clear();
    _scene.grid?.clear();
    final r = Rng(mapSeed);

    // ── 지면: 길과 풀밭 ──────────────────────────────────────────────────
    for (var i = 0; i < cols; i++) {
      _scene.addProp(PropInstance(
        prop: PathPatch(seed: mapSeed + i, tileWidth: iso.tileWidth),
        tile: Offset(i + 0.5, rows / 2 + 0.5),
      ));
    }
    for (var i = 0; i < 14; i++) {
      _scene.addProp(PropInstance(
        prop: GroundPatch(
          seed: mapSeed + i * 13,
          radius: r.range(60, 115),
          blades: 20,
          flowerColor:
              r.chance(0.35) ? hsl(r.range(300, 360), 0.6, 0.7) : null,
        ),
        tile: Offset(r.range(0.5, cols - 0.5), r.range(0.5, rows - 0.5)),
      ));
    }

    // ── 물웅덩이 ─────────────────────────────────────────────────────────
    _scene.addProp(PropInstance(
      prop: WaterProp(seed: mapSeed + 5, radius: 160),
      tile: const Offset(10.5, 10.5),
    ));

    // ── 마을: 건물 세 채 ─────────────────────────────────────────────────
    const spots = <(Offset, Size, int, WallStyle, RoofStyle)>[
      (Offset(2.0, 1.5), Size(2, 2), 2, WallStyle.timber, RoofStyle.gable),
      (Offset(6.5, 1.0), Size(1, 1), 1, WallStyle.log, RoofStyle.gable),
      (Offset(9.5, 2.0), Size(2, 2), 1, WallStyle.stone, RoofStyle.gable),
      (Offset(12.0, 5.0), Size(1, 1), 2, WallStyle.brick, RoofStyle.cone),
    ];
    for (final (i, spot) in spots.indexed) {
      final (tile, tiles, storeys, wall, roof) = spot;
      _scene.addProp(PropInstance(
        prop: BuildingProp(
          seed: mapSeed + i * 101,
          tiles: tiles,
          tileWidth: iso.tileWidth,
          isoRatio: iso.elevationSin,
          storeys: storeys,
          wall: wall,
          roof: roof,
        ),
        tile: tile,
      ));
    }

    // ── 담장 ────────────────────────────────────────────────────────────
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

    // ── 숲 ──────────────────────────────────────────────────────────────
    final forestTiles = <Offset>[];
    for (var i = 0; i < 20; i++) {
      final tx = r.range(0.5, cols - 0.5);
      final ty = r.range(0.5, rows - 0.5);
      if ((ty - rows / 2).abs() < 1.3) continue; // 길 위에는 심지 않는다
      if (ty < 4.8 && tx < 12.5) continue; // 마을 자리도 비운다
      forestTiles.add(Offset(tx, ty));
    }
    _scene.addProps(plantForest(
      seed: mapSeed + 77,
      tiles: forestTiles,
      kinds: const [
        TreeKind.broadleaf,
        TreeKind.conifer,
        TreeKind.blossom,
        TreeKind.dead,
      ],
      baseHeight: 150,
    ));

    // ── 바위 ────────────────────────────────────────────────────────────
    for (var i = 0; i < 5; i++) {
      _scene.addProp(PropInstance(
        prop: RockProp(
          seed: mapSeed + i * 211,
          size: r.range(36, 60),
          mossy: r.chance(0.5),
          shards: r.intRange(0, 3),
        ),
        tile: Offset(r.range(0.5, cols - 0.5), r.range(6.5, rows - 0.5)),
      ));
    }

    // ── 영웅과 몬스터 ───────────────────────────────────────────────────
    //
    // 게임플레이 액터는 RiggedIsoActor 를 쓴다. 손으로 그린 Artist 는 고정
    // 3/4 초상이라 걸어도 자세가 그대로지만, 이쪽은 매 프레임 Pose 를 풀어
    // 그리므로 다리가 교차하고 방향에 따라 몸이 돈다.
    _scene.actors.clear();
    _scene.rigged.clear();
    _wanderers.clear();

    final start = _openTileNear(const Offset(6.5, 9.5));
    _hero = IsoController(tile: start, grid: _scene.grid, speed: 3.0);
    _heroActor = RiggedIsoActor(
      renderer: HumanoidRenderer(HumanoidSpec.generate(mapSeed ^ 0x11EE)),
      tile: start,
      height: 195,
    );
    _scene.rigged.add(_heroActor);

    // 몬스터도 같은 방식으로 — 짐승 골격에 같은 클립을 얹으면 전혀 다른
    // 걸음걸이가 나온다. 각자 맵을 돌아다닌다.
    for (var i = 0; i < 3; i++) {
      final seed = mapSeed ^ (0xB0A5 + i * 7919);
      final spec = HumanoidSpec.generate(seed);
      final tile = _openTileNear(Offset(2.5 + i * 4.0, 12.0));
      final ctrl = IsoController(
        tile: tile,
        grid: _scene.grid,
        speed: 1.5 + i * 0.35,
      );
      final actor = RiggedIsoActor(
        renderer: HumanoidRenderer(
          spec,
          body: Body.beast(Rng(seed ^ 0x5EED), height: spec.height * 1.12),
          palette: Palette.monster(Rng(seed ^ 0xB0A5)),
          beast: true,
        ),
        tile: tile,
        height: 215,
      );
      _scene.rigged.add(actor);
      _wanderers.add((actor, ctrl));
    }
  }

  /// 몬스터가 스스로 맵을 배회한다. 목적지에 닿으면 새 목적지를 고른다.
  void _wander(double dt) {
    final r = Rng(DateTime.now().microsecondsSinceEpoch & 0x7FFFFFFF);
    for (final (actor, ctrl) in _wanderers) {
      if (!ctrl.isMoving) {
        ctrl.moveTo(Offset(
          r.range(0.5, cols - 0.5),
          r.range(0.5, rows - 0.5),
        ));
      }
      ctrl.update(dt);
      actor.follow(ctrl, dt);
    }
  }

  Offset _openTileNear(Offset wanted) {
    final g = _scene.grid!;
    if (g.isWalkable(wanted.dx.floor(), wanted.dy.floor())) return wanted;
    for (var radius = 1; radius < 8; radius++) {
      for (var dy = -radius; dy <= radius; dy++) {
        for (var dx = -radius; dx <= radius; dx++) {
          final x = wanted.dx.floor() + dx, y = wanted.dy.floor() + dy;
          if (g.isWalkable(x, y)) return Offset(x + 0.5, y + 0.5);
        }
      }
    }
    return wanted;
  }

  @override
  void onTapDown(TapDownEvent event) {
    final target = _scene.tileAt(event.localPosition.toOffset());
    _hero.moveTo(target);
    _scene.marker?.ping(target);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _hero.update(dt);
    // follow 가 위치·방향·클립(대기/걷기/달리기)을 한 번에 맞춘다.
    _heroActor.follow(_hero, dt);
    _wander(dt);
  }
}
