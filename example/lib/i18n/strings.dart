import 'package:provis/provis.dart';

import 'lang.dart';

/// 화면에 나가는 모든 문자열.
///
/// ## 왜 손으로 짰는가
///
/// `flutter_localizations` + `gen_l10n` 은 `.arb` 파일과 생성 코드를 요구한다.
/// 예제 앱 하나에 빌드 단계를 하나 더 붙일 값이 없고, 무엇보다 이 저장소는
/// 스프라이트도 아틀라스도 없이 전부 코드로 짜는 곳이다. 문자열도 같은
/// 규칙을 따른다 — 한 줄에 두 언어가 나란히 보이면 번역이 어긋난 자리를
/// 눈으로 바로 찾는다.
///
/// 새 문자열을 넣을 때는 [_pick] 한 줄이면 된다. 새 언어를 넣을 때만
/// [_pick] 의 시그니처가 바뀐다.
class Strings {
  const Strings(this.lang);

  /// 언어별 인스턴스. 상태가 없으므로 매번 만들어도 되지만, 화면이 매
  /// 프레임 읽으므로 상수로 잡아 둔다.
  static const Strings ko = Strings(Lang.ko);
  static const Strings en = Strings(Lang.en);

  static Strings of(Lang lang) => lang == Lang.ko ? ko : en;

  final Lang lang;

  String _pick(String ko, String en) => lang == Lang.ko ? ko : en;

  // ── 명부(시작 화면) ────────────────────────────────────────────────────

  String get tagline => _pick('절차적 2.5D 아이소메트릭', 'Procedural 2.5D isometric');

  String heroesTab(int n) => _pick('캐릭터  $n', 'CHARACTERS  $n');

  String monstersTab(int n) => _pick('몬스터  $n', 'MONSTERS  $n');

  String get heroesHint => _pick(
        '캐릭터를 선택하면 게임 맵에 입장합니다',
        'Pick a character to enter the game map',
      );

  String get monstersHint => _pick(
        '맵에서 마주칠 상대들 — 전원이 한 마리씩 배치됩니다',
        'What waits out there — one of each is placed on the map',
      );

  /// 명부 필터의 '전체'. 뒤에 인원수가 붙는다.
  String allFilter(int n) => _pick('전체  $n', 'ALL  $n');

  String get enterMap => _pick('게임 맵 입장', 'ENTER THE MAP');

  String get monsterLocked => _pick(
        '몬스터는 조작할 수 없다 — 맵에서 적으로 만난다',
        'Monsters are not playable — you meet them on the map',
      );

  /// 키보드 조작 안내. 마우스만 쓰는 사람은 몰라도 되지만, 25 명을
  /// 훑을 때는 화살표가 훨씬 빠르다.
  String get pickHint => _pick(
        '↑ ↓ ← → 로 고르고  ·  Enter 로 입장  ·  카드를 두 번 누르면 바로 입장',
        'Arrows to browse  ·  Enter to start  ·  double-click a card to jump in',
      );

  String get loadout => _pick('장비', 'LOADOUT');

  String get armorStat => _pick('방어', 'ARMOR');

  String get mightStat => _pick('완력', 'MIGHT');

  /// 이 인물이 어느 길로 만들어졌는가. 라이브러리 데모의 핵심 정보다 —
  /// 같은 명부에 700 줄짜리와 15 줄짜리가 섞여 서 있다.
  String get handDrawn => _pick('손그림 Artist', 'Hand-drawn Artist');

  String get declaredBuild => _pick('선언형 BuiltArtist', 'Declared BuiltArtist');

  String get shieldGear => _pick('방패', 'Shield');

  String get capeGear => _pick('망토', 'Cape');

  String get pauldronGear => _pick('견갑', 'Pauldrons');

  String get runeGear => _pick('발광 룬', 'Glow runes');

  // ── 게임 맵 ────────────────────────────────────────────────────────────

  String get backToRoster => _pick('← 명부', '← Roster');

  String mapHint(int kinds) => _pick(
        '맵을 클릭해 이동  ·  공격 중 한 번 더 눌러 3단 콤보  ·  몬스터 $kinds종 출현',
        'Click to move  ·  press Attack again mid-strike for a 3-hit combo  ·  $kinds kinds afield',
      );

  String get regenerateMap => _pick('맵 다시 생성', 'Regenerate map');

  // ── 소리 ───────────────────────────────────────────────────────────────

  String get sprint => _pick('달리기', 'Sprint');

  String get guard => _pick('방어', 'Guard');

