# provis

**Procedural 2.5D isometric visuals for Flutter & Flame.**

스프라이트 시트 한 장 없이, 코드만으로 아이소메트릭 게임 화면을 그립니다.
캐릭터·몬스터부터 나무·바위·건물·물웅덩이까지, 그리고 그것들이 서 있는 지면과
클릭 이동까지 전부 런타임에 벡터 패스로 생성합니다.

```dart
import 'package:provis/provis.dart';
```

## 왜 스프라이트를 쓰지 않는가

이미지를 굽지 않는 대가로 세 가지를 얻습니다.

| | |
|---|---|
| **무한한 변주** | 시드 하나로 나무 1,000 그루가 전부 다르게 자랍니다. 아틀라스 용량은 0 입니다. |
| **살아 있는 조명** | 시각을 정오에서 황혼으로 바꾸면 캐릭터·건물·물·그림자가 **한꺼번에** 반응합니다. 다시 구울 것이 없습니다. |
| **해상도 무제한** | 벡터라 4K 에서도, 48px 썸네일에서도 같은 코드가 선명합니다. |

같은 규칙을 소리에도 적용합니다 — 발소리·검격·몬스터의 목소리·배경음까지
[런타임에 합성](#소리도-파일이-없습니다)하므로 오디오 파일도 0 입니다.

## 핵심 개념

### 재질은 19가지 `Finish`

각 재질이 **전용 알고리즘**을 갖습니다. 금속은 하늘·지평선·지면이 비치는 3단
환경 밴딩으로, 피부는 명암 경계에 배어나는 붉은 산란으로, 머리카락은 점이 아닌
띠 모양 광택으로 그립니다. 하나의 범용 그라디언트를 19번 재활용하지 않습니다.

```dart
paintSurface(canvas, path, Surface(color, Finish.metal), light, detail: 1.0);
```

`skin · metal · gold · cloth · leather · scale · chitin · fur · hair · bone ·
wood · bark · foliage · soil · gem · energy · slime · stone · membrane`

### 조명은 씬이 공유

```dart
final light = LightRig.preset(1);   // 0 정오 · 1 황혼 · 2 달빛 · 3 화톳불
```

`LightRig.dir` 은 **피사체가 광원을 바라보는 방향**입니다(빛이 나아가는 방향이
아닙니다). 씬의 모든 것이 같은 리그를 참조하므로, 하나를 바꾸면 화면 전체의
명암·그림자·반사가 함께 움직입니다.

### 아이소 투영은 접지점에만

```dart
const iso = IsoView(tileWidth: 156, tileHeight: 78);  // 2:1 → 카메라 고도각 30°
```

지면은 아이소 평면에 눕고, 캐릭터는 그 위에 **세워진 카드**입니다. 몸까지
투영하면 인체가 마름모로 찌그러집니다. 세로 단축(`iso.squash`)은 렌더 진입부에서
한 번만 겁니다.

## 빠른 시작

### 1. 맵을 채운다

```dart
final scene = IsoSceneComponent(
  iso: const IsoView(tileWidth: 156, tileHeight: 78),
  grid: IsoGrid(cols: 14, rows: 14),
  light: LightRig.dusk,
)..marker = MoveMarker();

// 숲 — 시드마다 종류·키·기울기가 흔들린다.
// 실루엣이 서로 다른 종을 섞어야 숲의 밀도가 올라간다.
scene.addProps(plantForest(
  seed: 42,
  tiles: [for (var i = 0; i < 12; i++) Offset(i * 1.1 + 1, 2.0)],
  kinds: [TreeKind.broadleaf, TreeKind.conifer, TreeKind.pine, TreeKind.bush],
));

// 건물 — 아이소에서 왼쪽 벽·오른쪽 벽·지붕 3면이 보인다.
// 마루 방향(ridgeAlongX)을 섞으면 마을이 한 방향으로 도열하지 않는다.
scene.addProp(PropInstance(
  prop: BuildingProp(seed: 7, tiles: const Size(2, 2), storeys: 2,
                     roof: RoofStyle.gable, wall: WallStyle.timber),
  tile: const Offset(5, 8),
));

// 물웅덩이 — 지면 평면에 눕고 하늘을 비춘다. 물가와 갈대가 함께 온다
scene.addProp(PropInstance(
  prop: WaterProp(seed: 3, radius: 130),
  tile: const Offset(9, 5),
));

// 언덕 — 지면 자체에 높이가 있다는 사실이 맵을 판에서 지형으로 바꾼다
scene.addProp(PropInstance(
  prop: MoundProp(seed: 5, radius: 150, rise: 48,
                  isoRatio: iso.elevationSin),
  tile: const Offset(2, 10),
));

// 발치의 작은 것들 — 화면의 밀도는 이것들이 만든다
scene.addProp(PropInstance(prop: GrassTuft(seed: 9), tile: const Offset(4, 6)));
scene.addProp(PropInstance(prop: FlowerBed(seed: 10), tile: const Offset(4, 7)));
```

기물을 `addProp` 으로 넣으면 **통행 격자도 함께 막힙니다.** 화면에는 나무가
있는데 캐릭터가 통과하는 일이 생기지 않습니다.

<details>
<summary>놓을 수 있는 기물 전부</summary>

| 파일 | 기물 |
|---|---|
| `tree.dart` | `TreeProp` — `broadleaf`·`conifer`·`pine`·`dead`·`blossom`·`willow`·`bush` |
| `building.dart` | `BuildingProp`(벽 5종 × 지붕 5종 × 표면 4종) · `WallProp` |
| `rock.dart` | `RockProp` · `PebbleField` |
| `water.dart` | `WaterProp` · `LavaProp` |
| `ground.dart` | `GroundPatch` · `PathPatch` |
| `flora.dart` | `GrassTuft` · `FlowerBed` · `StumpProp` · `LogProp` · `FenceProp` |
| `terrain.dart` | `MoundProp` |

**건물·담장·그루터기·통나무·울타리·언덕은 `isoRatio` 를 맵의
`iso.elevationSin` 과 맞춥니다.** 지면과 평행한 면(밑면·지붕·절단면)이
격자와 어긋나면 기물이 공중에 뜬 것처럼 보입니다.

</details>

### 2. 클릭으로 움직인다

```dart
final hero = IsoController(
  tile: const Offset(6.5, 10.5),
  grid: scene.grid,
  speed: 3.2,
);

// 탭 처리
void onTapDown(Offset localPosition) {
  final target = scene.tileAt(localPosition);
  hero.moveTo(target);            // 8방향 A*, 코너 컷 방지, 경로 평활화
  scene.marker!.ping(target);     // 눌렀다는 사실을 화면에 보여 준다
}

// 매 프레임
hero.update(dt);
actor.follow(hero, dt);   // 위치·방향·클립·보폭을 한 번에
```

목표가 벽이면 **가장 가까운 통행 가능한 타일**로 갑니다 — 벽을 눌렀다고 아무
반응이 없으면 조작이 고장난 것처럼 느껴지기 때문입니다.

방향 전환은 `turnTime`(기본 0.14초)에 걸쳐 최단 경로로 보간됩니다. 8방향으로
즉시 스냅하지 않는 이유는, 절차적 렌더러가 중간 각도를 그릴 수 있기 때문입니다.

`follow` 는 걷기/달리기를 **보폭에서** 고르고, 클립의 재생 배속을 실제 이동
속도에 맞춥니다 — 그래서 속도를 바꿔도 발이 미끄러지지 않습니다. 다만 보폭은
타일이 얼마나 큰지 알아야 계산되므로 액터에 맵과 **같은 `IsoView`** 를 줍니다.

```dart
final actor = riggedFromArtist(hero, tile: start, height: 200, iso: iso);
```

### 타격을 그림과 맞춘다

판정·타격음·이펙트를 프레임 번호가 아니라 **클립 위의 시점**에 겁니다.
프레임률이 흔들려도, 보폭 동기화로 배속이 바뀌어도 정확히 한 번 터집니다.

```dart
actor.play('attack');

// 매 프레임
if (actor.animator.fired.contains('strike')) {
  world.applyHit(actor);
  actor.animator.hitstop(0.06);   // 타격 프레임에서 시간을 잠깐 멈춘다
}
```

### 3. 캐릭터를 만든다

**선언 하나면 됩니다.** 명부 초상과 게임 맵의 액터가 같은 렌더러로 그려지므로
두 화면이 어긋날 수 없습니다.

```dart
final garran = BuiltArtist(
  id: 'garran',
  name: 'Garran',
  title: 'Shieldbearer of the Pass',
  blurb: '고갯길을 혼자 막아선 방패병.',
  build: CharacterBuild(
    archetype: Archetype.knight,       // 체형·기본 장비의 대역
    sex: Sex.male,
    palette: paletteOf(                // 넷만 고르면 나머지 일곱은 파생됩니다
      skin: Color(0xFFC08A66), hair: Color(0xFF3A2A1E),
      cloth: Color(0xFF7A2E2E), accent: Color(0xFFD9A441),
    ),
    weapon: WeaponKind.sword,
    headGear: HeadGear.halfHelm,
    hasShield: true, hasPauldrons: true,
    armorHeaviness: 0.9, muscle: 0.8,
  ),
);

// 명부에도, 맵에도 그대로 들어갑니다.
scene.rigged.add(riggedFromArtist(garran, tile: start, height: 195));
```

`accent` 가 그 캐릭터의 정체성입니다 — 눈, 발광, 트림, 역광이 전부 이 색에서
나옵니다. `headGear` 와 `weapon` 은 명시하세요. 비워 두면 시드 생성기가 정하므로
후드를 원하지 않은 마법사가 후드를 쓰고 나타납니다.

값을 바꿔 가며 만들고 싶으면 작업대를 띄우세요. 하단에 그대로 붙여 넣을 수 있는
선언이 나옵니다.

```bash
cd example && flutter run -t lib/create_character.dart
```

#### 손으로 그리기

명세로 표현할 수 없는 형상이 필요하면 `Artist` 를 직접 구현합니다. 개성의
상한이 없는 대신 한 명에 수백 줄이 듭니다.

```dart
class MyHero extends Artist {
  @override String get id => 'my_hero';
  @override String get name => 'Hero';
  @override Camp get camp => Camp.player;
  @override LightRig get light => LightRig.heroic;

  @override
  void paint(Canvas c, double t, {double detail = 1.0}) {
    final bob = breathe(t, amp: 3.4);          // 정지 상태에도 호흡
    groundShadow(c, const Offset(500, kGround), 240, 42);

    final torso = torsoShape(
      chest: Offset(500, kGround - 900 + bob),
      pelvis: Offset(500, kGround - 480),
      shoulderW: 150, chestW: 130, waistW: 96, hipW: 118,
    );
    paintSurface(c, torso, Surface(const Color(0xFF7A8AA8), Finish.metal), light,
        detail: detail);
    occlude(c, torso, light.dir);              // 겹친 파츠의 접촉 그림자
    rimBand(c, torso, light, width: 5);        // 실루엣을 배경에서 떼어낸다
  }
}
```

좌표계는 `kStage`(1000×1400), 발바닥이 `kGround`(1332)입니다. 같은 `t` 에는
언제나 같은 그림이 나와야 합니다(`math.Random` 대신 `Rng` 를 씁니다).

손으로 그린 캐릭터는 **`build` 를 반드시 오버라이드하세요.** 그것이 초상의 색과
장비를 게임 맵의 골격 액터로 넘기는 유일한 다리입니다. 빠뜨리면 명부에서 고른
인물과 맵에서 걷는 인물이 달라집니다.

```dart
@override
CharacterBuild get build => CharacterBuild(
      archetype: Archetype.mage,
      palette: paletteOf(skin: …, hair: …, cloth: …, accent: accent),
      weapon: WeaponKind.staff,
      headGear: HeadGear.none,   // 초상에 없으면 none 을 명시합니다
    );
```

### 4. 시드로 찍어낸다

이름 없는 군중은 `HumanoidSpec` 으로 생성합니다.

```dart
final spec = HumanoidSpec.generate(seed);   // 원형 → 체형 → 장비 → 팔레트
```

원형(knight/berserker/ranger/mage/assassin/paladin)을 먼저 뽑고 **그 원형의
겹치지 않는 대역 안에서만** 변주합니다. 파라미터를 각각 독립 무작위화하면
"특징 없는 평균"만 나옵니다.

## 방향은 연속이다

스프라이트 게임이 8방향에 묶이는 이유는 방향마다 이미지를 굽기 때문입니다.
provis는 매 프레임 골격을 다시 풀므로 `yaw` 가 임의의 실수이고, **방향 수에
따른 비용 증가가 없습니다.**

같은 캐릭터 200프레임 반복 렌더 실측:

| 분할 | 프레임당 |
|---|---|
| 8 | 418 µs |
| 16 | 295 µs |
| 32 | 260 µs |
| 360 | 284 µs |

차이는 측정 노이즈입니다. 그래서 기본은 스냅하지 않습니다 — `IsoController` 가
내는 연속 `yaw` 가 렌더러까지 그대로 갑니다.

```dart
facing.snap(16)   // 그리드 전투처럼 방향을 상태로 저장할 때만
facing.snap8 / snap16 / snap32
```

정면에서는 팔이 몸 옆으로 내려가고 다리가 좌우로 벌어지며, 측면에서는 코와 턱이
실루엣 밖으로 나옵니다. `solve(body, pose, yaw:)` 가 관절을 시상면·좌우·수직
세 성분으로 나눠 투영하기 때문입니다.

## 소리도 파일이 없습니다

그림에 스프라이트가 없는 것과 같은 이유로, 소리에도 `.wav` 가 없습니다.
발소리·검격·방어·몬스터의 목소리·배경음까지 **런타임에 합성**합니다.

```dart
final bank = SoundBank.field(seed: 7);            // 표준 창고
final wav  = bank.pick(SfxKeys.step(StepGround.grass), rng);  // WAV 바이트
```

`SoundBank` 는 이름 하나에 변주 여럿을 매답니다. 발소리 하나를 반복 재생하면
기관총이 되기 때문입니다 — 나무마다 시드를 바꾸는 것과 같은 규칙입니다.
굽기는 **처음 요청될 때** 일어나고 그 뒤로는 캐시를 줍니다.

| 무엇 | 어디에 |
|---|---|
| 발소리 — 바닥 5종(풀·흙·돌·나무·물) × 걷기/달리기 | `Sfx.footstep` |
| 휘두르기 — 무기 8종의 도플러 | `Sfx.swing` |
| 타격 · 방어 · 흘리기 · 사격 · 쓰러짐 | `Sfx.impact` · `block` · `parry` · `bowShot` · `bodyFall` |
| 몬스터의 목소리 — 목 7종 × 발화 5종 | `CreatureVoice` |
| 배경음 — 무드 4종의 이음매 없는 스테레오 루프 | `Bgm.bake` |
| 발진기 · 포락선 · 필터 · 잔향 | `Osc` · `Env` · `Svf` · `reverb` |

### 몬스터의 목소리는 그 몬스터에서 나온다

목소리는 **성대**(펄스열 + 거칢)와 **성도**(포먼트 공명 셋)의 곱입니다. 몸집이
커지면 성도가 길어져 포먼트가 통째로 내려가므로, `size` 하나만 올려도 같은
레시피가 거인이 됩니다.

```dart
final voice = CreatureVoice.of(monster, kind: VoiceKind.roar);
bank.addVoice(monster.id, voice);          // idle · alert · attack · hurt · die
```

`id` 가 시드이므로 **같은 캐릭터는 언제나 같은 목소리**를 냅니다. 같은 종을 열
마리 놓아도 개체마다 다릅니다.

### 재생은 하지 않습니다

라이브러리는 WAV 바이트까지만 만듭니다. 오디오 백엔드에 묶이지 않기 위해서이며,
덕분에 합성은 격리 스레드에서 돌릴 수 있습니다.

```dart
final bytes = encodeWav(Sfx.block(seed: 3));   // 이 뒤는 앱의 몫
```

`example/lib/audio/` 에 `audioplayers` 로 붙인 재생 계층이 있습니다 — 창고를
격리 스레드에서 굽고, 거리로 음량을, 화면 가로 위치로 좌우 균형을 정합니다.

### 소리는 클립 이벤트에 붙입니다

프레임 수를 세지 않습니다. `Clip.events` 에 찍힌 정규화 시각을 `Animator.fired`
로 읽으므로, 보폭 동기화로 재생 배속이 바뀌어도 **발이 땅에 닿는 그 프레임**에
소리가 납니다.

```dart
for (final e in actor.animator.fired) {
  if (e == 'footfall') audio.play(SfxKeys.step(groundAt(actor.tile)));
  if (e == 'strike')   resolveHit();
}
```

## 결정론

같은 시드는 언제나 같은 결과를 냅니다. `Rng.branch(salt)` 는 **루트 시드**에서
파생하므로, 생성 규칙을 하나 추가해도 기존 캐릭터의 색과 장비가 보존됩니다.

```dart
final r = Rng(seed);
final palette = Palette.hero(r.branch(11));   // 언제 불러도 같은 결과
final gear = buildGear(r.branch(23));
```

## Flame 없이도 쓸 수 있습니다

핵심 렌더는 `dart:ui` 만 씁니다. `IsoSceneComponent` 하나만 Flame 에 의존하므로,
순수 Flutter `CustomPainter` 에서도 그대로 동작합니다.

```dart
paintScene(canvas, [
  ...props.map(PropItem.new),
  ...actors.map(ActorItem.new),
], iso, light, time);        // 기물과 캐릭터가 하나의 깊이 정렬을 거친다
```

## 예제 실행

```bash
cd example
flutter run -t lib/main.dart              # 아이소 필드 — 기물 + 클릭 이동
flutter run -t lib/gallery.dart           # 캐릭터 갤러리
flutter run -t lib/viewer.dart            # 절차 액터 뷰어 (시드·클립·8방향)
flutter run -t lib/create_character.dart  # 캐릭터 작업대 — 만들고 코드를 복사
```

`example/lib/characters/` 가 두 방식을 나란히 보여 줍니다.

- `aldric.dart` 등 **손으로 그린 5종** — 각 파일 첫머리의 **시각 논제** 주석이
  그 캐릭터를 무엇으로 읽히게 할지 한 문단으로 적어 둔 것입니다.
- `recruits.dart` 의 **선언형 20종** — 전사·마법사·궁수·군인·사이보그가 남녀로
  들어 있고, 한 명이 15줄입니다.

초상과 게임 액터가 같은 인물로 보이는지는 시트로 대조합니다.

```bash
cd example && flutter test test/identity_sheet_test.dart
open build/art/identity_*.png
```

## 라이선스

MIT
