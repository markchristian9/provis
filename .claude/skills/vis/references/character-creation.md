# 캐릭터 만들기 — 상세

## 목차

1. [두 가지 길과 선택 기준](#두-가지-길과-선택-기준)
2. [CharacterBuild — 정체성 선언](#characterbuild--정체성-선언)
3. [팔레트 — 넷만 고르면 된다](#팔레트--넷만-고르면-된다)
4. [직업별 대역표](#직업별-대역표)
5. [BuiltArtist — 선언만으로 캐릭터](#builtartist--선언만으로-캐릭터)
6. [손그림 Artist 에 build 잇기](#손그림-artist-에-build-잇기)
7. [검증 — 초상과 게임 액터 대조](#검증--초상과-게임-액터-대조)
8. [흔한 실패와 원인](#흔한-실패와-원인)
9. [렌더러가 파츠를 그리는 순서](#렌더러가-파츠를-그리는-순서)

---

## 두 가지 길과 선택 기준

캐릭터는 화면에 **두 곳**에 나타난다.

- **명부 초상** — 정지한 3/4 각도. 가장 예쁘게 보여야 하는 곳.
- **게임 액터** — 맵에서 걷고 8방향으로 돈다.

이 둘이 같은 인물로 보여야 한다는 것이 캐릭터 시스템의 유일한 어려운 요구다. 두 길은 이 문제를 다르게 푼다.

| | 선언형 `BuiltArtist` | 손그림 `Artist` |
|---|---|---|
| 분량 | 15~40줄 | 700~1300줄 |
| 초상을 그리는 코드 | `HumanoidRenderer` | 직접 짠 `paint()` |
| 게임 액터를 그리는 코드 | **같은 `HumanoidRenderer`** | `HumanoidRenderer` |
| 어긋날 수 있는가 | **불가능** | 가능 — `build` 로 이어야 한다 |
| 개성의 상한 | 명세가 표현하는 범위 | 없음 |

**대다수는 선언형이 맞다.** 손그림은 그 캐릭터가 게임의 얼굴이고, 명세로 표현할 수 없는 형상(용의 단일 스파인, 어깨가 머리의 5배인 괴물)이 필요할 때만 고른다.

`example/lib/characters/` 가 두 방식을 나란히 보여 준다 — `aldric.dart` 등 5종이 손그림, `recruits.dart` 20종이 선언형이다.

---

## CharacterBuild — 정체성 선언

`lib/src/actor/character_build.dart`

```dart
class CharacterBuild {
  const CharacterBuild({
    required this.archetype,   // 체형·기본 장비의 대역
    this.sex,
    this.palette,              // ★ 정체성의 핵심
    this.headGear,
    this.weapon,
    this.hasCape,
    this.hasPauldrons,
    this.hasShield,
    this.armorHeaviness,       // 0 = 천, 1 = 판금
    this.muscle,               // 0..1
    this.hairLength,           // 0..1
    this.glowRunes,
    this.heightScale = 1.0,    // 거인 1.2, 소인 0.8
    this.beast = false,        // 짐승형 골격
    this.seed,
  });

  HumanoidSpec toSpec(int fallbackSeed) { … }
}
```

**지정하지 않은 항목은 시드 생성기가 채운다.** 이것이 장점이자 함정이다 — 최소한만 선언해도 원형에 맞는 캐릭터가 나오지만, 비워 둔 항목은 매번 예측할 수 없다.

**반드시 명시할 것**

| 항목 | 이유 |
|---|---|
| `palette` | 비우면 게임 액터의 색이 시드에서 나와 초상과 어긋난다 |
| `headGear` | 비우면 후드를 원하지 않은 마법사가 후드를 쓰고 나온다. 장식이 없으면 `HeadGear.none` 을 **명시** |
| `weapon` | 비우면 궁수가 도끼를 들 수 있다 |

**비워 두어도 되는 것**: `muscle`·`hairLength`·`armorHeaviness` 는 원형 대역 안에서 흔들려도 정체성이 흔들리지 않는다.

### archetype 이 결정하는 것

`Archetype.{knight, berserker, ranger, mage, assassin, paladin}`

체형 비율(어깨·허리·팔다리 굵기), 기본 장비 후보, 기본 갑옷 비중을 한꺼번에 정한다. 모든 파라미터를 독립적으로 무작위화하면 "특징 없는 평균"만 쏟아지므로, **원형을 먼저 뽑고 그 안에서 변주**하는 것이 절차적 생성의 기본형이다.

원형은 직업 이름이 아니라 **체형 대역**으로 고른다. 예를 들어 사이보그 중장 보병은 `paladin`(중장·망토), 정찰기는 `ranger`(경장·민첩)가 맞다. 이름이 아니라 실루엣이 기준이다.

---

## 팔레트 — 넷만 고르면 된다

```dart
Palette paletteOf({
  required Color skin,
  required Color hair,
  required Color cloth,
  required Color accent,
  Color? metal, Color? leather, Color? eye, Color? glow,
})
```

`Palette` 는 11색이지만 넷만 받고 나머지는 파생시킨다. 열한 색을 손으로 고르면 조화가 깨지기 쉽고, 무엇보다 지루하다.

**`accent` 가 그 캐릭터의 정체성이다.** 명부 카드 테두리, 눈, 발광, 역광, 트림 밴드가 전부 여기서 나온다. 조명을 지정하지 않은 `BuiltArtist` 는 이 색을 림라이트에 실어 주므로, 은색 판금 캐릭터가 여럿이어도 실루엣 가장자리에서 서로 갈린다.

### 대안 — 강조색만으로 물들이기

```dart
Palette tintedPalette(Color accent, Rng r, {bool monster = false})
```

옷·강조·발광·눈만 갈아 끼우고 피부·금속은 생성기에 맡긴다. 전부 한 색으로 칠하면 단색 인형이 되므로, **색이 얹히는 자리를 한정하는 것**이 오히려 정체성을 살린다. 몬스터에 특히 잘 맞는다.

---

## 직업별 대역표

`example/lib/characters/recruits.dart` 20종이 따르는 규칙이다. 직업마다 색 대역을 갈라 두면 명부를 훑을 때 **이름보다 역할이 먼저 읽힌다.**

| 직업 | 색 대역 | archetype | 무기 | armorHeaviness |
|---|---|---|---|---|
| 전사 | 붉은·철 | knight · berserker · paladin | sword · greatsword · spear | 0.45~1.0 |
| 마법사 | 청보라 | mage | staff | 0.02~0.2 |
| 궁수 | 초록·흙 | ranger | bow | 0.2~0.35 |
| 군인 | 카키·회청 | knight · paladin · ranger | spear · sword · axe | 0.4~0.8 |
| 사이보그 | 청록·주황 | 임의 + `glowRunes: true` | 임의 | 0.2~1.0 |

사이보그는 archetype 을 가리지 않는다. **룬 대신 회로가 빛나는 것**이 정체성이고, 그것은 `glowRunes` 와 청록·주황 강조색이 만든다.

---

## BuiltArtist — 선언만으로 캐릭터

`lib/src/actor/built_artist.dart`

```dart
final maevis = BuiltArtist(
  id: 'maevis',
  name: 'Maevis',
  title: 'Weaver of Cold Lanterns',
  blurb: '차가운 등불을 엮어 길을 밝힌다.',
  build: CharacterBuild(
    archetype: Archetype.mage,
    sex: Sex.female,
    palette: paletteOf(
      skin: Color(0xFFE8C4A0), hair: Color(0xFFDCE8F4),
      cloth: Color(0xFF3B2E6E), accent: Color(0xFF9A6BFF),
    ),
    weapon: WeaponKind.staff,
    headGear: HeadGear.none,
    hasCape: true, glowRunes: true,
    hairLength: 0.9, armorHeaviness: 0.02,
  ),
  light: LightRig.spectral,       // 생략하면 accent 기반 리그가 붙는다
  camp: Camp.player,              // 기본값
  portraitClip: 'wait',           // 초상에서 재생할 클립
  portraitYaw: 0.62,              // 3/4 각도. 0 은 완전 정면
);
```

`BuiltArtist` 는 `Artist` 의 하위 타입이므로 명부·갤러리·`riggedFromArtist` 어디에나 그대로 들어간다.

**초상이 게임 액터와 같은 `HumanoidRenderer` 로 그려진다** — 이 한 가지 사실이 두 화면의 불일치를 구조적으로 불가능하게 만든다.

### 새 캐릭터 추가 절차

1. `example/lib/characters/recruits.dart` 에 `BuiltArtist` 하나를 쓴다
2. 파일 끝 `recruits` 목록에 이름을 넣는다
3. `flutter test test/identity_sheet_test.dart` 로 시트를 뽑아 눈으로 본다

`roster.dart` 는 `recruits` 를 재수출하므로 UI 는 손댈 필요가 없다.

---

## 손그림 Artist 에 build 잇기

손그림 캐릭터의 `paint()` 는 초상만 그린다. 게임 맵에서는 골격 액터가 필요하고, 그 액터는 `build` 를 통해서만 원본의 색과 장비를 알 수 있다.

```dart
class Seraphine extends Artist {
  @override
  Color get accent => const Color(0xFF57E8FF);

  @override
  CharacterBuild get build => CharacterBuild(
        archetype: Archetype.mage,
        sex: Sex.female,
        palette: paletteOf(
          skin: const Color(0xFFE0B49C),
          hair: const Color(0xFFCFF6FF),   // 초상의 은발
          cloth: const Color(0xFF2A4A72),  // 초상의 파란 로브
          accent: accent,
          metal: const Color(0xFF9BB0C6),
        ),
        weapon: WeaponKind.staff,
        headGear: HeadGear.none,
        hasCape: true,
        armorHeaviness: 0.04,
        hairLength: 0.95,
        muscle: 0.25,
        glowRunes: true,
      );
}
```

**색은 초상 코드에서 실제로 쓴 값을 가져온다.** 눈으로 비슷해 보이는 값을 새로 고르지 말 것 — 그 차이가 곧 "다른 사람"이다.

```bash
# 그 캐릭터가 실제로 쓰는 색 빈도순
grep -oE "const Color\(0x[0-9A-Fa-f]{8}\)" seraphine.dart | sort | uniq -c | sort -rn | head
```

오버라이드하지 않으면 `CharacterBuild.guess()` 가 이름과 강조색만 보고 추정한다. 최선을 다하지만 **원형과 색이 초상과 다를 수 있다.**

---

## 검증 — 초상과 게임 액터 대조

`example/test/identity_sheet_test.dart`

```bash
cd example
flutter test test/identity_sheet_test.dart
open build/art/identity_*.png
```

한 줄이 캐릭터 하나다. 맨 왼쪽이 명부 초상, 오른쪽 여덟 칸이 게임 맵에서 한 바퀴 도는 모습이다.

**확인할 것**

- 머리·옷·강조색이 초상과 이어지는가
- 초상이 지팡이면 맵에서도 지팡이인가
- 여덟 방향이 실제로 다른가 — 남쪽 앞모습, 북쪽 뒷모습, 동/서 옆모습

이 종류의 회귀는 컴파일러도 단위 테스트도 잡지 못한다. 양쪽 다 멀쩡히 돌기 때문이다. **두 그림을 나란히 놓고 사람이 보는 것**만이 검증이 된다.

같은 파일에 기계가 잡을 수 있는 것 하나가 들어 있다 — 모든 캐릭터의 `build.palette` 가 비어 있지 않은지 검사한다.

---

## 흔한 실패와 원인

| 증상 | 원인 | 고치는 곳 |
|---|---|---|
| 명부와 게임 화면이 다른 인물 | `build` 미오버라이드 → `guess()` 가 추정 | 캐릭터에 `build` 선언 |
| 마법사가 후드를 쓰고 나옴 | `headGear` 미지정 → 생성기가 결정 | `headGear: HeadGear.none` 명시 |
| 얼굴이 없는 매끈한 공 | 머리카락·후드를 얼굴 **위에** 그림 | `_hairBack`(얼굴 전) / `_hairFront`(얼굴 후) 분리 — 이미 적용됨 |
| 어깨가 머리보다 큼 | 폴드론이 어깨 관절 중심에 과대 배치 | 팔 방향으로 밀고 크기 축소 — 이미 적용됨 |
| 칼끝이 지면을 뚫음 | 손목 각도를 그대로 따름 | 쉴 때는 세우고 휘두를 때 손을 따름 — 이미 적용됨 |
| 방패병이 맨손 | 렌더러에 방패 구현 없음 | `_shield()` — 이미 적용됨 |
| 허벅지가 거대한 흰 캡슐 | 다리 전체를 판금 관 하나로 칠함 | 쿠이스·그리브 조각으로 분리 — 이미 적용됨 |
| 팔이 몸통에 묻혀 사라짐 | 팔과 몸통이 같은 판금 재질 | 가까운 팔 밑에 어두운 윤곽 — 이미 적용됨 |
| 은색 캐릭터가 다 비슷 | 조명이 전부 같음 | `accent` 를 림라이트에 — `BuiltArtist` 기본 동작 |

"이미 적용됨" 은 `lib/src/actor/humanoid_renderer.dart` 에 들어 있다는 뜻이다. **같은 실수를 다시 하지 않도록 해당 코드의 주석에 이유가 적혀 있다** — 고칠 때 먼저 읽을 것.

---

## 렌더러가 파츠를 그리는 순서

`HumanoidRenderer.paint()` 의 순서는 임의가 아니다. 하나를 옮기면 다른 것이 가려진다.

```
접지 그림자 (아이소 평면 — 세로 단축 바깥)
└ 세로 단축 적용
  ├ 꼬리 (짐승형)
  ├ 먼 쪽 다리 · 먼 쪽 팔 · 방패      ← 방패는 그것을 든 팔과 같은 깊이
  ├ 망토 (뒤에서 볼 때)
  ├ 몸통
  ├ 머리
  │  ├ 목
  │  ├ 뒷머리 · 후드 뒤통수            ← 얼굴보다 먼저
  │  ├ 두개골
  │  ├ 얼굴 (눈·눈썹·입)
  │  ├ 옆얼굴 (코·턱)
  │  └ 앞머리 · 투구 · 후드 앞테두리   ← 얼굴보다 나중
  ├ 망토 (앞에서 볼 때)
  ├ 가까운 다리 · 가까운 팔
  ├ 무기
  └ 이펙트
```

**머리 안쪽 순서가 특히 취약하다.** 머리카락을 통째로 얼굴 뒤에 그리면 덩어리가 두개골보다 커서 이목구비를 전부 덮는다. 뒤통수 볼륨은 얼굴보다 먼저, 이마를 덮는 앞머리는 얼굴보다 나중에 — 이 분리가 있어야 둘 다 살아난다.

머리 로컬 좌표는 원점이 머리 중심, **+x 가 전방**, **-y 가 정수리**다. 눈은 `y ≈ -0.05·headLen`, 코는 `x ≈ 0.40·headLen` 에 있으므로, 앞머리가 `y > -0.10·headLen` 으로 내려오면 눈을 가린다.
