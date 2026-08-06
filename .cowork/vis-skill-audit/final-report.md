# 종합 검토 — vis-skill-audit

> 요청: vis 스킬이 Flutter Flame 으로 2.5D 아이소메트릭 게임의 AAA 급 PC/Mob 비주얼을
> 만들 수 있게 되어 있는지 분석하고, 수정보완할 내용이 있으면 수정보완할 것.
> 참여: **codex ✅ · grok ✅(2-pass) · claude ❌(900s 타임아웃) · kimi ❌(900s 타임아웃)**
> — claude·kimi 재시도를 타임아웃 2400s 로 백그라운드 재실행 중. kimi 는 1차에서 최종 출력 전에
> 잘렸으나 `.logs/kimi.log`(23KB)에 실질 분석이 축적되어 참고 자료로 사용했다(검증 대상으로만 사용,
> 결론 근거로는 직접 확인한 것만 채택).

---

## 1. 결론

**스킬은 "절차적 아이소메트릭 그래픽스 교재"로는 우수하지만, 이 저장소가 실제로 AAA 품질을 내고 있는
경로를 문서화하지 않았다.** 완성된 캐릭터 9종(PC 5 · Mob 4)은 전부 `Artist` + `core/shading.dart`
계보로 손수 작성되는데, 스킬의 6단계 워크플로우는 그것을 쓰지 않는 `HumanoidSpec` + `render/surface.dart`
계보만 정답으로 가르친다. 스킬을 충실히 따를수록 로스터와 다른 구조·다른 API·낮은 품질의 캐릭터가 나온다.

여기에 **스킬이 로드조차 안 될 수 있는 메타 오류**(`name: abc`, `def.md` 의 깨진 경로)와
**실재하지 않는 API 를 지시하는 허구 5건**, **문서가 "필수"라고 못 박았지만 코드 전역 호출이 0인 규칙**이
겹쳐 있다. 즉 현재 스킬은 "체크리스트를 통과했다"고 보고해도 그것이 시각 품질을 보장하지 않는다.

수정 방향은 코드 통합이 아니라 **① 메타 정합 → ② 목표별 진입점 이중 트랙 분기 → ③ 허구 API 제거·수치 정정
→ ④ 계보 B(실제 AAA 경로) 문서화 → ⑤ 아트 디렉션 단계 추가** 다.

---

## 2. 네 AI 의견 대조

| 쟁점 | codex | grok(2-pass) | claude | kimi | 검증 결과 |
|---|---|---|---|---|---|
| 이중 파이프라인이 최대 결함 | 1순위 | 1순위(메타와 병렬) | 실패 | (로그에 동일 지적) | ✅ 합의 — 직접 확인 |
| `name: abc` 미정정 | 지적 | 지적 | 실패 | 실패 | ✅ `SKILL.md:2` 확인 |
| `paintContactShadow` 필수인데 호출 0 | 미지적 | 지적 | 실패 | 로그에 지적 | ✅ 검증: 정의 1 / 호출 **0** |
| `Rng.branch` 격리 실패 | 지적 + 대안코드 | 미지적 | 실패 | 실패 | ✅ 검증: `_s` 기반 확인 |
| 문서 전용 허구 API | 부분 지적 | 5건 열거 | 실패 | 로그에 지적 | ✅ 검증: 5건 전부 lib 0건 |
| `architecture.md` 수직 투영식 오류 | 지적 | 미지적 | 실패 | 실패 | ✅ 검증: `wz*TILE_H` vs `wz*heightScale` |
| 로스터는 PC 5종(Vesper 포함) | 지적(§6) | 지적(자기비판 ➕) | 실패 | 실패 | ✅ `roster.dart:17-23` 확인 |
| "다각형 금지" 절대 규칙이 실제와 충돌 | 지적 | 미지적 | 실패 | 실패 | ⚖️ **부분 인정** — 아래 §4 |
| "씬 하나의 LightRig" 규칙이 실제와 충돌 | 지적 + 대체 문구 | 지적 | 실패 | 실패 | ✅ 합의 — 트랙별로 다름 |
| `assets/iso.dart` 복사 지시 위험 | 지적 | 지적(자기비판 ❌철회 후 재확인) | 실패 | 로그에 지적 | ✅ 검증: 14줄 드리프트 |
| 성능 수치가 미측정 가설 | 지적 | 미지적 | 실패 | 실패 | ⚖️ **인정** — 출처 없음 |
| 계보 B 를 1급으로 승격 | 권고 3 | "단독 정답 아님, 목표별 분기" | 실패 | 실패 | ⚖️ **grok 채택** — §4 |

