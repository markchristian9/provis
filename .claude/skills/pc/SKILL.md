---
name: pc
description: provis 로 **플레이어 캐릭터(PC)** 를 세우고 **공격 애니메이션**을 저작·배선한다. 다음 작업에 반드시 사용할 것 — (1) 조작되는 주인공을 맵에 세우고 클릭 이동·8방향을 붙일 때, (2) 공격·피격·사격·대시 클립을 새로 만들거나 고칠 때, (3) 타격감(예비/타격/회복, 히트스톱, 무기 궤적, 피격 섬광, 화면 흔들림)을 손볼 때, (4) 공격 입력 → 타격 이벤트 → 데미지 → 반응까지 전투 루프를 배선할 때, (5) 콤보·차지·무기별 모션을 늘릴 때, (6) `Anims`·`Clip`·`ClipEvent`·`Animator`·`RiggedIsoActor` 를 수정할 때. 키워드 — PC, player character, 플레이어, 주인공, 공격, attack, combat, 전투, 타격감, hitstop, 히트스톱, combo, 콤보, Clip, ClipEvent, Anims, Animator, RiggedIsoActor, weaponSwing, impact, strideCycle, 보폭, 원샷, one-shot, 클립, keyframe, 키프레임.
---

# PC — 플레이어 캐릭터와 공격 애니메이션

`vis` 는 **보기 좋게** 만드는 기술이다. 이 스킬은 그중 하나를 **내 것으로 느끼게** 하고, 그것이 **무언가를 때리는 순간**을 만든다.

관객은 PC 를 수천 시간 본다. 나무 한 그루의 잎맥이 틀린 것은 아무도 모르지만, 공격의 예비 동작이 0.1초 길면 전원이 "굼뜨다"고 말한다. **PC 와 공격은 품질 기준이 다른 영역이다.**

## `vis` 와의 분업

| 작업 | 스킬 |
|---|---|
| 캐릭터의 생김새 — 실루엣·팔레트·장비·셰이딩 | `vis` |
| 맵 기물·지면·조명·아이소 배치 | `vis` |
| **조작되는 몸** — PC 를 세우고 이동·방향을 붙인다 | **`pc`** |
| **공격 클립 저작** — 키프레임·타이밍·무기 궤적 | **`pc`** |
| **전투 루프** — 입력·타격 이벤트·히트스톱·피드백 | **`pc`** |

PC 의 **생김새**를 만들 때는 `vis` 의 캐릭터 워크플로우를 먼저 쓴다. 이 스킬은 그 결과물을 **손에 쥐여 주는** 단계부터다.

---

## 데이터가 흐르는 길

```
탭 / 키 입력
  └→ IsoController          A* 경로 · 위치 · yaw (turnTime 0.14s 보간)
       └→ RiggedIsoActor.follow(ctrl, dt)   idle ⇄ walk ⇄ run + 보폭 동기화(rate)
            ├→ Animator                      크로스페이드 · 이벤트 · 히트스톱
            │    ├→ Clip.sample(0..1)        Catmull-Rom → Pose (각도만)
            │    └→ animator.fired           이번 프레임에 지나간 시점들
            └→ solve(body, pose, yaw:)       → Skeleton (좌표)
                 └→ HumanoidRenderer.paint   무기 · 궤적 · 피격 섬광
```

**공격은 이 흐름을 가로채는 것이다.** `actor.play('attack')` 한 줄이 아니다. 다섯이 같이 움직여야 타격감이 난다 — **입력 · 이동 정지 · 클립 · 타격 이벤트 · 피드백**. 하나라도 빠지면 "애니메이션은 나오는데 안 때린 것 같다"가 된다.

---

## 작업 전 확인

```bash
find lib/src/anim lib/src/rig -name '*.dart' | sort
grep -n "class ClipEvent\|List<ClipEvent> events\|double strideCycle" lib/src/anim/clip.dart
grep -n "_isOneShot\|driveByScene\|gaitCrossover" lib/src/iso/iso_stage.dart
```

고쳤으면 **양쪽 다** 돌린다.

```bash
flutter analyze && (cd example && flutter analyze)
flutter test && (cd example && flutter test)
```

네 테스트가 이 영역의 불변식을 지킨다.

