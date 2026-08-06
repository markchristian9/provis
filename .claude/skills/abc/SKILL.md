---
name: abc
description: Flutter + Flame 으로 2.5D 아이소메트릭 게임의 AAA 급 플레이어 캐릭터와 몬스터를 절차적 코드로 생성·렌더링·애니메이션한다. 스프라이트 없이 Canvas 벡터 패스와 다패스 셰이딩으로 그린다. 다음 작업에 반드시 사용할 것 — (1) 캐릭터·몬스터·보스·NPC 를 새로 만들거나 고칠 때, (2) 실루엣·비율·체형·장비·팔레트 등 절차적 생성 규칙을 다룰 때, (3) 조명·재질·림라이트·그림자·셰이딩 패스를 손볼 때, (4) 포즈·걷기·공격·피격 클립, IK, 망토·머리카락 2차 모션을 만들 때, (5) 8방향 페이싱·아이소 투영·깊이 정렬(y-sort)·접지 그림자를 다룰 때, (6) 캐릭터 렌더 성능(saveLayer·블러·캐싱·품질 티어)을 조정할 때. 키워드 — procedural, creature, silhouette, 실루엣, shading, rim light, pose, rig, isometric, 아이소메트릭, Flame, Canvas.
---

# 절차적 AAA 캐릭터/몬스터 — Flutter Flame

## 이 스킬이 다루는 것

**스프라이트 이미지 없이, 코드만으로** 2.5D 아이소메트릭 게임의 플레이어 캐릭터와 몬스터를 만든다. 시드 하나에서 체형·장비·색이 나오고, 벡터 패스로 실루엣을 만들고, 다패스 셰이딩으로 칠하고, 관절 각도로 움직인다.

목표 품질은 **AAA 급**이다. "그럭저럭 캐릭터로 보이는 것"이 아니라, 조명이 일관되고 재질이 구분되며 실루엣만으로 정체가 읽히는 결과물이다.

**전제 세 가지 — 협상 대상이 아니다:**
1. Flutter + Flame (`flame: ^1.38.0`), `dart:ui` Canvas 직접 렌더.
2. **게임 맵은 항상 2.5D 아이소메트릭.** 모든 캐릭터가 이 뷰에 맞게 설계된다.
3. 같은 시드는 언제나 같은 캐릭터를 만든다.

---

## 시작하기 전에

저장소가 활발히 진화 중이다. **작업 전 반드시 실제 구조를 확인한다:**

```bash
find lib -name '*.dart' | sort
```

특히 셰이딩 계보가 둘(`render/surface.dart` vs `core/shading.dart`)이므로, **수정하려는 파일이 이미 import 하는 쪽을 따른다.** 자세한 것은 [references/architecture.md](references/architecture.md).

---

## 절대 규칙

어기면 품질이 무너지거나 시스템이 깨진다. 각 규칙의 "왜"를 함께 기억할 것.

1. **아이소 투영은 접지점 하나에만.** 캐릭터 몸을 아이소 평면에 투영하면 인체가 마름모로 찌그러진다. 지면은 눕고, 캐릭터는 그 위에 세워진 카드다. 세로 단축은 렌더 진입부에서 `canvas.scale(1, iso.squash)` **한 번**.

2. **접지 그림자 없는 액터를 만들지 않는다.** 아이소 뷰는 원근이 없어 높이와 깊이가 화면상 같은 축이다. 그림자가 없으면 점프한 캐릭터와 뒤에 선 캐릭터를 구별할 수 없다. 반드시 2:1 타원.

3. **깊이 정렬은 월드 `wx + wy` 로.** 화면 y 로 정렬하면 점프한 액터가 뒤로 밀린다.

4. **`math.Random` 금지.** 캐릭터 생성 경로는 `Rng(seed)` 만 쓴다. 재현성이 깨지면 버그를 재현할 수 없다.

5. **하위 시스템은 `r.branch(salt)` 로 격리.** 장비 생성이 체형 생성의 난수를 소비하면, 장비 규칙 한 줄 추가로 **기존 모든 캐릭터의 체형이 바뀐다.** salt 상수는 한 번 정하면 바꾸지 않는다.

6. **원형(Archetype)을 먼저 뽑고 그 대역 안에서만 변주한다.** 파라미터를 각각 독립 무작위화하면 "특징 없는 평균"만 나온다. 원형별 대역은 서로 겹치지 않아야 한다.

7. **한 씬은 하나의 `LightRig` 를 공유한다.** 액터마다 다른 조명을 주면 즉시 스티커 콜라주가 된다. `keyDir` 은 **빛이 진행하는 방향**(광원 위치가 아님).

8. **파츠 하나 = `paintSurface` 한 번.** 개별 패스를 호출부에서 재조합하지 않는다. 패스 순서가 곧 물리적 의미다.

9. **그림자는 차갑게(ambient 혼합), 하이라이트는 따뜻하게(keyColor 혼합).** 검정과 섞으면 진흙색이 된다. 색은 전부 HSL 에서 조작한다.

