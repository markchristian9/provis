# 2.5D 아이소메트릭 — 투영·페이싱·정렬

이 프로젝트의 게임 맵은 **항상 2.5D 아이소메트릭**이다. 이 문서의 규칙은 선택이 아니라 전제다.

## 목차

1. [핵심 개념: 지면은 눕고 캐릭터는 선다](#핵심-개념-지면은-눕고-캐릭터는-선다)
2. [투영 수식과 IsoView (핵심 소스코드)](#투영-수식과-isoview)
3. [8방향 페이싱 — 스프라이트 없이 회전하기](#8방향-페이싱)
4. [수직 단축과 상단면](#수직-단축과-상단면)
5. [접지: 그림자가 곧 좌표다](#접지-그림자가-곧-좌표다)
6. [깊이 정렬 (y-sort)](#깊이-정렬-y-sort)
7. [아이소 전용 실루엣 규칙](#아이소-전용-실루엣-규칙)
8. [타일 대비 캐릭터 스케일](#타일-대비-캐릭터-스케일)
9. [체크리스트](#체크리스트)

---

## 핵심 개념: 지면은 눕고 캐릭터는 선다

2.5D 아이소메트릭에서 초보가 반드시 하는 실수는 **캐릭터까지 아이소 평면에 투영하는 것**이다. 그러면 인체가 마름모로 찌그러져 아무리 잘 칠해도 살아나지 않는다.

올바른 모델은 이것이다:

```
       ╱╲        ← 지면 타일: 아이소 평면에 누움 (2:1 마름모)
      ╱  ╲
     ╱ ┃  ╲      ← 캐릭터: 지면 위에 화면 수직으로 세워진 카드
    ╱ ┃┃┃  ╲        (billboard). 아이소 투영을 받지 않는다.
   ╱  ┃┃┃   ╲
  ╱___(oval)__╲   ← 접지 그림자: 다시 아이소 평면에 누움 (2:1 타원)
```

- **아이소 투영을 받는 것**: 지면 타일, 접지 그림자, 지면에 놓인 오브젝트의 밑면, 캐릭터의 **접지점 좌표 하나**.
- **아이소 투영을 받지 않는 것**: 캐릭터의 몸 전체. 국소 공간에서 수직으로 그린 뒤 세로만 `cos30°` 압축한다.

이 분리 덕분에 `rig/` 의 골격·IK·포즈 코드를 **한 줄도 고치지 않고** 아이소 씬에 얹을 수 있다.

---

## 투영 수식과 IsoView

2:1 dimetric(업계에서 통칭 "아이소메트릭")은 카메라 yaw 45°, **고도각 30°** 의 정사영이다. 월드 축 단위벡터의 화면 투영:

| 월드 축 | 화면 벡터 | 비율 |
|---------|-----------|------|
| +X | `( cos45, sin45·sin30)` = `(0.707,  0.354)` | 타일 폭/2, 타일 높이/2 |
| +Y | `(-cos45, sin45·sin30)` = `(-0.707, 0.354)` | |
| +Z (수직) | `(0, -cos30)` = `(0, -0.866)` | 높이 스케일 |

여기서 `tileHeight / tileWidth = sin(고도각)` 이라는 관계가 나온다. 2:1 이면 `sin θ = 0.5` → `θ = 30°`, 수직 단축 `cos 30° = 0.866`.

**신설 파일: `lib/src/render/iso.dart`**

```dart
import 'dart:math' as math;
import 'dart:ui';

/// 2.5D 아이소메트릭 카메라.
///
/// 게임 맵 전체가 이 하나의 리그를 공유한다. 타일 비율을 바꾸면 고도각과
/// 수직 단축이 함께 따라오므로, 스케일 상수를 손으로 흩어 두지 않는다.
class IsoView {
  const IsoView({this.tileWidth = 128, this.tileHeight = 64});

  /// 타일 한 칸의 화면 폭. 높이와의 비가 곧 카메라 고도각이다.
  final double tileWidth;
  final double tileHeight;

  /// sin(고도각). 2:1 타일이면 0.5 → 30°.
  double get elevationSin => (tileHeight / tileWidth).clamp(0.05, 0.98);

  /// cos(고도각). 수직 물체가 화면에서 짧아지는 비율.
  double get squash => math.sqrt(1 - elevationSin * elevationSin);

  /// 고도각(라디안). 상단면 하이라이트 강도 계산에 쓴다.
  double get elevation => math.asin(elevationSin);

  /// 월드 수직 1 단위가 화면에서 차지하는 픽셀.
  /// 유도: heightScale / (tileWidth/2) = cosθ / cos45° = cosθ·√2
  double get heightScale => tileWidth * squash / math.sqrt2;

  /// 월드 타일 좌표 → 화면 좌표. [wz] 는 지면 위 높이(양수가 위).
  Offset project(double wx, double wy, [double wz = 0]) => Offset(
        (wx - wy) * tileWidth * 0.5,
        (wx + wy) * tileHeight * 0.5 - wz * heightScale,
      );

  /// 화면 좌표 → 지면(z=0) 월드 좌표. 마우스 피킹·타일 하이라이트에 쓴다.
  Offset unproject(Offset screen) {
    final a = screen.dx / (tileWidth * 0.5);
    final b = screen.dy / (tileHeight * 0.5);
    return Offset((b + a) * 0.5, (b - a) * 0.5);
  }

  /// 깊이 정렬 키. 클수록 화면 앞(나중에 그림).
  double depthKey(double wx, double wy) => wx + wy;

  /// 접지 그림자 타원의 세로/가로 비.
  double get shadowRatio => elevationSin;
}

/// 프로젝트 기본 카메라. 액터 렌더러는 이것을 참조한다.
const IsoView kIso = IsoView();
```

**호출 규약** — 액터를 그리는 진입부는 언제나 이 3단계다:

```dart
void renderActor(Canvas canvas, IsoView iso, Offset worldTile, void Function(Canvas) body) {
  final anchor = iso.project(worldTile.dx, worldTile.dy);
  canvas.save();
  canvas.translate(anchor.dx, anchor.dy);   // ① 접지점으로 이동 (아이소 투영은 여기까지)
  canvas.scale(1, iso.squash);              // ② 세로만 단축 (몸은 수직 카드)
  body(canvas);                             // ③ 국소 공간에서 평소대로 그린다
  canvas.restore();
}
```

> **경고**: `canvas.scale(1, squash)` 안에서 `MaskFilter.blur` 반경과 `strokeWidth` 도 함께 세로로 눌린다. 실무상 0.87 배 왜곡은 눈에 띄지 않으므로 허용한다. 정확한 원형 블러가 필요한 발광 코어는 scale 밖에서 그린다.

---

## 8방향 페이싱

아이소 게임은 보통 8방향 스프라이트를 굽는다. 이 프로젝트는 **절차적 벡터**이므로 스프라이트가 필요 없다 — yaw 를 연속 값으로 받아 골격을 재배치한다. 8방향으로 스냅하는 것은 **입력 처리 쪽 선택**이지 렌더러의 제약이 아니다.

```dart
/// 액터가 바라보는 방향. yaw = 0 이 카메라 정면(화면 아래, 아이소 S).
///
/// 스프라이트를 굽지 않으므로 yaw 는 연속값이어도 된다. 8방향 게임플레이에서는
/// [snap8] 으로 스냅하되, 전환 시 `lerpAngle`(rig/ik.dart)로 부드럽게 돌리면 스프라이트
/// 기반 게임이 낼 수 없는 품질이 나온다.
class Facing {
  const Facing(this.yaw);

  final double yaw;

  /// 8방향 인덱스 0=S, 1=SE, 2=E, 3=NE, 4=N, 5=NW, 6=W, 7=SW
  int get octant => ((yaw / (math.pi / 4)).round() % 8 + 8) % 8;

  Facing get snap8 => Facing(octant * math.pi / 4);

  /// 0 = 정면/후면, 1 = 완전 측면. 어깨 폭 축소에 쓴다.
  double get profile => math.sin(yaw).abs();

  /// 카메라를 향하고 있는가. 얼굴을 그릴지 뒤통수를 그릴지 결정한다.
  bool get toCamera => math.cos(yaw) > 0;

  /// +1 이면 화면 오른쪽 팔이 near, -1 이면 왼쪽 팔이 near.
  double get nearSide => math.sin(yaw) >= 0 ? 1 : -1;

  /// 어깨선이 화면에서 보이는 폭 비율. 측면일수록 좁다.
  double get shoulderScale => 1.0 - 0.62 * profile;

  /// 사지의 앞뒤 어긋남 정도. 정면에서는 0(겹침), 측면에서 최대.
  double get depthSpread => profile;
}
```

**렌더러가 yaw 를 소비하는 방법** — 파츠마다 다르게 쓴다:

| 요소 | yaw 반영 방식 |
|------|---------------|
| 어깨 폭 / 골반 폭 | `body.shoulderHalf * facing.shoulderScale` |
| near/far 사지 | `facing.nearSide` 부호로 **그리기 순서를 뒤집는다** |
| 사지 깊이 오프셋 | `spec.depthOffset * facing.depthSpread * facing.nearSide` |
| 얼굴 | `facing.toCamera` 면 이목구비, 아니면 뒤통수·머리 뒤 장비 |
| 망토 | 후면(`!toCamera`)일 때 몸통 **앞에** 그린다 |
| 무기 | 손 좌표에 붙되, 정면일 때는 몸통 뒤/앞 판정을 `nearSide` 로 |

**그리기 순서(뒤 → 앞)** — `toCamera` 여부로 두 가지 순서를 갖는다:

```dart
// 정면(toCamera == true)
farLeg → farArm → cape → torso → head → nearLeg → nearArm → weapon → FX

// 후면(toCamera == false)
farLeg → farArm → torso → head → cape → nearLeg → nearArm → weapon → FX
//                                       ^^^^ 망토가 몸을 덮는다
```

이 두 순서를 하드코딩된 if 로 분기하지 말고 **파츠 리스트에 depth 값을 붙여 정렬**하면 새 장비를 추가할 때 순서 버그가 사라진다.

---

## 수직 단축과 상단면

카메라가 30° 위에서 내려다보므로 두 가지가 따라온다.

**① 세로 압축** — `canvas.scale(1, iso.squash)` 로 일괄 적용. `Body`/`Pose` 치수에 미리 곱해 넣지 말 것. IK 는 실제 사지 길이로 풀어야 하며, 압축된 길이로 풀면 무릎이 어긋난다.

**② 상단면이 보인다** — 어깨 윗면, 투구 정수리, 어깨보호대 윗면, 발등. 3D 라면 노멀이 위를 향하는 면이다. 2D 에서는 이것을 **파츠 상단의 짧고 밝은 밴드**로 표현한다. 이 한 가지가 아이소 캐릭터를 "위에서 본 것"으로 읽히게 만드는 결정적 장치다.

```dart
/// 아이소 뷰에서 위를 향한 면에 얹는 하이라이트.
///
/// 카메라가 내려다보는 각도만큼 파츠의 상단이 하늘빛을 받는다. 어깨·투구·
/// 어깨보호대·발등처럼 "윗면이 있는" 파츠에만 준다. 사지 옆면에 주면
/// 오히려 형태가 납작해진다.
void paintTopPlane(
  Canvas canvas,
  Path path,
  LightRig light,
  IsoView iso, {
  double strength = 0.5,
}) {
  final b = path.getBounds();
  if (b.isEmpty) return;
  // 고도각이 클수록(위에서 볼수록) 상단면이 넓게 보인다.
  final band = 0.18 + 0.30 * iso.elevationSin;
  canvas.save();
  canvas.clipPath(path, doAntiAlias: true);
  canvas.drawRect(
    b,
    Paint()
      ..blendMode = BlendMode.plus
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          mix(light.rimColor, light.keyColor, 0.45)
              .withValues(alpha: (0.34 * strength).clamp(0, 1)),
          const Color(0x00000000),
        ],
        stops: [0.0, band],
      ).createShader(b),
  );
  canvas.restore();
}
```

호출 위치: `paintSurface` **직후**, 해당 파츠에만.

---

## 접지: 그림자가 곧 좌표다

아이소 뷰에는 원근이 없어 **높이와 깊이가 화면상 같은 축(세로)을 공유**한다. 그래서 그림자가 없으면 캐릭터가 지면 위 어디에 있는지 물리적으로 판별 불가능하다. 점프한 캐릭터와 뒤쪽에 선 캐릭터가 똑같아 보인다.

**규칙: 아이소 씬의 모든 액터는 접지 그림자를 반드시 그린다. 예외 없음.**

```dart
/// 아이소 지면에 눕는 접지 그림자. iso.shadowRatio 로 2:1 타원이 된다.
void paintIsoGroundShadow(
  Canvas canvas,
  IsoView iso,
  Offset groundAt,      // 액터 국소 공간의 접지점 (보통 Offset.zero)
  double width,
  LightRig light, {
  double strength = 0.5,
  double airborne = 0.0,   // 지면에서 뜬 높이(월드 단위). 점프 시 그림자가 작고 옅어진다.
}) {
  final k = (1 - airborne * 0.6).clamp(0.35, 1.0);
  paintGroundShadow(
    canvas,
    groundAt,
    width * k,
    width * iso.shadowRatio * k,   // ← 원이 아니라 2:1 타원
    light,
    strength: strength * k,
  );
}
```

- **점프/비행**: 캐릭터는 위로 올라가지만 그림자는 접지점에 남고 작아진다. 이것만으로 높이가 읽힌다.
- **광원 오프셋**: `paintGroundShadow` 가 `light.shadowDir` 로 이미 밀어 준다. 씬 전역 광원이 하나이므로 모든 액터의 그림자가 같은 방향으로 눕는다 — 이것이 여러 캐릭터를 "한 세계에" 묶는다.

---

## 깊이 정렬 (y-sort)

```dart
// Flame: 매 프레임 priority 를 깊이 키로 갱신한다.
@override
void update(double dt) {
  super.update(dt);
  priority = (kIso.depthKey(worldTile.dx, worldTile.dy) * 1000).round();
}
```

- 정렬 키는 **화면 y 가 아니라 월드 `wx + wy`** 다. 화면 y 를 쓰면 점프한 캐릭터가 갑자기 뒤로 밀린다 (높이가 y 를 줄이므로).
- 큰 오브젝트(벽·나무)는 접지점 하나로 정렬하면 겹침이 틀어진다. 타일 단위로 쪼개거나, 캐릭터가 뒤로 지나갈 때 반투명 처리한다.
- 같은 키를 갖는 액터는 안정 정렬이 보장되지 않으므로, 미세한 tie-breaker(엔티티 id)를 더해 깜빡임을 막는다.

---

## 아이소 전용 실루엣 규칙

일반적인 캐릭터 실루엣 원칙([silhouette.md](silhouette.md))에 아이소 고유 제약이 더해진다.

1. **머리 위가 실루엣의 왕좌다.** 위에서 내려다보므로 캐릭터의 상단 30% 가 가장 먼저 읽힌다. 뿔·깃털·후드·어깨보호대의 **윗면 윤곽**에 개성을 몰아준다. 발치의 디테일은 거의 보이지 않는다.
2. **좌우 폭보다 상하 실루엣이 짧다.** `squash` 로 세로가 0.87 배 눌리므로, 세로로만 긴 형상(창·긴 지팡이)은 설계 단계에서 조금 더 길게 잡는다.
3. **어깨선이 방향을 말한다.** yaw 판독의 90% 는 어깨 폭과 어깨보호대의 비대칭에서 온다. 측면일 때 `shoulderScale` 이 충분히 작아지지 않으면 방향이 안 읽힌다.
4. **바닥 접점은 한 점으로 모은다.** 다리를 넓게 벌린 포즈는 아이소에서 어느 타일에 서 있는지 모호해진다. 접지점은 항상 `Skeleton.groundContact` 하나.
5. **squint test 는 아이소 축소 상태에서 한다.** 실제 게임에서 캐릭터는 화면의 작은 일부다. 200px 로 렌더한 뒤 **48px 로 축소해서** 원형이 구분되는지 확인한다. 이 테스트를 통과하지 못하면 디테일을 더 넣는 게 아니라 실루엣을 다시 잡아야 한다.
6. **정면과 후면이 달라야 한다.** 절차적 생성기는 뒷모습을 잊기 쉽다. 망토·등에 멘 무기·머리 뒤 장식으로 후면 실루엣에도 정보를 준다.

---

## 타일 대비 캐릭터 스케일

| 항목 | 권장값 (tileWidth 128 기준) |
|------|------------------------------|
| 타일 | 128 × 64 |
| 일반 인간형 키 | 150 ~ 200 px (타일 폭의 1.2~1.6배) |
| 정예/보스 | 240 ~ 400 px |
| 소형 몹 | 90 ~ 130 px |
| 접지 그림자 폭 | 어깨 폭의 1.6 ~ 2.0배 |
| 캐릭터 상단 여유 | 무기·오라 포함해 키의 +40% |

`Body.humanoid(r, height: 300)` 의 기본 300 은 **갤러리 미리보기용**이다. 아이소 씬에 배치할 때는 `height: 180` 안팎으로 낮추고, 대신 `Quality` 를 유지한다 — 작아졌다고 패스를 빼면 캐릭터가 실루엣 덩어리로 뭉개진다.

---

## 체크리스트

액터 렌더러를 완성했다면 아래를 전부 확인한다.

- [ ] 접지 그림자가 2:1 타원인가 (원이면 지면에 눕지 않은 것)
- [ ] `canvas.scale(1, iso.squash)` 가 렌더 진입부에 **한 번만** 적용됐는가
- [ ] `Body`/`Pose` 치수에 squash 가 섞여 들어가지 않았는가
- [ ] 8방향을 모두 돌려 봤을 때 near/far 사지 순서가 뒤집히는가
- [ ] 후면(yaw = π)에서 얼굴 대신 뒤통수가 나오는가
- [ ] 망토가 후면에서 몸통을 덮는가
- [ ] 어깨·투구에 `paintTopPlane` 이 적용됐는가
- [ ] `priority` 가 월드 `wx + wy` 로 갱신되는가 (화면 y 가 아님)
- [ ] 48px 로 축소해도 원형이 구분되는가
- [ ] 점프 시 그림자가 접지점에 남고 작아지는가
