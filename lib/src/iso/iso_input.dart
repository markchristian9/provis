import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui';

import 'iso_view.dart';

/// 화면 좌표를 월드 타일 좌표로 되돌린다.
///
/// 마우스·터치로 맵을 조작하는 모든 것의 출발점이다. [cameraOffset] 은 씬을
/// 그릴 때 `canvas.translate` 로 건 값과 **같은 값**이어야 한다 — 그리기와
/// 피킹이 서로 다른 원점을 쓰면 클릭한 곳과 캐릭터가 가는 곳이 어긋난다.
///
/// ```dart
/// void onTapDown(TapDownDetails d) {
///   final tile = screenToTile(d.localPosition, iso, cameraOffset);
///   controller.moveTo(tile);
/// }
/// ```
Offset screenToTile(Offset screen, IsoView iso, Offset cameraOffset) =>
    iso.unproject(screen - cameraOffset);

/// 타일 좌표를 정수 격자로 스냅한다.
Point<int> tileIndex(Offset tile) =>
    Point(tile.dx.floor(), tile.dy.floor());

/// 정수 좌표 한 쌍. `dart:math` 의 `Point` 를 쓰면 제네릭 때문에 장황해진다.
class Point<T extends num> {
  const Point(this.x, this.y);
  final T x;
  final T y;

  @override
  bool operator ==(Object other) =>
      other is Point<T> && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => '($x, $y)';
}

/// 8방향. 아이소 화면 기준이며 [Facing] 의 옥탄트와 같은 순서다.
///
/// 이름은 나침반을 따른다 — 아이소 맵에서 "남"은 화면 아래쪽, 즉 카메라
/// 가까운 쪽이다.
enum Dir8 {
  south(0, 1),
  southEast(1, 1),
  east(1, 0),
  northEast(1, -1),
  north(0, -1),
  northWest(-1, -1),
  west(-1, 0),
  southWest(-1, 1);

  const Dir8(this.dx, this.dy);

  /// 월드 타일 좌표계에서의 한 걸음.
  final int dx;
  final int dy;

  bool get isDiagonal => dx != 0 && dy != 0;

  /// 이 방향을 향하는 액터의 yaw(라디안).
  double get yaw => yawFromVelocity(Offset(dx.toDouble(), dy.toDouble()));
}

/// 통행 가능 여부를 담은 격자.
///
/// 기물([Prop])이 놓인 타일을 막아 두면 캐릭터가 나무와 건물을 피해 걷는다.
/// 막힌 곳이 없으면 [findPath] 는 직선을 돌려주므로, 장애물이 없는 맵에서도
/// 그대로 쓸 수 있다.
class IsoGrid {
  IsoGrid({required this.cols, required this.rows})
      : _blocked = List.filled(cols * rows, false);

  final int cols;
  final int rows;
  final List<bool> _blocked;

  bool inBounds(int x, int y) => x >= 0 && y >= 0 && x < cols && y < rows;

  bool isBlocked(int x, int y) =>
      !inBounds(x, y) || _blocked[y * cols + x];

  bool isWalkable(int x, int y) => !isBlocked(x, y);

  void block(int x, int y, {bool value = true}) {
    if (inBounds(x, y)) _blocked[y * cols + x] = value;
  }

  /// 기물이 차지한 타일을 한꺼번에 막는다.
  ///
  /// [footprint] 는 타일 단위 크기이며, 기물의 접지 타일을 좌상단으로 삼는다.
  void blockFootprint(Offset tile, Size footprint) {
    final x0 = tile.dx.floor();
    final y0 = tile.dy.floor();
    for (var dy = 0; dy < footprint.height.ceil(); dy++) {
      for (var dx = 0; dx < footprint.width.ceil(); dx++) {
        block(x0 + dx, y0 + dy);
      }
    }
  }

  void clear() {
    for (var i = 0; i < _blocked.length; i++) {
      _blocked[i] = false;
    }
  }

