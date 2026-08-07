import 'dart:math' as math;
import 'dart:ui';

import 'package:provis/provis.dart';

/// 주인공을 따라가되 맵 밖을 보여 주지 않는 카메라.
///
/// ## 왜 고정 카메라를 버려야 했는가
///
/// 예전 맵은 15×15 타일이었고 `isoCameraOffset` 이 맵 전체를 화면 한가운데
/// 맞춰 놓았다. 기물이 제 크기를 찾으면서 맵은 40×34 m 가 되었고, 화면상
/// 폭은 `(40+34) × 75 = 5,550 px` 다. 어떤 창에도 들어가지 않는다. 전체를
/// 우겨넣으려고 줌을 빼면 사람이 다시 점이 되므로, **비율을 고친 의미가
/// 사라진다.** 그래서 카메라가 따라간다.
///
/// ## 경계에서 멈춘다
///
/// 따라가기만 하면 맵 가장자리에서 화면 절반이 빈 배경이 된다. 지면 바깥이
/// 보이는 순간 "여기가 세계의 끝"이라는 것이 드러나 몰입이 깨진다. 그래서
/// 맵이 화면보다 큰 축에서는 카메라를 지면 안쪽으로 **가둔다**. 맵이 화면보다
/// 작은 축에서는 가운데 정렬한다 — 가두면 오히려 한쪽으로 쏠린다.
Offset followCamera({
  required IsoView iso,
  required Offset focusTile,
  required Size view,
  required int cols,
  required int rows,
  double headroom = 0.0,
}) {
  // 지면 마름모의 화면 공간 경계.
  final minX = -rows * iso.tileWidth * 0.5;
  final maxX = cols * iso.tileWidth * 0.5;
  final minY = -headroom;
  final maxY = (cols + rows) * iso.tileHeight * 0.5;

  final focus = iso.project(focusTile.dx, focusTile.dy);
  var ox = view.width * 0.5 - focus.dx;
  var oy = view.height * 0.5 - focus.dy;

  // 각 축에서 맵이 화면보다 큰지 먼저 본다.
  final spanX = maxX - minX;
  final spanY = maxY - minY;

  if (spanX <= view.width) {
    ox = view.width * 0.5 - (minX + maxX) * 0.5; // 가운데 정렬
  } else {
    ox = ox.clamp(view.width - maxX, -minX);
  }

  if (spanY <= view.height) {
    oy = view.height * 0.5 - (minY + maxY) * 0.5;
  } else {
    oy = oy.clamp(view.height - maxY, -minY);
  }

  return Offset(ox, oy);
}

/// 카메라를 목표로 부드럽게 따라 붙인다.
///
/// 즉시 스냅하면 화면이 캐릭터에 못 박혀 걸음마다 배경이 딱딱 끊긴다.
/// 프레임률과 무관한 지수 감쇠를 쓴다 — `dt` 가 흔들려도 같은 속도로 붙는다.
Offset easeCamera(Offset from, Offset to, double dt, {double time = 0.16}) {
  if (time <= 0) return to;
  final k = 1 - math.exp(-dt / time);
  return from + (to - from) * k;
}
