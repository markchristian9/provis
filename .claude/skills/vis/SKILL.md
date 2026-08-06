---
name: vis
description: provis 라이브러리로 Flutter + Flame 2.5D 아이소메트릭 게임의 비주얼을 코드로 만든다. 스프라이트 없이 Canvas 벡터 패스와 다패스 셰이딩으로 그린다. 다음 작업에 반드시 사용할 것 — (1) 플레이어 캐릭터·몬스터·보스·NPC 를 새로 만들거나 고칠 때, (2) 나무·바위·건물·담장·물웅덩이·길 등 맵 기물을 만들 때, (3) 실루엣·비율·체형·장비·팔레트 등 생성 규칙을 다룰 때, (4) 조명·재질(Finish)·림라이트·그림자를 손볼 때, (5) 포즈·걷기·공격·피격 클립, IK, 망토·머리카락 2차 모션을 만들 때, (6) 아이소 투영·8방향·깊이 정렬·클릭 이동·경로탐색을 다룰 때, (7) provis 패키지 자체를 수정하거나 pub.dev 에 배포할 때. 키워드 — provis, procedural, creature, prop, silhouette, 실루엣, shading, Finish, rim light, pose, isometric, 아이소메트릭, 클릭 이동, pathfinding, Flame, Canvas, Artist.
---

# provis — 절차적 2.5D 아이소메트릭 비주얼

**스프라이트 이미지 없이, 코드만으로** 아이소메트릭 게임 화면을 만든다. 캐릭터·몬스터부터 나무·바위·건물·물까지, 그리고 그것들이 서 있는 지면과 클릭 이동까지 전부 런타임 벡터 패스다.

목표 품질은 **AAA 급** — "캐릭터로 보이는 것"이 아니라, 조명이 일관되고 재질이 구분되며 실루엣만으로 정체가 읽히는 결과물이다.

## 저장소 구조 — 라이브러리와 예제가 나뉘어 있다

```
provis/                      ← pub.dev 배포 패키지 (루트)
├── lib/provis.dart          public barrel — 예제는 이것 하나만 import 한다
├── lib/src/
│   ├── core/                rng · noise · spline · palette · scheme · shading
│   ├── art/                 creature(Artist 계약) · anatomy(부위 헬퍼)
│   ├── rig/ · anim/         body · pose · ik · verlet · clip · animator
│   ├── actor/               spec(HumanoidSpec) · humanoid_renderer
│   ├── iso/                 iso_view · iso_stage · iso_input
│   ├── props/               prop · tree · rock · building · water · ground
│   └── flame/               iso_scene (선택적 Flame 통합)
└── example/                 실행 앱 (별도 패키지)
    ├── lib/main.dart        아이소 필드 — 기물 + 클릭 이동
    ├── lib/gallery.dart     캐릭터 갤러리
    ├── lib/viewer.dart      절차 액터 뷰어
    └── lib/characters/      참조 캐릭터 9종 + roster
```

**어디에 코드를 둘지의 기준**: 재사용 가능한 도구는 `lib/src/`, 특정 게임의 캐릭터·맵은 `example/`(또는 사용자 프로젝트). 이름과 사연이 있는 캐릭터는 라이브러리에 넣지 않는다.

---

## 작업 전 반드시 확인

```bash
find lib -name '*.dart' | sort
grep -rn "SurfaceKind\|Quality\.\|render/surface" lib/   # 0건이어야 정상 (폐기됨)
```

라이브러리를 고쳤으면 **양쪽 다** 검사한다:

```bash
flutter analyze && (cd example && flutter analyze)
flutter test && (cd example && flutter test)
```

---

## 절대 규칙

1. **셰이딩 계보는 `core/shading.dart` 하나뿐이다.** `SurfaceKind`·`Quality`·`paintContactShadow`·`LightRig.keyDir` 은 폐기됐다. 지금은 `Finish` 16종과 `detail`(0..1) 이다.

2. **`LightRig.dir` 은 피사체가 광원을 바라보는 방향이다.** 빛이 나아가는 방향이 아니다. 부호를 뒤집으면 명암이 통째로 반전된다.

3. **씬은 하나의 `LightRig` 를 공유한다** (`LightRig.preset(0~3)`). 갤러리 초상만 `Artist` 별 무드 조명을 갖는 것이 의도된 예외다. 발광체를 그렸으면 **주변 수광 파츠에도 같은 색 반사광을 반영한다.**

4. **아이소 투영은 접지점 하나에만.** 몸을 아이소 평면에 투영하면 인체가 마름모로 찌그러진다. 세로 단축은 렌더 진입부에서 한 번.

