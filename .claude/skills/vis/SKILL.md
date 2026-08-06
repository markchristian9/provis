---
name: vis
description: Flutter + Flame 으로 2.5D 아이소메트릭 게임의 AAA 급 플레이어 캐릭터와 몬스터를 코드로 생성·렌더링·애니메이션한다. 스프라이트 없이 Canvas 벡터 패스와 다패스 셰이딩으로 그린다. 다음 작업에 반드시 사용할 것 — (1) 캐릭터·몬스터·보스·NPC 를 새로 만들거나 고칠 때, (2) 실루엣·비율·체형·장비·팔레트 등 생성 규칙을 다룰 때, (3) 조명·재질·림라이트·그림자·셰이딩 패스를 손볼 때, (4) 포즈·걷기·공격·피격 클립, IK, 망토·머리카락 2차 모션을 만들 때, (5) 8방향 페이싱·아이소 투영·깊이 정렬(y-sort)·접지 그림자를 다룰 때, (6) 캐릭터 렌더 성능(saveLayer·블러·캐싱·품질 티어)을 조정할 때. 키워드 — procedural, creature, silhouette, 실루엣, shading, rim light, pose, rig, isometric, 아이소메트릭, Flame, Canvas, Artist, Finish.
---

# AAA 캐릭터/몬스터 — Flutter Flame

**스프라이트 이미지 없이, 코드만으로** 플레이어 캐릭터와 몬스터를 만든다. 목표 품질은 **AAA 급** — "캐릭터로 보이는 것"이 아니라, 조명이 일관되고 재질이 구분되며 실루엣만으로 정체가 읽히는 결과물이다.

**전제 — 협상 대상이 아니다:**
1. Flutter + Flame (`flame: ^1.38.0`), `dart:ui` Canvas 직접 렌더.
2. **게임 맵은 2.5D 아이소메트릭.** 인게임 액터는 이 뷰에 맞게 설계된다.
3. 스프라이트 시트·이미지 에셋·3D 모델을 도입하지 않는다.

---

## 🚦 먼저: 어느 트랙인가

**이 저장소에는 서로 다른 두 제작 경로가 실재한다. 무엇을 만들지부터 정하고, 두 트랙의 API 를 한 파일에서 섞지 마라.** 섞으면 조명 부호가 뒤집히고 타입이 맞지 않는다.

| | **트랙 B — 작품 캐릭터** | **트랙 A — 인게임 액터** |
|---|---|---|
| 만드는 것 | 이름 있는 간판 PC/Mob (Aldric, Gorehide…) | 시드로 찍는 군중·잡몹 |
| 진입점 | `lib/entry.dart` (로스터 갤러리) | `lib/main.dart` (액터 뷰어) |
| 계약 | `Artist` (`art/creature.dart`) | `HumanoidSpec` → `Body`/`Pose` |
| 셰이딩 | **`core/shading.dart`** — `Surface(base, Finish)`, `LightRig(dir…)` | **`render/surface.dart`** — `Surface(albedo, SurfaceKind)`, `LightRig(keyDir…)` |
| 형상 | `art/anatomy.dart` 부위 헬퍼 | `core/spline.dart` `tube`/`blob` |
| 좌표 | `kStage` 1000×1400, `kGround` 1332, 3/4 초상 | 발밑 원점 국소공간 + 아이소 투영 |
| 등록 | `art/roster.dart` | `ViewerModel` |
| 품질 상한 | **가장 높다. 현재 완성 9종이 전부 이 트랙** | 절차적 다양성이 강점, 디테일 상한은 낮다 |
| 읽을 문서 | [artist-craft.md](references/artist-craft.md) · [art-direction.md](references/art-direction.md) | [architecture.md](references/architecture.md) · [isometric.md](references/isometric.md) · [procgen.md](references/procgen.md) |

**판단 기준**: "이 캐릭터에 이름과 사연이 있는가?" → 있으면 트랙 B, 없으면 트랙 A.

두 트랙 공통 문서: [silhouette.md](references/silhouette.md) · [animation.md](references/animation.md) · [performance.md](references/performance.md).

> **주의**: `lib/src/art/anatomy.dart` 는 "캐릭터가 서로 닮는 문제 때문에 범용 인체 시스템을 **의도적으로 피했다**"고 선언한다. 트랙 B 에서 `HumanoidSpec` 을 끌어와 자동 생성하려 들면 그 철학을 정면으로 위반해 형제 같은 평균 실루엣이 나온다.

---

## 시작하기 전에

저장소가 활발히 진화 중이다. **작업 전 반드시 실제 구조를 확인한다:**

