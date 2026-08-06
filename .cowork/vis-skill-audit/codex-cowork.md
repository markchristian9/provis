<!-- cowork:codex | 2026-08-06 15:18:51 | exit=0 | 541s -->
# codex 분석 — vis-skill-audit

> 요청: vis 스킬을 분석하여, Flutter Flame 으로 2.5d isometric 게임의 pc/mob 을 잘 생성할 수 있도록, 멋지고 예쁜 AAA 급 pc/mob 비주얼 디자인을 할 수 있도록 되어져 있는지 분석 후, 수정보완 할 내용이 있으면 수정보완해주세요. 참고: 폴더 이름 abc 를 vis 로 변경했습니다.

[분석 대상] .claude/skills/vis/ 스킬 문서 일체 — SKILL.md(188줄), references/{architecture,isometric,shading,silhouette,procgen,animation,performance}.md(7개, 약 2845줄), assets/iso.dart(248줄).
[대조 자료] 실제 구현 코드 lib/ (약 13400줄) — 특히 이미 완성된 PC 4종(art/pc/aldric,kaelen,lyra,seraphine)과 Mob 4종(art/mob/gorehide,vaelmorth,mourne,chitinis), 렌더 파이프라인(render/surface.dart, core/shading.dart, render/iso.dart).
[핵심 질문] 이 스킬 문서만 읽은 AI 가 실제로 AAA 급 2.5D 아이소메트릭 PC/Mob 을 만들어낼 수 있는가? 못 만든다면 무엇이 빠졌거나 틀렸는가? 문서와 실제 코드가 어긋난 곳은 어디인가?
> 생성: 2026-08-06 15:18:51 · 소요 541s · 읽기 전용 분석(작업공간 미수정)

---



## 1. 결론 요약

현재 `vis` 스킬만으로는 기본적인 시드 기반 아이소메트릭 휴머노이드는 만들 수 있지만, 실제 로스터 수준의 개성 있는 AAA급 PC/Mob을 안정적으로 만들 수는 없다.  
가장 큰 원인은 시드 기반 `actor/render` 파이프라인과 수작업 절차 아트인 `art/core` 파이프라인을 하나처럼 설명하면서, 실제 PC/Mob 8종이 사용하는 후자를 거의 문서화하지 않은 점이다. `lib/src/art/anatomy.dart:10-15`  
아이소 투영·접지 그림자·깊이 정렬의 기본 수식은 대체로 타당하지만, RNG 브랜치 안정성, 연속 8방향 회전, 회전 가능한 셰이딩 캐시, 성능 예산에는 명백한 오류 또는 검증되지 않은 주장이 있다.  
우선 보완할 것은 `name: vis` 정정, 두 제작 모드의 분리, `core/shading.dart` 계보 문서화, 실제 PC/Mob의 아트 디렉션 패턴 추가, 렌더-검토 반복 절차와 8방향 검증 기준의 명문화다.

## 2. 근거