---

## 3. 합의 — 검증 통과

직접 열어 확인한 사실만 적는다.

1. **이중 파이프라인이 실재한다.** 진입점이 둘이다 — `lib/entry.dart:8`(갤러리 로스터),
   `lib/main.dart:19`(절차 액터 뷰어). `lib/src/art/pc/*.dart`·`art/mob/*.dart` 8개 파일이 import 하는
   것은 `core/shading.dart`·`art/anatomy.dart`·`core/spline.dart`·`core/palette.dart` 뿐이며,
   `actor/spec.dart`(HumanoidSpec)·`render/surface.dart`·`render/iso.dart` 를 import 하는 art 파일은
   **0개**다.

2. **재질 어휘가 다르다.** 계보 A `SurfaceKind` 10종(`render/surface.dart:12`) vs
   계보 B `Finish` **16종**(`core/shading.dart`) — `gold, scale, fur, wood, energy, slime, membrane` 은
   계보 B 에만 있다. 스킬의 재질 파라미터 표는 계보 A 의 10종만 다룬다.

3. **조명 방향 규약이 정반대다.** 계보 A `LightRig.keyDir` = 빛이 진행하는 방향
   (`render/light.dart`), 계보 B `LightRig.dir` = 피사체가 광원을 바라보는 방향
   (`core/shading.dart:29`). 섞으면 명암이 통째로 뒤집힌다. 스킬의 "자주 하는 실수" 표에 항목은 있으나
   **어느 계보의 `LightRig` 인지 명시가 없다.**

4. **`paintContactShadow` 는 호출되지 않는다.** 정의 `render/surface.dart:503`, 저장소 전역 호출 **0건**.
   그런데 `SKILL.md` 4단계와 품질 체크리스트는 "접촉 그림자 5곳"을 **필수**로 못 박았다.
   → 문서가 요구하는 것을 아무도 하지 않고 있으며, 체크리스트 통과가 품질을 보장하지 않는다.

5. **문서 전용 허구 API 5건.** `Facing.lerp`(isometric.md:133) · `MonsterRole`(procgen.md) ·
   `shapeBias`(silhouette.md) · `actor_component.dart`(performance.md:56, 실제로는 `main.dart` 인라인) ·
   `renderImposter`(performance.md, 실제 이름은 `paintImposter`) — **전부 `lib/` 검색 결과 0건**.
   그대로 따라 쓰면 컴파일 실패한다.

6. **`architecture.md:122` 의 수직 투영식이 틀렸다.** 문서 `- wz * TILE_H`,
   실제 `lib/src/render/iso.dart:48` `- wz * heightScale` (= `tileWidth * cosθ / √2`).
   같은 스킬 안의 `isometric.md` 는 올바른 식을 쓰므로 **문서 내부 모순**이기도 하다.

7. **`Rng.branch` 는 문서가 약속한 격리를 제공하지 않는다.**
   `core/rng.dart:77` `Rng branch(int salt) => Rng((_s ^ (salt * 0x9E3779B9)) & 0xFFFFFFFF);`
   — 루트 시드가 아니라 **호출 시점의 현재 상태 `_s`** 에서 파생한다. 따라서 체형 난수 호출을 하나 앞에
   추가하면 이후 `r.branch(11)` 의 팔레트까지 바뀐다. `procgen.md` 의 "장비 규칙을 하나 추가해도 기존
   체형이 안 바뀐다"는 설명은 **현재 구현에서 거짓**이다.