5. **접지 그림자 없는 것을 씬에 놓지 않는다.** 아이소는 원근이 없어 높이와 깊이가 화면상 같은 축이다. 그림자가 없으면 떠 있는지 뒤에 있는지 알 수 없다. 캐릭터는 `groundShadow`, 기물은 `propShadow`.

6. **깊이 정렬은 월드 `wx + wy` 로, 기물과 캐릭터를 한 목록에서.** 따로 그리면 나무 뒤로 걸어간 캐릭터가 나무 앞에 나타난다. `paintScene` 또는 `IsoSceneComponent` 를 쓴다.

7. **기물을 놓으면 통행 격자도 함께 막는다.** `IsoSceneComponent.addProp` 이 자동으로 처리한다. 따로 관리하면 반드시 어긋난다.

8. **`math.Random` 금지.** 생성 경로는 `Rng(seed)` 만 쓴다. 같은 `t` 에는 같은 그림이 나와야 한다.

9. **하위 시스템은 `r.branch(salt)` 로 격리한다.** 루트 시드에서 파생하므로 부모를 얼마나 소비한 뒤 불러도 같은 결과다. `test/rng_test.dart` 가 이 불변식을 지킨다.

10. **원형을 먼저 뽑고 그 대역 안에서만 변주한다**(시드 생성 시). 파라미터를 각각 독립 무작위화하면 "특징 없는 평균"만 나온다.

11. **파츠 하나 = `paintSurface` 한 번.** 개별 패스를 호출부에서 재조합하지 않는다.

12. **그림자는 차갑게, 하이라이트는 따뜻하게.** 검정과 섞으면 진흙색이 된다. 색은 전부 HSL 에서 조작한다.

13. **유기체는 스플라인으로, 인공물은 직선을 허용한다.** 살·잎·천·촉수는 `tube`/`blob`/`smoothClosedPath` 를 거친다. 갑옷 패널·검날·바위의 깨진 면·건물 벽은 의도적인 직선이 옳다.

14. **방향은 폭 축소가 아니라 골격 투영으로 만든다.** `solve(body, pose, yaw:)` 가 시상면 스윙과 좌우 폭을 `yaw` 로 섞는다. 이걸 안 넘기면 여덟 방향이 전부 같은 옆모습이 된다. 얼굴은 `Facing.faceVisible`·`bothEyes` 로 **연속 보간**한다 — 이진으로 껐다 켜면 3/4 에서 껌뻑인다.

15. **Flame 과 `mix` 이름이 충돌한다.** `import 'package:flame/game.dart' hide mix;`.

---

## 워크플로우 1 — 맵 기물 만들기

가장 자주 하는 작업이다. 맵이 비어 있으면 아무리 캐릭터가 좋아도 게임 화면이 안 된다.

### 기존 기물 배치

```dart
scene.addProps(plantForest(seed: 42, tiles: spots, kinds: [TreeKind.conifer]));
scene.addProp(PropInstance(
  prop: BuildingProp(seed: 7, tiles: const Size(2, 2), storeys: 2,
                     tileWidth: iso.tileWidth, isoRatio: iso.elevationSin),
  tile: const Offset(5, 8),
));
```

**건물·담장은 `tileWidth`·`isoRatio` 를 맵의 `IsoView` 와 맞춘다.** 안 맞으면 밑면 마름모가 타일 격자와 어긋나 건물이 공중에 뜬 것처럼 보인다.

### 새 기물 타입 추가

`Prop` 을 구현한다. **접지 중심이 원점, `-y` 가 위**인 국소 좌표에 그린다.

- `grounded = true` → 지면에 눕는다(웅덩이·길·풀). 세로가 `iso.shadowRatio` 로 눌린다.
- `grounded = false` → 세워진다(나무·바위·건물). 세로가 `iso.squash` 로 눌린다.
- `walkable` 과 `footprint` 를 정확히 준다 — 경로탐색이 이 값을 쓴다.

→ 상세와 각 기물의 설계 근거: [props.md](references/props.md)

---

## 워크플로우 2 — 캐릭터 만들기

### 1. 시각 논제를 한 문장으로 정한다

**이 단계를 건너뛴 캐릭터는 반드시 평범해진다.** 참조 9종은 전부 논제가 먼저 있었다 — "판금의 반사 분할"(Aldric), "머리 2/3·어깨 5배의 압도"(Gorehide), "단일 스파인으로 흐르는 용"(Vaelmorth).
→ [art-direction.md](references/art-direction.md)

### 2. `Artist` 를 구현한다

