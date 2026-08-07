import '../core/rng.dart';

/// 캐릭터 한 구의 골격 치수.
///
/// 모든 길이는 전체 키 [height] 에 대한 비율로 결정된다. 절차적 캐릭터에서
/// 비율은 실루엣만큼이나 인상을 좌우한다 — 다리가 길면 영웅적으로, 팔이 길고
/// 상체가 무거우면 짐승처럼 보인다. 애니메이션 클립은 이 치수를 모르고
/// 관절 각도만 다루므로, 같은 클립이 8등신 영웅과 4등신 괴물 모두에서
/// 자연스럽게 재생된다.
class Body {
  const Body({
    required this.height,
    required this.hipHeight,
    required this.torso,
    required this.neck,
    required this.headLen,
    required this.headWidth,
    required this.shoulderHalf,
    required this.hipHalf,
    required this.upperArm,
    required this.foreArm,
    required this.hand,
    required this.thigh,
    required this.shin,
    required this.foot,
    required this.bulk,
    required this.hunch,
    required this.depth,
  });

  /// 발바닥에서 정수리까지.
  final double height;

  /// 지면에서 골반 관절까지. 걸음 폭과 무게중심 높이를 결정한다.
  final double hipHeight;

  /// 골반에서 가슴(어깨선)까지.
  final double torso;

  final double neck;
  final double headLen;
  final double headWidth;

  /// 어깨선 반폭. 근거리/원거리 팔의 좌우 어긋남에 쓰인다.
  final double shoulderHalf;
  final double hipHalf;

  final double upperArm;
  final double foreArm;
  final double hand;

  final double thigh;
  final double shin;
  final double foot;

  /// 근육량. 1.0 이 표준이며 팔다리·몸통 두께 전체에 곱해진다.
  final double bulk;

  /// 구부정한 정도(라디안). 몬스터는 크고 영웅은 거의 0 이다.
  final double hunch;

  /// 측면뷰에서 몸의 앞뒤 두께 비율. 가슴 판·골반 판의 폭을 만든다.
  final double depth;

  /// 어깨 폭·골반 폭만 바꾼 사본. 페이싱에 따라 좌우 폭이 화면에서
  /// 줄어드는 것을 반영할 때 쓴다 — 치수 자체를 건드리지 않으므로 IK 와
  /// 사지 길이는 그대로 유지된다.
  Body scaledWidth(double k) => Body(
    height: height,
    hipHeight: hipHeight,
    torso: torso,
    neck: neck,
    headLen: headLen,
    headWidth: headWidth,
    shoulderHalf: shoulderHalf * k,
    hipHalf: hipHalf * k,
    upperArm: upperArm,
    foreArm: foreArm,
    hand: hand,
    thigh: thigh,
    shin: shin,
    foot: foot,
    bulk: bulk,
    hunch: hunch,
    depth: depth,
  );

  double get shoulderY => -(hipHeight + torso);

  double get armLength => upperArm + foreArm;

  double get legLength => thigh + shin;

  /// 인간형 표준 비율. 8등신에 가까운 영웅 체형.
  factory Body.humanoid(Rng r, {double height = 300}) {
    final heroic = r.range(0.94, 1.06);
    final legRatio = r.range(0.485, 0.525);
    final bulk = r.bell(0.85, 1.25);
    return Body(
      height: height,
      hipHeight: height * legRatio,
      torso: height * r.range(0.275, 0.305) * heroic,
      neck: height * r.range(0.030, 0.045),
      headLen: height * r.range(0.115, 0.132),
      headWidth: height * r.range(0.078, 0.090),
      shoulderHalf: height * r.range(0.052, 0.070) * bulk,
      hipHalf: height * r.range(0.040, 0.052),
      upperArm: height * r.range(0.165, 0.185),
      foreArm: height * r.range(0.150, 0.168),
      hand: height * r.range(0.048, 0.058),
      thigh: height * legRatio * r.range(0.50, 0.54),
      shin: height * legRatio * r.range(0.46, 0.50),
      foot: height * r.range(0.055, 0.068),
      bulk: bulk,
      hunch: r.range(0.0, 0.06),
      depth: r.range(0.86, 1.06),
    );
  }

