import 'dart:math' as math;
import 'dart:ui';

import '../core/spline.dart';
import 'body.dart';

/// 팔 한 짝의 관절 각도.
///
/// 모든 각도는 "레스트 자세로부터의 변위"이며 라디안이다. 레스트는 팔을
/// 아래로 늘어뜨린 상태이므로 [shoulder] 가 커질수록 팔이 앞으로 올라간다.
/// 길이가 아닌 각도만 담기 때문에 하나의 클립이 어떤 체형에도 적용된다.
class ArmPose {
  const ArmPose({this.shoulder = 0, this.elbow = 0, this.wrist = 0});

  /// 어깨. + 는 앞으로(전방 = 화면 오른쪽) 들어 올린다.
  final double shoulder;

  /// 팔꿈치 굽힘. 항상 0 이상이며 손이 앞쪽으로 접힌다.
  final double elbow;

  /// 손목. 무기 각도에 그대로 반영된다.
  final double wrist;

  static const ArmPose rest = ArmPose();

  ArmPose operator +(ArmPose o) => ArmPose(
        shoulder: shoulder + o.shoulder,
        elbow: elbow + o.elbow,
        wrist: wrist + o.wrist,
      );

  ArmPose scaled(double k) => ArmPose(
        shoulder: shoulder * k,
        elbow: elbow * k,
        wrist: wrist * k,
      );

  static ArmPose lerp(ArmPose a, ArmPose b, double t) => ArmPose(
        shoulder: lerpD(a.shoulder, b.shoulder, t),
        elbow: lerpD(a.elbow, b.elbow, t),
        wrist: lerpD(a.wrist, b.wrist, t),
      );
}

/// 다리 한 짝의 관절 각도. [knee] 는 항상 0 이상이며 정강이가 뒤로 접힌다.
class LegPose {
  const LegPose({this.hip = 0, this.knee = 0, this.ankle = 0});

  /// 고관절. + 는 다리를 앞으로 내민다.
  final double hip;

  /// 무릎 굽힘(뒤로).
  final double knee;

  /// 발목. + 는 발끝을 든다(도살굽 반대).
  final double ankle;

  static const LegPose rest = LegPose();

  static LegPose lerp(LegPose a, LegPose b, double t) => LegPose(
        hip: lerpD(a.hip, b.hip, t),
        knee: lerpD(a.knee, b.knee, t),
        ankle: lerpD(a.ankle, b.ankle, t),
      );
}

/// 한 프레임의 전신 포즈.
///
/// 절대 좌표를 담지 않는다. 위치 성분([rootX], [rootY])조차 키에 대한 비율로
/// 두어, 애니메이션 데이터가 캐릭터 치수와 완전히 분리되도록 한다.
class Pose {
  const Pose({
    this.rootX = 0,
    this.rootY = 0,
    this.rootRot = 0,
    this.spine = 0,
    this.chest = 0,
    this.neck = 0,
    this.head = 0,
    this.armNear = ArmPose.rest,
    this.armFar = ArmPose.rest,
    this.legNear = LegPose.rest,
    this.legFar = LegPose.rest,
    this.breath = 0,
    this.squash = 1,
    this.weaponSwing = 0,
    this.mouth = 0,
    this.eyeOpen = 1,
    this.capeFlow = 0,
    this.impact = 0,
  });

  /// 골반의 수평 변위(키 대비 비율). + 는 전방.
  final double rootX;

  /// 골반의 수직 변위(키 대비 비율). - 는 위(도약), + 는 아래(웅크림).
  final double rootY;

  /// 골반을 중심으로 한 몸 전체의 기울기. + 는 앞으로 기운다.
  final double rootRot;

  /// 허리 굽힘. + 는 상체가 앞으로 숙여진다.
  final double spine;

  /// 가슴. 척추 위에 누적된다.
  final double chest;

  final double neck;
  final double head;

  final ArmPose armNear;
  final ArmPose armFar;
  final LegPose legNear;
  final LegPose legFar;

  /// 호흡. -1..1 이며 흉곽 부피에 반영된다.
  final double breath;

  /// 스쿼시&스트레치. 1 이 기본, <1 은 납작해지고 >1 은 늘어난다.
  final double squash;

  /// 손에 쥔 무기의 추가 회전. 손목과 별개로 잔상·궤적에도 쓰인다.
  final double weaponSwing;