```bash
find lib -name '*.dart' | sort
grep -n "^import" <수정할 파일>     # 이 파일이 어느 계보인지 먼저 확인
```

---

## 절대 규칙

1. **트랙을 섞지 않는다.** 한 파일에서 `core/shading.dart` 와 `render/surface.dart` 를 함께 import 하지 않는다. `Surface`·`LightRig`·`paintSurface` 이름이 양쪽에 모두 있어 **조용히 잘못된 것이 잡힌다**.

2. **조명 방향 규약은 계보마다 반대다.**
   - 트랙 B `LightRig.dir` = **피사체가 광원을 바라보는 방향** (`core/shading.dart:29`)
   - 트랙 A `LightRig.keyDir` = **빛이 진행하는 방향** (`render/light.dart`)

3. **조명은 씬 단위로 일관되게.** 인게임 씬(트랙 A)은 하나의 `LightRig` 를 공유한다. 트랙 B 는 `Artist` 마다 `light` 를 소유하는 것이 **의도된 설계**다(캐릭터별 무드 조명). 어느 쪽이든 화면에 근거가 보이는 국소 발광(마법진·조명탄·용암)은 추가해도 되지만, **발광체를 그렸으면 주변 수광 파츠에도 같은 색의 반사광을 반영한다.**

4. **아이소 투영은 접지점 하나에만** (트랙 A). 몸을 아이소 평면에 투영하면 인체가 마름모로 찌그러진다. 세로 단축은 렌더 진입부에서 `canvas.scale(1, iso.squash)` **한 번**.

5. **접지 그림자 없는 액터를 만들지 않는다.** 아이소 뷰는 원근이 없어 높이와 깊이가 화면상 같은 축이다. 그림자가 없으면 점프한 캐릭터와 뒤에 선 캐릭터를 구별할 수 없다.

6. **깊이 정렬은 월드 `wx + wy` 로.** 화면 y 로 정렬하면 점프한 액터가 뒤로 밀린다.

7. **`math.Random` 금지.** 생성 경로는 `Rng(seed)` 만 쓴다.

8. **하위 시스템은 `r.branch(salt)` 로 격리** — 단, **현재 구현은 이 격리를 완전히 보장하지 않는다**(`core/rng.dart:77` 이 루트 시드가 아니라 호출 시점의 `_s` 에서 파생). 시드 안정성이 중요하면 **부모 난수를 소비하기 전에** 브랜치를 먼저 만들어라. 상세: [procgen.md](references/procgen.md).

9. **원형을 먼저 뽑고 그 대역 안에서만 변주한다** (트랙 A). 파라미터를 각각 독립 무작위화하면 "특징 없는 평균"만 나온다.

10. **파츠 하나 = `paintSurface` 한 번.** 개별 패스를 호출부에서 재조합하지 않는다.

11. **그림자는 차갑게, 하이라이트는 따뜻하게.** 검정과 섞으면 진흙색이 된다. 색은 전부 HSL 에서 조작한다.

12. **유기체는 스플라인으로, 인공물은 직선을 허용한다.** 살·근육·천·촉수는 `smoothClosedPath`/`tube`/`blob` 을 거친다 — 곡률이 끊기면 값싸 보인다. 반대로 **갑옷 패널·검날·결정·기계 부품은 의도적인 직선 `Path`(`lineTo`)가 옳다** — 전부 둥글리면 재질과 형상 언어가 약해진다. 실제로 `art/pc/aldric.dart` 는 갑옷에 `lineTo` 를 6회 쓰고, `art/mob/*.dart` 4종은 한 번도 쓰지 않는다.

13. **`Pose` 에 절대 좌표를 넣지 않는다** (트랙 A). 관절 각도와 키 대비 비율만.

14. **Flame 을 import 하는 파일에서 `mix` 이름이 충돌한다.** `import '...palette.dart' as pal;` 또는 `import 'package:flame/components.dart' hide mix;`.

---

## 워크플로우 B — 작품 캐릭터 (현재 품질 상한)

### 1. 시각 논제를 한 문장으로 정한다

**이 단계를 건너뛴 캐릭터는 반드시 평범해진다.** 완성 9종은 전부 논제가 먼저 있었다 — "판금의 반사 분할"(Aldric), "머리 2/3·어깨 5배의 압도"(Gorehide), "몸·활·시위가 만드는 긴장 곡선"(Lyra), "단일 스파인으로 흐르는 용"(Vaelmorth), "불투명과 반투명의 대비"(Mourne).
→ [art-direction.md](references/art-direction.md)

