<!-- cowork:kimi | 2026-08-06 15:33:31 | exit=0 | 401s -->
# kimi 분석 — vis-skill-audit

> 요청: vis 스킬을 분석하여, Flutter Flame 으로 2.5d isometric 게임의 pc/mob 을 잘 생성할 수 있도록, 멋지고 예쁜 AAA 급 pc/mob 비주얼 디자인을 할 수 있도록 되어져 있는지 분석 후, 수정보완 할 내용이 있으면 수정보완해주세요. 참고: 폴더 이름 abc 를 vis 로 변경했습니다.

[분석 대상] /Users/thruthesky/tmp/games/vis/.claude/skills/vis/ 스킬 문서 일체 — SKILL.md(188줄), references/{architecture,isometric,shading,silhouette,procgen,animation,performance}.md(7개, 약 2845줄), assets/iso.dart(248줄).
[대조 자료] 실제 구현 코드 /Users/thruthesky/tmp/games/vis/lib/ (약 13400줄) — 특히 완성된 PC(art/pc/)와 Mob(art/mob/), 렌더 파이프라인(render/surface.dart, core/shading.dart, render/iso.dart).
[핵심 질문] 이 스킬 문서만 읽은 AI 가 실제로 AAA 급 2.5D 아이소메트릭 PC/Mob 을 만들어낼 수 있는가? 못 만든다면 무엇이 빠졌거나 틀렸는가? 문서와 실제 코드가 어긋난 곳은 어디인가?
[주의] 시간이 제한돼 있다. 파일을 전부 정독하려 하지 말고, 먼저 스킬 문서 7개의 목차와 SKILL.md 를 읽은 뒤 lib/ 의 대표 파일 3~4개만 표적 대조하라. 그리고 반드시 결론을 출력하라 — 탐색만 하다 끝나면 분석이 통째로 버려진다.
> 생성: 2026-08-06 15:33:31 · 소요 401s · 읽기 전용 분석(작업공간 미수정)

---

• 스킬 문서와 코드를 표적 대조해 감사하겠습니다.

• `SKILL.md:2` 에서 이미 첫 발견 — 폴더는 vis 로 바뀌었는데 frontmatter 는 `name: abc` 다. 계속 대조하겠습니다.

• 마지막으로 보조 함수 소속과 실제 캐릭터의 verlet 사용 여부만 확인하겠습니다.

• 

## 1. 결론 요약

  **현 상태의 스킬 문서만으로는 AAA 급 PC/Mob 을 재현할 수 없다.** 결정적 이유: 실제 쇼케이스 캐릭터 9종(PC 5종·Mob 4종)이 쓰는 제작 패턴(`Artist` 서브클래스 + 계보 B `core/shading.dart` + 고정 스테이지 수작업)이 문서 어디에도 없고, SKILL.md 의 6단계 워크플로우는 오직 `humanoid_renderer.dart` 만 쓰는 별도 파이프라인(계보 A + 시드 생성)을 가리킨다. 문서를 읽은 AI 는 Aldric 같은 캐릭터를 만들 때 **정반대 파이프라인으로, 존재하지 않는 파일 경로에, 문서화되지 않은 API 를 모른 채** 작업하게 된다. 추가로 `SKILL.md:2` 의 `name: abc`(폴더 개명 미반영), "새 액터 추가 절차"의 경로 오류, 얼굴·손·헤어 디테일 라이브러리(`anatomy.dart`)의 완전한 무 문서화가 확인됐다. 원리 문서(아이소 수식·셰이딩 이론·procgen 개념) 자체는 물리적으로 정확하고 수준 높다.

  

