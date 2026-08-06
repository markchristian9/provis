# 아키텍처 — 레이어 규약과 모듈 지도

## 목차

1. [핵심 개념: 왜 이 레이어 구조인가](#핵심-개념-왜-이-레이어-구조인가)
2. [디렉토리 지도](#디렉토리-지도)
3. [좌표계 규약 (절대 규칙)](#좌표계-규약-절대-규칙) — 월드는 아이소, 캐릭터는 세워진 카드
4. [데이터 흐름: Seed → Spec → Body → Pose → Skeleton → Paths → Pixels](#데이터-흐름)
5. [모듈별 공개 API](#모듈별-공개-api)
6. [새 캐릭터를 추가하는 절차](#새-캐릭터를-추가하는-절차)
7. [의존성 규칙](#의존성-규칙)

---

## 핵심 개념: 왜 이 레이어 구조인가

절차적 캐릭터 코드가 무너지는 전형적인 방식은 **"그리기 코드 안에서 치수를 계산하고, 치수 계산 안에서 난수를 뽑는 것"**이다. 그러면 같은 시드가 다른 결과를 내고, 애니메이션을 바꾸면 실루엣이 깨지고, 조명을 바꾸면 모든 파츠를 손봐야 한다.

이 프로젝트는 그것을 **다섯 개의 단방향 레이어**로 끊는다:

| 레이어 | 책임 | 하지 말아야 할 것 |
|--------|------|------------------|
| `core/` | 난수·노이즈·스플라인·색·**셰이딩** | 캐릭터를 안다 |
| `rig/` | 치수(Body)·포즈(Pose)·순운동학(solve)·IK | 색이나 Canvas 를 안다 |
| `anim/` | 시간 → Pose, 베를레 2차 모션 | 그린다 |
| `render/` | 아이소 카메라(IsoView·Facing) | 난수를 뽑는다 |
| `actor/` | 위 넷을 조립한 한 종류의 캐릭터 | 위 넷의 내부를 재구현한다 |

**단방향**이라는 것이 핵심이다. `rig/` 는 셰이딩을 import 하지 않는다. 그래서 같은 골격에 완전히 다른 셰이딩을 입힐 수 있고, 같은 애니메이션 클립을 8등신 영웅과 4등신 몬스터에 동시에 재생할 수 있다.

---

## 디렉토리 지도

> **이 지도는 스냅샷이다.** 저장소가 활발히 진화 중이므로, 작업 시작 전
> `find lib -name '*.dart'` 로 실제 구조를 먼저 확인한다. **레이어 원칙과 아래
> 문서들의 기법은 파일이 옮겨져도 그대로 유효하다.**

```
lib/
├── entry.dart                 【트랙 B 진입점】 로스터 갤러리 앱
├── main.dart                  【트랙 A 진입점】 절차 액터 뷰어 (ActorComponent 인라인)
├── iso_game.dart              【게임 화면】 아이소 필드 — 완성 9종이 타일 위에 선다
└── src/
    ├── core/                  아무것도 캐릭터를 모른다
    │   ├── rng.dart           Rng — xorshift 결정론 난수
    │   ├── noise.dart         Noise — 값 노이즈·fbm, wobble()
    │   ├── spline.dart        Offset2 확장, tube()/blob()/web(), smoothClosedPath()
    │   ├── palette.dart       ColorTune 확장, Ramp, Pal (세계관 공기색)
    │   └── shading.dart       **유일한 셰이딩 계보** — LightRig, Finish 19종, Surface, paintSurface
    ├── rig/                   치수와 관절. Canvas 를 모른다
    │   ├── body.dart          Body — 골격 치수 (humanoid/beast 팩토리)
    │   ├── pose.dart          Pose/ArmPose/LegPose, Limb, Skeleton, solve()
    │   └── ik.dart            solveIk2(), reachable(), lerpAngle(), polar()
    ├── anim/                  시간 → Pose
    │   ├── verlet.dart        VerletChain, ClothStrip
    │   ├── clip.dart          Clip, sampleLoop()/sampleOnce() (Catmull-Rom 키프레임)
    │   ├── animator.dart      Animator — 클립 전환·블렌딩 상태 기계
    │   └── library.dart       Anims — 이름으로 꺼내 쓰는 클립 모음
    ├── render/                아이소 카메라와 생성용 팔레트
    │   ├── iso.dart           IsoView, Facing, paintTopPlane, BakedPart, detailFor
    │   └── palette.dart       hsl()/shiftColor()/mix(), Palette.hero/.monster
    ├── iso/
    │   └── iso_stage.dart     Artist → 아이소 맵 브리지 (IsoActor, y-sort, 지면, haze)
    ├── art/                   【트랙 B】 이름 있는 작품 캐릭터 — 완성 9종이 전부 여기
    │   ├── creature.dart      Artist 추상 클래스, Camp/Sex, kStage(1000×1400), kGround(1332)
    │   ├── anatomy.dart       headShape/torsoShape/limb/drawEye/handShape/bootShape/
    │   │                      hairStrand/clothSpine/breathe/jitter/drawMotes …
    │   ├── roster.dart        heroes(5) / monsters(4) / everyone — 등록하지 않으면 안 뜬다
    │   ├── pc/                aldric, kaelen, seraphine, lyra, vesper  (PC 5종)
    │   └── mob/               gorehide, vaelmorth, mourne, chitinis   (Mob 4종)
    ├── ui/                    갤러리 UI — entry_screen, portrait_card, backdrop, stage
    └── actor/                 【트랙 A】 조립
        ├── spec.dart          Archetype, HumanoidSpec.generate()
        └── humanoid_renderer.dart
```

### 주의 ① — 셰이딩 계보는 하나다 (2026-08-06 통합)

한때 `render/surface.dart`(계보 A)와 `core/shading.dart`(계보 B)가 공존했다. **계보 A 는 삭제됐다.**
`Finish` 19종이 각각 전용 알고리즘을 갖는 계보 B 가 품질에서 앞섰고, 완성 캐릭터 전원이 그쪽을
쓰고 있었기 때문이다.

| 사라진 것 (계보 A) | 지금 (`core/shading.dart`) |
|---|---|
| `SurfaceKind` 10종 | `Finish` **19종** |
| `Quality` enum | `detail` 0..1 |
| `Surface(albedo:, roughness:, metalness:…)` | `Surface(base, finish, {contrast, sss, glow, alpha})` |
| `LightRig.keyDir`(빛의 진행 방향) | `LightRig.dir`(**피사체 → 광원**) |
| `paintContactShadow` (호출 0건이었다) | `occlude` · `castShadow` |
| `paintTopPlane(…, iso)` | `topPlane(…, elevationSin:)` |
| `paintTrim` | `trimBand` |

옛 코드에서 위 왼쪽 열의 이름을 보면 낡은 것이다. 전 API 는 [artist-craft.md](artist-craft.md).

### 주의 ② — `palette.dart` 도 둘이다

- `core/palette.dart` → `ColorTune` 확장(darken/lighten/saturate/mix), `Ramp`(5단계 톤), `Pal`(전역 상수색)
- `render/palette.dart` → `hsl()`, `shiftColor()`, `mix()`, `luminance()`, `Palette`(캐릭터 1인분 색 조합)

셰이딩 내부는 `render/palette.dart` 의 `shiftColor`/`mix` 를 쓴다.

### 주의 ③ — Flame 과 `mix` 이름 충돌

`package:flame/components.dart` 는 `vector_math` 를 통해 전역 함수 `mix` 를 노출한다. 같은 파일에서 `render/palette.dart` 를 import 하면 **`ambiguous_import` 컴파일 오류**가 난다.

```dart
// ✗ 컴파일 실패
import 'package:flame/components.dart';
import 'src/render/palette.dart';

// ✓ 해법 1 — 프로젝트 팔레트에 접두사
import 'src/render/palette.dart' as pal;   // pal.mix(a, b, t)

// ✓ 해법 2 — Flame 쪽 이름을 숨긴다
import 'package:flame/components.dart' hide mix;
```

같은 이유로 `flutter/material.dart` 를 렌더 코드에 통째로 끌어오지 않는다. `Alignment`·`LinearGradient` 처럼 필요한 것만 `show` 로 가져온다:

```dart
import 'package:flutter/painting.dart' show Alignment, LinearGradient, RadialGradient;
```

---

## 좌표계 규약 (절대 규칙)

이 프로젝트의 게임 맵은 **항상 2.5D 아이소메트릭**이다. 따라서 좌표계가 두 개이며, 둘을 섞으면 캐릭터가 지면에서 떠 보이거나 정렬이 무너진다.

```
① 월드(타일) 공간 — 2:1 dimetric, 지면 평면
      screen.x = (wx - wy) * TILE_W / 2
      screen.y = (wx + wy) * TILE_H / 2 - wz * iso.heightScale
                 // heightScale = tileWidth * cosθ / √2  (iso.dart 참조)

② 액터 국소 공간 — 화면에 세워진 카드 (billboard)
        -y (위)
         │   ● headTop
         │   ● chest
   ──────┼───────────── y = 0  (발바닥 = 액터의 접지점)
        +y (아래)
      +x = 캐릭터의 정면(facing yaw = 0)이 투영된 방향
```

**핵심**: 지면은 아이소 평면에 눕고, 캐릭터는 그 위에 **수직으로 세워진 카드**다. 캐릭터 파츠를 아이소 평면에 투영하지 않는다 — 그러면 인체가 마름모로 찌그러진다. 아이소 투영은 **액터의 접지점 하나**에만 적용하고, 몸은 국소 공간에서 그대로 세워 그린다.

1. **액터 국소 원점은 발밑 지면.** 캐릭터의 모든 좌표는 접지점이 `Offset.zero`.
2. **y 는 화면 아래가 +.** 따라서 몸은 전부 음수 y 에 있다. `Body.shoulderY` 가 `-(hipHeight + torso)` 인 이유.
3. **캐릭터는 국소 +x 를 바라본다.** 8방향 페이싱은 포즈 데이터를 반전하지 않고 `IsoView` 의 yaw 로 처리한다 ([isometric.md](isometric.md) 참조). 좌우 미러가 필요한 방향은 렌더 시점에 `canvas.scale(-1, 1)`.
4. **수직 단축(foreshortening)**: 카메라 고도각 30°이므로 세로 길이에 `cos30° ≈ 0.866` 을 곱한다. 이 스케일은 렌더 진입부에서 `canvas.scale(1, kIsoSquash)` 한 번으로 적용하고, `Body`/`Pose` 치수에는 절대 섞지 않는다 — 섞으면 IK 길이 계산이 어긋난다.
5. **`HumanoidSpec` 의 `*Y` 필드만 예외로 양수**(지면 기준 높이)다. 렌더 시 `y = -값` 으로 변환한다. 이 규약은 `spec.dart` 주석에 명시돼 있다.
6. **near/far**: `armNear`/`legNear` 가 카메라에 가까운 쪽, `armFar`/`legFar` 가 먼 쪽. yaw 에 따라 어느 쪽이 near 인지 **바뀐다** — 렌더러가 yaw 부호를 보고 그리기 순서를 뒤집는다.
7. **깊이 정렬(y-sort)**: 액터의 월드 접지점 `(wx + wy)` 가 큰 것이 나중에(위에) 그려진다. Flame 에서는 `priority` 를 이 값으로 매 프레임 갱신한다.

상세한 투영 수식·8방향 처리·아이소 전용 실루엣 규칙은 [isometric.md](isometric.md).

각도 규약:
- 라디안. `_up = -π/2`, `_down = π/2`.
- `ArmPose.shoulder` + → 팔을 앞(+x)으로 들어 올림.
- `ArmPose.elbow`, `LegPose.knee` 는 **항상 0 이상**. 해부학적으로 반대로 꺾이지 않는다.
- `LegPose.ankle` + → 발끝을 든다.

---

## 데이터 흐름

```
int seed
   │  Rng(seed)                                    core/rng.dart
   ▼
HumanoidSpec.generate(seed)                        actor/spec.dart
   │  ├─ Archetype 선택 (knight/berserker/…)
   │  ├─ 체형 다이얼 (heads, broad, bulk, poise)
   │  ├─ 랜드마크 높이 (hipY, chestY, shoulderY…)
   │  ├─ Palette.hero(r.branch(11))                render/palette.dart
   │  └─ 장비 (weapon, headGear, cape, pauldrons)
   ▼
Body                                               rig/body.dart
   │  치수만. 색·장비를 모른다.
   ▼
Pose (애니메이션 클립이 매 프레임 생성)              rig/pose.dart
   │  관절 각도 + 비율 좌표만. 치수를 모른다.
   ▼
solve(body, pose) → Skeleton                       rig/pose.dart
   │  월드 좌표 관절점 (pelvis, chest, armNear.a..d …)
   ▼
Path (tube/blob/web 으로 실루엣 생성)               core/spline.dart
   ▼
paintSurface(canvas, path, surface, light)         render/surface.dart
   ▼
픽셀
```

**이 흐름을 건너뛰지 말 것.** 예를 들어 "팔을 조금 굵게" 하려고 `paintSurface` 호출부에서 Path 를 손보면, 같은 캐릭터의 다른 포즈에서 두께가 튄다. 두께는 `Body.bulk` 또는 `tube()` 의 radii 프로파일에서 조정한다.

---

## 모듈별 공개 API

### core/rng.dart — `Rng`

```dart
Rng(int seed)                    // seed 0 은 0x9E3779B9 로 대체
Rng.fromString(String s)         // FNV-1a 해시
double get unit                  // [0, 1)
double range(double a, double b)
int intRange(int a, int b)
bool chance(double p)
T pick<T>(List<T> xs)
T weighted<T>(List<T> xs, List<double> w)
double bell(double a, double b, {int k = 3})   // 종 모양 분포
double signed([double scale = 1])              // -scale..+scale
double gaussian()
Rng branch(int salt)             // 상태를 소비하지 않는 자식 생성기
```

**핵심 로직**: xorshift32. 캐릭터 생성 경로에서 `math.Random` 을 절대 쓰지 않는다 — 시드 재현성이 깨진다.

**`branch` 의 존재 이유**: 장비 생성이 몸 비율 생성의 난수 상태를 소비하면, 장비 규칙을 하나 추가하는 것만으로 기존 모든 캐릭터의 체형이 바뀐다. 독립적으로 발전시켜야 하는 하위 시스템마다 `r.branch(고유상수)` 를 준다.

### core/noise.dart — `Noise`

```dart
Noise(int seed)
double at1(double x)                              // 1D 값 노이즈 0..1
double at2(double x, double y)
double fbm1(double x, {int octaves = 4, double gain = 0.5, double lacunarity = 2})
double fbm2(double x, double y, {...})
double signed1(double x, {int octaves = 3})       // -1..1
double signed2(double x, double y, {int octaves = 3})

double wobble(double t, double seed)              // 최상위 함수. 3개 사인파 합성
```

`wobble` 은 호흡·근육 떨림·불꽃 명멸처럼 "살아 있는 정지 상태"에 쓴다. 주기가 무리수 비율(1.0 : 1.71 : 2.93)이라 반복이 눈에 띄지 않는다.

### core/spline.dart

```dart
extension Offset2 on Offset { Offset get perp; Offset normalized(); Offset rotated(double a); double get angle; }
Offset lerpO(Offset a, Offset b, double t)
double lerpD(double a, double b, double t)
double clamp01(double v)
double smoothstep(double edge0, double edge1, double x)

Path smoothOpenPath(List<Offset> pts, {double tension = 1.0})
Path smoothClosedPath(List<Offset> pts, {double tension = 1.0})
List<Offset> resample(List<Offset> pts, int count)
List<Offset> smoothPolyline(List<Offset> pts, int samples, {double tension = 1.0})

Path tube(List<Offset> spine, List<double> radii, {bool capStart, bool capEnd,
          int samples = 22, double tension = 1.0, double bias = 0.0})
Path blob(Offset center, double rx, double ry, {int points = 14, double rotation = 0,
          double Function(double angle, double t)? warp})
Path web(Offset a, double ra, Offset b, double rb, {double bulge = 0.25})
Alignment alignIn(Rect b, Offset p)
```

상세는 [silhouette.md](silhouette.md).

### rig/body.dart — `Body`

전 필드가 `height` 기준 비율로 산출된 절대 길이(픽셀). 팩토리 두 개:
- `Body.humanoid(Rng r, {double height = 300})` — legRatio 0.485~0.525, hunch 0~0.06
- `Body.beast(Rng r, {double height = 320})` — legRatio 0.40~0.46, hunch 0.12~0.34, 팔이 다리보다 길다

**핵심 로직**: 인간형과 짐승형의 비율 대역이 **겹치지 않는다**. 실루엣만으로 종을 구분하려면 다리 비율과 hunch 를 겹치지 않게 유지해야 한다.

### rig/pose.dart

```dart
class ArmPose { double shoulder, elbow, wrist; }   // + 연산자, scaled(), lerp()
class LegPose { double hip, knee, ankle; }         // lerp()
class Pose { rootX, rootY, rootRot, spine, chest, neck, head,
             armNear, armFar, legNear, legFar,
             breath, squash, weaponSwing, mouth, eyeOpen, capeFlow, impact }
class Limb { Offset a, b, c, d; double angleAB, angleBC, angleCD; }
class Skeleton { pelvis, waist, chest, neckTop, headCenter, headTop,
                 spineAngle, chestAngle, headAngle,
                 armNear, armFar, legNear, legFar, body, pose;
                 Offset get groundContact; Rect get bounds; }
Skeleton solve(Body body, Pose pose)
```

`Pose` 는 **절대 좌표를 담지 않는다**. `rootX`/`rootY` 조차 키에 대한 비율이다. 상세는 [animation.md](animation.md).

### rig/ik.dart

```dart
Offset solveIk2(Offset root, Offset target, double l1, double l2, double bend)
Offset reachable(Offset root, Offset target, double maxLen)
double lerpAngle(double a, double b, double t)
Offset polar(Offset from, double angle, double len)
```

`bend` 는 ±1. 팔꿈치는 뒤로, 무릎은 앞으로 굽는 해부학적 제약을 호출부가 부호로 표현한다.

### anim/verlet.dart

```dart
class VerletChain {
  VerletChain({required Offset anchor, required int segments, required double segmentLength,
               Offset initialDir, double gravity = 900, double damping = 0.986,
               double stiffness = 0.62, int iterations = 6});
  List<Offset> pos, prev;
  Offset restDir; double restStrength;
  void step(double dt, Offset anchor, {Offset wind, Offset carry});
  void teleport(Offset anchor, {Offset dir});
}
class ClothStrip {
  ClothStrip({required Offset anchorLeft, required Offset anchorRight,
              required int segments, required double segmentLength, ...});
  double flare;                                   // A 라인 정도
  void step(double dt, Offset anchorLeft, Offset anchorRight, {Offset wind, Offset carry});
  Path silhouette({double hemSag = 0.18});
  List<Path> folds(int count);
}
```

`carry` 항이 앵커 이동을 관성으로 전달한다 — **달릴 때 망토가 뒤로 날리는 것은 중력이 아니라 이 항의 효과다.**

### render/light.dart — `LightRig`

```dart
LightRig({Offset dir, Offset rimDir, Color key, Color fill, Color rim,
          Color bounce, Color ambient, double intensity});
Alignment get keyAlign;             // dir 쪽으로 치우친 그라디언트 중심
LightRig copyWith({...});
LightRig get mirrored;              // 캔버스 반전 시 광원도 함께 뒤집는다
LightRig rotated(double radians);   // 파츠 회전 시 월드 조명 유지
static const heroic / infernal / spectral;          // 초상용 무드
static const daylight / dusk / moonlit / torchlit;  // 인게임 시각
static LightRig preset(int i);      // 0 정오 / 1 황혼 / 2 달빛 / 3 화톳불
```

`dir` 은 **피사체가 광원을 바라보는 방향**이다. 빛이 진행하는 방향이 아니다 — 부호를 헷갈리면 명암이 통째로 뒤집힌다.

`keyDir` 은 **빛이 진행하는 방향**(광원 → 피사체)이다. 광원 위치가 아니다. 부호를 헷갈리면 명암이 통째로 뒤집힌다.

### render/surface.dart

상세는 [artist-craft.md](artist-craft.md). 시그니처만:

```dart
enum SurfaceKind { skin, cloth, leather, metal, chitin, bone, hair, gem, stone, flesh }
enum Quality { low, medium, high }
class Surface { albedo, kind, roughness, metalness, sss, rim, ao, outline,
                emissive, emissiveStrength, detail;
                static Surface skin/flesh/cloth/leather/metal/chitin/bone/hair/gem/stone(...) }

void paintSurface(Canvas, Path, Surface, LightRig,
                  {Quality quality, double occlusion, double detailSeed, double? unitScale});
void paintContactShadow(Canvas, Path receiver, Path occluder, LightRig,
                        {double strength, double spread});
void paintGroundShadow(Canvas, Offset at, double width, double height, LightRig,
                       {double strength});
void paintTrim(Canvas, Path, Color, LightRig, {double width, double alpha});
void paintGlow(Canvas, Path, Color color, double radius, double strength);
```

### actor/spec.dart

```dart
enum Archetype { knight, berserker, ranger, mage, assassin, paladin }
enum WeaponKind { sword, greatsword, axe, staff, spear, daggers, bow, none }
enum HeadGear { none, circlet, hood, halfHelm, fullHelm, hornedHelm }
class HumanoidSpec {
  static HumanoidSpec generate(int seed, {Archetype? forceArchetype});
  // final 필드 26개: 랜드마크 높이, 사지 길이, 장비 플래그, palette
}
```

상세는 [procgen.md](procgen.md).

---

## 새 캐릭터를 추가하는 절차

> **🚦 먼저 트랙을 정한다.** 이름과 사연이 있는 간판 캐릭터인가, 시드로 찍는 군중인가.
> 잘못 고르면 파일이 쓰이지 않는 경로에 생기고 갤러리에 나타나지 않는다.

### 트랙 B — 이름 있는 작품 캐릭터 (완성 9종이 전부 이 방식)

1. **시각 논제를 한 문장으로 정한다** → [art-direction.md](art-direction.md)
2. **`example/lib/characters/<name>.dart`** 또는 **`art/mob/<name>.dart`** 에 `Artist` 상속 클래스를 만든다.
3. `art/anatomy.dart` 헬퍼로 부위를 조립하고 `core/shading.dart` 로 칠한다 → [artist-craft.md](artist-craft.md)
4. **`example/lib/characters/roster.dart`** 의 `heroes` / `monsters` 리스트에 등록한다. **이걸 빠뜨리면 갤러리에 안 뜬다.**
5. `test/render_sheet_test.dart` 로 시트를 뽑아 확인한다.

### 트랙 A — 시드 기반 인게임 액터

1. **명세 타입 정의** — `lib/src/actor/<name>_spec.dart`
   - `Archetype` 에 대응하는 원형 enum 을 먼저 만든다. 원형 없이 파라미터를 독립 무작위화하면 "특징 없는 평균"만 나온다.
   - `Rng.branch()` 로 하위 시스템(장비/색/변이)을 분리한다.
2. **치수 매핑** — `Body` 를 명세에서 만든다. 새 골격(꼬리·날개·다수 다리)이 필요하면 `Body` 를 확장하지 말고 별도 클래스로 만든 뒤 `solve` 에 대응하는 solver 를 새로 쓴다.
3. **포즈 클립** — `lib/src/anim/<name>_clips.dart`. `Pose` 를 시간 함수로 생성. 절대 좌표 금지.
4. **렌더러** — `lib/src/render/<name>_renderer.dart`. `Skeleton` → `Path` 목록 → `paintSurface`.
   - 그리기 순서는 **뒤에서 앞으로**: farLeg → farArm → cape → torso → head → nearLeg → nearArm → weapon → FX
5. **갤러리 등록** — `main.dart` 에서 시드 그리드로 12~24개를 동시에 띄운다. 한 개만 보고 판단하면 **분포의 실패**(전부 비슷하거나 극단값이 흉함)를 놓친다.

---

## 의존성 규칙

```
actor → render → core
  ↓       ↓
 anim →  rig  → core
```

- `core/` 는 아무것도 import 하지 않는다 (`dart:ui`, `dart:math` 제외).
- `rig/` 는 `core/` 만 import 한다. **`dart:ui` 의 Canvas 를 만지지 않는다** (Offset/Rect 는 허용).
- `render/` 는 `core/` 만 import 한다. `rig/` 를 import 해도 되지만, `Skeleton` 을 받는 함수는 렌더러(actor 레이어)에 두는 편이 재사용에 유리하다.
- `anim/` 은 `core/`·`rig/` 를 import 한다.
- 순환 import 가 생기면 레이어를 잘못 나눈 것이다. 공통 부분을 `core/` 로 내린다.
