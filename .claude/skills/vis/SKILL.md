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
│   ├── props/               prop · prop_kit · tree · rock · building
│   │                        water · ground · flora · terrain
│   ├── audio/               dsp · wave · sfx · voice · bgm · bank
│   │                        (합성만 한다 — 재생은 앱의 몫)
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

**공개 API 를 추가했으면 세 가지를 한다.**

1. `lib/provis.dart` 에 `export` 추가 — 빠뜨리면 라이브러리는 빌드되지만
   소비자는 그 기능에 닿을 수 없다.
2. `example/test/public_api_test.dart` 에 호출 한 줄 추가 — 이 테스트가 barrel
   하나만 import 해서 소비자 시나리오를 돌린다.
3. README 예제가 여전히 컴파일되는지 확인 — 새 사용자가 처음 만나는 코드다.

```bash
# export 누락 자동 점검
for f in $(find lib/src -name '*.dart' | sed 's|lib/||'); do
  grep -q "export '$f'" lib/provis.dart || echo "누락: $f"
done
```

---

## 절대 규칙

1. **셰이딩 계보는 `core/shading.dart` 하나뿐이다.** `SurfaceKind`·`Quality`·`paintContactShadow`·`LightRig.keyDir` 은 폐기됐다. 지금은 `Finish` 19종과 `detail`(0..1) 이다.

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

15. **방향 수를 제한하지 않는다.** 스프라이트를 굽지 않으므로 `yaw` 는 임의의 실수이고, 8·16·32·360 분할의 렌더 비용이 실측상 동일하다. 기본은 연속이며, 그리드 전투 상태·히트박스처럼 **이유가 있을 때만** `facing.snap(n)` 으로 스냅한다.

16. **Flame 과 `mix` 이름이 충돌한다.** `import 'package:flame/game.dart' hide mix;`.

---

## 워크플로우 1 — 맵 기물 만들기

가장 자주 하는 작업이다. 맵이 비어 있으면 아무리 캐릭터가 좋아도 게임 화면이 안 된다.

### 리얼함은 셰이딩이 아니라 이 넷에서 나온다

기물이 클립아트로 보이는 이유는 거의 언제나 같다. **재질을 잘못 골라서가 아니라, 아래 넷 중 하나가 빠져서**다.

1. **실루엣이 재질을 말하는가.** 잎 뭉치의 윤곽은 매끄러운 타원이 아니라 돌기가 반복되는 선이다(`leafCluster`). 이 신호 없이 초록을 칠하면 무슨 짓을 해도 풍선이다. 전나무는 각진 톱니(`coniferTier`), 바위는 직선으로 깨진 면, 잎은 가장자리에서 몇 장이 삐져나온다(`scatterLeaves`).
2. **덩어리 안에 덩어리가 있는가.** 수관은 잎 뭉치 여럿(`lobeLight`), 벽은 돌 하나하나(`courseTexture`), 지붕은 기와 한 줄. **단위가 보여야 관객이 크기를 읽는다.** 단색 면은 스케일이 없다.
3. **접지가 두 겹인가.** 넓고 옅은 `propShadow` 만 있으면 그림자 위에 얹힌 스티커다. 좁고 짙은 `contactAO` + 밑동을 감싸는 `rootSkirt` 가 함께 있어야 박힌다.
4. **빛이 통과하는가.** 얇은 것(잎·꽃잎)은 그늘 쪽이 그냥 어두우면 플라스틱이다. `Finish.foliage` + `translucentBand` 가 광원 **반대쪽** 가장자리를 띄운다.

### 기존 기물 배치

```dart
scene.addProps(plantForest(seed: 42, tiles: spots,
    kinds: [TreeKind.conifer, TreeKind.pine, TreeKind.bush]));
scene.addProp(PropInstance(
  prop: BuildingProp(seed: 7, tiles: const Size(2, 2), storeys: 2,
                     roof: RoofStyle.gable, ridgeAlongX: true,
                     tileWidth: iso.tileWidth, isoRatio: iso.elevationSin),
  tile: const Offset(5, 8),
));
```

**건물·담장·그루터기·통나무·울타리·언덕은 `tileWidth`·`isoRatio` 를 맵의 `IsoView` 와 맞춘다.** 안 맞으면 밑면 마름모가 타일 격자와 어긋나 기물이 공중에 뜬 것처럼 보인다.

### 무엇을 놓을 수 있는가

