import 'dart:math' as math;

import '../rig/pose.dart';

/// 균등 간격 키프레임 배열을 Catmull-Rom 으로 보간한다.
///
/// 선형 보간은 관절 속도가 키마다 계단처럼 꺾여 로봇처럼 보인다. 곡률이
/// 연속인 보간을 쓰면 키를 8개만 찍어도 손으로 다듬은 듯한 가감속이 나온다.
double _catmull(double p0, double p1, double p2, double p3, double t) {
  final t2 = t * t;
  final t3 = t2 * t;
  return 0.5 *
      ((2 * p1) +
          (-p0 + p2) * t +
          (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 +
          (-p0 + 3 * p1 - 3 * p2 + p3) * t3);
}

/// 순환 트랙 표본화. 마지막 키와 첫 키가 이어지므로 이음매가 없다.
double sampleLoop(List<double> keys, double t) {
  final n = keys.length;
  if (n == 0) return 0;
  if (n == 1) return keys[0];
  final x = (t - t.floorToDouble()) * n;
  final i = x.floor();
  final f = x - i;
  return _catmull(
    keys[(i - 1 + n) % n],
    keys[i % n],
    keys[(i + 1) % n],
    keys[(i + 2) % n],
    f,
  );
}

/// 원샷 트랙 표본화. 배열의 첫 키가 t=0, 마지막 키가 t=1 이다.
double sampleOnce(List<double> keys, double t) {
  final n = keys.length;
  if (n == 0) return 0;
  if (n == 1) return keys[0];
  final u = t.clamp(0.0, 1.0);
  final x = u * (n - 1);
  final i = x.floor().clamp(0, n - 2);
  final f = x - i;
  double at(int k) => keys[k.clamp(0, n - 1)];
  return _catmull(at(i - 1), at(i), at(i + 1), at(i + 2), f);
}

/// 한 프레임에 소비할 수 있는 최대 시간(초).
///
/// 프레임이 한 번 크게 밀리면(에셋 로드·GC·창 전환·브레이크포인트) 그 `dt` 를
/// 그대로 먹은 애니메이션은 예비동작을 통째로 건너뛰고 타격 자세에서 순간이동
/// 하며, 이동 컨트롤러는 몇 타일을 한 번에 넘어간다. 잘라 두면 최악의 경우
/// 재생이 잠깐 느려질 뿐 **포즈가 튀지 않는다** — 눈에는 후자가 훨씬 낫다.
///
/// 1/20 초는 60fps 세 프레임이다. 이보다 짧게 잡으면 30fps 기기에서 상시
/// 슬로모션이 되고, 길게 잡으면 히치 한 번에 동작이 건너뛴다.
const double kMaxFrameStep = 1 / 20;

/// 클립 위의 한 시점 표식.
///
/// 히트박스·사운드·이펙트를 "몇 번째 프레임"이 아니라 **클립의 어느 지점**에
/// 건다. 프레임률이 흔들려도, 보폭 동기화로 재생 배속이 바뀌어도 언제나 같은
/// 자세에서 정확히 한 번 터지므로 타격과 그림이 어긋나지 않는다.
///
/// ```dart
/// if (actor.animator.fired.contains('strike')) {
///   world.applyHit(actor);
///   actor.animator.hitstop(0.06);
/// }
/// ```
class ClipEvent {
  const ClipEvent(this.name, this.at);

  /// 게임 쪽에서 비교하는 식별자.
  final String name;

  /// 클립 안의 정규화 시각 0..1.
  final double at;
}

/// 관절별 키프레임 트랙의 묶음.
///
/// 클립은 [Pose] 와 같은 필드를 리스트로 갖는다. 지정하지 않은 트랙은
/// 기본값으로 남으므로, 죽음 애니메이션처럼 상체만 움직이는 클립은
/// 필요한 트랙만 적으면 된다.
class Clip {
  const Clip({
    required this.name,
    required this.label,
    required this.duration,
    this.loop = true,
    this.blendIn = 0.18,
    this.autoSeconds = 3.2,
    this.holdAtEnd = false,
    this.repeatDelay = 0.28,
    this.events = const [],
    this.strideCycle = 0,
    this.rootX,
    this.rootY,
    this.rootRot,
    this.spine,
    this.chest,
    this.neck,
    this.head,
    this.nearShoulder,
    this.nearElbow,
    this.nearWrist,
    this.farShoulder,
    this.farElbow,
    this.farWrist,
    this.nearHip,
    this.nearKnee,
    this.nearAnkle,
    this.farHip,
    this.farKnee,
    this.farAnkle,
    this.breath,
    this.squash,
    this.weaponSwing,
    this.mouth,
    this.eyeOpen,
    this.capeFlow,
    this.impact,
  });

  /// 코드에서 참조하는 식별자.
  final String name;

  /// 버튼에 표시되는 이름.
  final String label;

  /// 한 사이클(루프) 또는 전체 재생(원샷) 길이(초).
  final double duration;

  final bool loop;

  /// 다른 클립에서 넘어올 때의 크로스페이드 시간(초).
  final double blendIn;

  /// AUTO 순환에서 이 클립에 머무는 시간(초). 원샷은 반복 재생된다.
  final double autoSeconds;

  /// 원샷이 끝난 뒤 마지막 포즈를 유지할지. 죽음처럼 되돌아오지 않는
  /// 동작만 true 다.
  final bool holdAtEnd;

  /// 원샷을 자동 반복할 때 끝과 다음 시작 사이의 정지 시간(초).
  /// 뷰어에서 동작을 반복해 관찰할 수 있도록 두는 여백이다.
  final double repeatDelay;

  /// 이 클립이 지나가며 알리는 시점들. [Animator.fired] 로 읽는다.
  final List<ClipEvent> events;

  /// 한 사이클이 나아가는 거리 — **다리 길이의 배수**. 0 이면 제자리 동작이다.
  ///
  /// 길이를 픽셀이나 타일이 아니라 다리 길이로 적는 이유는 클립 데이터가
  /// 관절 각도만 담는다는 규약과 같다 — 다리가 짧은 몬스터와 8등신 영웅이
  /// 같은 클립을 써도 각자의 보폭으로 걷는다.
  ///
  /// 값의 근거는 클립의 고관절 스윙이다. 걷기의 `nearHip` 은 `+0.50 … -0.45`
  /// 라디안이므로 한 걸음의 발 이동은 `2·L·sin(0.95/2) ≈ 0.92·L`, 한 사이클은
  /// 두 걸음이라 `1.83·L`. 달리기·전력질주는 여기에 체공 구간이 더해진다.
  ///
  /// [RiggedIsoActor] 가 이 값으로 재생 배속을 정해 발 미끄러짐을 없앤다.
  final double strideCycle;

  final List<double>? rootX;
  final List<double>? rootY;
  final List<double>? rootRot;
  final List<double>? spine;
  final List<double>? chest;
  final List<double>? neck;
  final List<double>? head;

  final List<double>? nearShoulder;
  final List<double>? nearElbow;
  final List<double>? nearWrist;
  final List<double>? farShoulder;
  final List<double>? farElbow;
  final List<double>? farWrist;

  final List<double>? nearHip;
  final List<double>? nearKnee;
  final List<double>? nearAnkle;
  final List<double>? farHip;
  final List<double>? farKnee;
  final List<double>? farAnkle;

  final List<double>? breath;
  final List<double>? squash;
  final List<double>? weaponSwing;
  final List<double>? mouth;
  final List<double>? eyeOpen;
  final List<double>? capeFlow;
  final List<double>? impact;

  double _v(List<double>? keys, double t, double fallback) {
    if (keys == null) return fallback;
    return loop ? sampleLoop(keys, t) : sampleOnce(keys, t);
  }

  /// 정규화 시간 [t](루프면 0..1 순환, 원샷이면 0..1 클램프)의 포즈.
  Pose sample(double t) => Pose(
        rootX: _v(rootX, t, 0),
        rootY: _v(rootY, t, 0),
        rootRot: _v(rootRot, t, 0),
        spine: _v(spine, t, 0),
        chest: _v(chest, t, 0),
        neck: _v(neck, t, 0),
        head: _v(head, t, 0),
        armNear: ArmPose(
          shoulder: _v(nearShoulder, t, 0.10),
          elbow: _v(nearElbow, t, 0.22),
          wrist: _v(nearWrist, t, 0),
        ),
        armFar: ArmPose(
          shoulder: _v(farShoulder, t, 0.08),
          elbow: _v(farElbow, t, 0.20),
          wrist: _v(farWrist, t, 0),
        ),
        legNear: LegPose(
          hip: _v(nearHip, t, 0.05),
          knee: _v(nearKnee, t, 0.06),
          ankle: _v(nearAnkle, t, 0),
        ),
        legFar: LegPose(
          hip: _v(farHip, t, -0.05),
          knee: _v(farKnee, t, 0.08),
          ankle: _v(farAnkle, t, 0),
        ),
        breath: _v(breath, t, 0),
        squash: _v(squash, t, 1),
        weaponSwing: _v(weaponSwing, t, 0),
        mouth: _v(mouth, t, 0),
        eyeOpen: _v(eyeOpen, t, 1),
        capeFlow: _v(capeFlow, t, 0),
        impact: _v(impact, t, 0),
      );

  /// 원샷 클립이 끝난 뒤에도 유지되는 최종 포즈(죽음의 시체 자세 등).
  Pose get endPose => sample(1);
}

/// 사인 합성으로 만드는 미세 요동. 키프레임만 쓰면 루프가 정확히 반복되어
/// 기계적으로 보이므로, 저주파 노이즈를 얹어 반복 인지를 흐린다.
double idleJitter(double time, double seed, double amp) =>
    (math.sin(time * 0.73 + seed) * 0.6 + math.sin(time * 1.31 + seed * 3.1) * 0.4) * amp;