- `.claude/skills/vis/SKILL.md:1-3` — 폴더는 `vis`로 바뀌었지만 frontmatter는 아직 `name: abc`다.
- `.claude/skills/vis/SKILL.md:74-105` — 공식 워크플로우는 `HumanoidSpec → 실루엣 → render 계보 → Pose → PositionComponent` 하나만 제시한다.
- `.claude/skills/vis/references/architecture.md:72-82` — 두 셰이딩 계보의 공존은 인식하지만, `shading.md`가 계보 A만 문서화한다고 명시한다.
- `.claude/skills/vis/references/architecture.md:363-372` — 새 액터 절차는 `actor/<name>_spec.dart`와 `render/<name>_renderer.dart`를 만들도록 하지만, 실제 로스터의 경로·등록 방식과 다르다.
- `lib/src/art/anatomy.dart:10-15` — 실제 고품질 아트 계층은 캐릭터가 서로 닮는 문제 때문에 범용 “인체 시스템”을 의도적으로 피하고, 비율과 포즈를 캐릭터별로 직접 정한다고 설명한다.
- `lib/src/art/creature.dart:20-53` — 실제 PC/Mob은 시드·`Body`·`Pose`가 아니라 `Artist.paint(Canvas, t, detail)` 인터페이스로 그려진다.
- `lib/src/art/pc/aldric.dart:5-17`, `lib/src/art/mob/gorehide.dart:5-18` — 실제 PC/Mob은 모두 `core/shading.dart`와 `art/anatomy.dart`를 사용하고 `Artist`를 상속한다. 다른 대상 6종도 같은 계보다.
- `.claude/skills/vis/references/shading.md:3-16` — 셰이딩 문서는 `render/surface.dart` 계보 A의 `SurfaceKind`, `Quality`, 9패스만 다룬다.
- `lib/src/core/shading.dart:86-177` — 실제 로스터가 쓰는 계보 B는 `Finish` 16종과 전혀 다른 `Surface`·`paintSurface` 시그니처를 가진다. `gold`, `fur`, `wood`, `energy`, `slime`, `membrane` 등도 계보 B에만 있다.
- `lib/src/art/pc/aldric.dart:11-16`, `lib/src/art/pc/lyra.dart:12-17`, `lib/src/art/mob/vaelmorth.dart:12-17`, `lib/src/art/mob/mourne.dart:12-17` — 완성 캐릭터는 각각 반사 분할, 긴장된 포즈 곡선, 단일 척추 흐름, 투명도 대비처럼 하나의 명확한 시각 논제를 먼저 세운다. 이 제작 단계가 스킬에는 없다.
- `.claude/skills/vis/references/architecture.md:120-123`, `lib/src/render/iso.dart:36-49` — 아키텍처 문서는 수직 높이를 `wz * TILE_H`로 쓰지만 실제 구현과 아이소 문서는 `wz * heightScale`, 즉 `tileWidth * cosθ / √2`를 쓴다.
- `lib/src/render/iso.dart:67-95`, `lib/src/actor/humanoid_renderer.dart:152-182` — “연속 yaw”라는 설명과 달리 `toCamera`·`nearSide`가 불리언/부호로 즉시 전환되고, 렌더러는 그 순간 전체 미러와 망토 순서를 바꾼다.
- `.claude/skills/vis/references/procgen.md:109-120`, `lib/src/core/rng.dart:75-77` — 문서는 `branch`가 다른 하위 시스템 변경으로부터 결과를 격리한다고 하지만, 실제 브랜치는 초기 시드가 아니라 현재 `_s`에서 파생된다.
- `.claude/skills/vis/SKILL.md:55`, `lib/src/art/pc/aldric.dart:573-585`, `lib/src/art/pc/kaelen.dart:521-536` — “다각형 금지” 절대 규칙과 달리 실제 갑옷·검날은 의도적인 직선 `Path`로 날카로운 형상을 만든다.
- `.claude/skills/vis/references/performance.md:210-215`, `lib/src/render/light.dart:128-137` — 문서는 조명이 구워진 `Picture`의 회전을 허용하지만, 실제 조명 코드는 셰이딩이 파츠와 함께 회전하면 월드 조명이 깨진다고 명시한다.
- `test/render_sheet_test.dart:66-113`, `test/snapshot_test.dart:103-129` — 렌더 시트·8방향 이미지 출력 도구는 있으나 기대 이미지와 비교하는 golden assertion은 없다. `build/snapshots/hero.png`를 직접 확인하면 현재 범용 휴머노이드 결과는 단순한 캡슐형 신체와 반복 실루엣에 머문다.

## 3. 상세 분석

**현재 저장소에는 사실상 두 제품이 공존한다.**

| 구분 | 시드 기반 아이소 액터 | 실제 고품질 로스터 |
|---|---|---|
| 진입점 | `lib/main.dart` | `lib/entry.dart` |
| 데이터 | `HumanoidSpec → Body → Pose → Skeleton` | 캐릭터별 상수·형상·시간 함수 |
| 렌더러 | `HumanoidRenderer` | `Artist.paint` |
| 셰이딩 | `render/surface.dart` 계보 A | `core/shading.dart` 계보 B |
| 방향 | `Facing` 기반 유사 8방향 | `facesLeft`에 따른 좌우 미러 한 가지 |
| 변주 | 시드 기반 | 이름 있는 캐릭터별 수작업 절차 아트 |
| 등록 | `ViewerModel` | `art/roster.dart` |

근거는 `lib/main.dart:42-80`, `lib/src/actor/humanoid_renderer.dart:46-60`, `lib/src/art/creature.dart:20-53`, `lib/src/art/roster.dart:12-30`이다. 현재 스킬은 왼쪽 파이프라인을 정답으로 가르치지만, 사용자가 대조 대상으로 지정한 PC/Mob 8종은 오른쪽 파이프라인이다. 따라서 AI가 스킬을 충실히 따를수록 실제 로스터와 다른 구조·API·품질 특성을 가진 캐릭터를 만들 가능성이 높다.

