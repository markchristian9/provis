# 실루엣 — 형상 언어와 스플라인 생성기

`lib/src/core/spline.dart` 의 완전한 참조와, 그것으로 캐릭터 형상을 만드는 레시피.

## 목차

1. [핵심 개념: 인상의 70%는 실루엣에서 온다](#핵심-개념-인상의-70는-실루엣에서-온다)
2. [형상 언어 — 원형을 실루엣으로 번역하는 표](#형상-언어)
3. [스플라인 기본기 (전체 소스)](#스플라인-기본기)
4. [tube() — 축을 가진 모든 것](#tube--축을-가진-모든-것)
5. [blob() — 덩어리](#blob--덩어리)
6. [web() — 파츠 경계 메우기](#web--파츠-경계-메우기)
7. [두께 프로파일 레시피](#두께-프로파일-레시피)
8. [부위별 형상 레시피](#부위별-형상-레시피)
9. [디테일 배치 원칙](#디테일-배치-원칙)
10. [검증: squint test](#검증-squint-test)

---

## 핵심 개념: 인상의 70%는 실루엣에서 온다

캐릭터 디자인의 경험칙은 **실루엣 70 : 디테일 30** 이다. 완전히 검게 칠하고 눈을 가늘게 떴을 때 누구인지, 무슨 무기를 들었는지 읽히지 않으면 그 디자인은 실패다. 디테일을 아무리 더해도 이 실패는 복구되지 않는다.

절차적 생성에서 이것이 특히 중요한 이유: 사람이 하나하나 손보지 않으므로, **실루엣을 만드는 규칙 자체가 좋아야** 1000개가 전부 좋다.

두 번째 원칙: **다각형 그대로 그리면 아무리 셰이딩을 잘해도 값싸 보인다.** 이 프로젝트의 모든 형상은 Catmull-Rom 스플라인을 3차 베지어로 변환해 **곡률이 연속인** 윤곽으로 만든다. `smoothClosedPath` 가 그 관문이며, `tube`/`blob`/`web` 은 전부 그 위에 세워져 있다.

세 번째 원칙(아이소 전용): **위에서 30° 내려다보므로 상단 실루엣이 왕이다.** 자세한 것은 [isometric.md](isometric.md).

---

## 형상 언어

기본 도형은 관객에게 즉각적인 감정 신호를 준다. 절차적 생성기는 **원형(Archetype)을 먼저 뽑고 그 원형의 도형 편향을 전체 파츠에 일관되게 적용**해야 한다. 파츠마다 독립적으로 무작위하면 특징 없는 평균만 나온다.

| 도형 | 감정 | 적용 파츠 | 대응 원형 |
|------|------|-----------|-----------|
| ▲ 삼각 (뾰족·역삼각) | 공격성, 위협, 속도 | 어깨보호대 끝, 투구 뿔, 망토 밑단, 발톱 | berserker, assassin, 몬스터 |
| ■ 사각 (넓고 안정) | 방어, 권위, 견고 | 어깨 판, 흉갑, 방패, 부츠 | knight, paladin |
| ● 원 (부드러움) | 친근, 마법, 유기체 | 후드, 로브 자락, 촉수, 물집 | mage, 유기체 몬스터 |

**구현 방법** — 도형 편향을 숫자 하나로 만들어 전 파츠에 전달한다:

> **🚧 미구현 설계** — 아래 `shapeBias` 는 `lib/` 에 없다. 트랙 A 에서 도형 언어를 코드로 강제하고
> 싶을 때 이 패턴으로 직접 추가하라. 트랙 B 는 캐릭터마다 시각 논제를 손으로 정하므로 필요 없다.

```dart
/// -1 = 완전 원형(부드러움), 0 = 중립, +1 = 완전 삼각(공격적)
double shapeBias(Archetype a) => switch (a) {
      Archetype.berserker => 0.85,
      Archetype.assassin => 0.70,
      Archetype.ranger => 0.25,
      Archetype.knight => -0.10,   // 사각 계열은 0 근처 + 폭으로 표현
      Archetype.paladin => -0.15,
      Archetype.mage => -0.70,
    };
```

이 값이 `tube` 의 `tension`(낮을수록 각짐), 어깨보호대 꼭짓점 각도, 망토 밑단의 지그재그 횟수를 동시에 몬다.

**실루엣 대비 규칙**: 한 캐릭터 안에서 **큰 도형 1개 + 중간 2~3개 + 작은 여러 개**로 크기 위계를 만든다. 같은 크기의 형상이 나열되면 눈이 초점을 못 잡는다.

---

## 스플라인 기본기

**파일: `lib/src/core/spline.dart`**

```dart
extension Offset2 on Offset {
  Offset get perp => Offset(-dy, dx);           // 법선. tube 의 폭 방향
  Offset normalized();                           // 0 길이는 Offset.zero 반환(안전)
  Offset rotated(double a);
  double get angle => math.atan2(dy, dx);
}

Offset lerpO(Offset a, Offset b, double t);
double lerpD(double a, double b, double t);
double clamp01(double v);
double smoothstep(double edge0, double edge1, double x);   // t*t*(3-2t)
```

### smoothClosedPath — 모든 실루엣의 관문

```dart
/// 닫힌 Catmull-Rom 곡선을 Path 로 변환한다. 실루엣 생성의 기본 도구.
Path smoothClosedPath(List<Offset> pts, {double tension = 1.0}) {
  final path = Path();
  final n = pts.length;
  if (n < 3) return path;
  path.moveTo(pts[0].dx, pts[0].dy);
  for (var i = 0; i < n; i++) {
    final p0 = pts[(i - 1 + n) % n];
    final p1 = pts[i];
    final p2 = pts[(i + 1) % n];
    final p3 = pts[(i + 2) % n];
    final c1 = p1 + (p2 - p0) * (tension / 6);
    final c2 = p2 - (p3 - p1) * (tension / 6);
    path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
  }
  path.close();
  return path;
}
```

`smoothOpenPath` 는 같은 원리의 열린 버전(끝점을 복제해 클램프).

**`tension` 의 의미**: 1.0 이 표준 Catmull-Rom. 낮출수록(0.6~0.8) 제어점에 각이 서고, 높이면(1.2+) 과도하게 부풀어 루프가 생긴다. **0.6 ~ 1.1 밖으로 나가지 말 것.**

### resample / smoothPolyline

```dart
/// 폴리라인을 균등 간격으로 재표본화. 두께 프로파일을 적용하기 전에 스파인을
/// 고르게 만들어, 곡률이 큰 구간에서 실루엣이 뭉치는 것을 막는다.
List<Offset> resample(List<Offset> pts, int count);

/// 스파인을 스플라인으로 부드럽게 만든 뒤 촘촘한 폴리라인으로 되돌린다.
List<Offset> smoothPolyline(List<Offset> pts, int samples, {double tension = 1.0});
```

`resample` 을 건너뛰고 관절점 3~4개에 바로 `tube` 를 쓰면, 팔꿈치처럼 각도가 급한 곳에서 두께가 뭉친다.

---

## tube() — 축을 가진 모든 것

팔·다리·목·꼬리·촉수·뿔·무기 자루 — **축(스파인)과 두께(반지름 프로파일)를 가진 모든 형상**의 공통 생성기다.

```dart
Path tube(
  List<Offset> spine,
  List<double> radii, {
  bool capStart = true,
  bool capEnd = true,
  int samples = 22,
  double tension = 1.0,
  /// 좌우 비대칭. 0 이면 대칭, 양수면 법선 + 쪽이 두꺼워진다.
  double bias = 0.0,
})
```

**핵심 로직 3가지:**

1. **스파인 재표본화** — `spine.length >= 3` 이면 `smoothPolyline(spine, samples, tension)`, 아니면 `resample`. 관절점을 그대로 쓰지 않는다.
2. **반지름 보간** — `radii` 는 스파인 길이에 정규화된 프로파일이며 표본 수와 달라도 선형 보간해 맞춘다. 덕분에 **근육 부풀림 곡선을 골격과 독립적으로 저작**할 수 있다.
3. **끝단 캡** — 접선 방향으로 반원(5스텝)을 그려 잘린 단면이 보이지 않게 한다. `capStart`/`capEnd` 를 false 로 두는 것은 다른 파츠에 확실히 묻힐 때뿐.

```dart
// 내부 구현의 요체
for (var i = 0; i < n; i++) {
  final t = i / (n - 1);
  final tangent = (i == 0 ? s[1] - s[0]
                 : i == n - 1 ? s[n-1] - s[n-2]
                 : s[i+1] - s[i-1]).normalized();
  final nrm = tangent.perp;
  final r = radiusAt(t);
  left.add(s[i] + nrm * (r * (1 + bias)));
  right.add(s[i] - nrm * (r * (1 - bias)));
}
// ring = left + endCap + right.reversed + startCap → smoothClosedPath(ring, tension: 0.8)
```

**`bias` 활용**: 종아리 근육(뒤가 두껍다), 대검의 날(한쪽만 예리), 게 집게(비대칭)에 쓴다. `±0.35` 를 넘으면 축이 형상 밖으로 나가 뒤집힌다.

---

## blob() — 덩어리

몸통·머리·알·물집·바위처럼 **축이 없는 덩어리**.

```dart
Path blob(
  Offset center, double rx, double ry, {
  int points = 14,
  double rotation = 0,
  /// 각도별 반지름 배율. 이것이 blob 을 타원에서 생물로 바꾼다.
  double Function(double angle, double t)? warp,
})
```

`warp` 없이 쓰면 그냥 타원이다. **반드시 warp 를 준다:**

```dart
// 흉곽: 위가 넓고 아래가 좁은 역삼각. 어깨 쪽에 볼륨을 더한다.
blob(chest, chestW, chestH, warp: (a, t) {
  final up = -math.sin(a);                       // +1 이 위
  return 1.0 + 0.18 * up + 0.06 * math.sin(a * 3);
});

// 몬스터 살덩이: 노이즈로 불규칙한 융기.
final n = Noise(seed);
blob(c, rx, ry, points: 22, warp: (a, t) => 1.0 + 0.22 * n.signed1(t * 6.0));

// 두개골: 뒤통수가 크고 턱이 좁다.
blob(head, hw, hl, rotation: headAngle, warp: (a, t) {
  final back = math.cos(a);                      // +1 이 뒤
  return 1.0 + 0.14 * back - 0.10 * math.max(0, -back);
});
```

`points` 는 14가 기본. 유기체의 불규칙 표면은 20~26, 결정/금속처럼 각진 것은 6~10.

---

## web() — 파츠 경계 메우기

```dart
/// 두 Path 사이를 잇는 부드러운 연결부. 어깨-몸통, 목-머리처럼 파츠 경계가
/// 딱딱하게 끊기는 곳을 유기적으로 메운다.
Path web(Offset a, double ra, Offset b, double rb, {double bulge = 0.25});
```

**언제 쓰는가**: 파츠를 따로 그리면 관절에서 실루엣이 계단처럼 끊긴다. `web` 을 관절 위에 **한 겹 더 깔면**(파츠보다 먼저 그린다) 경계가 사라진다.

필수 적용 지점: 목–어깨, 어깨–위팔, 골반–허벅지, 꼬리 뿌리, 날개 뿌리.

---

## 두께 프로파일 레시피

`tube` 의 `radii` 는 **길이 방향 정규화 좌표 0..1 의 샘플 목록**이다. 이 프로파일이 근육과 종을 결정한다.

| 부위 | radii (thickness 배율) | 의미 |
|------|------------------------|------|
| 위팔 (인간) | `[0.95, 1.10, 1.00, 0.78]` | 어깨 근처 볼륨, 팔꿈치로 수렴 |
| 위팔 (근육형) | `[1.00, 1.35, 1.12, 0.80]` | 이두근 봉우리를 t≈0.33 에 |
| 아래팔 | `[0.80, 0.92, 0.70, 0.55]` | 팔꿈치 아래 볼록, 손목 수렴 |
| 허벅지 | `[1.15, 1.25, 1.00, 0.72]` | 골반 쪽이 굵다 |
| 정강이 | `[0.78, 0.95, 0.62, 0.48]` | 종아리 봉우리 t≈0.3, `bias: 0.2` 로 뒤쪽 강조 |
| 목 | `[0.95, 0.88, 0.92]` | 중간이 잘록, 두개골 밑에서 넓어짐 |
| 꼬리 | `[1.0, 0.82, 0.60, 0.38, 0.18, 0.06]` | 지수적 수렴 |
| 촉수 | `[0.6, 1.0, 0.85, 0.66, 0.42, 0.10]` | 뿌리보다 조금 아래가 가장 굵다 |
| 뿔 | `[1.0, 0.72, 0.45, 0.20, 0.04]` | 끝이 날카로움, `tension: 0.8` |
| 검신 | `[0.35, 1.0, 0.96, 0.88, 0.30]` | 페룰-강-첨. `bias` 로 날 방향 |

**근육량 반영**: `muscle`(0..1) 로 봉우리만 키운다. 전체를 곱하면 그냥 뚱뚱해진다.

```dart
List<double> withMuscle(List<double> base, double muscle) {
  final peak = base.reduce(math.max);
  return [
    for (final r in base) r * (1 + (r / peak) * (r / peak) * muscle * 0.45),
  ];
}
```

---

## 부위별 형상 레시피

그리기 순서는 **뒤 → 앞** ([isometric.md](isometric.md) 의 8방향 순서표 참조).

### 몸통

몸통 하나를 blob 으로 만들면 실루엣이 감자가 된다. **흉곽 + 복부 + 골반 세 덩어리를 web 으로 잇는다.**

```dart
final ribcage = blob(chestPt, chestW * 0.5, torso * 0.30, warp: ...);
final belly   = blob(waistPt, waistW * 0.5, torso * 0.22, warp: ...);
final pelvis  = blob(pelvisPt, hipW * 0.5, torso * 0.20, warp: ...);
final body = Path()
  ..addPath(web(chestPt, chestW * 0.42, waistPt, waistW * 0.40), Offset.zero)
  ..addPath(web(waistPt, waistW * 0.40, pelvisPt, hipW * 0.42), Offset.zero)
  ..addPath(ribcage, Offset.zero)
  ..addPath(belly, Offset.zero)
  ..addPath(pelvis, Offset.zero);
// Path.combine(PathOperation.union, ...) 로 합치면 윤곽선이 하나로 나온다.
```

`Path.combine(PathOperation.union, a, b)` 를 쓰면 내부 경계선이 사라져 아웃라인이 깨끗하다. 다만 비용이 있으므로 **파츠 조립 시점에 1회**만, 포즈가 바뀌지 않는 파츠에 한해 캐싱한다.

### 사지

`Skeleton.armNear` 등 `Limb(a, b, c, d)` 를 스파인으로 그대로 넘긴다.

```dart
final upper = tube([limb.a, lerpO(limb.a, limb.b, 0.5), limb.b],
                   withMuscle([0.95, 1.10, 1.00, 0.78], spec.muscle)
                       .map((r) => r * spec.armThickness).toList(),
                   samples: 16);
```

중간점을 하나 끼우는 이유: 점 2개면 `resample` 이 직선을 그려 근육 곡선이 살지 않는다.

### 머리

두개골 blob + 턱 + (선택) 후드/투구. **아이소에서는 정수리가 보이므로** 머리 blob 의 상단을 살짝 부풀리고 `paintTopPlane` 을 적용한다.

이목구비는 `facing.toCamera` 일 때만 그린다.

**눈의 겹 수는 트랙에 따라 다르다.**
- **트랙 A**(축소 렌더): 소켓 → 흰자 → 홍채 → 하이라이트 점 **4겹**으로 축약한다. 48px 에서는 그 이상이 보이지 않는다.
- **트랙 B**(초상): `anatomy.dart` 의 `drawEye` 가 **6겹**으로 그린다 — 소켓·흰자·홍채 섬유·동공·각막 하이라이트·눈꺼풀. 상세는 [artist-craft.md](artist-craft.md#얼굴).

어느 쪽이든 **하이라이트 점 하나가 생기를 만든다.**

### 망토 / 천

`ClothStrip.silhouette()` 을 그대로 쓴다 ([animation.md](animation.md)). 밑단은 `hemSag` 로 처지게 하고, 원형이 공격적이면 밑단에 지그재그를 준다:

```dart
Path jaggedHem(Path cloth, int teeth, double depth) { /* 밑단 정점을 번갈아 올림 */ }
```

### 무기

무기는 **실루엣 판독의 두 번째 축**이다(캐릭터 실루엣 + 무기 실루엣). 검신은 `tube` + `bias`, 도끼날은 `blob` + `warp`, 지팡이는 `tube` + 끝단 `gem`.

무기 길이는 캐릭터 키의 비율로: 검 0.45, 대검 0.72, 창 1.15, 지팡이 1.05, 활 0.62, 단검 0.20.

---

## 디테일 배치 원칙

**"디테일이 사방에 있으면 디테일이 없는 것과 같다."**

1. **디테일 섬(island)을 3개만 만든다.** 보통 머리/가슴/무기. 나머지는 큰 면으로 비운다.
2. **큰 면 : 중간 : 작은 디테일 = 6 : 3 : 1** 의 면적 비율.
3. **관절과 실루엣 경계에 디테일을 몰지 않는다.** 그 부분은 이미 눈이 보고 있다.
4. **아이소 축소를 고려**: 48px 로 줄었을 때 사라질 디테일은 `Quality.high` 전용으로 두고, 실루엣에 기여하는 것(뿔·어깨보호대)만 항상 그린다.

---

## 검증: squint test

절차적 생성기를 고칠 때마다 다음 3단계를 돌린다.

```dart
/// 실루엣 검증 모드. 모든 파츠를 단색으로 칠해 형태만 남긴다.
/// 갤러리 화면에 토글을 두고, 생성 규칙을 바꿀 때마다 반드시 확인한다.
void renderSilhouetteOnly(Canvas canvas, List<Path> parts) {
  final black = Paint()..color = const Color(0xFF000000);
  for (final p in parts) {
    canvas.drawPath(p, black);
  }
}
```

1. **단색 테스트** — 전부 검게 칠하고 원형(knight/mage/…)이 구분되는가.
2. **축소 테스트** — 48px 로 줄이고 여전히 구분되는가. 아이소 게임의 실제 크기다.
3. **분포 테스트** — 시드 12~24개를 한 화면에 띄우고, 전부 비슷하지 않은지 / 극단값이 흉하지 않은지 확인한다. **하나만 보고 판단하면 분포의 실패를 놓친다.**

세 테스트 중 하나라도 실패하면 셰이딩이 아니라 **생성 규칙**을 고친다.
