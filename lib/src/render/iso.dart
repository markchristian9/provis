import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/painting.dart' show Alignment, LinearGradient;

import 'light.dart';
import 'palette.dart';
import 'surface.dart';

/// 2.5D 아이소메트릭 카메라.
///
/// 게임 맵 전체가 이 하나의 리그를 공유한다. 타일 비율을 바꾸면 고도각과
/// 수직 단축이 함께 따라오므로, 스케일 상수를 손으로 흩어 두지 않는다.
///
/// 지면은 아이소 평면에 눕고, 캐릭터는 그 위에 화면 수직으로 세워진 카드다.
/// 캐릭터 파츠를 아이소 평면에 투영하면 인체가 마름모로 찌그러진다 — 아이소
/// 투영은 액터의 접지점 하나에만 적용한다.
class IsoView {
  const IsoView({this.tileWidth = 128, this.tileHeight = 64});

  /// 타일 한 칸의 화면 폭. 높이와의 비가 곧 카메라 고도각이다.
  final double tileWidth;

  /// 타일 한 칸의 화면 높이. 2:1 이면 고도각 30°.
  final double tileHeight;

  /// sin(고도각). 2:1 타일이면 0.5.
  double get elevationSin => (tileHeight / tileWidth).clamp(0.05, 0.98);

  /// cos(고도각). 수직 물체가 화면에서 짧아지는 비율.
  double get squash => math.sqrt(1 - elevationSin * elevationSin);

  /// 고도각(라디안). 상단면 하이라이트 강도 계산에 쓴다.
  double get elevation => math.asin(elevationSin);

  /// 월드 수직 1 단위가 화면에서 차지하는 픽셀.
  ///
  /// 유도: 카메라 yaw 45° 정사영에서 월드 X 축의 화면 길이는 cos45°,
  /// 월드 Z 축은 cosθ 이므로 heightScale / (tileWidth/2) = cosθ / cos45°.
  double get heightScale => tileWidth * squash / math.sqrt2;

  /// 접지 그림자 타원의 세로/가로 비.
  double get shadowRatio => elevationSin;

  /// 월드 타일 좌표 → 화면 좌표. [wz] 는 지면 위 높이(양수가 위).
  Offset project(double wx, double wy, [double wz = 0]) => Offset(
        (wx - wy) * tileWidth * 0.5,
        (wx + wy) * tileHeight * 0.5 - wz * heightScale,
      );

  /// 화면 좌표 → 지면(z=0) 월드 좌표. 마우스 피킹·타일 하이라이트에 쓴다.
  Offset unproject(Offset screen) {
    final a = screen.dx / (tileWidth * 0.5);
    final b = screen.dy / (tileHeight * 0.5);
    return Offset((b + a) * 0.5, (b - a) * 0.5);
  }

  /// 깊이 정렬 키. 클수록 화면 앞(나중에 그림).
  ///
  /// 화면 y 를 쓰면 점프한 액터가 뒤로 밀리므로 반드시 월드 좌표로 정렬한다.
  double depthKey(double wx, double wy) => wx + wy;
}

/// 프로젝트 기본 카메라. 액터 렌더러는 이것을 참조한다.
const IsoView kIso = IsoView();

/// 액터가 바라보는 방향. yaw = 0 이 카메라 정면(화면 아래, 아이소 S).
///
/// 스프라이트를 굽지 않으므로 yaw 는 연속값이어도 된다. 8방향 게임플레이에서는
/// [snap8] 로 스냅하되 전환을 보간하면, 스프라이트 기반 게임이 낼 수 없는
/// 부드러움이 나온다.
class Facing {
  const Facing(this.yaw);

  final double yaw;

  /// 8방향 인덱스. 0=S, 1=SE, 2=E, 3=NE, 4=N, 5=NW, 6=W, 7=SW.
  int get octant => ((yaw / (math.pi / 4)).round() % 8 + 8) % 8;

  Facing get snap8 => Facing(octant * math.pi / 4);

  /// 0 = 정면/후면, 1 = 완전 측면. 어깨 폭 축소에 쓴다.
  double get profile => math.sin(yaw).abs();

  /// 카메라를 향하고 있는가. 얼굴을 그릴지 뒤통수를 그릴지 결정한다.
  bool get toCamera => math.cos(yaw) > 0;

  /// +1 이면 화면 오른쪽 사지가 near, -1 이면 왼쪽이 near.
  double get nearSide => math.sin(yaw) >= 0 ? 1 : -1;

  /// 어깨선이 화면에서 보이는 폭 비율. 측면일수록 좁다.
  double get shoulderScale => 1.0 - 0.62 * profile;

  /// 사지의 앞뒤 어긋남 정도. 정면에서는 0(겹침), 측면에서 최대.
  double get depthSpread => profile;
}

/// 월드 이동 속도 → 액터 yaw.
///
/// 아이소 화면에서 "오른쪽 위"로 이동하는 것이 월드 +x 이므로, 화면 방향이
/// 아니라 월드 방향에서 yaw 를 뽑아야 이동과 시선이 일치한다.
double yawFromVelocity(Offset worldVelocity) => math.atan2(
      worldVelocity.dx - worldVelocity.dy,
      worldVelocity.dx + worldVelocity.dy,
    );

