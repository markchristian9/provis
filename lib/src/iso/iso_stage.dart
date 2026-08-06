import 'dart:math' as math;
import 'dart:ui';

import '../art/creature.dart';
import '../core/palette.dart';
import '../core/shading.dart';
import '../render/iso.dart';

/// 손으로 그린 [Artist] 를 2.5D 아이소 맵 위에 세우는 다리.
///
/// 이 파일이 존재하는 이유는 하나다. 이 저장소에서 AAA 품질이 나오는 곳은
/// `art/` 의 수작업 캐릭터인데, 그들은 [kStage] 라는 초상용 논리 캔버스에
/// 그려지도록 만들어졌다. 반면 게임 맵은 아이소메트릭이다. 둘을 잇지 못하면
/// "품질은 갤러리에, 게임은 저품질 액터로" 라는 분열이 영원히 남는다.
///
/// 다리는 좌표 변환 하나로 충분하다. 셰이딩·부위 형상·마무리는 좌표계를
/// 모르기 때문이다. 그래서 **완성된 캐릭터를 한 줄도 고치지 않고** 아이소
/// 씬에 세울 수 있다.
///
/// ```
/// ① 접지점만 아이소 투영한다        iso.project(tile)
/// ② 원하는 키로 스케일한다           height / kStage.height
/// ③ 세로만 카메라 고도각으로 누른다   × iso.squash
/// ④ Artist 원점을 발밑으로 옮긴다     (-kStage.width/2, -kGround)
/// ```

/// 아이소 맵 위에 선 액터 하나.
class IsoActor {
  IsoActor({
    required this.artist,
    required this.tile,
    this.height = 430,
    this.facesLeft = false,
    this.airborne = 0,
    this.timeOffset = 0,
  });

  final Artist artist;

  /// 월드 타일 좌표. 게임 로직은 이것만 갱신한다.
  Offset tile;

  /// 화면상 키(px). 타일 폭의 1.2~1.6배가 아이소 게임의 인간형 표준이다.
  /// 그보다 크면 격자가 묻혀 지면 평면이 사라진다.
  double height;

  /// 좌우 반전 여부. 아이소 8방향 중 서쪽 절반을 향할 때 켠다.
  bool facesLeft;

  /// 지면에서 뜬 높이(월드 단위). 점프·비행에 쓴다.
  double airborne;

  /// 개체마다 애니메이션 위상을 어긋나게 해 군집이 한 몸처럼 움직이는 것을 막는다.
  double timeOffset;

  /// 깊이 정렬 키. 화면 y 가 아니라 월드 좌표라야 점프해도 순서가 유지된다.
  double get depth => tile.dx + tile.dy;
}

/// [IsoActor] 하나를 그린다.
///
/// [detail] 은 그대로 [Artist.paint] 에 전달된다. 멀리 있는 개체는 낮춰서
/// 미세 텍스처와 파티클을 생략한다 — `detailFor()` 참조.
void paintIsoActor(
  Canvas c,
  IsoActor a,
  IsoView iso,
  double time, {
  double detail = 1.0,
}) {
  final anchor = iso.project(a.tile.dx, a.tile.dy, a.airborne);
  final s = a.height / kStage.height;

  c.save();
  c.translate(anchor.dx, anchor.dy);
  // 세로만 카메라 고도각으로 누른다. 가로까지 누르면 인체가 찌그러진다.
  c.scale(s * (a.facesLeft ? -1 : 1), s * iso.squash);
  // Artist 는 발바닥이 kGround, 가로 중심이 kStage.width/2 인 좌표계로 그린다.
  c.translate(-kStage.width / 2, -kGround);
  a.artist.paint(c, time + a.timeOffset, detail: detail);
  c.restore();
}

/// 여러 액터를 깊이 순으로 그린다.
///
/// 아이소 씬에서 그리기 순서는 곧 앞뒤 관계다. 정렬을 빠뜨리면 뒤에 선
/// 캐릭터가 앞 캐릭터를 덮어 장면이 무너진다.
void paintIsoActors(
  Canvas c,
  List<IsoActor> actors,
  IsoView iso,
  double time, {
  double Function(IsoActor)? detailOf,
}) {
  final sorted = [...actors]..sort((x, y) => x.depth.compareTo(y.depth));
  for (final a in sorted) {
    paintIsoActor(c, a, iso, time, detail: detailOf?.call(a) ?? 1.0);
  }
}

