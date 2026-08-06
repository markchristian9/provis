import 'dart:math' as math;
import 'dart:ui';

import 'light.dart';
import 'palette.dart';

const Color _clear = Color(0x00000000);

Alignment _flip(Alignment a) => Alignment(-a.x, -a.y);

/// 하나의 [Path] 를 3점 조명 아래에서 입체로 칠한다.
///
/// 2D 절차 캐릭터가 종이처럼 보이는 가장 큰 이유는 각 파츠가 단색이기
/// 때문이다. 여기서는 파츠마다 확산광 → 바닥 반사광 → 림라이트 →
/// 스펙큘러 → 가장자리 감쇠를 순서대로 얹어, 같은 실루엣에서도 볼륨이
/// 읽히게 만든다. 모든 파츠가 같은 [LightRig] 를 쓰므로 광원을 하나
/// 돌리면 캐릭터 전체가 일관되게 따라 돈다.
class Shade {
  Shade._();

  static void part(
    Canvas canvas,
    Path path,
    Color base,
    LightRig rig, {
    /// 0 이면 카메라 쪽(근거리), 1 이면 반대쪽 사지. 클수록 대기 중에
    /// 묻혀 어둡고 흐려진다 — 정측면 실루엣에 깊이를 만드는 핵심 장치.
    double depth = 0,
    double rim = 0.85,
    double spec = 0,
    double edgeDark = 0.5,
    double roughness = 1,
  }) {
    final b = path.getBounds();
    if (b.width < 0.2 || b.height < 0.2) return;

    final body = depth > 0 ? mix(base, rig.ambient, 0.42 * depth) : base;
    final key = rig.keyAlign;

    // 1) 확산광. 광원 쪽은 키 색으로 데워지고 반대쪽은 환경광에 잠긴다.
    final lit = mix(body, rig.keyColor, 0.34 * rig.keyIntensity * (1 - depth * 0.55));
    final shadow = mix(body, rig.ambient, 0.50 + 0.16 * depth);
    canvas.drawPath(
      path,
      Paint()
        ..isAntiAlias = true
        ..shader = LinearGradient(
          begin: key,
          end: _flip(key),
          colors: [lit, body, shadow],
          stops: const [0.0, 0.44, 1.0],
        ).createShader(b),
    );

    // 2) 바닥 반사광. 아래쪽에서 올라오는 약한 따뜻함이 없으면 그림자가
    //    죽은 회색으로 가라앉는다.
    canvas.drawPath(
      path,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.center,
          colors: [
            rig.bounce.withValues(alpha: 0.30 * (1 - depth * 0.6)),
            _clear,
          ],
        ).createShader(b),
    );

    // 3) 림라이트. 실루엣을 배경에서 떼어내는 역광.
    if (rim > 0) {
      final r = rig.rimAlign;
      canvas.drawPath(
        path,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = LinearGradient(
            begin: r,
            end: _flip(r),
            colors: [
              rig.rimColor.withValues(
                alpha: (0.52 * rim * rig.rimIntensity * (1 - depth * 0.75)).clamp(0.0, 1.0),
              ),
              _clear,
            ],
            stops: const [0.0, 0.34],
          ).createShader(b),
      );
    }

    // 4) 스펙큘러. 금속과 젖은 표면에서만 좁고 강하게 튄다.
    if (spec > 0) {
      canvas.drawPath(
        path,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = RadialGradient(
            center: key * 0.65,
            radius: 0.30 + 0.45 * roughness,
            colors: [
              rig.keyColor.withValues(alpha: (spec * (1 - depth * 0.8)).clamp(0.0, 1.0)),
              _clear,
            ],
            stops: const [0.0, 1.0],
          ).createShader(b),
      );
    }

    // 5) 가장자리 감쇠. 실루엣 안쪽으로 파고드는 그림자가 파츠에
    //    두께를 주고 겹친 파츠끼리의 경계를 읽히게 한다.
    if (edgeDark > 0) {
      final w = math.max(1.5, math.min(b.width, b.height) * 0.22);
      canvas.save();
      canvas.clipPath(path);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w
          ..color = shiftColor(shadow, dl: -0.10)
              .withValues(alpha: (0.55 * edgeDark).clamp(0.0, 1.0))
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.55),
      );
      canvas.restore();
    }
  }

  /// 파츠가 겹치는 곳에 찍는 접촉 그림자. 팔이 몸통 앞을 지날 때
  /// 이것이 없으면 두 파츠가 같은 평면에 붙어 보인다.
  static void contact(Canvas canvas, Offset at, double radius, {double strength = 0.5}) {
    canvas.drawCircle(
      at,
      radius,
      Paint()
        ..color = const Color(0xFF000000).withValues(alpha: (0.42 * strength).clamp(0.0, 1.0))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.75),
    );
  }

  /// 발광체. 눈·마법·룬처럼 스스로 빛나는 것은 확산광 규칙에서 제외하고
  /// 중심부를 흰색으로 태워 블룸 느낌을 만든다.
  static void glow(
    Canvas canvas,
    Offset center,
    double radius,
    Color color, {
    double intensity = 1,
  }) {
    canvas.drawCircle(
      center,
      radius * 2.4,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: (0.55 * intensity).clamp(0.0, 1.0)),
            color.withValues(alpha: (0.16 * intensity).clamp(0.0, 1.0)),
            _clear,
          ],
          stops: const [0.0, 0.35, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: radius * 2.4)),
    );
    canvas.drawCircle(
      center,
      radius * 0.55,
      Paint()
        ..blendMode = BlendMode.plus
        ..color = mix(color, const Color(0xFFFFFFFF), 0.6)
            .withValues(alpha: (0.9 * intensity).clamp(0.0, 1.0)),
    );
  }

  /// 지면에 드리우는 접지 그림자. 광원 방향으로 늘어나고, 발이 뜰수록
  /// 흐려지고 넓어진다.
  static void groundShadow(
    Canvas canvas,
    Offset at,
    double width,
    LightRig rig, {
    double lift = 0,
    double strength = 1,
  }) {
    final spread = 1 + lift * 1.9;
    final dir = rig.shadowDir;
    final rect = Rect.fromCenter(
      center: at + Offset(dir.dx * width * 0.35, 0),
      width: width * 1.65 * spread,
      height: width * 0.42 * spread,
    );
    canvas.drawOval(
      rect,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF000000)
                .withValues(alpha: (0.55 * strength / spread).clamp(0.0, 1.0)),
            _clear,
          ],
          stops: const [0.25, 1.0],
        ).createShader(rect)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, width * 0.10 * spread),
    );
  }
}
