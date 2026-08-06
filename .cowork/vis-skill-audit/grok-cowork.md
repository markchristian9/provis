<!-- cowork:grok | 2026-08-06 15:21:26 | exit=0 | 696s -->
# grok 분석 — vis-skill-audit

> 요청: vis 스킬을 분석하여, Flutter Flame 으로 2.5d isometric 게임의 pc/mob 을 잘 생성할 수 있도록, 멋지고 예쁜 AAA 급 pc/mob 비주얼 디자인을 할 수 있도록 되어져 있는지 분석 후, 수정보완 할 내용이 있으면 수정보완해주세요. 참고: 폴더 이름 abc 를 vis 로 변경했습니다.

[분석 대상] .claude/skills/vis/ 스킬 문서 일체 — SKILL.md(188줄), references/{architecture,isometric,shading,silhouette,procgen,animation,performance}.md(7개, 약 2845줄), assets/iso.dart(248줄).
[대조 자료] 실제 구현 코드 lib/ (약 13400줄) — 특히 이미 완성된 PC 4종(art/pc/aldric,kaelen,lyra,seraphine)과 Mob 4종(art/mob/gorehide,vaelmorth,mourne,chitinis), 렌더 파이프라인(render/surface.dart, core/shading.dart, render/iso.dart).
[핵심 질문] 이 스킬 문서만 읽은 AI 가 실제로 AAA 급 2.5D 아이소메트릭 PC/Mob 을 만들어낼 수 있는가? 못 만든다면 무엇이 빠졌거나 틀렸는가? 문서와 실제 코드가 어긋난 곳은 어디인가?
> 생성: 2026-08-06 15:21:26 · 소요 696s · 읽기 전용 분석(작업공간 미수정)

---



## 1. 결론 요약

**스킬 문서만 따른 AI는 동작하는 2.5D 아이소 휴머노이드(시드→`HumanoidSpec`→`HumanoidRenderer`)는 만들 수 있어도, 현재 저장소 갤러리 PC/Mob이 보여 주는 “핸드 아트 AAA” 수준은 재현하지 못한다.**  
근거는 진입점 불일치다. 완성 작품 9종(PC 5+Mob 4)은 전부 `Artist` + 계보 B(`core/shading.dart`의 `Finish`/`drawEye`/`rimBand`/`castShadow` 등)인데, `SKILL.md` 6단계 워크플로우는 `HumanoidSpec.generate`와 계보 A(`render/*`)를 정답 경로로 가르친다.  
절차 교재로서의 품질(아이소 수식, 원형 다이얼, 9패스, Rng.branch)은 높지만, **문서가 필수로 적은 `paintContactShadow` 5곳은 코드 전역에서 호출 0회**이고, `Facing.lerp`·`MonsterRole`·`shapeBias`·별도 `actor_component.dart`는 문서 전용이다.  
수정보완은 코드 merge가 아니라 **이중 트랙 강제 분기 + 계보 B 최소 레시피 + 체크리스트·메타·허위 API 정합**이 먼저다. (직접 수정하지 않음 — 권고만 §5.)

## 2. 근거