  /// 입 벌림 0..1.
  final double mouth;

  /// 눈 뜬 정도 0..1.
  final double eyeOpen;

  /// 망토·머리카락이 뒤로 날리는 정도 0..1.
  final double capeFlow;

  /// 피격 섬광 세기 0..1. 렌더러가 실루엣을 흰색으로 덧칠한다.
  final double impact;

  static const Pose rest = Pose();

  static Pose lerp(Pose a, Pose b, double t) {
    if (t <= 0) return a;
    if (t >= 1) return b;
    return Pose(
      rootX: lerpD(a.rootX, b.rootX, t),
      rootY: lerpD(a.rootY, b.rootY, t),
      rootRot: lerpD(a.rootRot, b.rootRot, t),
      spine: lerpD(a.spine, b.spine, t),
      chest: lerpD(a.chest, b.chest, t),
      neck: lerpD(a.neck, b.neck, t),
      head: lerpD(a.head, b.head, t),
      armNear: ArmPose.lerp(a.armNear, b.armNear, t),
      armFar: ArmPose.lerp(a.armFar, b.armFar, t),
      legNear: LegPose.lerp(a.legNear, b.legNear, t),
      legFar: LegPose.lerp(a.legFar, b.legFar, t),
      breath: lerpD(a.breath, b.breath, t),
      squash: lerpD(a.squash, b.squash, t),
      weaponSwing: lerpD(a.weaponSwing, b.weaponSwing, t),
      mouth: lerpD(a.mouth, b.mouth, t),
      eyeOpen: lerpD(a.eyeOpen, b.eyeOpen, t),
      capeFlow: lerpD(a.capeFlow, b.capeFlow, t),
      impact: lerpD(a.impact, b.impact, t),
    );
  }

  Pose copyWith({
    double? rootX,
    double? rootY,
    double? rootRot,
    double? spine,
    double? chest,
    double? neck,
    double? head,
    ArmPose? armNear,
    ArmPose? armFar,
    LegPose? legNear,
    LegPose? legFar,
    double? breath,
    double? squash,
    double? weaponSwing,
    double? mouth,
    double? eyeOpen,
    double? capeFlow,
    double? impact,
  }) =>
      Pose(
        rootX: rootX ?? this.rootX,
        rootY: rootY ?? this.rootY,
        rootRot: rootRot ?? this.rootRot,
        spine: spine ?? this.spine,
        chest: chest ?? this.chest,
        neck: neck ?? this.neck,
        head: head ?? this.head,
        armNear: armNear ?? this.armNear,
        armFar: armFar ?? this.armFar,
        legNear: legNear ?? this.legNear,
        legFar: legFar ?? this.legFar,
        breath: breath ?? this.breath,
        squash: squash ?? this.squash,
        weaponSwing: weaponSwing ?? this.weaponSwing,
        mouth: mouth ?? this.mouth,
        eyeOpen: eyeOpen ?? this.eyeOpen,
        capeFlow: capeFlow ?? this.capeFlow,
        impact: impact ?? this.impact,
      );
}

/// 사지 하나의 FK 결과. 팔은 (어깨, 팔꿈치, 손목, 손끝),
/// 다리는 (고관절, 무릎, 발목, 발끝) 으로 같은 자료 구조를 쓴다.
class Limb {
  const Limb(this.a, this.b, this.c, this.d, this.angleAB, this.angleBC, this.angleCD);

  final Offset a;
  final Offset b;
  final Offset c;
  final Offset d;
  final double angleAB;
  final double angleBC;
  final double angleCD;
}

/// 포즈를 월드 좌표로 푼 결과.
///
/// 좌표계는 발밑 지면이 원점, y 는 화면 아래가 +, 캐릭터는 +x(오른쪽)를
/// 바라본다. 렌더러는 이 구조체만 보고 그리므로 애니메이션과 그리기가
/// 완전히 분리된다.
class Skeleton {
  Skeleton({
    required this.pelvis,
    required this.waist,
    required this.chest,
    required this.neckTop,
    required this.headCenter,
    required this.headTop,
    required this.spineAngle,
    required this.chestAngle,
    required this.headAngle,
    required this.armNear,
    required this.armFar,
    required this.legNear,
    required this.legFar,
    required this.body,
    required this.pose,
  });

  final Offset pelvis;
  final Offset waist;
  final Offset chest;
  final Offset neckTop;
  final Offset headCenter;
  final Offset headTop;

