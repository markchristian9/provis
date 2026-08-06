# 절차적 생성 — 시드·원형·팔레트

`lib/src/core/rng.dart`, `lib/src/core/noise.dart`, `lib/src/core/scheme.dart`, `lib/src/actor/spec.dart` 의 완전한 참조.

## 목차

1. [핵심 개념: 원형 우선, 파라미터 나중](#핵심-개념-원형-우선-파라미터-나중)
2. [Rng — 결정론 난수 (전체 소스)](#rng--결정론-난수)
3. [Noise — 자연스러운 불규칙 (전체 소스)](#noise--자연스러운-불규칙)
4. [Palette — 조화로운 색을 유도하기 (전체 소스)](#palette--조화로운-색을-유도하기)
5. [HumanoidSpec — 원형 다이얼 (전체 소스)](#humanoidspec--원형-다이얼)
6. [인체 비율 랜드마크 표](#인체-비율-랜드마크-표)
7. [몬스터 생성 확장 패턴](#몬스터-생성-확장-패턴)
8. [분포 품질 검증](#분포-품질-검증)

---

## 핵심 개념: 원형 우선, 파라미터 나중

> **절차적 생성에서 모든 파라미터를 독립적으로 무작위화하면 "특징 없는 평균"만 쏟아진다.**

이것이 이 프로젝트의 제1 원칙이다. 키·어깨폭·근육량을 각각 독립 균등분포에서 뽑으면, 통계적으로 대부분의 결과가 중앙값 근처에 모이고 서로 구별되지 않는다.

해법은 **2단계 생성**이다:

```
1단계: 원형(Archetype)을 뽑는다        → knight / berserker / ranger / mage / assassin / paladin
2단계: 그 원형의 대역 안에서만 변주한다  → heads 6.6~7.1 (berserker) vs 7.8~8.3 (assassin)
```

원형별 대역이 **겹치지 않게** 설계하면 실루엣이 서로 구별된다. 겹치면 아무리 시드를 바꿔도 같은 캐릭터가 나온다.

제2 원칙: **같은 시드는 항상 같은 결과.** 캐릭터 생성 경로에서 `math.Random` 을 절대 쓰지 않는다. 시드 재현성이 깨지면 버그를 재현할 수 없고, 서버-클라이언트가 다른 캐릭터를 그린다.

---

## Rng — 결정론 난수

**파일: `lib/src/core/rng.dart`**

```dart
/// 시드 기반 결정론적 난수 생성기. xorshift32.
class Rng {
  Rng(int seed) : _s = (seed == 0 ? 0x9E3779B9 : seed) & 0xFFFFFFFF;

  /// 문자열 시드(캐릭터 이름 등)로부터 생성. FNV-1a.
  factory Rng.fromString(String s) {
    var h = 0x811C9DC5;
    for (final c in s.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return Rng(h);
  }

  int _s;

  int _next() {
    var x = _s;
    x ^= (x << 13) & 0xFFFFFFFF;
    x ^= x >> 17;
    x ^= (x << 5) & 0xFFFFFFFF;
    _s = x & 0xFFFFFFFF;
    return _s;
  }

  double get unit => _next() / 0x100000000;             // [0, 1)
  double range(double a, double b) => a + (b - a) * unit;
  int intRange(int a, int b) => a + (_next() % (b - a));
  bool chance(double p) => unit < p;
  T pick<T>(List<T> xs) => xs[_next() % xs.length];

  T weighted<T>(List<T> xs, List<double> w) {
    var total = 0.0;
    for (final v in w) { total += v; }
    var t = unit * total;
    for (var i = 0; i < xs.length; i++) {
      t -= w[i];
      if (t <= 0) return xs[i];
    }
    return xs.last;
  }

  /// 종 모양 분포. 평균 근처가 잦고 극단값이 드물어 자연스러운 변주를 만든다.
  double bell(double a, double b, {int k = 3}) {
    var sum = 0.0;
    for (var i = 0; i < k; i++) { sum += unit; }
    return a + (b - a) * (sum / k);
  }

  double signed([double scale = 1]) => (unit * 2 - 1) * scale;

  double gaussian() {
    final u1 = math.max(unit, 1e-9);
    final u2 = unit;
    return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2);
  }

  /// 독립적으로 진행하는 자식 생성기. 부모의 상태를 소비하지 않는다.
  Rng branch(int salt) => Rng((_s ^ (salt * 0x9E3779B9)) & 0xFFFFFFFF);
}
```

### 세 가지 사용 규칙

**① `range` 대신 `bell` 을 기본으로 쓴다.**
균등분포는 극단값이 평균값만큼 자주 나온다. 인체 비율에 균등분포를 쓰면 목이 기린인 캐릭터가 1/6 확률로 나온다. `bell` 은 3회 평균이라 중앙이 두껍다. **비율·치수에는 항상 `bell`, 카테고리 선택에는 `weighted`.**

**② `branch` 로 하위 시스템을 격리한다.**
장비 생성이 몸 비율 생성의 난수 상태를 소비하면, **장비 규칙을 하나 추가하는 것만으로 기존 모든 캐릭터의 체형이 바뀐다.** 이것은 절차적 시스템에서 가장 흔하고 가장 치명적인 버그다.

> ### ✅ `branch` 는 루트 시드에서 파생한다 (2026-08-06 수정)
>
> ```dart
> Rng branch(int salt) => Rng((_root ^ (salt * 0x9E3779B9)) & 0xFFFFFFFF);
> ```
>
> `_root` 는 생성 당시의 시드이며 소비되지 않는다. 그래서 **부모 스트림을 얼마나 소비한 뒤에
> 불러도 같은 salt 는 언제나 같은 자식을 낸다.** 생성 규칙을 하나 추가해도 다른 하위 시스템의
> 결과가 보존되므로, 생성기를 계속 손볼 수 있다.
>
> 이 불변식은 **`test/rng_test.dart` 가 지킨다**. 예전 구현(`_s` 파생)으로 되돌리면 테스트가
> 즉시 실패한다 — 조용한 회귀가 불가능하다.

```dart
final r = Rng(seed);
final palette = Palette.hero(r.branch(11));      // 색은 독립 브랜치
final gear    = buildGear(r.branch(23));         // 장비도 독립 브랜치
final body    = buildBody(r);                    // 메인 스트림은 마지막에
```

salt 상수는 **한 번 정하면 절대 바꾸지 않는다** (바꾸면 모든 시드의 결과가 바뀐다). 소수를 쓰면 충돌이 적다: 11, 23, 37, 53, 71, 97.

**③ 생성 순서를 바꾸지 않는다.**
`r.bell()` 호출 순서를 한 줄 바꾸면 그 이후 모든 값이 달라진다. 기존 필드 사이에 새 필드를 끼워 넣지 말고, **끝에 추가하거나 `branch` 를 쓴다.**

---

## Noise — 자연스러운 불규칙

**파일: `lib/src/core/noise.dart`**

```dart
class Noise {
  Noise(this.seed);
  final int seed;

  double _hash(int x, int y) {
    var h = seed ^ (x * 374761393) ^ (y * 668265263);
    h = (h ^ (h >> 13)) & 0xFFFFFFFF;
    h = (h * 1274126177) & 0xFFFFFFFF;
    h = (h ^ (h >> 16)) & 0xFFFFFFFF;
    return h / 0xFFFFFFFF;
  }
  static double _smooth(double t) => t * t * (3 - 2 * t);

  double at1(double x);                    // 1D 값 노이즈 0..1
  double at2(double x, double y);
  double fbm1(double x, {int octaves = 4, double gain = 0.5, double lacunarity = 2});
  double fbm2(double x, double y, {...});
  double signed1(double x, {int octaves = 3});      // -1..1, 변위에 바로 곱함
  double signed2(double x, double y, {int octaves = 3});
}

/// 여러 사인파를 합쳐 주기적이면서도 반복이 눈에 띄지 않는 요동을 만든다.
/// 호흡, 근육 떨림, 불꽃 명멸처럼 "살아 있는" 정지 상태에 쓴다.
double wobble(double t, double seed) =>
    math.sin(t * 1.00 + seed) * 0.60 +
    math.sin(t * 1.71 + seed * 2.3) * 0.28 +
    math.sin(t * 2.93 + seed * 5.1) * 0.12;
```

**용도별 선택**:

| 목적 | 함수 | 파라미터 |
|------|------|----------|
| 실루엣 요철 (몬스터 살덩이) | `signed1(t * 6)` | octaves 3 |
| 표면 미세 디테일 | `at1(seed * 13.7 + i * 3.3)` | 파츠 고정 시드 |
| 지형/천 결 | `fbm2(x, y)` | octaves 4~5 |
| 호흡·아이들 | `wobble(t, seed)` | — |
| 불꽃·마법 명멸 | `wobble(t * 3.2, seed)` | 시간 배율만 조정 |

**규칙**: `Noise` 인스턴스를 매 프레임 새로 만들지 않는다. 파일 최상단이나 액터 필드에 한 번 만들어 재사용한다 — 매번 새로 만들면 무늬가 프레임마다 바뀌어 지글거린다.

---

## Palette — 조화로운 색을 유도하기

**파일: `lib/src/core/scheme.dart`**

> **개별 색을 독립적으로 뽑으면 조화가 깨진다.** 하나의 기준 색상환 각도에서 유사색/보색 관계로 파생시켜야 "디자이너가 고른 색"처럼 보인다.

```dart
class Palette {
  const Palette({
    required this.skin, required this.skinDeep, required this.hair,
    required this.cloth, required this.clothShade, required this.accent,
    required this.leather, required this.metal, required this.metalWarm,
    required this.eye, required this.glow,
  });
  final Color skin, skinDeep, hair, cloth, clothShade, accent,
              leather, metal, metalWarm, eye, glow;

  /// 영웅 계열. 채도 높은 주조색 + 금속 + 자연스러운 피부.
  factory Palette.hero(Rng r) {
    // 주조색: 파랑~보라, 청록, 진홍 중 하나. 각 대역 안에서만 흔들어
    // "탁한 중간 색"이 나오지 않게 한다.
    final band = r.weighted([210.0, 265.0, 175.0, 350.0, 30.0], [3, 2, 2, 2, 1]);
    final baseHue = band + r.signed(14);
    final accentHue = baseHue + (r.chance(0.5) ? 150 : -150) + r.signed(18);

    final skinHue = r.range(20, 34);
    final skinLight = r.bell(0.42, 0.78);
    final skinSat = r.range(0.24, 0.46) * (1.25 - skinLight * 0.5);

    final metalHue = r.chance(0.35) ? r.range(38, 48) : r.range(200, 225);
    final metalSat = metalHue < 100 ? r.range(0.30, 0.5) : r.range(0.04, 0.13);

    return Palette(
      skin: hsl(skinHue, skinSat, skinLight),
      skinDeep: hsl(skinHue - 8, (skinSat + 0.22).clamp(0, 1), skinLight * 0.52),
      hair: r.chance(0.25)
          ? hsl(accentHue, r.range(0.45, 0.7), r.range(0.4, 0.6))
          : hsl(r.range(18, 40), r.range(0.12, 0.55), r.range(0.08, 0.34)),
      cloth: hsl(baseHue, r.range(0.42, 0.64), r.range(0.30, 0.44)),
      clothShade: hsl(baseHue - 12, r.range(0.5, 0.7), r.range(0.14, 0.22)),
      accent: hsl(accentHue, r.range(0.6, 0.85), r.range(0.46, 0.60)),
      leather: hsl(r.range(20, 34), r.range(0.28, 0.46), r.range(0.14, 0.26)),
      metal: hsl(metalHue, metalSat, r.range(0.52, 0.68)),
      metalWarm: hsl(metalHue - 10, (metalSat + 0.2).clamp(0, 1), r.range(0.30, 0.42)),
      eye: hsl(accentHue + r.signed(25), r.range(0.55, 0.9), r.range(0.55, 0.72)),
      glow: hsl(accentHue, r.range(0.7, 1.0), r.range(0.6, 0.72)),
    );
  }

  /// 몬스터 계열. 살/키틴/독기. 영웅과 색이 겹치지 않도록 대역을 분리한다.
  factory Palette.monster(Rng r) {
    final family = r.intRange(0, 4);
    late double bodyHue, bodySat, bodyLight, glowHue;
    switch (family) {
      case 0:  // 부패한 살덩이
        bodyHue = r.range(300, 355); bodySat = r.range(0.18, 0.34);
        bodyLight = r.range(0.28, 0.42); glowHue = r.range(70, 100);
      case 1:  // 갑각/키틴
        bodyHue = r.range(230, 275); bodySat = r.range(0.24, 0.44);
        bodyLight = r.range(0.16, 0.28); glowHue = r.range(150, 185);
      case 2:  // 화산암/재
        bodyHue = r.range(10, 28);   bodySat = r.range(0.10, 0.24);
        bodyLight = r.range(0.14, 0.24); glowHue = r.range(18, 40);
      default: // 심연/그림자
        bodyHue = r.range(190, 225); bodySat = r.range(0.22, 0.40);
        bodyLight = r.range(0.13, 0.24); glowHue = r.range(280, 320);
    }
    return Palette( /* bodyHue 파생 + glowHue 로 eye/glow/accent */ );
  }
}
```

### 팔레트 설계 규칙

1. **색상환 대역(band)을 이산적으로 뽑는다.** 0~360 을 균등하게 뽑으면 "탁한 겨자색" 같은 실패색이 나온다. 검증된 대역(210 파랑, 265 보라, 175 청록, 350 진홍, 30 주황)에서 `weighted` 로 고르고 ±14° 만 흔든다.
2. **강조색은 보색(±150°)에서.** 정확한 180° 보색은 진동해 보이므로 150° 를 쓴다.
3. **피부 채도는 명도에 반비례.** `skinSat = base * (1.25 - skinLight * 0.5)`. 밝은 피부가 채도까지 높으면 화상 입은 것처럼 보인다.
4. **금속은 두 갈래.** 금(38~48°, 채도 0.30~0.5) 또는 강철(200~225°, 채도 0.04~0.13). 그 사이는 없다.
5. **영웅과 몬스터의 색 대역을 분리한다.** 게임플레이 판독성 — 플레이어가 색만 보고 적/아군을 구분해야 한다.
6. **아이소 씬 전용 추가 규칙**: 캐릭터는 배경 타일보다 **명도 대비를 크게** 잡는다. 아이소 게임은 캐릭터가 작아 배경에 묻히기 쉽다. `luminance()` 로 배경 평균과 0.25 이상 차이를 확보한다.

세계관 공기색은 `core/palette.dart` 의 `Pal` 에 있다 (`voidDeep`, `fogBlue`, `arcaneCyan`, `emberOrange`, `venomGreen`, `goldLeaf` 등). 배경·안개·이펙트는 여기서 가져와 전 씬이 같은 공기를 공유하게 한다.

---

## HumanoidSpec — 원형 다이얼

**파일: `lib/src/actor/spec.dart`**

```dart
enum Archetype { knight, berserker, ranger, mage, assassin, paladin }
enum WeaponKind { sword, greatsword, axe, staff, spear, daggers, bow, none }
enum HeadGear { none, circlet, hood, halfHelm, fullHelm, hornedHelm }
```

### 원형별 체형 다이얼 (핵심 로직)

네 개의 다이얼이 모든 것을 몬다:

| 원형 | heads (등신) | broad (어깨) | bulk (근육) | poise (자세) |
|------|-------------|-------------|------------|-------------|
| knight | 7.2 – 7.8 | 1.05 – 1.16 | 0.55 – 0.75 | 0.50 |
| berserker | 6.6 – 7.1 | 1.16 – 1.34 | 0.82 – 1.00 | 0.20 |
| ranger | 7.6 – 8.1 | 0.94 – 1.02 | 0.34 – 0.50 | 0.70 |
| mage | 7.4 – 8.0 | 0.86 – 0.96 | 0.18 – 0.36 | 0.85 |
| assassin | 7.8 – 8.3 | 0.90 – 0.99 | 0.32 – 0.48 | 0.90 |
| paladin | 7.0 – 7.6 | 1.10 – 1.24 | 0.62 – 0.82 | 0.45 |

전부 `r.bell(a, b)` 로 뽑는다. **대역이 서로 겹치지 않는 것**이 핵심: berserker(6.6~7.1)와 assassin(7.8~8.3)은 절대 같은 등신이 될 수 없다.

```dart
static HumanoidSpec generate(int seed, {Archetype? forceArchetype}) {
  final r = Rng(seed);
  final arch = forceArchetype ?? r.pick(Archetype.values);

  late double heads, broad, bulk, poise;
  switch (arch) {
    case Archetype.knight:
      heads = r.bell(7.2, 7.8); broad = r.bell(1.05, 1.16);
      bulk = r.bell(0.55, 0.75); poise = 0.5;
    case Archetype.berserker:
      heads = r.bell(6.6, 7.1); broad = r.bell(1.16, 1.34);
      bulk = r.bell(0.82, 1.0);  poise = 0.2;
    // ... ranger / mage / assassin / paladin
  }

  const h = 180.0;
  final headH = h / heads;

  // 인체 비율의 표준 랜드마크. 여기서 크게 벗어나면 아무리 잘 칠해도
  // 사람으로 안 보이므로, 변주는 ±몇 퍼센트로만 준다.
  final ankleY    = h * r.bell(0.043, 0.052);
  final kneeY     = h * r.bell(0.272, 0.292) * (1 + (poise - 0.5) * 0.03);
  final hipY      = h * r.bell(0.508, 0.532);
  final waistY    = h * r.bell(0.610, 0.632);
  final chestY    = h * r.bell(0.735, 0.755);
  final shoulderY = h * r.bell(0.812, 0.832);
  final neckY     = h * 0.848;
  final chinY     = h - headH * r.bell(0.94, 1.02);

  return HumanoidSpec._(
    seed: seed, archetype: arch,
    palette: Palette.hero(r.branch(11)),        // ← 색은 독립 브랜치
    height: h, headHeight: headH,
    shoulderWidth: h * 0.232 * broad,
    chestWidth:    h * 0.196 * broad,
    waistWidth:    h * 0.146 * (0.85 + broad * 0.18),
    hipWidth:      h * 0.166 * (0.9 + broad * 0.12),
    neckWidth:     h * 0.050 * (0.85 + bulk * 0.4),
    // ... 랜드마크 y, 사지 길이, 두께
    armThickness: h * 0.030 * (0.78 + bulk * 0.62),
    legThickness: h * 0.040 * (0.80 + bulk * 0.52),
    muscle: bulk,
    depthOffset: h * r.bell(0.030, 0.048),
    weapon: /* 원형별 weighted */,
    headGear: /* 원형별 weighted */,
    // ...
  );
}
```

### 장비 확률표 (핵심 로직 — 원형의 정체성이 여기서 완성된다)

| 원형 | weapon (가중치) | headGear (가중치) | cape | pauldrons | shield | armorHeaviness |
|------|-----------------|-------------------|------|-----------|--------|----------------|
| knight | sword 5, spear 2, axe 2 | halfHelm 3, fullHelm 3, horned 2, none 1 | 0.75 | 0.90 | 0.45 | 0.70–.95 |
| berserker | axe 3, greatsword 3 | horned 4, none 3, halfHelm 2 | 0.30 | 0.90 | — | 0.25–.50 |
| ranger | bow 4, daggers 2, spear 1 | hood 4, none 3, circlet 1 | 0.55 | 0.35 | — | 0.20–.42 |
| mage | staff (고정) | hood 5, circlet 2, none 1 | 0.90 | 0.25 | — | 0.02–.16 |
| assassin | daggers 5, sword 1 | hood 6, none 1 | 0.70 | 0.20 | — | 0.12–.32 |
| paladin | sword 4, greatsword 2 | fullHelm 3, halfHelm 3, circlet 2 | 0.95 | 0.90 | 0.45 | 0.75–1.00 |

`glowRunes`: mage 0.9, paladin 0.6, 그 외 0.2. `trimAccent`: 0.7 공통.

---

## 인체 비율 랜드마크 표

**지면(y=0) 기준 높이 / 전체 키.** 이 값에서 크게 벗어나면 아무리 잘 칠해도 사람으로 안 보인다. 변주는 ±3% 이내로만.

| 랜드마크 | 비율 | 변주 |
|----------|------|------|
| 발목 | 0.043 – 0.052 | bell |
| 무릎 | 0.272 – 0.292 | bell, poise 로 ±3% |
| 골반 | 0.508 – 0.532 | bell |
| 허리 | 0.610 – 0.632 | bell |
| 가슴 | 0.735 – 0.755 | bell |
| 어깨 | 0.812 – 0.832 | bell |
| 목 | 0.848 | 고정 |
| 턱 | `1 - headH*(0.94~1.02)/h` | bell |

| 치수 | 키 대비 비율 |
|------|-------------|
| 어깨 폭 | 0.232 × broad |
| 가슴 폭 | 0.196 × broad |
| 허리 폭 | 0.146 × (0.85 + broad·0.18) |
| 골반 폭 | 0.166 × (0.9 + broad·0.12) |
| 위팔 | 0.163 – 0.176 |
| 아래팔 | 0.150 – 0.162 |
| 손 | 0.052 |
| 발 | 0.062 – 0.074 |

**짐승형(`Body.beast`)은 대역을 완전히 분리한다**: legRatio 0.40~0.46 (인간 0.485~0.525), hunch 0.12~0.34 (인간 0~0.06), 팔이 다리보다 길다. 실루엣만으로 "사람이 아니다"가 읽혀야 한다.

---

## 몬스터 생성 확장 패턴

> **🚧 미구현 설계 — 아래 `MonsterRole`·`MonsterParts` 는 `lib/` 에 존재하지 않는다.**
> 현재 완성된 Mob 4종(`art/mob/`)은 전부 트랙 B 로 **손수** 만들어졌다. 이 절은 트랙 A 로 몬스터를
> 절차 생성하기로 결정했을 때의 설계안이며, 그대로 import 하면 컴파일되지 않는다.
> 이름 있는 몬스터를 만들라는 요청이라면 [art-direction.md](art-direction.md) 로 갈 것.

`HumanoidSpec` 을 몬스터로 확장할 때의 설계.

**① 원형 축을 바꾼다.** 몬스터는 직업이 아니라 **위협 유형**으로 나눈다:

```dart
enum MonsterRole { swarm, brute, ranged, caster, elite, boss }
```

`swarm` 은 작고 많다(키 0.5배, 디테일 최소, `Quality.low` 허용), `boss` 는 크고 유일하다(키 2.5배, 발광 코어, 다중 파츠).

**② 신체 부위를 확률적 모듈로 만든다.**

```dart
class MonsterParts {
  final int legs;        // 2, 4, 6, 0(부유)
  final int arms;        // 0, 2, 4
  final bool tail, wings, horns, tentacles, extraEyes, exposedBone;
}
```

각 모듈은 `r.branch()` 로 독립 생성한다. 그래야 "날개 추가" 기능을 나중에 넣어도 기존 몬스터의 다리가 안 바뀐다.

**③ 변이(mutation)를 한 축으로 관리한다.** `mutation` 0..1 이 커질수록 비대칭·발광·노이즈 요철이 강해진다. 이 다이얼 하나로 같은 종의 일반/정예/보스를 만든다.

**④ 색은 `Palette.monster`.** 영웅과 색 대역이 겹치면 게임플레이 판독성이 무너진다.

**⑤ 아이소 실루엣 우선순위**: 몬스터는 플레이어가 **위협을 즉시 판단**해야 한다. 상단 실루엣(뿔·촉수·부유 오브)에 위협 등급을 인코딩한다 — swarm 은 상단이 매끈, boss 는 상단이 복잡.

---

## 분포 품질 검증

절차적 생성기는 **하나가 아니라 분포를 만든다.** 검증도 분포로 한다.

```dart
/// 갤러리: 시드 0..23 을 6×4 격자로 동시에 렌더한다.
/// 생성 규칙을 바꿀 때마다 이 화면을 먼저 본다.
for (var i = 0; i < 24; i++) {
  final spec = HumanoidSpec.generate(baseSeed + i);
  // 격자 셀에 렌더
}
```

**확인 항목:**

| 질문 | 실패 신호 | 처방 |
|------|-----------|------|
| 24개가 서로 구별되는가 | 전부 비슷 | 원형 대역이 겹침 → 대역 분리 |
| 흉한 극단값이 있는가 | 1~2개가 기괴 | `range` → `bell` 로 교체 |
| 원형이 실루엣으로 읽히는가 | 검게 칠하면 구분 불가 | 어깨폭·등신 대역 확대 |
| 색이 조화로운가 | 탁한 겨자색 등장 | 색상 band 를 이산 선택으로 |
| 특정 장비가 과다/부재 | 편중 | `weighted` 가중치 조정 |
| 48px 축소 후에도 구분되는가 | 뭉개짐 | 상단 실루엣 강화 |

**시드 안정성 테스트**: 코드를 고친 뒤 같은 시드가 같은 결과를 내는지 확인한다. 달라졌다면 `Rng` 호출 순서를 건드린 것이다 — 의도한 변경인지 반드시 판단한다.