## 2. 근거

  - `SKILL.md:2` — frontmatter 가 `name: abc`. 폴더는 `vis/` 인데 이름이 미갱신.
  - `lib/src/art/pc/aldric.dart:5-9,17,33-38` — 실제 PC 는 `Artist` 를 상속하고 `core/shading.dart`(계보 B)를 import 하며 캐릭터 개별 `LightRig(dir:, rimDir:, rim:, bounce:)` 를 갖는다. kaelen/lyra/seraphine/vesper, mob 4종 모두 동일 패턴(import 일괄 확인).
  - `lib/src/art/creature.dart:8-13` — 고정 논리 스테이지 `kStage = Size(1000, 1400)`, `kGround = 1332`. 캐릭터는 아이소 카드가 아니라 정면 초상화로 그려진다.
  - `lib/src/art/roster.dart:20-35` — 신규 캐릭터 등록은 `roster.dart` 의 `heroes`/`monsters` 리스트. PC 는 **5종**(vesper 포함).
  - `architecture.md:363-372` — "새 액터를 추가하는 절차"가 `lib/src/actor/<name>_spec.dart`·`lib/src/anim/<name>_clips.dart`·`lib/src/render/<name>_renderer.dart`·`main.dart` 등록을 지시. 실제로는 이 경로들이 쓰이지 않는다(`lib/src/anim/`·`lib/src/render/` 에 캐릭터별 파일 없음, find 결과로 확인).
  - `grep: actor/spec importers → lib/main.dart 뿐` — SKILL.md 2단계의 `HumanoidSpec.generate` 파이프라인은 데모 한 곳에서만 사용.
  - `grep: VerletChain/ClothStrip 사용자 → lib/src/art/, lib/src/actor/ 에 0건`; `Facing/IsoView 사용자 → humanoid_renderer.dart 뿐` — animation.md 의 2차 모션·isometric.md 의 8방향 지침은 적용된 캐릭터가 없는 미사용 파이프라인 얘기다.
  - `lib/src/core/shading.dart:169,87,721-898` — 계보 B 는 자체 `paintSurface` + `Finish`(wood/energy/slime/membrane 등) + `rimBand`/`glowPath`/`glowAt`/`castShadow`/`occlude`/`inkOutline`/`panelLine`/`groundShadow` 헬퍼군을 갖춘 완전한 파이프라인. `architecture.md:82` 는 이를 "파일별 헬퍼" 한 줄로만 처리.
  - `lib/src/art/anatomy.dart:120,332,364,421,487,500,588,654` — `drawEye`/`drawBrow`/`drawNose`/`drawMouth`/`earShape`/`handShape`/`hairStrand`/`drawMotes` 등 얼굴·손·헤어 디테일 라이브러리 존재. 스킬 문서 7개 어디에도 이 API 가 없다(silhouette.md:246-302 의 부위 레시피는 몸통/사지/머리/망토/무기뿐).
  - `aldric.dart:11-16` — "판금의 매력은 반사 → 파츠를 쪼개 밴딩 차이로 금속 인상" 같은 실전 아트 디렉션 지식이 코드 주석에만 존재.
  - `assets/iso.dart:31-43` — `squash = sqrt(1-sin²θ) ≈ 0.866`, `heightScale = tileWidth·squash/√2` — 유도와 수치가 물리적으로 정확. lib 판과 내용 거의 동일(주석·`label` getter 수준의 차이만).
  - `architecture.md:355` — "43개 필드" 주장 vs `spec.dart:26-112` 의 실제 `final` 필드 26개.
  - `lib/src/render/surface.dart:194-205` — 계보 A `paintSurface` 시그니처(Quality/occlusion/detailSeed/unitScale)는 architecture.md:337-338 과 일치.

  

