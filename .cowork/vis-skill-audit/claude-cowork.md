<!-- cowork:claude | 2026-08-06 15:41:14 | exit=0 | 864s -->
# claude 분석 — vis-skill-audit

> 요청: vis 스킬을 분석하여, Flutter Flame 으로 2.5d isometric 게임의 pc/mob 을 잘 생성할 수 있도록, 멋지고 예쁜 AAA 급 pc/mob 비주얼 디자인을 할 수 있도록 되어져 있는지 분석 후, 수정보완 할 내용이 있으면 수정보완해주세요. 참고: 폴더 이름 abc 를 vis 로 변경했습니다.

[분석 대상] /Users/thruthesky/tmp/games/vis/.claude/skills/vis/ 스킬 문서 일체 — SKILL.md(188줄), references/{architecture,isometric,shading,silhouette,procgen,animation,performance}.md(7개, 약 2845줄), assets/iso.dart(248줄).
[대조 자료] 실제 구현 코드 /Users/thruthesky/tmp/games/vis/lib/ (약 13400줄) — 특히 완성된 PC(art/pc/)와 Mob(art/mob/), 렌더 파이프라인(render/surface.dart, core/shading.dart, render/iso.dart).
[핵심 질문] 이 스킬 문서만 읽은 AI 가 실제로 AAA 급 2.5D 아이소메트릭 PC/Mob 을 만들어낼 수 있는가? 못 만든다면 무엇이 빠졌거나 틀렸는가? 문서와 실제 코드가 어긋난 곳은 어디인가?
[주의] 시간이 제한돼 있다. 파일을 전부 정독하려 하지 말고, 먼저 스킬 문서 7개의 목차와 SKILL.md 를 읽은 뒤 lib/ 의 대표 파일 3~4개만 표적 대조하라. 그리고 반드시 결론을 출력하라 — 탐색만 하다 끝나면 분석이 통째로 버려진다.
> 생성: 2026-08-06 15:41:14 · 소요 864s · 읽기 전용 분석(작업공간 미수정)

---

`Write` 도구가 이 세션에서 비활성입니다(읽기 전용 분석 샌드박스). 계획 파일을 만들 수 없으므로, 요청된 6섹션 보고서 형식으로 결과를 출력합니다.

## 1. 결론 요약

**현재 상태로는 만들 수 없다.** `SKILL.md` 자체는 이미 훌륭하게 개정돼 있다 — 이 저장소에 제작 트랙이 둘 실재한다는 사실을 정확히 진단하고, 트랙 B(`core/shading.dart` + `Artist`)를 "현재 품질 상한, 완성 9종이 전부 이 트랙"이라고 못박았다. 이 진단은 코드와 정확히 일치한다(`lib/src/art/` 11개 파일 **전부** `core/shading.dart` 를 쓰고, `render/surface.dart` 를 쓰는 art 파일은 **0개**).

문제는 **개정이 절반에서 멈춘 것**이다. SKILL.md 가 트랙 B 의 읽을 문서로 지정한 `artist-craft.md` 와 `art-direction.md` 가 **파일 자체로 존재하지 않는다.** 7곳에서 깨진 링크로 참조된다. 결과적으로 AAA 로 가는 문이 지도에는 그려져 있으나 실제로는 뚫려 있지 않다 — AI 는 "AAA 하려면 트랙 B 로 가라"는 지시를 받고 문서를 열려다 실패하고, 트랙 A 로 후퇴하면 SKILL.md 스스로 "디테일 상한은 낮다"고 명시한 경로를 밟는다.

## 2. 근거

