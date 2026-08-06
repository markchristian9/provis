import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/painting.dart' show Alignment;

/// 스플라인 및 실루엣 생성 유틸리티.
///
/// 절차적 캐릭터의 품질은 실루엣에서 결정된다. 다각형 그대로 그리면
/// 아무리 셰이딩을 잘해도 값싸 보이므로, 모든 형상은 Catmull-Rom 스플라인을
/// 3차 베지어로 변환해 곡률이 연속인 윤곽으로 만든다.
extension Offset2 on Offset {
  Offset get perp => Offset(-dy, dx);

  Offset normalized() {
    final d = distance;
    return d < 1e-9 ? Offset.zero : this / d;
  }

  Offset rotated(double a) {
    final c = math.cos(a), s = math.sin(a);
    return Offset(dx * c - dy * s, dx * s + dy * c);
  }

  double get angle => math.atan2(dy, dx);
}

Offset lerpO(Offset a, Offset b, double t) => a + (b - a) * t;

double lerpD(double a, double b, double t) => a + (b - a) * t;

double clamp01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);

/// smoothstep. 0..1 구간에서 부드럽게 상승.
double smoothstep(double edge0, double edge1, double x) {
  final t = clamp01((x - edge0) / (edge1 - edge0));
  return t * t * (3 - 2 * t);
}

/// 열린 Catmull-Rom 곡선을 Path 로 변환한다.
Path smoothOpenPath(List<Offset> pts, {double tension = 1.0}) {
  final path = Path();
  if (pts.isEmpty) return path;
  if (pts.length < 3) {
    path.moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    return path;
  }
  path.moveTo(pts.first.dx, pts.first.dy);
  for (var i = 0; i < pts.length - 1; i++) {
    final p0 = pts[i == 0 ? 0 : i - 1];
    final p1 = pts[i];
    final p2 = pts[i + 1];
    final p3 = pts[i + 2 >= pts.length ? pts.length - 1 : i + 2];
    final c1 = p1 + (p2 - p0) * (tension / 6);
    final c2 = p2 - (p3 - p1) * (tension / 6);
    path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
  }
  return path;
}

/// 닫힌 Catmull-Rom 곡선을 Path 로 변환한다. 실루엣 생성의 기본 도구.
Path smoothClosedPath(List<Offset> pts, {double tension = 1.0}) {
  final path = Path();
  final n = pts.length;
  if (n < 3) return path;
  path.moveTo(pts[0].dx, pts[0].dy);
  for (var i = 0; i < n; i++) {
    final p0 = pts[(i - 1 + n) % n];
    final p1 = pts[i];
    final p2 = pts[(i + 1) % n];
    final p3 = pts[(i + 2) % n];
    final c1 = p1 + (p2 - p0) * (tension / 6);
    final c2 = p2 - (p3 - p1) * (tension / 6);
    path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
  }
  path.close();
  return path;
}

/// 폴리라인을 균등 간격으로 재표본화한다. 두께 프로파일을 적용하기 전에
/// 스파인을 고르게 만들어, 곡률이 큰 구간에서 실루엣이 뭉치는 것을 막는다.
List<Offset> resample(List<Offset> pts, int count) {
  if (pts.length < 2 || count < 2) return List.of(pts);
  final segLen = <double>[];
  var total = 0.0;
  for (var i = 0; i < pts.length - 1; i++) {
    final d = (pts[i + 1] - pts[i]).distance;
    segLen.add(d);
    total += d;
  }
  if (total < 1e-9) return List.filled(count, pts.first);
  final out = <Offset>[pts.first];
  final step = total / (count - 1);
  var seg = 0;
  var acc = 0.0;
  for (var i = 1; i < count - 1; i++) {
    final target = step * i;
    while (seg < segLen.length - 1 && acc + segLen[seg] < target) {
      acc += segLen[seg];
      seg++;
    }
    final t = segLen[seg] < 1e-9 ? 0.0 : (target - acc) / segLen[seg];
    out.add(lerpO(pts[seg], pts[seg + 1], t));
  }
  out.add(pts.last);
  return out;
}

/// 스파인을 스플라인으로 부드럽게 만든 뒤 촘촘한 폴리라인으로 되돌린다.
List<Offset> smoothPolyline(List<Offset> pts, int samples, {double tension = 1.0}) {
  if (pts.length < 3) return resample(pts, samples);
  final out = <Offset>[];
  final segs = pts.length - 1;
  final per = math.max(2, (samples / segs).ceil());
  for (var i = 0; i < segs; i++) {
    final p0 = pts[i == 0 ? 0 : i - 1];
    final p1 = pts[i];
    final p2 = pts[i + 1];
    final p3 = pts[i + 2 >= pts.length ? pts.length - 1 : i + 2];
    for (var j = 0; j < per; j++) {
      final t = j / per;
      final t2 = t * t, t3 = t2 * t;
      final v = (p1 * 2.0 +
              (p2 - p0) * (t * tension) +
              (p0 * 2.0 - p1 * 5.0 + p2 * 4.0 - p3) * (t2 * tension) +
              (p1 * 3.0 - p0 - p2 * 3.0 + p3) * (t3 * tension)) *
          0.5;
      out.add(v);
    }
  }
  out.add(pts.last);
  return out;
}