/// 아이소 뷰에서 위를 향한 면에 얹는 하이라이트.
///
/// 카메라가 내려다보는 각도만큼 파츠의 상단이 하늘빛을 받는다. 어깨·투구·
/// 어깨보호대·발등처럼 "윗면이 있는" 파츠에만 준다. 사지 옆면에 주면 오히려
/// 형태가 납작해진다. [paintSurface] 직후에 호출한다.
void paintTopPlane(
  Canvas canvas,
  Path path,
  LightRig light,
  IsoView iso, {
  double strength = 0.5,
}) {
  final b = path.getBounds();
  if (b.isEmpty || b.height < 0.5) return;

  // 고도각이 클수록(위에서 볼수록) 상단면이 넓게 보인다.
  final band = 0.18 + 0.30 * iso.elevationSin;

  canvas.save();
  canvas.clipPath(path, doAntiAlias: true);
  canvas.drawRect(
    b,
    Paint()
      ..blendMode = BlendMode.plus
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          mix(light.rimColor, light.keyColor, 0.45)
              .withValues(alpha: (0.34 * strength).clamp(0, 1)),
          const Color(0x00000000),
        ],
        stops: [0.0, band.clamp(0.05, 0.95)],
      ).createShader(b),
  );
  canvas.restore();
}

/// 아이소 지면에 눕는 접지 그림자.
///
/// 아이소 뷰에는 원근이 없어 높이와 깊이가 화면상 같은 축을 공유한다. 그래서
/// 그림자가 없으면 점프한 캐릭터와 뒤쪽에 선 캐릭터를 구별할 수 없다.
/// **모든 액터는 예외 없이 이 그림자를 그린다.**
///
/// [groundAt] 은 액터 국소 공간의 접지점(보통 Offset.zero), [airborne] 은
/// 지면에서 뜬 높이(월드 단위)다. 뜰수록 그림자가 작고 옅어져 높이가 읽힌다.
void paintIsoGroundShadow(
  Canvas canvas,
  IsoView iso,
  Offset groundAt,
  double width,
  LightRig light, {
  double strength = 0.5,
  double airborne = 0.0,
}) {
  final k = (1 - airborne * 0.6).clamp(0.35, 1.0);
  paintGroundShadow(
    canvas,
    groundAt,
    width * k,
    width * iso.shadowRatio * k,
    light,
    strength: strength * k,
  );
}

/// 아주 작거나(<32px) 아주 많은 액터를 위한 임포스터.
///
/// saveLayer 0회, 블러 0회. 실루엣 + 림만으로도 형태가 읽히므로 군중을
/// 감당한다.
void paintImposter(Canvas canvas, Path silhouette, Color tint, LightRig light) {
  canvas.drawPath(silhouette, Paint()..color = tint);
  canvas.drawPath(
    silhouette,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = light.rimColor.withValues(alpha: 0.5)
      ..blendMode = BlendMode.plus,
  );
}

/// 파츠를 한 번 굽고 이후엔 재생만 한다.
///
/// paintSurface 는 파츠당 saveLayer 1회 + 블러 3~6회를 쓴다. 프레임 간에
/// 형상이 바뀌지 않는 것(무기·장비·정지 몹)은 반드시 구워서 그 비용을 없앤다.
///
/// 주의: 구운 Picture 에는 조명이 이미 칠해져 있다. 광원이 바뀌면 전부
/// 무효화해야 하며, 비균등 스케일로 재생하면 블러와 스펙큘러가 찌그러진다.
class BakedPart {
  BakedPart._(this.picture, this.bounds);

  final Picture picture;
  final Rect bounds;

  /// [draw] 를 국소 좌표계에서 실행해 Picture 로 굽는다.
  factory BakedPart.bake(Rect bounds, void Function(Canvas) draw) {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder, bounds);
    draw(canvas);
    return BakedPart._(recorder.endRecording(), bounds);
  }

  /// 변환만 걸어 재생. saveLayer·블러가 다시 실행되지 않는다.
  void replay(
    Canvas canvas, {
    Offset at = Offset.zero,
    double rotation = 0,
    double scale = 1,
  }) {
    canvas.save();
    canvas.translate(at.dx, at.dy);
    if (rotation != 0) canvas.rotate(rotation);
    if (scale != 1) canvas.scale(scale);
    canvas.drawPicture(picture);
    canvas.restore();
  }

  /// Picture 는 네이티브 자원이다. 액터 제거 시 반드시 호출한다.
  void dispose() => picture.dispose();
}

/// 화면상 크기와 게임플레이 중요도로 렌더 품질을 정한다.
///
/// 플레이어와 보스는 언제나 최고 품질을 쓴다 — 시선이 가장 오래 머무는
/// 대상에서 아끼면 게임 전체의 인상이 떨어진다.
Quality qualityFor(
  double screenHeightPx, {
  bool isPlayer = false,
  bool isBoss = false,
}) {
  if (isPlayer || isBoss) return Quality.high;
  if (screenHeightPx > 140) return Quality.high;
  if (screenHeightPx > 70) return Quality.medium;
  return Quality.low;
}