## 3. 상세 분석

  **문서-코드 불일치의 구조.** 스킬 문서는 "파이프라인이 하나"라는 톤이지만 실제 저장소에는 목적이 다른 두 제작 방식이 공존한다. (a) **갤러리 쇼케이스 방식**: `Artist` 서브클래스가 시간 `t` 의 순수 함수로 `kStage(1000×1400)` 위에 수작업 좌표로 그린다(`paint(Canvas c, double t, {double detail})`, creature.dart:53). 계보 B 의 재질별 전용 페인터(`_metal`·`_skin`·`_cloth`…, core/shading.dart:237-586)를 쓰고, `breathe`/`jitter`(anatomy.dart:614-618)로 아이들 모션을 만든다. 등록은 `roster.dart`. 지금 존재하는 모든 AAA 결과물이 여기서 나왔다. (b) **시드 생성 방식**: `HumanoidSpec.generate(seed)` → `Body` → `Pose`/`solve` → 계보 A `paintSurface` — `main.dart` 의 데모에서만 동작한다. SKILL.md 워크플로우 2~6단계는 전부 (b)만 서술한다. 문서의 절대 규칙("수정하려는 파일이 이미 import 하는 쪽을 따른다", SKILL.md:29)은 수정 작업에는 유효하지만, **신규 캐릭터 생성 작업에서 어느 방식을 택할지 기준 자체가 없다.**

  **범위와 경계.** 불일치 대부분은 코드가 진실이고 문서가 낡은 케이스라 **문서만 고치면 되는 범위**다. 코드를 바꿔야 할 발견은 없다. 다만 "한 씬은 하나의 LightRig"(SKILL.md:49)와 "캐릭터마다 LightRig 보유"(aldric.dart:33)의 충돌은 해석이 필요하다 — 갤러리 카드 한 장 = 독립 씬으로 보면 규칙 위반이 아니지만, 이 캐릭터들을 실제 아이소 게임 씬에 함께 놓는 순간 규칙과 정면충돌한다. 그 판단(카드 라이트를 씬 라이트로 수렴시킬지)은 설계 결정이지 문서 결함이 아니므로 사람 몫이다.

  **AAA 달성 관점의 공백.** ① 얼굴: 48px 축소·아이소 뷰에서 눈코입을 어디까지 묘사할지, `drawEye` 군의 사용 조건이 문서에 없다 — 얼굴은 AAA 인상의 절반인데 지침 0줄. ② 헤어: `hairStrand` 존재하나 스트랜드 설계 지침 없음(shading.md:483 에 hair 재질 파라미터 한 줄뿐). ③ 반투명·이펙트: 계보 B 의 `glowPath`/`glowAt`/`drawMotes` 가 문서 밖. ④ 수작업 디렉션 방법론(파츠 분할로 재질 밴딩 만들기 등)이 코드 주석에만 갇혀 있다. ⑤ 카드 계약(`kStage`·`kGround`·`framing`·`accent`·`moodSky`) 미문서화 — 새 캐릭터가 갤러리에 어울리려면 반드시 필요한 정보다. 반면 아이소 수식·깊이 정렬·9패스 이론·procgen 원리(원형 대역·branch·bell)는 정확하고 검증 절차(시드 24개 squint test)도 실행 가능하다.

  

## 4. 리스크 · 함정

  - **엉뚱한 위치에 엉뚱한 패턴으로 파일 생성**: `architecture.md:363-372` 를 따른 AI 는 `lib/src/render/<name>_renderer.dart` 같은 미사용 경로에 계보 A 코드를 만들고 `main.dart` 에 등록한다 — 기존 9종과 구조·품질이 어긋나고 갤러리에 안 뜬다. 가장 되돌리기 번거로운 실패 모드.
  - **계보 혼용 유도**: shading.md(계보 A 전용)만 읽고 기존 캐릭터(계보 B)를 "개선"하면 `keyDir` 부호 규약이 달라 명암이 통째로 뒤집힌다(architecture.md:82 가 경고하지만 계보 B 의 API 자체가 없어 결국 추측 코딩이 된다).
  - **`name: abc`**: 스킬 로더가 디렉토리명과 frontmatter name 의 일치를 요구하면 스킬이 로드되지 않거나 `abc` 로 표시된다. 사용자가 이미 `vis` 로 개명했으므로 불일치 상태.
  - **문서가 약속하는 검증이 실제 캐릭터에 적용 불가**: "시드 24개를 띄워라"(SKILL.md:84)는 수작업 캐릭터에는 의미가 없다. 문서대로 검증 절차를 밟으면 갤러리 캐릭터의 품질 검증 기준이 공백이 된다.
  - **미사용 파이프라인 과잉 신뢰**: verlet·8방향 Facing 지침을 캐릭터에 처음 적용하는 AI 는 "검증된 레시피"로 착각한다 — 실제로는 프로덕션 캐릭터 적용 전례가 없다.
  - 미세 불일치: "43개 필드"(실제 26), 디렉토리 지도에 `ui/`·`entry.dart`·`roster.dart`·`vesper.dart` 누락, cowork 프롬프트조차 "PC 4종"이라 서술(실제 5종).

  