8. **메타 오류로 스킬/커맨드가 깨져 있다.** `SKILL.md:2` `name: abc`(폴더는 `vis`),
   `.claude/commands/def.md:10` 이 `../skills/abc/SKILL.md` 를 참조 — 해당 경로는 존재하지 않는다.

9. **번들 에셋이 드리프트했다.** `assets/iso.dart` ↔ `lib/src/render/iso.dart` 가 **14줄** 다르다.
   `Facing.label` 은 assets 에만 있고 lib 에는 없다(`main.dart:64` 가 같은 배열을 인라인으로 재구현).
   `SKILL.md` 의 "`lib/src/render/iso.dart` 로 복사해 쓴다"를 그대로 실행하면 lib 최신본을 덮어쓴다.

10. **로스터는 PC 5종이다.** `art/roster.dart:17-23` — Aldric, Kaelen, Seraphine, Lyra, **Vesper**.
    Mob 4종(Gorehide, Vaelmorth, Mourne, Chitinis). 총 9종.
    (`core/shading.dart:13` 주석은 "8종"이라고 적혀 있어 코드 주석도 낡았다 — grok 고유 발견.)

---

## 4. 이견 — 자료로 판정

### 쟁점 A: 계보 B 를 문서의 1급 경로로 올려야 하는가

- **codex**: 권고 3 — `references/shading-core.md` 를 추가해 계보 B 를 문서화하고, 실제 로스터 패턴을
  정본으로 삼자.
- **grok**: 반대 뉘앙스 — 스킬 `description` 이 "**절차적** 코드로 생성"을 명시하므로, 계보 B 를 유일한
  정답으로 올리면 스킬 정체성과 충돌한다. **목표별 진입점 분기**가 옳다.

**판정: grok 이 맞다.** 근거 — 스킬 `description`(`SKILL.md:3`)은 절차적 생성을 스킬의 정의로 삼고 있고,
`lib/src/art/anatomy.dart:12-15` 는 "캐릭터가 서로 닮는 문제 때문에 범용 인체 시스템을 **의도적으로 피했다**"고
선언한다. 두 철학은 양립 불가능한 것이 아니라 **목적이 다르다** — 손수 만드는 간판 캐릭터(트랙 B)와
시드로 찍는 인게임 군중(트랙 A). 어느 한쪽을 폐기할 근거는 자료에 없다.
따라서 채택안은 **"계보 B 를 1급으로 승격"이 아니라 "목표를 먼저 묻고 트랙을 강제 분기"** 다.
다만 계보 B 의 공개 API 문서화(codex 권고 3의 실질)는 그대로 필요하다 — 트랙 B 로 갈 때 읽을 것이 없으면
분기해도 소용없기 때문이다. **두 권고를 합쳐서 채택한다.**

### 쟁점 B: "다각형을 그대로 그리지 않는다"(절대 규칙 10)가 틀렸는가

- **codex**: 실제 갑옷·검날은 의도적 직선 `Path` 를 쓴다(`aldric.dart:573-585`). 규칙이 과잉이다.
- **grok**: 미지적.

**판정: 부분 인정.** 검증 — `art/pc/aldric.dart` 에 `lineTo` **6회**, `art/mob/*.dart` 4개 파일 합계
`lineTo` **0회**. 즉 **유기체(Mob)에는 규칙이 그대로 유효**하고, **인공물(갑옷 패널·검날·결정)에서만
예외**다. 규칙을 폐기할 것이 아니라 예외 조건을 붙이는 것이 자료에 맞다.

