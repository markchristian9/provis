# 전투 루프 배선

입력에서 피드백까지. `lib/src/iso/iso_stage.dart`(`RiggedIsoActor`), `lib/src/iso/iso_input.dart`(`IsoController`), `lib/src/anim/animator.dart`, `lib/src/flame/iso_scene.dart`(`IsoSceneComponent`) 의 실제 계약과 그 위에 전투를 얹는 법.

## 목차

1. [상태를 누가 갖는가](#상태를-누가-갖는가)
2. [RiggedIsoActor — 전 API](#riggedisoactor--전-api)
3. [시간의 주인은 하나다](#시간의-주인은-하나다)
4. [프레임 순서](#프레임-순서)
5. [공격 입력](#공격-입력)
6. [조준 — 이동 없이 도는 법](#조준--이동-없이-도는-법)
7. [타격 판정 — ClipEvent](#타격-판정--clipevent)
8. [피드백 셋 — 히트스톱·흔들림·섬광](#피드백-셋--히트스톱흔들림섬광)
9. [콤보](#콤보)
10. [원샷 이름 제약을 넘는 법](#원샷-이름-제약을-넘는-법)
11. [dash 함정](#dash-함정)
12. [몬스터 쪽](#몬스터-쪽)
13. [완전한 예제](#완전한-예제)
14. [흔한 실패](#흔한-실패)

---

## 상태를 누가 갖는가

네 곳에 나뉘어 있다. **어느 것이 무엇의 주인인지 헷갈리면 전투가 절대 안 맞는다.**

| 상태 | 주인 | 읽는 법 |
|---|---|---|
| 위치 · 경로 · 진행 방향 | `IsoController` | `ctrl.tile` · `ctrl.yaw` · `ctrl.isMoving` |
| 현재 클립 이름 | `RiggedIsoActor` | `actor.state` (`play()` 로만 바뀐다) |
| 클립 진행도 · 이벤트 · 히트스톱 | `Animator` | `animator.progress` · `animator.fired` · `animator.frozen` |
| 시간 | **`IsoSceneComponent`**(씬을 쓰면) 또는 `follow` | 아래 참조 |
| HP · 팀 · 쿨다운 · 히트박스 | **게임 코드** | 라이브러리에 없다 |

provis 는 **전투 로직을 갖고 있지 않다.** 데미지·히트박스·쿨다운은 전부 게임 쪽이다. 라이브러리가 주는 것은 정확히 셋 — **동작을 재생하는 것**, **그 위의 시점을 알려 주는 것**(`fired`), **시간을 멈추는 것**(`hitstop`)이다.

---

## `RiggedIsoActor` — 전 API

```dart
class RiggedIsoActor {
  RiggedIsoActor({
    required HumanoidRenderer renderer,
    required Offset tile,
    double height = 200,
    Animator? animator,
    double yaw = 0,
    double? runThreshold,       // null 이면 gaitCrossover 로 자동
    IsoView iso = kIso,         // 보폭 동기화가 쓴다. 맵과 같은 것을 준다
  });

  final HumanoidRenderer renderer;
  final Animator animator;

  Offset tile;
  double height;
  double yaw;                   // 라디안. 0 = 남(카메라 정면)
  double airborne = 0;
  bool ranged = false;          // 활을 든 자세로 그린다
  double? runThreshold;
  IsoView iso;

  String get state;             // 현재 클립 이름 (읽기 전용)
  double get depth;             // tile.dx + tile.dy — 깊이 정렬 키

  double get gaitCrossover;     // 걷기/달리기가 갈리는 속도(타일/초)
  double naturalSpeed(Clip c);  // c 를 배속 1 로 돌렸을 때의 이동 속도
  double cycleTiles(Clip c);    // c 한 사이클이 나아가는 거리(타일)

  void follow(IsoController c, double dt);   // 위치·방향·클립·보폭을 한 번에
  void play(String name);
  void update(double dt);
  void driveByScene(double dt);              // IsoSceneComponent 전용
}
```

### `follow()` 가 정확히 하는 일

```dart
void follow(IsoController c, double dt) {
  tile = c.tile;                                 // ① 위치를 무조건 복사
  yaw = c.yaw;                                   // ② 방향을 무조건 복사
  if (c.isMoving) {
    final want = _gaitFor(c.speed);              // ③ 속도로 걷기/달리기 선택
    if (want != _state && !_isOneShot(_state)) play(want);
    animator.rate = _rateFor(animator.current, c.speed);   // ④ 보폭 동기화
  } else {
    animator.rate = 1.0;
    if (_state != 'idle' && !_isOneShot(_state)) play('idle');
  }
  if (!_sceneDriven) update(dt);                 // ⑤ 씬이 주인이면 안 민다
}
```

**①②는 조건이 없다.** 공격 중이든 죽었든 위치와 방향을 덮어쓴다. 그래서:

- **공격 시작에 `ctrl.stop()`** 을 안 부르면 → 휘두르며 미끄러진다.
- **조준으로 `actor.yaw` 를 바꾸려면 `follow()` 뒤에** 써야 한다.

**③④가 발 미끄러짐을 없앤다.** `runThreshold` 가 `null` 이면 `gaitCrossover` — 걷기와 달리기가 각자 미끄러짐 없이 낼 수 있는 속도의 기하평균이다. `rate` 는 클립 한 사이클의 이동 거리를 실제 이동 거리에 맞추되 `0.55~1.9` 로 클램프한다(대역 밖에서는 클립 자체가 무너진다). **제자리 동작(`strideCycle == 0`)에는 `rate` 를 걸지 않는다** — 빨리 걷는다고 칼이 빨리 나가면 판정 타이밍이 속도에 따라 달라진다.

**`_isOneShot` 이 공격을 지켜 준다.** `_state` 가 원샷이면 걷기·대기로 갈아타지 않아, 공격 중 이동 입력이 들어와도 클립이 안 끊긴다.

**⑤ 뒤에 자동 복귀가 붙는다.**

```dart
void update(double dt) {
  animator.update(dt);
  if (_isOneShot(_state) && animator.progress >= 1.0) play('idle');
}

bool _isOneShot(String name) =>
    name == 'attack' || name == 'hit' || name == 'shoot' || name == 'dash';
```

---

## 시간의 주인은 하나다

`IsoSceneComponent.update` 가 자기 목록의 액터를 진행시키고 **표시를 남긴다.**

```dart
@override
void update(double dt) {
  super.update(dt);
  if (dt > kMaxFrameStep) dt = kMaxFrameStep;    // 씬·액터·마커·카메라가 같은 상한
  _clock += dt;
  marker?.update(dt);
  for (final a in rigged) a.driveByScene(dt);    // ← _sceneDriven = true 를 남긴다
  …
}
```

그 뒤 게임 코드가 `follow(ctrl, dt)` 를 불러도 `_sceneDriven` 때문에 시간은 다시 안 밀린다 — **입력만 갱신한다.**

**그래서 `follow(ctrl, dt)` 가 언제나 맞다.**

- 액터를 `scene.rigged` 에 넣었다 → 씬이 민다. `follow` 는 입력만.
- 씬 없이 직접 그린다 → `follow` 가 민다.

`dt` 를 0 으로 넘겨 우회할 필요가 없다. `test/anim_timing_test.dart` 의 「씬과 follow 가 시간을 두 번 밀지 않는다」 · 「씬 없이 쓰면 follow 가 시간을 민다」 가 양쪽을 다 지킨다.

**`kMaxFrameStep`(1/20초) 상한을 지우지 않는다.** 프레임이 한 번 크게 밀리면(에셋 로드·GC·창 전환·브레이크포인트) 그 `dt` 를 그대로 먹은 애니메이션은 예비 동작을 통째로 건너뛰고 타격 자세에서 순간이동하며, 이동 컨트롤러는 몇 타일을 한 번에 넘어간다. **잘라 두면 최악의 경우 잠깐 느려질 뿐이다.**

---

## 프레임 순서

순서를 지키지 않으면 한 프레임씩 어긋나 조준이 떨리고 판정이 늦는다.

```
① 컨트롤러 전진      ctrl.update(dt);
② 액터 동기화        actor.follow(ctrl, dt);
③ 조준 덮어쓰기      actor.yaw = lerpAngle(...);        ← 반드시 ② 뒤
④ 이벤트 소비        if (actor.animator.fired.contains('strike')) …
⑤ 흔들림 감쇠·카메라  scene.cameraTarget = base + shake;
```

**히트스톱은 별도 처리가 필요 없다.** `animator.hitstop(0.06)` 이 클립 시간·전환·요동을 함께 멈추고, 남은 정지가 프레임보다 짧으면 **그 나머지로 진행한다** — 그래서 0.06초가 프레임 경계에 따라 0.05~0.08초로 들쭉날쭉해지지 않는다. 게임 로직까지 얼리고 싶으면 `animator.frozen` 을 보고 건너뛴다.

---

## 공격 입력

```dart
void requestAttack(Offset targetTile) {
  if (actor.animator.frozen) return;           // 얼어 있는 동안 입력을 먹지 않는다
  if (actor.state == 'attack') return;         // 예비 동작을 잘라 먹지 않는다

  ctrl.stop();                                 // 반드시. 없으면 미끄러진다
  _aim = targetTile;
  actor.play('attack');
}
```

**`state == 'attack'` 일 때 무시할지 콤보로 받을지**가 게임 감각을 가른다.

| 방식 | 느낌 | 언제 |
|---|---|---|
| 무시 | 묵직하다. 한 번 휘두르면 끝까지 | 소울류 · 대검 |
| 회복 구간(`progress > 0.5`)부터 콤보 | 경쾌하다 | 액션 RPG 기본 |
| 무조건 되감기 | 예비가 잘려 **약해 보인다** | 쓰지 않는다 |

`Animator.play` 는 같은 원샷을 다시 요청하면 `_time = 0` 으로 되감는다 — **막는 것은 호출부의 책임이다.**

**전환 도중 갈아타도 안전하다.** `Animator` 는 전환 중에 또 전환이 걸리면 나가던 클립이 아니라 **화면에 실제로 나와 있던 혼합 포즈**에서 잇는다. 그래서 연타해도 A 로 되돌아갔다가 C 로 가는 것처럼 보이지 않는다.

---

## 조준 — 이동 없이 도는 법

`IsoController` 에는 **"이동하지 않고 방향만 바꾸는" API 가 없다.** `_targetYaw` 는 private 이고 경로 추종 중에만 갱신된다. `ctrl.stop()` 하면 `ctrl.yaw` 는 마지막 진행 방향에서 멈춘다.

그래서 조준은 **`follow()` 뒤에 `actor.yaw` 를 덮어쓴다.**

```dart
final aim = _aim;
if (aim != null) {
  final want = yawFromVelocity(aim - actor.tile);        // iso_view.dart
  actor.yaw = lerpAngle(actor.yaw, want, 1 - math.exp(-dt / 0.08));   // ik.dart
}
```

- `yawFromVelocity(worldDelta)` — 월드 이동 방향을 액터 yaw 로. 아이소 화면의 "오른쪽 위"가 월드 +x 다.
- `lerpAngle(a, b, t)` — 최단 경로 보간. π 를 넘나들 때 한 바퀴 도는 것을 막는다.
- **시정수 0.08초.** 이동 회전(`turnTime` 0.14)보다 빠르다 — 때릴 때는 즉각 조준되는 편이 낫다. 0 으로 스냅하면 뚝뚝 끊긴다.

공격이 끝나면 `_aim = null` 로 놓아 준다. 안 그러면 걷는 내내 목표를 쳐다보며 게처럼 옆으로 간다(그걸 원한다면 그대로 두면 된다 — 스트레이프가 된다).

---

## 타격 판정 — `ClipEvent`

**`progress` 를 비교하지 않는다.** 클립 위에 찍힌 시점을 읽는다.

```dart
if (actor.animator.fired.contains('strike')) {
  for (final e in _enemiesInArc(reach: 1.4, halfAngle: 0.9)) { … }
}
```

`fired` 는 이번 프레임에 지나간 이벤트 이름들이다. 계약이 셋이다.

1. **프레임률과 무관하게 정확히 한 번.** 24·30·60·90·144 fps 전부에서 `strike` 가 딱 1회다(`anim_timing_test` 가 검사한다). 중복 방지 플래그가 필요 없다.
2. **경계는 반열림 `(from, to]`.** 양끝을 다 포함하면 프레임 경계에 걸린 이벤트가 두 번 터지고, 다 빼면 배속이 낮을 때 영영 안 터진다.
3. **히치가 이벤트를 건너뛰지 않는다.** `dt` 가 `kMaxFrameStep` 로 잘리므로 400ms 프레임이 들어와도 타격 프레임을 뛰어넘지 않는다.

루프 클립의 이벤트는 **사이클마다** 터진다 — `walk` 를 두 사이클 돌리면 `footfall` 이 4번이다.

### 부채꼴 판정

타일 좌표계에서 직접 계산한다.

```dart
List<RiggedIsoActor> _enemiesInArc({required double reach, required double halfAngle}) {
  final f = Offset(math.cos(actor.yaw), math.sin(actor.yaw));   // 월드 전방
  final limit = math.cos(halfAngle);
  final out = <RiggedIsoActor>[];
  for (final e in enemies) {
    if (e.state == 'death') continue;
    final d = e.tile - actor.tile;
    final dist = d.distance;
    if (dist > reach || dist < 1e-4) continue;
    if ((d.dx * f.dx + d.dy * f.dy) / dist >= limit) out.add(e);
  }
  return out;
}
```

**`yaw` 는 화면 각이 아니라 월드 각이다** — 아이소 투영을 거치기 전이므로 타일 좌표와 직접 비교해도 맞다. 화면 좌표로 판정하면 대각선에서 사거리가 어긋난다.

| 무기 | `reach`(타일) | `halfAngle`(rad) |
|---|---|---|
| 단검 | 1.0 | 0.7 |
| 검 | 1.4 | 0.9 |
| 대검 | 1.8 | 1.3 |
| 창 | 2.2 | 0.4 |
| 도끼 | 1.5 | 1.1 |

**1 타일 = 1 미터**가 이 저장소의 기준이다(`lib/src/iso/world_scale.dart`). 사거리를 실제 무기 길이로 생각해도 맞는다.

---

## 피드백 셋 — 히트스톱·흔들림·섬광

**셋이 함께 있어야 타격감이 난다.** 하나만 있으면 오히려 어색하다.

### 히트스톱

```dart
actor.animator.hitstop(0.06);
target.animator.hitstop(0.06);
```

**가장 싸고 가장 효과가 큰 한 줄이다.** 클립 시간·전환·요동이 전부 함께 멈춰 그림이 한 장으로 굳고, 그 뒤 **정확히 멈춘 지점에서** 이어진다. 겹쳐 부르면 더 긴 쪽이 이긴다.

- **0.05 미만이면 안 느껴지고 0.10 을 넘으면 랙으로 느껴진다.**
- 가벼운 공격 0.04 · 표준 0.06 · 대검 0.09 · 크리티컬 0.12.
- **때린 쪽과 맞은 쪽 둘 다** 얼려야 한 장으로 굳는다. 한쪽만 얼리면 어색하다.
- 게임 로직까지 얼리려면 `animator.frozen` 을 보고 건너뛴다.

### 화면 흔들림

카메라 훅이 둘이다.

| 필드 | 무엇 |
|---|---|
| `scene.cameraOffset` | 현재 원점. `tileAt()` 의 클릭 → 타일 변환도 **같은 값**을 쓴다 |
| `scene.cameraTarget` | 따라갈 목표. `null` 이면 `cameraOffset` 을 직접 쓴다 |
| `scene.cameraLag` | 목표를 따라잡는 시간(초). 기본 0.15. **0.2 를 넘기지 않는다** |

**PC 추적을 쓰고 있다면 흔들림은 `cameraTarget` 에 더한다.** `cameraOffset` 을 직접 건드리면 다음 프레임에 추적 보간이 도로 지운다.

```dart
double _shake = 0;

// 임팩트에
_shake = 3.0;

// 매 프레임
if (_shake > 0.01) {
  _shake *= math.exp(-dt / 0.05);                          // 0.05초 시정수로 감쇠
  final r = Rng((_frame * 2654435761) & 0x7FFFFFFF);       // math.Random 금지
  scene.cameraTarget = _followTarget + Offset(r.range(-1, 1), r.range(-1, 1)) * _shake;
} else {
  _shake = 0;
  scene.cameraTarget = _followTarget;                      // 정확히 되돌린다
}
```

- **진폭 2~4px.** 그 이상은 멀미가 난다. 크리티컬만 6px.
- 감쇠는 지수. 선형으로 줄이면 딱 멈춰 부자연스럽다.
- **정확히 원래 목표로 복귀한다.** 조금씩 어긋나 누적되면 탭한 곳과 다른 데로 걸어간다. 입력 자체는 `tileAt` 이 현재 `cameraOffset` 으로 풀기 때문에 흔들리는 동안에도 클릭 지점은 정확하다.

### 피격 섬광

맞은 쪽이 `hit` 클립을 재생하면 `impact` 트랙이 켜지고 렌더러가 실루엣을 주황으로 태운다. **때린 쪽은 아무것도 안 한다.**

```dart
for (final e in hits) {
  e.play('hit');                       // impact: [1.0, 0.85, 0.55, …] — 첫 키가 최대
  e.hp -= damage;
  if (e.hp <= 0) e.play('death');      // holdAtEnd: true — 마지막 포즈로 굳는다
}
```

`hit` 은 `blendIn: 0.04` 다 — 충격에는 예비가 없어야 한다. `death` 는 `holdAtEnd: true` 라 idle 로 안 돌아오고, **끝난 뒤에는 미세 요동까지 멎는다**(시체가 어깨를 들썩이면 죽은 것으로 안 보인다).

---

## 콤보

체인 창을 회복 구간에 연다.

```dart
static const _comboWindow = (0.55, 0.90);      // progress 기준

void requestAttack(Offset target) {
  if (actor.state == 'attack') {
    final p = actor.animator.progress;
    if (p < _comboWindow.$1 || p > _comboWindow.$2) return;   // 창 밖이면 무시
    _chain = (_chain + 1) % 3;
  } else {
    _chain = 0;
  }
  ctrl.stop();
  _aim = target;
  actor.animator.play(_chainClips[_chain]);
}
```

**`animator.play(Clip)` 은 `RiggedIsoActor._state` 를 바꾸지 않는다.** `_state` 는 private 이고 `actor.play(name)` 으로만 갱신된다. 그래서 콤보 클립을 `animator` 에 직접 넣으면 `_state` 가 이전 값으로 남아 `follow()` 의 원샷 보호가 안 걸리고, **이동 입력이 들어오면 다음 프레임에 walk 로 갈아탄다.**

**해결 셋.**

**(a) `Animator(clips: [...])` 에 콤보 클립을 넣고 전부 `name: 'attack'` 으로 만든다.** `Animator.byName` 은 자기 `clips` 를 먼저 보므로 `actor.play('attack')` 이 그쪽을 재생하고 `_state` 도 `'attack'` 이 된다. 다만 이름이 같아 단계를 이름으로 못 고르므로, 단계 전환은 `clips` 목록을 갈아 끼우거나 `animator.play(clip)` 과 병행한다.

**(b) 콤보 동안 `follow` 를 건너뛰고 직접 동기화한다.** 가장 간단하고 실제로 잘 동작한다.

```dart
if (_comboing) {
  actor.tile = ctrl.tile;                       // follow 대신 직접
  if (actor.animator.progress >= 1.0) { _comboing = false; actor.play('idle'); }
} else {
  actor.follow(ctrl, dt);
}
```

**(c) 라이브러리를 고친다** — `play(Clip, {String? state})` 오버로드를 추가하거나 `_state` 에 setter 를 연다. 콤보를 본격적으로 쓸 거면 이쪽이 맞다.

| 단계 | 클립 길이 | 예비 | 특징 |
|---|---|---|---|
| 1타 | 0.70 s | 짧게 | 빠른 진입 |
| 2타 | 0.62 s | 더 짧게 | 반대 방향 궤적 |
| 3타 | 1.05 s | 길게 | 마무리. 넉백 · 큰 흔들림 · 히트스톱 0.10 |

**마지막 타만 예비를 길게 준다.** 전부 빠르면 무게가 없고, 전부 느리면 콤보가 아니다.

---

## 원샷 이름 제약을 넘는 법

```dart
// lib/src/iso/iso_stage.dart
bool _isOneShot(String name) =>
    name == 'attack' || name == 'hit' || name == 'shoot' || name == 'dash';
```

**이 넷이 아닌 이름으로 `play()` 하면**:

1. `follow()` 의 `!_isOneShot(_state)` 가 참 → 이동 상태와 다르면 **다음 프레임에 덮어쓴다**. 서 있어도 `_state != 'idle'` 인 순간 즉시 idle 로 간다.
2. `update()` 의 자동 복귀도 안 걸린다.

**즉 새 이름의 원샷은 한 프레임도 못 보인다.**

### 처방 A — 이름을 재활용한다 (라이브러리 수정 없음)

새 클립의 `name` 을 `'attack'` 으로 주고 `Animator(clips: [...])` 로 넘긴다. `byName` 이 자기 목록을 먼저 보므로 `actor.play('attack')` 이 그것을 재생하고 `_state` 도 맞는다.

### 처방 B — 라이브러리를 고친다 (권장)

`lib/src/iso/iso_stage.dart` 를 한 줄 고친다. `Clip` 은 이미 import 돼 있고, `animator.byName` 이 재생기의 목록까지 본다.

```dart
/// 끝나면 대기로 돌아오는 한 번짜리 동작들.
/// 클립 자체가 아는 정보(`loop == false`)를 쓰므로 이름을 늘려도 따라온다.
bool _isOneShot(String name) => !animator.byName(name).loop;
```

**이 한 줄이 규칙 7 과 규칙 8(dash 함정)을 동시에 없앤다.** `dash` 는 `loop: true` 이므로 더 이상 원샷으로 취급되지 않아 갇히지 않고, 새로 만든 `loop: false` 클립은 이름과 무관하게 원샷으로 동작한다.

고친 뒤 확인:

```bash
flutter analyze && (cd example && flutter analyze)
flutter test && (cd example && flutter test)   # public_api_test 가 actor.play('attack') 을 검사한다
```

`example/test/public_api_test.dart` 에 `dash` 복귀 검사를 한 줄 더한다.

---

## dash 함정

```dart
static const dash = Clip(name: 'dash', duration: 0.46, /* loop 미지정 → true */ …);
```

`Clip.loop` 의 기본값이 `true` 라 `dash` 는 **루프 클립**이다. 그런데 `_isOneShot('dash')` 는 참이다. 그리고

```dart
double get progress => _current.loop
    ? (_time / _current.duration) % 1.0      // 항상 [0, 1) — 1.0 에 절대 안 닿는다
    : (_time / _current.duration).clamp(0.0, 1.0);
```

→ `progress >= 1.0` 이 영원히 거짓 → 자동 복귀 안 걸림 → `follow()` 도 원샷으로 보고 비켜 감 → **`play('dash')` 하면 영구히 dash 다.**

**즉시 처방**: 자동 복귀에 기대지 말고 게임 쪽에서 시간을 재어 명시적으로 빠져나온다.

```dart
if (actor.state == 'dash') {
  _dashLeft -= dt;
  if (_dashLeft <= 0) actor.play(ctrl.isMoving ? 'run' : 'idle');
}
```

**근본 처방**: 위의 [처방 B](#처방-b--라이브러리를-고친다-권장). `dash` 는 의미상 **이동 루프**(`strideCycle: 4.7`, `footfall` 이벤트 2개를 갖는다)이지 원샷이 아니므로, `_isOneShot` 에서 빠지는 쪽이 옳다.

---

## 몬스터 쪽

같은 배선을 그대로 쓴다. 다른 점은 입력이 AI 라는 것뿐이다.

```dart
for (final (actor, ctrl, brain) in mobs) {
  if (brain.target != null && (brain.target! - actor.tile).distance < brain.reach) {
    if (actor.state != 'attack' && brain.cooldown <= 0) {
      ctrl.stop();
      actor.play('attack');
      brain.cooldown = brain.interval;
    }
  } else if (!ctrl.isMoving) {
    ctrl.moveTo(brain.nextTile());
  }
  brain.cooldown -= dt;
  ctrl.update(dt);
  actor.follow(ctrl, dt);

  if (actor.animator.fired.contains('strike') && _hitsPlayer(actor)) {
    hero.play('hit');
    hero.animator.hitstop(0.05);
  }
}
```

**몬스터의 예비 동작은 PC 보다 길게.** 플레이어가 반응할 시간이 필요하다 — 같은 0.86초 클립을 `animator.speed = 0.75` 로 늦추면 예비가 0.43초가 되어 회피할 수 있다. 보스는 0.6 배까지. **`speed` 는 이벤트 시각도 함께 늦추므로** 판정과 그림이 계속 맞는다.

**`math.Random` 금지** — 배회 목적지·공격 간격도 `Rng(seed ^ tick)` 으로. 같은 시드가 같은 전투를 재현해야 버그를 잡을 수 있다.

---

## 완전한 예제

```dart
class Combat {
  Combat({required this.scene, required this.actor, required this.ctrl});

  final IsoSceneComponent scene;
  final RiggedIsoActor actor;
  final IsoController ctrl;
  final List<RiggedIsoActor> enemies = [];

  /// 카메라가 따라갈 기준점. 흔들림은 여기에 더한다.
  Offset followTarget = Offset.zero;

  Offset? _aim;
  double _shake = 0;
  int _frame = 0;

  void tapMove(Offset tile) {
    if (actor.state == 'attack') return;      // 공격 중 이동 입력은 버린다
    ctrl.moveTo(tile);
    scene.marker?.ping(tile);
  }

  void tapAttack(Offset tile) {
    if (actor.animator.frozen || actor.state == 'attack') return;
    ctrl.stop();
    _aim = tile;
    actor.play('attack');
  }

  void update(double dt) {
    _frame++;

    // ① 컨트롤러 — 히트스톱 중에는 세워 둔다
    if (!actor.animator.frozen) ctrl.update(dt);

    // ② 액터 동기화 — 씬이 시간을 굴려도 dt 를 그대로 넘긴다
    actor.follow(ctrl, dt);

    // ③ 조준 — 반드시 follow 뒤
    final aim = _aim;
    if (aim != null) {
      actor.yaw = lerpAngle(actor.yaw,
          yawFromVelocity(aim - actor.tile), 1 - math.exp(-dt / 0.08));
    }
    if (actor.state != 'attack') _aim = null;

    // ④ 타격 이벤트 — 프레임률·배속과 무관하게 정확히 한 번
    if (actor.animator.fired.contains('strike')) {
      for (final e in _inArc(reach: 1.4, halfAngle: 0.9)) {
        e.play('hit');
        e.animator.hitstop(0.06);
        actor.animator.hitstop(0.06);
        _shake = 3.0;
      }
    }

    // ⑤ 카메라 — 추적 기준점에 흔들림을 더한다
    _updateCamera(dt);
  }

  void _updateCamera(double dt) {
    if (_shake <= 0.01) {
      if (_shake != 0) _shake = 0;
      scene.cameraTarget = followTarget;
      return;
    }
    _shake *= math.exp(-dt / 0.05);
    final r = Rng((_frame * 2654435761) & 0x7FFFFFFF);
    scene.cameraTarget =
        followTarget + Offset(r.range(-1, 1), r.range(-1, 1)) * _shake;
  }

  /// 전방 부채꼴 안의 적. yaw 는 월드 각이므로 타일 좌표와 직접 비교한다.
  List<RiggedIsoActor> _inArc({required double reach, required double halfAngle}) {
    final f = Offset(math.cos(actor.yaw), math.sin(actor.yaw));
    final limit = math.cos(halfAngle);
    final out = <RiggedIsoActor>[];
    for (final e in enemies) {
      if (e.state == 'death') continue;
      final d = e.tile - actor.tile;
      final dist = d.distance;
      if (dist > reach || dist < 1e-4) continue;
      if ((d.dx * f.dx + d.dy * f.dy) / dist >= limit) out.add(e);
    }
    return out;
  }
}
```

---

## 흔한 실패

| 증상 | 원인 | 처방 |
|---|---|---|
| 휘두르며 미끄러진다 | `ctrl.stop()` 누락 | 공격 시작에 `stop()` |
| 조준이 안 먹는다 | `follow()` **앞에서** `yaw` 를 씀 | `follow()` 뒤로 옮긴다 |
| 조준이 떨린다 | 매 프레임 스냅 | `lerpAngle` + 시정수 0.08 |
| 한 번 휘두르고 여러 번 때린다 | `progress` 비교로 판정 | `animator.fired` |
| 타격 판정이 안 터진다 | 클립에 `events` 없음 | `ClipEvent('strike', 0.5)` |
| 판정과 그림이 어긋난다 | 이벤트 시각 ≠ `weaponSwing` 정점 | 같은 시각으로 맞춘다 |
| 대각선에서 사거리가 어긋난다 | 화면 좌표로 판정 | 타일 좌표 + `yaw` 로 판정 |
| 타격감이 없다 | 피드백이 하나뿐 | 히트스톱 + 흔들림 + 섬광 셋 다 |
| 히트스톱이 한쪽만 걸린다 | 때린 쪽만 얼림 | 양쪽 다 `hitstop()` |
| 랙처럼 느껴진다 | 히트스톱 0.10 초과 | 0.05~0.08 |
| 흔들림이 곧바로 지워진다 | `cameraOffset` 을 직접 건드림 | `cameraTarget` 에 더한다 |
| 흔들린 뒤 클릭한 곳과 다른 데로 간다 | 기준점 복귀 누락/누적 | 정확히 `followTarget` 으로 되돌린다 |
| 멀미가 난다 | 흔들림 진폭 과다 | 2~4px |
| 카메라가 늦게 따라온다 | `cameraLag` 과다 | 0.2 이하 |
| 새 공격이 한 프레임도 안 보인다 | 원샷 이름 4종 밖 | `_isOneShot` 을 `!loop` 로 |
| dash 에서 못 빠져나온다 | `loop: true` + 원샷 취급 | 명시적 `play()` 또는 `_isOneShot` 수정 |
| 콤보 클립이 즉시 walk 로 바뀐다 | `animator.play(Clip)` 이 `_state` 를 안 바꿈 | `Animator(clips:)` + 같은 이름, 또는 `follow` 건너뛰기 |
| 연타하면 공격이 약해 보인다 | 예비를 매번 잘라 먹음 | 진행 중 입력을 무시하거나 콤보 창에서만 |
| 죽은 몬스터가 일어난다 | `death` 뒤에 `follow` 가 walk 로 전환 | `state == 'death'` 면 `follow` 를 건너뛴다 |
| 몬스터 공격을 못 피한다 | 예비가 너무 빠름 | `animator.speed = 0.75` |
| 발이 미끄러진다 | `iso` 불일치 또는 `strideCycle` 누락 | 액터에 맵의 `iso`, 이동 클립에 `strideCycle` |
| 기기마다 걷기 속도가 다르다 | 프레임 수로 시간을 잼 | 벽시계 `dt` |
| 창 전환 뒤 동작이 건너뛴다 | `kMaxFrameStep` 제거 | 상한을 지우지 않는다 |
| 같은 전투가 재현이 안 된다 | `math.Random` | `Rng(seed ^ tick)` |
