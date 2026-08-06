# 맵 기물 — Prop 계약과 6종 구현

`lib/src/props/` 의 완전한 참조.

## 목차

1. [핵심 개념: 맵이 비면 게임 화면이 아니다](#핵심-개념-맵이-비면-게임-화면이-아니다)
2. [Prop 계약 (전체 소스)](#prop-계약)
3. [배치와 깊이 정렬](#배치와-깊이-정렬)
4. [TreeProp — 나무](#treeprop--나무)
5. [RockProp — 바위](#rockprop--바위)
6. [BuildingProp · WallProp — 건물과 담장](#buildingprop--wallprop)
7. [WaterProp · LavaProp — 물과 용암](#waterprop--lavaprop)
8. [GroundPatch · PathPatch — 지면](#groundpatch--pathpatch)
9. [새 기물을 만드는 절차](#새-기물을-만드는-절차)
10. [체크리스트](#체크리스트)

---

## 핵심 개념: 맵이 비면 게임 화면이 아니다

캐릭터가 아무리 좋아도 빈 격자 위에 서 있으면 테스트 화면으로 보인다. 기물은
화면을 채우는 장식이 아니라 **공간에 이야기를 주는 장치**다 — 길은 동선을,
담장은 경계를, 물은 우회를, 고사목은 분위기를 말한다.

세 가지 원칙이 기물 전체를 관통한다.

1. **한 덩어리로 그리지 않는다.** 나무를 초록 원 하나로, 바위를 회색 타원
   하나로 그리면 클립아트가 된다. 잎은 깊이별 덩어리로, 바위는 깨진 면으로,
   건물은 세 면으로 나눈다.
2. **시드로 개체를 흔든다.** 같은 숲에 똑같은 나무 스무 그루가 서 있으면 즉시
   가짜다. 형상·색·기울기·바람 위상을 전부 시드에서 파생시킨다.
3. **그림자로 지면에 붙인다.** 아이소는 원근이 없어 높이와 깊이가 화면상 같은
   축이다. 그림자가 없으면 나무가 떠 있는지 뒤에 있는지 알 수 없다.

---

## Prop 계약

**파일: `lib/src/props/prop.dart`**

```dart
abstract class Prop {
  /// 타일 단위 점유 크기. 경로탐색이 통행 가능 여부를 판단할 때 쓴다.
  Size get footprint => const Size(1, 1);

  /// 화면상 높이(px). 깊이 정렬과 컬링에 쓰인다.
  double get height;

  /// 지면 평면에 눕는가. 웅덩이·길·풀밭이 true.
  bool get grounded => false;

  /// 캐릭터가 통과할 수 있는가.
  bool get walkable => grounded;

  /// 국소 좌표에 자신을 그린다. 같은 [t] 에는 언제나 같은 그림이 나와야 한다.
  void paint(Canvas c, double t, LightRig light, {double detail = 1.0});
}
```

### 좌표 규약

구현체는 **접지 중심이 원점, `-y` 가 위**인 국소 좌표에 그린다. 캐릭터
([Artist])의 발밑 원점 규약과 같으므로 둘을 같은 씬에 섞어도 접지선이 어긋나지
않는다.

### 세워지는 것과 눕는 것

| | `grounded` | 세로 압축 | 예 |
|---|---|---|---|
| 세워진다 | `false` | `iso.squash` (≈0.866) | 나무·바위·건물·담장 |
| 눕는다 | `true` | `iso.shadowRatio` (=0.5) | 웅덩이·길·풀밭 |

눕는 기물은 세로가 더 강하게 눌려 **원이 2:1 타원**이 된다. 이 처리는
[paintProp] 이 대신 하므로 구현체는 신경 쓰지 않는다.

### 배치 정보

```dart
class PropInstance {
  PropInstance({
    required this.prop,
    required this.tile,        // 월드 타일 좌표
    this.facesLeft = false,    // 좌우 반전 — 반복을 덜 눈에 띄게
    this.timeOffset = 0,       // 바람·명멸의 위상
    this.scale = 1.0,          // 개체별 크기 변주 (0.85~1.15)
  });
  double get depth => tile.dx + tile.dy;   // 정렬 키
}
```

### 그림자

```dart
/// 기물이 지면에 드리우는 그림자. 세워지는 기물에는 예외 없이 필요하다.
void propShadow(Canvas c, double radius, LightRig l,
    {double alpha = 0.42, double stretch = 1.35});
```

광원 반대쪽으로 늘어난 타원이며, 세로가 절반으로 눌려 지면에 눕는다.

---

## 배치와 깊이 정렬

**기물과 캐릭터를 따로 그리면 나무 뒤로 걸어 들어간 캐릭터가 나무 앞에
나타난다.** 아이소 씬에서 그리기 순서는 곧 앞뒤 관계이므로, 화면에 있는 모든
것이 하나의 정렬을 거쳐야 한다.

```dart
// 저수준 — Flame 을 쓰지 않을 때
paintScene(canvas, [
  ...props.map(PropItem.new),
  ...actors.map(ActorItem.new),
], iso, light, time);

// 고수준 — Flame 컴포넌트
scene.addProp(instance);   // 통행 격자도 함께 막힌다
scene.actors.add(actor);
```

`IsoSceneComponent.addProp` 이 **격자를 함께 막는 것**이 중요하다. 둘을 따로
관리하면 반드시 어긋난다 — 화면에는 나무가 있는데 캐릭터가 통과하거나,
아무것도 없는데 길이 막힌다.

---

## TreeProp — 나무

```dart
enum TreeKind { broadleaf, conifer, dead, blossom, willow }

TreeProp({
  required int seed,
  TreeKind kind = TreeKind.broadleaf,
  double trunkHeight = 190,
  Color? canopyColor,
  Color? barkColor,
  double wind = 1.0,
});
```

### 나무가 나무로 읽히는 세 가지

1. **잎 덩어리를 깊이로 나눈다.** 덩어리마다 `depth`(-1 뒤 … +1 앞)를 계산해
   뒤쪽은 어둡고 차갑게(`ambient` 혼합), 앞쪽은 밝고 따뜻하게 칠한다. 한
   덩어리로 그리면 아무리 잘 칠해도 종잇장이다.

   ```dart
   final lit = (depth + 1) * 0.5;
   final tone = _leaf.darken(0.22 * (1 - lit))
                     .mix(l.ambient, 0.30 * (1 - lit))
                     .lighten(0.08 * lit);
   ```

2. **가지가 잎 사이로 비친다.** 수관을 그리기 전에 가지를 몇 개 뻗어 두면 잎이
   가지에 달려 있다는 사실이 전달된다.

3. **바람에 위상차를 준다.** 덩어리마다 `sin(t * 1.4 + i * 1.7 + seed * 0.29)`
   로 흔들림의 위상을 어긋나게 한다. 통째로 흔들면 판때기가 흔들린다.

### 종류별 형상

| kind | 형상 | 쓰임 |
|---|---|---|
| `broadleaf` | 둥근 덩어리 4~7개 | 가장 흔한 배경 나무 |
| `conifer` | 원뿔 층을 아래에서 위로 쌓음 | 수직선으로 화면을 잡아 준다 |
| `dead` | 잎 없이 가지 9개 + 잔가지 | 실루엣 자체가 이야기를 한다 |
| `blossom` | `Finish.cloth` + 분홍 대역 | 색으로 시선을 끄는 강조용 |
| `willow` | 아래로 늘어지는 가닥 14개 | 물가 |

### 숲 심기

```dart
List<PropInstance> plantForest({
  required int seed,
  required List<Offset> tiles,
  List<TreeKind> kinds = const [TreeKind.broadleaf, TreeKind.conifer],
  double baseHeight = 190,
});
```

시드마다 종류·키(`bell(0.82, 1.18)`)·좌우 반전·`timeOffset`·`scale` 을 흔들어
복제 인간 문제를 없앤다.

---

## RockProp — 바위

```dart
RockProp({required int seed, double size = 70, Color? color,
          bool mossy = false, int shards = 0});
```

### 왜 실루엣은 곡선, 내부는 직선인가

바위를 둥근 덩어리로만 그리면 감자가 된다. 바위가 바위로 읽히는 이유는
**평면(facet)의 집합**이기 때문이다 — 깨진 면들이 서로 다른 각도로 빛을 받아
명도가 계단처럼 갈리고, 그 경계가 날카롭다.

그래서 실루엣만 `smoothClosedPath(tension: 0.72)` 로 부드럽게 잡고, 내부는
클립 안에서 **직선으로 쪼갠다**:

```dart
c.clipPath(_outline);
for (var i = 0; i < _facets; i++) {
  // 임의 각도의 반평면을 덮어 명도를 갈아 준다
  c.drawPath(side, Paint()
    ..blendMode = lit ? BlendMode.plus : BlendMode.multiply
    ..color = (lit ? light.key : light.ambient).fade(lit ? 0.055 : 0.16));
  // 면 경계선 — 광물의 날카로움은 이 선에서 나온다
  c.drawLine(a, b, Paint()..color = _tone.darken(0.3).fade(0.5));
}
```

`mossy` 는 **위쪽 면에만** 이끼를 얹는다. 아무 데나 뿌리면 물감 자국이 된다.

`PebbleField` 는 지면에 흩어진 자갈밭(`grounded`)으로, 큰 바위 주변을 채운다.

---

## BuildingProp · WallProp

```dart
enum WallStyle { timber, stone, log, brick }
enum RoofStyle { gable, flat, cone }

BuildingProp({
  required int seed,
  Size tiles = const Size(2, 2),
  double tileWidth = 156,      // 맵의 IsoView 와 맞춘다
  double isoRatio = 0.5,       // iso.elevationSin 을 넘긴다
  int storeys = 1,
  WallStyle wall = WallStyle.timber,
  RoofStyle roof = RoofStyle.gable,
  bool litWindows = true,
});
```

### 세 면의 명도 위계

아이소에서 상자는 **왼쪽 벽·오른쪽 벽·지붕** 세 면이 동시에 보인다. 이 셋의
명도가 확실히 갈리지 않으면 건물이 납작한 판이 된다. 밝기 순서는 언제나
**지붕 > 광원 쪽 벽 > 반대쪽 벽**이며, 이 위계가 무너지면 텍스처를 아무리
얹어도 입체로 읽히지 않는다.

```dart
final leftLit = l.dir.dx < 0;         // dir 은 피사체→광원
final litTone = _wallTone.lighten(0.06);
final shadeTone = _wallTone.darken(0.20).mix(l.ambient, 0.28);
```

### squash 보정 — 반드시 이해할 것

`paintProp` 은 세워지는 기물에 `iso.squash`(≈0.866)를 건다. 그런데 건물의
밑면·지붕 마름모는 **지면 평면에 누워야** 하므로 화면 비율이 타일과 같은
`tileHeight/tileWidth`(=0.5)여야 한다. 그래서 내부에서 미리 부풀린다:

```dart
double get _planeK {
  final squash = math.sqrt(1 - isoRatio * isoRatio);
  return isoRatio / squash;          // 0.5 / 0.866 = 0.577
}
```

밑면 마름모는 아이소 기저벡터로 계산한다 — 월드 x 축은 화면 오른쪽-아래,
y 축은 왼쪽-아래로 간다:

```dart
(Offset, Offset, Offset, Offset) _diamond() {
  final hx = tiles.width * 0.5, hy = tiles.height * 0.5;
  final u = tileWidth * 0.5, k = _planeK;
  return (
    Offset(u * (hx - hy),  u * k * (hx + hy)),   // 앞
    Offset(u * (hx + hy),  u * k * (hx - hy)),   // 오른
    Offset(u * (hy - hx), -u * k * (hx + hy)),   // 뒤
    Offset(-u * (hx + hy), u * k * (hy - hx)),   // 왼
  );
}
```

**`isoRatio` 를 맵의 `iso.elevationSin` 과 맞추지 않으면 건물이 격자와 어긋나
공중에 뜬 것처럼 보인다.**

### 비율 — 실측으로 얻은 값

| 항목 | 값 | 이유 |
|---|---|---|
| 층고 | `tileWidth * 0.34~0.44` | 이보다 크면 건물이 화면을 압도한다 |
| 박공 마루 높이 | `_storeyH * 0.62` | 층고 기준이라야 층수가 바뀌어도 비례가 유지된다 |
| 원뿔 지붕 높이 | `_storeyH * 1.15` | |
| 처마 | `tileWidth * 0.06` | 벽 밖으로 나와야 지붕을 "쓰고" 있는 것으로 보인다 |
| 창문 | `_storeyH * 0.13 × 0.18` | 크면 벽이 창문에 먹힌다 |

### 벽 디테일

- `timber` — 회벽을 가로지르는 어두운 보. 중세 마을의 정체성이다.
- `stone`/`brick` — **가로 줄눈만.** 세로까지 그리면 격자무늬가 된다.
- `log` — 굵은 가로 원통이 쌓인다.

창문에 불이 켜지면 `glowAt` 으로 **벽도 함께 적신다**. 발광체를 그렸으면 주변
수광면에도 반사광을 반영해야 광원이 장면에 속한 것으로 보인다.

### WallProp

담장은 한 방향으로 길게 이어지는 것을 전제로 한다. 윗면(`cap`)이 하늘을 정면
으로 받아 가장 밝고, `crenellated` 로 총안을 낸다. `alongX` 로 진행 방향을 정한다.

---

## WaterProp · LavaProp

```dart
WaterProp({required int seed, double radius = 120, Color? color,
           double ripple = 1.0, bool shallow = false});
```

### 물이 물로 보이는 세 겹

1. **깊이** — 가장자리는 바닥이 비쳐 밝고 탁하며, 가운데는 어둡고 푸르다.
2. **하늘 반사** — 조명의 `rim` 색을 위쪽에 얹는다. 이것이 수면을 **위를 향한
   면**으로 만든다.
3. **잔물결** — 위상이 다른 밝은 선 여러 겹. 정지한 물은 유리판이다.

`shallow` 는 통행 가능하며 바닥이 더 많이 비친다. 물가에는 젖은 테두리를 두고,
광원 쪽 가장자리에만 반짝임을 얹는다.

`LavaProp` 은 **자신이 광원**이므로 하늘 반사 대신 자체 발광으로 그린다. 굳은
표면(`crust`) 사이로 갈라진 틈에서 빛이 새고, 형상 밖으로 열기가 번진다
(`BlurStyle.outer`).

---

## GroundPatch · PathPatch

```dart
GroundPatch({required int seed, double radius = 90, Color? color,
             int blades = 0, Color? flowerColor});
PathPatch({required int seed, double tileWidth = 156, double isoRatio = 0.5,
           double width = 0.62, Color? color, bool alongX = true});
```

빈 타일이 계속되면 화면이 격자무늬 장판이 된다. 이 둘이 그 사이를 메운다.

- **가장자리를 흐린다.** 선명한 테두리를 두면 스티커가 된다 — 방사 그라디언트로
  알파를 0 까지 떨어뜨린다.
- **얼룩을 넣는다.** 단색 패치는 물감이다.
- **길은 동선을 보여 준다.** 텍스트 없이 "이쪽으로 가라"를 전달하는 장치다.
  가장자리를 노이즈로 흔들어 인공적인 직선을 없앤다.

---

## 새 기물을 만드는 절차

1. **`Prop` 을 구현**하고 `grounded`·`walkable`·`footprint`·`height` 를 정확히
   준다. 경로탐색이 이 값을 그대로 믿는다.
2. **접지 중심 원점, `-y` 가 위**인 국소 좌표에 그린다.
3. **세워지는 기물이면 `propShadow` 를 첫 줄에** 부른다.
4. **시드로 흔든다** — 형상·색·기울기·위상. `Rng(seed)` 만 쓴다.
5. **`detail` 로 게이팅한다** — 미세 텍스처는 `if (detail > 0.4)`, 파티클은
   `> 0.5`. 멀리 있는 개체에서 보이지도 않는 것에 프레임을 쓰지 않는다.
6. **재질은 `Finish` 에서 고른다.** 나무 `wood`, 잎 `fur`, 바위·벽 `stone`,
   회벽 `cloth`, 발광 `energy`, 반투명 `slime`/`membrane`.

```dart
class FenceProp extends Prop {
  FenceProp({required this.seed});
  final int seed;

  @override double get height => 60;
  @override bool get walkable => false;

  @override
  void paint(Canvas c, double t, LightRig light, {double detail = 1.0}) {
    propShadow(c, 40, light);
    final r = Rng(seed);
    for (var i = 0; i < 5; i++) {
      final post = tube([Offset(i * 20.0 - 40, 0), Offset(i * 20.0 - 40, -55)],
                        [5, 3.5], samples: 6);
      paintSurface(c, post, Surface(_wood, Finish.wood), light,
          detail: detail, seed: seed + i);
    }
  }
}
```

---

## 체크리스트

- [ ] `propShadow` 로 지면에 붙였는가 (세워지는 기물)
- [ ] `footprint`·`walkable` 이 실제 형상과 맞는가
- [ ] 같은 종류를 여럿 놓을 때 시드·크기·`timeOffset` 이 개체마다 다른가
- [ ] 한 덩어리로 그리지 않았는가 (잎은 깊이별, 바위는 면별, 건물은 3면)
- [ ] `detail` 로 미세 텍스처를 게이팅했는가
- [ ] 건물·담장의 `tileWidth`·`isoRatio` 가 맵의 `IsoView` 와 같은가
- [ ] 같은 `t` 에 같은 그림이 나오는가 (`math.Random` 미사용)
- [ ] 발광체를 그렸으면 주변에 반사광을 돌려줬는가