- `lib/src/art/roster.dart:17-30` — `heroes` 5명(Aldric…**Vesper**)+`monsters` 4명. cowork/분석 프롬프트의 “PC 4종”과 불일치.
- `lib/src/art/pc/aldric.dart:6-7,55-61,69-74` — 완성 PC는 `core/shading.dart` import, `Surface(..., Finish.metal)`, `paint` 하드코딩. 계보 A 미사용.
- `lib/src/art/mob/gorehide.dart:7-10,14-17,61-70,77-90` — Mob도 계보 B; 머리 2/3·어깨 5배 등 **비율 왜곡**이 아트 디렉션 핵심.
- `lib/src/art/mob/vaelmorth.dart:14-17,65-80` — 용은 단일 spine+두께 곡선; 절차 휴머노이드 확장만으로는 동일 품질이 안 나옴.
- `lib/src/art/anatomy.dart:12-15,115-119` — “자동 인체 시스템을 **일부러 만들지 않았다**”; 눈은 **6겹**이 살아 있는 눈의 조건.
- `lib/src/art/creature.dart:11-14,43-53` — `kStage` 1000×1400, 캐릭터별 `LightRig`, `Artist.paint` 초상 좌표계.
- `.claude/skills/vis/SKILL.md:1-3,63-77,88-93` — frontmatter `name: abc`; 워크플로우 2단계=`HumanoidSpec.generate`만; 4단계는 “접촉 그림자 5곳” 필수.
- `.claude/commands/def.md:1-10` — `../skills/abc/SKILL.md` 참조(폴더는 `vis`).
- `lib/src/actor/humanoid_renderer.dart:117-154,565-595` — 아이소·`paintTopPlane`·접지 그림자 구현; 눈은 gem blob+동공 점; **`paintContactShadow` 호출 없음**(대신 `occlusion` 인자 다수 사용).
- 저장소 전역 검색 — `paintContactShadow` **정의만** `lib/src/render/surface.dart:503-520`, **호출 0회**.
- `lib/src/core/shading.dart:16-30,169-178,807-847` vs `lib/src/render/light.dart:14-46` — 계보 B `dir`=키라이트를 **보는** 방향 / 계보 A `keyDir`=빛이 **진행하는** 방향, `keyAlign` 부호 규약 반대 축.
- `.claude/skills/vis/references/architecture.md:72-82,153-179,363-372` — 계보 A/B 공존 경고·표는 있음; 데이터 흐름·“새 액터 절차”는 **A 전용**, `art/` 제작 레시피 없음.
- `.claude/skills/vis/references/isometric.md:132` / `silhouette.md:46-54` / `procgen.md:388` / `performance.md:56-71` — 문서 전용: `Facing.lerp`, `shapeBias`, `MonsterRole`, `actor_component.dart`(실제 `ActorComponent`는 `lib/main.dart:225`).
- `lib/entry.dart:5-9` vs `lib/main.dart:19-28` — 갤러리 엔트리 vs 절차 액터 뷰어 **이중 진입점**.

## 3. 상세 분석

### 3.1 범위와 권위

| 영역 | 실제 권위 | 스킬이 가르치는 것 |
|------|-----------|-------------------|
| 갤러리/대치 UI 비주얼 | `art/pc|mob/*` + `core/shading` + `anatomy` | 디렉토리 이름·계보 경고 수준 |
| 인게임 아이소 액터 | `HumanoidSpec` + `humanoid_renderer` + `render/*` + `rig/*` + `anim/*` | 워크플로우·체크리스트 거의 전부 |
| 목표 “AAA” | 저장소 증거상 **핸드 아트(B)가 상한** | 절차 체크리스트로 대체 |

분석 대상은 **스킬이 AI를 올바른 진입점으로 이끄는가**다. 절차 렌더러 실기 미학은 코드만으로 최종 판정하지 않는다.

### 3.2 이중 파이프라인 (핵심)

```
[트랙 A — 절차/인게임]                    [트랙 B — 작품/초상]
seed → HumanoidSpec → Body/Pose/solve     Artist.paint(t) 하드 포즈
     → Path → paintSurface A                   → Path + paintSurface B
     → IsoView squash, 8 facing                → kStage, 단일 3/4
main.dart 뷰어                               entry.dart 로스터
```

- **트랙 A 문서화**: 우수 — 접지점만 투영, `wx+wy` depth, `Rng.branch`/`bell`, 원형 비겹침 대역, 9패스·`paintTopPlane`.
- **트랙 B 문서화**: architecture에 `art/`·계보 B 존재 경고는 있다. 그러나 **공개 API 맵·6단계 워크플로우·체크리스트·참고 캐릭터 레시피가 없다.** 1차의 “한 줄뿐”은 과장이었고, “제작 경로 부재”가 정확한 표현이다.

`anatomy.dart`의 “자동 인체 금지” 선언과 `HumanoidSpec` 철학은 정면 충돌한다. 스킬이 이 긴장을 설명하지 않으면 AI는 A로 “새 보스”를 찍어 **형제 같은 평균 실루엣**을 만든다 — anatomy가 피하려던 실패.

### 3.3 AAA 정의의 층위 (1차보다 정교화)

스킬 본문의 AAA 정의는 “조명 일관 · 재질 구분 · 실루엣 판독”이다(`SKILL.md:12-13`).  
**이 정의의 일부**는 트랙 A 문서+코드로 도달 가능하다(공유 `LightRig`, `SurfaceKind` 프리셋, 원형 대역, squint 48px).  

그러나 질문의 “멋지고 예쁜 / 저장소 PC·Mob 급”은 다음을 추가로 요구한다:

1. 파츠 분할 금속 밴딩 (`aldric` 주석 철학)  
2. 종 단위 비율 왜곡 (`gorehide`) / 단일 spine 유기체 (`vaelmorth`)  
3. `drawEye` 6겹 vs 절차 gem 눈 / 문서 4겹(`silhouette.md:286`)  
4. `rimBand`·`panelLine`·`castShadow`·`occlude` 후처리  
5. 캐릭터 전용 무드 조명·한 줄 이펙트(후광, 파리, 모트 등)  
6. `kStage` 초상 구도  

이것들은 **코드에만** 있고 스킬 워크플로우에 없다. 따라서 “문서만으로 갤러리급 AAA”는 **불가**가 맞고, “문서만으로 스킬 정의 AAA 전항 충족”도 **체크리스트 허위 항목 때문에 신뢰 불가**다.

### 3.4 계보 A vs B: 섞으면 명암 반전

| | 계보 A `render/` | 계보 B `core/shading.dart` |
|--|------------------|----------------------------|
| 방향 | `keyDir` = 진행 | `dir` = 광원을 보는 방향 |
| 재질 | `SurfaceKind`+roughness/metalness | `Finish`+contrast/sss |
| `paintSurface` | quality/occlusion/detailSeed | detail/seed/rim/ao |
| 사용처 | `humanoid_renderer` (+main) | **모든 PC/Mob Artist** |

architecture 주의 ①은 공존을 경고하지만, SKILL 4단계가 “`render/` 또는 `core/shading`”으로만 얼버무려 **산출물 타입 → import 계보** 매핑이 없다.

### 3.5 체크리스트 vs 코드 (1차 보강)

| 문서 필수 | 실제 |
|-----------|------|
| 접촉 그림자 5곳 `paintContactShadow` | **전역 호출 0**. A는 `occlusion` 수치로 부분 대체 |
| 눈 4겹(실루엣 문서) / 6겹(anatomy) | 절차 눈=gem blob; 갤러리=`drawEye` 6겹 |
| 씬 단일 `LightRig` (규칙 7) | 초상 트랙은 캐릭터별 `light` getter가 의도 |
| `Facing.lerp` | 없음. `lerpAngle`은 `rig/ik.dart`·SKILL 6단계에 존재 |
| `actor_component.dart` | 없음. `main.dart` 인라인 |

즉 A 경로도 “문서 체크리스트 통과 = 구현 완료”가 성립하지 않는다.

### 3.6 아이소 특수성

- 아이소 규칙 자체(접지 타원, squash 1회, top plane, 8방향 near/far)는 문서 A·`humanoid_renderer`·`main`에 **일관**.
- 완성 PC/Mob의 `groundShadow(..., rx, ry)`는 **초상용 납작 타원**이지 2:1 아이소 접지 규약이 아님.
- **트랙 간 이식 가이드 없음** → B 품질을 아이소 액터에 옮기려면 좌표계·8방향·공유 조명·Pose를 전면 재설계해야 한다.

### 3.7 절차 생성 장치

강점: `spec.dart` 원형 다이얼·`branch(11)` 팔레트·`bell` 대역 비겹침·시드24 검증 서술이 실행 가능에 가깝다.  
약점: `MonsterRole`/`shapeBias`/모듈 파츠는 문서 설계뿐; 실제 Mob 4종은 100% 수작업; 성별·헤어 스타일 축이 Spec에 빈약 → lyra/seraphine/vesper급 개성을 절차로 못 냄.

### 3.8 메타·실행 가능성

- `name: abc` + `def` → `skills/abc` : 리네임 미완료 → 스킬/커맨드 로딩 실패 위험.
- shading.md는 **계보 A 전용 완전 참조**; 계보 B API(`rimBand` 등)는 스킬 체계 밖.
- `assets/iso.dart`는 `lib/src/render/`에 복사 전제(상대 import). `Facing.label`은 번들에만 있는 미세 차이.

### 3.9 스킬 정체성 긴장 (1차가 약하게 둔 가설)

스킬 description은 “**절차적** 코드로 생성”을 명시한다. 트랙 B를 유일한 정답으로 올리면 스킬 목적과 충돌한다.  
올바른 수정은 **“B만 문서화”가 아니라 “목표별 진입점 강제”**: 갤러리 작품=B, 인게임 시드 액터=A, 이식은 별도 절.

