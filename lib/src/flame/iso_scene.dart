import 'dart:ui';

import 'package:flame/components.dart' hide mix;

import '../core/shading.dart';
import '../iso/iso_input.dart';
import '../iso/iso_stage.dart';
import '../iso/iso_view.dart';
import '../props/prop.dart';

/// 아이소 씬에 놓이는 모든 것의 공통 인터페이스.
///
/// 기물과 캐릭터를 따로 그리면 나무 뒤로 걸어 들어간 캐릭터가 나무 앞에
/// 나타난다. 아이소 씬에서 그리기 순서는 곧 앞뒤 관계이므로, 화면에 있는
/// **모든 것이 하나의 정렬을 거쳐야 한다.** 이 타입이 그 통로다.
sealed class SceneItem {
  double get depth;
}

/// 씬에 놓인 기물.
class PropItem extends SceneItem {
  PropItem(this.instance);
  final PropInstance instance;
  @override
  double get depth => instance.depth;
}

/// 씬에 놓인 수작업 캐릭터([Artist] 기반, 고정 3/4 초상).
class ActorItem extends SceneItem {
  ActorItem(this.actor);
  final IsoActor actor;
  @override
  double get depth => actor.depth;
}

/// 씬에 놓인 골격 구동 캐릭터 — 8방향 회전과 보행 애니메이션을 한다.
class RiggedItem extends SceneItem {
  RiggedItem(this.actor);
  final RiggedIsoActor actor;
  @override
  double get depth => actor.depth;
}

/// 기물과 캐릭터를 한 목록으로 묶어 깊이 순으로 그린다.
///
/// Flame 을 쓰지 않는 프로젝트에서도 이 함수만 따로 호출할 수 있다.
void paintScene(
  Canvas canvas,
  List<SceneItem> items,
  IsoView iso,
  LightRig light,
  double time, {
  double detail = 1.0,
}) {
  final sorted = [...items]..sort((a, b) => a.depth.compareTo(b.depth));
  for (final it in sorted) {
    switch (it) {
      case PropItem(:final instance):
        paintProp(canvas, instance, iso, light, time, detail: detail);
      case ActorItem(:final actor):
        paintIsoActor(canvas, actor, iso, time, detail: detail);
      case RiggedItem(:final actor):
        paintRiggedActor(canvas, actor, iso, light, time, detail: detail);
    }
  }
}

/// 지면·기물·캐릭터·마커를 한꺼번에 그리는 Flame 컴포넌트.
///
/// 게임 쪽에서는 [props]·[actors] 목록만 갱신하면 되고, 정렬·투영·조명은
/// 이 컴포넌트가 맡는다.
///
/// ```dart
/// class MyGame extends FlameGame {
///   final scene = IsoSceneComponent(
///     iso: const IsoView(tileWidth: 156, tileHeight: 78),
///     grid: IsoGrid(cols: 12, rows: 12),
///   );
///
///   @override
///   Future<void> onLoad() async => add(scene);
/// }
/// ```
class IsoSceneComponent extends Component {
  IsoSceneComponent({
    required this.iso,
    this.grid,
    LightRig? light,
    this.showGrid = true,
    this.haze = 0.45,
  }) : light = light ?? LightRig.daylight;

  IsoView iso;
  IsoGrid? grid;
  LightRig light;
  bool showGrid;

  /// 대기 원근 세기. 먼 곳이 환경광으로 흐려지면 평면에 깊이가 생긴다.
  double haze;

  final List<PropInstance> props = [];

  /// 수작업 캐릭터 — 고정 3/4 초상. 연출·전시용.
  final List<IsoActor> actors = [];

  /// 골격 구동 캐릭터 — 8방향 회전과 보행 애니메이션. 게임플레이용.
  final List<RiggedIsoActor> rigged = [];

  /// 클릭 표식. `null` 이면 그리지 않는다.
  MoveMarker? marker;

  /// 씬 원점(카메라). 화면 좌표 ↔ 타일 변환에도 **같은 값**을 써야 한다.
  Offset cameraOffset = Offset.zero;

  double _clock = 0;
  double get clock => _clock;

  /// 화면 좌표를 타일 좌표로 되돌린다. 탭 처리에서 그대로 쓴다.
  Offset tileAt(Offset screen) => screenToTile(screen, iso, cameraOffset);

  /// 기물을 놓으면서 통행 격자도 함께 막는다.
  ///
  /// 둘을 따로 관리하면 반드시 어긋난다 — 화면에는 나무가 있는데 캐릭터가
  /// 통과하거나, 아무것도 없는데 길이 막힌다.
  void addProp(PropInstance it) {
    props.add(it);
    if (!it.prop.walkable) {
      grid?.blockFootprint(it.tile, it.prop.footprint);
    }
  }

  void addProps(Iterable<PropInstance> items) => items.forEach(addProp);

  @override
  void update(double dt) {
    super.update(dt);
    _clock += dt;
    marker?.update(dt);
    for (final a in rigged) {
      a.update(dt);
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.save();
    canvas.translate(cameraOffset.dx, cameraOffset.dy);

    if (showGrid) {
      final g = grid;
      paintIsoGround(canvas, iso, g?.cols ?? 8, g?.rows ?? 8, light);
    }
    marker?.paint(canvas, iso);

    paintScene(
      canvas,
      [
        ...props.map(PropItem.new),
        ...actors.map(ActorItem.new),
        ...rigged.map(RiggedItem.new),
      ],
      iso,
      light,
      _clock,
    );

    canvas.restore();
  }
}