### 2. `Artist` 를 구현한다 (`lib/src/art/pc/` 또는 `art/mob/`)

`id`·`name`·`title`·`blurb`·`camp`·`sex`·`accent`·`light`·`moodSky`·`framing` + `paint(Canvas, double t, {double detail})`.
좌표는 `kStage`(1000×1400), 발바닥은 `kGround`(1332). 같은 `t` 에는 언제나 같은 그림이 나와야 한다.

### 3. 부위를 조립한다

`art/anatomy.dart` 의 `headShape`/`torsoShape`/`limb`/`handShape`/`bootShape`/`hairStrand`/`clothSpine`.
얼굴은 `drawEye`(6겹)·`drawBrow`·`drawNose`·`drawMouth`.
→ [artist-craft.md](references/artist-craft.md)

### 4. 칠한다 (`core/shading.dart`)

`Surface(color, Finish.xxx)` + `paintSurface(c, path, s, l, detail:, seed:)`.
마무리 4종이 품질을 결정한다 — `occlude`(겹친 파츠 접촉), `castShadow`(파츠 아래 그림자), `rimBand`(실루엣을 정확히 훑는 림), `panelLine`(갑옷 패널 경계).
→ [artist-craft.md](references/artist-craft.md)

### 5. 로스터에 등록한다

`lib/src/art/roster.dart` 의 `heroes` 또는 `monsters` 에 추가. **등록하지 않으면 갤러리에 나타나지 않는다.**

### 6. 렌더해서 본다

`test/render_sheet_test.dart` 로 시트를 뽑아 전신·48px 축소·얼굴 확대를 확인한다.

---

## 워크플로우 A — 인게임 아이소 액터

### 1. 원형을 정한다
"멀리서 봤을 때 무엇으로 읽혀야 하는가?" → `Archetype`(knight/berserker/ranger/mage/assassin/paladin).

### 2. 명세를 생성한다 (`lib/src/actor/`)
`HumanoidSpec.generate(seed)` 패턴. 체형 다이얼 4개를 원형별 **겹치지 않는 대역**에서 `r.bell()` 로 뽑고, 인체 랜드마크 비율은 ±3% 이내로만 흔든다. → [procgen.md](references/procgen.md)

### 3. 실루엣을 만든다
`tube`(사지·꼬리·뿔) + `blob`(흉곽·머리) + `web`(관절 연결부).
**여기서 멈추고 검증한다** — 단색 / 48px 축소 / 시드 24개 분포. 하나라도 실패하면 셰이딩으로 넘어가지 말고 생성 규칙을 고친다. → [silhouette.md](references/silhouette.md)

### 4. 칠한다 (`render/surface.dart`)
파츠마다 `Surface` 프리셋 + `paintSurface`. 겹친 파츠에 `occlusion` 인자(0.3~0.6). 어깨·투구에 `paintTopPlane`. 접지 그림자는 예외 없음. → [shading.md](references/shading.md)

### 5. 움직인다 (`lib/src/anim/`)
정지 상태에도 호흡을 넣는다. 공격은 **예비 35% / 타격 12% / 회복 53%** 비대칭 타이밍. → [animation.md](references/animation.md)

### 6. 씬에 놓는다
`PositionComponent.render(Canvas)` 오버라이드. `priority` 를 `wx + wy` 로 갱신. → [isometric.md](references/isometric.md) · [performance.md](references/performance.md)

---

## AAA 품질 체크리스트

**실루엣** (공통)
- [ ] 검게 칠했을 때 정체가 구분되는가
- [ ] 48px 로 축소해도 구분되는가
- [ ] 상단 실루엣(뿔·투구·어깨)에 개성이 있는가
- [ ] 큰 도형 1 + 중간 2~3 + 작은 여럿의 크기 위계가 있는가

**셰이딩 — 트랙 B**
- [ ] `Finish` 를 재질에 맞게 골랐는가 (16종 중)
- [ ] 겹친 파츠에 `occlude` 를 넣었는가 — 없으면 파츠가 종이처럼 겹쳐 보인다
- [ ] 시선이 머무는 곳(얼굴·어깨·무기날)에 `rimBand` 를 썼는가
- [ ] 갑옷에 `panelLine` 이 있는가
- [ ] `groundShadow` 로 바닥에 붙였는가
- [ ] 눈이 6겹인가 (`drawEye`) — 눈 하나가 캐릭터의 생사를 가른다