### 쟁점 C: 성능 수치(`saveLayer` 150회, 블러 3000px)가 유효한가

- **codex**: 프로젝트 내부 측정과 연결돼 있지 않다. "측정 전 가설"로 강등해야 한다. 또한 이 모델은
  파츠마다 `saveLayer` 를 쓰는 계보 A 에만 해당하며 계보 B 에는 적용되지 않는다.

**판정: 인정.** 해당 수치의 출처가 문서 어디에도 없고, 계보 B 의 `paintSurface` 는 구조가 달라
같은 예산이 성립할 이유가 없다. 다만 **삭제가 아니라 "미측정 가설" 표기 + 계보 한정**이 맞다 —
근사 예산조차 없으면 최적화 판단 기준이 사라진다.

---

## 5. 고유 통찰 — 하나만 발견했으나 검증됨

- **[codex] `BakedPart` 의 회전 재생은 조명을 깨뜨린다.** `performance.md` 는 "회전 변환은 허용"이라고
  적었지만, 구운 `Picture` 에는 조명이 이미 칠해져 있으므로 파츠를 돌리면 하이라이트·그림자도 함께
  돌아 월드 조명이 무너진다. → 캐시 키에 방향·조명·품질·스케일을 포함하고, 셰이딩된 파트의 임의 회전은
  금지해야 한다.
- **[codex] `Rng.branch` 대체 구현 제시.** 루트 시드를 별도 필드로 보관해 파생시키는 4줄 패치.
  현재 구현의 결함을 실제로 고칠 수 있는 유일한 구체안이다.
- **[grok] 스킬 정체성 긴장의 발견.** description 의 "절차적"과 로스터의 "수작업"이 충돌한다는 지적은
  codex 에 없었고, 쟁점 A 의 판정을 바꾼 결정적 관점이다.
- **[grok 자기비판 §7]** 1차에서 "architecture 에 트랙 B 가 한 줄뿐"이라고 과장했다가 2차에서
  "디렉토리·계보 공존 표는 있다. 없는 것은 B 의 제작 워크플로우·공개 API·체크리스트·레시피"로 정정.
  → **이 정정된 표현이 정확하다.** 검증: `architecture.md:62-82` 에 계보 대조표가 실재한다.

---

## 6. 반증 — 근거가 틀린 주장

- **[grok 1차, 본인이 철회]** "`assets/iso.dart` 와 lib 판이 거의 동일해 번들 상태 양호" →
  실제 14줄 드리프트. grok 이 2차에서 스스로 철회했고 검증 결과 철회가 옳다.
- **[grok 1차, 본인이 철회]** "`paintContactShadow` 가 humanoid_renderer 에서 0회" → 범위가 틀렸다.
  **저장소 전역 0회**가 정확하다. 다만 "깊이 장치가 전무하다"는 과장이며, 계보 A 는 `occlusion` 인자로
  부분 대체하고 있다. 검증 결과 이 정정도 옳다.
- **[cowork-prompt.md:12 — 내가 쓴 것]** "PC 4종" → 실제 **5종**(Vesper 포함). 분석 프롬프트 자체의
  오류였으며, 네 AI 모두에게 잘못된 전제를 준 것이다. 결론에는 영향이 없다.
- **채택하지 않은 권고**: codex 권고 3 의 "계보 B 를 정본으로" 프레이밍 — §4 쟁점 A 판정에 따라
  "목표별 분기 + B 문서화"로 재구성해 채택한다.

---

## 7. 최종 권고