| 파일 | 기물 |
|---|---|
| `tree.dart` | `TreeProp` 7종 — `broadleaf`·`conifer`·`pine`·`dead`·`blossom`·`willow`·`bush`, `plantForest` |
| `building.dart` | `BuildingProp`(벽 5종 × 지붕 5종 × 표면 4종) · `WallProp` |
| `rock.dart` | `RockProp` · `PebbleField` |
| `water.dart` | `WaterProp`(갈대·물가 포함) · `LavaProp` |
| `ground.dart` | `GroundPatch`(풀·꽃) · `PathPatch`(바퀴자국) |
| `flora.dart` | `GrassTuft` · `FlowerBed` · `StumpProp` · `LogProp` · `FenceProp` |
| `terrain.dart` | `MoundProp` — 지면에서 솟은 둔덕 |
| `prop_kit.dart` | 공용 형상·텍스처 도구 |

**큰 기물만 놓으면 그 사이가 빈 장판으로 남는다.** 화면의 밀도는 발치의 작은 것들이 만든다 — 풀 포기, 꽃, 그루터기, 쓰러진 통나무.

### 새 기물 타입 추가

`Prop` 을 구현한다. **접지 중심이 원점, `-y` 가 위**인 국소 좌표에 그린다.

- `grounded = true` → 지면에 눕는다(웅덩이·길·풀밭). 세로가 `iso.shadowRatio` 로 눌린다.
- `grounded = false` → 세워진다(나무·바위·건물·풀 포기). 세로가 `iso.squash` 로 눌린다.
- `walkable` 과 `footprint` 를 정확히 준다 — 경로탐색이 이 값을 쓴다.

→ 상세와 각 기물의 설계 근거: [props.md](references/props.md)

---

## 워크플로우 2 — 캐릭터 만들기

**길이 둘이다. 먼저 어느 쪽인지 정한다.**

| | 선언형 — `BuiltArtist` | 손그림 — `Artist` 구현 |
|---|---|---|
| 분량 | **한 명 15~40줄** | 한 명 700~1300줄 |
| 초상과 게임 액터 | **같은 렌더러 — 어긋날 수 없다** | 서로 다른 코드 — `build` 를 반드시 선언해야 한다 |
| 개성의 상한 | 명세가 표현하는 범위 | 없음 |
| 쓰는 곳 | **명부를 채우는 대다수** | 간판·보스 소수 |

**기본은 선언형이다.** 손그림은 그 캐릭터가 게임의 얼굴이고 명세로 표현할 수 없는 형상이 있을 때만 고른다.
→ 상세: [character-creation.md](references/character-creation.md)

### 길 A — 선언형 (기본)

```dart
final garran = BuiltArtist(
  id: 'garran',
  name: 'Garran',
  title: 'Shieldbearer of the Pass',
  blurb: '고갯길을 혼자 막아선 방패병.',
  build: CharacterBuild(
    archetype: Archetype.knight,      // 체형·기본 장비의 대역
    sex: Sex.male,
    palette: paletteOf(               // 넷만 고르면 나머지 일곱은 파생된다
      skin: Color(0xFFC08A66), hair: Color(0xFF3A2A1E),
      cloth: Color(0xFF7A2E2E), accent: Color(0xFFD9A441),
    ),
    weapon: WeaponKind.sword,
    headGear: HeadGear.halfHelm,
    hasShield: true, hasPauldrons: true,
    armorHeaviness: 0.9, muscle: 0.8,
  ),
);
```

**`accent` 가 그 캐릭터의 정체성이다** — 명부 카드 테두리, 눈, 발광, 역광이 전부 여기서 나온다. 직업마다 색 대역을 갈라 두면 멀리서도 역할이 읽힌다.

**`headGear` 와 `weapon` 은 명시하라.** 비워 두면 시드 생성기가 정하므로, 후드를 원하지 않은 마법사가 후드를 쓰고 나타난다.

### 길 B — 손그림

1. **시각 논제를 한 문장으로 정한다.** 이 단계를 건너뛴 캐릭터는 반드시 평범해진다. 참조 5종은 전부 논제가 먼저 있었다 — "판금의 반사 분할"(Aldric), "머리 2/3·어깨 5배의 압도"(Gorehide), "단일 스파인으로 흐르는 용"(Vaelmorth). → [art-direction.md](references/art-direction.md)
2. **`Artist` 를 구현한다.** `id`·`name`·`camp`·`light`·`paint(Canvas, t, {detail})`. 좌표는 `kStage`(1000×1400), 발바닥은 `kGround`(1332).
3. **부위를 조립하고 칠한다.** `anatomy.dart` 의 `headShape`/`torsoShape`/`limb`/`handShape`/`hairStrand` + `drawEye`(6겹). `Surface(color, Finish.xxx)` + `paintSurface`. 마무리 4종이 품질을 결정한다 — `occlude`·`castShadow`·`rimBand`·`panelLine`. → [artist-craft.md](references/artist-craft.md)
4. **`build` 를 반드시 오버라이드한다.** 이것이 게임 맵의 골격 액터로 건너가는 유일한 다리다.