  /// 8방향 A* 경로탐색.
  ///
  /// 대각선 이동은 **양옆이 모두 열려 있을 때만** 허용한다. 그렇지 않으면
  /// 캐릭터가 두 건물 사이 대각선 틈으로 몸을 통과시켜 벽을 뚫는 것처럼 보인다.
  ///
  /// 목표가 막혀 있으면 그 근처의 통행 가능한 가장 가까운 타일로 대신 간다 —
  /// 클릭 이동에서 벽을 눌렀다고 아무 반응이 없으면 조작이 고장난 것처럼
  /// 느껴지기 때문이다.
  List<Offset> findPath(Offset from, Offset to) {
    final sx = from.dx.floor(), sy = from.dy.floor();
    var gx = to.dx.floor(), gy = to.dy.floor();

    if (!inBounds(sx, sy)) return const [];
    if (isBlocked(gx, gy)) {
      final near = _nearestOpen(gx, gy);
      if (near == null) return const [];
      gx = near.x;
      gy = near.y;
    }
    if (sx == gx && sy == gy) return const [];

    final open = _MinHeap();
    final cameFrom = HashMap<int, int>();
    final gScore = HashMap<int, double>();
    int id(int x, int y) => y * cols + x;
    double h(int x, int y) {
      // 옥타일 거리 — 8방향 격자의 정확한 하한.
      final dx = (x - gx).abs().toDouble();
      final dy = (y - gy).abs().toDouble();
      return (dx + dy) + (math.sqrt2 - 2) * math.min(dx, dy);
    }

    final startId = id(sx, sy);
    gScore[startId] = 0;
    open.push(startId, h(sx, sy));

    while (!open.isEmpty) {
      final current = open.pop();
      final cx = current % cols, cy = current ~/ cols;
      if (cx == gx && cy == gy) {
        return _reconstruct(cameFrom, current);
      }
      final cg = gScore[current] ?? double.infinity;

      for (final d in Dir8.values) {
        final nx = cx + d.dx, ny = cy + d.dy;
        if (isBlocked(nx, ny)) continue;
        // 코너 컷 방지 — 대각선은 양옆이 열려 있어야 지나간다.
        if (d.isDiagonal &&
            (isBlocked(cx + d.dx, cy) || isBlocked(cx, cy + d.dy))) {
          continue;
        }
        final step = d.isDiagonal ? math.sqrt2 : 1.0;
        final nid = id(nx, ny);
        final tentative = cg + step;
        if (tentative < (gScore[nid] ?? double.infinity)) {
          gScore[nid] = tentative;
          cameFrom[nid] = current;
          open.push(nid, tentative + h(nx, ny));
        }
      }
    }
    return const [];
  }

  Point<int>? _nearestOpen(int gx, int gy) {
    for (var r = 1; r <= 6; r++) {
      for (var dy = -r; dy <= r; dy++) {
        for (var dx = -r; dx <= r; dx++) {
          if (dx.abs() != r && dy.abs() != r) continue;
          if (isWalkable(gx + dx, gy + dy)) return Point(gx + dx, gy + dy);
        }
      }
    }
    return null;
  }

  List<Offset> _reconstruct(HashMap<int, int> cameFrom, int current) {
    final out = <Offset>[];
    var node = current;
    while (cameFrom.containsKey(node)) {
      out.add(Offset(node % cols + 0.5, node ~/ cols + 0.5));
      node = cameFrom[node]!;
    }
    return out.reversed.toList();
  }
}

/// 이진 힙. A* 의 열린 목록에 쓴다.
class _MinHeap {
  final List<int> _ids = [];
  final List<double> _keys = [];

  bool get isEmpty => _ids.isEmpty;

  void push(int id, double key) {
    _ids.add(id);
    _keys.add(key);
    var i = _ids.length - 1;
    while (i > 0) {
      final p = (i - 1) >> 1;
      if (_keys[p] <= _keys[i]) break;
      _swap(p, i);
      i = p;
    }
  }

