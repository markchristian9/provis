# 성능 — Flame 통합·예산·캐싱

## 목차

1. [핵심 개념: 이 파이프라인의 비용 구조](#핵심-개념-이-파이프라인의-비용-구조)
2. [비용 표 — 무엇이 비싼가](#비용-표--무엇이-비싼가)
3. [Flame 통합 (핵심 소스코드)](#flame-통합)
4. [품질 티어 — Quality 를 거리로 몬다](#품질-티어)
5. [Picture 캐싱 — 정적 파츠 굽기](#picture-캐싱)
6. [아틀라스 하이브리드 — 군중 렌더링](#아틀라스-하이브리드)
7. [프레임 예산표](#프레임-예산표)
8. [측정 방법](#측정-방법)
9. [최적화 체크리스트](#최적화-체크리스트)

---

## 핵심 개념: 이 파이프라인의 비용 구조

`paintSurface` 는 품질을 위해 **파츠 하나당 `saveLayer` 1회 + `MaskFilter.blur` 3~6회**를 쓴다. 이것은 의도된 설계지만 비용을 정확히 알아야 한다.

`saveLayer` 는 **오프스크린 버퍼를 할당하고 렌더 타깃을 전환**한다. GPU 는 소방호스처럼 흐르길 원하는데, 렌더 타깃 전환은 그 흐름을 돌렸다가 되돌리는 일이다. 모바일 GPU(타일 기반)에서 특히 파괴적이다.

캐릭터 한 명 = 파츠 약 18~26개 = **`saveLayer` 18~26회**. 액터 10명이면 200회가 넘고, 그 시점에서 저사양 기기의 프레임은 무너진다.

따라서 전략은 셋이다:

1. **디테일 티어** — 멀리 있고 작은 액터는 `detail` 을 낮춘다. 각 `Finish` 구현이 `detail` 로 미세 텍스처(스크래치·섬유결·기공)를 게이팅하고, `Artist` 는 파티클까지 생략한다.
2. **캐싱** — 포즈가 바뀌지 않는 파츠(무기·장비·정적 몹)는 `ui.Picture` 로 한 번 굽는다.
3. **임포스터** — 아주 멀거나 아주 많은 액터는 실루엣 + 그림자만 그린다.

---

## 비용 표 — 무엇이 비싼가

> **⚠️ 이 문서의 수치는 미측정 가설이다.** 상대 비용·`saveLayer` 150회·블러 3000px 은 이 프로젝트에서
> 실측한 값이 아니라 일반적인 Skia/Impeller 특성에서 온 출발점이다. 최적화 판단의 근거로 쓰되,
> **합격 기준으로 쓰지 마라.** `flutter run --profile` 로 실측한 뒤 이 표를 갱신할 것.
>
> **또한 이 표는 이미 삭제된 계보 A(`render/surface.dart`)의 파츠당 `saveLayer` 구조를 전제한다.**
> 현재 유일한 계보인 `core/shading.dart` 의 `paintSurface` 는 **`saveLayer` 를 쓰지 않고**
> `save`+`clipPath` 로만 그린다. 따라서 아래 `saveLayer` 예산은 지금 코드에 그대로 적용되지 않는다 —
> 실제 병목은 `MaskFilter.blur`(글로우·`rimBand`·`castShadow`)와 `Path.combine`(`rimBand`) 쪽이다.
> 실측 후 이 절을 다시 쓸 것.

| 연산 | 상대 비용 | 비고 |
|------|-----------|------|
| `canvas.drawPath` (단색) | 1 | 기준 |
| `canvas.drawPath` (그라디언트 셰이더) | 2–3 | 셰이더 생성은 매 프레임 |
| `MaskFilter.blur` | 8–20 | **반경에 비례**. 큰 블러가 특히 비쌈 |
| `canvas.saveLayer` | 25–60 | 렌더 타깃 전환. 영역 크기에 비례 |
| `Path.combine` | 15–40 | 경로 복잡도에 비례. 매 프레임 금지 |
| `path.getBounds()` | 1 | 캐시되지만 변환 후엔 재계산 |
| `LinearGradient.createShader` | 3–6 | **매 프레임 새로 만들지 말 것** |
| `ui.Picture` 재생 | 1–2 | 캐싱의 근거 |
| `drawAtlas` (N개) | 1 + 0.05N | 군중에 압도적으로 유리 |

**즉시 적용할 세 가지:**

- `Paint` 와 `Shader` 를 매 프레임 새로 만들지 않는다. 액터 필드에 캐시하고 색/변환만 갱신한다. (단, `paintSurface` 내부는 `Rect` 의존이라 캐시가 어렵다 — 그래서 캐싱은 파츠 단위가 아니라 **Picture 단위**로 한다.)
- 블러 반경을 파츠 크기에 비례시키되 **상한을 둔다**. `size * 0.42` 가 400px 파츠에서 168px 블러가 되면 그 한 번이 프레임을 먹는다.
- **블러는 개수로 죽는다 — 형상을 모아 한 번에 태운다.** 실측으로 확인된 가장 큰
  실수다. 얼룩·반점·잎을 점마다 블러로 그리면 수관 하나에 블러가 수십 번 걸리고,
  나무 스무 그루면 수천 번이 된다.

```dart
// ✗ 나쁨 — 셀마다 블러. 한 파츠에 40~50회
for (var y = ...) for (var x = ...) {
  c.drawCircle(p, r, paint..maskFilter = blur);
}

// ✓ 좋음 — 밝은 것과 어두운 것을 각각 한 Path 에 모아 블러 2회
final lit = Path(), dark = Path();
for (...) { k > 0.63 ? lit.addOval(...) : dark.addOval(...); }
c.drawPath(dark, paint..color = r.deep.fade(a) ..maskFilter = blur);
c.drawPath(lit,  paint..color = r.light.fade(a)..maskFilter = blur);
```

  같은 이유로 `Path.combine`(= `rimBand`·`translucentBand`)은 복합 형상에서
  비싸다. **덩어리마다 부르지 말고 앞쪽·위쪽 것에만** 얹는다 — 뒤쪽 잎 덩어리와
  아래쪽 침엽수 층은 어차피 가려져 보이지 않는다.

---

## Flame 통합

**현재 위치: `lib/main.dart` 의 `ActorComponent`** (별도 파일이 아니다). 아래는 그 구조를 요약한
참고 골격이며, 실제 코드를 고칠 때는 `main.dart` 를 연다.

```dart
import 'package:flame/components.dart';
import 'dart:ui';

/// 아이소 씬에 놓이는 액터 한 구.
///
/// Flame 의 컴포넌트 트리를 좌표계로 쓰지 않는다. 위치는 월드 타일 좌표로
/// 들고 있고, 화면 좌표는 render 시점에 IsoView 로 투영한다. 그래야
/// 깊이 정렬(priority)과 그리기가 같은 진실을 공유한다.
class ActorComponent extends PositionComponent {
  ActorComponent({required this.spec, required this.iso, required this.light})
      : super(anchor: Anchor.bottomCenter);

  final HumanoidSpec spec;
  final IsoView iso;
  LightRig light;

  /// 월드 타일 좌표. 게임 로직은 이것만 갱신한다.
  Offset worldTile = Offset.zero;
  double airborne = 0;          // 지면 위 높이(월드 단위)
  Facing facing = const Facing(0);
  double detail = 1.0;

  late final Body _body = /* spec → Body */;
  late final ClothStrip? _cape = spec.hasCape ? /* … */ : null;

  double _t = 0;
  Offset _prevScreen = Offset.zero;

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;

    // ① 화면 좌표 갱신
    final screen = iso.project(worldTile.dx, worldTile.dy, airborne);
    position = Vector2(screen.dx, screen.dy);

    // ② 깊이 정렬. 화면 y 가 아니라 월드 (wx + wy) 로 정렬해야
    //    점프한 액터가 뒤로 밀리지 않는다.
    priority = (iso.depthKey(worldTile.dx, worldTile.dy) * 1000).round();

    // ③ 2차 모션. carry 는 화면 공간 이동량으로 준다.
    final carry = dt > 0 ? (screen - _prevScreen) / dt : Offset.zero;
    _prevScreen = screen;
    _cape?.step(dt, /* anchorL */, /* anchorR */, carry: carry);
  }

  @override
  void render(Canvas canvas) {
    final pose = /* 현재 상태의 클립 */;
    final skel = solve(_body, pose);

    // 접지 그림자는 세로 압축 밖에서, 지면 평면에 눕힌다.
    paintIsoGroundShadow(canvas, iso, Offset.zero,
        _body.shoulderHalf * 3.4, light, airborne: airborne);

    canvas.save();
    canvas.scale(1, iso.squash);        // 카메라 고도각에 따른 수직 단축
    _paintActor(canvas, skel);          // 국소 공간에서 평소대로
    canvas.restore();
  }
}
```

### Flame 사용 시 주의

- **`CustomPainterComponent` 를 쓰지 않는다.** 위젯 레이어를 한 번 더 거쳐 불필요한 오버헤드가 생긴다. `PositionComponent.render(Canvas)` 를 직접 오버라이드한다.
- **`priority` 갱신은 값이 바뀔 때만.** 매 프레임 대입하면 컴포넌트 트리가 매번 재정렬된다. `if (p != priority) priority = p;`
- **Flame 의 `renderSnapshot`** (SnapshotComponent) 은 배경·정적 장식에 유효하다. 매 프레임 포즈가 바뀌는 액터에는 오히려 손해다.
- **`HasAutoBatchedChildren`** 은 유사한 자식이 많을 때(타일·파티클) 효과가 크다. 절차적 액터는 각자 다른 경로를 그리므로 배칭 이득이 거의 없다.

---

## 품질 티어

`detail`(0..1)은 각 `Finish` 구현 안에서 미세 텍스처를 게이팅한다:

| 패스 | detail 0.25 | detail 0.6 | detail 1.0 |
|------|-----|--------|------|
| 외곽 글로우 | ✗ | ✓ | ✓ |
| 확산 / 반사광 / AO / 정반사 / 림 / 윤곽선 | ✓ | ✓ | ✓ |
| 표면하 산란 | ✗ | ✓ | ✓ |
| 스펙큘러 코어 | ✗ | ✗ | ✓ |
| 미세 디테일 | ✗ | ✗ | ✓ |

**티어를 무엇으로 정하는가** — 화면상 크기와 게임플레이 중요도:

```dart
double detailFor(double screenHeightPx, {bool isPlayer = false, bool isBoss = false}) {
  if (isPlayer || isBoss) return 1.0;      // 항상 최고
  if (screenHeightPx > 140) return 1.0;
  if (screenHeightPx > 70) return 0.6;
  return 0.25;
}
```

**추가 티어 (파이프라인 밖에서)**:

```dart
/// 아주 작거나(<32px) 아주 많은 액터. 실루엣 + 그림자 + 색 하나.
/// 구현체는 `lib/src/iso/iso_view.dart` 의 `paintImposter` 다.
void paintImposter(Canvas canvas, Path silhouette, Color tint, LightRig light) {
  canvas.drawPath(silhouette, Paint()..color = tint);
  canvas.drawPath(silhouette, Paint()      // 림만 남긴다 — 이것만으로 형태가 산다
    ..style = PaintingStyle.stroke ..strokeWidth = 1.5
    ..color = light.rimColor.withValues(alpha: 0.5)
    ..blendMode = BlendMode.plus);
}
```

`saveLayer` 0회, 블러 0회. 군중 100명도 감당한다.

---

## Picture 캐싱

**원칙: 프레임 간에 바뀌지 않는 것은 굽는다.**

무엇이 정적인가:
- 무기·방패·투구 등 **파츠 국소 공간에서 형상이 고정된** 장비 (위치는 변환으로 처리)
- 정지 몹, 배경 오브젝트
- 아이들 루프만 도는 원거리 NPC (N프레임마다 갱신)

```dart
/// 파츠를 한 번 굽고 이후엔 재생만 한다.
class BakedPart {
  BakedPart._(this.picture, this.bounds);
  final Picture picture;
  final Rect bounds;

  /// [draw] 를 국소 좌표계에서 실행해 Picture 로 굽는다.
  factory BakedPart.bake(Rect bounds, void Function(Canvas) draw) {
    final rec = PictureRecorder();
    final c = Canvas(rec, bounds);
    draw(c);
    return BakedPart._(rec.endRecording(), bounds);
  }

  /// 변환만 걸어 재생. saveLayer·블러가 다시 실행되지 않는다.
  void replay(Canvas canvas, {Offset at = Offset.zero, double rotation = 0, double scale = 1}) {
    canvas.save();
    canvas.translate(at.dx, at.dy);
    if (rotation != 0) canvas.rotate(rotation);
    if (scale != 1) canvas.scale(scale);
    canvas.drawPicture(picture);
    canvas.restore();
  }

  void dispose() => picture.dispose();
}
```

**사용 규약:**

1. **광원이 바뀌면 다시 굽는다.** 구운 파츠에는 조명이 이미 칠해져 있다. 낮/밤 전환, `rotatedKey` 시 전체 무효화. 무효화 키: `(specSeed, lightPresetIndex, quality)`.
2. **셰이딩된 파트는 회전 재생하지 않는다.** 구운 `Picture` 에는 조명이 이미 칠해져 있으므로, 파츠를
   돌리면 하이라이트·그림자·스크래치 방향도 함께 돌아 **월드 조명이 무너진다**. 회전이 필요하면
   각도를 캐시 키에 넣어 각도별로 따로 굽는다. 비균등 스케일도 금지 — 블러와 스펙큘러가 찌그러진다.
   캐시 키 = `(specSeed, lightPreset, quality, angleBucket, scale)`.
3. **반드시 `dispose`.** `Picture` 는 네이티브 자원이다. 액터 제거 시 해제하지 않으면 누수된다.
4. **N프레임 갱신**: 원거리 NPC 는 6~10프레임마다 다시 구우면 움직이면서도 비용이 1/8 이다.

```dart
// 조명 변경 시 전체 무효화
void onLightChanged(LightRig next) {
  light = next;
  for (final p in _baked.values) { p.dispose(); }
  _baked.clear();
}
```

---

## 아틀라스 하이브리드 — 군중 렌더링

같은 종의 몹이 20마리 이상 나오는 씬에서는, 절차적 렌더링의 결과를 **런타임에 스프라이트 아틀라스로 구워** `drawAtlas` 로 뿌린다. 절차적 다양성(시드별 외형)과 스프라이트 성능을 동시에 얻는다.

```
① 스폰 시점에 시드별로 8방향 × K프레임을 오프스크린 렌더 → ui.Image
② 이후 프레임은 canvas.drawAtlas(image, transforms, rects, colors, ...) 한 번
③ 시드가 다른 개체는 아틀라스 슬롯만 다르게 참조
```

**언제 이걸 쓰는가**: 동시 20+ 액터, 저사양 타깃, 웹. **쓰지 말아야 할 때**: 플레이어·보스(연속 회전과 IK 보정이 스프라이트로 표현 안 됨).

굽는 비용은 개체당 8×K 회의 전체 렌더다. 스폰 프레임에 몰리면 스파이크가 생기므로 **프레임당 1~2 슬롯씩 점진적으로** 굽는다.

---

## 프레임 예산표

60fps = 16.6ms. 실제로는 UI·물리·게임로직이 쓰므로 **렌더에 8~10ms** 를 잡는다.

| 상황 | 액터 수 | 권장 구성 | 예상 `saveLayer` |
|------|---------|-----------|------------------|
| 플레이어 단독(캐릭터 시트) | 1 | high, 캐싱 없음 | ~24 |
| 일반 전투 | 4–8 | 플레이어 high, 나머지 medium | ~90 |
| 소규모 무리 | 10–16 | high 1, medium 3, low 나머지 | ~120 |
| 대규모 전투 | 20–40 | high 1, medium 3, 나머지 아틀라스/임포스터 | ~50 |
| 웹/저사양 | — | 전 티어 한 단계 하향 + 아틀라스 | ~40 |

**상한선**: 프레임당 `saveLayer` **150회**를 넘기면 중급 모바일에서 60fps 가 무너진다. 넘어가면 티어를 낮추거나 캐싱한다.

블러 상한: `MaskFilter.blur` 반경의 **합계**가 프레임당 3000px 를 넘지 않게 한다 (파츠 24개 × 반경 40px × 3패스 ≈ 2880).

---

## 측정 방법

```bash
flutter run --profile          # 반드시 profile 모드. debug 는 측정 의미 없음
```

1. **DevTools → Performance** 에서 **Raster thread** 를 본다. UI thread 가 아니라 raster 가 길면 `saveLayer`·블러 문제다.
2. **`debugProfilePaintsEnabled = true`** 로 페인트 단계를 타임라인에 노출.
3. **Impeller 셰이더 컴파일 지연**: 첫 등장 시 프레임이 튀면 워밍업이 필요하다. 게임 시작 시 대표 액터 1구를 화면 밖에서 한 번 렌더한다.
4. **웹**: CanvasKit 에서 `saveLayer` 가 더 비싸다. 웹 타깃이면 기본 `Quality` 를 한 단계 낮춘다.

---

## 최적화 체크리스트

적용 순서대로. 위쪽이 효과 대비 비용이 낮다.

- [ ] `Quality` 티어를 화면 크기로 자동 결정하는가
- [ ] 32px 미만 액터에 임포스터를 쓰는가
- [ ] `priority` 를 값이 바뀔 때만 대입하는가
- [ ] `Path.combine` 이 매 프레임 호출되지 않는가 (파츠 조립 시 1회 + 캐싱)
- [ ] 블러 반경에 상한이 있는가
- [ ] 무기·장비를 `BakedPart` 로 굽는가
- [ ] 정지/원거리 NPC 를 N프레임마다 갱신하는가
- [ ] `Picture` 를 `dispose` 하는가
- [ ] 조명 변경 시 캐시를 무효화하는가
- [ ] 20+ 액터 씬에서 아틀라스로 전환하는가
- [ ] `--profile` 모드에서 raster thread 를 실측했는가