10. **다각형을 그대로 그리지 않는다.** 모든 실루엣은 `smoothClosedPath`/`tube`/`blob` 을 거친다. 곡률이 끊기면 아무리 잘 칠해도 값싸 보인다.

11. **`Pose` 에 절대 좌표를 넣지 않는다.** 관절 각도와 키 대비 비율만. 그래야 한 클립이 8등신 영웅과 4등신 몬스터에서 함께 재생된다.

12. **Flame 을 import 하는 파일에서 `mix` 이름이 충돌한다.** `import '...palette.dart' as pal;` 또는 `import 'package:flame/components.dart' hide mix;`.

---

## 워크플로우 — 새 캐릭터/몬스터 만들기

### 1단계. 원형을 먼저 정한다

무엇을 만들지 한 문장으로 답한다: **"멀리서 봤을 때 이 캐릭터는 무엇으로 읽혀야 하는가?"**

- 플레이어 캐릭터 → `Archetype`(knight/berserker/ranger/mage/assassin/paladin)
- 몬스터 → 위협 유형(swarm/brute/ranged/caster/elite/boss)

원형이 정해지면 **도형 편향**(▲ 공격적 / ■ 방어적 / ● 유기적)을 숫자 하나로 만들어 전 파츠에 전달한다. → [references/silhouette.md](references/silhouette.md)

### 2단계. 명세를 생성한다 (`lib/src/actor/`)

`HumanoidSpec.generate(seed)` 패턴을 따른다. 체형 다이얼 4개(등신·어깨·근육·자세)를 원형별 **겹치지 않는 대역**에서 `r.bell()` 로 뽑고, 인체 랜드마크 비율은 ±3% 이내로만 흔든다. 색은 `r.branch(11)` 로 분리한다.

→ [references/procgen.md](references/procgen.md) (원형 다이얼 표, 랜드마크 비율표, 장비 확률표, 팔레트 유도 규칙)

### 3단계. 실루엣을 만든다 (`lib/src/art/`)

`tube`(축이 있는 것: 사지·꼬리·뿔·무기) + `blob`(덩어리: 흉곽·머리) + `web`(관절 연결부)로 조립한다. 두께 프로파일이 근육과 종을 결정한다.

**여기서 멈추고 검증한다** — 전부 검게 칠하고, 48px 로 축소하고, 시드 24개를 한 화면에 띄운다. 셋 중 하나라도 실패하면 셰이딩으로 넘어가지 말고 생성 규칙을 고친다.

→ [references/silhouette.md](references/silhouette.md) (생성기 소스, 두께 프로파일 표, 부위별 레시피)

### 4단계. 칠한다 (`render/` 또는 `core/shading.dart`)

파츠마다 `Surface` 프리셋을 고르고 `paintSurface` 를 호출한다. 그린 뒤 반드시 더할 것:
- **접촉 그림자 5곳**: 턱 아래 목, 어깨보호대 아래 팔, 몸통 위 벨트, 망토 아래 다리, 투구 아래 얼굴
- **상단면 하이라이트**: 어깨·투구·어깨보호대 (아이소 전용, `paintTopPlane`)
- **접지 그림자**: 예외 없음

→ [references/shading.md](references/shading.md) (9패스 전체 소스, 재질 파라미터 표, 실패 진단표)

### 5단계. 움직인다 (`lib/src/anim/`)

`Pose` 를 시간 함수로 만든다. 정지 상태에도 호흡을 넣는다 — 아이들이 죽어 있으면 캐릭터 전체가 죽는다. 공격은 **예비 35% / 타격 12% / 회복 53%** 의 비대칭 타이밍이 타격감의 90%다. 망토·머리카락은 `VerletChain`/`ClothStrip` 에 맡기고 `carry` 를 반드시 전달한다.

→ [references/animation.md](references/animation.md) (클립 레시피, FK/IK 소스, 타이밍 표)

### 6단계. 씬에 놓는다

`PositionComponent.render(Canvas)` 를 오버라이드한다(`CustomPainterComponent` 아님). 월드 타일 좌표를 들고 있다가 렌더 시점에 투영하고, `priority` 를 `wx + wy` 로 갱신한다. 8방향 전환은 즉시 스냅하지 말고 0.15초에 걸쳐 `lerpAngle` 로 돌린다.

→ [references/isometric.md](references/isometric.md) · [references/performance.md](references/performance.md)

---

## AAA 품질 체크리스트

완성했다고 보고하기 전에 전부 확인한다. 하나라도 빠지면 "그럭저럭"에 머문다.

**실루엣**
- [ ] 검게 칠했을 때 원형이 구분되는가
- [ ] 48px 로 축소해도 구분되는가 (아이소 게임의 실제 크기)
- [ ] 상단 실루엣(뿔·투구·어깨)에 개성이 있는가 — 위에서 내려다보므로 여기가 왕이다
- [ ] 정면과 후면이 다른가
- [ ] 큰 도형 1 + 중간 2~3 + 작은 여럿의 크기 위계가 있는가

