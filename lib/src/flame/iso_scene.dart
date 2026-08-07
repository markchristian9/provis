import 'dart:math' as math;
import 'dart:ui' hide Clip;

import 'package:flame/components.dart' hide mix;

import '../anim/clip.dart' show kMaxFrameStep;
import '../core/shading.dart';
import '../iso/iso_input.dart';
import '../iso/iso_stage.dart';
import '../iso/iso_view.dart';
import '../props/prop.dart';
import 'scene_profile.dart';

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
  final sw = SceneProfile.enabled ? (Stopwatch()..start()) : null;
  for (final it in sorted) {
    final t0 = sw?.elapsedMicroseconds ?? 0;
    switch (it) {
      case PropItem(:final instance):
        paintProp(canvas, instance, iso, light, time, detail: detail);
      case ActorItem(:final actor):
        paintIsoActor(canvas, actor, iso, time, detail: detail);
      case RiggedItem(:final actor):
        paintRiggedActor(canvas, actor, iso, light, time, detail: detail);
    }
    if (sw != null) {
      final key = switch (it) {
        PropItem(:final instance) => instance.prop.runtimeType.toString(),
        ActorItem() => 'IsoActor',
        RiggedItem() => 'RiggedActor',
      };
      SceneProfile.add(key, sw.elapsedMicroseconds - t0);
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

  /// 지면 얼룩의 시드. 맵을 다시 생성할 때 함께 바꾸면 땅도 새로 깔린다.
  int groundSeed = 7;

  final List<PropInstance> props = [];

  /// 수작업 캐릭터 — 고정 3/4 초상. 연출·전시용.
  final List<IsoActor> actors = [];

  /// 골격 구동 캐릭터 — 8방향 회전과 보행 애니메이션. 게임플레이용.
  final List<RiggedIsoActor> rigged = [];

  /// 클릭 표식. `null` 이면 그리지 않는다.
  MoveMarker? marker;

  /// 씬 원점(카메라). 화면 좌표 ↔ 타일 변환에도 **같은 값**을 써야 한다.
  Offset cameraOffset = Offset.zero;

  /// 카메라가 따라갈 목표 원점. `null` 이면 [cameraOffset] 을 직접 쓴다.
  ///
  /// 매 프레임 목표만 갱신하면 [cameraLag] 에 걸쳐 부드럽게 따라붙는다.
  Offset? cameraTarget;

  /// 카메라가 목표를 따라잡는 데 걸리는 시간(초). 0 이면 즉시 붙는다.
  ///
  /// 지수 감쇠라 프레임률이 흔들려도 같은 속도로 붙는다. **0.2 를 넘기지
  /// 않는다** — 그 이상이면 캐릭터가 화면 가장자리로 밀려 조작이 늦게
  /// 반응하는 것처럼 느껴진다. 입력은 어차피 [tileAt] 이 현재 오프셋으로
  /// 풀기 때문에 클릭 지점은 언제나 정확하다.
  double cameraLag = 0.15;

  /// 화면 밖 기물을 건너뛴다.
  ///
  /// ## 왜 필요해졌는가
  ///
  /// 맵이 15×15 타일이던 시절에는 전체가 한 화면에 들어와 컬링할 것이 없었다.
  /// 기물이 제 크기를 찾으면서 맵은 40×34 m 가 되었고, 화면상 폭은 5,550 px —
  /// 1600×900 창에 들어오는 것은 그중 일부다. 나머지를 그리는 비용은 전부
  /// 버려지는데, 기물 한 개는 `paintSurface` 안에서 `saveLayer` 와 블러를
  /// 여러 번 태우므로 **버려지는 비용이 프레임 예산을 통째로 먹는다.**
  ///
  /// [viewport] 가 `null` 이면 아무것도 걸러내지 않는다.
  bool cullToViewport = false;

  /// 화면 사각형(씬을 그리는 캔버스의 좌표계). [cullToViewport] 가 쓴다.
  Rect? viewport;

  /// 이 기물이 화면에 걸치는가.
  ///
  /// 정확한 경계 대신 **넉넉한 상한**을 쓴다. 기물은 자기 폭을 알려 주지
  /// 않으므로 높이와 타일 폭으로 반경을 잡는다. 조금 더 그리는 것은 싸지만,
  /// 화면 안의 것을 빠뜨리면 기물이 깜빡이며 사라져 즉시 눈에 띈다.
  bool _onScreen(Offset tile, double height) {
    final v = viewport;
    if (v == null) return true;
    final a = iso.project(tile.dx, tile.dy) + cameraOffset;
    final pad = height * iso.squash + iso.tileWidth;
    return a.dx + pad >= v.left &&
        a.dx - pad <= v.right &&
        a.dy + iso.tileHeight >= v.top &&
        a.dy - pad <= v.bottom;
  }

  /// 지금 화면에 걸리는 기물 수. 컬링이 실제로 걸러내는지 확인하는 데 쓴다.
  int visiblePropCount() {
    if (!cullToViewport || viewport == null) return props.length;
    var n = 0;
    for (final it in props) {
      if (_onScreen(it.tile, it.prop.height * it.scale)) n++;
    }
    return n;
  }

  double _clock = 0;
  double get clock => _clock;

  /// 깊이 정렬 목록. `(리스트 안의 첨자 << 2) | 종류` 로 인코딩한다.
  ///
  /// 매 프레임 래퍼 객체를 새로 만들면 기물 100개짜리 씬에서 프레임마다
  /// 100번 이상 할당이 일어나 GC 가 주기적으로 프레임을 밀어낸다. 정수만
  /// 담으면 목록을 재사용할 수 있고, 첨자는 목록을 다시 채워도 유효하므로
  /// 낡은 참조가 남지 않는다.
  final List<int> _order = [];

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
    // 히치 한 번에 씬 전체가 건너뛰지 않도록, 액터·마커·카메라가 모두 같은
    // 상한을 쓴다. 서로 다른 dt 를 먹으면 그림자와 발이 어긋난다.
    if (dt > kMaxFrameStep) dt = kMaxFrameStep;

    _clock += dt;
    marker?.update(dt);

    // 시간의 주인은 씬이다. 게임 코드가 같은 프레임에 `follow` 를 불러도
    // 여기서 이미 진행시켰다는 사실을 알고 시간은 건드리지 않는다.
    for (final a in rigged) {
      a.driveByScene(dt);
    }

    final target = cameraTarget;
    if (target != null) {
      cameraOffset = cameraLag <= 0
          ? target
          : Offset.lerp(cameraOffset, target, 1 - math.exp(-dt / cameraLag))!;
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.save();
    canvas.translate(cameraOffset.dx, cameraOffset.dy);

    // 지면은 언제나 그린다. [showGrid] 는 **격자선만** 껐다 켠다 — 격자는
    // 좌표를 확인하는 개발 도구이지 땅이 아니며, 그것을 껐다고 캐릭터가
    // 허공에 뜨면 안 된다.
    final g = grid;
    final gsw = SceneProfile.enabled ? (Stopwatch()..start()) : null;
    paintIsoGround(
      canvas,
      iso,
      g?.cols ?? 8,
      g?.rows ?? 8,
      light,
      lineAlpha: showGrid ? 0.10 : 0.0,
      seed: groundSeed,
    );
    if (gsw != null) SceneProfile.add('#ground', gsw.elapsedMicroseconds);
    marker?.paint(canvas, iso);
    _paintSorted(canvas);
    if (SceneProfile.enabled) SceneProfile.endFrame();

    canvas.restore();
  }

  /// 기물·액터를 하나의 깊이 순서로 그린다.
  ///
  /// [paintScene] 과 결과는 같지만 목록과 래퍼를 매 프레임 새로 만들지 않는다.
  /// 깊이는 액터가 움직이면 바뀌므로 정렬 자체는 매 프레임 해야 하지만,
  /// 거의 정렬된 목록이라 실제 비교 횟수는 적다.
  void _paintSorted(Canvas canvas) {
    final n = props.length + actors.length + rigged.length;
    if (_order.length != n) {
      _order.clear();
      for (var i = 0; i < props.length; i++) {
        _order.add(i << 2);
      }
      for (var i = 0; i < actors.length; i++) {
        _order.add((i << 2) | 1);
      }
      for (var i = 0; i < rigged.length; i++) {
        _order.add((i << 2) | 2);
      }
    }

    double depthOf(int k) => switch (k & 3) {
          0 => props[k >> 2].depth,
          1 => actors[k >> 2].depth,
          _ => rigged[k >> 2].depth,
        };

    _order.sort((a, b) => depthOf(a).compareTo(depthOf(b)));

    final cull = cullToViewport && viewport != null;
    // 종류별 실측. 이것 없이 최적화하면 안 아픈 곳을 수술한다.
    final sw = SceneProfile.enabled ? (Stopwatch()..start()) : null;
    for (final k in _order) {
      final i = k >> 2;
      final t0 = sw?.elapsedMicroseconds ?? 0;
      String? key;
      switch (k & 3) {
        case 0:
          final it = props[i];
          // 액터는 거르지 않는다. 수가 적어 이득이 없고, 화면 밖에 있어도
          // 애니메이션 상태는 계속 흘러야 하기 때문이다.
          if (cull && !_onScreen(it.tile, it.prop.height * it.scale)) continue;
          paintProp(canvas, it, iso, light, _clock);
          if (sw != null) key = it.prop.runtimeType.toString();
        case 1:
          paintIsoActor(canvas, actors[i], iso, _clock);
          if (sw != null) key = 'IsoActor';
        default:
          paintRiggedActor(canvas, rigged[i], iso, light, _clock);
          if (sw != null) key = 'RiggedActor';
      }
      if (sw != null && key != null) {
        SceneProfile.add(key, sw.elapsedMicroseconds - t0);
      }
    }
  }
}