  String get attack => _pick('공격', 'Attack');

  String get mute => _pick('음소거', 'Mute');

  String get soundOn => _pick('소리 켬', 'Sound on');

  /// 소리는 실행 중에 합성한다. 그동안 조용한 것이 고장이 아님을 알린다.
  String get bakingSound => _pick('소리 합성 중…', 'Synthesizing sound…');

  String get hideGrid => _pick('격자 끄기', 'Hide grid');

  String get showGrid => _pick('격자 켜기', 'Show grid');

  /// 조명 프리셋 이름. [LightRig.preset] 의 0..3 순서를 그대로 따른다.
  String lightPreset(int i) => switch (i) {
        0 => _pick('정오', 'Noon'),
        1 => _pick('황혼', 'Dusk'),
        2 => _pick('달빛', 'Moonlight'),
        _ => _pick('화톳불', 'Campfire'),
      };

  // ── 대치 화면 ──────────────────────────────────────────────────────────

  String get rosterTitle => _pick('경야의 명부', 'THE VIGIL ROSTER');

  String get rosterSubtitle => _pick(
        '누가 어떤 밤을 마주할 것인가 — 챔피언과 악몽을 하나씩 고르십시오.',
        'Who faces which night — choose one champion and one nightmare.',
      );

  String get champion => _pick('챔피언', 'CHAMPION');

  String get nightmare => _pick('악몽', 'NIGHTMARE');

  String get champions => _pick('챔피언', 'CHAMPIONS');

  String get nightmares => _pick('악몽', 'NIGHTMARES');

  String sexTally(int males, int females) => _pick(
        '남성 $males · 여성 $females',
        '$males male · $females female',
      );

  String aberrationTally(int n) => _pick('$n 종의 이형', '$n aberrations');

  String faceOff(String hero, String monster, String heroTitle,
          String monsterTitle) =>
      _pick(
        '$hero 이(가) $monster 을(를) 마주 봅니다 — $heroTitle vs $monsterTitle.',
        '$hero faces $monster — $heroTitle vs $monsterTitle.',
      );

  // ── 액터 뷰어 ──────────────────────────────────────────────────────────

  String get newSeed => _pick('새 시드', 'New seed');

  String get heroOrMonster => _pick('영웅 / 몬스터', 'Hero / Monster');

  String get lighting => _pick('조명', 'Lighting');

  String get turnLeft => _pick('왼쪽으로 회전', 'Turn left');

  String get turnRight => _pick('오른쪽으로 회전', 'Turn right');

  String get beast => _pick('야수', 'BEAST');

  String get speed => _pick('속도', 'SPEED');

  String facingLine(int seed, String weapon, String headGear, String facing) =>
      _pick(
        '시드 $seed  ·  $weapon  ·  $headGear  ·  $facing 방향',
        'seed $seed  ·  $weapon  ·  $headGear  ·  facing $facing',
      );

  /// 애니메이션 클립 이름. [Anims] 의 `name` 을 키로 쓴다.
  String clip(String name) => switch (name) {
        'idle' => _pick('대기', 'Idle'),
        'wait' => _pick('기다림', 'Wait'),
        'walk' => _pick('걷기', 'Walk'),
        'run' => _pick('달리기', 'Run'),
        'dash' => _pick('돌진', 'Dash'),
        'attack' => _pick('공격', 'Attack'),
        'attack2' => _pick('역방향 베기', 'Reverse Cut'),
        'attack3' => _pick('내려치기 피날레', 'Overhead Finisher'),
        'shoot' => _pick('사격', 'Shoot'),
        'shoot2' => _pick('낮은 순간 사격', 'Low Snap Shot'),
        'shoot3' => _pick('강전 사격', 'Power Shot'),
        'cast' => _pick('비전 밀쳐내기', 'Arcane Thrust'),
        'cast2' => _pick('룬 휘두르기', 'Runic Sweep'),
        'cast3' => _pick('별빛 붕괴', 'Astral Rupture'),
        'hit' => _pick('피격', 'Hit'),
        'death' => _pick('죽음', 'Death'),
        _ => name,
      };

  // ── 캐릭터 작업대 ──────────────────────────────────────────────────────

  String get workbenchTitle => _pick('provis — 캐릭터 만들기', 'provis — Character maker');

  String get workbenchSubtitle =>
      _pick('캐릭터 하나 = 이 선언 하나', 'One character = one declaration');

  String get workbenchName => _pick('새 지원자', 'New Recruit');

  String get workbenchArtistTitle =>
      _pick('작업대에서 만드는 중', 'Under construction on the workbench');