  int pop() {
    final top = _ids.first;
    final lastId = _ids.removeLast();
    final lastKey = _keys.removeLast();
    if (_ids.isNotEmpty) {
      _ids[0] = lastId;
      _keys[0] = lastKey;
      var i = 0;
      while (true) {
        final l = i * 2 + 1, r = l + 1;
        var m = i;
        if (l < _ids.length && _keys[l] < _keys[m]) m = l;
        if (r < _ids.length && _keys[r] < _keys[m]) m = r;
        if (m == i) break;
        _swap(m, i);
        i = m;
      }
    }
    return top;
  }

  void _swap(int a, int b) {
    final ti = _ids[a];
    _ids[a] = _ids[b];
    _ids[b] = ti;
    final tk = _keys[a];
    _keys[a] = _keys[b];
    _keys[b] = tk;
  }
}

/// 클릭으로 움직이는 액터의 이동 상태.
///
/// ## 왜 별도 클래스인가
///
/// 이동은 "목표를 향해 좌표를 더하는 것"이 아니다. 경로를 따라가면서 방향을
/// 바꾸고, 방향이 바뀌면 캐릭터가 돌아야 하며, 도착하면 멈춰야 한다. 이 상태
/// 기계를 렌더 코드에 섞으면 둘 다 망가진다.
///
/// ## 회전을 보간하는 이유
///
/// 8방향으로 즉시 스냅하면 캐릭터가 순간이동하듯 홱 돌아 조작감이 싸구려가
/// 된다. 절차적 렌더러는 중간 각도를 그릴 수 있으므로, [turnTime] 에 걸쳐
/// 최단 경로로 돌린다. 스프라이트 기반 게임이 낼 수 없는 부드러움이다.
///
/// ```dart
/// final ctrl = IsoController(tile: const Offset(3.5, 3.5), grid: grid);
/// // 탭 처리
/// ctrl.moveTo(screenToTile(pos, iso, camera));
/// // 매 프레임
/// ctrl.update(dt);
/// actor.tile = ctrl.tile;
/// actor.facesLeft = ctrl.facesLeft;
/// ```
class IsoController {
  IsoController({
    required Offset tile,
    this.grid,
    this.speed = 3.2,
    this.turnTime = 0.14,
    double yaw = 0,
    // ignore: prefer_initializing_formals
  })  : _tile = tile,
        _yaw = yaw,
        _targetYaw = yaw;

  /// 통행 격자. `null` 이면 장애물 없이 직선으로 간다.
  final IsoGrid? grid;

  /// 초당 이동하는 타일 수.
  double speed;

  /// 8방향 전환에 걸리는 시간(초). 0 이면 즉시 스냅한다.
  double turnTime;

  Offset _tile;
  double _yaw;
  double _targetYaw;
  final List<Offset> _path = [];

  /// 현재 위치(연속 타일 좌표).
  Offset get tile => _tile;

  /// 현재 바라보는 각도(라디안). 렌더러에 그대로 넘긴다.
  double get yaw => _yaw;

  /// 8방향으로 스냅한 방향.
  Dir8 get facing8 {
    final o = ((_yaw / (math.pi / 4)).round() % 8 + 8) % 8;
    return Dir8.values[o];
  }

  /// 서쪽 절반을 향하는가. 좌우 반전으로 방향을 표현하는 액터에 쓴다.
  bool get facesLeft => math.sin(_yaw) < 0;

  bool get isMoving => _path.isNotEmpty;

  /// 남은 경로. 디버그 렌더에 쓸 수 있다.
  List<Offset> get path => List.unmodifiable(_path);

  /// 목표 타일로 이동을 시작한다. 이미 이동 중이면 경로를 갈아탄다.
  ///
  /// 격자가 있으면 A* 로 장애물을 피하고, 없으면 직선으로 간다.
  void moveTo(Offset target) {
    _path.clear();
    final g = grid;
    if (g == null) {
      _path.add(target);
      return;
    }
    final route = g.findPath(_tile, target);
    if (route.isEmpty) return;
    _path.addAll(_smooth(route, g));
  }

  /// 이동을 즉시 멈춘다.
  void stop() => _path.clear();