`id`·`name`·`camp`·`light`·`paint(Canvas, t, {detail})`. 좌표는 `kStage`(1000×1400), 발바닥은 `kGround`(1332).

### 3. 부위를 조립하고 칠한다

`anatomy.dart` 의 `headShape`/`torsoShape`/`limb`/`handShape`/`hairStrand` + `drawEye`(6겹).
`Surface(color, Finish.xxx)` + `paintSurface`. 마무리 4종이 품질을 결정한다 — `occlude`·`castShadow`·`rimBand`·`panelLine`.
→ [artist-craft.md](references/artist-craft.md)

### 4. 씬에 세운다 — 액터 종류를 먼저 고른다

| | `IsoActor` (Artist) | `RiggedIsoActor` (골격) |
|---|---|---|
| 품질 | 가장 높다 | 중간 |
| 걸을 때 | **정지 자세로 미끄러진다** | 다리가 교차한다 |
| 방향 | 좌우 반전만 | **8방향 — 북=뒷모습, 남=앞모습, 동서=옆모습** |
| 쓰는 곳 | 갤러리·대치 연출·컷신 | **게임플레이 캐릭터·몬스터·NPC** |

```dart
// 게임플레이 — 걷고 돌아야 한다
scene.rigged.add(RiggedIsoActor(
  renderer: HumanoidRenderer(HumanoidSpec.generate(seed)),
  tile: start, height: 195,
));
// 매 프레임: 위치·방향·클립(idle/walk/run)을 한 번에
actor.follow(controller, dt);

// 연출 — 정지 상태 품질이 최우선
scene.actors.add(IsoActor(artist: myHero, tile: tile, height: 200));
```

**캐릭터 키는 타일 폭의 1.2~1.6배.** 넘으면 격자가 묻혀 지면 평면이 사라진다.

---

## 워크플로우 3 — 클릭 이동 붙이기

```dart
final hero = IsoController(tile: start, grid: scene.grid, speed: 3.0);

// 탭
final target = scene.tileAt(event.localPosition.toOffset());
hero.moveTo(target);
scene.marker?.ping(target);      // 눌렀다는 사실을 화면에 보여 준다

// 매 프레임
hero.update(dt);
actor.tile = hero.tile;
actor.facesLeft = hero.facesLeft;
```

- 8방향 A*, 코너 컷 방지(대각선은 양옆이 열려 있을 때만)
- 목표가 막혀 있으면 가장 가까운 통행 가능 타일로 — 벽을 눌렀는데 무반응이면 조작이 고장난 것처럼 느껴진다
- 회전은 `turnTime`(0.14초)에 걸쳐 최단 경로 보간. **즉시 스냅하지 않는다**

→ [isometric.md](references/isometric.md)

---

## 워크플로우 4 — 시드로 찍어내기

이름 없는 군중은 `HumanoidSpec.generate(seed)`. 원형을 먼저 뽑고 **겹치지 않는 대역**에서 `r.bell()` 로 변주한다.
→ [procgen.md](references/procgen.md)

---

## 품질 체크리스트

**실루엣**
- [ ] 검게 칠했을 때 정체가 구분되는가
- [ ] 48px 로 축소해도 구분되는가
- [ ] 큰 도형 1 + 중간 2~3 + 작은 여럿의 크기 위계가 있는가

**셰이딩**
- [ ] `Finish` 를 재질에 맞게 골랐는가 (16종 중)
- [ ] 겹친 파츠에 `occlude`/`castShadow` 를 넣었는가 — 없으면 종이처럼 겹쳐 보인다
- [ ] 시선이 머무는 곳에 `rimBand` 를 썼는가
- [ ] 눈이 6겹인가 (`drawEye`)

**맵 기물**
- [ ] `propShadow` 로 지면에 붙였는가
- [ ] 같은 종류를 여러 개 놓을 때 시드·크기·`timeOffset` 이 개체마다 다른가
- [ ] `footprint`·`walkable` 이 실제 형상과 맞는가
- [ ] 건물의 `tileWidth`·`isoRatio` 가 맵의 `IsoView` 와 같은가
- [ ] 세 면(좌벽·우벽·지붕)의 명도가 확실히 갈리는가

**아이소 씬**
- [ ] 기물과 캐릭터가 **하나의 깊이 정렬**을 거치는가
- [ ] 씬 전체가 같은 `LightRig` 를 쓰는가
- [ ] 캐릭터 키가 타일 폭의 1.2~1.6배인가
- [ ] `paintIsoHaze` 로 원경이 흐려지는가 — 비용 대비 효과가 가장 큰 한 겹