| 테스트 | 무엇을 막는가 |
|---|---|
| `test/pc_skill_contract_test.dart` | **이 문서가 낡는 것** — 아래 규칙들의 수치·계약을 코드에 못 박는다 |
| `test/anim_timing_test.dart` | 2배속 재생 · 프레임률 의존 · 전환 시 포즈 튐 · 발 미끄러짐 · 이벤트 중복/누락 |
| `example/test/widget_test.dart` | 커브의 NaN(파츠가 통째로 사라진다) · 관절 역굽힘 |
| `example/test/snapshot_test.dart` | 전 클립 × 4시점 시트 — 눈으로 대조 |

**`pc_skill_contract_test.dart` 가 깨졌다면 대개 회귀가 아니라 이 문서를 갱신하라는 신호다.** 문서는 코드를 읽고 쓰지만 코드가 바뀔 때 조용히 틀린 말이 되고, **틀린 문서는 없는 문서보다 나쁘다** — 읽는 쪽이 그것을 믿고 배선하기 때문이다. 실제로 이 문서를 쓰는 도중에 애니메이션 API 가 바뀌어 "`progress` 로 판정하라"던 설명이 한 시간 만에 낡았다. 실패 메시지의 `reason` 이 어느 규칙을 고쳐야 하는지 알려 준다.

---

## 절대 규칙

1. **PC 는 `RiggedIsoActor` 다.** `IsoActor`(Artist) 로 만들면 걸을 때 정지 자세로 미끄러지고 8방향이 없다. 초상은 `Artist`, **조작되는 몸은 `RiggedIsoActor`** — `riggedFromArtist(hero, tile:, height:)` 가 그 다리다.

2. **공격 중에는 컨트롤러를 세운다.** `follow()` 는 클립이 원샷이어도 `tile = c.tile` 을 **계속 복사한다**. `ctrl.stop()` 을 부르지 않으면 칼을 휘두르면서 얼음판처럼 미끄러진다.

3. **타격 판정은 `progress` 가 아니라 `ClipEvent` 로 낸다.**

   ```dart
   if (actor.animator.fired.contains('strike')) { … }
   ```

   `fired` 는 프레임률·배속·히트스톱과 무관하게 **정확히 한 번** 터진다. `progress >= 0.5` 로 재면 여러 프레임 동안 참이라 직접 중복 방지 플래그를 들어야 하고, 보폭 동기화로 배속이 바뀌면 시각이 어긋난다.

4. **시간의 주인은 하나다.** `IsoSceneComponent` 는 자기 목록의 액터를 `driveByScene(dt)` 로 진행시키고 표시를 남긴다. 그 뒤 게임 코드가 `follow(ctrl, dt)` 를 불러도 시간은 다시 밀지 않고 **입력만 갱신한다.** 씬을 안 쓰면 `follow` 가 직접 민다. **어느 쪽이든 `follow(ctrl, dt)` 가 맞다** — `dt` 를 0 으로 넘기지 않는다.

5. **`dt` 는 `kMaxFrameStep`(1/20초)으로 잘린다.** 이 상한을 지우면 프레임이 한 번 크게 밀렸을 때 예비 동작을 통째로 건너뛰고 타격 자세로 순간이동한다. 씬·액터·마커·카메라가 **전부 같은 상한**을 써야 그림자와 발이 안 어긋난다.

6. **`play(name)` 의 `name` 은 재생기가 찾을 수 있어야 한다.** `Animator.byName` 은 자기 `clips` 목록을 먼저 보고, 없으면 `Anims.all` 을 본다. **둘 다 없으면 조용히 `idle` 로 떨어진다** — 예외도 경고도 없다. 커스텀 클립은 `Animator(clips: [...])` 로 넘기거나 `Anims.all` 에 등록한다.

