import 'dart:async';
import 'dart:math' as math;

import 'package:flame/events.dart';
import 'package:flame/game.dart' hide mix;
import 'package:flutter/material.dart' hide Colors;
import 'package:flutter/material.dart' as m show Colors;
import 'package:provis/provis.dart';

import '../audio/game_audio.dart';
import '../characters/roster.dart';
import '../world/camera.dart';
import '../world/village.dart';
import '../i18n/lang.dart';

/// 게임 맵 — 선택한 캐릭터로 입장하고, 명부의 모든 몬스터가 한 마리씩 나온다.
///
/// 맵을 클릭하면 캐릭터가 나무와 건물을 피해 걸어가고, 몬스터를 클릭하면
/// 다가가 벤다. 화면에서 나는 모든 소리는 [GameAudio] 가 실행 중에 합성한
/// 것이다 — 이 앱에는 오디오 파일이 한 장도 들어 있지 않다.
class GameMapScreen extends StatefulWidget {
  const GameMapScreen({super.key, required this.hero});

  final Artist hero;

  @override
  State<GameMapScreen> createState() => _GameMapScreenState();
}

class _GameMapScreenState extends State<GameMapScreen> {
  late final FieldGame _game = FieldGame(hero: widget.hero)
    ..audio.onReady = _onAudioReady;