- `.claude/skills/vis/references/` 실제 파일은 **7개뿐** — architecture · isometric · shading · silhouette · procgen · animation · performance. `artist-craft.md`·`art-direction.md` 없음 (Glob 전수)
- `SKILL.md:31,91,102,108,187,188` + `procgen.md:418` — **7곳의 깨진 링크**
- `SKILL.md:30` — 트랙 B 는 "가장 높다. 현재 완성 9종이 전부 이 트랙", 트랙 A 는 "디테일 상한은 낮다"
- `grep -rn "core/shading\|render/surface" lib/src/art/` — core/shading **11/11**, render/surface **0/11**
- `lib/src/core/shading.dart:87-104` — `enum Finish` **16종**(skin·metal·gold·cloth·leather·scale·chitin·fur·hair·bone·wood·gem·energy·slime·stone·membrane). 트랙 A 의 `SurfaceKind` 10종과 이름·개수 모두 불일치
- `shading.dart:108-116` — `const Surface(this.base, this.finish, {contrast, sss, glow, glowColor, alpha})` 위치 인자 2개. albedo/roughness/metalness/rim/ao/outline **없음**
- `shading.dart:18-27` vs `render/light.dart:14-25` — `LightRig.dir`(피사체→광원) 과 `keyDir`(빛 진행 방향)이 **부호 반대**. 프리셋도 static const 3종 vs `preset(int)` 4종
- `shading.dart:169-177` — 트랙 B `paintSurface` 는 `saveLayer` 를 **쓰지 않고** `save/clipPath` 만 쓴다 → `performance.md` 의 saveLayer 비용 모델이 트랙 B 에 그대로 적용되지 않음
- `art/anatomy.dart:117-119` — `drawEye` 주석이 **6겹** 명시. 그러나 `silhouette.md:289` 는 "4겹"
- `art/creature.dart:11,14,25` — `kStage(1000,1400)`, `kGround 1332`, `abstract class Artist` 12개 멤버
- `art/pc/aldric.dart:225`, `mob/gorehide.dart:226` — `paintSurface(..., detail:, seed:)` + `rim: false` 플래그. seed 대역이 캐릭터별 분리(aldric 31~231, gorehide 601~659)
- `lib/src/art/pc/vesper.dart` **1290줄 실재** — PC 는 4종이 아니라 **5종**(총 9종). `architecture.md:39-70` 디렉토리 지도에 `vesper.dart`·`roster.dart` 누락
- `core/rng.dart:77` — `branch` 가 루트 시드가 아닌 호출 시점 `_s` 파생. `SKILL.md:70` 이 이미 정확히 경고 중
- `test/render_sheet_test.dart` 실재 — `SKILL.md:116` 은 정확

## 3. 상세 분석

**경계 구분이 이 판단의 핵심이다.** 이 저장소는 사실상 두 제품이다. 트랙 B(`entry.dart` → `roster.dart` → `Artist` 9종)는 1000×1400 논리 캔버스에 **수작업 절대좌표**로 그리는 3/4 초상 갤러리다 — 아이소메트릭이 아니다. 트랙 A(`main.dart` → `HumanoidSpec` → `render/*`)가 절차적·아이소 액터다. 두 축은 교차 import 가 0이다.

그런데 **AAA 비주얼이 실제로 나온 곳은 트랙 B 뿐이다.** 그리고 트랙 B 를 설명하는 문서가 0줄이다. 남은 7개 문서 중 `shading.md`(502줄)·`procgen.md`·`isometric.md`·`architecture.md` 는 트랙 A 전용이고, 공통이라 표시된 `silhouette.md`·`animation.md`·`performance.md` 도 `Pose`/`Body`/`saveLayer` 기반이라 `Artist` 트랙에는 절반만 적용된다.

즉 **문서화 부재의 대상이 정확히 "예쁨을 만드는 기법"이다.** 완성 9종이 품질을 내는 실제 수단 — `Finish` 16종 선택, 마무리 4종(`occlude`/`castShadow`/`rimBand`/`panelLine`), 눈 6겹, `hairStrand`+`clothSpine`, `glowAt`/`drawMotes`, 캐릭터별 무드 조명, `framing`/`moodSky` 구도 — 이 전부가 어느 문서에도 없다. `SKILL.md:151-157` 체크리스트는 이 6항목을 검사하라고 하면서 설명은 없는 문서로 보낸다.

