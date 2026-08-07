import 'dart:math' as math;

import 'iso_view.dart';

/// 이 저장소의 **유일한 크기 기준**.
///
/// ## 왜 이것이 없으면 반드시 어긋나는가
///
/// 아이소 씬의 모든 것은 자기 국소 픽셀 치수로 그린다 — [IsoActor.height],
/// [Prop.height], `BuildingProp._storeyH`. 픽셀은 만드는 사람마다 다른 기준으로
/// 고른다. 나무를 만든 사람은 "화면에서 이 정도"로, 건물을 만든 사람은 "타일
/// 폭의 몇 배"로 정했다. **각자 그럴듯한 숫자를 넣었는데도 한 화면에 모으면
/// 사람이 2층집보다 크다.** 실제로 이 저장소가 그랬다.
///
/// 고치는 방법은 눈으로 보며 숫자를 흔드는 것이 아니라, 모든 치수를 **미터로
/// 선언하고 마지막에 한 번만 픽셀로 바꾸는 것**이다. 그러면 "층고 0.5 m" 같은
/// 값이 코드에서 바로 읽힌다.
///
/// ## 환산식 — squash 는 약분된다
///
/// `paintProp`·`paintRiggedActor` 는 국소 px 를 세로만 `iso.squash` 로 누르고,
/// [IsoView.project] 는 월드 수직 1 단위를 `heightScale = tileWidth·squash/√2`
/// px 로 옮긴다. 둘을 같이 놓으면 `squash` 가 약분된다.
///
/// ```
/// 월드 높이(타일) = 국소px · squash / heightScale
///                 = 국소px · squash · √2 / (tileWidth · squash)
///                 = 국소px · √2 / tileWidth
/// ```
///
/// 즉 **국소 1 타일 = `tileWidth/√2` px** 이며 카메라 고도각과 무관하다. 타일
/// 비율을 바꿔도 사람과 집의 비례는 흔들리지 않는다는 뜻이다.
///
/// ## 1 타일 = 1 미터인 이유
///
/// provis 의 아이소 규약은 **캐릭터 키 = 타일 폭의 1.2~1.6배**다(넘으면 격자가
/// 묻혀 지면 평면이 사라진다). 이 규약을 위 환산식에 넣으면
///
/// ```
/// 키(타일) = (1.2~1.6)·tileWidth · √2 / tileWidth = 1.70~2.26 타일
/// ```
///
/// 사람 키 1.8 m 를 이 대역 한가운데 놓으면 1 타일 ≈ 1 m 가 나온다. 즉 규약과
/// 미터법이 이미 일치하고 있었고, **어긋난 것은 기물 쪽뿐**이었다.
///
/// ```dart
/// const scale = WorldScale(iso: IsoView(tileWidth: 150, tileHeight: 75));
/// scale.px(3.0)      // 층고 3 m → 318 px
/// scale.meters(200)  // 200 px → 1.89 m
/// ```
class WorldScale {
  const WorldScale({
    this.iso = kIso,
    this.metersPerTile = kMetersPerTile,
  });

  /// 타일 폭만 아는 곳에서 쓴다.
  ///
  /// 기물([Prop])은 대개 [IsoView] 전체가 아니라 `tileWidth` 하나만 받는다.
  /// [pxPerMeter] 는 `tileWidth` 에만 의존하므로(`tileWidth/√2 ÷ metersPerTile`)
  /// 고도각을 몰라도 치수를 정확히 환산할 수 있다.
  factory WorldScale.ofTileWidth(
    double tileWidth, {
    double metersPerTile = kMetersPerTile,
  }) =>
      WorldScale(
        iso: IsoView(tileWidth: tileWidth, tileHeight: tileWidth * 0.5),
        metersPerTile: metersPerTile,
      );

  /// 이 스케일이 딸린 카메라.
  final IsoView iso;

  /// 타일 한 칸의 변 길이(미터).
  final double metersPerTile;

  /// 국소 좌표에서 월드 1 타일이 차지하는 픽셀. `tileWidth/√2`.
  double get pxPerTile => iso.tileWidth / math.sqrt2;

  /// 국소 좌표에서 1 미터가 차지하는 픽셀. 모든 치수 선언이 이것을 지난다.
  double get pxPerMeter => pxPerTile / metersPerTile;

  /// 미터 → 국소 px.
  double px(double meters) => meters * pxPerMeter;

  /// 국소 px → 미터.
  double meters(double px) => px / pxPerMeter;

  /// 미터 → 타일. 이동 속도·사거리를 타일 단위로 옮길 때 쓴다.
  double tiles(double meters) => meters / metersPerTile;

  /// 타일 → 미터.
  double metersOfTiles(double tiles) => tiles * metersPerTile;

  /// 화면에 실제로 찍히는 세로 픽셀. 컬링·LOD 판단에 쓴다.
  double screenPx(double localPx) => localPx * iso.squash;

  // ── 자주 쓰는 치수 ───────────────────────────────────────────────────

  /// 표준 인간 키(국소 px). 액터 [height] 기본값이자 모든 비례의 기준자.
  double get humanPx => px(kHumanHeightM);

  /// 타일 폭 대비 캐릭터 키 배율. provis 규약은 1.2~1.6 이다.
  double get humanTileRatio => humanPx / iso.tileWidth;
}

/// 타일 한 칸 = 1 미터.
///
/// 값을 바꾸면 사람과 기물이 **함께** 커지거나 작아진다 — 비례는 유지된다.
/// 바꿀 이유는 사실상 하나뿐이다: 맵 한 칸이 방 한 칸(≈2 m)이어야 하는
/// 타일형 던전으로 장르를 옮길 때.
const double kMetersPerTile = 1.0;

// ---------------------------------------------------------------------------
// 인간 척도 — 여기 있는 숫자가 게임 세계의 현실이다
// ---------------------------------------------------------------------------
//
// 전부 실제 건축·인체 치수다. "화면에서 예뻐 보이는 값"을 여기에 넣으면 이
// 파일의 존재 이유가 사라진다. 화면 인상은 카메라(tileWidth)로 조절한다.

/// 성인 키.
const double kHumanHeightM = 1.8;

/// 어깨 폭. 출입문 너비의 하한을 준다.
const double kShoulderWidthM = 0.48;

/// 한 층의 바닥에서 다음 바닥까지. 중세 민가는 2.4~3.2 m 다.
const double kStoreyHeightM = 2.9;

/// 출입문 높이. 사람이 고개를 숙이지 않고 지난다.
const double kDoorHeightM = 2.05;

/// 출입문 너비.
const double kDoorWidthM = 0.95;

/// 창 하단이 바닥에서 뜨는 높이.
const double kWindowSillM = 0.95;

/// 창 한 짝의 크기.
const double kWindowHeightM = 1.20;
const double kWindowWidthM = 0.85;

/// 사람 허리께 울타리.
const double kFenceHeightM = 1.15;

/// 사람이 넘겨다볼 수 없는 담.
const double kWallHeightM = 2.6;

/// 다 자란 활엽수. 수관까지 포함한 전체 키가 아니라 **밑동에서 수관 시작까지**다.
const double kTreeTrunkM = 4.2;

/// 계단 한 단.
const double kStepRiseM = 0.18;
const double kStepRunM = 0.28;