  void _onAudioReady() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    // 플레이어를 놓아 주지 않으면 화면을 몇 번 드나든 뒤 오디오 채널이 마른다.
    unawaited(_game.audio.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final audio = _game.audio;
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
                  label: context.t.backToRoster,
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
                      // 소리는 실행 중에 굽는다. 그동안 조용한 것이 고장이
                      // 아님을 알려 준다.
                      audio.ready
                          ? context.t.mapHint(monsters.length)
                          : context.t.bakingSound,
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
                for (var i = 0; i < 4; i++)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: _Chip(
                      label: context.t.lightPreset(i),
                      on: _game.preset == i,
                      onTap: () => setState(() => _game.setPreset(i)),
                    ),
                  ),
                const Padding(
                  padding: EdgeInsets.only(left: 14),
                  child: LangToggle(),
                ),
              ],
            ),
          ),

          // ── 하단: 전투와 맵 조작 ───────────────────────────────────────
          //
          // 소리를 부르는 동작(공격·방어·달리기)을 손이 닿는 곳에 둔다.
          // 그러지 않으면 만들어 둔 소리의 절반은 아무도 듣지 못한다.
          Positioned(
            left: 0,
            right: 0,
            bottom: 20,
            child: Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 8,
                children: [
                  _Chip(
                    label: context.t.attack,
                    on: false,
                    onTap: _game.strikeNearest,
                  ),
                  _Chip(
                    label: context.t.guard,
                    on: _game.guarding,
                    onTap: () => setState(_game.toggleGuard),
                  ),
                  _Chip(
                    label: context.t.sprint,
                    on: _game.sprinting,
                    onTap: () => setState(_game.toggleSprint),
                  ),
                  _Chip(
                    label: audio.muted ? context.t.mute : context.t.soundOn,
                    on: !audio.muted,
                    onTap: () => setState(_game.toggleMute),
                  ),
                  _Chip(
                    label: context.t.regenerateMap,
                    on: false,
                    onTap: () => setState(_game.regenerate),
                  ),
                  _Chip(
                    label:
                        _game.showGrid ? context.t.hideGrid : context.t.showGrid,
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

  static const int cols = kVillageCols;
  static const int rows = kVillageRows;
  static const IsoView iso = IsoView(tileWidth: 150, tileHeight: 75);

  /// 이 맵의 자. 기물과 캐릭터가 **같은 자**를 쓴다는 사실이 여기서 시작한다.
  static const WorldScale scale = WorldScale(iso: iso);

  /// 영웅의 칼이 닿는 거리(m). 타일 = m 이므로 그대로 타일 거리다.
  static const double _reach = 1.7;

  /// 몬스터의 사정거리. 영웅보다 조금 짧아야 먼저 칠 여지가 생긴다.
  static const double _mobReach = 1.5;

  int preset = 1;
  int mapSeed = 20260806;

  /// 소리 담당. 합성·굽기·재생을 전부 맡는다.
  final GameAudio audio = GameAudio(seed: 20260806);

  /// 달리는 중인가. 걷기와 달리기는 **다른 발소리**를 쓴다.
  bool sprinting = false;

  /// 방패를 들고 있는가.
  bool guarding = false;

  bool get showGrid => _scene.showGrid;

  late final IsoSceneComponent _scene = IsoSceneComponent(
    iso: iso,
    grid: IsoGrid(cols: cols, rows: rows),
    light: LightRig.preset(1),
  )..marker = MoveMarker();

  late IsoController _heroCtrl;
  late RiggedIsoActor _heroActor;

  /// 주인공과 몬스터가 실제로 세워졌는가.
  ///
  /// 카메라·입력·프레임 갱신이 전부 `_heroCtrl` 을 딛고 서 있으므로, 맵이
  /// 서기 전에 그 문들이 열리면 안 된다.
  bool _spawned = false;

  /// 몬스터와 각자의 배회 컨트롤러, 그리고 다음 목적지까지 남은 시간.
  ///
  /// 프레임마다 주사위를 굴리면 배회 빈도가 프레임률에 비례한다 — 120fps
  /// 기기에서 몬스터가 두 배로 부산해진다. 초 단위 타이머로 재야 어디서나
  /// 같은 리듬으로 움직인다.
  final List<_Mob> _mobs = [];

  /// 영웅이 노리는 상대. 사정거리에 들어가면 벤다.
  _Mob? _target;

  double _heroCooldown = 0;

  /// 흔들리기 전의 카메라 원점. 흔들림은 **여기로 정확히 돌아와야** 한다.
  Offset _cameraBase = Offset.zero;

  /// 화면 흔들림의 남은 진폭(px).
  double _shake = 0;

  /// 타일별 바닥. 발소리를 고르는 데 쓴다.
  late List<StepGround> _ground;

  /// 시간이 지나 실행할 일들. 스윙 소리를 예비동작이 끝나는 지점에 맞춰
  /// 트는 데 쓴다.
  final List<_Delayed> _pending = [];

  final Rng _dice = Rng(0xC0FFEE);

  @override
  Color backgroundColor() => const Color(0xFF090D18);

  /// 이번 맵의 배치도 — 건물 위치와 등장 지점.
  late VillageLayout _layout;

  @override
  Future<void> onLoad() async {
    _buildMap();
    _snapCamera(size.toSize());
    await add(_scene);
    // 굽기는 격리 스레드에서 돈다. 기다리지 않으므로 게임은 즉시 시작하고,
    // 소리는 준비되는 대로 붙는다.
    unawaited(audio.warmUp(_bakeOrder()));
    unawaited(audio.setMood(Mood.values[preset]));
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _snapCamera(size.toSize());
  }

  /// 카메라가 따라갈 목표 위치.
  ///
  /// 맵이 화면보다 훨씬 커졌으므로(40×34 m ≈ 5,550 px 폭) 전체를 한 화면에
  /// 담는 [isoCameraOffset] 은 더 이상 쓸 수 없다. 전체를 담으려 줌을 빼면
  /// 사람이 다시 점이 되어, 비율을 고친 의미가 사라진다.
  Offset _wantCamera(Size view) => followCamera(
        iso: iso,
        focusTile: _heroCtrl.tile,
        view: view,
        cols: cols,
        rows: rows,
        // 2층집 + 지붕이 8 m 를 넘는다. 머리 위 여유가 없으면 지붕이 잘린다.
        headroom: scale.px(9.0) * iso.squash,
      );

  /// 보간 없이 즉시 맞춘다. 시작 직후와 창 크기 변경에만 쓴다.
  ///
  /// Flame 은 첫 레이아웃에서 [onLoad] 보다 **먼저** [onGameResize] 를 부른다.
  /// 그때는 아직 주인공이 없으므로 [_wantCamera] 가 `_heroCtrl` 을 읽는 순간
  /// LateInitializationError 가 레이아웃 콜백 안에서 터진다 — 예외가 레이아웃을
  /// 통째로 무너뜨려 맵이 한 픽셀도 그려지지 않고 HUD 만 남는다. 물러나면
  /// [onLoad] 가 맵을 세운 직후 곧바로 다시 맞춘다.
  void _snapCamera(Size view) {
    if (!_spawned) return;
    _cameraBase = _wantCamera(view);
    _scene.cameraOffset = _cameraBase;
    // 화면 밖 기물은 그리지 않는다. 맵이 40×34 m(화면상 5,550 px)가 되면서
    // 어느 순간에도 기물의 절반 이상이 화면 밖에 있다 — 그것을 그리는 비용은
    // 전부 버려진다. 컬링 창은 흔들림·따라가기 여유까지 한 타일 더 준다.
    _scene.cullToViewport = true;
    _scene.viewport = Rect.fromLTWH(0, 0, view.width, view.height)
        .inflate(iso.tileWidth);
  }

  void setPreset(int i) {
    preset = i;
    _scene.light = LightRig.preset(i);
    // 빛과 소리는 같은 시각을 말해야 한다. 정오의 화면에 달빛의 음악이
    // 깔리면 둘 다 거짓말이 된다.
    unawaited(audio.setMood(Mood.values[i]));
  }

  void toggleGrid() => _scene.showGrid = !_scene.showGrid;

  void toggleSprint() {
    sprinting = !sprinting;
    audio.play(SfxKeys.uiClick, volume: 0.5);
  }

  void toggleGuard() {
    // HUD 는 GameWidget 바깥의 Flutter 위젯이라 맵이 서기 전에도 눌린다.
    if (!_spawned) return;
    guarding = !guarding;
    if (guarding) {
      _heroCtrl.stop();
      audio.play(SfxKeys.guardUp, volume: 0.8);
    } else {
      audio.play(SfxKeys.uiClick, volume: 0.5);
    }
  }

  void toggleMute() => unawaited(audio.setMuted(!audio.muted));

  void regenerate() {
    mapSeed = mapSeed * 31 + 17;
    _buildMap();
  }

  void _buildMap() {
    _scene.props.clear();
    _scene.grid?.clear();
    _scene.rigged.clear();
    _mobs.clear();
    _pending.clear();
    _target = null;
    _scene.groundSeed = mapSeed;
    // 구워 둔 기물 텍스처를 놓아 준다. 이걸 빠뜨리면 맵을 다시 생성할 때마다
    // 못 쓰는 GPU 텍스처가 캐시 상한(160장)까지 쌓인다 — 새 기물은 새
    // 인스턴스라 옛 항목에 다시 닿을 일이 없기 때문이다.
    _scene.invalidateProps();

    // 맵 생성은 `world/village.dart` 에 있다. 게임과 테스트가 **같은 함수**를
    // 써야 "문 앞까지 걸어갈 수 있는가" 를 테스트가 검사할 수 있다.
    _layout = buildVillage(
      scene: _scene,
      seed: mapSeed,
      scale: scale,
      cols: cols,
      rows: rows,
      mobCount: monsters.length,
    );
    _bakeGroundMap();
    _spawnActors();
  }

  // ── 바닥 ──────────────────────────────────────────────────────────────

  /// 놓인 기물에서 타일별 바닥을 읽어 둔다.
  ///
  /// 좌표를 여기에 다시 적으면 마을 배치가 바뀔 때마다 조용히 어긋난다.
  /// **씬에 실제로 들어간 기물을 훑는 편이** 배치도와 절대 갈라서지 않는다.
  void _bakeGroundMap() {
    _ground = List<StepGround>.filled(cols * rows, StepGround.grass);

    // 길 — 마을의 뼈대이므로 먼저 깐다.
    final roadY = rows / 2;
    for (var y = 0; y < rows; y++) {
      if ((y + 0.5 - roadY).abs() >= kRoadWidthM * 0.5 + 0.4) continue;
      for (var x = 0; x < cols; x++) {
        _ground[y * cols + x] = StepGround.dirt;
      }
    }

    void stamp(Offset tile, double radiusPx, StepGround g) {
      final r = radiusPx / scale.pxPerTile;
      final rr = r.ceil();
      final cx = tile.dx, cy = tile.dy;
      for (var dy = -rr; dy <= rr; dy++) {
        for (var dx = -rr; dx <= rr; dx++) {
          final x = (cx + dx).floor();
          final y = (cy + dy).floor();
          if (x < 0 || y < 0 || x >= cols || y >= rows) continue;
          if ((Offset(x + 0.5, y + 0.5) - tile).distance > r) continue;
          _ground[y * cols + x] = g;
        }
      }
    }

    for (final p in _scene.props) {
      final prop = p.prop;
      if (prop is PebbleField) stamp(p.tile, prop.radius, StepGround.stone);
    }
    // 물은 마지막이다 — 자갈밭과 겹치면 물이 이긴다.
    for (final p in _scene.props) {
      final prop = p.prop;
      if (prop is WaterProp) stamp(p.tile, prop.radius * 0.9, StepGround.water);
    }
  }

  /// 이 타일의 바닥. 발소리의 정체는 신발이 아니라 바닥이 만든다.
  StepGround _groundAt(Offset tile) {
    final x = tile.dx.floor();
    final y = tile.dy.floor();
    if (x < 0 || y < 0 || x >= cols || y >= rows) return StepGround.grass;
    return _ground[y * cols + x];
  }

  // ── 등장 인물 ─────────────────────────────────────────────────────────
  //
  // 선택한 캐릭터 하나와 **명부의 모든 몬스터가 한 마리씩** 나온다. 전부
  // RiggedIsoActor 이므로 걸을 때 다리가 교차하고 방향에 따라 몸이 돈다.
  void _spawnActors() {
    final start = _layout.heroSpawn;
    // 속도는 타일/초 = m/s 다. 3.2 m/s 는 가벼운 구보 — 타일이 1 m 가 되면서
    // 이 숫자가 비로소 현실의 단위를 갖게 됐다. 값 자체는 건드리지 않는다.
    _heroCtrl = IsoController(tile: start, grid: _scene.grid, speed: 3.2);
    // iso 를 넘겨야 보폭이 이 맵의 타일 크기에 맞는다 — 빠뜨리면 기본 타일
    // 크기로 계산해 걸음 수와 이동 거리가 어긋난다.
    _heroActor = riggedFromArtist(
      hero,
      tile: start,
      height: scale.humanPx,
      iso: iso,
    );
    _scene.rigged.add(_heroActor);
    // 주인공이 건물 뒤로 들어가면 그 건물이 흐려진다. 8 m 짜리 벽이 1.8 m
    // 짜리 사람을 통째로 덮으므로, 이게 없으면 주인공을 잃어버린다.
    _scene.occlusionFocus = _heroActor;

    // 몬스터는 마을 곳곳에 흩어 놓고 각자 배회시킨다.
    final r = Rng(mapSeed ^ 0x5A17);
    for (final (i, m) in monsters.indexed) {
      final tile = _layout.mobSpawns[i % _layout.mobSpawns.length];
      // 몹은 사람보다 크되 종마다 다르다. 2.0~2.3 m 대역.
      final actor = riggedFromArtist(
        m,
        tile: tile,
        height: scale.px(2.0 + (i % 3) * 0.15),
        iso: iso,
      );
      final ctrl = IsoController(
        tile: tile,
        grid: _scene.grid,
        speed: 1.2 + i * 0.28,
      );
      _scene.rigged.add(actor);
      _mobs.add(_Mob(
        artist: m,
        actor: actor,
        ctrl: ctrl,
        rest: r.range(0.5, 4.0),
        mutter: r.range(3.0, 12.0),
        home: tile,
      ));
    }
    _spawned = true;
  }

  // ── 소리 주문 ─────────────────────────────────────────────────────────

  /// 이 맵이 실제로 쓰는 소리만 주문한다.
  ///
  /// 표준 창고를 통째로 구우면 쓰지도 않는 무기의 휘두르기까지 만든다.
  /// 맵이 아는 것만 굽는 편이 로딩이 몇 배 빠르다.
  BakeOrder _bakeOrder() {
    final weapons = <int>{_heroWeapon.index};
    final voices = <VoiceSpec>[VoiceSpec.of(hero)];
    for (final mob in _mobs) {
      weapons.add(mob.weapon.index);
      voices.add(VoiceSpec.of(mob.artist, kind: _voiceKindFor(mob.artist)));
    }
    return BakeOrder(
      seed: mapSeed,
      grounds: StepGround.values.map((g) => g.index).toList(),
      weapons: weapons.toList(),
      voices: voices,
    );
  }

  /// 이름 있는 몬스터의 목은 손으로 정한다.
  ///
  /// 자동 추정은 직업과 몸집만 보므로 "천 개의 목소리로 애도하는" 므오른과
  /// "여덟 개의 눈을 가진" 키티니스를 구분하지 못한다. 실루엣이 눈에 정체를
  /// 말하듯, 목소리는 **화면 밖에서** 정체를 말해야 한다.
  VoiceKind? _voiceKindFor(Artist a) => switch (a.id) {
        'gorehide' => VoiceKind.growl, // 고산의 식인귀 — 낮게 깔린다
        'vaelmorth' => VoiceKind.roar, // 잿불의 비룡 — 터진다
        'mourne' => VoiceKind.wail, // 형체 없는 장례의 주인 — 코러스
        'chitinis' => VoiceKind.chitter, // 갑각 포식자 — 딱딱거린다
        _ => null,
      };

  WeaponKind get _heroWeapon => _heroActor.renderer.spec.weapon;

  // ── 입력 ──────────────────────────────────────────────────────────────

  @override
  void onTapDown(TapDownEvent event) {
    if (!_spawned) return;
    // 흔들리는 중에도 클릭은 정확해야 한다. 피킹은 흔들리기 전 원점으로 푼다.
    final target =
        screenToTile(event.localPosition.toOffset(), iso, _cameraBase);

    final mob = _mobAt(target);
    if (mob != null) {
      _target = mob;
      if ((mob.actor.tile - _heroActor.tile).distance <= _reach) {
        _beginHeroAttack();
      } else {
        _heroCtrl.moveTo(mob.actor.tile);
        _scene.marker?.ping(mob.actor.tile);
      }
      return;
    }

    _target = null;
    _heroCtrl.moveTo(target);
    _scene.marker?.ping(target);
    audio.play(SfxKeys.moveMark, volume: 0.45);
  }

  _Mob? _mobAt(Offset tile) {
    _Mob? best;
    var bestD = 1.2; // 클릭 판정 반경(m)
    for (final mob in _mobs) {
      if (!mob.alive) continue;
      final d = (mob.actor.tile - tile).distance;
      if (d < bestD) {
        bestD = d;
        best = mob;
      }
    }
    return best;
  }

  /// 가장 가까운 산 몬스터를 벤다. 버튼이 부르는 입구다.
  void strikeNearest() {
    if (!_spawned) return;
    _Mob? best;
    var bestD = double.infinity;
    for (final mob in _mobs) {
      if (!mob.alive) continue;
      final d = (mob.actor.tile - _heroActor.tile).distance;
      if (d < bestD) {
        bestD = d;
        best = mob;
      }
    }
    // 사정거리 밖이면 노리기만 하고 헛스윙한다 — 휘둘렀다는 사실은 들려야 한다.
    _target = bestD <= _reach * 4 ? best : null;
    _beginHeroAttack();
  }

  // ── 프레임 ────────────────────────────────────────────────────────────

  @override
  void update(double dt) {
    // 씬이 먼저 돈다 — 여기서 액터의 시간이 진행되고 클립 이벤트가 채워진다.
    super.update(dt);
    if (!_spawned) return;

    _runPending(dt);
    _updateHero(dt);
    _updateMobs(dt);
    _updateCamera(dt);
  }

  void _updateHero(double dt) {
    _heroCooldown = math.max(0, _heroCooldown - dt);
    _heroCtrl.speed = sprinting ? 6.4 : 3.2;

    // 노린 상대가 사정거리에 들어오면 벤다.
    final target = _target;
    if (target != null && target.alive && !_heroBusy) {
      final d = (target.actor.tile - _heroActor.tile).distance;
      if (d <= _reach) {
        _heroCtrl.stop();
        _beginHeroAttack();
      } else if (!_heroCtrl.isMoving) {
        _heroCtrl.moveTo(target.actor.tile);
      }
    }

    _heroCtrl.update(dt);

    // 방어 자세는 follow 에 맡길 수 없다. follow 는 멈춰 있으면 무조건 idle
    // 로 되돌리므로, 매 프레임 wait 을 다시 걸면 클립이 t=0 에서 영원히 다시
    // 시작한다. 서 있는 동안만 follow 를 비켜 간다.
    if (guarding && !_heroCtrl.isMoving && !_heroBusy) {
      _heroActor
        ..tile = _heroCtrl.tile
        ..yaw = _heroCtrl.yaw
        ..animator.rate = 1.0;
      if (_heroActor.state != 'wait') _heroActor.play('wait');
    } else {
      // follow 가 위치·방향·클립(대기/걷기/달리기)과 보폭을 한 번에 맞춘다.
      // 시간은 씬이 이미 진행시켰으므로 여기서 또 밀지 않는다.
      _heroActor.follow(_heroCtrl, dt);
    }

    // 공격 중에는 상대를 향해 돈다. follow 가 yaw 를 덮으므로 **뒤에서** 건다.
    if (_heroBusy && target != null && target.alive) {
      final want = yawFromVelocity(target.actor.tile - _heroActor.tile);
      _heroActor.yaw =
          lerpAngle(_heroActor.yaw, want, 1 - math.exp(-dt / 0.08));
    }

    _consumeEvents(_heroActor, isHero: true);
  }

  bool get _heroBusy =>
      _heroActor.state == 'attack' || _heroActor.state == 'shoot';

  void _beginHeroAttack() {
    if (_heroBusy || _heroCooldown > 0) return;
    _heroCtrl.stop();
    _heroCooldown = 0.42;

    final ranged = _heroWeapon == WeaponKind.bow;
    _heroActor.ranged = ranged;
    _heroActor.play(ranged ? 'shoot' : 'attack');
    if (ranged) return; // 활은 release 이벤트가 시위 소리를 낸다

    // 스윙 소리의 봉우리는 파형의 60% 지점에 있다. 그 봉우리가 클립의 strike
    // 이벤트(t=0.5)에 떨어지도록 앞당겨 예약한다 — 소리와 그림이 어긋나는
    // 순간 두 배로 싸구려가 된다.
    final lead = Anims.attack.duration * 0.5 - 0.21;
    _after(math.max(0, lead), () {
      audio.play(SfxKeys.swing(_heroWeapon),
          volume: 0.9, pan: _panOf(_heroActor.tile));
    });
  }

  /// 영웅의 칼이 닿는 순간. `strike` 이벤트가 부른다.
  void _resolveHeroStrike() {
    var landed = false;
    for (final mob in _mobs) {
      if (!mob.alive) continue;
      final delta = mob.actor.tile - _heroActor.tile;
      if (delta.distance > _reach + 0.4) continue;
      // 부채꼴 판정 — 등 뒤의 적이 맞으면 방향을 맞춘 의미가 없다.
      if (_angleBetween(_heroActor.yaw, yawFromVelocity(delta)) > 1.0) continue;
      _hurt(mob);
      landed = true;
    }
    // 빗나가면 바람 소리만 남는다. 이 차이가 맞았는지 아닌지를 말해 준다.
    if (landed) _shake = math.max(_shake, 3.4);
  }

  void _hurt(_Mob mob) {
    mob.hp -= 1;
    final pan = _panOf(mob.actor.tile);
    final vol = _volumeAt(mob.actor.tile);
    final armored = mob.actor.renderer.spec.armorHeaviness > 0.55;
    audio.play(armored ? SfxKeys.impactArmor : SfxKeys.impactFlesh,
        volume: vol, pan: pan);

    // 히트스톱 — 타격감의 상당 부분이 이 0.06초에서 나온다.
    _heroActor.animator.hitstop(0.06);
    mob.actor.animator.hitstop(0.06);

    if (mob.hp <= 0) {
      mob.alive = false;
      mob.ctrl.stop();
      // death 는 원샷 목록에 없으므로 follow 가 덮어쓴다. 죽은 몬스터는
      // 아래 갱신 루프에서 통째로 건너뛰므로 마지막 포즈가 유지된다.
      mob.actor.play('death');
      audio.play(VoiceKeys.die(mob.artist.id), volume: vol, pan: pan);
      if (identical(_target, mob)) _target = null;
    } else {
      mob.actor.play('hit');
      audio.play(VoiceKeys.hurt(mob.artist.id), volume: vol * 0.9, pan: pan);
    }
  }

  void _updateMobs(double dt) {
    for (final mob in _mobs) {
      if (!mob.alive) {
        // 죽은 뒤에도 이벤트는 읽는다 — 쓰러지는 소리가 여기서 난다.
        _consumeEvents(mob.actor);
        continue;
      }

      final delta = _heroActor.tile - mob.actor.tile;
      final d = delta.distance;
      final busy = mob.actor.state == 'attack';

      // 발견과 망각. 문턱을 벌려 두지 않으면 경계에서 계속 짖는다.
      if (!mob.alerted && d < 5.5) {
        mob.alerted = true;
        audio.play(VoiceKeys.alert(mob.artist.id),
            volume: _volumeAt(mob.actor.tile), pan: _panOf(mob.actor.tile));
      } else if (mob.alerted && d > 9.0) {
        mob.alerted = false;
      }

      mob.cooldown = math.max(0, mob.cooldown - dt);
      mob.mutter -= dt;

      if (mob.alerted) {
        if (d <= _mobReach && mob.cooldown <= 0 && !busy) {
          mob.ctrl.stop();
          mob.actor.play('attack');
          mob.cooldown = _dice.range(1.7, 3.2);
          audio.play(VoiceKeys.attack(mob.artist.id),
              volume: _volumeAt(mob.actor.tile), pan: _panOf(mob.actor.tile));
          final lead = Anims.attack.duration * 0.5 - 0.21;
          _after(math.max(0, lead), () {
            audio.play(SfxKeys.swing(mob.weapon),
                volume: _volumeAt(mob.actor.tile) * 0.85,
                pan: _panOf(mob.actor.tile));
          });
        } else if (d > _mobReach && !busy && !mob.ctrl.isMoving) {
          mob.ctrl.moveTo(_heroActor.tile);
        }
      } else if (!mob.ctrl.isMoving && !busy) {
        // 배회. 쉬는 시간이 다 되면 제 자리 주변에서 새 목적지를 고른다.
        mob.rest -= dt;
        if (mob.rest <= 0) {
          // 제 자리에서 6 m 안. 맵 전체를 목적지로 삼으면 배회가 이주가 된다.
          mob.ctrl.moveTo(Offset(
            (mob.home.dx + _dice.signed(6)).clamp(0.5, cols - 0.5),
            (mob.home.dy + _dice.signed(6)).clamp(0.5, rows - 0.5),
          ));
          mob.rest = _dice.range(1.5, 6.0);
        }
      }

      // 이따금 흘리는 소리. 이것이 없으면 맵이 표본실처럼 조용하다.
      if (mob.mutter <= 0) {
        mob.mutter = _dice.range(7.0, 17.0);
        if (!busy) {
          audio.play(VoiceKeys.idle(mob.artist.id),
              volume: _volumeAt(mob.actor.tile) * 0.55,
              pan: _panOf(mob.actor.tile));
        }
      }

      mob.ctrl.update(dt);
      mob.actor.follow(mob.ctrl, dt);
      if (busy) {
        mob.actor.yaw = lerpAngle(
            mob.actor.yaw, yawFromVelocity(delta), 1 - math.exp(-dt / 0.08));
      }
      _consumeEvents(mob.actor, mob: mob);
    }
  }

  /// 몬스터의 무기가 닿는 순간. 여기서 **방어의 성패가 갈린다.**
  void _resolveMobStrike(_Mob mob) {
    final delta = _heroActor.tile - mob.actor.tile;
    if (delta.distance > _mobReach + 0.5) return; // 영웅이 빠져나갔다

    final pan = _panOf(_heroActor.tile);
    // 등 뒤에서 맞는 것은 막지 못한다. 방패는 보고 있는 쪽만 가린다.
    final facing =
        _angleBetween(_heroActor.yaw, yawFromVelocity(-delta)) < 1.15;

    if (guarding && facing) {
      // 방어가 성공했다는 사실은 **소리로만** 전달된다. 공격 애니메이션은
      // 그대로 나오고 피격 모션만 없을 뿐이라, 이 소리가 없으면 플레이어는
      // 막았는지 빗나갔는지 구분하지 못한다.
      audio.play(SfxKeys.blockMetal, volume: 0.95, pan: pan);
      _heroActor.animator.hitstop(0.05);
      _shake = math.max(_shake, 2.2);
    } else {
      audio.play(SfxKeys.impactFlesh, volume: 0.95, pan: pan);
      audio.play(VoiceKeys.hurt(hero.id), volume: 0.8, pan: pan);
      _heroActor.play('hit');
      _heroActor.animator.hitstop(0.06);
      _shake = math.max(_shake, 4.2);
    }
  }

  /// 클립이 알려 온 시점들을 소리로 바꾼다.
  ///
  /// **프레임 수를 세지 않는다.** 클립 위의 정규화 시각에 찍힌 표식이므로,
  /// 보폭 동기화로 재생 배속이 바뀌어도 발이 땅에 닿는 그 프레임에 소리가
  /// 난다. 타이머로 흉내내면 반드시 어긋난다.
  void _consumeEvents(
    RiggedIsoActor actor, {
    bool isHero = false,
    _Mob? mob,
  }) {
    final fired = actor.animator.fired;
    if (fired.isEmpty) return;
    for (final e in fired) {
      switch (e) {
        case 'footfall':
          final running = actor.state == 'run' || actor.state == 'dash';
          audio.play(
            SfxKeys.step(_groundAt(actor.tile), running: running),
            volume: (isHero ? 0.85 : 0.6) * _volumeAt(actor.tile),
            pan: _panOf(actor.tile),
          );
        case 'strike':
          if (isHero) {
            _resolveHeroStrike();
          } else if (mob != null) {
            _resolveMobStrike(mob);
          }
        case 'release':
          audio.play(SfxKeys.bowShot, volume: 0.9, pan: _panOf(actor.tile));
          if (isHero) _resolveHeroStrike();
        case 'collapse':
          audio.play(SfxKeys.bodyFall,
              volume: _volumeAt(actor.tile), pan: _panOf(actor.tile));
      }
    }
  }

  // ── 소리의 자리 ───────────────────────────────────────────────────────

  /// 영웅에게서 멀어질수록 작아진다. 거리는 m 다.
  double _volumeAt(Offset tile) {
    final d = (tile - _heroActor.tile).distance;
    return (1.0 / (1.0 + d * d * 0.03)).clamp(0.0, 1.0);
  }

  /// 화면 가로 위치를 좌우 균형으로. 등 뒤에서 다가오는 것을 귀로 알아챈다.
  double _panOf(Offset tile) {
    final w = size.x;
    if (w <= 1) return 0;
    final x = iso.project(tile.dx, tile.dy).dx + _cameraBase.dx;
    return (((x / w) * 2 - 1) * 0.75).clamp(-1.0, 1.0);
  }

  /// 두 각도 사이의 최소 차(0..π).
  static double _angleBetween(double a, double b) {
    var d = (a - b) % (math.pi * 2);
    if (d > math.pi) d -= math.pi * 2;
    if (d < -math.pi) d += math.pi * 2;
    return d.abs();
  }

  // ── 카메라와 예약 ─────────────────────────────────────────────────────

  /// 카메라가 주인공을 따라가고, 타격이 화면을 흔든다.
  ///
  /// 흔들림은 따라가기 **위에** 얹는다. 흔들림을 `cameraOffset` 에 직접
  /// 누적하면 감쇠가 끝난 뒤 원점이 조금씩 밀려 화면이 서서히 어긋난다.
  void _updateCamera(double dt) {
    _cameraBase = easeCamera(_cameraBase, _wantCamera(size.toSize()), dt);
    if (_shake <= 0.02) {
      _shake = 0;
      _scene.cameraOffset = _cameraBase;
      return;
    }
    _shake *= math.exp(-dt / 0.085);
    final t = _scene.clock;
    _scene.cameraOffset = _cameraBase +
        Offset(math.sin(t * 97) * _shake, math.cos(t * 83) * _shake * 0.55);
  }

  /// [seconds] 뒤에 [fn] 을 부른다.
  ///
  /// 프레임으로 재므로 히트스톱과 일시정지를 함께 탄다 — `Future.delayed` 로
  /// 하면 화면이 멈춘 동안에도 소리만 혼자 흘러간다.
  void _after(double seconds, VoidCallback fn) {
    if (seconds <= 0) {
      fn();
      return;
    }
    _pending.add(_Delayed(seconds, fn));
  }

  void _runPending(double dt) {
    if (_pending.isEmpty) return;
    for (var i = _pending.length - 1; i >= 0; i--) {
      final p = _pending[i];
      p.left -= dt;
      if (p.left <= 0) {
        _pending.removeAt(i);
        p.fn();
      }
    }
  }
}

/// 맵 위의 몬스터 한 마리.
class _Mob {
  _Mob({
    required this.artist,
    required this.actor,
    required this.ctrl,
    required this.rest,
    required this.mutter,
    required this.home,
  });

  /// 명부의 원본. 목소리의 이름표가 여기서 나온다.
  final Artist artist;

  final RiggedIsoActor actor;
  final IsoController ctrl;

  /// 다음 목적지를 고르기까지 남은 시간(초).
  double rest;

  /// 다음 혼잣소리까지 남은 시간(초).
  double mutter;

  /// 다음 공격까지 남은 시간(초).
  double cooldown = 0;

  /// 영웅을 발견했는가.
  bool alerted = false;

  int hp = 3;
  bool alive = true;

  WeaponKind get weapon => actor.renderer.spec.weapon;

  /// 처음 나타난 자리. 배회는 이 주변으로 묶는다.
  ///
  /// 맵이 15 m 에서 40 m 로 커지면서, 맵 전체를 목적지로 삼으면 몬스터가
  /// 30 m 씩 행군해 마을을 가로지른다 — 배회가 아니라 이주다. 게다가 A* 가
  /// 매번 긴 경로를 풀어 프레임을 먹는다.
  final Offset home;
}

/// 몇 초 뒤에 할 일 하나.
class _Delayed {
  _Delayed(this.left, this.fn);
  double left;
  final VoidCallback fn;
}
