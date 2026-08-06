# 맵 기물 — 리얼함의 네 조건과 전 기물 참조

`lib/src/props/` 의 완전한 참조.

## 목차

1. [핵심: 리얼함은 셰이딩이 아니라 네 가지에서 나온다](#핵심-리얼함은-셰이딩이-아니라-네-가지에서-나온다)
2. [Prop 계약](#prop-계약)
3. [배치와 깊이 정렬](#배치와-깊이-정렬)
4. [prop_kit — 공용 형상·텍스처 도구](#prop_kit--공용-형상텍스처-도구)
5. [TreeProp — 나무 7종](#treeprop--나무-7종)
6. [RockProp · PebbleField — 바위](#rockprop--pebblefield)
7. [BuildingProp · WallProp — 건물과 담장](#buildingprop--wallprop)
8. [WaterProp · LavaProp — 물과 용암](#waterprop--lavaprop)
9. [GroundPatch · PathPatch — 지면](#groundpatch--pathpatch)
10. [flora.dart — 풀·꽃·그루터기·통나무·울타리](#floradart)
11. [MoundProp — 언덕](#moundprop--언덕)
12. [지면 자체 — paintIsoGround](#지면-자체--paintisoground)
13. [성능 — 블러가 프레임을 죽인다](#성능--블러가-프레임을-죽인다)
14. [새 기물을 만드는 절차](#새-기물을-만드는-절차)
15. [체크리스트](#체크리스트)

---

## 핵심: 리얼함은 셰이딩이 아니라 네 가지에서 나온다

기물이 클립아트로 보일 때 **재질 선택을 의심하지 마라.** 원인은 거의 언제나
아래 넷 중 하나가 빠진 것이다. 이 넷을 갖추면 같은 `Finish` 로도 결과가 완전히
달라지고, 이 넷이 없으면 어떤 셰이딩을 얹어도 풍선·조약돌·회색 상자다.

### ① 실루엣이 재질을 말한다

가장 중요하고 가장 자주 빠뜨린다. 관객은 셰이딩을 보기 전에 **윤곽선**을 본다.

| 대상 | 틀린 실루엣 | 옳은 실루엣 | 도구 |
|---|---|---|---|
| 잎 뭉치 | 매끄러운 타원 | 돌기가 반복되는 울퉁불퉁한 선 | `leafCluster` |
| 수관 가장자리 | 깨끗한 곡선 | 잎 몇 장이 삐져나옴 | `scatterLeaves` |
| 전나무 | 매끈한 삼각형 | 아래로 처진 각진 톱니 | `coniferTier` |
| 바위 | 둥근 감자 | 직선으로 깨진 면의 집합 | 다각형 `_chunk` |
| 풀 | 굵기 일정한 선 | 뿌리가 넓고 끝이 뾰족한 채움 | `grassBlade` |
| 꽃 | 색 점 | 갈라진 꽃잎 + 꽃술 | `paintFlower` |

**톱니는 스플라인에 통과시키지 않는다.** `smoothClosedPath` 를 거치면 뾰족함이
뭉개져 다시 매끈한 삼각형이 된다. 광물과 바늘잎은 `lineTo` 로 그린다.

### ② 덩어리 안에 덩어리가 있다

단일 그라디언트로 칠한 면은 **크기를 알 수 없다.** 관객이 규모를 읽는 근거는
반복 단위다 — 돌 한 장, 널 한 장, 기와 한 줄, 잎 뭉치 하나.

```dart
// 벽 — 돌 하나하나가 쌓인다
courseTexture(c, a, b, up, tone, l, seed: seed,
    courses: 6, perCourse: 5, stagger: 0.5, bevel: 0.42, variance: 0.20);

// 수관 — 잎 뭉치 단위의 밝기 차
lobeLight(c, center, rx, ry, tone, l, seed: seed, count: 3);
```

### ③ 접지가 두 겹이다

넓고 옅은 드리운 그림자만 있으면 물체가 **그림자 위에 얹힌 스티커**가 된다.

```dart
propShadow(c, radius, light, alpha: 0.38);       // 넓고 옅다 — 광원 반대로 눕는다
rootSkirt(c, r * 3.4, litterColor, light, seed: seed);  // 밑동을 감싼 흙
contactAO(c, r * 1.9, alpha: 0.5);               // 좁고 짙다 — 접촉선 바로 아래
```

셋이 다 있어야 "그 자리에서 자란 것"이 된다.

### ④ 얇은 것은 빛을 통과시킨다

잎·꽃잎·천막의 그늘 쪽이 그냥 어두우면 플라스틱 조화다. 실제로는 빛이 재질을
뚫고 나와 **광원 반대쪽 가장자리가 밝은 황록으로 뜬다.**

```dart
Surface(tone, Finish.foliage, sss: throughColor)   // 재질 내부의 투과
translucentBand(c, shape, l, color: through, alpha: 0.18)  // 가장자리의 투과
```

`rimBand` 와 혼동하지 않는다 — 저쪽은 백라이트가 만드는 **윤곽선**이고 색이
하늘빛(`l.rim`)이다. 이쪽은 재질을 뚫고 나온 빛이라 **재질의 고유색** 쪽으로
밀려 있어야 한다.

---

## Prop 계약

**파일: `lib/src/props/prop.dart`**

```dart
abstract class Prop {
  Size get footprint => const Size(1, 1);   // 타일 점유 — 경로탐색이 쓴다
  double get height;                        // 화면상 높이(px)
  bool get grounded => false;               // 지면 평면에 눕는가
  bool get walkable => grounded;            // 통과 가능한가
  void paint(Canvas c, double t, LightRig light, {double detail = 1.0});
}
```

### 좌표 규약

구현체는 **접지 중심이 원점, `-y` 가 위**인 국소 좌표에 그린다. 캐릭터의 발밑
원점 규약과 같으므로 둘을 같은 씬에 섞어도 접지선이 어긋나지 않는다.

### 세워지는 것과 눕는 것

| | `grounded` | 세로 압축 | 예 |
|---|---|---|---|
| 세워진다 | `false` | `iso.squash` (≈0.866) | 나무·바위·건물·풀 포기·꽃·언덕 |
| 눕는다 | `true` | `iso.shadowRatio` (=0.5) | 웅덩이·길·풀밭 패치·자갈밭 |

**풀은 둘 다 있다.** `GroundPatch` 의 풀은 눕는 패치의 장식이고, `GrassTuft` 는
세워지는 기물이다. 발치의 밀도가 필요하면 후자를 쓴다.

### 지면 평면과 나란한 면 — `_planeK`

건물 밑면·지붕 마름모·그루터기 절단면처럼 **지면과 평행한 면**은 화면 비율이
타일과 같아야 한다. 바깥에서 걸린 `squash` 를 상쇄한다:

```dart
double get _planeK {
  final squash = math.sqrt(1 - isoRatio * isoRatio);
  return isoRatio / squash;          // 0.5 / 0.866 = 0.577
}
```

**`isoRatio` 를 맵의 `iso.elevationSin` 과 맞추지 않으면 기물이 격자와 어긋나
공중에 뜬 것처럼 보인다.**

---

## 배치와 깊이 정렬

```dart
scene.addProp(instance);   // 통행 격자도 함께 막힌다
scene.addProps(plantForest(seed: 42, tiles: spots, kinds: [...]));
```

`IsoSceneComponent.addProp` 이 **격자를 함께 막는 것**이 중요하다. 둘을 따로
관리하면 반드시 어긋난다 — 화면에는 나무가 있는데 캐릭터가 통과하거나,
아무것도 없는데 길이 막힌다.

`PropInstance` 는 `tile`·`facesLeft`·`timeOffset`·`scale` 로 개체를 흔든다.
**같은 종류를 여럿 놓을 때 `timeOffset` 을 반드시 다르게 준다** — 같으면 숲이
한 몸처럼 흔들린다.

---

## prop_kit — 공용 형상·텍스처 도구

**파일: `lib/src/props/prop_kit.dart`**

| 함수 | 하는 일 |
|---|---|
| `leafCluster(center, rx, ry, {lobes, lobeSize, spread, seed})` | 잎 뭉치 실루엣. 코어 + 둘레 돌기를 `nonZero` 로 합쳐 불 연산 없이 울퉁불퉁한 윤곽을 만든다 |
| `leafBlade(root, length, angle, {width})` | 잎 한 장(방추형) |
| `grassBlade(root, height, lean, {width})` | 풀잎 한 장. 뿌리가 넓고 끝이 뾰족 |
| `paintFlower(c, at, radius, petal, heart, l, {petals, squash})` | 꽃 한 송이 |
| `coniferTier(apex, halfWidth, drop, {teeth, sag})` | 침엽수 가지 한 단. **직선으로** 그린 톱니 |
| `lobeLight(c, center, rx, ry, tone, l, {count})` | 덩어리 안의 뭉치 단위 밝기 차 |
| `scatterLeaves(c, center, rx, ry, tone, l, {count, size})` | 가장자리에 잎을 흩뿌려 윤곽을 깨뜨린다 |
| `rootSkirt(c, radius, tone, l, {squash})` | 밑동을 감싸는 흙더미 |
| `courseTexture(c, a, b, up, tone, l, {courses, perCourse, stagger, bevel})` | 조적·널판·기와의 반복 단위 |
| `isoDiamond(hx, hy, u, k, {lift})` | 지면 평면에 눕는 마름모 |
| `eaveShadow(c, face, from, to, {depth})` | 돌출부가 벽에 드리우는 그림자 |
| `sway(t, seed, {phase, speed})` | 바람 위상 |

셰이딩 쪽(`core/shading.dart`)에 추가된 것:

- `Finish.foliage` — 잎. 확산 + **투과** + 얼룩(`_dapple`)
- `Finish.bark` — 나무껍질. 원통 명암 띠 + 세로 홈
- `Finish.soil` — 흙. 확산만, 스펙큘러 없음
- `translucentBand(c, path, l, {color, width})` — 광원 반대쪽 투과 밴드
- `contactAO(c, radius, {alpha, squash, at})` — 좁고 짙은 접촉 그늘

---

## TreeProp — 나무 7종

```dart
enum TreeKind { broadleaf, conifer, pine, dead, blossom, willow, bush }

TreeProp({
  required int seed,
  TreeKind kind = TreeKind.broadleaf,
  double trunkHeight = 190,
  Color? canopyColor, Color? barkColor,
  double wind = 1.0,
});
```

| kind | 실루엣 | 쓰임 |
|---|---|---|
| `broadleaf` | 잎 뭉치 5~7개가 겹친 둥근 수관 | 가장 흔한 배경 나무 |
| `conifer` | 처진 톱니 층 6~9단이 위로 좁아짐 | 수직선으로 화면을 잡아 준다 |
| `pine` | 굽은 줄기가 길게 드러나고 수관이 위에만 판판하게 | `conifer` 와 정반대라 섞으면 숲의 밀도가 오른다 |
| `dead` | 잎 없이 주지 5개에서 잔가지가 재귀로 갈라짐 | 실루엣 자체가 이야기 |
| `blossom` | 분홍 뭉치 + 흩날리는 꽃잎 | 색으로 시선을 끄는 강조용 |
| `willow` | 늘어지는 가는 잎 가닥 24개 | 물가 |
| `bush` | 줄기 없는 낮은 덤불. `walkable = true` | 나무 밑동·담장 아래를 메운다 |

### 잎 뭉치 하나를 그리는 순서

순서 자체가 결과를 좌우한다.

```dart
final shape = leafCluster(at, rad, rad * 0.88, lobes: 8, seed: massSeed);

// ① 실루엣 + 재질(투과 포함)
paintSurface(c, shape, Surface(tone, Finish.foliage, sss: through), l, ...);

// ② 뭉치 단위 밝기 차 — 클립 안에서
c.save(); c.clipPath(shape);
lobeLight(c, at, rad, rad * 0.88, tone, l, seed: massSeed, count: 3);
c.restore();

// ③ 투과 밴드 + 림 — **앞쪽 덩어리에만**
if (lit > 0.55 && detail > 0.45) {
  translucentBand(c, shape, l, color: through, alpha: 0.09 + 0.13 * lit);
  rimBand(c, shape, l, width: rad * 0.07, alpha: 0.26 * lit);
}
```

**뒤/앞 명도 대비가 수관의 부피를 만든다.** 덩어리마다 `depth`(-1 뒤 … +1 앞)를
계산해 뒤쪽은 어둡고 차갑게(`ambient` 혼합), 앞쪽은 밝고 따뜻하게 칠한다.

```dart
final tone = _leaf.darken(0.26 * (1 - lit))
                  .mix(l.ambient, 0.32 * (1 - lit))
                  .lighten(0.07 * lit);
```

### 줄기

- `Finish.bark` 를 쓰고 **`rim: false`** 를 준다. 좁은 형상에서는 림이 면적을
  다 먹어 줄기가 흰 파이프가 된다.
- 밑동이 굵고 위가 가는 테이퍼 + 뿌리 판 4개. 직선 원기둥은 전봇대다.
- **수관이 줄기에 그림자를 드리운다.** 이게 없으면 수관이 떠 보인다.

### 전나무 — 층 그림자가 전부다

```dart
// 아래층을 그린 뒤, 위층 실루엣을 아래로 밀어 multiply 로 얹는다
c.clipPath(shapes[i]);
c.drawPath(shapes[i + 1].shift(Offset(0, ub.height * 0.34)),
    Paint()..blendMode = BlendMode.multiply ..color = ...);
```

이것이 없으면 초록 삼각형이 겹쳐 있는 것에 지나지 않는다.

### 숲 심기

```dart
List<PropInstance> plantForest({
  required int seed, required List<Offset> tiles,
  List<TreeKind> kinds = const [...], double baseHeight = 190,
});
```

종류별로 키 배율이 다르다 — `bush` 0.34, `pine` 1.18, `conifer` 1.10. 관목을
나무 키로 만들면 화면을 덮는다.

---

## RockProp · PebbleField

```dart
RockProp({required int seed, double size = 70, Color? color,
          bool mossy = false, int shards = 0, double buried = 0.22});
```

### 면을 실제로 만든다

반투명 오버레이로 명도를 흉내 내면 색이 탁해지고 경계가 흐려진다. 각진 다각형
덩어리를 여럿 만들어 `nonZero` 로 합치고, **면마다 바깥을 향한 방향**을 갖게 해
광원과의 내적으로 밝기를 정한다.

```dart
final ndl = (dir.dx * light.dir.dx + dir.dy * light.dir.dy).clamp(-1.0, 1.0);
final lit = 0.5 + 0.5 * ndl;
final tone = _tone.lighten(0.20 * lit * (0.5 + 0.5 * up))
                  .darken(0.26 * (1 - lit))
                  .mix(light.ambient, 0.30 * (1 - lit));
```

- 아래쪽에 넓은 베이스 면 2~3개, 위쪽에 좁은 면 2~3개 — 이 위계가 없으면 자갈
  무더기가 된다.
- 면이 **충분히 겹쳐야** 한 덩어리로 보인다. 떨어지면 도자기 조각이다.
- 면 경계선은 있되 **약하게**(alpha 0.24). 진하면 조각들이 분리된다.
- `mossy` 는 위쪽 면과 그늘진 쪽에만. 아무 데나 뿌리면 물감 자국이다.

`PebbleField` 는 자갈 아래에 **흙 베드**를 먼저 깐다. 자갈만 띄엄띄엄 그리면
공중에 뜬다.

---

## BuildingProp · WallProp

```dart
enum WallStyle { timber, stone, log, brick, plank }
enum RoofStyle { gable, hip, flat, cone, gambrel }
enum RoofSkin  { shingle, tile, thatch, plank }

BuildingProp({
  required int seed,
  Size tiles = const Size(2, 2),
  double tileWidth = 156, double isoRatio = 0.5,
  int storeys = 1,
  WallStyle wall = WallStyle.timber,
  RoofStyle roof = RoofStyle.gable,
  RoofSkin? skin,          // 생략하면 벽 재질에서 유도
  bool litWindows = true,
  bool ridgeAlongX = true, // 마루 방향 — 마을에서 섞는다
  bool chimney = true,
});
```

### 마루는 월드 축 하나와 평행해야 한다

**가장 흔한 치명적 실수.** 밑면 마름모 전체를 지붕으로 덮으면 벽이 지붕에 먹혀
버섯이 된다. 박공 마루는 축 하나와 평행하고, 그 결과 한쪽에는 **경사면**,
다른 쪽에는 **삼각 박공벽**이 온다.

```dart
// 마루 양 끝 — 밑면 중심선 위
final (mA, mB) = ridgeAlongX
    ? (lerpO(eF, eR, 0.5), lerpO(eL, eB, 0.5))
    : (lerpO(eF, eL, 0.5), lerpO(eR, eB, 0.5));

// 처마 끝과 마루 끝의 짝을 정확히 맞춘다 — 어긋나면 지붕면이 자기를
// 가로질러 부채꼴로 뻗어 나간다
final ridgeNearA = ridgeAlongX ? ridgeB : ridgeA;
final ridgeNearB = ridgeAlongX ? ridgeA : ridgeB;
final slope = Path()
  ..moveTo(nearEaveA) ..lineTo(nearEaveB)
  ..lineTo(ridgeNearB) ..lineTo(ridgeNearA) ..close();
```

박공 꼭짓점은 **언제나 `mA` 쪽 마루 끝**이다 (`ridgeAlongX` 와 무관).

### 그리는 순서

1. `propShadow` + `contactAO`
2. **기단** — 벽이 흙에서 바로 시작하면 상자를 얹어 둔 것이 된다
3. 좌·우 벽 (명도 위계) + 벽 표면(`courseTexture` / 통나무 / 널판 / 하프팀버)
4. **처마 그림자**(`eaveShadow`) — 지붕이 벽 앞으로 튀어나왔음을 알리는 한 줄
5. 문(아치 상인방 + 문지방) · 창(유리 + 십자 창살 + 창틀 + 창턱 + 새는 빛)
6. 박공벽(다락창 + 박공 널) 또는 모임지붕 측면
7. 경사면 + 지붕 표면(기와 열) + **처마 널**(지붕의 두께)
8. 마루기와 · 굴뚝 + 연기

### 세 면의 명도 위계

밝기 순서는 언제나 **지붕 > 광원 쪽 벽 > 반대쪽 벽**이다. 무너지면 텍스처를
아무리 얹어도 입체로 읽히지 않는다.

```dart
final leftLit = l.dir.dx < 0;                    // dir 은 피사체→광원
final litTone = _wallTone.lighten(0.07);
final shadeTone = _wallTone.darken(0.24).mix(l.ambient, 0.30);
```

### 벽 표면

- `timber` — 회벽 + 골조. **대각 브레이스**가 하프팀버의 정체성이다
- `stone` / `brick` — `courseTexture`. 벽돌은 켜를 촘촘히, 석재는 성기게
- `log` — 가로 원통. 위가 밝고 아래에 그림자, 모서리에 마구리
- `plank` — 세로 널 + 가로 띠장. 헛간

### 비율 — 실측값

| 항목 | 값 |
|---|---|
| 층고 | `tileWidth * 0.32~0.40` |
| 기단 | `_storeyH * 0.12` |
| 박공 마루 | `_storeyH * 0.70` (감베렐 0.86) |
| 원뿔 지붕 | `_storeyH * 1.35` |
| 처마 | `tileWidth * 0.075` |
| 처마 널 두께 | `_storeyH * 0.085` |
| 창 | `_storeyH * 0.17 × 0.24` |
| 문 | `_storeyH * 0.30 × 0.62` |

### WallProp

돌 하나하나(`courseTexture`)가 보이지 않으면 회색 상자다. 윗면 갓돌은 살짝
넓어야 갓돌로 읽히고, `crenellated` 총안에도 상단면을 그려야 두께가 생긴다.
`mossy` 는 밑동에만.

---

## WaterProp · LavaProp

```dart
WaterProp({required int seed, double radius = 120, Color? color,
           double ripple = 1.0, bool shallow = false, bool reeds = true});
```

### 물가가 먼저다

젖은 흙과 얕은 여울을 **물보다 먼저** 그린다. 이 띠가 없으면 파란 스티커를
붙인 것이 된다.

그 다음 순서: 깊이 그라디언트 → 비치는 바닥 → 하늘 반사(`l.rim`) → 잔물결 →
광원 쪽에 몰린 반짝임 → 물가 선 → 갈대.

`LavaProp` 은 **자신이 광원**이므로 하늘 반사 대신 자체 발광으로 그린다. 굳은
표면은 한 장이 아니라 **조각(plate)들이 떠 있는 것**이며 그 틈에서 빛이 샌다.

---

## GroundPatch · PathPatch

```dart
GroundPatch({required int seed, double radius = 90, Color? color,
             int blades = 0, Color? flowerColor});
PathPatch({required int seed, double tileWidth = 156, double isoRatio = 0.5,
           double width = 0.62, Color? color, bool alongX = true,
           bool ruts = true});
```

- **풀은 포기 단위로 뭉쳐 난다.** 균등하게 흩뿌리면 잔디밭 텍스처가 된다.
- **풀잎은 채워진 형상**(`grassBlade`)이고 뿌리가 어둡고 끝이 밝다. 선으로
  그으면 철사다.
- 얼룩은 두 층 — 넓은 색 변주 위에 작은 뭉침.
- 길은 **다닌 흔적**으로 길이 된다 — 바퀴자국 두 줄, 가운데가 밟혀 밝음,
  박힌 자갈, 길가에 밀려난 풀.

---

## flora.dart

발치의 작은 것들. **큰 기물만 놓으면 그 사이가 빈 장판으로 남는다.**

| 클래스 | 설명 | walkable |
|---|---|---|
| `GrassTuft(seed, size, blades, wind)` | 서 있는 풀 포기. 뒤→앞 깊이 정렬 | `true` |
| `FlowerBed(seed, size, petalColor, count)` | 꽃대 + 꽃 + 밑잎 | `true` |
| `StumpProp(seed, size, isoRatio, mossy)` | 그루터기. 나이테 + 방사 균열 | `false` |
| `LogProp(seed, length, isoRatio, alongX, mossy)` | 쓰러진 통나무. 마구리 + 축 하이라이트 | `false` |
| `FenceProp(seed, tileWidth, isoRatio, rails, posts)` | 나무 울타리. 기둥이 조금씩 기운다 | `false` |

`StumpProp`·`LogProp`·`FenceProp` 은 지면과 평행한 면(절단면·마구리·기둥 갓)이
있으므로 **`isoRatio` 를 반드시 맵과 맞춘다.**

---

## MoundProp — 언덕

```dart
MoundProp({required int seed, double radius = 120, double rise = 48,
           double isoRatio = 0.5, bool walkOver = false, int tufts = 5});
```

아이소 지면은 완벽한 평면이라 기물을 아무리 놓아도 화면이 한 층에 머문다.
둔덕 하나가 **지면 자체에 높이가 있다**는 사실을 전달한다.

1. **잘린 옆면이 보인다.** 상단 링에서 화면 앞쪽(아래) 절반을 골라 아래로
   extrude. 옆면이 없으면 지면에 초록 얼룩을 칠한 것과 같다.
2. **흙에 지층이 있다.** 수평 줄 세 개 + 박힌 돌 몇 개.
3. **풀이 가장자리를 넘는다.** 상단 풀이 옆면 위로 흘러내려야 두 면이 같은
   땅이 된다. 경계가 칼로 자른 듯하면 케이크다.

높이 처리가 없으므로 `walkOver` 는 낮은 둔덕에만 켠다.

---

## 지면 자체 — paintIsoGround

```dart
paintIsoGround(c, iso, cols, rows, l, {
  Color? base, double lineAlpha = 0.10, Color? soil,
  int seed = 7, double detail = 1.0, double skirt = 0.55,
});
```

**체커 타일은 지면이 아니라 장판이다.** 격자는 좌표를 확인하는 개발 도구다.

1. **가장자리 흙 두께**(`skirt`) — 지면보다 **먼저** 그린다. 맵 경계에서 지면이
   그냥 끊기면 종이가 잘린 것이지만, 흙 단면이 보이면 **두께를 가진 땅덩어리**가
   된다. 비용 대비 3D 감각 개선이 가장 크다.
2. 베이스 + 거리 감쇠 — 먼 쪽이 환경광으로 밀린다.
3. 얼룩 두 층 — 타일 경계와 **무관하게** 번져야 한다.
4. 격자선은 `lineAlpha: 0`(인게임 기본) 로 끌 수 있다.

`IsoSceneComponent` 는 `showGrid` 로 **격자선만** 껐다 켠다 — 지면은 언제나
그린다. 격자를 껐다고 캐릭터가 허공에 뜨면 안 된다.

---

## 성능 — 블러가 프레임을 죽인다

`MaskFilter.blur` 는 이 라이브러리에서 가장 비싼 연산이다. 점을 하나씩 블러로
그리면 수관 하나에 블러가 수십 번 걸린다.

```dart
// ✗ 나쁨 — 셀마다 블러
for (...) c.drawCircle(p, r, paint..maskFilter = blur);

// ✓ 좋음 — 한 Path 에 모아 블러 두 번
final lit = Path(), dark = Path();
for (...) { lit.addOval(...); or dark.addOval(...); }
c.drawPath(dark, paint..maskFilter = blur);
c.drawPath(lit,  paint..maskFilter = blur);
```

같은 이유로 `Path.combine`(= `rimBand`·`translucentBand`)은 복합 형상에서
비싸다. **덩어리마다 부르지 말고 앞쪽/위쪽 것에만** 얹는다 — 뒤쪽은 어차피
보이지 않는다.

`detail` 게이팅 기준:

| 값 | 켜지는 것 |
|---|---|
| `> 0.3` | 벽 표면, 밑동 흙, 잔물결 |
| `> 0.4` | 뿌리 판, `lobeLight`, 지층, 나이테 |
| `> 0.45` | 이끼, 갈대, 균열 |
| `> 0.5` | 투과·림 밴드, 통나무 마구리, 첨탑 |
| `> 0.55` | `scatterLeaves`, 흩날리는 꽃잎, 박힌 돌 |
| `> 0.6` | 개별 기와, 연기 |

---

## 새 기물을 만드는 절차

1. **`Prop` 을 구현**하고 `grounded`·`walkable`·`footprint`·`height` 를 정확히
   준다. 경로탐색이 이 값을 그대로 믿는다.
2. **접지 중심 원점, `-y` 가 위**인 국소 좌표에 그린다.
3. **접지를 두 겹으로** — `propShadow` + `contactAO`(+ 필요하면 `rootSkirt`).
4. **실루엣이 재질을 말하게 한다** — 위의 ① 표를 본다.
5. **면 안에 반복 단위를 넣는다** — `courseTexture` 또는 직접.
6. **시드로 흔든다** — 형상·색·기울기·위상. `Rng(seed)` 만 쓴다.
7. **`detail` 로 게이팅한다.**
8. **재질은 `Finish` 에서 고른다** — 잎 `foliage`, 껍질 `bark`, 흙 `soil`,
   바위·벽 `stone`, 회벽 `cloth`, 판재 `wood`, 발광 `energy`.
9. **`lib/provis.dart` 에 export 를 추가한다.** 빠뜨리면 소비자가 못 쓴다.

---

## 체크리스트

- [ ] 접지가 두 겹인가 (`propShadow` + `contactAO`)
- [ ] 실루엣이 재질을 말하는가 (잎=돌기, 전나무=톱니, 바위=직선 면)
- [ ] 면 안에 반복 단위가 보이는가 (돌·널·기와 한 장)
- [ ] 얇은 것에 투과광을 넣었는가 (`Finish.foliage`·`translucentBand`)
- [ ] 위를 향한 면에 `topPlane` 을 얹었는가
- [ ] `footprint`·`walkable` 이 실제 형상과 맞는가
- [ ] 지면과 평행한 면이 `isoRatio` 보정(`_planeK`)을 거쳤는가
- [ ] 같은 종류를 여럿 놓을 때 시드·크기·`timeOffset` 이 개체마다 다른가
- [ ] 건물의 마루가 월드 축과 평행한가 (지붕이 벽을 먹지 않는가)
- [ ] 지붕이 벽에 처마 그림자를 드리우는가
- [ ] 블러를 파츠마다 부르지 않았는가 (한 Path 로 모았는가)
- [ ] 같은 `t` 에 같은 그림이 나오는가 (`math.Random` 미사용)
- [ ] 발광체를 그렸으면 주변에 반사광을 돌려줬는가