| 순위 | 권고 | 범위 | 근거 | 리스크 | 검증 방법 |
|---|---|---|---|---|---|
| 1 | `SKILL.md:2` 를 `name: vis` 로 정정. `.claude/commands/def.md:10` 의 `../skills/abc/SKILL.md` → `../skills/vis/SKILL.md`. 본문 `abc` 잔여 제거 | 메타 | `SKILL.md:2`, `def.md:10` | 없음 | 스킬 목록에 `vis` 로 로드되는지 확인 |
| 2 | **SKILL.md 최상단에 "목표 → 트랙" 라우터 추가.** 간판 캐릭터/갤러리 → 트랙 B(`Artist`+`core/shading`+`anatomy`+`roster`), 인게임 아이소 군중 → 트랙 A(`HumanoidSpec`+`render/*`+`humanoid_renderer`). **두 트랙의 API 를 한 파일에서 섞지 않는다**를 절대 규칙으로 | SKILL 진입 | `art/*` import 0건, `entry.dart` vs `main.dart` | 분량 증가 | 각 트랙 대표 파일이 어느 계보를 import 하는지 대조 |
| 3 | **허구 API 5건 제거·정정**: `Facing.lerp`→`lerpAngle`, `MonsterRole`·`shapeBias`→「미구현 설계」 라벨, `actor_component.dart`→`main.dart:ActorComponent`, `renderImposter`→`paintImposter` | isometric/procgen/silhouette/performance | lib 검색 0건 | 없음 | `grep -rn <심볼> lib/` 재확인 |
| 4 | **`architecture.md:122` 수직 투영식 정정** `wz * TILE_H` → `wz * iso.heightScale` | 아이소 정확성 | `iso.dart:48` | 없음 | isometric.md 와 식이 일치하는지 대조 |
| 5 | **접촉 그림자 규칙 강등·정합**: "필수 5곳"을 "계보 A 에서 권장 / 계보 B 는 `castShadow`·`occlude` 사용"으로. 조명 규칙 7 은 "인게임 씬 한정 — 트랙 B 는 캐릭터별 `light` 가 의도" 로 한정 | SKILL 규칙·체크리스트 | 호출 0건, `creature.dart:43` | 문서 기준 하향 | 체크리스트 항목이 실제 호출 가능한지 확인 |
| 6 | **`references/artist-craft.md` 신설** — 트랙 B 공개 API(`Finish` 16종, `LightRig(dir…)`, `paintSurface` B, `rimBand`/`castShadow`/`occlude`/`glowAt`/`panelLine`), `kStage`/`kGround`, `drawEye` 6겹, roster 등록 | 트랙 B | `core/shading.dart`, `anatomy.dart` | 분량 증가 | 계보 B 파일 하나를 문서만 보고 재현 가능한지 |
| 7 | **`references/art-direction.md` 신설** — 캐릭터별 "시각 논제" 단계. 비율 왜곡(gorehide 머리 2/3·어깨 5배), 단일 spine(vaelmorth), 파츠 분할 금속(aldric), 긴장 곡선(lyra), 투명 대비(mourne) | AAA 비주얼 | 각 art 파일 헤더 주석 | 템플릿화 시 획일화 | 신규 캐릭터가 한 문장 논제를 갖는지 |
| 8 | **절대 규칙 10(다각형 금지)에 예외 명시** — 유기체는 스플라인 필수, 인공물(갑옷 패널·검날·결정)은 의도적 직선 허용 | SKILL 규칙 | `aldric.dart` lineTo 6 / mob 0 | 없음 | 신규 파츠가 어느 범주인지 판단 가능한지 |
| 9 | **`Rng.branch` 를 루트 시드 기반으로 수정**하고 `procgen.md` 설명을 실제 동작과 일치시킴 | 코드 + 문서 | `rng.dart:77` | 기존 시드 결과 1회 변경 | 브랜치 앞에 난수 호출을 추가해도 팔레트가 불변인지 |
| 10 | **성능 수치를 "미측정 가설 · 계보 A 한정"으로 표기** | performance.md | 출처 없음 | 없음 | `--profile` 실측 시 갱신 |
| 11 | **`assets/iso.dart` 를 "복사본"이 아니라 "템플릿"으로 표기** — 기존 파일이 있으면 diff/merge. 드리프트 14줄 해소 | 번들 에셋 | diff 결과 | 없음 | `diff assets/iso.dart lib/src/render/iso.dart` |

