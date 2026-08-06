# 셰이딩 (트랙 A) — 재질·조명·10패스 파이프라인

`lib/src/render/surface.dart`, `lib/src/render/light.dart`, `lib/src/render/palette.dart` 의 완전한 참조.

> **🚦 이 문서는 트랙 A(인게임 아이소 액터) 전용이다.**
> 이름 있는 작품 캐릭터(`art/pc/`·`art/mob/`)를 만든다면 이 문서가 아니라
> [artist-craft.md](artist-craft.md) 를 읽어야 한다. 그쪽은 `core/shading.dart` 계보이며
> `Surface`·`LightRig`·`paintSurface` 이름은 같지만 **필드와 조명 부호 규약이 다르다.**

## 목차

1. [핵심 개념: 칠해진 그림 vs 빛을 받는 물체](#핵심-개념-칠해진-그림-vs-빛을-받는-물체)
2. [LightRig — 3점 조명의 2D 근사 (전체 소스)](#lightrig--3점-조명의-2d-근사)
3. [Surface — PBR 을 2D 로 번역한 재질 (전체 소스)](#surface--pbr-을-2d-로-번역한-재질)
4. [명암 램프 `_Ramp` — 그림을 살리는 4줄](#명암-램프-_ramp)
5. [paintSurface — 10패스 (전체 소스)](#paintsurface--10패스)
6. [미세 디테일 `_paintMicroDetail`](#미세-디테일)
7. [보조 페인터: 접촉 그림자·지면 그림자·트림·글로우](#보조-페인터)
8. [색 조작 유틸 (render/palette.dart)](#색-조작-유틸)
9. [재질별 파라미터 표](#재질별-파라미터-표)
10. [흔한 실패와 진단](#흔한-실패와-진단)

---

## 핵심 개념: 칠해진 그림 vs 빛을 받는 물체

절차적 2D 캐릭터가 싸구려로 보이는 이유는 형태가 아니라 **조명 논리의 부재**다. 파츠마다 임의의 그라디언트를 넣으면 각 파츠는 예뻐도 전체가 "스티커 콜라주"가 된다.

이 프로젝트의 해법은 두 가지다.

1. **씬 전체가 단 하나의 `LightRig` 를 공유한다.** 광원 방향을 하나 바꾸면 캐릭터·무기·망토·지면 그림자가 동시에 따라 움직인다. 이 일관성이 "같은 세계에 서 있다"는 인상을 만든다.
2. **모든 파츠는 `paintSurface` 하나로만 칠한다.** 패스 순서가 곧 물리적 의미(확산 → 반사광 → 산란 → 차폐 → 정반사 → 디테일 → 림)이므로, 호출부에서 개별 패스를 조합하면 재질감이 무너진다.

여기에 회화의 관습 하나가 결정적으로 더해진다: **그림자는 차갑게, 하이라이트는 따뜻하게.** 그림자를 단순히 검정 쪽으로 어둡게만 하면 진흙처럼 탁해진다. 그림자에는 하늘의 산란광(`ambient`)을, 하이라이트에는 키라이트의 색온도(`keyColor`)를 섞는다. 이 한 가지 규칙만으로 같은 형상이 플라스틱과 실물만큼 달라진다.

---

## LightRig — 3점 조명의 2D 근사

**파일: `lib/src/render/light.dart`**

```dart
class LightRig {
  LightRig({
    Offset keyDir = const Offset(0.55, 0.83),
    this.keyColor = const Color(0xFFFFF1D8),
    this.keyIntensity = 1.0,
    Offset rimDir = const Offset(-0.72, -0.69),
    this.rimColor = const Color(0xFF8FC7FF),
    this.rimIntensity = 1.0,
    this.ambient = const Color(0xFF2A3550),
    this.bounce = const Color(0xFF5B4A38),
    this.exposure = 1.0,
  })  : keyDir = keyDir.normalized(),
        rimDir = rimDir.normalized();

  /// 빛이 진행하는 방향(광원 → 피사체). 광원의 위치가 아니다.
  final Offset keyDir;
  final Color keyColor;
  final double keyIntensity;

  /// 백라이트가 진행하는 방향.
  final Offset rimDir;
  final Color rimColor;
  final double rimIntensity;

  /// 하늘/환경광. 그림자 쪽 색조를 결정한다.
  final Color ambient;

  /// 바닥 반사광. 아래쪽에서 올라오는 따뜻한 빛.
  final Color bounce;

  final double exposure;

  /// 광원이 있는 쪽(= -keyDir)의 정렬. 그라디언트 시작점으로 쓴다.
  Alignment get keyAlign => Alignment(-keyDir.dx, -keyDir.dy);
  Alignment get rimAlign => Alignment(-rimDir.dx, -rimDir.dy);

  /// 그림자가 드리우는 방향(지면 투영).
  Offset get shadowDir => Offset(keyDir.dx, keyDir.dy.abs()).normalized();

  LightRig copyWith({ /* 모든 필드 */ });

  /// 시각에 따른 프리셋. 0 정오 / 1 황혼 / 2 달빛 / 3 던전 화톳불
  static LightRig preset(int i);

  /// 키라이트를 각도로 회전한 리그. 림은 반대편(π·0.86)으로 함께 돈다.
  LightRig rotatedKey(double radians);
}
```

**프리셋 값 (그대로 보존할 것 — 색 조합이 손으로 맞춰져 있다)**

| # | 이름 | keyDir | keyColor | keyI | rimDir | rimColor | rimI | ambient | bounce | exposure |
|---|------|--------|----------|------|--------|----------|------|---------|--------|----------|
| 0 | 정오 야외 | (0.5, 0.86) | `FFFFF4DC` | 1.05 | (-0.7, -0.71) | `FF9CD2FF` | 0.85 | `FF31415F` | `FF6F6A4E` | 1.0 |
| 1 | 황혼 | (0.82, 0.57) | `FFFFB06A` | 1.15 | (-0.6, -0.8) | `FF7FA8FF` | 1.10 | `FF3B2B52` | `FF7A4630` | 1.0 |
| 2 | 달빛 | (0.45, 0.89) | `FFB9D4FF` | 0.80 | (-0.75, -0.66) | `FFCFE4FF` | 1.25 | `FF141E38` | `FF25344F` | 0.92 |
| 3 | 던전 화톳불 | (0.35, 0.94) | `FFFF9A45` | 1.20 | (-0.8, -0.6) | `FF56E0C8` | 1.00 | `FF1B1526` | `FF57210F` | 1.05 |

**아이소메트릭에서의 광원 규약**

- 모든 프리셋의 `keyDir.dy` 가 크게 양수다 = 빛이 **위에서 아래로** 진행한다 = 위에서 내려다보는 아이소 뷰와 자연히 맞다. 프리셋을 그대로 쓰면 상단면이 밝게 나온다.
- 키라이트는 **화면 공간 고정**이다. 캐릭터가 회전(yaw)해도 광원은 따라 돌지 않는다. 그래야 씬의 모든 액터가 같은 태양 아래 있게 된다.
- `rotatedKey` 로 광원을 돌릴 때는 씬 전체를 한 번에 돌린다. 액터마다 다른 리그를 주면 즉시 콜라주가 된다.

---

## Surface — PBR 을 2D 로 번역한 재질

**파일: `lib/src/render/surface.dart`**

3D 의 PBR 파라미터를 2D 페인팅으로 옮긴 것이다:
- `roughness` → 스펙큘러 반경 (거칠수록 넓고 흐림)
- `metalness` → 명암 램프의 **비단조성** (금속 특유의 어두운 중간톤 + 밝은 환경 반사 밴드)
- `sss` → 터미네이터 부근의 따뜻한 번짐

```dart
enum SurfaceKind { skin, cloth, leather, metal, chitin, bone, hair, gem, stone, flesh }
enum Quality { low, medium, high }

class Surface {
  const Surface({
    required this.albedo,
    this.kind = SurfaceKind.cloth,
    this.roughness = 0.6,
    this.metalness = 0.0,
    this.sss = 0.0,
    this.rim = 1.0,
    this.ao = 1.0,
    this.outline = 0.55,
    this.emissive,
    this.emissiveStrength = 0.0,
    this.detail = 0.0,
  });

  final Color albedo;
  final SurfaceKind kind;
  final double roughness;    // 0 거울 ~ 1 완전 확산
  final double metalness;    // 0.5 초과 시 금속 램프로 분기
  final double sss;          // 표면하 산란
  final double rim;          // 림라이트 배율
  final double ao;           // 내부 앰비언트 오클루전 배율
  final double outline;      // 윤곽선 알파 배율
  final Color? emissive;
  final double emissiveStrength;
  final double detail;       // 미세 디테일(스크래치·주름·기공) 강도

  Surface copyWith({Color? albedo, double? roughness, double? rim, double? ao, double? outline});
}
```

**프리셋 팩토리 (수치를 임의로 바꾸지 말 것 — 재질 구분이 이 표에서 나온다)**

```dart
static Surface skin(Color c)    => Surface(albedo: c, kind: .skin,    roughness: 0.68, sss: 0.85,  rim: 1.0,  outline: 0.42, detail: 0.15);
static Surface flesh(Color c)   => Surface(albedo: c, kind: .flesh,   roughness: 0.55, sss: 1.0,  rim: 1.15, outline: 0.5,  detail: 0.4);
static Surface cloth(Color c)   => Surface(albedo: c, kind: .cloth,   roughness: 0.92, sss: 0.18,  rim: 0.75,  outline: 0.6,  detail: 0.25);
static Surface leather(Color c) => Surface(albedo: c, kind: .leather, roughness: 0.72,            rim: 0.85,  outline: 0.7,  detail: 0.35);
static Surface metal(Color c, {double polish = 0.8})
                                => Surface(albedo: c, kind: .metal,   roughness: (1-polish).clamp(0.06,0.9), metalness: 1.0, rim: 1.35, outline: 0.75, detail: 0.5);
static Surface chitin(Color c)  => Surface(albedo: c, kind: .chitin,  roughness: 0.30, metalness: 0.35, rim: 1.3, outline: 0.8, detail: 0.45);
static Surface bone(Color c)    => Surface(albedo: c, kind: .bone,    roughness: 0.62, sss: 0.35,  rim: 1.0,  outline: 0.7,  detail: 0.3);
static Surface hair(Color c)    => Surface(albedo: c, kind: .hair,    roughness: 0.34,            rim: 1.5,  outline: 0.5,  detail: 0.6);
static Surface gem(Color c, {Color? glow})
                                => Surface(albedo: c, kind: .gem,     roughness: 0.05, metalness: 0.2, rim: 1.6, outline: 0.4, emissive: glow ?? c, emissiveStrength: 0.9);
static Surface stone(Color c)   => Surface(albedo: c, kind: .stone,   roughness: 0.95,            rim: 0.6,   outline: 0.65, detail: 0.5);
```

---

## 명암 램프 `_Ramp`

`paintSurface` 내부의 private 클래스. **베이스 컬러 + 조명 → 7단계 톤**을 유도한다.

```dart
class _Ramp {
  _Ramp(Surface s, LightRig l) {
    final base = s.albedo;
    final key = l.keyColor;
    final ki = l.keyIntensity * l.exposure;

    hot   = mix(shiftColor(base, dl:  0.24, ds: -0.16), key, 0.55 * ki);
    lit   = mix(shiftColor(base, dl:  0.13, ds: -0.05), key, 0.30 * ki);
    mid   = base;
    // 터미네이터에서 채도가 오르고 색상이 따뜻한 쪽으로 밀리는 것은 실제
    // 표면 산란의 결과이며, 이 한 줄이 그림을 크게 살린다.
    term  = shiftColor(base, dl: -0.07, ds: 0.14, dh: -7);
    shade = mix(shiftColor(base, dl: -0.20, ds:  0.03), l.ambient, 0.44);
    deep  = mix(shiftColor(base, dl: -0.29, ds: -0.04), l.ambient, 0.66);
    // 금속의 환경 반사 밴드: 하늘색이 비쳐 어두운 면 한가운데가 되레 밝다.
    sky   = mix(mix(base, l.rimColor, 0.45), key, 0.10);
  }
  late final Color hot, lit, mid, term, shade, deep, sky;
}
```

**세 가지 핵심 로직 — 반드시 보존:**

1. **밝아질수록 채도가 내려간다** (`hot` 의 `ds: -0.16`). 실제 필름/눈의 반응이며, 이걸 빼면 하이라이트가 형광색이 된다.
2. **터미네이터에서 채도가 올라가고 색상이 −7° 밀린다** (`term`). 표면하 산란의 시각적 결과. 이 한 줄이 없으면 회색 그라디언트가 된다.
3. **그림자는 `ambient` 와 섞인다** (44%, 66%). 검정과 섞으면 탁해진다.

---

## paintSurface — 10패스

**호출 규약**: 파츠 하나 = 호출 한 번. 개별 패스를 호출부에서 재조합하지 않는다.

```dart
void paintSurface(
  Canvas canvas,
  Path path,
  Surface s,
  LightRig light, {
  Quality quality = Quality.high,
  double occlusion = 0.0,     // 다른 파츠에 가려진 정도. 몸통 뒤 팔에 0.3~0.6
  double detailSeed = 0.0,    // 미세 디테일 위상. 파츠마다 고정값을 준다
  double? unitScale,          // 파츠 고유 스케일(월드 단위). 아웃라인 두께 기준
})
```

### 패스 순서와 의미

| # | 패스 | 물리적 의미 | 블렌드 | 품질 게이트 |
|---|------|-------------|--------|-------------|
| 0 | 외곽 글로우 | 발광체가 주변 공기를 밝힘 | plus | `!= low` |
| 1 | 확산 | 램버트 명암, 광원 축 그라디언트 | srcOver | 항상 |
| 2 | 바닥 반사광 | 지면에서 되받이 오는 따뜻한 빛 | plus | 항상 |
| 3 | 표면하 산란 | 터미네이터 직전 붉은 비침 | plus | `!= low` |
| 4 | 내부 AO | 실루엣 안쪽 가장자리 눌러 부피 생성 | multiply | 항상 |
| 5 | 정반사 | roughness=반경, metalness=색조 | plus | 항상 (코어는 `high`) |
| 6 | 미세 디테일 | 스크래치·주름·기공 | 혼합 | `high` |
| 7 | 림라이트 | 백라이트가 실루엣을 태움 | plus | 항상 |
| 8 | 발광 코어 | 내부 발광 | plus | 항상 |
| 9 | 윤곽선 | 환경광으로 물든 어두운 선 | srcOver | 항상 |

> **순서를 바꾸지 말 것.** 예를 들어 AO(4)를 정반사(5) 뒤로 옮기면 하이라이트가 눌려 금속이 플라스틱이 된다.

### 전체 소스

```dart
void paintSurface(Canvas canvas, Path path, Surface s, LightRig light, {
  Quality quality = Quality.high, double occlusion = 0.0,
  double detailSeed = 0.0, double? unitScale,
}) {
  final b = path.getBounds();
  if (b.isEmpty || b.width < 0.4 || b.height < 0.4) return;   // 퇴화 파츠 조기 탈출

  final size = math.max(b.shortestSide, 1.0);
  final ramp = _Ramp(s, light);
  final unit = unitScale ?? size;

  // ── 0. 발광체의 외곽 글로우는 형상 밖으로 나가므로 클립 이전에 그린다.
  if (s.emissive != null && s.emissiveStrength > 0 && quality != Quality.low) {
    canvas.drawPath(path, Paint()
      ..color = s.emissive!.withValues(alpha: 0.34 * s.emissiveStrength)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, size * 0.42)
      ..blendMode = BlendMode.plus);
  }

  canvas.saveLayer(b.inflate(size * 0.6), Paint());
  canvas.clipPath(path, doAntiAlias: true);

  // ── 1. 확산: 광원 축을 따르는 명암 램프.
  final ka = light.keyAlign;
  final Paint basePaint = Paint();
  if (s.metalness > 0.5) {
    // 금속: 비단조 램프. 어두운 중간톤 뒤에 하늘 반사 밴드(sky)가 다시 밝다.
    basePaint.shader = LinearGradient(begin: ka, end: -ka,
      colors: [ramp.hot, ramp.lit, ramp.mid, ramp.deep, ramp.shade, ramp.sky, ramp.deep, ramp.shade],
      stops: const [0.0, 0.09, 0.24, 0.40, 0.53, 0.68, 0.84, 1.0]).createShader(b);
  } else if (s.kind == SurfaceKind.cloth) {
    // 천은 대비가 낮고 터미네이터가 넓다.
    basePaint.shader = LinearGradient(begin: ka, end: -ka,
      colors: [ramp.lit, ramp.mid, ramp.term, ramp.shade, ramp.deep],
      stops: const [0.0, 0.34, 0.58, 0.80, 1.0]).createShader(b);
  } else {
    basePaint.shader = LinearGradient(begin: ka, end: -ka,
      colors: [ramp.hot, ramp.lit, ramp.mid, ramp.term, ramp.shade, ramp.deep],
      stops: const [0.0, 0.16, 0.42, 0.585, 0.79, 1.0]).createShader(b);
  }
  canvas.drawRect(b.inflate(size * 0.5), basePaint);

  // ── 2. 바닥 반사광.
  canvas.drawRect(b, Paint()
    ..blendMode = BlendMode.plus
    ..shader = LinearGradient(begin: Alignment.bottomCenter, end: Alignment.center,
      colors: [light.bounce.withValues(alpha: 0.30), light.bounce.withValues(alpha: 0.0)]).createShader(b));

  // ── 3. 표면하 산란: 터미네이터 직전에서 살이 붉게 비친다.
  if (s.sss > 0.01 && quality != Quality.low) {
    final sssColor = shiftColor(s.albedo, dh: -14, ds: 0.35, dl: -0.05);
    canvas.drawRect(b, Paint()
      ..blendMode = BlendMode.plus
      ..shader = LinearGradient(begin: ka, end: -ka, colors: [
        sssColor.withValues(alpha: 0.0),
        sssColor.withValues(alpha: 0.34 * s.sss),
        sssColor.withValues(alpha: 0.0),
      ], stops: const [0.40, 0.615, 0.86]).createShader(b));
  }

  // ── 4. 내부 앰비언트 오클루전: 안쪽 가장자리를 눌러 부피를 만든다.
  if (s.ao > 0.01) {
    final w = size * 0.55;
    canvas.drawPath(path, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..color = mix(light.ambient, const Color(0xFF000000), 0.55)
          .withValues(alpha: (0.44 * s.ao + 0.5 * occlusion).clamp(0, 0.92))
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.34)
      ..blendMode = BlendMode.multiply);
  }

  // ── 5. 정반사.
  final specColor = mix(light.keyColor, shiftColor(s.albedo, dl: 0.35), s.metalness * 0.75);
  final specPos = b.center - light.keyDir * (size * 0.34);
  final specR = lerpD(0.20, 1.05, s.roughness);
  final specA = lerpD(0.85, 0.14, s.roughness) * (0.55 + 0.65 * s.metalness);
  canvas.drawRect(b, Paint()
    ..blendMode = BlendMode.plus
    ..shader = RadialGradient(center: alignIn(b, specPos), radius: specR, colors: [
      specColor.withValues(alpha: specA.clamp(0, 1)),
      specColor.withValues(alpha: 0.0),
    ], stops: const [0.0, 1.0]).createShader(b));

  // 광택 재질은 좁고 뜨거운 코어 하이라이트를 하나 더 얹는다.
  if (s.roughness < 0.45 && quality == Quality.high) {
    canvas.drawRect(b, Paint()
      ..blendMode = BlendMode.plus
      ..shader = RadialGradient(
        center: alignIn(b, specPos - light.keyDir * size * 0.06),
        radius: specR * 0.34,
        colors: [
          mix(specColor, const Color(0xFFFFFFFF), 0.6).withValues(alpha: 0.7 * (1 - s.roughness)),
          specColor.withValues(alpha: 0.0),
        ]).createShader(b));
  }

  // ── 6. 미세 디테일.
  if (s.detail > 0.01 && quality == Quality.high) {
    _paintMicroDetail(canvas, b, s, light, ramp, detailSeed);
  }

  // ── 7. 림라이트: 배경에서 캐릭터를 떼어내는 가장 강력한 장치.
  if (s.rim > 0.01) {
    final ra = light.rimAlign;
    final rimMask = LinearGradient(begin: ra, end: -ra, colors: [
      light.rimColor.withValues(alpha: (0.85 * s.rim * light.rimIntensity).clamp(0, 1)),
      light.rimColor.withValues(alpha: 0.0),
    ], stops: const [0.0, 0.46]).createShader(b);

    final soft = size * 0.16;
    canvas.drawPath(path, Paint()      // 넓고 부드러운 번짐
      ..style = PaintingStyle.stroke ..strokeWidth = soft ..shader = rimMask
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, soft * 0.45)
      ..blendMode = BlendMode.plus);
    canvas.drawPath(path, Paint()      // 날카로운 코어. 가장자리가 "금속처럼" 선다.
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(unit * 0.03, size * 0.035) ..shader = rimMask
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, size * 0.012)
      ..blendMode = BlendMode.plus);
  }

  // ── 8. 발광 재질의 내부 코어.
  if (s.emissive != null && s.emissiveStrength > 0) {
    canvas.drawRect(b, Paint()
      ..blendMode = BlendMode.plus
      ..shader = RadialGradient(center: Alignment.center, radius: 0.9, colors: [
        s.emissive!.withValues(alpha: 0.55 * s.emissiveStrength),
        s.emissive!.withValues(alpha: 0.0),
      ]).createShader(b));
  }

  canvas.restore();

  // ── 9. 윤곽선. 완전한 검정이 아니라 환경광으로 물든 어두운 색.
  if (s.outline > 0.01) {
    canvas.drawPath(path, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = (unit * 0.018).clamp(0.5, 2.4)
      ..color = mix(ramp.deep, light.ambient, 0.35).withValues(alpha: 0.55 * s.outline)
      ..isAntiAlias = true);
  }
}
```

### 파라미터 사용 지침

- **`occlusion`**: 몸통 뒤로 들어가는 far 쪽 팔·다리에 `0.3 ~ 0.6`. 이게 없으면 사지가 몸통 앞에 떠 보인다. 아이소 8방향에서 yaw 에 따라 near/far 가 바뀌므로 **매 프레임 계산**한다.
- **`detailSeed`**: 파츠별 **고정값**(예: 파츠 인덱스 × 7.3). 매 프레임 바뀌면 스크래치가 지글거린다.
- **`unitScale`**: 캐릭터 전체 키를 넘긴다. 이걸 생략하면 작은 파츠의 윤곽선이 상대적으로 굵어져 실루엣이 뭉친다.

---

## 미세 디테일

`kind` 에 따라 세 갈래로 분기한다. 공통 원리: **디테일은 광원 축과의 관계로 그려야 요철로 읽힌다.**

| 재질군 | 기법 | 방향 |
|--------|------|------|
| metal, chitin | 브러시드 스크래치 (직선) | `light.keyDir.perp` — 광원 축과 **직교** |
| cloth, leather | 접힘 주름 (2차 베지어) + 밝은 하이라이트 오프셋 | `light.keyDir.perp` 를 가로지름 |
| stone, bone, flesh | 기공/융기 (원 + 오프셋 하이라이트) | 하이라이트를 `-keyDir` 로 밀어 볼록하게 |

핵심 코드 패턴 — **어두운 선(multiply) + 광원 쪽으로 민 밝은 선(plus)** 의 짝이 요철의 전부다:

```dart
canvas.drawPath(p, Paint()                          // 골(오목)
  ..style = PaintingStyle.stroke ..strokeWidth = w
  ..color = ramp.deep.withValues(alpha: 0.22 * s.detail)
  ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.55)
  ..blendMode = BlendMode.multiply);
canvas.drawPath(p.shift(-light.keyDir * w * 0.6), Paint()   // 마루(볼록)
  ..style = PaintingStyle.stroke ..strokeWidth = w * 0.6
  ..color = ramp.lit.withValues(alpha: 0.16 * s.detail)
  ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.5)
  ..blendMode = BlendMode.plus);
```

노이즈는 파일 최상단의 공유 인스턴스 `final Noise _detailNoise = Noise(0x5EED);` 를 쓴다. 매번 새로 만들면 프레임마다 무늬가 바뀐다.

---

## 보조 페인터

```dart
/// 한 파츠가 다른 파츠 위에 드리우는 접촉 그림자.
/// 파츠를 따로따로 잘 칠해도 "서로 붙어 있다"는 느낌은 이 그림자에서 나온다.
void paintContactShadow(Canvas canvas, Path receiver, Path occluder, LightRig light,
    {double strength = 0.55, double spread = 6}) {
  canvas.save();
  canvas.clipPath(receiver, doAntiAlias: true);
  canvas.drawPath(occluder.shift(light.keyDir * spread * 0.5), Paint()
    ..color = mix(light.ambient, const Color(0xFF000000), 0.6).withValues(alpha: strength)
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, spread)
    ..blendMode = BlendMode.multiply);
  canvas.restore();
}

/// 지면에 떨어지는 그림자. 접지감을 만든다.
/// 아이소에서는 width : height = 2 : 1 로 호출한다 (isometric.md 참조).
void paintGroundShadow(Canvas canvas, Offset at, double width, double height,
    LightRig light, {double strength = 0.5});

/// 금속 트림/테두리 장식. 갑옷 가장자리, 무기 날의 페룰.
void paintTrim(Canvas canvas, Path path, Color color, LightRig light,
    {double width = 2.0, double alpha = 0.9});

/// 발광 궤적/오라. 마법 이펙트와 몬스터의 코어.
void paintGlow(Canvas canvas, Path path, Color color, double radius, double strength);
```

**접촉 그림자를 반드시 넣어야 하는 자리**: 턱 아래 목, 어깨보호대 아래 팔, 몸통 위 벨트, 망토 아래 다리, 투구 아래 얼굴. 이 다섯 곳만 넣어도 캐릭터가 조립 부품에서 한 덩어리로 바뀐다.

---

## 색 조작 유틸

**파일: `lib/src/render/palette.dart`**

```dart
Color hsl(double h, double s, double l, [double a = 1]);
Color shiftColor(Color c, {double dh = 0, double ds = 0, double dl = 0, double? alpha});
Color mix(Color a, Color b, double t);
double luminance(Color c);
```

**절대 규칙: 절차적 색은 전부 HSL 에서 조작한 뒤 되돌린다.** RGB 로 직접 더하고 빼면 금방 탁해지고 색상이 예측 불가능하게 튄다.

`core/palette.dart` 에는 별도의 `ColorTune` 확장(`darken`/`lighten`/`saturate`/`desaturate`/`shiftHue`/`fade`/`mix`)과 5단계 `Ramp` 가 있다. 셰이딩 파이프라인 바깥(UI·이펙트·배경)에서 간이 톤이 필요할 때 쓴다.

---

## 재질별 파라미터 표

새 재질을 만들 때 이 표의 대역 안에서 정한다. 밖으로 나가면 재질 구분이 무너진다.

| kind | roughness | metalness | sss | rim | outline | detail | 비고 |
|------|-----------|-----------|-----|-----|---------|--------|------|
| skin | 0.60–.75 | 0 | 0.7–.9 | 1.0 | 0.40–.45 | 0.1–.2 | sss 가 핵심 |
| flesh | 0.50–.60 | 0 | 1.0 | 1.15 | 0.5 | 0.4 | 몬스터 살점 |
| cloth | 0.88–.95 | 0 | 0.1–.2 | 0.7–.8 | 0.6 | 0.25 | 램프 대비 낮음 |
| leather | 0.68–.78 | 0 | 0 | 0.85 | 0.7 | 0.35 | |
| metal | 0.06–.90 | 1.0 | 0 | 1.35 | 0.75 | 0.5 | `polish` 로 제어 |
| chitin | 0.25–.35 | 0.35 | 0 | 1.3 | 0.8 | 0.45 | 곤충 갑각 |
| bone | 0.58–.66 | 0 | 0.35 | 1.0 | 0.7 | 0.3 | |
| hair | 0.30–.40 | 0 | 0 | 1.5 | 0.5 | 0.6 | rim 이 가장 높다 |
| gem | 0.03–.08 | 0.2 | 0 | 1.6 | 0.4 | 0 | emissive 필수 |
| stone | 0.92–.98 | 0 | 0 | 0.6 | 0.65 | 0.5 | rim 이 가장 낮다 |

---

## 흔한 실패와 진단

| 증상 | 원인 | 처방 |
|------|------|------|
| 캐릭터가 배경에 파묻힌다 | 림라이트 부족 | `Surface.rim` 상향, `LightRig.rimIntensity` 확인 |
| 명암이 통째로 뒤집혔다 | `keyDir` 을 광원 위치로 착각 | `keyDir` 은 빛의 **진행 방향** |
| 색이 진흙처럼 탁하다 | 그림자를 검정과 섞음 | `ambient` 와 섞기. `_Ramp` 수식 확인 |
| 하이라이트가 형광색 | 밝은 톤의 채도를 안 낮춤 | `hot` 의 `ds: -0.16` 보존 |
| 금속이 플라스틱 | 램프가 단조 | `metalness > 0.5` 분기의 `sky` 밴드 확인 |
| 파츠가 스티커처럼 떠 있다 | 접촉 그림자·AO 없음 | `paintContactShadow` + `occlusion` |
| 프레임이 튄다 | `saveLayer` 남용 | [performance.md](performance.md) 의 예산표 |
| 스크래치가 지글거린다 | `detailSeed` 가 매 프레임 변함 | 파츠별 고정 시드 |
| 아이소에서 납작해 보인다 | 상단면 하이라이트 없음 | `paintTopPlane` ([isometric.md](isometric.md)) |
