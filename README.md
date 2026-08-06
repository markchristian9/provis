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

## 핵심 개념

### 재질은 16가지 `Finish`

각 재질이 **전용 알고리즘**을 갖습니다. 금속은 하늘·지평선·지면이 비치는 3단
환경 밴딩으로, 피부는 명암 경계에 배어나는 붉은 산란으로, 머리카락은 점이 아닌
띠 모양 광택으로 그립니다. 하나의 범용 그라디언트를 16번 재활용하지 않습니다.

```dart
paintSurface(canvas, path, Surface(color, Finish.metal), light, detail: 1.0);
```

`skin · metal · gold · cloth · leather · scale · chitin · fur · hair · bone ·
wood · gem · energy · slime · stone · membrane`

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

// 숲 — 시드마다 종류·키·기울기가 흔들린다
scene.addProps(plantForest(
  seed: 42,
  tiles: [for (var i = 0; i < 12; i++) Offset(i * 1.1 + 1, 2.0)],
  kinds: [TreeKind.broadleaf, TreeKind.conifer],
));

// 건물 — 아이소에서 왼쪽 벽·오른쪽 벽·지붕 3면이 보인다
scene.addProp(PropInstance(
  prop: BuildingProp(seed: 7, tiles: const Size(2, 2), storeys: 2),
  tile: const Offset(5, 8),
));

// 물웅덩이 — 지면 평면에 눕고 하늘을 비춘다
scene.addProp(PropInstance(
  prop: WaterProp(seed: 3, radius: 130),
  tile: const Offset(9, 5),
));
```

기물을 `addProp` 으로 넣으면 **통행 격자도 함께 막힙니다.** 화면에는 나무가
있는데 캐릭터가 통과하는 일이 생기지 않습니다.

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
actor.tile = hero.tile;
actor.facesLeft = hero.facesLeft;
```

목표가 벽이면 **가장 가까운 통행 가능한 타일**로 갑니다 — 벽을 눌렀다고 아무
반응이 없으면 조작이 고장난 것처럼 느껴지기 때문입니다.

방향 전환은 `turnTime`(기본 0.14초)에 걸쳐 최단 경로로 보간됩니다. 8방향으로
즉시 스냅하지 않는 이유는, 절차적 렌더러가 중간 각도를 그릴 수 있기 때문입니다.

### 3. 캐릭터를 만든다

`Artist` 를 구현하면 갤러리와 아이소 필드 양쪽에 그대로 섭니다.

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
      top: kGround - 900 + bob, bottom: kGround - 480,
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

### 4. 시드로 찍어낸다

이름 없는 군중은 `HumanoidSpec` 으로 생성합니다.

```dart
final spec = HumanoidSpec.generate(seed);   // 원형 → 체형 → 장비 → 팔레트
```

원형(knight/berserker/ranger/mage/assassin/paladin)을 먼저 뽑고 **그 원형의
겹치지 않는 대역 안에서만** 변주합니다. 파라미터를 각각 독립 무작위화하면
"특징 없는 평균"만 나옵니다.

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
flutter run -t lib/main.dart      # 아이소 필드 — 기물 + 클릭 이동
flutter run -t lib/gallery.dart   # 캐릭터 갤러리 (참조 구현 9종)
flutter run -t lib/viewer.dart    # 절차 액터 뷰어 (시드·클립·8방향)
```

`example/lib/characters/` 에는 손으로 만든 참조 캐릭터 9종이 들어 있습니다.
각 파일 첫머리의 **시각 논제** 주석이 그 캐릭터를 무엇으로 읽히게 할지
한 문단으로 적어 둔 것으로, 새 캐릭터를 만들 때의 본보기입니다.

## 라이선스

MIT