**적용 순서: 1 → 2 → 3 → 4 → 5 → 8 → 11 → 10 → 6 → 7 → 9**
(9번은 코드 수정이므로 시드 결과가 바뀐다 — 사람 확인 후 별도 처리 권장)

---

## 8. 미해결 · 사람 판단 필요

1. **제품 방향**: 트랙 A(절차 인게임)와 트랙 B(수작업 갤러리) 중 무엇이 본선인가? 자료는 둘 다 활발히
   개발 중임을 보여줄 뿐 우선순위를 정하지 않는다. 이 답에 따라 스킬의 무게중심이 달라진다.
2. **`Rng.branch` 수정 시점**: 고치면 기존 모든 시드의 색·장비가 한 번 바뀐다. 지금 고칠지, 시드를
   고정해야 할 캐릭터가 생기기 전에 고칠지 판단 필요.
3. **"AAA" 의 합격 기준**: 기준 이미지·목표 해상도·golden 비교 절차가 없어 AI 가 스스로 합격을 선언할 수
   있다. `test/render_sheet_test.dart` 가 있으나 golden assertion 이 없다.
4. **claude·kimi 재시도 결과**: 백그라운드 진행 중. 결과가 도착하면 이 보고서의 §2 대조표와 §6 을
   갱신해야 한다.

---

## 9. 적용 결과

> **재시도 성공** — claude(864s)·kimi(401s)가 2차 실행에서 결과를 냈다. 두 분석은 §7 권고를 모두
> 지지했고, 아래 추가 결함 6건을 새로 짚었다. 전부 직접 검증 후 반영했다.
>
> **재시도가 추가로 찾은 것**: ① "9패스"가 실제로는 10패스(0~9) ② 선행 0 없는 소수 리터럴
> (`.68`)이 문서 전반에 40여 곳 — Dart 컴파일 불가 ③ `silhouette.md` 눈 4겹 vs `anatomy.dart` 6겹
> ④ `architecture.md` "새 액터 절차"가 쓰이지 않는 경로를 지시 ⑤ "43개 필드" vs 실제 26개
> ⑥ `VerletChain`·`ClothStrip` 호출부 0건(프로덕션 적용 전례 없음).
>
> **채택하지 않은 재시도 주장**: claude 의 "dot-shorthand `kind: .skin` 은 컴파일 불가" — 이 프로젝트의
> Dart(SDK ^3.12.2)는 enum dot-shorthand 를 지원한다(`lib/main.dart` 가 `mainAxisAlignment: .center`
> 를 쓰고 `flutter analyze` 무결점 통과). 반증으로 분류.

