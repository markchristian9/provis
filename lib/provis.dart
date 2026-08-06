/// **provis** — Flutter Flame 을 위한 절차적 2.5D 아이소메트릭 비주얼 툴킷.
///
/// 스프라이트 이미지 한 장 없이, 코드만으로 게임 화면을 그린다. 캐릭터·몬스터,
/// 나무·바위·건물 같은 맵 기물, 그리고 그것들이 서 있는 아이소메트릭 지면까지
/// 전부 런타임에 벡터 패스로 생성한다.
///
/// 스프라이트를 쓰지 않는 대가로 얻는 것은 세 가지다.
/// 시드 하나로 무한한 변주를 만들 수 있고, 조명을 바꾸면 화면 전체가 한꺼번에
/// 반응하며, 해상도에 상한이 없다.
///
/// ## 다섯 갈래
///
/// | 무엇 | 시작점 |
/// |---|---|
/// | 재질과 조명 | [Surface] · [Finish] · [LightRig] · [paintSurface] |
/// | 캐릭터 | [Artist] · `anatomy.dart` 부위 헬퍼 · [HumanoidSpec] |
/// | 맵 기물 | [Prop] · [TreeProp] · [RockProp] · [BuildingProp] · [WaterProp] |
/// | 아이소 배치 | [IsoView] · [IsoActor] · [paintIsoActors] · [paintIsoGround] |
/// | 조작 | [IsoController] · [screenToTile] · [IsoGrid] |
///
/// ## 최소 예제
///
/// ```dart
/// // 나무 한 그루를 타일 (3, 4) 에 세운다.
/// final iso = const IsoView(tileWidth: 156, tileHeight: 78);
/// final tree = TreeProp(seed: 7);
/// paintProp(canvas, PropInstance(prop: tree, tile: const Offset(3, 4)),
///           iso, LightRig.daylight, time);
/// ```
///
/// 실행 가능한 전체 예제는 저장소의 `example/` 을 참조한다.
library;

// ── 기반: 난수·노이즈·형상·색 ────────────────────────────────────────────
export 'src/core/rng.dart';
export 'src/core/noise.dart';
export 'src/core/spline.dart';
export 'src/core/palette.dart';
export 'src/core/scheme.dart';

// ── 재질과 조명 (유일한 셰이딩 계보) ─────────────────────────────────────
export 'src/core/shading.dart';

// ── 캐릭터 ───────────────────────────────────────────────────────────────
export 'src/art/creature.dart';
export 'src/art/anatomy.dart';

// ── 골격·포즈·애니메이션 ─────────────────────────────────────────────────
export 'src/rig/body.dart';
export 'src/rig/pose.dart';
export 'src/rig/ik.dart';
export 'src/anim/verlet.dart';
export 'src/anim/clip.dart';
export 'src/anim/animator.dart';
export 'src/anim/library.dart';

// ── 시드 기반 휴머노이드 ─────────────────────────────────────────────────
export 'src/actor/spec.dart';
export 'src/actor/humanoid_renderer.dart';

// ── 아이소메트릭: 카메라·배치·조작 ───────────────────────────────────────
export 'src/iso/iso_view.dart';
export 'src/iso/iso_stage.dart';
export 'src/iso/iso_input.dart';

// ── Flame 통합 (선택) ────────────────────────────────────────────────────
// 핵심 렌더는 dart:ui 만으로 동작한다. 이 파일만 Flame 에 의존한다.
export 'src/flame/iso_scene.dart';

// ── 맵 기물 ──────────────────────────────────────────────────────────────
export 'src/props/prop.dart';
export 'src/props/tree.dart';
export 'src/props/rock.dart';
export 'src/props/building.dart';
export 'src/props/water.dart';
export 'src/props/ground.dart';