```dart
@override
CharacterBuild get build => CharacterBuild(
      archetype: Archetype.mage,
      sex: Sex.female,
      palette: paletteOf(skin: …, hair: …, cloth: …, accent: accent),
      weapon: WeaponKind.staff,
      headGear: HeadGear.none,   // 초상에 없으면 반드시 none 을 명시
      hasCape: true, glowRunes: true,
    );
```

**빠뜨리면 명부와 게임 화면이 다른 인물이 된다.** 실제로 은발 마법사를 골랐는데 맵에서는 금발 전사가 걸어 나온 적이 있다. `example/test/identity_sheet_test.dart` 가 이 회귀를 막는다 — 초상과 8방향을 한 줄에 나란히 뽑아 눈으로 대조하고, `build.palette` 가 비어 있으면 실패한다.

### 씬에 세운다 — 액터 종류를 먼저 고른다

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
  iso: iso,          // ← 맵과 같은 것. 없으면 보폭이 어긋나 발이 미끄러진다
));
// 매 프레임: 위치·방향·클립(idle/walk/run)·보폭을 한 번에.
// 씬이 시간을 이미 밀었으므로 follow 는 입력만 갱신한다.
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
- [ ] `Finish` 를 재질에 맞게 골랐는가 (19종 중)
- [ ] 겹친 파츠에 `occlude`/`castShadow` 를 넣었는가 — 없으면 종이처럼 겹쳐 보인다
- [ ] 시선이 머무는 곳에 `rimBand` 를 썼는가
- [ ] 눈이 6겹인가 (`drawEye`)

**맵 기물**
- [ ] 접지가 **두 겹**인가 — `propShadow`(넓고 옅다) + `contactAO`(좁고 짙다)
- [ ] 실루엣이 재질을 말하는가 — 잎은 돌기, 전나무는 톱니, 바위는 직선 면
- [ ] 면 안에 **반복 단위**가 보이는가 — 돌·널·기와 한 장이 크기를 알려 준다
- [ ] 얇은 것에 투과광을 넣었는가 (`Finish.foliage`·`translucentBand`)
- [ ] 같은 종류를 여러 개 놓을 때 시드·크기·`timeOffset` 이 개체마다 다른가
- [ ] `footprint`·`walkable` 이 실제 형상과 맞는가
- [ ] 건물의 `tileWidth`·`isoRatio` 가 맵의 `IsoView` 와 같은가
- [ ] 세 면(좌벽·우벽·지붕)의 명도가 확실히 갈리는가
- [ ] 지붕이 벽에 **처마 그림자**를 드리우는가 (`eaveShadow`)
- [ ] 블러를 파츠마다 부르지 않았는가 — 점을 한 Path 로 모아 한 번에 태운다

**아이소 씬**
- [ ] 기물과 캐릭터가 **하나의 깊이 정렬**을 거치는가
- [ ] 씬 전체가 같은 `LightRig` 를 쓰는가
- [ ] 캐릭터 키가 타일 폭의 1.2~1.6배인가
- [ ] 지면이 **체커 타일이 아닌가** — 얼룩 두 층 + 거리 감쇠 + 가장자리 흙 두께
- [ ] 큰 기물 사이를 밑풀(`GrassTuft`·`FlowerBed`)로 메웠는가
- [ ] `paintIsoHaze` 로 원경이 흐려지는가 — 비용 대비 효과가 가장 큰 한 겹

**애니메이션**
- [ ] 정지 상태에 호흡이 있는가 (`breathe`)
- [ ] 좌우 팔다리에 위상차가 있는가 (완전 대칭 = 마네킹)
- [ ] 공격이 **예비 35% / 타격 12% / 회복 53%** 비대칭인가
- [ ] 액터에 맵의 `IsoView` 를 넘겼는가 — 안 넘기면 발이 미끄러진다
- [ ] 판정·소리·이펙트를 `ClipEvent` 로 걸었는가 (프레임 번호가 아니라)
- [ ] 30fps 와 120fps 에서 같은 속도로 재생되는가 (`test/anim_timing_test.dart`)