**셰이딩 — 트랙 A**
- [ ] 씬의 모든 액터가 같은 `LightRig` 를 쓰는가
- [ ] 겹친 파츠에 `occlusion` 인자를 주었는가
- [ ] 어깨·투구에 `paintTopPlane` 을 적용했는가
- [ ] 림라이트가 캐릭터를 배경에서 떼어내는가

**아이소** (트랙 A)
- [ ] 접지 그림자가 2:1 타원인가
- [ ] `canvas.scale(1, squash)` 가 한 번만 적용됐는가
- [ ] 8방향을 모두 돌렸을 때 near/far 사지 순서가 뒤집히는가
- [ ] `priority` 가 월드 `wx + wy` 인가

**애니메이션** (공통)
- [ ] 정지 상태에 호흡이 있는가
- [ ] 좌우 팔다리에 위상차가 있는가 (완전 대칭 = 마네킹)
- [ ] 공격 타이밍이 비대칭인가

**분포** (트랙 A)
- [ ] 시드 24개가 서로 구별되는가
- [ ] 기괴한 극단값이 없는가 (`range` 대신 `bell`)
- [ ] 같은 시드가 여전히 같은 결과를 내는가

---

## 참조 문서

| 문서 | 트랙 | 언제 읽는가 |
|------|------|------------|
| [artist-craft.md](references/artist-craft.md) | B | `Artist` 계약, `Finish` 16종, `core/shading.dart` 공개 API, `anatomy.dart` 부위 헬퍼, 얼굴 6겹 |
| [art-direction.md](references/art-direction.md) | B | 시각 논제 설계, 비율 왜곡, 완성 9종의 실제 논제, 캐릭터 설계서 양식 |
| [architecture.md](references/architecture.md) | 공통 | 레이어 규약, 좌표계, 계보 대조표, Flame 이름 충돌 |
| [isometric.md](references/isometric.md) | A | 아이소 투영 수식, 8방향 페이싱, y-sort, 접지 그림자 |
| [silhouette.md](references/silhouette.md) | 공통 | 형상 언어, `tube`/`blob`/`web`, 두께 프로파일, squint test |
| [shading.md](references/shading.md) | A | 계보 A 9패스 전체 소스, 재질 파라미터 표 |
| [procgen.md](references/procgen.md) | A | `Rng`/`Noise`/`Palette`, 원형 다이얼, 인체 비율표 |
| [animation.md](references/animation.md) | 공통 | `Pose`/`solve`/IK/베를레, 클립 레시피, 타이밍 표 |
| [performance.md](references/performance.md) | 공통 | 비용 표, Flame 통합, 품질 티어, 캐싱 |

## 번들 에셋

[assets/iso.dart](assets/iso.dart) — `IsoView`·`Facing`·`paintTopPlane`·`paintIsoGroundShadow`·`paintImposter`·`BakedPart`·`qualityFor` 의 **템플릿**이다.

⚠️ `lib/src/render/iso.dart` 가 **이미 존재하며 이 템플릿과 다르다**. 통째로 복사하지 말고 diff 후 필요한 부분만 병합하라.

```bash
diff .claude/skills/vis/assets/iso.dart lib/src/render/iso.dart
```

---

## 자주 하는 실수

| 증상 | 원인 | 처방 |
|------|------|------|
| 타입이 안 맞거나 명암이 뒤집힘 | 두 계보를 섞음 | 파일의 import 를 보고 한 계보만 |
| 캐릭터가 지면에서 떠 보인다 | 접지 그림자 없음 / 원형 그림자 | 트랙 B `groundShadow`, 트랙 A 2:1 타원 |
| 파츠가 종이처럼 겹쳐 보인다 | 접촉 그림자 없음 | 트랙 B `occlude`+`castShadow`, 트랙 A `occlusion` 인자 |
| 인체가 마름모로 찌그러짐 | 몸까지 아이소 투영 | 투영은 접지점만 |
| 새 캐릭터가 갤러리에 안 나온다 | `roster.dart` 미등록 | `heroes`/`monsters` 에 추가 |
| 생성 결과가 전부 비슷하다 | 원형 대역이 겹침 / 시각 논제 부재 | 대역 분리 / 논제 먼저 |
| 난수 하나 추가했더니 색이 다 바뀜 | `branch` 가 `_s` 기반 | 부모 난수 소비 전에 브랜치 생성 |
| 무릎이 반대로 꺾인다 | `knee` 가 음수 | `math.max(0, ...)` |
| 망토가 폭발한다 | `dt` 미클램프 / `teleport` 누락 | `min(dt, 1/30)`, 스폰 시 teleport |
| `ambiguous_import: mix` | Flame 의 vector_math 충돌 | `as pal` 또는 `hide mix` |