  String get workbenchArtistBlurb => _pick(
        '왼쪽 값을 바꾸면 이 인물이 바뀐다.',
        'Change the values on the left and this person changes.',
      );

  String get portraitCaption =>
      _pick('명부 초상 — Artist.paint()', 'Roster portrait — Artist.paint()');

  String get turntableCaption => _pick(
        '게임 액터 — riggedFromArtist() · 걷기 · 8방향',
        'Game actor — riggedFromArtist() · walk · 8 facings',
      );

  String get pasteHint => _pick(
        '이 값을 그대로 characters/recruits.dart 에 붙여 넣으면 된다',
        'Paste this straight into characters/recruits.dart',
      );

  String get sampleBlurb => _pick('한 줄 소개.', 'One-line intro.');

  String get archetypeLabel => _pick(
        'archetype — 체형과 기본 장비의 대역',
        'archetype — the band of build and default gear',
      );

  String get headGearLabel => _pick(
        'headGear — 비워 두면 시드가 정한다. 반드시 명시할 것',
        'headGear — the seed decides if you leave it out. Always state it',
      );

  String get accentLabel => _pick(
        'accent — 이 색이 정체성이다',
        'accent — this color is the identity',
      );

  String get armorLabel => _pick(
        'armorHeaviness — 0 천, 1 판금',
        'armorHeaviness — 0 cloth, 1 plate',
      );

  /// 강조색 견본 이름.
  ///
  /// 견본은 색이 본체고 이름은 표시용이다. 언어를 바꿔도 고른 색이 유지되어야
  /// 하므로 키는 문자열이 아니라 순번으로 잡는다.
  String accentSwatch(int i) => switch (i) {
        0 => _pick('전사 · 금', 'Warrior · gold'),
        1 => _pick('전사 · 주홍', 'Warrior · scarlet'),
        2 => _pick('마법사 · 청', 'Mage · blue'),
        3 => _pick('마법사 · 보라', 'Mage · violet'),
        4 => _pick('궁수 · 연두', 'Ranger · green'),
        5 => _pick('군인 · 황토', 'Soldier · ochre'),
        6 => _pick('사이보그 · 청록', 'Cyborg · cyan'),
        _ => _pick('사이보그 · 주황', 'Cyborg · orange'),
      };

  // ── 패키지 열거형 ──────────────────────────────────────────────────────
  //
  // provis 는 라이브러리이므로 영어 한 벌만 들고 있다. 예제 앱이 한국어를
  // 얹는 자리가 여기다 — 패키지 API 를 건드리지 않고 표시만 바꾼다.

  String job(Archetype a) => switch (a) {
        Archetype.knight => _pick('기사', 'Knight'),
        Archetype.berserker => _pick('광전사', 'Berserker'),
        Archetype.ranger => _pick('궁수', 'Ranger'),
        Archetype.mage => _pick('마법사', 'Mage'),
        Archetype.assassin => _pick('암살자', 'Assassin'),
        Archetype.paladin => _pick('성기사', 'Paladin'),
      };

  String sex(Sex s) => switch (s) {
        Sex.male => _pick('남성', 'Male'),
        Sex.female => _pick('여성', 'Female'),
      };

  String weapon(WeaponKind w) => switch (w) {
        WeaponKind.sword => _pick('검', 'Sword'),
        WeaponKind.greatsword => _pick('대검', 'Greatsword'),
        WeaponKind.axe => _pick('도끼', 'Axe'),
        WeaponKind.staff => _pick('지팡이', 'Staff'),
        WeaponKind.spear => _pick('창', 'Spear'),
        WeaponKind.daggers => _pick('쌍단검', 'Twin daggers'),
        WeaponKind.bow => _pick('활', 'Bow'),
        WeaponKind.none => _pick('맨손', 'Unarmed'),
      };

  String headGear(HeadGear h) => switch (h) {
        HeadGear.none => _pick('맨머리', 'Bare head'),
        HeadGear.circlet => _pick('서클릿', 'Circlet'),
        HeadGear.hood => _pick('후드', 'Hood'),
        HeadGear.halfHelm => _pick('반투구', 'Half-helm'),
        HeadGear.fullHelm => _pick('전신투구', 'Full helm'),
        HeadGear.hornedHelm => _pick('뿔투구', 'Horned helm'),
      };

  String camp(Camp c) => switch (c) {
        Camp.player => _pick('영웅', 'Hero'),
        Camp.monster => _pick('몬스터', 'Monster'),
      };
}