**셰이딩**
- [ ] 씬의 모든 액터가 같은 `LightRig` 를 쓰는가
- [ ] 림라이트가 캐릭터를 배경에서 떼어내는가
- [ ] 그림자에 `ambient` 가, 하이라이트에 `keyColor` 가 섞였는가
- [ ] 접촉 그림자 5곳이 들어갔는가
- [ ] 금속·천·피부가 서로 다른 재질로 읽히는가

**아이소**
- [ ] 접지 그림자가 2:1 타원인가
- [ ] `canvas.scale(1, squash)` 가 한 번만 적용됐는가
- [ ] 8방향을 모두 돌렸을 때 near/far 사지 순서가 뒤집히는가
- [ ] `priority` 가 월드 `wx + wy` 인가
- [ ] 점프 시 그림자가 접지점에 남고 작아지는가

**애니메이션**
- [ ] 정지 상태에 호흡이 있는가
- [ ] 좌우 팔다리에 위상차가 있는가 (완전 대칭 = 마네킹)
- [ ] 공격 타이밍이 비대칭인가
- [ ] 이동 속도와 걸음 주기가 동기화됐는가 (발 미끄러짐)
- [ ] 망토가 달릴 때 뒤로 날리는가 (`carry` 전달)

**분포** — 절차적 생성기는 하나가 아니라 분포를 만든다
- [ ] 시드 24개를 띄웠을 때 서로 구별되는가
- [ ] 기괴한 극단값이 없는가 (`range` 대신 `bell` 을 썼는가)
- [ ] 같은 시드가 여전히 같은 결과를 내는가

**성능**
- [ ] 프레임당 `saveLayer` 150회 이하인가
- [ ] 화면 크기로 `Quality` 티어가 자동 결정되는가
- [ ] `--profile` 모드에서 raster thread 를 실측했는가

---

## 참조 문서

필요할 때만 읽는다. 각 문서는 핵심 개념 · 핵심 로직 · 실제 소스코드를 담고 있어, 그것만 보고 해당 기능을 복구·재생성할 수 있다.

| 문서 | 언제 읽는가 |
|------|------------|
| [architecture.md](references/architecture.md) | 레이어 규약, 좌표계, 모듈 API 지도, 셰이딩 계보 구분, Flame 이름 충돌 |
| [isometric.md](references/isometric.md) | 아이소 투영 수식, 8방향 페이싱, y-sort, 접지 그림자, 아이소 전용 실루엣 규칙 |
| [silhouette.md](references/silhouette.md) | 형상 언어, `tube`/`blob`/`web` 소스, 두께 프로파일, 부위별 레시피, squint test |
| [shading.md](references/shading.md) | 9패스 전체 소스, `LightRig`/`Surface` 정의, 재질 파라미터 표, 실패 진단 |
| [procgen.md](references/procgen.md) | `Rng`/`Noise`/`Palette` 소스, 원형 다이얼 표, 인체 비율표, 몬스터 확장 패턴 |
| [animation.md](references/animation.md) | `Pose`/`solve`/IK/베를레 소스, 클립 레시피(아이들·걷기·달리기·공격·피격), 타이밍 표 |
| [performance.md](references/performance.md) | 비용 표, Flame 통합, 품질 티어, `Picture` 캐싱, 아틀라스, 프레임 예산 |

## 번들 에셋

[assets/iso.dart](assets/iso.dart) — `IsoView`, `Facing`, `paintTopPlane`, `paintIsoGroundShadow`, `paintImposter`, `BakedPart`, `qualityFor`. `lib/src/render/iso.dart` 로 복사해 쓴다. `flutter analyze` 검증 완료.

---

## 자주 하는 실수

| 증상 | 원인 | 처방 |
|------|------|------|
| 캐릭터가 지면에서 떠 보인다 | 접지 그림자 없음 / 원형 그림자 | 2:1 타원 접지 그림자 |
| 인체가 마름모로 찌그러짐 | 몸까지 아이소 투영 | 투영은 접지점만 |
| 명암이 통째로 뒤집힘 | `keyDir` 을 광원 위치로 착각 | `keyDir` = 빛의 진행 방향 |
| 파츠가 스티커처럼 떠 있다 | 접촉 그림자·AO 없음 | `paintContactShadow` + `occlusion` |
| 생성 결과가 전부 비슷하다 | 원형 대역이 겹침 | 대역 분리, 실루엣으로 검증 |
| 장비 규칙 추가했더니 체형이 다 바뀜 | `branch` 미사용 | 하위 시스템마다 `r.branch(salt)` |
| 무릎이 반대로 꺾인다 | `knee` 가 음수 | `math.max(0, ...)` |
| 망토가 폭발한다 | `dt` 미클램프 / `teleport` 누락 | `min(dt, 1/30)`, 스폰 시 teleport |
| 프레임이 무너진다 | `saveLayer` 남용 | 품질 티어 + `BakedPart` 캐싱 |
| `ambiguous_import: mix` | Flame 의 vector_math 충돌 | `as pal` 또는 `hide mix` |
