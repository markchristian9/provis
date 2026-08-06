# 캐릭터 제작 — Artist · core/shading · anatomy

**이 저장소의 유일한 셰이딩 계보이자, AAA 품질이 나오는 경로다.** 완성 9종(PC 5 · Mob 4)이 전부 이 방식이며, 2026-08-06 계보 통합 이후 아이소 액터(`humanoid_renderer`)도 같은 API를 쓴다.

`lib/src/core/shading.dart`, `lib/src/art/creature.dart`, `lib/src/art/anatomy.dart`, `lib/src/art/roster.dart` 의 완전한 참조.

> **폐기됨**: `render/surface.dart`(`SurfaceKind` 10종, 9패스)와 `render/light.dart`(`keyDir` 규약)는
> 삭제됐다. 옛 문서나 코드에서 `SurfaceKind`·`Quality`·`paintTopPlane(…, iso)`·`paintContactShadow`
> 를 보면 낡은 것이다. 지금은 `Finish` 16종과 `detail`(0..1) 하나뿐이다.

## 목차

0. [셰이딩의 제1 원리](#셰이딩의-제1-원리)
1. [핵심 개념: 왜 자동 생성하지 않는가](#핵심-개념-왜-자동-생성하지-않는가)
2. [Artist 계약 (전체 소스)](#artist-계약)
3. [좌표계 — kStage / kGround](#좌표계--kstage--kground)
4. [LightRig (트랙 B) — 부호 규약이 트랙 A 와 반대](#lightrig-트랙-b)
5. [Finish 16종과 재질별 기법](#finish-16종과-재질별-기법)
6. [Surface · paintSurface (전체 소스)](#surface--paintsurface)
7. [마무리 함수 — 품질을 결정하는 네 가지](#마무리-함수)
8. [독립 효과 — 발광·그림자·윤곽](#독립-효과)
9. [anatomy.dart 부위 헬퍼](#anatomydart-부위-헬퍼)
10. [얼굴 — 눈 6겹이 캐릭터의 생사를 가른다](#얼굴)
11. [로스터 등록](#로스터-등록)
12. [신규 캐릭터 작성 골격](#신규-캐릭터-작성-골격)
13. [체크리스트](#체크리스트)

---

## 셰이딩의 제1 원리

절차적 2D 캐릭터가 싸구려로 보이는 이유는 형태가 아니라 **조명 논리의 부재**다. 파츠마다 임의의 그라디언트를 넣으면 각 파츠는 예뻐도 전체가 "스티커 콜라주"가 된다.

**① 파츠 하나 = `paintSurface` 한 번.** 이 함수는 클립 → 재질 고유 레이어 → AO → 림 순으로 쌓는다. 순서가 곧 결과이므로 호출부에서 개별 패스를 재조합하지 않는다.

**② 그림자는 차갑게, 하이라이트는 따뜻하게.** 그림자를 검정 쪽으로 어둡게만 하면 진흙처럼 탁해진다. 그림자에는 환경광(`ambient`)을, 하이라이트에는 키라이트의 색온도(`key`)를 섞는다. `Ramp.of()`(`core/palette.dart`)가 이 규칙을 구현하며, 모든 `Surface` 가 `ramp` 게터로 그것을 통과한다. **이 한 가지 규칙이 플라스틱과 실물의 차이를 만든다.**

**③ 밝아질수록 채도가 내려가고, 명암 경계에서는 오른다.** 하이라이트의 채도를 안 낮추면 형광색이 되고, 터미네이터에서 채도가 안 오르면 회색 그라디언트가 된다. 후자가 피부의 SSS 붉은 띠이며, `Finish.skin` 이 그것을 그린다.

**④ 색은 전부 HSL 에서 조작한다.** RGB 로 직접 더하고 빼면 금방 탁해지고 색상이 예측 불가능하게 튄다. `core/palette.dart` 의 `darken`/`lighten`/`saturate`/`shiftHue`/`mix` 를 쓴다.

---

## 핵심 개념: 왜 자동 생성하지 않는가

`lib/src/art/anatomy.dart` 머리말은 이 트랙의 철학을 명시한다:

> 캐릭터가 서로 닮는 문제 때문에 **범용 "인체 시스템"을 의도적으로 만들지 않았다.** 비율과 포즈는
> 캐릭터별로 직접 정한다.

절차적 생성기는 평균을 만든다. 평균은 안전하지만 기억에 남지 않는다. 간판 캐릭터는 **비율 자체가
캐릭터의 정체성**이므로(고어하이드의 머리는 인간의 2/3, 어깨는 머리의 5배), 공통 골격에서 파생시키는
순간 그 정체성이 사라진다.

`anatomy.dart` 가 제공하는 것은 **인체 시스템이 아니라 부위 형상 함수**다 — `headShape`, `torsoShape`,
`limb`, `handShape`. 어디에 어떤 크기로 놓을지는 캐릭터가 직접 정한다.

> **트랙 A(`HumanoidSpec`)를 여기로 끌어오지 마라.** 두 철학은 목적이 달라서 공존하는 것이지,
> 통합 대상이 아니다.

---

## Artist 계약

**파일: `lib/src/art/creature.dart`**

```dart
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

  Camp get camp;                    // Camp.player | Camp.monster

  /// 플레이어 캐릭터만 성별을 가진다.
  Sex? get sex;                     // Sex.male | Sex.female | null

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

  /// 포즈가 화면 왼쪽을 향하는가.
  ///
  /// 대치 화면에서 플레이어는 오른쪽의 적을, 몬스터는 왼쪽의 플레이어를
  /// 봐야 한다. 이 값이 맞지 않는 캐릭터만 좌우를 뒤집는다.
  bool get facesLeft => false;
}

enum Sex { male, female }
enum Camp { player, monster }
```

**`detail` 규약**: 카드 썸네일은 `detail: 0.3~0.5`, 대형 스테이지는 `1.0`. 각 파츠에서
`if (detail > 0.5)` 로 미세 텍스처·파티클·주름을 게이팅한다. `paintSurface` 도 `detail` 을 그대로
받는다.

**결정론 규약**: `paint` 안에서 `math.Random` 을 쓰지 않는다. 흔들림은 `t` 의 함수(`breathe`,
`jitter`, `wobble`)로, 텍스처 무작위성은 고정 `seed` 로 만든다. 같은 `t` 가 같은 그림을 내야
스냅샷 테스트가 성립한다.

---

## 좌표계 — kStage / kGround

```dart
/// 모든 캐릭터가 그려지는 공통 좌표계.
///
/// 실제 화면 크기와 무관하게 캐릭터는 언제나 이 논리 캔버스 안에 그려지고,
/// 표시할 때만 스케일된다. 덕분에 카드 썸네일과 대형 스테이지가 완전히 같은
/// 코드로 렌더된다. 8등신 기준으로 머리 높이가 약 175 이므로 눈·입 같은
/// 디테일에 충분한 해상도가 남는다.
const Size kStage = Size(1000, 1400);

/// 지면선. 모든 캐릭터의 발바닥이 이 높이에 닿는다.
const double kGround = 1332;
```

- 가로 중심은 `500`. 캐릭터는 보통 `x = 500` 근처에 선다.
- 8등신이면 머리 높이 ≈ 175, 정수리 ≈ `y = 1332 - 1400 = -68`… 이 아니라 실제 키를 1100~1250 사이로
  잡는다(`framing` 이 그 범위를 크롭한다).
- **트랙 A 의 아이소 좌표계(발밑 원점, -y 가 위)와 다르다.** 여기서는 `+y` 가 아래이고 원점이
  캔버스 좌상단이다.

---

## LightRig (트랙 B)

**파일: `lib/src/core/shading.dart`**

```dart
class LightRig {
  const LightRig({
    this.dir = ...,        // 피사체가 광원을 바라보는 방향 ← 트랙 A 와 반대
    this.rimDir = ...,
    this.key = ...,        // 키라이트 색
    this.fill = ...,       // 필라이트 색
    this.rim = ...,        // 림라이트 색
    this.bounce = ...,     // 바닥 반사광
    this.ambient = ...,    // 환경광
    this.intensity = 1.0,
  });

  final Offset dir, rimDir;
  final Color key, fill, rim, bounce, ambient;
  final double intensity;

  Alignment get keyAlign => Alignment(dir.dx * 0.78, dir.dy * 0.78);
  Alignment get rimAlign => Alignment(rimDir.dx, rimDir.dy);

  LightRig copyWith({Offset? dir, Color? rim, Color? key, double? intensity});

  static const heroic   = LightRig();     // 기본
  static const infernal = LightRig(...);  // 지옥·용암
  static const spectral = LightRig(...);  // 유령·냉기
}
```

> ### ⚠️ 조명 부호 규약이 트랙 A 와 정반대다
>
> | | 트랙 B `core/shading.dart` | 트랙 A `render/light.dart` |
> |---|---|---|
> | 필드명 | `dir` | `keyDir` |
> | 의미 | **피사체 → 광원** (광원을 바라보는 방향) | **광원 → 피사체** (빛이 진행하는 방향) |
> | 프리셋 | `heroic` / `infernal` / `spectral` | `preset(0~3)` 정오/황혼/달빛/던전 |
>
> 두 계보를 한 파일에서 섞으면 **명암이 통째로 뒤집힌다.** 파일의 import 를 먼저 확인하라.

**캐릭터마다 자기 `light` 를 갖는 것이 의도된 설계다.** 트랙 B 는 초상 갤러리이므로 캐릭터별 무드
조명이 정체성의 일부다(고어하이드의 화톳불, 모른의 냉기). 인게임 씬(트랙 A)의 "하나의 LightRig 공유"
규칙은 여기 적용되지 않는다.

예 — Gorehide 의 조명:

```dart
@override
LightRig get light => const LightRig(
      dir: Offset(-0.62, -0.78),
      rimDir: Offset(0.84, -0.44),
      key: Color(0xFFFFE9C0),
      fill: Color(0xFF4A5C48),
      rim: Color(0xFFFFB871),
      bounce: Color(0xFF7A5A3A),
      ambient: Color(0xFF221E18),
    );
```

---

## Finish 16종과 재질별 기법

```dart
enum Finish {
  skin, metal, gold, cloth, leather, scale, chitin, fur,
  hair, bone, wood, gem, energy, slime, stone, membrane,
}
```

각 `Finish` 는 **전용 알고리즘**으로 그려진다. 무엇이 그 재질을 그 재질로 읽히게 하는지가 코드에
주석으로 박혀 있다 — 새 재질을 추가할 때 같은 밀도로 쓸 것.

| Finish | 핵심 기법 | 왜 |
|---|---|---|
| `metal` | **3단 환경 밴딩**(위=차가운 하늘 / 중간=어두운 지평선 / 아래=따뜻한 지면) + 좁은 스펙큘러 스트라이프 + 스크래치 | 금속은 확산이 거의 없고 환경을 반사한다. **이 밴딩이 금속을 금속으로 읽히게 한다** |
| `gold` | `metal` + `warm: true` (하늘=크림, 지면=구리) | 금은 반사색 자체가 따뜻하다 |
| `skin` | 명암 경계에 **붉은 SSS 띠** + 넓고 흐릿한 피지막 스펙큘러 | 이 띠가 없으면 아무리 형태가 좋아도 밀랍 인형 |
| `cloth` | 부드러운 확산(softness 0.75) + **가장자리가 안쪽보다 밝음**(shear) + 섬유결 | 실 끝에서 빛이 산란한다 |
| `leather` | 확산(0.35) + sheen + grain | |
| `scale` | 확산(0.45) + sheen(좁게) | |
| `chitin` | 어두운 램프 + **이리데센스**(보라→청록 그라디언트) + 좁고 날카로운 하이라이트 | 다층 구조의 간섭색 |
| `fur` | 아주 부드러운 확산(0.7) + 넓은 sheen | |
| `hair` | **앤이소트로픽 띠** — 점이 아니라 결을 가로지르는 링 | 원통 다발의 광택. 점 하이라이트를 쓰면 플라스틱이 된다 |
| `bone` | 누런 기가 섞인 램프 + grain | |
| `wood` | 확산 + **나뭇결 9줄**(노이즈로 휜 선) | |
| `gem` | **내부 전반사** — 중심이 어둡고 가장자리·반대면이 밝음 + 흰 코어 | 보석은 빛이 안에서 튄다 |
| `energy` | 중심이 **흰색으로 포화** → 바깥으로 고유색. `BlendMode.plus` 필수. AO·rim 건너뜀 | 발광체는 센서를 날린다 |
| `slime` | 반투명 — 가장자리가 두꺼워 진하고 중심이 밝음 + 젖은 하이라이트 | |
| `stone` | 확산(0.5) + 강한 grain(0.16) | |
| `membrane` | **조명 방향과 무관하게 전체가 은은히 빛남**, 뼈대 근처만 어두움 | 얇은 막은 빛을 투과시킨다 |

**공통 후처리**: `paintSurface` 는 재질 분기 후 `_ambientOcclusion`(아랫면 어둡게 + 바닥 반사광)과
`_rimInside`(림 방향 끝만 밝힘)를 자동으로 얹는다. `energy` 는 rim 을 건너뛴다.

---

## Surface · paintSurface

```dart
class Surface {
  const Surface(
    this.base,          // 위치 인자 1: 기본색
    this.finish, {      // 위치 인자 2: 재질
    this.contrast = 1.0,
    this.sss,           // 표면하 산란색. 피부·막·슬라임에서 명암 경계에 배어 나온다
    this.glow = 0.0,
    this.glowColor,
    this.alpha = 1.0,
  });

  final Color base;
  final Finish finish;
  final double contrast;
  final Color? sss;
  final double glow;
  final Color? glowColor;
  final double alpha;

  Ramp get ramp => Ramp.of(base, contrast: contrast);   // core/palette.dart
}

/// 파츠 하나를 칠한다.
void paintSurface(
  Canvas c,
  Path path,
  Surface s,
  LightRig l, {
  double detail = 1.0,     // 0..1. 카드 썸네일 0.3~0.5, 대형 스테이지 1.0
  int seed = 7,            // 텍스처 무작위성. 파츠마다 고정값을 준다
  bool rim = true,
  bool ao = true,
  double occlusion = 0.0,  // 뒤쪽 평면에 있는 파츠를 눌러 앞뒤를 가른다
}) {
  final b = path.getBounds();
  if (b.width < 0.5 || b.height < 0.5) return;
  final r = s.alpha < 1 ? s.ramp.withAlpha(s.alpha) : s.ramp;

  c.save();
  c.clipPath(path);
  switch (s.finish) { /* Finish 별 전용 알고리즘 */ }
  if (ao) _ambientOcclusion(c, b, l, s);
  if (rim && s.finish != Finish.energy) _rimInside(c, b, l, s);
  c.restore();

  if (s.glow > 0) {
    glowPath(c, path, s.glowColor ?? s.base, 18 * s.glow, alpha: 0.5 * s.glow);
  }
}
```

> **트랙 A 의 `paintSurface` 와 인자가 완전히 다르다.** 트랙 A 는
> `(quality, occlusion, detailSeed, unitScale)`, 트랙 B 는 `(detail, seed, rim, ao)`.
> 또한 트랙 B 는 **`saveLayer` 를 쓰지 않는다**(`clipPath` 만) — 성능 특성이 다르다.

사용 예:

```dart
final steel = Surface(const Color(0xFF8894A8), Finish.metal, contrast: 1.15);
paintSurface(c, pauldronPath, steel, light, detail: detail, seed: 3);

final flesh = Surface(const Color(0xFFB4795E), Finish.skin,
                      sss: const Color(0xFFC24A38));
paintSurface(c, armPath, flesh, light, detail: detail);

final core = Surface(const Color(0xFF57E8FF), Finish.energy,
                     glow: 0.9, glowColor: const Color(0xFF9AF4FF), alpha: 0.85);
paintSurface(c, corePath, core, light);
```

---

## 마무리 함수

**이 넷이 품질을 결정한다.** 파츠를 아무리 잘 칠해도 이것들이 없으면 종이를 오려 붙인 것처럼 보인다.

```dart
/// ① 형상 안쪽 가장자리를 어둡게 하는 접촉 그림자.
///
/// [from] 방향에서 다른 파츠가 덮고 있다고 가정한다. 팔이 몸통 위에 얹힐 때
/// 이 한 겹이 없으면 파츠가 종이처럼 겹쳐 보인다.
void occlude(Canvas c, Path p, Offset from, {double depth = 0.35, double alpha = 0.55});

/// ② 파츠 아래로 떨어지는 그림자. 겹친 파츠를 분리해 깊이를 만든다.
void castShadow(Canvas c, Path p,
    {Offset offset = const Offset(6, 10), double blur = 10, double alpha = 0.45});

/// ③ 형상의 윤곽을 정확히 따라가는 림라이트 밴드.
///
/// 클립 그라디언트로 만드는 값싼 림(_rimInside)과 달리 실루엣을 그대로 훑으므로,
/// 얼굴·어깨·무기날처럼 시선이 머무는 곳에만 선택적으로 쓴다.
void rimBand(Canvas c, Path p, LightRig l,
    {double width = 5, Color? color, double alpha = 0.85, double blur = 2.5});

/// ④ 갑옷 패널의 경계선. 홈은 어둡고 그 위 모서리는 밝다.
void panelLine(Canvas c, Path line, Ramp r, LightRig l,
    {double width = 3, double alpha = 1.0});
```

**적용 위치 — 최소한 이만큼은 넣는다:**

| 함수 | 어디에 |
|---|---|
| `occlude` | 턱 아래 목, 어깨보호대 아래 팔, 벨트 아래 몸통, 망토 아래 다리, 투구 아래 얼굴 |
| `castShadow` | 몸통 위에 얹히는 팔, 어깨 위 견갑, 머리 위 투구, 무기가 몸을 가로지를 때 |
| `rimBand` | 얼굴 윤곽, 어깨 상단, 무기날, 실루엣에서 가장 튀는 파츠 1~2곳 |
| `panelLine` | 갑옷 판의 분할선, 기계 이음매, 결정 파세트 |

`rimBand` 는 `Path.combine(PathOperation.difference, p, p.shift(-l.rimDir * width))` 로 띠를
만들므로 비용이 있다. **전 파츠에 쓰지 말고 시선이 머무는 곳에만.**

---

## 아이소메트릭 전용

계보 통합으로 아이소 액터도 이 API 를 쓴다. 초상 뷰에 없는 두 가지가 아이소에서 생긴다.

```dart
/// 위를 향한 면에 얹는 하늘빛 하이라이트.
///
/// 어깨·투구·어깨보호대·발등처럼 윗면이 실제로 보이는 파츠에만 준다. 사지
/// 옆면에 주면 오히려 형태가 납작해진다. paintSurface 직후에 호출한다.
/// [elevationSin] 은 카메라 고도각의 sin — 2:1 타일이면 0.5(=30°).
void topPlane(Canvas c, Path path, LightRig l,
    {double strength = 0.5, double elevationSin = 0.5});

/// 금속 트림·테두리. 단색 선이 아니라 광원 축 그라디언트여야 금속 띠로 읽힌다.
void trimBand(Canvas c, Path path, Color color, LightRig l,
    {double width = 2.0, double alpha = 0.9});
```

`LightRig` 에도 아이소용 API 가 있다:

```dart
LightRig get mirrored;              // 캔버스를 뒤집을 때 광원도 함께 뒤집는다
LightRig rotated(double radians);   // 파츠를 회전해 그릴 때 월드 조명을 유지한다
static LightRig preset(int i);      // 0 정오 / 1 황혼 / 2 달빛 / 3 화톳불
```

**인게임 씬은 하나의 `LightRig` 를 공유한다** — `LightRig.preset()` 넷은 그 용도다. 반면 갤러리 초상은 `Artist` 마다 `light` 를 갖는 것이 의도된 설계다(캐릭터별 무드 조명).

`Artist` 를 아이소 맵에 세우는 방법은 [isometric.md](isometric.md#작품-캐릭터를-아이소-맵에-세우기) 참조.

---

## 독립 효과

```dart
/// 형상 바깥으로 번지는 발광.
void glowPath(Canvas c, Path p, Color color, double blur,
    {double alpha = 0.6, BlendMode mode = BlendMode.plus});

/// 점광원. 코어 → 헤일로 → 스타버스트 3단.
void glowAt(Canvas c, Offset at, double radius, Color color,
    {double intensity = 1.0, bool star = false});

/// 두께를 가진 윤곽선. 실루엣을 다지는 마무리용.
void inkOutline(Canvas c, Path p, Color color, double width, {double alpha = 0.5});

/// 지면 접촉 그림자. 캐릭터를 바닥에 붙여 놓는다.
void groundShadow(Canvas c, Offset at, double rx, double ry,
    {double alpha = 0.55, Color color = const Color(0xFF05070E)});

const Color white = Color(0xFFFFFFFF);
```

**`groundShadow` 는 예외 없이 그린다.** 트랙 B 는 초상 구도라 아이소 2:1 비율에 얽매이지 않지만,
`rx : ry` 를 대략 `3 : 1` ~ `4 : 1` 로 납작하게 잡아야 바닥에 누운 것으로 읽힌다.

**발광체를 그렸으면 반사광을 돌려준다.** `glowAt` 으로 조명탄을 그렸다면, 그 빛을 받는 파츠에
같은 색의 `plus` 그라디언트를 한 겹 얹어야 광원이 장면에 속한 것으로 보인다.

---

## anatomy.dart 부위 헬퍼

**파일: `lib/src/art/anatomy.dart`** — 인체 시스템이 아니라 **부위 형상 함수 모음**이다.

```dart
/// 두개골. [turn] 은 3/4 시점의 회전(-1..1), [jaw]·[chin]·[cheek] 로 인상을 바꾼다.
Path headShape(Offset c, double w, double h,
    {double jaw = 0.74, double chin = 0.30, double turn = 0.0, double cheek = 1.0});

/// 몸통. 어깨-가슴-허리-골반 폭을 직접 준다. [bust] 는 여성 캐릭터.
Path torsoShape({required double top, required double bottom,
    required double shoulderW, required double chestW,
    required double waistW, required double hipW,
    double neckW = 0.0, double bust = 0.0});

/// 사지. 3점(어깨-팔꿈치-손목)과 3반지름. [swell] 이 근육 부풀림.
Path limb(Offset a, Offset b, Offset c,
    {required double r0, required double r1, required double r2, double swell = 1.18});

Path earShape(Offset at, double w, double h, {bool mirrored = false, double point = 0});
Path handShape(Offset wrist, ...);
Path bootShape(Offset ankle, double toeDir, double size, {double heel = 0.5});
Path hairStrand(...);                    // 머리카락 한 가닥 (tube 기반)
List<Offset> clothSpine(...);            // 천의 스파인 (망토·로브)

void drawKnuckles(...);                  // 손등 관절
void drawMuscleLine(...);                // 근육 분할선
void drawMotes(...);                     // 떠다니는 입자 (glowAt 사용)

/// 호흡. 정지 상태를 살아 있게 만든다.
double breathe(double t, {double speed = 1.0, double amp = 1.0, double phase = 0});

/// 미세 흔들림.
double jitter(double t, double seed, {double amp = 1.0});
```

**`turn` 파라미터**: `headShape` 의 `turn` 은 3/4 시점 회전이다. 얼굴 부위(`drawNose`, `drawMouth`)
에도 같은 `turn` 을 넘겨 일관되게 돌린다.

---

## 얼굴

**눈 하나가 캐릭터의 생사를 가른다.** `drawEye` 는 **6겹**으로 그린다:

```dart
void drawEye(Canvas c, Offset at, double w, double h, {
  ...,
  LightRig light = LightRig.heroic,
  double open = 1.0,     // 0 = 감음, 1 = 뜸
  double look = 0.0,     // 시선 좌우
  double tilt = 0.0,     // 눈꼬리 기울기
});
```

| 겹 | 무엇 | 왜 |
|---|---|---|
| 1 | **안와(eye socket) 그림자** | 눈이 얼굴에 파여 있어야 한다. 이게 없으면 눈알이 얼굴에 붙어 있는 것처럼 보인다 |
| 2 | **흰자(sclera)** — 순백이 아니라 살짝 어둡고 위쪽에 그림자 | 안구는 구체이고 눈꺼풀이 그림자를 드리운다 |
| 3 | **홍채 섬유** — 방사형 결 + 가장자리 어두운 링 | 단색 원은 인형 눈이 된다 |
| 4 | **동공** | |
| 5 | **각막 하이라이트** — 광원 방향의 밝은 점 + 반대쪽 약한 점 | 이 점 하나가 "살아 있음"을 만든다 |
| 6 | **눈꺼풀·속눈썹** — 위 눈꺼풀이 홍채 상단을 살짝 덮는다 | 홍채가 완전히 드러나면 놀란 표정이 된다 |

`drawBrow`(눈썹), `drawNose`(콧대·콧방울·콧구멍 그림자), `drawMouth`(입술·구각·치아)도 같은 밀도로
쌓는다.

**몬스터의 눈**: 사람 눈 구조를 그대로 쓰지 말고 `Finish.energy` 또는 `Finish.gem` 으로 발광 코어를
만든 뒤 `glowAt` 으로 헤일로를 얹는다. 다만 **안와 그림자(1겹)는 유지** — 그것이 눈을 두개골에 앉힌다.

---

## 로스터 등록

**파일: `lib/src/art/roster.dart`**

```dart
final List<Artist> heroes = List<Artist>.unmodifiable([
  Aldric(), Kaelen(), Seraphine(), Lyra(), Vesper(),
]);

final List<Artist> monsters = List<Artist>.unmodifiable([
  Gorehide(), Vaelmorth(), Mourne(), Chitinis(),
]);

final List<Artist> everyone =
    List<Artist>.unmodifiable([...heroes, ...monsters]);
```

**등록하지 않으면 갤러리에 나타나지 않는다.** 새 캐릭터를 만들고 화면에 안 보이면 여기부터 확인한다.

---

## 신규 캐릭터 작성 골격

```dart
import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../../core/noise.dart';
import '../../core/palette.dart';
import '../../core/shading.dart';
import '../../core/spline.dart';
import '../anatomy.dart';
import '../creature.dart';

/// 이름 — 한 줄 정체.
///
/// [시각 논제] 이 캐릭터를 무엇으로 읽히게 할 것인가를 여기 한 문단으로 적는다.
/// 비율을 어떻게 왜곡했는지, 어떤 대비를 만들었는지. 이 주석이 없으면 나중에
/// 손볼 때 원래 의도를 잃는다. → art-direction.md
class NewChar extends Artist {
  @override String get id => 'newchar';
  @override String get name => 'NewChar';
  @override String get title => 'The Something';
  @override String get blurb => '한 줄 소개.';
  @override Camp get camp => Camp.player;
  @override Sex? get sex => Sex.female;
  @override Color get accent => const Color(0xFF...);
  @override Rect get framing => const Rect.fromLTWH(80, 60, 840, 1300);

  @override
  LightRig get light => const LightRig(
        dir: Offset(-0.6, -0.8),
        rimDir: Offset(0.8, -0.5),
        key: Color(0xFF...), fill: Color(0xFF...), rim: Color(0xFF...),
        bounce: Color(0xFF...), ambient: Color(0xFF...),
      );

  @override
  List<Color> get moodSky => const [Color(0xFF...), Color(0xFF...)];

  @override
  void paint(Canvas c, double t, {double detail = 1.0}) {
    final l = light;
    final bob = breathe(t, speed: 0.9, amp: 4);      // 호흡 — 없으면 죽어 보인다
    final sway = jitter(t, 3.1, amp: 2);

    groundShadow(c, const Offset(500, kGround), 190, 46);   // 예외 없음

    _cloak(c, l, t, detail);      // 뒤에서 앞으로
    _legs(c, l, bob, detail);
    _torso(c, l, bob, sway, detail);
    _arms(c, l, bob, detail);
    _head(c, l, t, bob, sway, detail);
    _weapon(c, l, t, detail);
    if (detail > 0.5) _fx(c, t);  // 파티클·발광은 마지막
  }
}
```

**그리기 순서는 뒤 → 앞.** 망토 → 먼 쪽 팔다리 → 몸통 → 가까운 쪽 팔다리 → 머리 → 무기 → FX.

---

## 체크리스트

- [ ] 클래스 주석에 **시각 논제**가 한 문단으로 적혀 있는가
- [ ] `light` 가 캐릭터의 무드를 반영하는가 (기본값 복붙이 아닌가)
- [ ] `groundShadow` 를 그렸는가
- [ ] 겹친 파츠마다 `occlude` 또는 `castShadow` 가 있는가
- [ ] `rimBand` 를 시선이 머무는 1~2곳에 썼는가
- [ ] 갑옷·기계 파츠에 `panelLine` 이 있는가
- [ ] 눈이 6겹인가 (몬스터라도 안와 그림자는 있는가)
- [ ] `breathe`/`jitter` 로 정지 상태가 살아 있는가
- [ ] `detail < 0.5` 에서 미세 텍스처가 꺼지는가
- [ ] `roster.dart` 에 등록했는가
- [ ] 같은 `t` 에 같은 그림이 나오는가 (`math.Random` 미사용)
- [ ] `Finish` 를 재질에 맞게 골랐는가 — 애매하면 [Finish 표](#finish-16종과-재질별-기법) 재확인
- [ ] 48px 로 축소해도 정체가 읽히는가