  final double spineAngle;
  final double chestAngle;
  final double headAngle;

  final Limb armNear;
  final Limb armFar;
  final Limb legNear;
  final Limb legFar;

  final Body body;
  final Pose pose;

  /// 두 발 중 더 아래에 있는 접지점. 그림자 위치와 착지 판정에 쓴다.
  Offset get groundContact =>
      legNear.d.dy > legFar.d.dy ? Offset(legNear.d.dx, 0) : Offset(legFar.d.dx, 0);

  /// 실루엣 전체를 감싸는 대략적인 경계. 그라디언트 정렬에 쓴다.
  Rect get bounds {
    var minX = double.infinity, minY = double.infinity;
    var maxX = -double.infinity, maxY = -double.infinity;
    void acc(Offset p) {
      if (p.dx < minX) minX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy > maxY) maxY = p.dy;
    }

    for (final p in [pelvis, chest, headTop, headCenter]) {
      acc(p);
    }
    for (final l in [armNear, armFar, legNear, legFar]) {
      acc(l.a);
      acc(l.b);
      acc(l.c);
      acc(l.d);
    }
    final pad = body.height * 0.08;
    return Rect.fromLTRB(minX - pad, minY - pad, maxX + pad, maxY + pad);
  }
}

Offset _step(Offset from, double angle, double len) =>
    from + Offset(math.cos(angle) * len, math.sin(angle) * len);

const double _up = -math.pi / 2;
const double _down = math.pi / 2;

