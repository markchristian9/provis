# Changelog

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