**분포** (시드 생성 시)
- [ ] 시드 24개가 서로 구별되는가
- [ ] `range` 대신 `bell` 을 썼는가
- [ ] 같은 시드가 여전히 같은 결과를 내는가

---

## 참조 문서

| 문서 | 언제 읽는가 |
|------|------------|
| [character-creation.md](references/character-creation.md) | **캐릭터 만들기** — 선언형 vs 손그림, `CharacterBuild`, 팔레트, 직업별 대역표, 초상↔게임 액터 대조 검증, 흔한 실패, 파츠 렌더 순서 |
| [props.md](references/props.md) | 맵 기물 — 리얼함의 네 조건, 전 기물의 설계 근거, `Prop` 계약, `prop_kit` API, 새 기물 추가법 |
| [artist-craft.md](references/artist-craft.md) | 셰이딩 제1 원리, `Finish` 19종, `core/shading.dart` 전 API, `Artist` 계약, `anatomy.dart`, 얼굴 6겹 |
| [art-direction.md](references/art-direction.md) | 시각 논제 설계, 비율 왜곡, 참조 9종의 실제 논제, 설계서 양식 |
| [isometric.md](references/isometric.md) | 아이소 투영 수식, `Artist` 를 맵에 세우는 법, 클릭 이동, 8방향, y-sort |
| [architecture.md](references/architecture.md) | 레이어 규약, 좌표계, 폐기 API 대조표, Flame 이름 충돌 |
| [silhouette.md](references/silhouette.md) | 형상 언어, `tube`/`blob`/`web`, 두께 프로파일, squint test |
| [procgen.md](references/procgen.md) | `Rng`/`Noise`/`Palette`, 원형 다이얼, 인체 비율표 |
| [animation.md](references/animation.md) | `Pose`/`solve`/IK/베를레, 클립 레시피, 타이밍 표 |
| [performance.md](references/performance.md) | 비용 표, 디테일 티어, 캐싱 |
| [publishing.md](references/publishing.md) | pub.dev 배포 — 체크리스트, 버전 정책, public API 관리 |
| **`pc` 스킬** | **조작되는 주인공과 전투** — PC 를 맵에 세우고, 공격 클립을 저작하고, 입력 → `ClipEvent` 판정 → 히트스톱 → 피격 반응까지 배선한다. 이 문서가 "어떻게 그리는가"라면 그쪽은 "어떻게 손에 쥐여지는가"다 |

## 실행

```bash
cd example
flutter run -t lib/main.dart              # 아이소 필드 — 기물 + 클릭 이동
flutter run -t lib/gallery.dart           # 캐릭터 갤러리
flutter run -t lib/viewer.dart            # 절차 액터 뷰어
flutter run -t lib/create_character.dart  # 캐릭터 작업대 — 값을 바꾸며 만들고 코드를 복사
```

**캐릭터를 만들 때는 작업대부터 띄운다.** 왼쪽에서 값을 바꾸면 명부 초상과 게임 액터 8방향이 함께 갱신되고, 하단에 그대로 붙여 넣을 수 있는 `BuiltArtist` 선언이 나온다.

```bash
# 초상과 게임 액터가 같은 인물인지 시트로 대조
flutter test test/identity_sheet_test.dart && open build/art/identity_*.png
```

---

## 자주 하는 실수