**애니메이션**
- [ ] 정지 상태에 호흡이 있는가 (`breathe`)
- [ ] 좌우 팔다리에 위상차가 있는가 (완전 대칭 = 마네킹)
- [ ] 공격이 **예비 35% / 타격 12% / 회복 53%** 비대칭인가

**분포** (시드 생성 시)
- [ ] 시드 24개가 서로 구별되는가
- [ ] `range` 대신 `bell` 을 썼는가
- [ ] 같은 시드가 여전히 같은 결과를 내는가

---

## 참조 문서

| 문서 | 언제 읽는가 |
|------|------------|
| [props.md](references/props.md) | 맵 기물 — 6종의 설계 근거, `Prop` 계약, 새 기물 추가법 |
| [artist-craft.md](references/artist-craft.md) | 셰이딩 제1 원리, `Finish` 16종, `core/shading.dart` 전 API, `Artist` 계약, `anatomy.dart`, 얼굴 6겹 |
| [art-direction.md](references/art-direction.md) | 시각 논제 설계, 비율 왜곡, 참조 9종의 실제 논제, 설계서 양식 |
| [isometric.md](references/isometric.md) | 아이소 투영 수식, `Artist` 를 맵에 세우는 법, 클릭 이동, 8방향, y-sort |
| [architecture.md](references/architecture.md) | 레이어 규약, 좌표계, 폐기 API 대조표, Flame 이름 충돌 |
| [silhouette.md](references/silhouette.md) | 형상 언어, `tube`/`blob`/`web`, 두께 프로파일, squint test |
| [procgen.md](references/procgen.md) | `Rng`/`Noise`/`Palette`, 원형 다이얼, 인체 비율표 |
| [animation.md](references/animation.md) | `Pose`/`solve`/IK/베를레, 클립 레시피, 타이밍 표 |
| [performance.md](references/performance.md) | 비용 표, 디테일 티어, 캐싱 |
| [publishing.md](references/publishing.md) | pub.dev 배포 — 체크리스트, 버전 정책, public API 관리 |

## 실행

```bash
cd example
flutter run -t lib/main.dart      # 아이소 필드 — 기물 + 클릭 이동
flutter run -t lib/gallery.dart   # 캐릭터 갤러리
flutter run -t lib/viewer.dart    # 절차 액터 뷰어
```

---

## 자주 하는 실수

| 증상 | 원인 | 처방 |
|------|------|------|
| `SurfaceKind`·`Quality` 가 없다 | 폐기된 API | `Finish` 16종 + `detail`(0..1) |
| 명암이 통째로 뒤집힘 | `dir` 을 빛의 진행 방향으로 착각 | `dir` = 피사체 → 광원 |
| 나무 뒤 캐릭터가 나무 앞에 보인다 | 기물·캐릭터를 따로 그림 | `paintScene` 하나로 |
| 캐릭터가 나무를 통과한다 | 격자를 안 막음 | `scene.addProp` 사용 |
| 건물이 공중에 뜬다 | `isoRatio` 불일치 | 맵의 `iso.elevationSin` 을 넘긴다 |
| 지면 격자가 안 보인다 | 캐릭터·기물이 너무 큼 | 키를 타일 폭의 1.2~1.6배로 |
| 숲이 한 몸처럼 흔들린다 | `timeOffset` 이 같음 | 개체마다 다르게 |
| 파츠가 종이처럼 겹쳐 보인다 | 접촉 그림자 없음 | `occlude` + `castShadow` |
| 클릭했는데 반응이 없다 | 목표가 막힘 + 표식 없음 | `MoveMarker.ping`, A* 가 근처 타일로 대체 |
| 클릭한 곳과 다른 데로 간다 | 카메라 오프셋 불일치 | `scene.tileAt()` 사용 |
| 걸을 때 자세가 그대로다 | `IsoActor`(Artist)를 게임플레이에 씀 | `RiggedIsoActor` + `follow()` |
| 북쪽으로 가도 뒷모습이 안 나온다 | 같은 원인 | `RiggedIsoActor` 는 8방향을 낸다 |
| 여덟 방향이 전부 옆모습이다 | `solve` 에 `yaw` 미전달 | `solve(body, pose, yaw: facing.yaw)` |
| 3/4 에서 얼굴이 갑자기 사라진다 | `toCamera` 로 이진 판정 | `faceVisible`·`bothEyes` 로 연속 알파 |
| 공격 자세로 굳어 걸어 다닌다 | 한 번짜리 클립이 안 끝남 | `update` 가 자동 복귀시킨다 — `play()` 로만 전환 |
| `ambiguous_import: mix` | Flame 의 vector_math 충돌 | `hide mix` |