**아이소메트릭 기반은 강점이지만 완성된 8방향 시스템은 아니다.**

`IsoView`의 2:1 투영, `shadowRatio = tileHeight / tileWidth`, `depthKey = wx + wy`는 서로 일관된다. `lib/src/render/iso.dart:18-61` 다만 “연속 yaw”는 어깨 폭과 깊이 오프셋 일부만 연속이고, 얼굴/뒤통수·near/far·미러·망토 순서는 단계적으로 바뀐다. `lib/src/render/iso.dart:82-95`, `lib/src/actor/humanoid_renderer.dart:156-182` [판단] 이는 8개 고정 방향을 표시하기에는 쓸 수 있지만, 문서가 약속하는 매끄러운 중간 각도 렌더링에는 부족하다.

더 근본적으로 실제 PC/Mob 8종은 `IsoView`나 `Facing`을 받지 않는다. 같은 씬에서 `_ActorLayer`가 필요할 때 한쪽을 수평 반전할 뿐이다. `lib/src/ui/stage.dart:82-110` 따라서 현재 완성 로스터의 시각 품질을 아이소 게임용 8방향 캐릭터로 이전하는 방법이 스킬에서 가장 중요한 공백이다.

**셰이딩 문서는 실제 고품질 코드의 핵심을 놓친다.**

계보 A는 범용성과 품질 티어에 강하지만, 형상의 경계 상자에 선형·방사형 그라디언트를 배치하는 방식이다. `lib/src/render/surface.dart:226-316` 실제 표면 노멀이나 곡률 정보가 없으므로 [판단] “PBR”이라기보다 PBR 인상을 흉내 내는 아트 디렉티드 램프에 가깝다.

반면 실제 로스터의 계보 B는 재질별 전용 알고리즘을 가진다. 금속 밴드, 피부 SSS, 머리카락 이방성 띠, 키틴 이리데선스, 보석 내부 반사, 점액·막 투과를 별도로 그린다. `lib/src/core/shading.dart:186-221`, `lib/src/core/shading.dart:253-563` 하지만 스킬은 이 API와 제작 요령을 제공하지 않는다. “9패스 원리가 양쪽에 동일하다”는 설명도 정확하지 않다. 계보 B의 `paintSurface`는 파츠마다 `saveLayer`를 만들지 않고 `Finish`별 경로로 분기한다. `lib/src/core/shading.dart:165-230`

조명 규칙도 충돌한다. 스킬은 한 씬에 하나의 `LightRig`만 허용하지만 실제 `Artist`는 캐릭터마다 `light`를 소유하고, 대치 화면은 두 Artist를 같은 무대에 그린다. `.claude/skills/vis/SKILL.md:49`, `lib/src/art/creature.dart:43-47`, `lib/src/ui/stage.dart:88-110` 또한 발광체는 전역 리그 외의 국소 광원이 필요하다. Vesper는 조명탄을 그린 뒤 슈트에 반사광을 따로 돌려준다. `lib/src/art/pc/vesper.dart:1150-1205` 문서의 규칙은 “전역 환경광은 하나, 정당화된 국소 발광은 추가 가능”으로 바뀌어야 한다.

**AAA 비주얼을 만드는 아트 디렉션 단계가 빠져 있다.**

현재 문서는 원형, 삼각·사각·원 형상 언어, 6:3:1 디테일 비율을 제공한다. 그러나 실제 PC/Mob에서 품질을 결정하는 다음 항목은 충분히 다루지 않는다.

