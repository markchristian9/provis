# Changelog

## Unreleased

### 애니메이션 — 부드러움 점검
프레임률이 흔들려도, 이동 속도가 달라져도 같은 그림이 나오도록 재생 경로 전체를
손봤다.

- **재생이 두 배로 빨라지던 것을 고쳤다.** `IsoSceneComponent` 와
  `RiggedIsoActor.follow` 가 같은 프레임에 각자 시간을 밀고 있었다. 이제 씬이
  시간의 주인이고 `follow` 는 그 사실을 안다.
- **발 미끄러짐을 없앴다.** `Clip.strideCycle`(다리 길이 배수로 적은 보폭)과
  `RiggedIsoActor.iso` 로 클립의 재생 배속을 실제 이동 속도에 맞춘다. 걷기·
  달리기 전환도 고정 임계값이 아니라 보폭에서 갈린다(`gaitCrossover`).
  `runThreshold` 는 `double?` 이 되었고 기본값 `null` 이 자동을 뜻한다.
- **전환의 튐을 없앴다.** 전환 도중 다른 클립으로 갈아탈 때 화면에 나와 있던
  혼합 포즈에서 잇는다. 요동 진폭도 전환에 얹어 이어진다.
- **히치에 강해졌다.** 애니메이션·이동·씬이 같은 `kMaxFrameStep`(1/20초)으로
  `dt` 를 자른다 — 400ms 프레임 하나가 공격의 예비동작을 삼키거나 캐릭터를
  몇 타일 순간이동시키지 않는다.
- **`ClipEvent` 와 `Animator.fired`** — 판정·타격음·이펙트를 클립 위의 시점에
  건다. 프레임률·배속과 무관하게 정확히 한 번 터진다. `attack`·`shoot`·`hit`·
  `death` 와 보행 클립의 발소리에 표식을 넣었다.
- **`Animator.hitstop(seconds)`** — 타격 프레임에서 시간을 멈춘다. 남은 정지가
  한 프레임보다 짧으면 나머지로 진행해, 정지 길이가 프레임 경계에 흔들리지 않는다.
- **`Animator.rate`** — 보폭 동기화 배속. `speed`(사람이 조작하는 배속)와 성격이
  달라 분리했다. `speed` 는 전환에도 걸리고 `rate` 는 걸리지 않는다.
- **`Animator.byName`** — 커스텀 클립 목록을 먼저 찾는다. `playByName` 이
  `Anims` 만 보던 탓에 커스텀 클립을 이름으로 재생할 수 없었다.
- **프레임 스파이크 제거.** `IsoSceneComponent` 가 깊이 정렬 목록과 래퍼 객체를
  매 프레임 새로 만들지 않는다(기물 100개 씬에서 프레임당 100+ 할당 → 0).
- **`IsoSceneComponent.cameraTarget`/`cameraLag`** — 프레임률과 무관한 지수 감쇠
  카메라 추종. 입력은 현재 오프셋으로 풀리므로 클릭 지점이 밀리지 않는다.
- **`IsoView.worldScale`** — 타일 한 변의 실제 길이(px). 보폭 계산의 자.
- `IsoController` 의 누적 yaw 를 한 바퀴 안으로 되감아 장시간 실행에서 회전이
  거칠어지는 것을 막는다.
- `test/anim_timing_test.dart` 가 위 불변식을 지킨다 — 프레임률 독립성, 전환
  연속성, 이벤트 발화 횟수, 보폭 일치, 이중 진행 금지.

## 0.1.0

First release.

### 재질과 조명
- `Finish` 16종 — 각 재질이 전용 알고리즘을 갖는다. 금속의 3단 환경 밴딩,
  피부의 표면하 산란, 머리카락의 이방성 띠, 키틴의 이리데센스 등.
- `LightRig` — 씬이 공유하는 3점 조명. 초상용 무드 3종(`heroic`/`infernal`/
  `spectral`)과 인게임 시각 4종(`daylight`/`dusk`/`moonlit`/`torchlit`).
- 마무리 패스 — `occlude`·`castShadow`·`rimBand`·`panelLine`·`glowAt`·
  `topPlane`·`trimBand`·`groundShadow`.

### 캐릭터
- `Artist` — 시간의 순수 함수로 자신을 그리는 캐릭터 계약.
- `anatomy.dart` — `headShape`/`torsoShape`/`limb`/`handShape`/`bootShape`/
  `hairStrand`/`clothSpine`, 6겹 `drawEye` 를 포함한 얼굴 부위.
- `HumanoidSpec` — 원형 기반 시드 생성. 겹치지 않는 체형 대역으로 "특징 없는
  평균"을 피한다.
- `Pose`/`solve`/`solveIk2`/`VerletChain` — 골격·순운동학·2본 IK·2차 모션.

### 맵 기물
- `TreeProp` — 활엽수·침엽수·고사목·꽃나무·수양버들. 잎 덩어리를 깊이별로
  나눠 칠하고 덩어리마다 바람의 위상이 다르다.
- `RockProp`/`PebbleField` — 실루엣은 곡선, 내부는 직선 면으로 쪼개 광물의
  각을 만든다.
- `BuildingProp`/`WallProp` — 아이소의 3면(좌벽·우벽·지붕) 구조. 목조·석조·
  통나무·벽돌, 박공/평/원뿔 지붕, 밤에 켜지는 창문.
- `WaterProp`/`LavaProp` — 깊이·하늘 반사·잔물결 3겹. 용암은 자체 발광.
- `GroundPatch`/`PathPatch` — 지면 식생과 길.

### 아이소메트릭
- `IsoView` — 2:1 dimetric 투영, 역투영, 깊이 키, 수직 단축.
- `IsoActor`/`paintIsoActors` — 초상 좌표계로 그려진 `Artist` 를 아이소 맵에
  세우는 다리. 캐릭터 코드를 고치지 않는다.
- `paintIsoGround`/`paintIsoHaze` — 타일 지면과 대기 원근.

### 조작
- `IsoGrid` — 8방향 A*. 코너 컷을 막고, 목표가 막혀 있으면 가장 가까운
  통행 가능 타일로 대신 간다.
- `IsoController` — 경로 추종, 경로 평활화, 최단 경로 회전 보간.
- `screenToTile`/`MoveMarker` — 클릭 피킹과 반응 표식.

### Flame 통합
- `IsoSceneComponent` — 지면·기물·캐릭터·마커를 한 컴포넌트에서. 기물과
  캐릭터가 하나의 깊이 정렬을 거친다.
- 핵심 렌더는 `dart:ui` 만 쓰므로 Flame 없이도 동작한다.
