# pub.dev 배포 — provis 패키지 관리

## 목차

1. [핵심 개념: 라이브러리와 예제의 경계](#핵심-개념-라이브러리와-예제의-경계)
2. [저장소 구조](#저장소-구조)
3. [public API 관리 — provis.dart barrel](#public-api-관리)
4. [배포 전 체크리스트](#배포-전-체크리스트)
5. [버전 정책](#버전-정책)
6. [흔한 배포 실패와 원인](#흔한-배포-실패와-원인)

---

## 핵심 개념: 라이브러리와 예제의 경계

`provis` 는 **도구**를 배포한다. 특정 게임의 캐릭터와 맵은 배포하지 않는다.

| | 라이브러리 (`lib/src/`) | 예제 (`example/`) |
|---|---|---|
| 무엇 | 재사용 가능한 도구 — 셰이딩·기물·아이소·리그·조작 | 그 도구로 만든 결과물 |
| 예 | `TreeProp`, `paintSurface`, `IsoController`, `Artist` 계약 | Aldric, Gorehide, 마을 배치 |
| 판단 기준 | "다른 게임에서도 쓰나?" | "이 게임에만 있는 것인가?" |

이름과 사연이 있는 캐릭터는 **라이브러리에 넣지 않는다.** 패키지가 무거워지고,
소비자는 어차피 자기 캐릭터를 만든다. 대신 `example/lib/characters/` 의 9종이
**참조 구현**으로 남아 "이 정도 밀도로 만들어라"를 보여 준다.

기물(`props/`)은 반대다. 나무·바위·건물은 **파라미터로 다양성을 내는 완제품**
이므로 라이브러리에 있어야 즉시 쓸 수 있다.

---

## 저장소 구조

```
provis/                      ← pub.dev 패키지 루트
├── pubspec.yaml             name: provis
├── README.md                pub.dev 의 얼굴. 코드 예제가 실제로 동작해야 한다
├── CHANGELOG.md             버전별 변경. pub.dev 가 탭으로 보여 준다
├── LICENSE                  MIT
├── .pubignore               배포 아카이브에서 제외할 것
├── lib/
│   ├── provis.dart          public barrel — 소비자가 import 하는 유일한 파일
│   └── src/                 구현. 소비자는 여기를 직접 import 하지 않는다
├── test/                    라이브러리 테스트 (rng_test 등)
└── example/                 별도 패키지
    ├── pubspec.yaml         provis: {path: ../}
    ├── lib/                 실행 앱 3종 + characters/ + ui/
    └── test/                캐릭터 렌더 시트 테스트
```

### example 이 별도 패키지인 이유

pub.dev 는 `example/` 을 자동으로 인식해 "Example" 탭에 보여 준다. 그러려면
독립 패키지여야 하고, `provis` 를 `path: ../` 로 참조해야 한다. 그래야 배포 전
로컬 코드로 검증되고, 배포 후에는 소비자가 그대로 복사해 쓸 수 있다.

플랫폼 폴더(`macos/`·`web/`)도 example 에 있어야 한다. 라이브러리 패키지에
플랫폼 폴더가 있으면 용량만 늘고 아무 역할도 하지 않는다.

---

## public API 관리

**`lib/provis.dart` 가 유일한 진입점이다.** 새 파일을 만들면 여기에
`export` 를 추가해야 소비자가 쓸 수 있다.

```dart
export 'src/props/tree.dart';   // 새 기물을 만들었으면 이 줄을 추가한다
```

### 무엇을 export 하지 않는가

- 내부 헬퍼(`_MinHeap`, `_Ramp` 같은 private)
- 예제 전용 코드

### export 누락은 조용히 일어난다

**라이브러리가 컴파일된다는 것과 남이 쓸 수 있다는 것은 다른 문제다.** barrel 에
`export` 한 줄을 빠뜨리면 라이브러리는 멀쩡히 빌드되지만 소비자는 그 기능에 닿을
수 없다. 실제로 `prop_kit.dart`(442줄의 형상 헬퍼)가 그렇게 새어 나갔다.

**`example/test/public_api_test.dart` 가 이것을 잡는다.** barrel 하나만 import
해서 소비자가 하려는 일을 전부 시도하는 9개 시나리오다 — 재질 19종, `Artist`
구현, 기물(라이브러리 것 + 직접 만든 것), `prop_kit` 헬퍼, 아이소 투영·정렬,
경로탐색·이동, 방향 스냅, 시드 결정론, 골격 액터.

새 공개 API 를 추가했으면 **이 테스트에 한 줄 넣는다.** 넣지 않으면 export 를
빠뜨려도 아무도 모른다.

```bash
# 누락 자동 점검
for f in $(find lib/src -name '*.dart' | sed 's|lib/||'); do
  grep -q "export '$f'" lib/provis.dart || echo "누락: $f"
done
```

### 문서 예제도 컴파일되어야 한다

README 는 새 사용자가 처음 만나는 코드다. 시그니처가 바뀌면 문서는 조용히 낡고,
복사해 붙인 사람은 컴파일 오류부터 만난다. `torsoShape` 이 `top`/`bottom` 에서
`chest`/`pelvis` 로 바뀌었을 때 실제로 그랬다.

`public_api_test.dart` 는 README 예제와 **같은 API** 를 쓰므로, 문서가 낡으면
이 테스트가 먼저 깨진다.

### 진짜 소비자로 검증하기

의심스러우면 임시 패키지를 만들어 확인한다. 저장소 안에서는 상대 경로 때문에
문제가 가려질 수 있다.

```bash
mkdir -p /tmp/consumer/lib && cd /tmp/consumer
cat > pubspec.yaml <<'YAML'
name: consumer
environment: {sdk: ^3.12.2}
dependencies:
  flutter: {sdk: flutter}
  flame: ^1.38.0
  provis: {path: /경로/provis}
YAML
# lib/main.dart 에 barrel 하나만 import 하고 대표 API 를 써 본다
flutter pub get && flutter analyze
```

### 이름 충돌 주의

barrel 은 모든 export 를 한 네임스페이스에 합친다. 새 최상위 함수를 만들 때는
기존 이름과 겹치지 않는지 확인한다:

```bash
grep -rhoE "^(class|enum|mixin|extension|void|double|Color|Path|Offset|List<[^>]+>) [A-Za-z_]+" lib/src/ \
  | awk '{print $2}' | sort | uniq -d
```

특히 `mix` 는 Flame 이 재수출하는 `vector_math` 에도 있다. 소비자가
`package:flame/game.dart` 와 `package:provis/provis.dart` 를 함께 import 하면
충돌하므로, README 에 `hide mix` 를 안내해 두었다.

---

## 배포 전 체크리스트

```bash
# ① 양쪽 다 무결점
flutter analyze && (cd example && flutter analyze)

# ② 양쪽 다 통과
flutter test && (cd example && flutter test)

# ③ 예제가 실제로 뜨는지 눈으로 확인
cd example && flutter run -t lib/main.dart

# ④ 배포 시뮬레이션 — 경고 0 이 목표
flutter pub publish --dry-run

# ⑤ 실제 배포
flutter pub publish
```

`--dry-run` 이 보는 것:

- [ ] `pubspec.yaml` 에 `description`(60~180자)·`repository`·`version` 이 있는가
- [ ] `README.md`·`CHANGELOG.md`·`LICENSE` 가 있는가
- [ ] 아카이브 크기가 합리적인가 (`build/` 가 들어가면 수백 MB 가 된다)
- [ ] `test/`·`lib/` 가 참조하는 패키지가 전부 `dependencies` 에 있는가
- [ ] 커밋되지 않은 파일이 없는가

### `.pubignore` 가 필요한 이유

pub 은 `.gitignore` 를 존중하지만, **git 이 추적하지 않는 파일도 아카이브에
넣는다.** `build/` 가 그대로 들어가 255 MB 짜리 패키지가 되는 사고가 실제로
있었다. `.pubignore` 로 명시적으로 막는다:

```
build/
example/build/
example/macos/
example/web/
.dart_tool/
.cowork/
.claude/
CLAUDE.md
```

---

## 버전 정책

시맨틱 버저닝을 따른다. 이 패키지에서 **파괴적 변경**은 다음을 뜻한다:

| 변경 | 파괴적인가 | 이유 |
|---|---|---|
| `Finish` 에 값 추가 | ❌ | switch 가 exhaustive 하면 소비자 코드가 깨지지만 드물다 |
| `paintSurface` 에 선택 인자 추가 | ❌ | 기존 호출이 그대로 동작한다 |
| `LightRig` 필드 이름 변경 | ✅ | 모든 호출부가 깨진다 |
| `Prop.paint` 시그니처 변경 | ✅ | 모든 커스텀 기물이 깨진다 |
| `Rng.branch` 파생 방식 변경 | ✅ | **컴파일은 되지만 모든 시드 결과가 바뀐다.** 가장 위험한 종류 |

**마지막 항목이 중요하다.** 절차적 생성 라이브러리에서 "같은 시드가 다른 결과를
내는 변경"은 컴파일 오류를 내지 않으므로 소비자가 눈치채지 못한 채 게임의 모든
캐릭터가 바뀐다. 그런 변경은 반드시 major 를 올리고 CHANGELOG 에 굵게 적는다.

`0.x` 대에서는 minor 를 파괴적 변경으로 취급한다(`0.1.0` → `0.2.0`).

---

## 흔한 배포 실패와 원인

| 증상 | 원인 | 처방 |
|---|---|---|
| `Package is 255 MB` | `build/` 가 아카이브에 포함 | `.pubignore` 에 `build/` |
| `does not have X in dependencies` | 테스트가 옛 패키지명을 import | `package:provis/provis.dart` 로 통일 |
| `uncommitted changes` | 커밋 안 한 파일 | 커밋 후 재실행 |
| 소비자가 `mix` 충돌 | Flame 의 vector_math | README 에 `hide mix` 안내 |
| 소비자가 `src/` 를 직접 import | barrel 에 export 누락 | `lib/provis.dart` 에 추가 |
| 예제가 pub.dev 에서 안 보임 | `example/pubspec.yaml` 없음 | 별도 패키지로 유지 |
| dartdoc 커버리지 낮음 | public API 에 `///` 없음 | 모든 public 선언에 문서 주석 |

### 배포 후 확인

pub.dev 는 **Pub Points** 로 패키지를 채점한다. 만점 조건:

- `dart format` 통과 — `dart format --set-exit-if-changed .`
- 모든 public API 에 문서 주석
- 예제 제공
- 널 안전성
- 최신 SDK 지원

이 저장소는 문서 주석을 한국어로 쓴다. dartdoc 은 언어를 가리지 않으므로
점수에 영향이 없다.