- [판단] 캐릭터마다 하나의 시각 논제를 선정하는 단계: 판금 반사 분할, 활이 만드는 삼각형, 비룡의 단일 스파인, 유령의 불투명/반투명 대비 등이 실제 사례다. `lib/src/art/pc/aldric.dart:11-16`, `lib/src/art/mob/mourne.dart:12-17`
- [판단] 제스처와 포즈를 실루엣보다 먼저 설계하는 절차: Lyra는 몸·활·시위의 긴장 곡선이 캐릭터의 핵심이다. `lib/src/art/pc/lyra.dart:12-17`
- 얼굴·표정·헤어의 상세 제작법: 문서는 눈 네 겹 한 문장뿐이지만 실제 `drawEye`는 안와, 흰자, 홍채 섬유, 동공, 각막 하이라이트, 눈꺼풀과 속눈썹까지 처리한다. `.claude/skills/vis/references/silhouette.md:282-286`, `lib/src/art/anatomy.dart:115-329`
- 투명체·막·에너지·국소 발광·입자·환경 반응: 실제 Mourne, Vaelmorth, Seraphine의 정체성을 만드는 핵심인데 계보 A의 표와 체크리스트에는 충분한 레시피가 없다. `lib/src/art/mob/mourne.dart:63-101`, `lib/src/art/mob/vaelmorth.dart:54-60`, `lib/src/art/pc/seraphine.dart:69-105`
- 결과를 렌더한 뒤 검토하고 반복하는 작업 루프: 스킬은 체크리스트는 제공하지만 실제 `render_sheet_test.dart`와 얼굴 클로즈업·축소본을 언제 어떻게 읽고 수정할지 연결하지 않는다. `test/render_sheet_test.dart:66-113`

**절차적 생성의 안정성에도 핵심 결함이 있다.**

현재 `Rng.branch`는 호출 시점의 `_s`를 사용한다. 따라서 체형 난수 호출을 앞에 하나 추가하면 이후 `r.branch(11)`의 팔레트까지 바뀐다. `lib/src/actor/spec.dart:112-168`, `lib/src/core/rng.dart:20-77` 이는 문서가 약속한 “장비 규칙을 바꿔도 체형·색이 유지된다”는 안정성을 완전히 보장하지 않는다.

또한 모든 비율에 `bell`을 기본 적용하면 극단 실패는 줄지만, 각 원형 내부의 결과가 중앙으로 몰린다. `.claude/skills/vis/references/procgen.md:104-123` [판단] 개성을 위해서는 단순한 bell 적용보다 파라미터 간 상관관계, 의도적인 대표 변형, 희귀하지만 검증된 극단형, 중복 실루엣 거부 규칙이 필요하다.

**성능 지침은 계보별로 다시 측정해야 한다.**

`saveLayer` 150회, 블러 반경 합계 3000px, 상대 비용 25–60 등의 값에는 프로젝트 내부 측정 결과가 연결돼 있지 않다. `.claude/skills/vis/references/performance.md:33-50`, `.claude/skills/vis/references/performance.md:244-258` 특히 이 모델은 파츠마다 `saveLayer`를 사용하는 계보 A에만 해당하며, 실제 로스터의 계보 B에는 적용되지 않는다. [판단] 현재 값은 합격 기준이 아니라 초기 측정 가설로 표시해야 한다.

## 4. 리스크 · 함정

- 현재 절차대로 새 PC를 만들면 `actor/<name>_spec.dart`와 `render/<name>_renderer.dart`가 생기지만, 실제 대치 UI는 `Artist`와 `art/roster.dart`만 읽으므로 캐릭터가 로스터에 나타나지 않는다. `.claude/skills/vis/references/architecture.md:363-372`, `lib/src/art/roster.dart:12-30`
- 계보 B 파일에서 문서의 `SurfaceKind`, `Quality`, `paintContactShadow`를 사용하면 API가 맞지 않는다. 반대로 계보 A에 B의 `Finish`·`occlude`를 쓰는 것도 불가능하다. `lib/src/render/surface.dart:11-22`, `lib/src/core/shading.dart:86-177`
- `LightRig.dir`은 계보 B에서 “피사체가 광원을 바라보는 방향”이고, 계보 A의 `keyDir`은 “빛의 진행 방향”이다. 두 계보를 섞으면 명암 부호가 뒤집힌다. `lib/src/core/shading.dart:29-46`, `lib/src/render/light.dart:27-51`
- 모든 다각형을 금지하면 검날·갑옷 패널·수정처럼 의도적으로 평평하고 날카로운 형상까지 둥글어져 재질과 형상 언어가 약해진다. `.claude/skills/vis/SKILL.md:55`, `lib/src/art/pc/aldric.dart:573-585`
- 현재 `branch` 구현으로 생성 순서를 바꾸면 기존 시드의 색·장비가 예기치 않게 바뀔 수 있다. `lib/src/core/rng.dart:75-77`
- 연속 yaw를 믿고 회전 애니메이션을 넣으면 정면 경계에서 전체 미러, 얼굴 표시, 망토 깊이가 순간 전환될 수 있다. `lib/src/render/iso.dart:85-95`, `lib/src/actor/humanoid_renderer.dart:156-182`
- 셰이딩된 `Picture`를 회전 재생하면 하이라이트와 그림자도 무기와 함께 회전해 월드 조명이 깨진다. `.claude/skills/vis/references/performance.md:196-214`
- 계보 A의 성능 예산을 실제 PC/Mob 계보 B에 적용하면 잘못된 병목을 최적화할 수 있다. `lib/src/core/shading.dart:183-230`
- `assets/iso.dart`를 그대로 복사하라는 지시는 현재 `lib/src/render/iso.dart`를 덮어쓸 위험이 있다. 두 파일은 이미 완전히 동일하지 않다. `.claude/skills/vis/SKILL.md:169-171`, `.claude/skills/vis/assets/iso.dart:75-86`
- “AAA”의 합격 기준이 체크박스에만 있고 기준 이미지·golden·대상 해상도별 승인 절차가 없어, AI가 스스로 합격을 선언하기 쉽다. `.claude/skills/vis/SKILL.md:111-151`