| 권고 | 적용 | 파일 | 검증 |
|---|---|---|---|
| 1 메타 정합 | ✅ | `SKILL.md:2` `name: vis`, `commands/def.md` 경로·문구 | 스킬 목록에 `vis`·`def` 로 로드 확인 |
| 2 이중 트랙 라우터 | ✅ | `SKILL.md` — 트랙 대조표 + 판단 기준 + 워크플로우 2갈래 | art 8종 import 대조로 트랙 귀속 확인 |
| 3 허구 API 정정 | ✅ | `isometric.md`(→`lerpAngle`), `procgen.md`·`silhouette.md`(🚧 미구현 라벨), `performance.md`(→`paintImposter`, `main.dart:ActorComponent`) | `grep -rn` 잔여 0건 |
| 4 투영식 오류 | ✅ | `architecture.md:122` → `wz * iso.heightScale` | `iso.dart:48` 과 일치 |
| 5 규칙 강등·한정 | ✅ | `SKILL.md` 규칙 3(조명은 트랙별), 체크리스트를 트랙 A/B 로 분기. 접촉 그림자는 트랙 B `occlude`/`castShadow`, 트랙 A `occlusion` 으로 실제 호출 가능한 것만 요구 | 호출 0건이던 `paintContactShadow` 필수 규칙 제거 |
| 6 트랙 B API 문서 | ✅ | **`references/artist-craft.md` 신설(544줄)** — `Artist` 계약, `Finish` 16종 기법표, `Surface`/`paintSurface`(B), 마무리 4종, `anatomy.dart` 카탈로그, 눈 6겹, roster 등록, 작성 골격 | 모든 시그니처를 `core/shading.dart`·`anatomy.dart` 에서 역추적 대조 |
| 7 아트 디렉션 | ✅ | **`references/art-direction.md` 신설(207줄)** — 완성 9종의 실제 논제 표, 방법론 5가지, 11항목 설계서 양식 | 9개 파일 헤더 주석에서 논제 추출·인용 |
| 8 다각형 규칙 예외 | ✅ | `SKILL.md` 규칙 12 — 유기체 스플라인 / 인공물 직선 허용 | `aldric.dart` lineTo 6회, `mob/*` 0회로 근거 |
| 9 `Rng.branch` | ⏸️ **문서만** | `procgen.md` 에 한계·대처·근본 수정안 명시, `SKILL.md` 규칙 8 경고 | **코드는 미변경** — 고치면 기존 모든 시드 결과가 바뀌므로 §8-2 사람 판단 필요 |
| 10 성능 수치 | ✅ | `performance.md` — "미측정 가설 · 트랙 A 한정" 경고 + 트랙 B 는 `saveLayer` 미사용 명시 | `core/shading.dart:169-177` 구조 확인 |
| 11 에셋 템플릿화 | ✅ | `SKILL.md` — "복사" → "diff 후 병합", 14줄 드리프트 경고 | `diff` 명령 동봉 |
| 추가① 패스 개수 | ✅ | `shading.md` "9패스" → "10패스" | 패스 표 0~9 = 10행 |
| 추가② 소수 리터럴 | ✅ | 전 문서 40여 곳 `.68` → `0.68` | `grep -E "[:(=\|,* ]\.[0-9]"` 잔여 0건 |
| 추가③ 눈 겹 수 | ✅ | `silhouette.md` — 트랙 A 4겹 / 트랙 B 6겹으로 분기 | `anatomy.dart:117` 주석과 일치 |
| 추가④ 새 액터 절차 | ✅ | `architecture.md` — 트랙 B 절차(art/pc→roster 등록)를 먼저 배치 | `roster.dart:17-30` |
| 추가⑤ 디렉토리 지도 | ✅ | `architecture.md` — `entry.dart`·`ui/`·`roster.dart`·PC 5종·Mob 4종 반영, "43개 필드"→26개 | `find lib`, `grep -c "^  final" spec.dart` |
| 추가⑥ 미사용 표시 | ✅ | `animation.md` — Verlet 계열 "프로덕션 적용 전례 0건" 경고 | `grep -rn VerletChain lib/` 호출 0 |

**검증 결과**
- 링크 무결성: SKILL.md + reference 9개의 상대 링크 **깨진 링크 0건**
- `flutter analyze`: **문서만 수정했으므로 코드 영향 없음**. 잔여 경고 1건은 다른 세션이 작업 중인
  `lib/src/art/pc/vesper.dart:80` 의 미사용 변수로 이번 작업과 무관.
- 문서 규모: 3,281줄 → **3,912줄** (신규 751줄, 정정 다수)

**보류 (사람 판단 필요)**
- §8-1 제품 방향(트랙 A/B 중 본선) — 현재는 공존을 전제로 문서화했다.
- §8-2 `Rng.branch` 코드 수정 — 기존 시드 결과가 한 번 바뀐다.
- §8-3 "AAA" 합격 기준(golden 이미지 비교 절차) — `test/render_sheet_test.dart` 에 assertion 없음.