## 5. 권고안

  | 순위 | 권고 | 범위 | 근거 | 리스크 |
  |---|---|---|---|---|
  | 1 | `SKILL.md:2` 의 `name: abc` → `name: vis` | 스킬 메타 | `SKILL.md:2` vs 디렉토리명 | 없음 |
  | 2 | "새 액터 추가 절차"를 실제 패턴으로 교체: `lib/src/art/pc\|mob/<name>.dart` 에 `Artist` 상속 → `roster.dart` 등록. 기존 절차는 "시드 생성 humanoid 추가 시"로 한정 표기 | `architecture.md:363-372` | `roster.dart:20-35`, `creature.dart:53` | 잘못된 경로 안내 제거 |
  | 3 | 두 제작 방식의 분기 기준을 SKILL.md 상단에 명시: "쇼케이스/히어로급 = Artist 수작업(계보 B), 범용 생성형 = HumanoidSpec(계보 A)" | `SKILL.md` 워크플로우 | 9종 전원 계보 B, spec 사용자는 main.dart 뿐 | 방식 선택 잘못하면 전면 재작업 |
  | 4 | 계보 B API 레퍼런스 신설: `core/shading.dart` 의 `Surface`/`Finish`/`paintSurface`/`rimBand`/`glowPath`/`glowAt`/`castShadow`/`occlude`/`inkOutline`/`panelLine`/`groundShadow` + `breathe`/`jitter` | `shading.md` 에 절 추가 또는 신규 reference | `core/shading.dart:87,169,721-898` | 없으면 계보 B 추측 코딩 |
  | 5 | 얼굴·손·헤어 지침 추가: `anatomy.dart` 의 `drawEye`/`drawBrow`/`drawNose`/`drawMouth`/`handShape`/`hairStrand` API + 48px/아이소에서의 디테일 생략 기준 | `silhouette.md` 부위 레시피 확장 | `anatomy.dart:120-654` | 문서 분량 증가 |
  | 6 | 카드 계약 문서화: `kStage`, `kGround=1332`, `framing`, `accent`, `moodSky`, 그리고 규칙 7 의 예외("카드 한 장 = 독립 씬, 게임 씬 배치 시 씬 LightRig 로 수렴") | `architecture.md` 또는 신규 | `creature.dart:8-13,56`, `aldric.dart:33` | 규칙-코드 충돌 해소 필요 |
  | 7 | 미사용 파이프라인 표시: verlet 2차 모션·8방향 Facing 은 "humanoid_renderer 전용, 쇼케이스 적용 전례 없음" 임을 해당 절 머리에 명기 | `animation.md:252`, `isometric.md:124` | grep 사용자 0건 | 과잉 신뢰 방지 |
  | 8 | 디렉토리 지도 갱신(`ui/`, `entry.dart`, `roster.dart`, `vesper.dart`), "43개 필드" → 26개 | `architecture.md:39-70,355` | find 결과, `spec.dart` | 사소 |
  | 9 | 수작업 아트 디렉션 사례(aldric 의 판금 밴딩 기법 등)를 "캐릭터별 설계 노트"로 스킬에 이관 | 신규 reference 또는 silhouette.md | `aldric.dart:11-16` | [판단] 분량 대비 효과 검토 필요 |

  

## 6. 불확실 · 미확인

  - `shading.md:235` 의 9패스 전체 소스가 `render/surface.dart:194-406` 의 실제 패스 구현과 1:1 로 일치하는지는 전수 대조하지 못했다(시그니처와 구조만 확인).
  - `animation.md` 의 `Pose` 필드·`solve()` 소스가 `rig/pose.dart` 와, `procgen.md` 의 `Rng`/`Noise`/`Palette` 소스가 `core/*.dart` 와 시그니처 수준에서 일치하는지 부분 확인에 그쳤다.
  - `vesper.dart` 가 문서 작성(8/6 14:5x) 이후에 추가된 것인지, 문서가 의도적으로 4종만 언급한 것인지는 파일 시각만으로 판별 불가.
  - 규칙 7 과 캐릭터별 `LightRig` 의 충돌을 "카드=독립 씬"으로 해석할지, 게임 씬용 라이트 통합 계획이 있는지는 설계자 판단이 필요하다.
  - Mob/PC 가 실제 아이소 게임 씬(y-sort·8방향)에 배치되는 코드 경로는 `ui/` 만 훑었고 Flame 씬 통합은 미확인 — 없다면 SKILL.md 전제 2("모든 캐릭터가 아이소 뷰에 맞게 설계")와 현 구현의 괴리가 문서 문제가 아니라 제품 로드맵 문제가 된다.
