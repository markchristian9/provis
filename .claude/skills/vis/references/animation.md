# 애니메이션 — 포즈·FK·IK·2차 모션

`lib/src/rig/pose.dart`, `lib/src/rig/ik.dart`, `lib/src/anim/verlet.dart` 의 완전한 참조와 클립 저작 레시피.

## 목차

1. [핵심 개념: 데이터는 각도, 좌표는 결과](#핵심-개념-데이터는-각도-좌표는-결과)
2. [Pose — 한 프레임의 전신 (전체 소스)](#pose--한-프레임의-전신)
3. [solve() — 순운동학 (전체 소스)](#solve--순운동학)
4. [IK — 2본 해석 해 (전체 소스)](#ik--2본-해석-해)
5. [VerletChain / ClothStrip — 2차 모션 (전체 소스)](#verletchain--clothstrip)
6. [클립 저작 레시피](#클립-저작-레시피)
7. [아이소메트릭 이동과 8방향 전환](#아이소메트릭-이동과-8방향-전환)
8. [타이밍 표](#타이밍-표)
9. [흔한 실패](#흔한-실패)

---

## 핵심 개념: 데이터는 각도, 좌표는 결과

`Pose` 는 **절대 좌표를 담지 않는다.** 위치 성분(`rootX`, `rootY`)조차 키에 대한 비율이다.

이 규약의 대가는 다음과 같다:

- 하나의 걷기 클립이 **8등신 영웅과 4등신 몬스터 모두**에서 자연스럽게 재생된다.
- 캐릭터 치수를 바꿔도 애니메이션을 다시 만들 필요가 없다.
- 아이소 8방향 회전이 애니메이션 데이터를 건드리지 않는다.

**절대 하지 말 것**: 클립 안에서 `Offset` 을 직접 계산하거나, `Body` 치수를 참조하는 것. 그 순간 클립이 특정 체형에 고정된다.

흐름:

```
t (초) → Pose (각도만)  →  solve(body, pose)  →  Skeleton (월드 좌표)  →  렌더러
                                     ↑
                              Body (치수)
```

---

## Pose — 한 프레임의 전신

**파일: `lib/src/rig/pose.dart`**

```dart
/// 팔 한 짝의 관절 각도. 모든 각도는 "레스트 자세로부터의 변위"이며 라디안.
/// 레스트는 팔을 아래로 늘어뜨린 상태이므로 shoulder 가 커질수록 팔이 앞으로 올라간다.
class ArmPose {
  const ArmPose({this.shoulder = 0, this.elbow = 0, this.wrist = 0});
  final double shoulder;   // + 는 앞으로(전방 = 국소 +x) 들어 올린다
  final double elbow;      // 굽힘. 항상 0 이상이며 손이 앞쪽으로 접힌다
  final double wrist;      // 무기 각도에 그대로 반영된다
  static const ArmPose rest = ArmPose();
  ArmPose operator +(ArmPose o);
  ArmPose scaled(double k);
  static ArmPose lerp(ArmPose a, ArmPose b, double t);
}

/// 다리 한 짝. knee 는 항상 0 이상이며 정강이가 뒤로 접힌다.
class LegPose {
  const LegPose({this.hip = 0, this.knee = 0, this.ankle = 0});
  final double hip;        // + 는 다리를 앞으로 내민다
  final double knee;       // 굽힘(뒤로)
  final double ankle;      // + 는 발끝을 든다
  static const LegPose rest = LegPose();
  static LegPose lerp(LegPose a, LegPose b, double t);
}

class Pose {
  const Pose({
    this.rootX = 0, this.rootY = 0, this.rootRot = 0,
    this.spine = 0, this.chest = 0, this.neck = 0, this.head = 0,
    this.armNear = ArmPose.rest, this.armFar = ArmPose.rest,
    this.legNear = LegPose.rest, this.legFar = LegPose.rest,
    this.breath = 0, this.squash = 1, this.weaponSwing = 0,
    this.mouth = 0, this.eyeOpen = 1, this.capeFlow = 0, this.impact = 0,
  });

  final double rootX;       // 골반 수평 변위(키 대비 비율). + 는 전방
  final double rootY;       // 수직 변위. - 는 위(도약), + 는 아래(웅크림)
  final double rootRot;     // 몸 전체 기울기. + 는 앞으로
  final double spine;       // 허리 굽힘
  final double chest;       // 흉곽. 척추 위에 누적
  final double neck, head;
  final ArmPose armNear, armFar;
  final LegPose legNear, legFar;
  final double breath;      // -1..1, 흉곽 부피
  final double squash;      // 1 기본, <1 납작, >1 늘어남
  final double weaponSwing; // 손목과 별개. 잔상·궤적에도 쓴다
  final double mouth;       // 0..1
  final double eyeOpen;     // 0..1
  final double capeFlow;    // 0..1, 망토·머리카락이 뒤로 날리는 정도
  final double impact;      // 0..1, 피격 섬광. 렌더러가 실루엣을 흰색으로 덧칠

  static const Pose rest = Pose();
  static Pose lerp(Pose a, Pose b, double t);   // t<=0, t>=1 조기 반환
  Pose copyWith({ /* 모든 필드 */ });
}
```

`Pose.lerp` 는 모든 필드를 선형 보간한다. **각도가 π 를 넘나드는 경우에는 `lerpAngle` 을 직접 써야** 관절이 한 바퀴 도는 것을 막는다 (아래 IK 절 참조).

---

## solve() — 순운동학

```dart
/// 사지 하나의 FK 결과. 팔은 (어깨, 팔꿈치, 손목, 손끝),
/// 다리는 (고관절, 무릎, 발목, 발끝) 으로 같은 자료 구조를 쓴다.
class Limb {
  const Limb(this.a, this.b, this.c, this.d, this.angleAB, this.angleBC, this.angleCD);
  final Offset a, b, c, d;
  final double angleAB, angleBC, angleCD;
}

class Skeleton {
  final Offset pelvis, waist, chest, neckTop, headCenter, headTop;
  final double spineAngle, chestAngle, headAngle;
  final Limb armNear, armFar, legNear, legFar;
  final Body body;
  final Pose pose;

  /// 두 발 중 더 아래에 있는 접지점. 그림자 위치와 착지 판정에 쓴다.
  Offset get groundContact =>
      legNear.d.dy > legFar.d.dy ? Offset(legNear.d.dx, 0) : Offset(legFar.d.dx, 0);

  /// 실루엣 전체를 감싸는 대략적인 경계. 그라디언트 정렬에 쓴다.
  Rect get bounds;   // 관절점 + body.height * 0.08 패딩
}
```

전체 소스:

```dart
Offset _step(Offset from, double angle, double len) =>
    from + Offset(math.cos(angle) * len, math.sin(angle) * len);

const double _up = -math.pi / 2;
const double _down = math.pi / 2;

Skeleton solve(Body body, Pose pose) {
  final h = body.height;
  final sq = pose.squash;

  // 골반. 스쿼시는 골반 높이를 눌러 무게감을 만든다.
  final pelvis = Offset(pose.rootX * h, -body.hipHeight * sq + pose.rootY * h);

  // 척추: 골반 → 허리 → 가슴.
  final lean = pose.rootRot + body.hunch * 0.5;
  final spineAngle = _up + lean + pose.spine;
  final waist = _step(pelvis, spineAngle, body.torso * 0.45 * sq);
  final chestAngle = spineAngle + pose.chest + body.hunch * 0.5;
  final chest = _step(waist, chestAngle, body.torso * 0.55 * sq);

  // 목과 머리.
  final neckAngle = chestAngle + pose.neck;
  final neckTop = _step(chest, neckAngle, body.neck);
  final headAngle = neckAngle + pose.head;
  final headCenter = _step(neckTop, headAngle, body.headLen * 0.5);
  final headTop = _step(neckTop, headAngle, body.headLen);

  Limb solveArm(ArmPose ap, double side) {
    // 어깨는 가슴 라인에 수직으로 붙는다. side 는 근/원 구분(-1 원거리).
    final across = chestAngle + math.pi / 2;
    final shoulder = _step(chest, across, body.shoulderHalf * 0.35 * side)
        - Offset(0, body.torso * 0.06);
    final upperAngle = chestAngle + math.pi / 2 - ap.shoulder;
    final elbow = _step(shoulder, upperAngle, body.upperArm);
    final foreAngle = upperAngle - ap.elbow;
    final wrist = _step(elbow, foreAngle, body.foreArm);
    final handAngle = foreAngle - ap.wrist;
    final handTip = _step(wrist, handAngle, body.hand);
    return Limb(shoulder, elbow, wrist, handTip, upperAngle, foreAngle, handAngle);
  }

  Limb solveLeg(LegPose lp, double side) {
    final across = spineAngle + math.pi / 2;
    final root = _step(pelvis, across, body.hipHalf * 0.45 * side);
    final thighAngle = _down + pose.rootRot * 0.15 - lp.hip;
    final knee = _step(root, thighAngle, body.thigh * sq);
    final shinAngle = thighAngle + lp.knee;
    final ankle = _step(knee, shinAngle, body.shin * sq);
    // 발은 정강이에 대해 직각이 기본. ankle 이 +면 발끝을 든다.
    final footAngle = shinAngle - math.pi / 2 - lp.ankle;
    final toe = _step(ankle, footAngle, body.foot);
    return Limb(root, knee, ankle, toe, thighAngle, shinAngle, footAngle);
  }

  return Skeleton(
    pelvis: pelvis, waist: waist, chest: chest, neckTop: neckTop,
    headCenter: headCenter, headTop: headTop,
    spineAngle: spineAngle, chestAngle: chestAngle, headAngle: headAngle,
    armNear: solveArm(pose.armNear, 1),  armFar: solveArm(pose.armFar, -1),
    legNear: solveLeg(pose.legNear, 1),  legFar: solveLeg(pose.legFar, -1),
    body: body, pose: pose,
  );
}
```

**주의**: `squash` 는 `solve` 안에서 골반 높이·몸통·허벅지·정강이에 곱해진다. 아이소의 `iso.squash`(카메라 단축)와 **완전히 다른 것**이다. 렌더 진입부의 `canvas.scale(1, iso.squash)` 와 혼동하지 말 것.

---

## IK — 2본 해석 해

**파일: `lib/src/rig/ik.dart`**

```dart
/// 2본 역운동학. [root] 에서 [target] 까지 길이 [l1], [l2] 의 두 마디로 닿을 때
/// 중간 관절의 위치를 돌려준다. [bend] 는 굽는 방향(+1/-1)이며, 팔꿈치는 뒤로,
/// 무릎은 앞으로 굽는다는 해부학적 제약을 호출부가 부호로 표현한다.
Offset solveIk2(Offset root, Offset target, double l1, double l2, double bend) {
  var delta = target - root;
  var d = delta.distance;
  final maxD = (l1 + l2) * 0.999;
  final minD = (l1 - l2).abs() * 1.001 + 1e-4;
  if (d > maxD) {
    delta = delta.normalized() * maxD; d = maxD;
  } else if (d < minD) {
    if (d < 1e-6) { delta = const Offset(0, 1) * minD; }
    else { delta = delta.normalized() * minD; }
    d = minD;
  }
  final dir = delta / d;
  final a = (l1 * l1 - l2 * l2 + d * d) / (2 * d);
  final h = math.sqrt(math.max(0, l1 * l1 - a * a));
  return root + dir * a + dir.perp * (h * bend);
}

/// IK 목표가 사슬 길이를 넘어설 때 실제로 닿는 끝점.
Offset reachable(Offset root, Offset target, double maxLen);

/// 각도를 최단 경로로 보간. 포즈 전환에서 관절이 한 바퀴 도는 것을 막는다.
double lerpAngle(double a, double b, double t);

/// 기준점에서 각도와 길이로 뻗은 점.
Offset polar(Offset from, double angle, double len);
```

**`0.999` / `1.001` 여유의 이유**: 정확히 뻗은 상태(`d == l1+l2`)에서 `h` 가 0 이 되어 관절이 완전히 펴지면, 다음 프레임에 굽는 방향이 뒤집혀 무릎이 딱 소리를 내며 튄다. 항상 1% 남긴다.

**용도**:
- 발 접지 (지면 높이에 발을 고정)
- 무기를 두 손으로 잡기 (한 손을 IK 로 자루에 붙임)
- 벽·적을 향해 손 뻗기
- 계단·경사면 대응

FK 로 만든 클립 위에 IK 를 **덧씌우는** 순서가 표준이다: `Pose` → `solve` → 필요한 사지만 IK 보정 → 렌더.

---

## VerletChain / ClothStrip

**파일: `lib/src/anim/verlet.dart`**

> 망토·머리카락·꼬리·사슬 장식 등 "몸이 움직인 뒤에 뒤따라오는" 모든 것. **키프레임으로는 결코 얻을 수 없는 관성과 지연이 여기서 나온다.**

> **⚠️ 프로덕션 적용 전례가 없다.** 2026-08-06 기준 `VerletChain`·`ClothStrip` 을 호출하는 캐릭터가
> `lib/` 에 **0건**이다(완성 9종은 전부 시간 함수로 천을 그린다). 검증된 레시피가 아니라 **준비된
> 도구**로 취급하고, 처음 적용할 때는 아래 파라미터 표에서 시작해 직접 튜닝하라.

```dart
class VerletChain {
  VerletChain({
    required Offset anchor, required this.segments, required this.segmentLength,
    Offset initialDir = const Offset(0, 1),
    this.gravity = 900, this.damping = 0.986,
    this.stiffness = 0.62, this.iterations = 6,
  });

  final int segments;
  final double segmentLength;
  final double gravity;
  final double damping;
  final double stiffness;
  final int iterations;

  final List<Offset> pos = [];
  final List<Offset> prev = [];
  Offset restDir = const Offset(0, 1);   // 사슬이 뻗으려는 고정 방향
  double restStrength = 0.0;

  void step(double dt, Offset anchor, {Offset wind = Offset.zero, Offset carry = Offset.zero}) {
    if (dt <= 0) return;
    final d = math.min(dt, 1 / 30);       // ← 프레임 드롭 시 폭발 방지
    final acc = Offset(0, gravity) + wind;

    for (var i = 1; i < pos.length; i++) {
      final v = (pos[i] - prev[i]) * damping;
      prev[i] = pos[i];
      // carry: 앵커의 이동을 사슬 전체에 관성으로 전달한다. 캐릭터가 달릴 때
      // 망토가 뒤로 날리는 것은 중력이 아니라 이 항의 효과다.
      pos[i] = pos[i] + v + acc * (d * d) - carry * (d * (i / pos.length));
    }
    pos[0] = anchor; prev[0] = anchor;

    for (var it = 0; it < iterations; it++) {
      for (var i = 0; i < pos.length - 1; i++) {
        final delta = pos[i + 1] - pos[i];
        final dist = delta.distance;
        if (dist < 1e-6) continue;
        final corr = delta * ((dist - segmentLength) / dist * 0.5 * stiffness);
        if (i > 0) pos[i] = pos[i] + corr;
        pos[i + 1] = pos[i + 1] - corr;
      }
      if (restStrength > 0) { /* restDir 쪽으로 끌어당김 */ }
      pos[0] = anchor;
    }
  }

  void teleport(Offset anchor, {Offset dir = const Offset(0, 1)});
}
```

```dart
/// 두 개의 사슬을 가로로 묶어 만든 천 조각.
/// 한 줄짜리 사슬은 리본밖에 못 만들지만, 두 줄을 교차 구속으로 묶으면
/// 폭을 가진 면이 되어 망토가 펄럭이며 실루엣이 살아난다.
class ClothStrip {
  ClothStrip({required Offset anchorLeft, required Offset anchorRight,
              required this.segments, required this.segmentLength,
              double gravity = 780, double damping = 0.985, this.crossIterations = 4});
  final VerletChain left, right;
  final double width;
  double flare = 0.55;                  // 아래로 갈수록 폭이 넓어지는 정도(A 라인)

  void step(double dt, Offset anchorLeft, Offset anchorRight,
            {Offset wind = Offset.zero, Offset carry = Offset.zero});

  Path silhouette({double hemSag = 0.18});   // 밑단을 처지게 해 옷자락을 만든다
  List<Path> folds(int count);               // 천 위의 주름 선
}
```

### 사용 규약

1. **`teleport` 를 반드시 호출**한다 — 액터를 스폰하거나 순간이동시킬 때. 안 하면 망토가 화면을 가로질러 날아온다.
2. **`carry` 는 앵커의 프레임 간 이동량**이다: `carry = (anchorNow - anchorPrev) / dt`. 이걸 빼먹으면 달려도 망토가 안 날린다.
3. **`step` 은 렌더 전에 1회.** 여러 번 호출하면 중력이 중복 적용된다.
4. **`dt` 클램프(1/30)** 를 지운다면 브레이크포인트에서 재개할 때 사슬이 폭발한다.
5. **`folds` 는 `detail > 0.5` 에서만.** 주름 선은 비용 대비 효과가 낮은 편이다.

### 파라미터 표

| 대상 | segments | segmentLength | gravity | damping | stiffness | flare |
|------|----------|---------------|---------|---------|-----------|-------|
| 망토 | 7–9 | height·0.055 | 780 | 0.985 | 0.62 | 0.55 |
| 짧은 머리카락 | 3–4 | height·0.020 | 620 | 0.975 | 0.80 | — |
| 긴 머리카락 | 6–8 | height·0.028 | 700 | 0.980 | 0.70 | — |
| 꼬리 | 6–10 | height·0.045 | 400 | 0.990 | 0.55 | — |
| 촉수 | 10–14 | height·0.035 | 250 | 0.992 | 0.35 | — |
| 사슬 장식 | 4–6 | height·0.018 | 1100 | 0.970 | 0.90 | — |

꼬리는 `restDir` + `restStrength` 0.2~0.4 를 주어 몸 뒤로 뻗으려는 성질을 만든다.

---

## 클립 저작 레시피

클립은 `double t` (초 또는 0..1 위상) → `Pose` 함수다. 파일: `lib/src/anim/<name>_clips.dart`.

### 아이들 (호흡)

정지 상태가 죽어 있으면 캐릭터 전체가 죽는다. **호흡 + 미세 흔들림 + 가끔 눈 깜빡임.**

```dart
Pose idle(double t, {double seed = 0}) {
  final b = math.sin(t * 1.6);                    // 호흡 주기 ~3.9초
  final w = wobble(t * 0.7, seed);                // 무게중심 미세 이동
  return Pose(
    rootY: b * 0.004 + w * 0.002,
    rootRot: w * 0.02,
    chest: b * 0.035,
    neck: -b * 0.015,
    head: w * 0.03,
    breath: b,
    armNear: ArmPose(shoulder: 0.06 + b * 0.02, elbow: 0.18 + w * 0.02),
    armFar:  ArmPose(shoulder: 0.05 - b * 0.02, elbow: 0.16 - w * 0.02),
    eyeOpen: (math.sin(t * 0.9 + seed) > 0.985) ? 0.1 : 1.0,   // 드물게 깜빡
    capeFlow: 0.08 + w * 0.04,
  );
}
```

**좌우 팔에 서로 다른 위상**을 주는 것이 핵심이다. 완전 대칭이면 마네킹으로 보인다.

### 걷기

위상 `p = (t / period) % 1`. 다리는 반 주기 어긋난다.

```dart
Pose walk(double t, {double period = 0.95}) {
  final p = (t / period) % 1.0;
  final a = p * math.pi * 2;
  return Pose(
    // 몸통은 걸음당 2회 위아래로 흔들린다(양발 각각 한 번씩)
    rootY: -math.sin(a * 2).abs() * 0.012,
    rootRot: 0.04 + math.sin(a) * 0.015,
    spine: math.sin(a) * 0.02,
    legNear: LegPose(
      hip: math.sin(a) * 0.62,
      knee: math.max(0, -math.sin(a - 0.7)) * 0.85,      // 항상 0 이상
      ankle: math.sin(a + 1.2) * 0.22,
    ),
    legFar: LegPose(
      hip: math.sin(a + math.pi) * 0.62,
      knee: math.max(0, -math.sin(a + math.pi - 0.7)) * 0.85,
      ankle: math.sin(a + math.pi + 1.2) * 0.22,
    ),
    // 팔은 반대편 다리와 같은 위상(대측성 보행)
    armNear: ArmPose(shoulder: math.sin(a + math.pi) * 0.40, elbow: 0.22),
    armFar:  ArmPose(shoulder: math.sin(a) * 0.40, elbow: 0.22),
    capeFlow: 0.25,
  );
}
```

**대측성(contralateral) 보행** — 오른팔은 왼다리와 함께 나간다. 이걸 틀리면 "군대 행진" 같은 부자연스러움이 생긴다.

### 달리기

걷기와 다른 점 세 가지: (1) 몸이 앞으로 기운다(`rootRot` 0.14~0.22), (2) 양발이 지면에서 떨어지는 **체공 구간**이 있다, (3) 무릎이 훨씬 높이 올라간다.

```dart
Pose run(double t, {double period = 0.58}) {
  final p = (t / period) % 1.0;
  final a = p * math.pi * 2;
  return Pose(
    rootY: -0.02 - math.sin(a * 2).abs() * 0.028,      // 체공
    rootRot: 0.18,
    spine: 0.06 + math.sin(a) * 0.03,
    chest: -0.04,
    legNear: LegPose(hip: math.sin(a) * 0.95,
                     knee: math.max(0, -math.sin(a - 0.5)) * 1.5,
                     ankle: math.sin(a + 1.0) * 0.3),
    legFar:  LegPose(hip: math.sin(a + math.pi) * 0.95,
                     knee: math.max(0, -math.sin(a + math.pi - 0.5)) * 1.5,
                     ankle: math.sin(a + math.pi + 1.0) * 0.3),
    armNear: ArmPose(shoulder: math.sin(a + math.pi) * 0.72, elbow: 0.95),
    armFar:  ArmPose(shoulder: math.sin(a) * 0.72, elbow: 0.95),
    capeFlow: 0.85,
  );
}
```

### 공격 — 비대칭 타이밍이 전부

3구간으로 나누되 **길이를 다르게** 준다. 이것이 타격감의 90%다.

```
예비(anticipation)  35%  ─ 느리게 뒤로 감는다. 크게 감을수록 강해 보인다.
타격(strike)        12%  ─ 폭발적으로 빠르게. squash 로 몸을 늘인다.
회복(recovery)      53%  ─ 천천히 되돌아온다. 여기가 짧으면 가벼워 보인다.
```

```dart
Pose attack(double p, {double reach = 1.0}) {   // p: 0..1
  if (p < 0.35) {
    final k = smoothstep(0, 1, p / 0.35);
    return Pose.lerp(Pose.rest, _windUp, k);
  } else if (p < 0.47) {
    final k = (p - 0.35) / 0.12;
    final e = k * k;                              // ease-in: 가속하며 때린다
    return Pose.lerp(_windUp, _strike, e)
        .copyWith(squash: 1.0 + 0.06 * math.sin(e * math.pi),
                  weaponSwing: lerpD(-0.9, 1.7, e));
  } else {
    final k = smoothstep(0, 1, (p - 0.47) / 0.53);
    return Pose.lerp(_strike, Pose.rest, k);
  }
}

const _windUp = Pose(
  rootRot: -0.10, spine: -0.12, chest: -0.10,
  armNear: ArmPose(shoulder: -0.75, elbow: 1.15, wrist: -0.4),
  legNear: LegPose(hip: -0.15, knee: 0.25),
);
const _strike = Pose(
  rootX: 0.045, rootRot: 0.26, spine: 0.20, chest: 0.14,
  armNear: ArmPose(shoulder: 1.25, elbow: 0.12, wrist: 0.25),
  legNear: LegPose(hip: 0.40, knee: 0.30),
  legFar: LegPose(hip: -0.30, knee: 0.55),
);
```

**타격 프레임에 반드시 더할 것**: 무기 궤적(`paintGlow` 로 부채꼴 잔상), 카메라 흔들림 1~2px, 히트스톱 0.05~0.08초(그 프레임에서 `t` 진행을 멈춤).

### 피격

`impact` 를 1로 올리고 6~10프레임에 걸쳐 0으로 내린다. 렌더러는 `impact` 만큼 실루엣 전체를 흰색으로 덧칠한다.

```dart
Pose hit(double p, Offset fromDir) {
  final k = math.exp(-p * 8);                        // 급격히 감쇠
  return Pose(
    rootX: -fromDir.dx * 0.03 * k,
    rootRot: -0.22 * k,
    spine: -0.18 * k,
    head: -0.3 * k,
    squash: 1 - 0.08 * k,
    impact: k,
    mouth: 0.6 * k,
    capeFlow: 0.5 * k,
  );
}
```

### 죽음

`squash < 1` 로 무너뜨리고 `rootY` 를 양수로 올려 주저앉힌다. 마지막 20% 는 거의 움직이지 않아야 무게가 실린다.

---

## 아이소메트릭 이동과 8방향 전환

```dart
/// 월드 이동 방향 → 액터 yaw.
/// 아이소 화면에서 "오른쪽 위"로 이동하면 월드에서는 +x 방향이다.
double yawFromVelocity(Offset worldVelocity) =>
    math.atan2(worldVelocity.dx - worldVelocity.dy,
               worldVelocity.dx + worldVelocity.dy);
```

**회전 전환**: 8방향으로 스냅하더라도 **즉시 스냅하지 말고** `lerpAngle` 로 0.12~0.18초에 걸쳐 돌린다. 절차적 렌더러이므로 중간 각도를 그릴 수 있고, 이것만으로 스프라이트 기반 게임과 확연히 다른 부드러움이 나온다.

```dart
_yaw = lerpAngle(_yaw, targetYaw, 1 - math.exp(-dt / 0.15));
```

**보행 속도와 클립 속도 동기화** (발 미끄러짐 방지) — **`RiggedIsoActor` 가 자동으로 한다.**

`period` 를 고정하고 속도만 올리면 발이 얼음판에서 미끄러진다. `follow()` 가 매 프레임 이 계산을 하므로 게임 쪽에서는 **액터에 맵의 `IsoView` 만 넘기면 된다.**

```dart
final actor = riggedFromArtist(hero, tile: start, height: 200, iso: iso);
//                                                             ^^^^^^^^^
// 없으면 기본 타일 크기(kIso, 128px)로 보폭을 재서 걸음 수가 어긋난다.
```

계산의 계보는 이렇다.

```
Clip.strideCycle   한 사이클이 나아가는 거리 — 다리 길이의 배수 (walk 1.83)
      ↓ × body.legLength × (height / body.height)      화면 px
      ↓ ÷ iso.worldScale  (= tileWidth / √2)           타일
RiggedIsoActor.cycleTiles(clip)
      ↓ ÷ clip.duration
RiggedIsoActor.naturalSpeed(clip)   이 클립이 발을 붙인 채 낼 수 있는 속도
```

- **보폭을 다리 길이의 배수로 적는 이유**는 클립이 각도만 담는다는 규약과 같다. 다리가 짧은 몬스터와 8등신 영웅이 같은 클립으로 각자의 보폭을 낸다.
- **`worldScale` 이 화면상 길이가 아닌 이유**: 아이소 지면은 방향마다 단축률이 다르다(축 방향과 대각선이 다르게 줄어든다). 캐릭터 카드는 단축 없이 서 있으므로 그 픽셀이 곧 실제 길이이고, 지면도 같은 자로 재야 맞는다.
- **걷기/달리기 전환도 보폭에서 갈린다** (`gaitCrossover` = 두 클립 자연 속도의 기하 평균). 고정 임계값을 기본으로 두지 않는 이유는 타일 크기나 키가 바뀌면 그 숫자가 반드시 틀리기 때문이다. 명시하고 싶으면 `runThreshold` 에 값을 넣는다.
- 배속은 `[0.55, 1.9]` 로 자른다. 걷기를 두 배로 돌리면 종종걸음이 되고, 절반으로 돌리면 발이 공중에 멎는다.
- **제자리 동작(`strideCycle == 0`)에는 걸지 않는다.** 빨리 걷는다고 칼이 빨리 나가면 판정 타이밍이 이동 속도에 따라 달라진다.

---

## 타이밍을 그림에 붙인다 — `ClipEvent`

판정·타격음·이펙트를 프레임 번호로 걸면 프레임률이 흔들리는 순간 어긋난다. 클립 위의 **시점**에 걸면 배속이 바뀌어도 언제나 같은 자세에서 정확히 한 번 터진다.

```dart
static const attack = Clip(
  name: 'attack', duration: 0.86, loop: false,
  events: [ClipEvent('strike', 0.5)],   // weaponSwing 이 최대인 지점
  …
);

// 매 프레임
if (actor.animator.fired.contains('strike')) {
  world.applyHit(actor);
  actor.animator.hitstop(0.06);      // 타격 프레임에서 시간을 멈춘다
}
```

- 발화 구간은 반열림 `(from, to]` 다. 양끝을 다 포함하면 프레임 경계에서 두 번 터지고, 다 빼면 배속이 낮을 때 영영 안 터진다.
- `fired` 는 리스트를 재사용하므로 이벤트가 없는 프레임에서 할당이 0 이다.
- `hitstop` 은 남은 정지가 한 프레임보다 짧으면 **나머지로 진행한다.** 통째로 삼키면 0.06초가 프레임 경계에 따라 0.05~0.08초로 흔들려, 같은 공격의 회복 타이밍이 매번 달라진다.

---

## 시간은 누가 미는가

**`IsoSceneComponent` 를 쓰면 씬이 시간의 주인이다.** `follow()` 는 위치·방향·클립·보폭만 갱신하고 시간은 건드리지 않는다(`driveByScene` 이 남긴 표시를 본다). 이 규약이 없던 시절 씬과 `follow` 가 각자 `dt` 를 밀어 **모든 동작이 정확히 두 배 빨라졌다.**

씬 없이 쓰면 `follow(ctrl, dt)` 가 시간까지 민다 — 그대로 한 줄이면 된다.

**`dt` 는 세 곳에서 같은 상한(`kMaxFrameStep`, 1/20초)으로 잘린다** — `Animator`·`IsoController`·`IsoSceneComponent`. 서로 다른 값을 쓰면 이동 거리와 걸음 수가 어긋난다. 400ms 짜리 프레임 하나가 공격의 예비동작을 삼키거나 캐릭터를 몇 타일 순간이동시키는 것보다, 잠깐 느려지는 편이 훨씬 낫다.

**아이소 이동 시 추가 처리**:
- `carry` 는 **화면 공간** 이동량으로 준다 (`iso.project` 후의 차분). 월드 좌표로 주면 망토가 엉뚱한 방향으로 날린다.
- 경사/계단은 `reachable` + `solveIk2` 로 발을 지면 높이에 붙인다.

---

## 타이밍 표

60fps 기준. 게임 감각의 표준값이며, 여기서 크게 벗어나면 "반응이 굼뜨다/가볍다"고 느껴진다.

| 동작 | 전체 | 예비 | 타격/핵심 | 회복 |
|------|------|------|-----------|------|
| 경공격 | 0.35 s | 0.10 | 0.05 | 0.20 |
| 중공격 | 0.65 s | 0.24 | 0.07 | 0.34 |
| 대검 휘두르기 | 0.95 s | 0.38 | 0.09 | 0.48 |
| 찌르기 | 0.42 s | 0.14 | 0.05 | 0.23 |
| 시전(캐스팅) | 1.20 s | 0.85 | 0.10 | 0.25 |
| 피격 리액션 | 0.30 s | — | 0.04 | 0.26 |
| 회피 구르기 | 0.55 s | 0.08 | 0.30 | 0.17 |
| 점프 | 0.70 s | 0.12 | 0.40 (체공) | 0.18 |
| 걷기 1주기 | 0.95 s | | | |
| 달리기 1주기 | 0.58 s | | | |
| 방향 전환 | 0.15 s | | | |
| 히트스톱 | 0.05–0.08 s | | | |

---

## 흔한 실패

| 증상 | 원인 | 처방 |
|------|------|------|
| 관절이 한 바퀴 돈다 | `Pose.lerp` 의 선형 보간 | 해당 각도만 `lerpAngle` |
| 무릎이 반대로 꺾인다 | `knee` 가 음수 | `math.max(0, ...)` 로 클램프 |
| 발이 미끄러진다 | 액터에 맵의 `IsoView` 를 안 넘김 | `riggedFromArtist(…, iso: iso)` |
| 모든 동작이 두 배로 빠르다 | 씬과 `follow` 가 각자 시간을 밈 | `driveByScene` 규약 — 씬이 주인 |
| 연타하면 포즈가 튄다 | 전환 도중 전환에서 혼합 결과를 버림 | 화면에 있던 포즈에서 잇는다 |
| 히치 뒤 공격이 건너뛴다 | `dt` 미클램프 | `kMaxFrameStep` 로 자른다 |
| 판정이 그림보다 이르다/늦다 | 프레임 번호로 판정 | `ClipEvent` + `animator.fired` |
| 마네킹처럼 뻣뻣하다 | 좌우 완전 대칭 | 팔·다리에 위상차, `wobble` 추가 |
| 망토가 안 날린다 | `carry` 미전달 | 앵커 이동량을 `step` 에 전달 |
| 망토가 폭발한다 | `dt` 미클램프 / `teleport` 누락 | `min(dt, 1/30)`, 스폰 시 teleport |
| 타격감이 없다 | 3구간이 균등 | 예비 35 / 타격 12 / 회복 53 |
| 공격이 굼뜨다 | 예비가 너무 길다 | 위 타이밍 표 준수 |
| 정지 상태가 죽어 있다 | 호흡 없음 | `idle` 에 breath + wobble |
| 8방향 전환이 뚝뚝 끊긴다 | 즉시 스냅 | `lerpAngle` 로 0.15초 전환 |