**부차적으로 기존 7개 문서에도 사실 오류가 있다.** "9패스"라 부르지만 패스 표(`shading.md:220-231`)와 `surface.dart` 코드 모두 0~9 = **10패스**다. `isometric.md:132` 는 존재하지 않는 `Facing.lerp` 를 참조한다. `performance.md:159` 의 `renderImposter` 는 실제 `paintImposter`다. `architecture.md:384`("core/ 는 dart:ui·dart:math 외 import 금지")는 같은 문서 `:244` 가 `core/spline.dart` API 로 `Alignment alignIn(...)` 을 열거하는 것과 모순된다.

**문서 예제 코드는 상당수가 컴파일 불가다.** ① 선행 0 없는 소수 리터럴 `.68`(`shading.md:151-162` 프리셋 10개 전부, `procgen.md:230-240`) ② enum dot-shorthand `kind: .skin` ③ `clamp` 가 `num` 을 반환해 `double` 파라미터에 대입 불가(`shading.md:305,318,344` 등) ④ 자리표시자 주석이 식 위치에 들어간 "전체 소스"(`performance.md:81,103,108`) ⑤ `animation.md:259-320` 의 `VerletChain` 은 `pos`/`prev` 미초기화에 `gravity`/`damping` 필드 선언 자체가 없다.

## 4. 리스크 · 함정

- **가장 큰 함정은 "SKILL.md 가 좋아 보인다"는 것이다.** 트랙 분리·규칙 14개·실수 표가 잘 쓰여 있어 감사가 여기서 멈추기 쉽다. 실제 결함은 링크 끝에 있다.
- **트랙 B 문서를 트랙 A 어휘로 쓰면 더 나빠진다.** `Surface(albedo:, kind:)` 와 `Surface(base, finish)` 는 이름이 같고 시그니처가 다르다. `SKILL.md:54` 가 "조용히 잘못된 것이 잡힌다"고 경고한 그대로다. 신규 문서는 모든 시그니처를 `lib/` 에서 역추적 대조해야 한다.
- **`anatomy.dart` 의 철학을 침범하지 말 것.** `SKILL.md:37` 이 인용하듯 이 파일은 "캐릭터가 서로 닮는 문제 때문에 범용 인체 시스템을 의도적으로 피했다"고 선언한다. 트랙 B 문서에 `HumanoidSpec` 식 자동 생성을 권하면 설계 철학을 정면 위반한다.
- **`performance.md` 의 saveLayer 예산(150회/프레임)을 트랙 B 에 그대로 적용하면 틀린다.** 트랙 B `paintSurface` 는 saveLayer 를 쓰지 않는다. 두 트랙의 비용 모델이 다르다는 사실이 명시돼야 한다.
- 문서 수정만으로 `flutter analyze` 무결점은 유지되지만, `assets/iso.dart` 는 실제 Dart 파일이므로 clamp 수정 시 `lib/src/render/iso.dart:136` 과의 diff 가 벌어질 수 있다.
- 두 계보 통합이나 `rng.branch` 결함 수정은 **코드 변경**이며 이번 범위 밖이다. 되돌리기 어렵고 별도 판단이 필요하다.

## 5. 권고안