  /// 짐승형. 다리가 짧고 팔이 길며 상체가 무겁다. 실루엣만으로
  /// "사람이 아니다" 가 읽히도록 인간형과 비율 대역을 겹치지 않게 한다.
  factory Body.beast(Rng r, {double height = 320}) {
    final legRatio = r.range(0.40, 0.46);
    final bulk = r.bell(1.15, 1.75);
    return Body(
      height: height,
      hipHeight: height * legRatio,
      torso: height * r.range(0.30, 0.36),
      neck: height * r.range(0.020, 0.050),
      headLen: height * r.range(0.135, 0.175),
      headWidth: height * r.range(0.100, 0.135),
      shoulderHalf: height * r.range(0.075, 0.105) * bulk * 0.8,
      hipHalf: height * r.range(0.050, 0.070),
      upperArm: height * r.range(0.190, 0.235),
      foreArm: height * r.range(0.175, 0.225),
      hand: height * r.range(0.060, 0.085),
      thigh: height * legRatio * r.range(0.52, 0.60),
      shin: height * legRatio * r.range(0.44, 0.52),
      foot: height * r.range(0.070, 0.095),
      bulk: bulk,
      hunch: r.range(0.12, 0.34),
      depth: r.range(1.0, 1.35),
    );
  }

  /// Winged predator: broad chest, compact legs, and a forward-leaning neck.
  factory Body.drake(Rng r, {double height = 320}) {
    final legRatio = r.range(0.40, 0.44);
    final bulk = r.bell(1.12, 1.42);
    return Body(
      height: height,
      hipHeight: height * legRatio,
      torso: height * r.range(0.31, 0.34),
      neck: height * r.range(0.045, 0.065),
      headLen: height * r.range(0.115, 0.140),
      headWidth: height * r.range(0.086, 0.105),
      shoulderHalf: height * r.range(0.085, 0.108) * bulk * 0.82,
      hipHalf: height * r.range(0.050, 0.062),
      upperArm: height * r.range(0.175, 0.205),
      foreArm: height * r.range(0.160, 0.190),
      hand: height * r.range(0.055, 0.070),
      thigh: height * legRatio * r.range(0.50, 0.56),
      shin: height * legRatio * r.range(0.46, 0.51),
      foot: height * r.range(0.075, 0.095),
      bulk: bulk,
      hunch: r.range(0.16, 0.25),
      depth: r.range(1.05, 1.28),
    );
  }

  /// Spectral caster: a narrow core, long arms, and a high floating posture.
  factory Body.wraith(Rng r, {double height = 320}) {
    final legRatio = r.range(0.48, 0.52);
    final bulk = r.bell(0.72, 0.90);
    return Body(
      height: height,
      hipHeight: height * legRatio,
      torso: height * r.range(0.30, 0.33),
      neck: height * r.range(0.040, 0.060),
      headLen: height * r.range(0.135, 0.155),
      headWidth: height * r.range(0.082, 0.098),
      shoulderHalf: height * r.range(0.054, 0.068),
      hipHalf: height * r.range(0.036, 0.046),
      upperArm: height * r.range(0.215, 0.245),
      foreArm: height * r.range(0.195, 0.225),
      hand: height * r.range(0.055, 0.070),
      thigh: height * legRatio * r.range(0.48, 0.53),
      shin: height * legRatio * r.range(0.47, 0.52),
      foot: height * r.range(0.045, 0.058),
      bulk: bulk,
      hunch: r.range(0.03, 0.10),
      depth: r.range(0.78, 0.94),
    );
  }

  /// Brood creature: low center of gravity with a dense thorax for extra legs.
  factory Body.arachnid(Rng r, {double height = 320}) {
    final legRatio = r.range(0.33, 0.38);
    final bulk = r.bell(1.02, 1.28);
    return Body(
      height: height,
      hipHeight: height * legRatio,
      torso: height * r.range(0.27, 0.31),
      neck: height * r.range(0.018, 0.030),
      headLen: height * r.range(0.105, 0.125),
      headWidth: height * r.range(0.105, 0.130),
      shoulderHalf: height * r.range(0.082, 0.102) * bulk * 0.82,
      hipHalf: height * r.range(0.070, 0.088),
      upperArm: height * r.range(0.185, 0.215),
      foreArm: height * r.range(0.175, 0.205),
      hand: height * r.range(0.055, 0.072),
      thigh: height * legRatio * r.range(0.50, 0.56),
      shin: height * legRatio * r.range(0.46, 0.52),
      foot: height * r.range(0.072, 0.092),
      bulk: bulk,
      hunch: r.range(0.25, 0.36),
      depth: r.range(1.15, 1.38),
    );
  }
}
