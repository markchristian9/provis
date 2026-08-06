import 'dart:math' as math;
import 'dart:ui';

import '../core/spline.dart';

/// 2본 역운동학. 관절 애니메이션의 전부라고 해도 될 만큼 자주 쓴다.
///
/// [root] 에서 [target] 까지 길이 [l1], [l2] 의 두 마디로 닿을 때 중간 관절의
/// 위치를 돌려준다. [bend] 는 굽는 방향(+1/-1)이며, 팔꿈치는 뒤로, 무릎은
/// 앞으로 굽는다는 해부학적 제약을 호출부가 부호로 표현한다.
Offset solveIk2(Offset root, Offset target, double l1, double l2, double bend) {
  var delta = target - root;
  var d = delta.distance;
  final maxD = (l1 + l2) * 0.999;
  final minD = (l1 - l2).abs() * 1.001 + 1e-4;
  if (d > maxD) {
    delta = delta.normalized() * maxD;
    d = maxD;
  } else if (d < minD) {
    if (d < 1e-6) {
      delta = const Offset(0, 1) * minD;
    } else {
      delta = delta.normalized() * minD;
    }
    d = minD;
  }
  final dir = delta / d;
  final a = (l1 * l1 - l2 * l2 + d * d) / (2 * d);
  final h = math.sqrt(math.max(0, l1 * l1 - a * a));
  return root + dir * a + dir.perp * (h * bend);
}

/// IK 로 풀린 목표점이 사슬 길이를 넘어설 때 실제로 닿는 끝점.
/// 발이 지면을 파고들지 않게 보정할 때 쓴다.
Offset reachable(Offset root, Offset target, double maxLen) {
  final d = target - root;
  return d.distance <= maxLen ? target : root + d.normalized() * maxLen;
}

/// 각도를 최단 경로로 보간한다. 포즈 전환에서 관절이 한 바퀴 도는 것을 막는다.
double lerpAngle(double a, double b, double t) {
  var diff = (b - a) % (math.pi * 2);
  if (diff > math.pi) diff -= math.pi * 2;
  if (diff < -math.pi) diff += math.pi * 2;
  return a + diff * t;
}

/// 기준점에서 각도와 길이로 뻗은 점.
Offset polar(Offset from, double angle, double len) =>
    from + Offset(math.cos(angle) * len, math.sin(angle) * len);