## 5. 권고안

| 순위 | 권고 | 범위 | 근거 | 리스크 |
|---|---|---|---|---|
| 1 | `SKILL.md:2`를 `name: vis`로 정정하고, 첫 단계에 “`art/**` authored roster와 `actor/**` seeded runtime 중 어느 모드인지 먼저 결정하며 두 모드의 API를 섞지 않는다”는 라우터를 추가한다. | 스킬 진입·워크플로우 | `SKILL.md:2-3`, `architecture.md:72-82` | 기존 `abc` 이름으로 호출하는 자동화가 있다면 함께 갱신 필요 |
| 2 | 제작 절차를 두 갈래로 분리한다. 로스터 모드는 `visual thesis → art/pc 또는 art/mob → core/shading → roster 등록 → render sheet`, 아이소 군중 모드는 `Spec → Body/Pose → render/surface → Facing → main viewer`로 명시한다. | 아키텍처 | `anatomy.dart:10-15`, `roster.dart:12-30` | 두 결과물의 기능 차이를 감추고 통합하려 하면 범위가 급격히 커짐 |
| 3 | `references/shading-core.md`를 추가해 계보 B의 정확한 `LightRig`, `Finish` 16종, `Surface`, `paintSurface`, `rimBand`, `glowAt`, `castShadow`, `occlude`, `groundShadow`와 실제 사용 예를 문서화한다. | 실제 PC/Mob 셰이딩 | `core/shading.dart:16-151`, `core/shading.dart:165-230` | 계보 중복을 장기 유지하면 수정 비용이 계속 증가 |
| 4 | `references/art-direction.md`를 추가하고 각 캐릭터의 필수 설계서를 “한 문장 판타지, 주 제스처, 실루엣 앵커 3개, 큰/중간/작은 형상, 명도 그룹 3개, 초점 영역, 재질 대비, 전역광, 국소광·FX, 48px 판독 요소”로 고정한다. | AAA 비주얼 설계 | `aldric.dart:11-16`, `lyra.dart:12-17`, `mourne.dart:12-17` | 템플릿을 기계적으로 채우면 캐릭터가 다시 획일화될 수 있음 |
| 5 | `Rng`에 불변 루트 시드를 저장하고 모든 `branch`를 현재 `_s`가 아닌 루트 시드에서 파생시킨다. 문서의 “branch 격리” 예제도 부모 난수 소비 전에 브랜치를 생성하도록 바꾼다. | 절차적 생성 안정성 | `rng.dart:20-77`, `procgen.md:109-123` | 기존 시드 결과가 한 번 변경되므로 마이그레이션 기준 필요 |
| 6 | 현재 `Facing`을 “고정 8방향 근사”로 정확히 표기하거나, 연속 회전을 유지하려면 미러 없는 파츠 투영·연속 깊이·얼굴 가시성 보간을 구현 지침으로 추가한다. 모든 방향×대표 포즈 시트를 합격 조건으로 둔다. | 아이소 8방향 | `iso.dart:67-95`, `humanoid_renderer.dart:152-182` | 진정한 연속 방향은 캐릭터별 후면·측면 설계 비용을 크게 늘림 |
| 7 | 아키텍처의 수직 투영식을 `screenY = … - wz * iso.heightScale`로 통일하고, `paintTopPlane`은 경계 상단 밴드 외에 명시적 `topPlanePath` 또는 파츠 노멀 프록시를 받을 수 있게 문서화한다. | 아이소·조명 정확성 | `architecture.md:120-123`, `iso.dart:36-49`, `iso.dart:107-140` | 기존 룩이 달라질 수 있어 시각 회귀 검토 필요 |
| 8 | 얼굴·헤어·투명체·에너지·입자·피격 연출을 별도 참조 절로 추가한다. 특히 `drawEye/drawNose/drawMouth/hairStrand`, Mourne의 `dstOut`, Vesper의 국소광 반사를 대표 레시피로 사용한다. | 캐릭터 마감 | `anatomy.dart:115-484`, `mourne.dart:71-99`, `vesper.dart:1150-1205` | 작은 게임 크기에서는 세부 패스를 품질 티어로 제한해야 함 |
| 9 | 성능 문서의 절대 수치를 “측정 전 가설”로 낮추고 두 셰이딩 계보를 별도로 프로파일한다. 셰이딩된 `BakedPart`의 임의 회전을 금지하고 캐시 키에 방향·조명·품질·스케일을 포함한다. | 성능·캐싱 | `performance.md:244-258`, `light.dart:128-137` | 캐시 경우의 수와 메모리 사용량 증가 |
| 10 | 체크리스트에 실제 반복 절차를 연결한다: 전신, 실루엣, 48px, 얼굴 확대, 8방향, 전 클립 핵심 위상, 조명 프리셋을 렌더하고 승인된 golden과 비교한다. `assets/iso.dart`는 복사본이 아니라 템플릿으로 표시하고 기존 파일과 diff/merge하도록 지시한다. | QA·번들 에셋 | `render_sheet_test.dart:66-113`, `snapshot_test.dart:16-20`, `SKILL.md:169-171` | 플랫폼별 래스터 차이를 허용하는 golden 정책 필요 |

