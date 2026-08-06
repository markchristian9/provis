import 'dart:math' as math;
import 'dart:ui';

import '../core/spline.dart';

/// 베를레 적분 기반 사슬.
///
/// 망토·머리카락·꼬리·사슬 장식 등 "몸이 움직인 뒤에 뒤따라오는" 모든 것에
/// 쓴다. 키프레임으로는 결코 얻을 수 없는 관성과 지연이 여기서 나온다.
class VerletChain {
  VerletChain({
    required Offset anchor,
    required this.segments,
    required this.segmentLength,
    Offset initialDir = const Offset(0, 1),
    this.gravity = 900,
    this.damping = 0.986,
    this.stiffness = 0.62,
    this.iterations = 6,
  }) {
    final dir = initialDir.normalized();
    for (var i = 0; i <= segments; i++) {
      final p = anchor + dir * (segmentLength * i);
      pos.add(p);
      prev.add(p);
    }
  }

  final int segments;
  final double segmentLength;
  final double gravity;
  final double damping;
  final double stiffness;
  final int iterations;

  final List<Offset> pos = [];
  final List<Offset> prev = [];

  /// 사슬 끝을 향한 고정 방향 유도(예: 꼬리가 몸 뒤로 뻗으려는 성질).
  Offset restDir = const Offset(0, 1);
  double restStrength = 0.0;

  void step(double dt, Offset anchor, {Offset wind = Offset.zero, Offset carry = Offset.zero}) {
    if (dt <= 0) return;
    final d = math.min(dt, 1 / 30);
    final acc = Offset(0, gravity) + wind;

    for (var i = 1; i < pos.length; i++) {
      final v = (pos[i] - prev[i]) * damping;
      prev[i] = pos[i];
      // carry: 앵커의 이동을 사슬 전체에 관성으로 전달한다. 캐릭터가 달릴 때
      // 망토가 뒤로 날리는 것은 중력이 아니라 이 항의 효과다.
      pos[i] = pos[i] + v + acc * (d * d) - carry * (d * (i / pos.length));
    }
    pos[0] = anchor;
    prev[0] = anchor;

    for (var it = 0; it < iterations; it++) {
      for (var i = 0; i < pos.length - 1; i++) {
        final a = pos[i];
        final b = pos[i + 1];
        final delta = b - a;
        final dist = delta.distance;
        if (dist < 1e-6) continue;
        final diff = (dist - segmentLength) / dist;
        final corr = delta * (diff * 0.5 * stiffness);
        if (i > 0) pos[i] = a + corr;
        pos[i + 1] = b - corr;
      }
      if (restStrength > 0) {
        for (var i = 1; i < pos.length; i++) {
          final want = pos[i - 1] + restDir * segmentLength;
          pos[i] = lerpO(pos[i], want, restStrength * 0.1);
        }
      }
      pos[0] = anchor;
    }
  }

  /// 앵커를 기준으로 사슬 전체를 즉시 이동시킨다(순간이동/리셋).
  void teleport(Offset anchor, {Offset dir = const Offset(0, 1)}) {
    final n = dir.normalized();
    for (var i = 0; i < pos.length; i++) {
      pos[i] = anchor + n * (segmentLength * i);
      prev[i] = pos[i];
    }
  }
}

/// 두 개의 사슬을 가로로 묶어 만든 천 조각.
///
/// 한 줄짜리 사슬은 리본밖에 못 만들지만, 두 줄을 교차 구속으로 묶으면
/// 폭을 가진 면이 되어 망토가 펄럭이며 실루엣이 살아난다.
class ClothStrip {
  ClothStrip({
    required Offset anchorLeft,
    required Offset anchorRight,
    required this.segments,
    required this.segmentLength,
    double gravity = 780,
    double damping = 0.985,
    this.crossIterations = 4,
  })  : left = VerletChain(
          anchor: anchorLeft,
          segments: segments,
          segmentLength: segmentLength,
          gravity: gravity,
          damping: damping,
        ),
        right = VerletChain(
          anchor: anchorRight,
          segments: segments,
          segmentLength: segmentLength,
          gravity: gravity,
          damping: damping,
        ),
        width = (anchorRight - anchorLeft).distance;

  final int segments;
  final double segmentLength;
  final int crossIterations;
  final VerletChain left;
  final VerletChain right;
  final double width;

  /// 아래로 갈수록 폭이 넓어지는 정도(A 라인 망토).
  double flare = 0.55;

  void step(
    double dt,
    Offset anchorLeft,
    Offset anchorRight, {
    Offset wind = Offset.zero,
    Offset carry = Offset.zero,
  }) {
    left.step(dt, anchorLeft, wind: wind, carry: carry);
    right.step(dt, anchorRight, wind: wind * 1.12, carry: carry);

    for (var it = 0; it < crossIterations; it++) {
      for (var i = 1; i <= segments; i++) {
        final t = i / segments;
        final want = width * (1 + flare * t);
        final a = left.pos[i];
        final b = right.pos[i];
        final delta = b - a;
        final dist = delta.distance;
        if (dist < 1e-6) continue;
        final corr = delta * ((dist - want) / dist * 0.5 * 0.7);
        left.pos[i] = a + corr;
        right.pos[i] = b - corr;
      }
    }
  }

  /// 천의 외곽 실루엣. 두 사슬을 잇고 아래 끝을 살짝 늘어뜨려 옷자락을 만든다.
  Path silhouette({double hemSag = 0.18}) {
    final ring = <Offset>[];
    ring.addAll(left.pos);
    // 밑단: 좌우 끝점 사이를 아래로 처지게 통과시킨다.
    final a = left.pos.last;
    final b = right.pos.last;
    final sag = (b - a).distance * hemSag;
    ring.add(lerpO(a, b, 0.32) + Offset(0, sag));
    ring.add(lerpO(a, b, 0.68) + Offset(0, sag * 0.86));
    ring.addAll(right.pos.reversed);
    return smoothClosedPath(ring, tension: 0.85);
  }

  /// 천 위의 주름 선. 조명과 함께 쓰면 면이 접혀 있음을 즉시 전달한다.
  List<Path> folds(int count) {
    final out = <Path>[];
    for (var f = 1; f <= count; f++) {
      final t = f / (count + 1);
      final pts = <Offset>[];
      for (var i = 0; i <= segments; i++) {
        final base = lerpO(left.pos[i], right.pos[i], t);
        final wobbleAmt = math.sin(t * math.pi) * (i / segments) * 6;
        final n = (right.pos[i] - left.pos[i]).normalized().perp;
        pts.add(base + n * wobbleAmt * math.sin(t * 9.1 + f));
      }
      out.add(smoothOpenPath(pts, tension: 0.9));
    }
    return out;
  }
}