/// 스파인과 반지름 프로파일로부터 닫힌 실루엣을 만든다.
///
/// 팔·다리·목·꼬리·촉수 등 "축을 가진 모든 형상"의 공통 생성기다.
/// [radii] 는 스파인 길이에 정규화된 프로파일이며, 스파인 표본 수와
/// 달라도 선형 보간해 맞춘다. 이 덕분에 근육의 부풀림 같은 두께 곡선을
/// 골격과 독립적으로 저작할 수 있다.
Path tube(
  List<Offset> spine,
  List<double> radii, {
  bool capStart = true,
  bool capEnd = true,
  int samples = 22,
  double tension = 1.0,
  /// 좌우 비대칭. 0 이면 대칭, 양수면 왼쪽(법선 +) 이 두꺼워진다.
  double bias = 0.0,
}) {
  final s = spine.length >= 3 ? smoothPolyline(spine, samples, tension: tension) : resample(spine, samples);
  final n = s.length;
  if (n < 2) return Path();

  double radiusAt(double t) {
    if (radii.isEmpty) return 1;
    if (radii.length == 1) return radii.first;
    final x = t * (radii.length - 1);
    final i = x.floor().clamp(0, radii.length - 2);
    return lerpD(radii[i], radii[i + 1], x - i);
  }

  final left = <Offset>[];
  final right = <Offset>[];
  for (var i = 0; i < n; i++) {
    final t = i / (n - 1);
    final tangent = (i == 0
            ? s[1] - s[0]
            : i == n - 1
                ? s[n - 1] - s[n - 2]
                : s[i + 1] - s[i - 1])
        .normalized();
    final nrm = tangent.perp;
    final r = radiusAt(t);
    left.add(s[i] + nrm * (r * (1 + bias)));
    right.add(s[i] - nrm * (r * (1 - bias)));
  }

  final ring = <Offset>[];
  ring.addAll(left);

  // 끝단 캡: 접선 방향으로 반원을 그려 잘린 단면이 보이지 않게 한다.
  if (capEnd) {
    final tan = (s[n - 1] - s[n - 2]).normalized();
    final r = radiusAt(1);
    const steps = 5;
    for (var i = 1; i < steps; i++) {
      final a = math.pi / 2 - math.pi * i / steps;
      ring.add(s[n - 1] + tan.rotated(a) * r);
    }
  }

  ring.addAll(right.reversed);

  if (capStart) {
    final tan = (s[0] - s[1]).normalized();
    final r = radiusAt(0);
    const steps = 5;
    for (var i = 1; i < steps; i++) {
      final a = math.pi / 2 - math.pi * i / steps;
      ring.add(s[0] + tan.rotated(a) * r);
    }
  }

  return smoothClosedPath(ring, tension: 0.8);
}

/// 타원을 스플라인 링으로 만들고 반지름을 각도 함수로 변조한다.
/// 유기체의 몸통·머리·알·물집처럼 "덩어리"를 만드는 생성기.
Path blob(
  Offset center,
  double rx,
  double ry, {
  int points = 14,
  double rotation = 0,
  double Function(double angle, double t)? warp,
}) {
  final ring = <Offset>[];
  for (var i = 0; i < points; i++) {
    final t = i / points;
    final a = t * math.pi * 2;
    final m = warp?.call(a, t) ?? 1.0;
    final p = Offset(math.cos(a) * rx * m, math.sin(a) * ry * m);
    ring.add(center + p.rotated(rotation));
  }
  return smoothClosedPath(ring);
}

/// 두 Path 사이를 잇는 부드러운 연결부(웨브). 어깨-몸통, 목-머리처럼
/// 파츠 경계가 딱딱하게 끊기는 곳을 유기적으로 메운다.
Path web(Offset a, double ra, Offset b, double rb, {double bulge = 0.25}) {
  final dir = (b - a).normalized();
  final nrm = dir.perp;
  final mid = lerpO(a, b, 0.5);
  final len = (b - a).distance;
  final rm = lerpD(ra, rb, 0.5) * (1 + bulge);
  return tube(
    [a - dir * ra * 0.2, mid, b + dir * rb * 0.2],
    [ra, rm, rb],
    samples: 12,
  )..addOval(Rect.fromCenter(center: mid + nrm * 0, width: len * 0.1, height: len * 0.1));
}

/// Rect 안의 한 점을 Alignment 로 변환. 그라디언트 중심을 형상 위의
/// 실제 좌표(예: 광원 방향 스펙큘러 지점)로 지정할 때 쓴다.
Alignment alignIn(Rect b, Offset p) => Alignment(
      b.width < 1e-6 ? 0 : (p.dx - b.center.dx) / (b.width / 2),
      b.height < 1e-6 ? 0 : (p.dy - b.center.dy) / (b.height / 2),
    );