7. **원샷 이름은 네 개뿐이다** — `attack` · `hit` · `shoot` · `dash`. `RiggedIsoActor._isOneShot` 이 하드코딩이다. 다섯 번째 이름(`heavy`, `attack2` …)을 쓰면 `follow()` 가 **다음 프레임에 덮어써서** 클립이 한 프레임도 못 보인다. → [combat-loop.md](references/combat-loop.md#원샷-이름-제약을-넘는-법)

8. **`dash` 는 지금 원샷으로 동작하지 않는다.** `Anims.dash` 는 `loop: true` 인데 `_isOneShot` 은 dash 를 원샷으로 본다. 루프 클립의 `progress` 는 `% 1.0` 이라 **1.0 에 절대 닿지 않으므로** 자동 복귀가 영원히 안 걸리고, `follow()` 도 원샷으로 보고 비켜 간다 → **영구히 dash 에 갇힌다.** 빠져나오려면 명시적으로 `play('run')`/`play('idle')`.

9. **원샷 클립의 첫 키와 마지막 키는 같아야 한다** (가드로 돌아오는 동작). `Anims.attack` 은 19개 트랙 **전부** `key[0] == key[8]` 이다. 어긋나면 idle 로 되돌아가는 순간 툭 튄다. `holdAtEnd: true` 인 `death` 만 예외다.

10. **한 클립 안의 모든 트랙은 키 개수가 같아야 한다.** 8키 트랙과 9키 트랙을 섞으면 임팩트 프레임이 트랙마다 다른 시각에 온다. 이 저장소의 규약은 **루프 8키 · 원샷 9키**다.

11. **생략한 트랙은 이전 클립 값이 아니라 기본값으로 간다.** `nearShoulder` 를 안 적으면 0.10 에 고정된다. 상체만 쓰는 공격을 만들 때도 **다리 트랙을 반드시 적는다** — 안 적으면 다리가 레스트로 튄다.

12. **`weaponSwing` 이 곧 타격 프레임이다.** 렌더러가 이 값으로 (a) 무기를 손 방향으로 눕히고, (b) 부채꼴 잔상을 태운다. **1.0 을 찍는 키는 정확히 하나**여야 하고, `strike` 이벤트가 **같은 시각**에 있어야 판정과 그림이 맞는다.

13. **`impact` 는 맞은 쪽이 쓴다.** 때린 쪽이 아니다. 렌더러가 실루엣 전체를 주황 섬광으로 태운다 — 공격 클립에 넣으면 내가 맞은 것처럼 보인다.

14. **이동 클립은 `strideCycle` 을 적고 제자리 동작은 적지 않는다.** 이동 클립에 없으면 발이 미끄러지고, 공격에 있으면 **빨리 걸을수록 칼이 빨리 나가** 판정 타이밍이 이동 속도에 따라 달라진다.

15. **예비 35 / 타격 12 / 회복 53.** 균등하게 나누면 타격감이 사라진다. 예비가 길수록 강해 보이고, 회복이 짧으면 가벼워 보인다.

16. **`math.Random` 금지.** 공격 변주·크리티컬 흔들림도 `Rng(seed)` 로. 같은 입력이 같은 그림을 내야 스냅샷 테스트가 성립한다.

---

## 워크플로우 1 — PC 를 세운다

```dart
// ① 정체성 — 초상용 Artist (vis 스킬의 캐릭터 워크플로우 결과물)
final hero = roster.first;              // BuiltArtist 또는 손그림 Artist

// ② 조작되는 몸 — id 에서 시드를 뽑고 accent 로 팔레트를 물들인다
final start = const Offset(6.5, 9.5);
final actor = riggedFromArtist(hero, tile: start, height: 200)
  ..iso = scene.iso;                    // 보폭 동기화가 타일 크기를 알아야 한다
scene.rigged.add(actor);

// ③ 컨트롤러 — 격자를 넘겨야 A* 가 벽을 피한다
final ctrl = IsoController(tile: start, grid: scene.grid, speed: 3.2);

// ④ 탭
final target = scene.tileAt(event.localPosition.toOffset());
ctrl.moveTo(target);
scene.marker?.ping(target);             // 눌렀다는 사실을 화면에 보여 준다

// ⑤ 매 프레임 — 씬이 시간을 굴려도 dt 를 그대로 넘긴다 (절대 규칙 4)
ctrl.update(dt);
actor.follow(ctrl, dt);
```

- **키는 타일 폭의 1.2~1.6배.** 넘으면 격자가 묻혀 지면 평면이 사라진다.
- **`iso` 를 맵과 맞춘다.** 기본값은 `kIso` 다. 타일 크기가 다른 맵에서 안 넘기면 보폭 계산이 틀려 발이 미끄러진다.
- **`runThreshold` 는 비워 둔다.** `null`(기본)이면 `gaitCrossover` 가 골격에서 자동으로 정한다 — 다리가 짧은 몬스터는 같은 속도에서 더 일찍 뛴다. 고정 숫자를 박으면 타일 크기나 키가 바뀌는 순간 틀린다.
- **활을 든 PC 는 `actor.ranged = true`.** `shoot` 클립을 재생할 때만 켜는 것이 표준이다.

→ 정체성·체형·무기 궁합·초상 대조: [pc-build.md](references/pc-build.md)

---

## 워크플로우 2 — 공격을 배선한다

**다섯을 한 곳에 모은다.** 하나라도 빠지면 타격감이 무너진다.

```dart
Offset? _aim;                                  // 조준 대상의 타일

void attack(Offset targetTile) {               // ① 입력
  if (actor.state == 'attack') return;         //    연타로 예비 동작을 잘라 먹지 않는다
  ctrl.stop();                                 // ② 이동 정지 — 없으면 미끄러진다
  _aim = targetTile;
  actor.play('attack');                        // ③ 클립
}

void update(double dt) {
  ctrl.update(dt);
  actor.follow(ctrl, dt);

  // 목표를 향해 돈다. IsoController 에는 "이동 없이 돌리는" API 가 없으므로
  // follow() **뒤에** yaw 를 덮어쓴다 — 순서가 뒤바뀌면 follow 가 도로 지운다.
  final aim = _aim;
  if (aim != null) {
    actor.yaw = lerpAngle(
        actor.yaw, yawFromVelocity(aim - actor.tile), 1 - math.exp(-dt / 0.08));
  }
  if (actor.state != 'attack') _aim = null;

  // ④ 타격 이벤트 — 프레임률·배속과 무관하게 정확히 한 번 (절대 규칙 3)
  if (actor.animator.fired.contains('strike')) {
    for (final e in _enemiesInArc(reach: 1.4, halfAngle: 0.9)) {   // 게임 쪽 함수
      e.play('hit');                           // ⑤ 맞은 쪽이 impact 를 쓴다
      actor.animator.hitstop(0.06);            //    히트스톱
      e.animator.hitstop(0.06);
      _shake = 3.0;                            //    화면 흔들림
    }
  }
}
```

`Anims` 가 이미 들고 있는 이벤트:

| 클립 | 이벤트 | 시각 | 무엇에 쓰는가 |
|---|---|---|---|
| `attack` | `strike` | 0.5 | 히트박스 · 타격음 · 궤적 |
| `shoot` | `release` | 0.5 | 발사체 생성 — 여기서 안 나가면 손과 어긋난다 |
| `hit` | `impact` | 0.0 | 피격음 · 데미지 표시 |
| `death` | `collapse` | 0.5 | 쓰러지는 소리 · 먼지 |
| `walk` `run` `dash` | `footfall` ×2 | 0.0 · 0.5 | 발소리 · 발밑 먼지 |

→ 히트스톱·화면 흔들림·콤보·원샷 이름 제약 우회: [combat-loop.md](references/combat-loop.md)

---

## 워크플로우 3 — 공격 클립을 저작한다

클립은 **관절별 키프레임 배열**이다. 균등 간격이고 Catmull-Rom 으로 보간되므로, 한 관절을 9개 값으로만 적어도 손으로 다듬은 듯한 가감속이 나온다.

**원샷 9키 격자.** 키 인덱스 `i` → 정규화 시간 `t = i/8`. `Anims.attack`(0.86초) 기준:

| 키 | t | 초 | 이 키가 하는 일 |
|---|---|---|---|
| 0 | 0.000 | 0.00 | **가드** — 키 8 과 같아야 한다 |
| 1 | 0.125 | 0.11 | 감기 시작. 체중이 뒤로 |
| 2 | 0.250 | 0.22 | **예비 정점** — 가장 크게 감은 자세 |
| 3 | 0.375 | 0.32 | 예비 유지(히치). 살짝 되돌려 용수철을 만든다 |
| 4 | 0.500 | 0.43 | **임팩트** — `weaponSwing: 1.0`, `squash` 최저, 체중 전진. `strike` 이벤트 |
| 5 | 0.625 | 0.54 | 관성 오버슈트. 팔이 임팩트를 지나쳐 뻗는다 |
| 6 | 0.750 | 0.65 | 회복 시작 |
| 7 | 0.875 | 0.75 | 가드로 접근 |
| 8 | 1.000 | 0.86 | **가드** = 키 0 |

비율로는 **예비 37.5% / 타격 12.5% / 회복 50%** — 규칙 15 의 35/12/53 이 9키 격자에 떨어진 모습이다.

**히치(키 3)가 타격감의 절반이다.** 예비 정점에서 곧장 때리면 기계 팔이다. 정점을 한 키 유지하면서 아주 조금 되돌리면(2.65 → 2.55) 근육이 힘을 모으는 것처럼 읽힌다.

**`ClipEvent` 는 `weaponSwing` 정점과 같은 시각에 둔다.** 어긋나면 칼이 닿기 전에 피가 튀거나, 지나간 뒤에 튄다.

→ 트랙별 해부, 무기 8종 레시피, 새 클립 추가 절차: [attack-clip.md](references/attack-clip.md)

---

## 확인

```bash
cd example
flutter run -t lib/viewer.dart                 # 클립 버튼 + AUTO + 속도 슬라이더
flutter test test/snapshot_test.dart           # 전 클립 × 4시점 시트를 굽는다
flutter test test/widget_test.dart             # NaN · 역굽힘 방지
cd .. && flutter test test/anim_timing_test.dart   # 타이밍 불변식
```

**뷰어부터 띄운다.** `Anims.all` 에 클립을 넣으면 버튼이 자동으로 하나 생긴다. 속도를 0.25배로 낮추면 임팩트 프레임이 눈으로 보인다 — `speed` 는 전환에도 함께 걸리므로 크로스페이드까지 느리게 관찰된다.

---

## 체크리스트

**PC**
- [ ] `RiggedIsoActor` 인가 — `IsoActor` 로 만들면 걸을 때 자세가 그대로다
- [ ] 키가 타일 폭의 1.2~1.6배인가
- [ ] `iso` 를 맵의 `IsoView` 와 맞췄는가 — 안 맞으면 발이 미끄러진다
- [ ] `runThreshold` 를 비워 뒀는가 (자동 `gaitCrossover`)
- [ ] 몬스터 무리 속에서 **1프레임 안에** PC 를 찾을 수 있는가 (accent · 키 · 헤드기어)
- [ ] 초상과 게임 액터가 같은 인물인가 (`identity_sheet_test`)

**공격 클립**
- [ ] 예비 / 타격 / 회복이 **비대칭**인가 (35 / 12 / 53)
- [ ] 예비 정점 뒤에 **히치**가 있는가
- [ ] `weaponSwing` 이 **한 키에서만** 1.0 인가
- [ ] `ClipEvent` 가 `weaponSwing` 정점과 **같은 시각**인가
- [ ] 키 0 과 마지막 키가 **모든 트랙에서** 같은가
- [ ] 모든 트랙의 키 개수가 같은가 (원샷 9 · 루프 8)
- [ ] 다리 트랙을 적었는가 — 생략하면 레스트로 튄다
- [ ] 임팩트 프레임에 `squash` < 1 과 `rootX` 전진이 함께 있는가
- [ ] `blendIn` 이 짧은가 (공격 0.09 · 피격 0.04) — 길면 입력이 굼뜨게 느껴진다
- [ ] 제자리 동작에 `strideCycle` 을 **안** 넣었는가
- [ ] 재생기가 찾을 수 있는 이름인가 (`Anims.all` 또는 `Animator(clips:)`)
- [ ] `flutter test` 의 NaN · 역굽힘 · 타이밍 검사를 통과하는가

**타격감**
- [ ] 판정을 `animator.fired` 로 내는가 — `progress` 비교가 아니라
- [ ] 공격 시작에 `ctrl.stop()` 이 있는가
- [ ] `animator.hitstop(0.05~0.08)` 이 있는가
- [ ] 맞은 쪽이 `hit` 을 재생하는가 — `impact` 는 피격자의 것이다
- [ ] 화면 흔들림이 **감쇠**하며 정확히 원래 오프셋으로 돌아오는가
- [ ] 흔들림이 `cameraTarget` 과 싸우지 않는가

---

## 자주 하는 실수

| 증상 | 원인 | 처방 |
|---|---|---|
| `play('heavy')` 했는데 idle 이 나온다 | 재생기가 이름을 못 찾음 | `Anims.all` 등록 또는 `Animator(clips:)` |
| 새 공격이 한 프레임도 안 보인다 | 이름이 원샷 4종이 아님 → `follow()` 가 덮어씀 | 이름을 `attack` 으로 쓰거나 `_isOneShot` 확장 |
| dash 에서 영원히 못 빠져나온다 | `Anims.dash` 가 `loop: true` → `progress` 가 1.0 에 안 닿음 | 명시적 `play('run')` |
| 칼을 휘두르며 미끄러진다 | `ctrl.stop()` 누락 — `follow` 가 tile 을 계속 복사 | 공격 시작에 `stop()` |
| 한 번 휘두르고 여러 번 때린다 | `progress` 비교로 판정 | `animator.fired` |
| 타격 판정이 안 터진다 | 클립에 `events` 없음 | `ClipEvent('strike', 0.5)` 추가 |
| 빨리 걸으면 공격도 빨라진다 | 공격 클립에 `strideCycle` 을 넣음 | 제자리 동작에서 뺀다 |
| 발이 얼음판처럼 미끄러진다 | `strideCycle` 누락 또는 `iso` 불일치 | 이동 클립에 `strideCycle`, 액터에 맵의 `iso` |
| 공격이 끝나며 툭 튄다 | 키 0 ≠ 마지막 키 | 모든 트랙의 양 끝을 맞춘다 |
| 상체만 만든 공격에서 다리가 튄다 | 다리 트랙 생략 → 기본값으로 스냅 | 다리 트랙도 전부 적는다 |
| 임팩트가 트랙마다 다른 시각에 온다 | 트랙별 키 개수가 다름 | 한 클립 안에서 통일 |
| 무기 궤적이 뭉개져 속도가 안 보인다 | `weaponSwing` 1.0 이 여러 키 | 정확히 한 키만 1.0 |
| 때렸는데 내가 하얗게 탄다 | 공격 클립에 `impact` 를 넣음 | `impact` 는 `hit` 클립의 것 |
| 창끝이 지면을 뚫는다 | 손목 각도를 그대로 따름 | 렌더러가 `weaponSwing` 으로 섞는다 — 스윙 커브를 확인 |
| 타격감이 없다 | 3구간이 균등 | 35 / 12 / 53 |
| 공격이 굼뜨다 | 예비가 길거나 `blendIn` 이 큼 | 타이밍 표 준수, `blendIn` 0.09 |
| 연타하면 예비가 잘려 약해 보인다 | 진행 중 재입력을 그대로 수용 | `state == 'attack'` 이면 무시하거나 콤보 창에서만 |
| 창을 전환했다 다시 오면 동작이 건너뛴다 | `dt` 상한 제거 | `kMaxFrameStep` 를 지우지 않는다 |
| 기기마다 걷기 속도가 다르다 | `dt` 를 프레임 수로 대체 | 벽시계 `dt` 를 쓴다 — `anim_timing_test` 가 잡는다 |
| 시체가 계속 어깨를 들썩인다 | `holdAtEnd` 미설정 | `death` 는 `holdAtEnd: true` |
| 관절이 한 바퀴 돈다 | `Pose.lerp` 의 선형 보간 | 해당 각도만 `lerpAngle` |
| 무릎이 반대로 꺾인다 | Catmull-Rom 오버슈트 | 인접 키 차이를 줄이거나 값을 0 이상으로 |
| 뷰어에 새 클립 버튼이 없다 | `Anims.all` 미등록 | 등록하면 자동으로 생긴다 |

---

## 참조 문서

| 문서 | 언제 읽는가 |
|---|---|
| [attack-clip.md](references/attack-clip.md) | **공격 클립 저작** — 9키 격자, `Anims.attack` 트랙별 해부, `Clip`·`ClipEvent` 전 필드, `Animator` 전 API, 무기 8종 레시피, 새 클립 추가 절차, 타이밍 표 |
| [combat-loop.md](references/combat-loop.md) | **전투 배선** — 입력 → 타격 이벤트 → 데미지 → 피드백, 히트스톱, 화면 흔들림과 카메라 추적, 콤보, 원샷 이름 제약 우회, 몬스터 반응 |
| [pc-build.md](references/pc-build.md) | **PC 정체성** — 왜 PC 는 기준이 다른가, `riggedFromArtist` 가 잇는 것, `CharacterBuild` 필드표, 무기 ↔ 클립 궁합, 크기 기준, 초상 대조 |
| `vis` 스킬 | 생김새 전반 — 실루엣·셰이딩·팔레트·맵 기물·아이소 배치 |
| `vis` → `references/animation.md` | 포즈·FK·IK·베를레의 저수준 참조 (걷기·달리기·2차 모션) |