| 순위 | 권고 | 범위 | 근거 | 리스크 |
|---|---|---|---|---|
| 1 | `references/artist-craft.md` 신규 작성(500~600줄) — `Artist` 계약, `core/shading.dart` 전 API, **`Finish` 16종 대조표**, 마무리 4종 사용 규범, `anatomy.dart` 헬퍼 카탈로그, 눈 6겹 해부, seed 대역 규약 | 스킬 문서 (트랙 B) | `SKILL.md:102,108,187` 이 요구, `shading.dart:87-104`·`anatomy.dart:120` | 시그니처를 코드 대조 없이 쓰면 트랙 A 어휘 혼입 |
| 2 | `references/art-direction.md` 신규 작성(300~400줄) — 시각 논제 도출 절차, 완성 9종 논제의 코드 역추적, 색 대비·구도(`framing`/`moodSky`/`facesLeft`), 설계서 양식 | 스킬 문서 (트랙 B) | `SKILL.md:88-91` 이 "건너뛰면 반드시 평범해진다"면서 방법 미제공 | 일반론으로 흐르기 쉬움 — 반드시 9종 실제 코드에 앵커 |
| 3 | 사실 오류 정정 — "9패스"→**10패스**, `Facing.lerp` 삭제, `renderImposter`→`paintImposter`, 디렉토리 지도에 `vesper.dart`·`roster.dart` 추가(PC 5종/총 9종), `core/` import 규칙과 `alignIn` 모순 해소 | 기존 7개 문서 | `shading.md:220-231`, `isometric.md:132`, `performance.md:159`, `architecture.md:39-70,244,384` | 낮음 |
| 4 | 예제 코드 컴파일 가능화 — `.68`→`0.68`, `.skin`→`SurfaceKind.skin`, `.clamp(0,1)`→`.clamp(0.0,1.0)`, `VerletChain` 필드 선언 복원, 자리표시자 스니펫은 "전체 소스"→"골격 발췌"로 표현 하향 | 기존 7개 문서 + `assets/iso.dart` | §3 의 5개 유형 | `assets/iso.dart` 수정 시 `render/iso.dart` 와 diff 확대 |
| 5 | `silhouette.md:289` 눈 겹 수를 트랙별로 분기 — "트랙 A 축소 렌더는 4겹 축약 가능 / 트랙 B 는 6겹" | `silhouette.md` | `anatomy.dart:117` vs `SKILL.md:157` | 낮음 |
| 6 | `performance.md` 에 "트랙 B `paintSurface` 는 saveLayer 미사용" 명시 절 추가 | `performance.md` | `shading.dart:183-226` | 낮음 |

검증은 ① 링크 무결성(깨진 링크 0) ② 신규 문서의 모든 시그니처를 `grep -n` 으로 `lib/` 역추적 대조 ③ 수정한 코드 블록을 스크래치패드로 추출해 `dart analyze` ④ "Aldric 급 신규 PC 를 문서만으로 만들어라" 워크스루 — 이 순으로.

## 6. 불확실 · 미확인

- `references/` 7개 문서의 **전문을 직접 읽지 않았다.** 목차·핵심 수치·오류 목록은 서브에이전트 조사에 의존했고, 내가 직접 열어 확인한 것은 `SKILL.md` 전문과 `creature.dart`·`render/iso.dart` 일부·`anatomy.dart` 일부·`rng.dart:68-78` 이다. §C·§D 의 개별 줄번호는 수정 착수 전 재확인이 필요하다.
- `artist-craft.md`·`art-direction.md` 가 **한 번도 쓰인 적 없는지, 삭제됐는지** 확인 못 했다(git 이력 미조회). 삭제된 것이라면 복원이 신규 작성보다 빠르다.
- `assets/iso.dart` 와 `lib/src/render/iso.dart` 의 **실제 diff 전량**을 보지 않았다. 248 vs 242줄 차이의 내역이 미확인이다.
- `Finish` 16종 각각의 실제 렌더 특성(`_metal`/`_slime`/`_membrane` 등 전용 함수 내부)을 읽지 않았다. 대조표 작성 시 `shading.dart:186-221` 이하 각 함수를 정독해야 한다.
- `art/pc/vesper.dart`(1290줄, 최대 파일)와 `kaelen`·`lyra`·`seraphine`·`mourne`·`chitinis`·`vaelmorth` 를 열지 않았다. 관용구 일반화는 aldric·gorehide 2종 표본에 근거한다.
- `ui/backdrop.dart`(219줄)를 읽지 않아 **배경과 캐릭터의 색 대비 규약**을 코드로 확인하지 못했다. `art-direction.md` 의 색 대비 절은 이 파일 정독 후 작성해야 한다.
- **사람 판단이 필요한 지점**: 두 트랙을 장기적으로 공존시킬 것인지, 아니면 트랙 B 의 표현력을 아이소로 이식해 하나로 수렴시킬 것인지. 현재 스킬은 공존을 전제하나 이는 문서 분량을 2배로 만드는 구조적 비용을 낳는다.