| 증상 | 원인 | 처방 |
|------|------|------|
| `SurfaceKind`·`Quality` 가 없다 | 폐기된 API | `Finish` 19종 + `detail`(0..1) |
| 명암이 통째로 뒤집힘 | `dir` 을 빛의 진행 방향으로 착각 | `dir` = 피사체 → 광원 |
| 나무 뒤 캐릭터가 나무 앞에 보인다 | 기물·캐릭터를 따로 그림 | `paintScene` 하나로 |
| 캐릭터가 나무를 통과한다 | 격자를 안 막음 | `scene.addProp` 사용 |
| 건물이 공중에 뜬다 | `isoRatio` 불일치 | 맵의 `iso.elevationSin` 을 넘긴다 |
| 지면 격자가 안 보인다 | 캐릭터·기물이 너무 큼 | 키를 타일 폭의 1.2~1.6배로 |
| 숲이 한 몸처럼 흔들린다 | `timeOffset` 이 같음 | 개체마다 다르게 |
| 나무가 초록 풍선이다 | 실루엣이 매끄러운 타원 | `leafCluster` + `scatterLeaves` |
| 잎 그늘이 검게 죽는다 | 투과광 없음 | `Finish.foliage` + `translucentBand` |
| 줄기가 흰 파이프다 | 좁은 형상에 `rim` 이 다 먹음 | 줄기·가지는 `rim: false` |
| 전나무가 매끈한 삼각형이다 | 톱니를 스플라인에 통과시킴 | `coniferTier` 는 직선으로 그린다 |
| 벽·지붕이 밋밋하다 | 반복 단위가 없음 | `courseTexture`, 기와 열 |
| 지붕이 벽을 덮어 버섯이 된다 | 마루를 밑면 전체에 덮음 | 마루는 월드 축과 평행 (`ridgeAlongX`) |
| 지붕이 종잇장이다 | 처마 두께·그림자 없음 | 처마 널 + `eaveShadow` |
| 기물이 그림자 위에 얹혀 보인다 | 접지가 한 겹 | `contactAO` + `rootSkirt` 추가 |
| 지면이 격자무늬 장판이다 | 체커 타일 | `paintIsoGround` — 얼룩·감쇠·가장자리 흙 |
| 프레임이 무너진다 | 파츠마다 블러 | 점을 한 Path 로 모아 블러 한 번 |
| 파츠가 종이처럼 겹쳐 보인다 | 접촉 그림자 없음 | `occlude` + `castShadow` |
| 클릭했는데 반응이 없다 | 목표가 막힘 + 표식 없음 | `MoveMarker.ping`, A* 가 근처 타일로 대체 |
| 클릭한 곳과 다른 데로 간다 | 카메라 오프셋 불일치 | `scene.tileAt()` 사용 |
| 걸을 때 자세가 그대로다 | `IsoActor`(Artist)를 게임플레이에 씀 | `RiggedIsoActor` + `follow()` |
| 북쪽으로 가도 뒷모습이 안 나온다 | 같은 원인 | `RiggedIsoActor` 는 8방향을 낸다 |
| 여덟 방향이 전부 옆모습이다 | `solve` 에 `yaw` 미전달 | `solve(body, pose, yaw: facing.yaw)` |
| 3/4 에서 얼굴이 갑자기 사라진다 | `toCamera` 로 이진 판정 | `faceVisible`·`bothEyes` 로 연속 알파 |
| 공격 자세로 굳어 걸어 다닌다 | 한 번짜리 클립이 안 끝남 | `update` 가 자동 복귀시킨다 — `play()` 로만 전환 |
| 발이 얼음판처럼 미끄러진다 | 액터에 맵의 `IsoView` 미전달 | `RiggedIsoActor(iso: iso)` |
| 모든 동작이 두 배로 빠르다 | 씬과 `follow` 가 각자 시간을 밈 | 씬이 주인 — `follow` 는 입력만 |
| 연타하면 포즈가 튄다 | 전환 도중 전환에서 혼합을 버림 | 화면에 있던 포즈에서 잇는다 |
| 판정이 그림과 어긋난다 | 프레임 번호로 타이밍 | `ClipEvent` + `animator.fired` |
| 명부와 게임 화면이 다른 인물 | `Artist.build` 미오버라이드 | `build` 에 실제 색·장비 선언 → [character-creation.md](references/character-creation.md) |
| 마법사가 원치 않은 후드를 쓴다 | `headGear` 미지정 → 시드가 결정 | `headGear: HeadGear.none` 을 **명시** |
| 게임 액터의 얼굴이 매끈한 공 | 머리카락·후드를 얼굴 **위에** 그림 | 뒤통수는 얼굴 전, 앞머리는 얼굴 후 (`_hairBack`/`_hairFront`) |
| 어깨가 머리보다 크다 | 폴드론이 어깨 관절 중심에 과대 | 팔 방향으로 밀고 `r * 1.5` 로 |
| 칼끝이 지면을 뚫는다 | 손목 각도를 그대로 따름 | 쉴 때 세우고 휘두를 때 손을 따름 |
| 허벅지가 거대한 흰 캡슐 | 다리 전체를 판금 관 하나로 | 쿠이스·그리브 조각으로 분리 |
| 팔이 몸통에 묻혀 사라진다 | 팔과 몸통이 같은 판금 재질 | 가까운 팔 밑에 어두운 윤곽 한 겹 |
| `ambiguous_import: mix` | Flame 의 vector_math 충돌 | `hide mix` |