`Rng.branch`의 최소 대체 구조는 다음과 같다.

```dart
class Rng {
  Rng(int seed)
      : _root = (seed == 0 ? 0x9E3779B9 : seed) & 0xFFFFFFFF,
        _s = (seed == 0 ? 0x9E3779B9 : seed) & 0xFFFFFFFF;

  final int _root;
  int _s;

  Rng branch(int salt) =>
      Rng((_root ^ (salt * 0x9E3779B9)) & 0xFFFFFFFF);
}
```

조명 절대 규칙은 다음 의미로 교체하는 것이 실제 코드와 AAA 목표에 맞다.

> 한 씬은 하나의 전역 환경 `LightRig`를 공유한다. 마법진·용암·조명탄처럼 화면에 근거가 보이는 국소 발광은 추가할 수 있지만, 발광체를 그렸다면 주변 수광 파츠에도 같은 색·세기의 반사광을 반영한다.

## 6. 불확실 · 미확인

- 읽기 전용 조건 때문에 `flutter analyze`, 테스트, 프로파일링은 실행하지 않았다. “무결점 통과”와 성능 상한은 이번 분석에서 재검증되지 않았다.
- 현재 확인 가능한 래스터 출력은 범용 `hero`·`beast` 시트와 Vesper 전신뿐이다. Aldric·Kaelen·Lyra·Seraphine 및 Mob 4종의 최신 PNG는 없어서, 이 8종의 품질 평가는 렌더 코드와 아트 설계 주석을 중심으로 했다.
- 요청과 `.cowork/cowork-prompt.md:12-13`은 PC 4종이라고 하지만 실제 로스터에는 Vesper까지 PC 5종이 등록돼 있다. `lib/src/art/roster.dart:17-23` Vesper를 새 기준 캐릭터로 포함할지 사람의 결정이 필요하다.
- “AAA급”을 판정할 기준 이미지, 목표 화면 크기별 품질선, 지원 기기·DPR·동시 액터 수·프레임 예산이 정의돼 있지 않다. 따라서 절대적인 AAA 합격 여부는 최종 아트 디렉터 검수가 필요하다.
- 두 파이프라인 중 하나를 폐기할지, 각각 다른 목적의 정식 파이프라인으로 유지할지 결정되지 않았다. [판단] 현재 자료에는 둘을 즉시 합치는 것보다 역할을 분리해 문서화할 근거가 더 강하다.