  /// 경로를 무시하고 순간이동한다.
  void teleport(Offset target) {
    _path.clear();
    _tile = target;
  }

  void update(double dt) {
    if (dt <= 0) return;

    if (_path.isNotEmpty) {
      var budget = speed * dt;
      while (budget > 0 && _path.isNotEmpty) {
        final next = _path.first;
        final delta = next - _tile;
        final dist = delta.distance;
        if (dist <= 1e-6) {
          _path.removeAt(0);
          continue;
        }
        // 이동 방향이 곧 바라보는 방향이다.
        _targetYaw = yawFromVelocity(delta);
        if (dist <= budget) {
          _tile = next;
          budget -= dist;
          _path.removeAt(0);
        } else {
          _tile += delta / dist * budget;
          budget = 0;
        }
      }
    }

    // 최단 경로로 회전. π 를 넘나들 때 한 바퀴 도는 것을 막는다.
    if (turnTime <= 0) {
      _yaw = _targetYaw;
    } else {
      var diff = (_targetYaw - _yaw) % (math.pi * 2);
      if (diff > math.pi) diff -= math.pi * 2;
      if (diff < -math.pi) diff += math.pi * 2;
      _yaw += diff * (1 - math.exp(-dt / turnTime));
    }
  }

  /// 경로에서 불필요한 꺾임을 제거한다.
  ///
  /// A* 는 격자를 따라가므로 계단 모양 경로를 낸다. 시야가 트인 구간을 직선으로
  /// 이으면 캐릭터가 자연스럽게 움직인다.
  List<Offset> _smooth(List<Offset> route, IsoGrid g) {
    if (route.length < 3) return route;
    final out = <Offset>[];
    var anchor = _tile;
    var i = 0;
    while (i < route.length) {
      var j = route.length - 1;
      while (j > i && !_clear(anchor, route[j], g)) {
        j--;
      }
      out.add(route[j]);
      anchor = route[j];
      if (j == i) {
        i++;
      } else {
        i = j + 1;
      }
    }
    return out;
  }

  /// 두 점 사이가 통행 가능한지 표본으로 확인한다.
  bool _clear(Offset a, Offset b, IsoGrid g) {
    final steps = (((b - a).distance) * 4).ceil().clamp(1, 200);
    for (var i = 1; i <= steps; i++) {
      final p = a + (b - a) * (i / steps);
      if (g.isBlocked(p.dx.floor(), p.dy.floor())) return false;
    }
    return true;
  }
}

/// 클릭 지점에 잠깐 남는 이동 표식.
///
/// 클릭 이동에서 **눌렀다는 사실이 화면에 보여야** 조작이 반응한다고 느껴진다.
/// 이 표식이 없으면 캐릭터가 움직이기 시작할 때까지 아무 일도 안 일어난 것처럼
/// 보인다.
class MoveMarker {
  MoveMarker({this.duration = 0.55});

  final double duration;
  Offset? _tile;
  double _age = 0;

  void ping(Offset tile) {
    _tile = tile;
    _age = 0;
  }

  void update(double dt) {
    if (_tile == null) return;
    _age += dt;
    if (_age >= duration) _tile = null;
  }

  /// 아이소 지면에 퍼지는 고리를 그린다. 카메라 오프셋 안에서 호출한다.
  void paint(Canvas c, IsoView iso, {Color color = const Color(0xFF7FE7FF)}) {
    final tile = _tile;
    if (tile == null) return;
    final u = (_age / duration).clamp(0.0, 1.0);
    final p = iso.project(tile.dx, tile.dy);
    final r = iso.tileWidth * (0.14 + 0.30 * u);
    final rect = Rect.fromCenter(
      center: p,
      width: r * 2,
      height: r * 2 * iso.shadowRatio,
    );
    c.drawOval(
      rect,
      Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, iso.tileWidth * 0.018 * (1 - u))
        ..blendMode = BlendMode.plus
        ..color = color.withValues(alpha: 0.75 * (1 - u)),
    );
  }
}