/// 아이소 지면 타일.
///
/// 캐릭터가 서 있는 평면이 보여야 2.5D 로 읽힌다. 격자가 없으면 캐릭터가
/// 허공에 뜬 카드로 보인다.
void paintIsoGround(
  Canvas c,
  IsoView iso,
  int cols,
  int rows,
  LightRig l, {
  Color? base,
  double lineAlpha = 0.10,
}) {
  final ground = base ?? l.ambient.lighten(0.06);
  final fill = Paint()..isAntiAlias = true;
  final line = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1
    ..color = l.rim.fade(lineAlpha);

  for (var y = 0; y < rows; y++) {
    for (var x = 0; x < cols; x++) {
      final p0 = iso.project(x.toDouble(), y.toDouble());
      final p1 = iso.project(x + 1.0, y.toDouble());
      final p2 = iso.project(x + 1.0, y + 1.0);
      final p3 = iso.project(x.toDouble(), y + 1.0);
      final tile = Path()
        ..moveTo(p0.dx, p0.dy)
        ..lineTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..lineTo(p3.dx, p3.dy)
        ..close();

      // 체커 패턴에 거리 감쇠를 얹는다. 먼 타일이 어두워지면 깊이가 읽힌다.
      final far = 1 - (x + y) / (cols + rows);
      final checker = (x + y).isEven ? 0.0 : 0.045;
      fill.color = ground.lighten(checker).fade(0.55 + 0.35 * far);
      c.drawPath(tile, fill);
      c.drawPath(tile, line);
    }
  }
}

/// 씬 전체에 얹는 대기 원근(aerial perspective).
///
/// 먼 곳이 환경광 쪽으로 흐려지면 평면이던 화면에 깊이가 생긴다. 실사 렌더의
/// 안개와 같은 역할이며, 2D 에서는 이 한 겹이 비용 대비 효과가 가장 크다.
void paintIsoHaze(Canvas c, Rect view, LightRig l, {double strength = 0.5}) {
  c.drawRect(
    view,
    Paint()
      ..blendMode = BlendMode.srcOver
      ..shader = Gradient.linear(
        view.topCenter,
        view.bottomCenter,
        [
          l.ambient.fade((0.72 * strength).clamp(0.0, 1.0)),
          l.ambient.fade(0.0),
        ],
        const [0.0, 0.62],
      ),
  );
}

/// 화면 크기와 역할로 디테일 레벨을 정한다.
///
/// 아이소 씬은 캐릭터가 작게 보이므로, 전원을 최고 품질로 그리면 보이지도
/// 않는 텍스처에 프레임을 쓴다.
double isoDetailFor(IsoActor a, {bool isHero = false}) {
  if (isHero) return 1.0;
  if (a.height > 260) return 1.0;
  if (a.height > 160) return 0.7;
  return 0.35;
}

/// 타일 좌표를 격자로 흩뿌린다. 데모·군집 배치용.
List<Offset> scatterTiles(int count, int cols, int rows, int seed) {
  final out = <Offset>[];
  var h = seed & 0x7FFFFFFF;
  int next() {
    h = (h * 1103515245 + 12345) & 0x7FFFFFFF;
    return h;
  }

  final taken = <String>{};
  var guard = 0;
  while (out.length < count && guard++ < count * 40) {
    final x = next() % cols;
    final y = next() % rows;
    final key = '$x:$y';
    if (taken.contains(key)) continue;
    taken.add(key);
    out.add(Offset(x + 0.5, y + 0.5));
  }
  return out;
}

/// 씬 전체가 화면에 들어오도록 카메라 오프셋을 계산한다.
Offset isoCameraOffset(IsoView iso, int cols, int rows, Size view) {
  final corners = [
    iso.project(0, 0),
    iso.project(cols.toDouble(), 0),
    iso.project(cols.toDouble(), rows.toDouble()),
    iso.project(0, rows.toDouble()),
  ];
  var minX = double.infinity, maxX = -double.infinity;
  var minY = double.infinity, maxY = -double.infinity;
  for (final p in corners) {
    minX = math.min(minX, p.dx);
    maxX = math.max(maxX, p.dx);
    minY = math.min(minY, p.dy);
    maxY = math.max(maxY, p.dy);
  }
  return Offset(
    view.width / 2 - (minX + maxX) / 2,
    view.height / 2 - (minY + maxY) / 2,
  );
}