/// 포즈와 체형으로부터 관절 월드 좌표를 계산한다(순운동학).
///
/// ## [yaw] — 이것이 8방향을 만든다
///
/// 인체의 관절 운동은 대부분 **시상면(sagittal, 앞뒤)** 에서 일어난다. 팔은
/// 앞뒤로 흔들리고 무릎은 앞뒤로 굽는다. 그래서 순수한 측면 뷰는 2D 로 풀 수
/// 있지만, **정면에서는 그 스윙이 화면에서 사라지고 대신 좌우 폭이 드러난다.**
///
/// [yaw] 를 주면 각 관절을 세 성분으로 나눠 투영한다.
///
/// ```
/// 화면 x = 시상면성분 · sin(yaw) + 좌우성분 · cos(yaw)
/// 화면 y = 수직성분                       (아이소 단축은 렌더러가 따로 건다)
/// ```
///
/// - `yaw = ±π/2` → 완전 측면. 스윙이 최대로 보이고 좌우 폭은 0. (기본값)
/// - `yaw = 0` → 정면. 스윙이 화면에서 사라지고 팔다리가 좌우로 벌어진다.
/// - `yaw = π` → 후면. 정면과 같되 좌우가 뒤집힌다.
///
/// 기본값이 `π/2` 인 이유는 **기존 호출부의 동작을 그대로 두기 위해서**다.
/// 초상·갤러리는 측면 골격이 맞고, 방향이 필요한 인게임 액터만 값을 넘긴다.
Skeleton solve(Body body, Pose pose, {double yaw = math.pi / 2}) {
  final h = body.height;
  final sq = pose.squash;

  // 시상면 스윙이 화면에 드러나는 비율. 미러는 렌더러가 캔버스를 뒤집어
  // 처리하므로 여기서는 절댓값만 쓴다.
  final sag = math.sin(yaw).abs();
  // 좌우 폭이 화면에 드러나는 비율. 부호가 있어 후면에서 좌우가 뒤집힌다.
  final lat = math.cos(yaw);

  /// 관절 하나를 3성분으로 투영해 잇는다.
  ///
  /// [angle] 은 시상면 각(기존 2D 규약 그대로), [splay] 는 좌우 벌림이다.
  /// 정면일수록 시상면 성분이 줄고 좌우 성분이 살아난다.
  Offset step3(Offset from, double angle, double len,
      {double splay = 0, double side = 0}) {
    final sagittal = math.cos(angle) * len;
    final vertical = math.sin(angle) * len;
    final lateral = splay * len * side;
    return from + Offset(sagittal * sag + lateral * lat, vertical);
  }

  // 골반. 스쿼시는 골반 높이를 눌러 무게감을 만든다.
  final pelvis = Offset(pose.rootX * h * sag, -body.hipHeight * sq + pose.rootY * h);

  // 척추: 골반 → 허리 → 가슴. rootRot 이 몸 전체를 기울이고 spine 이
  // 허리 굽힘을, chest 가 흉곽의 젖힘을 더한다.
  final lean = pose.rootRot + body.hunch * 0.5;
  final spineAngle = _up + lean + pose.spine;
  final waist = step3(pelvis, spineAngle, body.torso * 0.45 * sq);
  final chestAngle = spineAngle + pose.chest + body.hunch * 0.5;
  final chest = step3(waist, chestAngle, body.torso * 0.55 * sq);

  // 목과 머리.
  final neckAngle = chestAngle + pose.neck;
  final neckTop = step3(chest, neckAngle, body.neck);
  final headAngle = neckAngle + pose.head;
  final headCenter = step3(neckTop, headAngle, body.headLen * 0.5);
  final headTop = step3(neckTop, headAngle, body.headLen);

  Limb solveArm(ArmPose ap, double side) {
    // 어깨 관절의 위치는 두 성분의 합이다.
    //  ① 좌우 — 정면에서 어깨가 벌어지는 실제 폭
    //  ② 앞뒤 — 측면에서 근/원 어깨가 어긋나 납작함을 없애는 양
    final base = _step(chest, chestAngle, -body.torso * 0.07);
    final across = chestAngle + math.pi / 2;
    final lateralOff = body.shoulderHalf * side * lat;
    final sagittalOff = body.shoulderHalf * 0.30 * side * sag;
    final shoulder = base +
        Offset(math.cos(across), math.sin(across)) * 0 +
        Offset(lateralOff + sagittalOff, -body.torso * 0.01);

    // 레스트(shoulder = 0)는 팔을 아래로 늘어뜨린 상태.
    // 정면일수록 팔을 몸통 바깥으로 조금 벌려 겨드랑이가 붙지 않게 한다.
    final splay = (1 - sag) * 0.30;
    final upperAngle = chestAngle + math.pi - ap.shoulder;
    final elbow = step3(shoulder, upperAngle, body.upperArm,
        splay: splay, side: side);
    final foreAngle = upperAngle - ap.elbow;
    final wrist =
        step3(elbow, foreAngle, body.foreArm, splay: splay * 0.6, side: side);
    final handAngle = foreAngle - ap.wrist;
    final handTip = step3(wrist, handAngle, body.hand);
    return Limb(shoulder, elbow, wrist, handTip, upperAngle, foreAngle, handAngle);
  }

  Limb solveLeg(LegPose lp, double side) {
    // 골반도 어깨와 같다 — 정면에서 좌우로 벌어지고 측면에서 앞뒤로 어긋난다.
    final lateralOff = body.hipHalf * side * lat;
    final sagittalOff = body.hipHalf * 0.45 * side * sag;
    final root = pelvis + Offset(lateralOff + sagittalOff, 0);

    // 정면에서는 다리가 약간 벌어져 선다. 완전히 붙이면 인형처럼 보인다.
    final splay = (1 - sag) * 0.13;
    final thighAngle = _down + pose.rootRot * 0.15 - lp.hip;
    final knee = step3(root, thighAngle, body.thigh * sq,
        splay: splay, side: side);
    final shinAngle = thighAngle + lp.knee;
    final ankle = step3(knee, shinAngle, body.shin * sq,
        splay: splay * 0.5, side: side);
    // 발은 정강이에 대해 직각이 기본. ankle 이 +면 발끝을 든다.
    // 정면에서는 발끝이 화면 앞을 향하므로 길이가 단축돼 보인다.
    final footAngle = shinAngle - math.pi / 2 - lp.ankle;
    final toe = step3(ankle, footAngle, body.foot * (0.55 + 0.45 * sag));
    return Limb(root, knee, ankle, toe, thighAngle, shinAngle, footAngle);
  }

  return Skeleton(
    pelvis: pelvis,
    waist: waist,
    chest: chest,
    neckTop: neckTop,
    headCenter: headCenter,
    headTop: headTop,
    spineAngle: spineAngle,
    chestAngle: chestAngle,
    headAngle: headAngle,
    armNear: solveArm(pose.armNear, 1),
    armFar: solveArm(pose.armFar, -1),
    legNear: solveLeg(pose.legNear, 1),
    legFar: solveLeg(pose.legFar, -1),
    body: body,
    pose: pose,
  );
}
