import 'dart:ui';

import '../core/shading.dart';
import '../iso/iso_view.dart';

/// 맵에 놓이는 기물 하나.
///
/// 캐릭터([Artist])와 나란히 아이소 씬을 채우는 나무·바위·건물·물웅덩이 따위다.
/// 캐릭터와 달리 기물은 **크기가 제각각**이므로 고정 논리 캔버스를 쓰지 않고,
/// 각자 자기 픽셀 치수로 그린다.
///
/// ## 좌표 규약
///
/// 구현체는 **접지 중심이 원점, `-y` 가 위**인 국소 좌표에 그린다. 캐릭터의
/// 발밑 원점 규약과 같으므로 둘을 같은 씬에 섞어도 접지선이 어긋나지 않는다.
///
/// ## 세워지는 것과 눕는 것
///
/// 나무·바위·건물은 화면에 **수직으로 선다**([grounded] = false). 반면 웅덩이·
/// 길·풀밭은 지면 평면에 **눕는다**([grounded] = true). 눕는 기물은 세로가
/// 카메라 고도각만큼 더 눌려 원이 2:1 타원이 되며, 그래야 바닥에 붙어 보인다.
/// 이 처리는 [paintProp] 이 대신 해 주므로 구현체는 신경 쓰지 않는다.
///
/// ## 왜 시드를 받는가
///
/// 같은 숲에 똑같은 나무가 스무 그루 서 있으면 즉시 가짜로 보인다. 모든 구현체는
/// 시드를 받아 형상·색·기울기를 변주하되, **같은 시드는 언제나 같은 결과**를
/// 내야 한다([Rng] 만 쓰고 `math.Random` 을 쓰지 않는다).
abstract class Prop {
  /// 타일 단위 점유 크기. 경로탐색이 통행 가능 여부를 판단할 때 쓴다.
  ///
  /// 나무 한 그루는 `Size(1, 1)`, 큰 건물은 `Size(2, 3)` 처럼 준다.
  Size get footprint => const Size(1, 1);

  /// 화면상 높이(px). 깊이 정렬과 컬링에 쓰인다.
  double get height;

  /// 지면 평면에 눕는가. 웅덩이·길·풀밭이 `true`.
  bool get grounded => false;

  /// 캐릭터가 통과할 수 있는가. 풀·꽃·얕은 물은 통과, 나무·바위·벽은 막힌다.
  bool get walkable => grounded;

  /// 국소 좌표에 자신을 그린다. 같은 [t] 에는 언제나 같은 그림이 나와야 한다.
  ///
  /// [detail] 은 0..1 이며, 멀리 있는 기물은 낮춰 미세 텍스처를 생략한다.
  void paint(Canvas c, double t, LightRig light, {double detail = 1.0});
}

/// 맵 위 특정 타일에 놓인 기물 한 개.
///
/// [Prop] 은 "무엇"이고 이것은 "어디에"다. 같은 [Prop] 인스턴스를 여러 타일에
/// 재사용하면 나무 한 그루의 형상 계산을 숲 전체가 공유한다.
class PropInstance {
  PropInstance({
    required this.prop,
    required this.tile,
    this.facesLeft = false,
    this.timeOffset = 0,
    this.scale = 1.0,
  });

  final Prop prop;

  /// 월드 타일 좌표.
  Offset tile;

  /// 좌우 반전. 같은 기물을 뒤집어 놓으면 반복이 덜 눈에 띈다.
  final bool facesLeft;

  /// 바람·명멸의 위상. 개체마다 다르게 주어야 숲이 한 몸처럼 흔들리지 않는다.
  final double timeOffset;

  /// 개체별 크기 변주. 0.85~1.15 정도가 자연스럽다.
  final double scale;

  /// 깊이 정렬 키. 화면 y 가 아니라 월드 좌표라야 높은 기물이 뒤로 밀리지 않는다.
  double get depth => tile.dx + tile.dy;
}

/// 기물 하나를 아이소 맵에 그린다.
///
/// 세워지는 기물은 캐릭터와 똑같이 세로만 `iso.squash` 로 누르고, 눕는 기물은
/// 지면 평면에 맞춰 `iso.shadowRatio`(=sin 고도각)로 더 강하게 누른다.
void paintProp(
  Canvas c,
  PropInstance it,
  IsoView iso,
  LightRig light,
  double time, {
  double detail = 1.0,
}) {
  final anchor = iso.project(it.tile.dx, it.tile.dy);
  final s = it.scale;

  c.save();
  c.translate(anchor.dx, anchor.dy);
  if (it.prop.grounded) {
    // 지면 평면에 눕는다. 원이 2:1 타원이 되어 바닥에 붙어 보인다.
    c.scale(s * (it.facesLeft ? -1 : 1), s * iso.shadowRatio);
  } else {
    c.scale(s * (it.facesLeft ? -1 : 1), s * iso.squash);
  }
  it.prop.paint(c, time + it.timeOffset, light, detail: detail);
  c.restore();
}

/// 기물과 액터를 **한 목록으로 묶어** 깊이 순으로 그린다.
///
/// 기물과 캐릭터를 따로 그리면 나무 뒤로 걸어 들어간 캐릭터가 나무 앞에
/// 나타난다. 아이소 씬에서 그리기 순서는 곧 앞뒤 관계이므로, 화면에 있는
/// 모든 것이 같은 정렬을 거쳐야 한다.
///
/// ```dart
/// paintDepthSorted(canvas, [
///   ...props.map(DepthItem.prop),
///   ...actors.map(DepthItem.actor),
/// ], iso, light, time);
/// ```
void paintProps(
  Canvas c,
  List<PropInstance> props,
  IsoView iso,
  LightRig light,
  double time, {
  double Function(PropInstance)? detailOf,
}) {
  final sorted = [...props]..sort((a, b) => a.depth.compareTo(b.depth));
  for (final it in sorted) {
    paintProp(c, it, iso, light, time, detail: detailOf?.call(it) ?? 1.0);
  }
}

/// 기물이 지면에 드리우는 그림자.
///
/// 세워지는 기물에는 예외 없이 필요하다. 아이소 뷰에는 원근이 없어, 그림자가
/// 없으면 나무가 지면에 서 있는지 공중에 떠 있는지 구별할 수 없다.
void propShadow(
  Canvas c,
  double radius,
  LightRig l, {
  double alpha = 0.42,
  double stretch = 1.35,
}) {
  // 광원 반대쪽으로 늘어난 타원. 지면에 눕는 것이므로 세로를 절반으로 누른다.
  final dir = l.dir;
  final cx = -dir.dx * radius * 0.45;
  final rect = Rect.fromCenter(
    center: Offset(cx, 0),
    width: radius * 2 * stretch,
    height: radius * 1.0,
  );
  c.drawOval(
    rect,
    Paint()
      ..isAntiAlias = true
      ..shader = Gradient.radial(
        rect.center,
        rect.width * 0.5,
        [
          const Color(0xFF05070E).withValues(alpha: alpha),
          const Color(0xFF05070E).withValues(alpha: alpha * 0.42),
          const Color(0x0005070E),
        ],
        const [0.0, 0.55, 1.0],
      ),
  );
}
