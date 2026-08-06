import 'dart:ui';

import '../actor/character_build.dart';
import '../actor/spec.dart';
import '../core/shading.dart';

/// 모든 캐릭터가 그려지는 공통 좌표계.
///
/// 실제 화면 크기와 무관하게 캐릭터는 언제나 이 논리 캔버스 안에 그려지고,
/// 표시할 때만 스케일된다. 덕분에 카드 썸네일과 대형 스테이지가 완전히 같은
/// 코드로 렌더된다. 8등신 기준으로 머리 높이가 약 175 이므로 눈·입 같은
/// 디테일에 충분한 해상도가 남는다.
const Size kStage = Size(1000, 1400);

/// 지면선. 모든 캐릭터의 발바닥이 이 높이에 닿는다.
const double kGround = 1332;

enum Sex { male, female }

extension SexLabel on Sex {
  String get label => this == Sex.male ? 'Male' : 'Female';

  /// 좁은 카드에는 이름을 적을 자리가 없다. 기호 하나로 대신한다.
  String get symbol => this == Sex.male ? '♂' : '♀';
}

enum Camp { player, monster }

extension CampLabel on Camp {
  String get label => this == Camp.player ? 'Hero' : 'Monster';
}

/// 그릴 수 있는 존재 하나.
///
/// 스프라이트도 아틀라스도 없다. 각 구현체는 매 프레임 순수 코드로 자신을
/// 그린다. [t] 는 초 단위 누적 시간이며, 같은 [t] 에는 언제나 같은 그림이
/// 나오도록(결정론적으로) 구현한다.
abstract class Artist {
  String get id;
  String get name;

  /// 이름 밑에 붙는 칭호.
  String get title;

  /// 카드에 표시할 한 줄 소개.
  String get blurb;

  Camp get camp;

  /// 플레이어 캐릭터만 성별을 가진다.
  Sex? get sex;

  /// UI 강조색. 캐릭터의 지배적인 색에서 가져온다.
  Color get accent;

  /// 이 캐릭터가 서 있는 조명 환경.
  LightRig get light;

  /// 배경 무드. 스테이지 배경 그라디언트에 쓴다.
  List<Color> get moodSky;

  /// [kStage] 좌표계에 자신을 그린다.
  ///
  /// [detail] 은 0..1 의 디테일 레벨이다. 카드 썸네일은 낮은 값으로 호출해
  /// 미세 텍스처와 파티클을 생략한다.
  void paint(Canvas c, double t, {double detail = 1.0});

  /// 캐릭터가 실제로 차지하는 세로 범위. 카드 크롭에 쓴다.
  Rect get framing => const Rect.fromLTWH(60, 40, 880, 1330);

  /// 직업. 명부에 표시하고, 골격 액터의 체형·장비를 결정한다.
  ///
  /// 기본값은 [build] 에서 가져오므로, 대개는 `build` 만 선언하면 된다.
  Archetype get job => build.archetype;

  /// 이 캐릭터를 골격 액터로 옮길 때 쓸 정체성.
  ///
  /// **오버라이드하지 않으면 id 와 accent 로 추정한다** — 초상과 정확히 같지
  /// 않다. 게임 맵에 세울 캐릭터라면 반드시 선언해서 머리색·옷색·장비를
  /// 넘겨라. 그러지 않으면 명부에서 고른 인물과 맵에서 걷는 인물이 다르다.
  CharacterBuild get build => CharacterBuild.guess(this);

  /// 포즈가 화면 왼쪽을 향하는가.
  ///
  /// 대치 화면에서 플레이어는 오른쪽의 적을, 몬스터는 왼쪽의 플레이어를
  /// 봐야 한다. 이 값이 맞지 않는 캐릭터만 좌우를 뒤집는다.
  bool get facesLeft => false;

}
