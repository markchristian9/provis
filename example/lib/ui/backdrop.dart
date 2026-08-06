import 'dart:math' as math;

import 'package:flutter/painting.dart';

import 'package:provis/provis.dart';

/// 대치 화면의 배경.
///
/// 배경의 임무는 예뻐지는 것이 아니라 두 실루엣을 떼어 놓는 것이다. 그래서
/// 화면 왼쪽은 영웅의 무드색, 오른쪽은 괴물의 무드색으로 칠하고 그 사이를
/// 부드럽게 섞는다. 캐릭터는 자기 색과 보색인 배경 앞에 서게 되므로 어떤
/// 조합을 골라도 실루엣이 묻히지 않는다.
void paintBackdrop(
  Canvas c,
  Size size,
  List<Color> left,
  List<Color> right,
  double t, {
  double detail = 1.0,
}) {
  final rect = Offset.zero & size;

  c.drawRect(rect, Paint()..shader = _sky(rect, left));

  // 오른쪽 무드를 수평 알파 마스크로 덮어 두 세계를 한 화면에 둔다.
  c.saveLayer(rect, Paint());
  c.drawRect(rect, Paint()..shader = _sky(rect, right));
  c.drawRect(
    rect,
    Paint()
      ..blendMode = BlendMode.dstIn
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [white.fade(0.0), white.fade(0.0), white.fade(1.0)],
        stops: const [0.0, 0.30, 0.86],
      ).createShader(rect),
  );
  c.restore();

  final horizon = size.height * 0.74;

  // 지평선의 광막. 캐릭터의 발치가 어디인지 알려 준다.
  c.drawRect(
    Rect.fromLTRB(0, horizon - size.height * 0.26, size.width, horizon + 8),
    Paint()
      ..blendMode = BlendMode.plus
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          left.last.mix(right.last, 0.5).fade(0.0),
          left.last.mix(right.last, 0.5).fade(0.28),
        ],
      ).createShader(
        Rect.fromLTRB(0, horizon - size.height * 0.26, size.width, horizon + 8),
      ),
  );

  // 바닥. 지평선 아래는 젖은 돌처럼 위쪽을 반사한다.
  final floor = Rect.fromLTRB(0, horizon, size.width, size.height);
  c.drawRect(
    floor,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          left.first.mix(right.first, 0.5).lighten(0.06),
          left.first.mix(right.first, 0.5).darken(0.55),
        ],
      ).createShader(floor),
  );

  if (detail > 0.4) {
    _floorGrid(c, size, horizon, left, right);
    _dust(c, size, t, left, right);
  }

  // 원경의 폐허 실루엣. 깊이를 만드는 가장 값싼 방법.
  _ruins(c, size, horizon, left, right);

  // 비네트.
  c.drawRect(
    rect,
    Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.98,
        colors: [
          const Color(0x00000000),
          const Color(0x00000000),
          const Color(0x99000000),
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(rect),
  );
}

Shader _sky(Rect rect, List<Color> mood) => LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        mood[0],
        mood.length > 1 ? mood[1] : mood[0],
        mood.last,
      ],
      stops: const [0.0, 0.55, 1.0],
    ).createShader(rect);

// 바닥의 원근 격자. 선 간격이 지평선 쪽에서 촘촘해지며 깊이를 만든다.
void _floorGrid(
    Canvas c, Size size, double horizon, List<Color> left, List<Color> right) {
  final paint = Paint()..style = PaintingStyle.stroke;
  final tint = left.last.mix(right.last, 0.5);
  for (var i = 1; i < 14; i++) {
    final u = i / 14;
    final y = horizon + (size.height - horizon) * u * u;
    paint
      ..strokeWidth = 0.6 + u * 1.6
      ..color = tint.fade(0.16 * (1 - u * 0.5));
    c.drawLine(Offset(0, y), Offset(size.width, y), paint);
  }
  final vp = Offset(size.width * 0.5, horizon - size.height * 0.1);
  for (var i = -9; i <= 9; i++) {
    final x = size.width * 0.5 + i * size.width * 0.11;
    paint
      ..strokeWidth = 1.0
      ..color = tint.fade(0.10);
    c.drawLine(
      Offset(lerpD(vp.dx, x, 0.35), horizon),
      Offset(vp.dx + (x - vp.dx) * 4.5, size.height),
      paint,
    );
  }
}

void _dust(
    Canvas c, Size size, double t, List<Color> left, List<Color> right) {
  final n = Noise(101);
  for (var i = 0; i < 44; i++) {
    final sx = n.at1(i * 3.13);
    final sy = n.at1(i * 7.31 + 11);
    final life = (t * 0.035 + sy) % 1.0;
    final x = size.width * sx + math.sin(t * 0.4 + i) * 22;
    final y = size.height * (1.02 - life);
    final a = math.sin(life * math.pi) * 0.5;
    final tint = (x < size.width * 0.5 ? left.last : right.last).lighten(0.4);
    c.drawCircle(
      Offset(x, y),
      1.2 + n.at1(i * 5.7) * 2.2,
      Paint()
        ..blendMode = BlendMode.plus
        ..color = tint.fade(0.30 * a),
    );
  }
}

// 지평선 위로 솟은 무너진 탑들.
void _ruins(
    Canvas c, Size size, double horizon, List<Color> left, List<Color> right) {
  final n = Noise(7);
  for (var layer = 0; layer < 2; layer++) {
    final depth = layer == 0 ? 0.55 : 0.30;
    final base = horizon + layer * 6;
    final pts = <Offset>[Offset(-20, base)];
    var x = -20.0;
    var i = 0;
    while (x < size.width + 20) {
      final w = size.width * (0.05 + n.at1(i * 3.7 + layer * 31) * 0.09);
      final h = size.height *
          (0.05 + n.at1(i * 5.3 + layer * 17) * (layer == 0 ? 0.20 : 0.12));
      pts.add(Offset(x, base - h));
      pts.add(Offset(x + w, base - h * (0.6 + n.at1(i * 2.1) * 0.5)));
      x += w;
      i++;
    }
    pts.add(Offset(size.width + 20, base));
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    path.close();
    final tint = left.first.mix(right.first, 0.5);
    c.drawPath(
      path,
      Paint()
        ..color = tint.darken(depth).fade(layer == 0 ? 0.85 : 0.6)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, layer == 0 ? 1.5 : 4),
    );
  }
}

/// 스테이지 위에 얹는 전경 효과. 캐릭터 위로 지나가는 빛과 필름 비네트.
void paintForeground(Canvas c, Size size, double t, Color heroTint,
    Color monsterTint) {
  final rect = Offset.zero & size;
  // 두 진영에서 뻗어 나와 화면 중앙에서 부딪히는 빛.
  final pulse = 0.5 + 0.5 * math.sin(t * 0.7);
  c.drawRect(
    rect,
    Paint()
      ..blendMode = BlendMode.plus
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          heroTint.fade(0.10 + pulse * 0.04),
          heroTint.fade(0.0),
          monsterTint.fade(0.0),
          monsterTint.fade(0.10 + (1 - pulse) * 0.04),
        ],
        stops: const [0.0, 0.34, 0.66, 1.0],
      ).createShader(rect),
  );
}
