# PC 정체성 — 조작되는 몸 만들기

`lib/src/iso/artist_rig.dart`, `lib/src/actor/character_build.dart`, `lib/src/actor/spec.dart` 를 PC 관점에서 읽는다. **생김새를 만드는 법 자체는 `vis` 스킬의 캐릭터 워크플로우**에 있다. 여기는 그 결과물이 **플레이어의 손에 쥐여지는** 순간에만 생기는 요구사항을 다룬다.

## 목차

1. [PC 는 왜 기준이 다른가](#pc-는-왜-기준이-다른가)
2. [두 개의 몸](#두-개의-몸)
3. [riggedFromArtist — 정체성을 잇는 다리](#riggedfromartist--정체성을-잇는-다리)
4. [CharacterBuild — PC 관점의 필드표](#characterbuild--pc-관점의-필드표)
5. [무기 ↔ 클립 궁합](#무기--클립-궁합)
6. [키와 스케일](#키와-스케일)
7. [방향 — 8방향은 공짜다](#방향--8방향은-공짜다)
8. [짐승형 PC](#짐승형-pc)
9. [검증](#검증)
10. [흔한 실패](#흔한-실패)

---

## PC 는 왜 기준이 다른가

몬스터는 몇 초 보고 죽는다. 나무는 배경이다. **PC 는 화면 중앙에서 수십 시간 움직인다.** 그래서 다른 것 셋이 중요해진다.

**① 실루엣이 군중 속에서 즉시 찾아져야 한다.** 몬스터 여섯이 몰려든 화면에서 내 캐릭터를 못 찾으면 조작이 불가능하다. 판단 기준은 하나 — **스크린샷을 흑백으로 만들고 1초 안에 PC 를 짚을 수 있는가.** 짚을 수 없다면 셋 중 하나로 고친다.

| 수단 | 강도 | 대가 |
|---|---|---|
| `accent` 색을 몬스터 대역에서 떼어 놓는다 | 중 | 없음 — 가장 먼저 쓴다 |
| 키를 10~15% 키운다 | 강 | 지면 격자가 묻힐 수 있다 |
| 헤드기어·망토로 실루엣 상단에 신호를 준다 | 강 | 캐릭터 컨셉을 제약한다 |

**② 뒷모습이 앞모습만큼 중요하다.** 아이소 게임에서 북쪽으로 걸어가는 시간은 전체의 1/4 이다. 초상만 보고 만족하면 안 된다 — 게임의 절반은 뒤통수를 본다. `facing_sweep_test.dart` 가 8방향을 한 줄에 뽑는다.

**③ 무기가 곧 조작감이다.** `WeaponKind` 는 그림 문제가 아니라 **어느 공격 클립을 쓸지의 문제**다. 대검을 쥐여 놓고 단검 타이밍의 클립을 재생하면 손과 눈이 어긋난다. → [무기 ↔ 클립 궁합](#무기--클립-궁합)

---

## 두 개의 몸

한 캐릭터에 몸이 둘 있다. **어느 쪽을 쓰는지 먼저 정한다.**

| | `IsoActor` (Artist) | `RiggedIsoActor` (골격) |
|---|---|---|
| 품질 | 가장 높다 — 손으로 그린 3/4 초상 | 중간 — 절차적 골격 렌더 |
| 걸을 때 | **정지 자세로 미끄러진다** | 다리가 교차한다 |
| 방향 | 좌우 반전만 | **연속 yaw** — 북=뒷모습, 남=앞모습 |
| 포즈 | 고정 | `Pose` 를 매 프레임 푼다 |
| 공격 | **불가능** | `play('attack')` |
| 쓰는 곳 | 갤러리 · 명부 카드 · 컷신 | **PC · 몬스터 · NPC** |

**PC 는 예외 없이 `RiggedIsoActor` 다.** 공격 애니메이션은 `Pose` 를 매 프레임 푸는 쪽에만 존재한다.

---

## `riggedFromArtist` — 정체성을 잇는 다리

```dart
RiggedIsoActor riggedFromArtist(Artist a, {required Offset tile, double height = 200});
```

초상용 `Artist` 를 게임에서 걷는 액터로 바꾼다. **두 가지로 정체성을 잇는다.**

```dart
final fallback = Rng.fromString(a.id).intRange(1, 0x7FFFFFF);   // ① 시드를 id 에서
final spec = a.build.toSpec(fallback);                          // ② build 로 색·장비
```

**① 시드가 `id` 문자열에서 나온다.** `Rng.fromString('aldric')` 이므로 같은 캐릭터는 언제나 같은 체형·장비를 갖는다. 게임에 들어갈 때마다 몸이 바뀌면 같은 인물로 안 보인다.

**② `Artist.build` 가 색과 장비를 결정한다.** 손그림 `Artist` 에서 `build` 를 오버라이드하지 않으면 **명부와 게임 화면이 다른 인물이 된다** — 실제로 은발 마법사를 골랐는데 맵에서는 금발 전사가 걸어 나온 적이 있다.

```dart
@override
CharacterBuild get build => CharacterBuild(
      archetype: Archetype.mage,
      sex: Sex.female,
      palette: paletteOf(skin: …, hair: …, cloth: …, accent: accent),
      weapon: WeaponKind.staff,
      headGear: HeadGear.none,     // 초상에 없으면 반드시 none 을 **명시**
      hasCape: true, glowRunes: true,
    );
```

**완전히 같은 그림은 아니다.** 그건 캐릭터마다 측면·후면을 손으로 그려야 가능하다. 목표는 **색과 실루엣 계열을 유지한 대역**이다.

### 세밀하게 통제하고 싶다면

`riggedFromArtist` 는 편의 함수다. 직접 조립하면 `Body`·`Palette`·`Animator` 를 전부 지정할 수 있다.

```dart
final actor = RiggedIsoActor(
  renderer: HumanoidRenderer(
    HumanoidSpec.generate(seed, forceArchetype: Archetype.knight),
    body: Body.humanoid(Rng(seed), height: 190),   // 체형을 직접
    palette: myPalette,                            // 비우면 spec.palette
  ),
  tile: start,
  height: 200,
  iso: scene.iso,                                // 보폭 동기화가 쓴다
  // runThreshold 는 비워 둔다 — gaitCrossover 가 골격에서 자동으로 정한다
);
```

**`runThreshold` 에 고정 숫자를 박지 않는다.** `null`(기본)이면 `gaitCrossover` — 걷기와 달리기가 각자 발을 미끄러뜨리지 않고 낼 수 있는 속도(`naturalSpeed`)의 기하평균이다. 고정값은 타일 크기나 캐릭터 키가 바뀌는 순간 반드시 틀리고, 다리가 짧은 몬스터는 같은 속도에서 더 일찍 뛰어야 한다.

---

## `CharacterBuild` — PC 관점의 필드표

| 필드 | 타입 | PC 에서의 의미 |
|---|---|---|
| `archetype` | `Archetype` (필수) | 체형·기본 장비의 **대역**. knight · berserker · ranger · mage · assassin · paladin |
| `sex` | `Sex?` | 비우면 시드가 정한다 |
| `palette` | `Palette?` | `paletteOf(skin:, hair:, cloth:, accent:)` — **넷만 고르면 나머지 일곱은 파생** |
| `weapon` | `WeaponKind?` | **반드시 명시.** 비우면 시드가 정해 원치 않은 무기가 나온다 |
| `headGear` | `HeadGear?` | **반드시 명시.** 비우면 마법사가 원치 않은 후드를 쓴다. 없으면 `HeadGear.none` |
| `hasCape` | `bool?` | 망토는 실루엣을 크게 바꾼다. PC 식별에 유효 |
| `hasPauldrons` | `bool?` | 어깨 폭 — 군중 속 식별에 가장 강한 신호 |
| `hasShield` | `bool?` | 왼손을 차지한다. 양손 무기와 함께 쓰지 않는다 |
| `armorHeaviness` | `double?` 0..1 | 무거울수록 느린 공격 클립이 어울린다 |
| `muscle` | `double?` 0..1 | 체형 |
| `hairLength` | `double?` 0..1 | 길수록 `capeFlow` 효과가 눈에 띈다 |
| `glowRunes` | `bool?` | 발광. **켰으면 주변 수광 파츠에도 같은 색 반사광이 필요** |
| `heightScale` | `double` = 1.0 | 기본 키의 배수 |
| `beast` | `bool` = false | 짐승 골격 — 무기를 그리지 않는다 |
| `seed` | `int?` | 비우면 `id` 문자열에서 파생 |

**`accent` 가 그 캐릭터의 정체성이다** — 명부 카드 테두리, 눈, 발광, 역광, 무기 궤적 색(`pal.glow` 와 섞인다)이 전부 여기서 나온다. **PC 의 `accent` 는 몬스터가 쓰지 않는 대역에서 고른다.**

---

## 무기 ↔ 클립 궁합

`WeaponKind` 는 그림이 아니라 **타이밍의 선언**이다.

| `WeaponKind` | 렌더 | 어울리는 공격 | `duration` | `ranged` |
|---|---|---|---|---|
| `sword` | 손 방향으로 눕는 검날 | `attack` 표준 | 0.86 | — |
| `greatsword` | 긴 검날 · 양손 | 예비·회복을 늘린 변형 | 1.10~1.20 | — |
| `axe` | 도끼머리 | 위→아래 궤적 | 0.95 | — |
| `spear` | `pole` 로 세워 쥔 장병기 | **찌르기** — `rootX` 주도 | 0.42~0.50 | — |
| `daggers` | 짧은 날 | 경공격 · 콤보 | 0.30~0.35 | — |
| `staff` | 자루 + 발광 오브(`glowPath`) | **시전** — 예비 70% | 1.20 | — |
| `bow` | `_bow()` — 활 + 시위 + 화살 | `shoot` | 1.15 | **`true` 필요** |
| `none` | 안 그린다 | 맨손 | 0.55 | — |

**장병기·도검은 `weaponSwing` 으로 각도가 바뀐다.** 렌더러가 쉴 때는 몸의 수직축에 가깝게 세워 쥐고, `weaponSwing` 이 오를수록 손 방향을 따라간다. 이 처리가 없으면 신장 절반짜리 칼날이 지면을 뚫는다. → [attack-clip.md](attack-clip.md#렌더러가-읽는-세-트랙)

**활은 `actor.ranged = true` 를 켜야 한다.** 안 켜면 근접 무기로 그려진다. 표준은 `shoot` 클립을 재생하는 동안만 켜는 것이다.

```dart
actor.ranged = actor.state == 'shoot' || spec.weapon == WeaponKind.bow;
```

**`hasShield` 는 `farArm` 을 차지한다.** 공격 클립의 `farShoulder`·`farElbow` 커브가 방패를 앞으로 가져오는 모양이어야 방어 자세로 읽힌다 — `Anims.attack` 은 임팩트에서 `farShoulder` 1.45 로 올린다.

---

## 키와 스케일

```dart
final s = a.height / a.renderer.body.height;   // paintRiggedActor 안
canvas.scale(s);
```

`height` 는 **화면상 픽셀 키**다. `body.height`(논리 키)와의 비율로 스케일한다.

- **타일 폭의 1.2~1.6배.** `IsoView(tileWidth: 156)` 이면 187~250px.
- 넘으면 지면 격자가 묻혀 **2.5D 가 아니라 평면 게임**으로 보인다.
- PC 는 대역의 위쪽(1.4~1.6), 잡몹은 아래쪽(1.2~1.3), 보스는 넘어도 된다(그것이 논제이므로).

### 크기의 유일한 기준 — 1 타일 = 1 미터

`lib/src/iso/world_scale.dart` 가 이 저장소의 자다. 기물과 캐릭터가 각자 국소 픽셀로 그리면 **각자 그럴듯한 숫자를 넣었는데도 한 화면에 모으면 사람이 2층집보다 크다.**

```
국소 1 타일 = tileWidth/√2 px        (iso.worldScale)
```

`squash` 가 약분되므로 **카메라 고도각과 무관하다** — 타일 비율을 바꿔도 사람과 집의 비례가 안 흔들린다. `example/test/scale_audit_test.dart` 가 맵 위의 모든 것을 미터로 환산해 한 표에 놓고, 현실 대역을 벗어난 것이 있으면 실패한다.

**보폭 동기화도 이 자를 쓴다.** `cycleTiles()` 가 다리 길이(px)를 `iso.worldScale` 로 나눠 타일 단위로 바꾼다. 그래서 액터의 `iso` 가 맵과 다르면 **발이 미끄러진다.**

`HumanoidRenderer` 가 **내부에서** 세로 단축(`iso.squash`)과 좌우 미러를 처리한다. 호출부에서 `canvas.scale(1, iso.squash)` 를 또 걸지 않는다 — 이중으로 눌린다.

**발 접지 자동 보정**이 들어 있다.

```dart
final low = _lowestFoot(sk);
if (low > 0.5) sk = solve(b, p.copyWith(rootY: p.rootY - low / b.height), yaw: solveYaw);
```

발이 지면 아래로 내려가면 골반을 들어 올려 붙인다. 그래서 **클립에서 `rootY` 를 대충 줘도 발이 땅을 뚫지 않는다.** 반대로 발이 지면 위로 뜨면 `airborne` 으로 계산되어 그림자가 작아진다 — 공중 공격이 자동으로 처리된다.

---

## 방향 — 8방향은 공짜다

`yaw` 는 **임의의 실수**다. 스프라이트를 굽지 않으므로 8·16·32·360 분할의 렌더 비용이 실측상 같다. **기본은 연속이며**, 그리드 전투·방향별 히트박스처럼 이유가 있을 때만 `Facing(yaw).snap(n)` 을 쓴다.

`Facing` 이 방향별 형상을 연속으로 준다. 전부 `cos(yaw)`·`sin(yaw)` 의 함수이므로 8단계로 끊기지 않는다.

| 게터 | 의미 |
|---|---|
| `toward` | −1(후면) … 0(측면) … +1(정면) |
| `profile` | 0(정면·후면) … 1(완전 측면) |
| `faceVisible` | 얼굴이 보이는 정도 0..1. 측면을 조금 지나서까지 남는다 |
| `bothEyes` | 두 눈이 다 보이는 정도 0..1 |
| `headTurn` | 머리의 3/4 회전량 −1..+1 |
| `profileJut` | 코·턱이 실루엣 밖으로 나오는 정도 |
| `nearSide` | +1 이면 화면 오른쪽 사지가 near |
| `showBack` | 뒤통수를 그려야 하는가 |
| `octant` | 0=S 1=SE 2=E 3=NE 4=N 5=NW 6=W 7=SW |

**PC 의 방향은 두 곳에서 온다.** 이동 중에는 `ctrl.yaw`(진행 방향), 공격 중에는 조준 대상. 후자는 `follow()` **뒤에** 덮어써야 한다. → [combat-loop.md](combat-loop.md#조준--이동-없이-도는-법)

**회전은 즉시 스냅하지 않는다.** `IsoController.turnTime` 기본 0.14초, 조준은 0.08초. 절차적 렌더러라 중간 각도를 그릴 수 있고, 이것만으로 스프라이트 게임과 확연히 다른 부드러움이 나온다.

---

## 짐승형 PC

```dart
RiggedIsoActor(
  renderer: HumanoidRenderer(
    spec,
    body: Body.beast(Rng(seed ^ 0x5EED), height: spec.height * 1.1),
    palette: Palette.monster(Rng(seed ^ 0xB0A5)),
    beast: true,
  ),
  tile: start, height: 215,
);
```

같은 골격 코드에 **비율과 색만** 바꿔 얹는다. 다리가 짧고 팔이 길며 구부정하므로, **같은 걷기 클립이 전혀 다른 걸음걸이로 읽힌다** — 클립을 새로 만들 필요가 없다. `CharacterBuild(beast: true)` 로도 같은 결과가 나온다.

**공격은 다르다.** `_weapon()` 이 `beast` 면 즉시 반환한다 — 짐승의 무기는 발톱과 이빨이다. 그래서 짐승형 공격 클립은 무기 궤적 대신 이렇게 만든다.

- `rootX` 돌진을 크게 (0.09 이상) — 몸통 전체가 무기다
- `mouth` 1.0 — 무는 동작
- `squash` 진폭을 키운다 (0.96~1.03) — 탄성
- `weaponSwing` 은 그대로 둔다 — 궤적은 안 그려지지만 다른 이펙트의 훅으로 쓸 수 있다

---

## 검증

```bash
cd example

# ① 작업대 — 값을 바꾸면 명부 초상과 게임 액터 8방향이 함께 갱신된다
flutter run -t lib/create_character.dart

# ② 뷰어 — 전 클립을 버튼으로. 속도 슬라이더로 임팩트 프레임을 본다
flutter run -t lib/viewer.dart

# ③ 초상 ↔ 게임 액터 대조. build.palette 가 비어 있으면 실패한다
flutter test test/identity_sheet_test.dart && open build/art/identity_*.png

# ④ 8방향 스윕
flutter test test/facing_sweep_test.dart

# ⑤ 전 클립 × 4시점 시트
flutter test test/snapshot_test.dart
```

**캐릭터를 만들 때는 작업대부터 띄운다.** 하단에 그대로 붙여 넣을 수 있는 `BuiltArtist` 선언이 나온다.

**PC 는 ③을 반드시 통과해야 한다.** 명부에서 고른 인물과 맵에 서는 인물이 다르면 그 게임은 그 순간 신뢰를 잃는다.

---

## 흔한 실패

| 증상 | 원인 | 처방 |
|---|---|---|
| 걸을 때 자세가 그대로다 | `IsoActor`(Artist) 를 PC 로 씀 | `RiggedIsoActor` + `riggedFromArtist` |
| 북쪽으로 가도 뒷모습이 안 나온다 | 같은 원인 | 같은 처방 |
| 공격을 재생할 수 없다 | 같은 원인 | 같은 처방 |
| 영원히 걷기만 한다 | `runThreshold` 에 고정 숫자를 박음 | 비워 둔다 — `gaitCrossover` 가 정한다 |
| 발이 얼음판처럼 미끄러진다 | 액터의 `iso` 가 맵과 다름 | `actor.iso = scene.iso` |
| 사람이 2층집보다 크다 | 국소 픽셀을 각자 기준으로 고름 | `world_scale.dart` — 1 타일 = 1 m |
| 명부와 게임 화면이 다른 인물 | `Artist.build` 미오버라이드 | `build` 에 실제 색·장비 선언 |
| 마법사가 원치 않은 후드를 쓴다 | `headGear` 미지정 → 시드가 결정 | `HeadGear.none` 을 **명시** |
| 들고 있는 무기가 매번 다르다 | `weapon` 미지정 | 명시 |
| 활을 쥐었는데 검이 나온다 | `actor.ranged` 미설정 | `ranged = true` |
| 게임에 들어갈 때마다 몸이 바뀐다 | `id` 없이 난수 시드 | `Rng.fromString(id)` — `riggedFromArtist` 가 한다 |
| 군중 속에서 PC 를 못 찾는다 | `accent` 가 몬스터 대역과 겹침 | 색을 떼어 놓고 키를 10~15% 올린다 |
| 지면 격자가 안 보인다 | 캐릭터가 너무 큼 | 키를 타일 폭의 1.2~1.6배로 |
| 캐릭터가 세로로 찌그러진다 | 호출부에서 `iso.squash` 를 또 걸었다 | 렌더러가 내부에서 처리한다 |
| 여덟 방향이 전부 옆모습이다 | `solve` 에 `yaw` 미전달 | 렌더러가 `Facing` 에서 넘긴다 — `facing` 인자 확인 |
| 3/4 에서 얼굴이 갑자기 사라진다 | `toCamera` 로 이진 판정 | `faceVisible`·`bothEyes` 로 연속 알파 |
| 짐승형인데 검을 들었다 | `beast` 는 무기를 안 그린다 | 정상 동작. 공격은 돌진·`mouth` 로 |
| 방향 전환이 뚝뚝 끊긴다 | 즉시 스냅 | `turnTime` 0.14 / 조준 0.08 |