## 4. 리스크 · 함정

- **최대 함정**: AI가 스킬만 보고 `HumanoidSpec` 변종을 양산 → 로스터 품질 붕괴 + anatomy 철학 위반.
- **조명 규약 혼동**: A/B `dir` 부호 반대 → 전신 명암 반전. SKILL 실수 표에 항목은 있으나 **어느 LightRig인지** 불명.
- **“접촉 그림자 필수” 문서 vs 호출 0**: 체크리스트 통과 보고가 시각 품질을 보장하지 않음.
- **허위 API 복사** (`Facing.lerp`, `MonsterRole`, `shapeBias`, 잘못된 파일 경로) → 컴파일 실패 루프.
- **초상→인게임 이식 비용**: 8방향·Pose·공유 LightRig 부재 시 전면 재작성.
- **계보 성급 통합**: 완성 9캐릭터 재작업. 문서 경계가 당분간 더 안전.
- **이름 `abc`/`vis` 잔여물**: 스킬 미로딩 시 이후 분석·생성 작업 전체가 무의미.
- **아틀라스/임포스터 조기 최적화**: performance 문서에 있으나 실전 맵 루프 미연결.

## 5. 권고안

| 순위 | 권고 | 범위 | 근거 | 리스크 |
|---|---|---|---|---|
| 1 | **SKILL 최상단 “이중 트랙·진입점”**: 목표=갤러리/초상 → `Artist`+`core/shading`+`anatomy`+`roster` / 목표=인게임 아이소 액터 → `HumanoidSpec`+`render/*`+`humanoid_renderer`. 절대 규칙 7(공유 LightRig)에 **“인게임 씬” 한정** 주석. | SKILL.md | roster·entry vs main, anatomy:12-15 | 분량↑; 경로 오용 급감 |
| 2 | **메타 정합 즉시**: `name: vis`, `def.md`→`../skills/vis/SKILL.md`, 본문 `abc` 잔여 제거; cowork-prompt PC **5종(Vesper)** 반영. | SKILL, def, cowork | frontmatter:1-3, def:10, roster:17-23 | 낮음 |
| 3 | **계보 A/B 대조표**를 architecture 맨 위 고정: 필드·방향 의미·`paintSurface` 인자·import·사용 파일. “수정 파일이 import하는 쪽만”. B 진입점=`paintSurface`+`rimBand`/`castShadow`/`occlude`/`drawEye` 한 줄씩. | architecture.md | light.dart vs shading.dart | 통합 전 필수 |
| 4 | **트랙 B 최소 레퍼런스**(`references/artist-craft.md` 권장, ≤1파일): `kStage`/`kGround`, roster 한 줄, `drawEye` 6겹, `rimBand`/`panelLine`/`castShadow`/`occlude`, 파츠 분할 금속, 비율 왜곡, 단일 spine. 템플릿 인용은 **aldric·gorehide·vaelmorth** 헤더+paint 골격만. | 신규 참조+SKILL 링크 | art/* 패턴 | 분량↑; 복붙 방지 위해 “비율 철학 먼저” |
| 5 | **문서 전용 API 처리**: `Facing.lerp`→`lerpAngle` 예시로 교체; `MonsterRole`/`shapeBias`에 **「미구현 설계」** 라벨 또는 삭제; `actor_component.dart`→`main.dart:ActorComponent`. | isometric/procgen/silhouette/performance | 검색 결과 | 환각 감소 |
| 6 | **체크리스트 트랙 분기 + A 동기화**: B=6겹 눈·rimBand·파츠 분할·초상 그림자; A=`occlusion` 실사용·`paintTopPlane`·48px·시드24. **`paintContactShadow` 5곳은 “권장/미호출”로 강등**하거나 코드에 호출을 추가(문서만 필수 유지 금지). | SKILL 체크리스트·shading.md:449 | surface:503 호출 0 | 문서 낮추기 vs 구현 따라잡기 선택 |
| 7 | **트랙 간 이식 1페이지**: Artist→Body/Pose 시 좌표계·공유 LightRig·8방향; 시드 캐릭터→초상 시 디테일 상한. | SKILL 또는 architecture | 규칙7 vs creature:43-44 | 설계 합의 필요 |
| 8 | **절차 몬스터 정책 택일**: `MonsterSpec`+역할 enum을 코드·문서 동시 도입 **또는** procgen “확장 패턴”을 **핸드 아트 필수**로 강등. 중간 상태 유지 금지. | procgen | Mob 전부 수작업 | 정책 공백이 최악 |
| 9 | **A 품질 상한 명시**: 인게임 48px 판독 목표와 갤러리 초상 목표를 분리해 “AAA” 단어를 트랙별로 정의. 스킬 description의 “절차적 AAA”와 갤러리 기대치를 문장으로 구분. | SKILL Overview | 정의 혼선 | 기대 관리 |
| 10 | (후순위) 계보 코드 통합은 **아트 디렉션 합의 후**. 당분간 문서 경계 > merge. | 코드 전략 | 완성작 전부 B | 고비용 |

오케스트레이터 적용 순서 권장: **2 → 1 → 3 → 6 → 5 → 4**.

## 6. 불확실 · 미확인

- 절차 `HumanoidRenderer`의 **실기 스크린샷/플레이 체감** AAA 여부는 코드 리딩만으로 단정 불가. 구조상 디테일 상한은 B보다 낮아 보임 `[판단]`.
- `vesper.dart`(1224줄) 장비·이펙트 전수 패턴은 헤더·검색 위주 — 스킬에 탱크/호스 등 특수 레시피가 더 필요한지 미확인.
- Flame 실전 맵(다중 액터 전투)·performance 예산표 실측·웹 Impeller 비용 미확인.
- 제품 방향: A=미래 본선 / B=쇼케이스 인지, 반대인지 — cowork-prompt는 스킬 감사를 요청할 뿐 최종 제품 방향을 고정하지 않음 → **사람 결정 필요**.
- anim/library 전 클립 품질, 테스트 스냅샷 픽셀 회귀 범위는 본 감사 밖.

## 7. 자기 비판으로 바로잡은 것

- 🔁 수정: “architecture에 트랙 B가 **한 줄**뿐” → “**디렉토리·계보 공존 표는 있음**. 없는 것은 B 제작 워크플로우·공개 API·체크리스트·레시피”. 이유: `architecture.md:62-82`.
- 🔁 수정: “`paintContactShadow`가 humanoid_renderer에서 0” → “**저장소 전역 호출 0** (정의만 존재). 다만 A 경로는 `occlusion`으로 부분 대체 중이라 ‘깊이 장치 전무’는 과장”. 이유: `surface.dart:503` 유일 히트, `humanoid_renderer` occlusion 다수.
- 🔁 수정: “문서만으로 AAA 절대 불가”의 단정 → “**갤러리급/핸드 아트 AAA 불가** + **스킬 자체 정의 AAA도 체크리스트 허위로 검증 불가**”. 층위를 나눔.
- 🔁 수정: “PC 4종 vs 문서” 프레임 → 실제 불일치는 **roster 5종(Vesper) vs cowork/SKILL 관행 4종**. 스킬 본문이 4종을 세지는 않음; cowork-prompt:12가 4종으로 적혀 있음.
- ❌ 철회: “assets/iso.dart vs lib iso.dart가 거의 동일·번들 양호”만 강조한 뉘앙스 — `Facing.label`은 **assets에만** 존재(`assets/iso.dart:86`). 미세 드리프트 사실을 약하게 씀.
- ➕ 추가: 스킬 description의 **절차 중심 정체성**과 “B를 1급으로” 권고 사이의 긴장 — 권고를 “B 단독 정답”이 아니라 **목표별 진입점 분기**로 재정렬.
- ➕ 추가: `core/shading.dart:13` “8종 캐릭터” 주석 vs 실제 **9종** 등록.
- ➕ 추가: `paintContactShadow` 5곳 “필수”는 문서 과대광고이며, A 체크리스트 동기화가 1차 권고 6번보다 더 시급할 수 있음.
- 🔁 수정: 권고 1순위를 “이중 트랙 절” 단독에서 **메타 정합(2)을 병렬 최우선**으로 — 스킬이 로드되지 않으면 문서 개선이 무효.

**한 줄 평**: 스킬은 **우수한 절차 아이소 그래픽스 교재**이며, **현재 저장소의 갤러리 AAA PC/Mob 제작 매뉴얼은 아니다.** 후자가 목표라면 트랙 B를 문서의 1급 경로로 올리고 A와 역할을 갈라야 한다.
