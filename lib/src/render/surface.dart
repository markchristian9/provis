import 'dart:math' as math;
import 'dart:ui';

import '../core/noise.dart';
import '../core/spline.dart';
import 'light.dart';
import 'palette.dart';

/// 재질 종류. 셰이딩 램프의 형태 자체를 바꾼다.
enum SurfaceKind { skin, cloth, leather, metal, chitin, bone, hair, gem, stone, flesh }

/// 렌더 품질. 낮출수록 패스 수를 줄여 웹/저사양에서도 프레임을 유지한다.
enum Quality { low, medium, high }

/// 한 파츠의 재질 정의.
///
/// 3D 의 PBR 파라미터를 2D 페인팅으로 번역한 것이다. roughness 는 스펙큘러
/// 반경으로, metalness 는 명암 램프의 비단조성(금속 특유의 어두운 중간톤과
/// 밝은 환경 반사 밴드)으로, sss 는 터미네이터 부근의 따뜻한 번짐으로 나타난다.
class Surface {
  const Surface({
    required this.albedo,
    this.kind = SurfaceKind.cloth,
    this.roughness = 0.6,
    this.metalness = 0.0,
    this.sss = 0.0,
    this.rim = 1.0,
    this.ao = 1.0,
    this.outline = 0.55,
    this.emissive,
    this.emissiveStrength = 0.0,
    this.detail = 0.0,
  });

  final Color albedo;
  final SurfaceKind kind;
  final double roughness;
  final double metalness;
  final double sss;
  final double rim;
  final double ao;
  final double outline;
  final Color? emissive;
  final double emissiveStrength;

  /// 미세 디테일(스크래치·주름·기공) 강도.
  final double detail;

  Surface copyWith({Color? albedo, double? roughness, double? rim, double? ao, double? outline}) => Surface(
        albedo: albedo ?? this.albedo,
        kind: kind,
        roughness: roughness ?? this.roughness,
        metalness: metalness,
        sss: sss,
        rim: rim ?? this.rim,
        ao: ao ?? this.ao,
        outline: outline ?? this.outline,
        emissive: emissive,
        emissiveStrength: emissiveStrength,
        detail: detail,
      );

  static Surface skin(Color c) => Surface(
        albedo: c,
        kind: SurfaceKind.skin,
        roughness: 0.68,
        sss: 0.85,
        rim: 1.0,
        outline: 0.42,
        detail: 0.15,
      );

  static Surface flesh(Color c) => Surface(
        albedo: c,
        kind: SurfaceKind.flesh,
        roughness: 0.55,
        sss: 1.0,
        rim: 1.15,
        outline: 0.5,
        detail: 0.4,
      );

  static Surface cloth(Color c) => Surface(
        albedo: c,
        kind: SurfaceKind.cloth,
        roughness: 0.92,
        sss: 0.18,
        rim: 0.75,
        outline: 0.6,
        detail: 0.25,
      );

  static Surface leather(Color c) => Surface(
        albedo: c,
        kind: SurfaceKind.leather,
        roughness: 0.72,
        rim: 0.85,
        outline: 0.7,
        detail: 0.35,
      );

  static Surface metal(Color c, {double polish = 0.8}) => Surface(
        albedo: c,
        kind: SurfaceKind.metal,
        roughness: (1 - polish).clamp(0.06, 0.9),
        metalness: 1.0,
        rim: 1.35,
        outline: 0.75,
        detail: 0.5,
      );

  static Surface chitin(Color c) => Surface(
        albedo: c,
        kind: SurfaceKind.chitin,
        roughness: 0.30,
        metalness: 0.35,
        rim: 1.3,
        outline: 0.8,
        detail: 0.45,
      );

  static Surface bone(Color c) => Surface(
        albedo: c,
        kind: SurfaceKind.bone,
        roughness: 0.62,
        sss: 0.35,
        rim: 1.0,
        outline: 0.7,
        detail: 0.3,
      );

  static Surface hair(Color c) => Surface(
        albedo: c,
        kind: SurfaceKind.hair,
        roughness: 0.34,
        rim: 1.5,
        outline: 0.5,
        detail: 0.6,
      );

  static Surface gem(Color c, {Color? glow}) => Surface(
        albedo: c,
        kind: SurfaceKind.gem,
        roughness: 0.05,
        metalness: 0.2,
        rim: 1.6,
        outline: 0.4,
        emissive: glow ?? c,
        emissiveStrength: 0.9,
      );

  static Surface stone(Color c) => Surface(
        albedo: c,
        kind: SurfaceKind.stone,
        roughness: 0.95,
        rim: 0.6,
        outline: 0.65,
        detail: 0.5,
      );
}

/// 재질별 명암 램프. 캐릭터가 "칠해진 그림"이 아니라 "빛을 받는 물체"로
/// 보이게 하는 핵심.
class _Ramp {
  _Ramp(Surface s, LightRig l) {
    final base = s.albedo;
    final key = l.keyColor;
    final ki = l.keyIntensity * l.exposure;

    hot = mix(shiftColor(base, dl: 0.24, ds: -0.16), key, 0.55 * ki);
    lit = mix(shiftColor(base, dl: 0.13, ds: -0.05), key, 0.30 * ki);
    mid = base;
    // 터미네이터에서 채도가 오르고 색상이 따뜻한 쪽으로 밀리는 것은 실제
    // 표면 산란의 결과이며, 이 한 줄이 그림을 크게 살린다.
    term = shiftColor(base, dl: -0.07, ds: 0.14, dh: -7);
    shade = mix(shiftColor(base, dl: -0.20, ds: 0.03), l.ambient, 0.44);
    deep = mix(shiftColor(base, dl: -0.29, ds: -0.04), l.ambient, 0.66);
    // 금속의 환경 반사 밴드: 하늘색이 비쳐 어두운 면 한가운데가 되레 밝다.
    sky = mix(mix(base, l.rimColor, 0.45), key, 0.10);
  }

  late final Color hot, lit, mid, term, shade, deep, sky;
}

final Noise _detailNoise = Noise(0x5EED);

/// 파츠 하나를 완성된 품질로 칠한다.
///
/// 순서가 곧 물리적 의미다: 확산 → 반사광 → 산란 → 차폐 → 정반사 → 미세
/// 디테일 → 림. 이 순서를 바꾸면 재질감이 무너지므로 호출부에서 개별 패스를
/// 조합하지 말고 이 함수를 쓴다.
void paintSurface(
  Canvas canvas,
  Path path,
  Surface s,
  LightRig light, {
  Quality quality = Quality.high,
  /// 다른 파츠에 가려진 정도. 몸통 뒤로 들어가는 팔 등에 0.3~0.6 을 준다.
  double occlusion = 0.0,
  /// 미세 디테일의 위상. 같은 파츠가 매 프레임 같은 무늬를 갖게 고정한다.
  double detailSeed = 0.0,
  /// 파츠 고유의 스케일(월드 단위). 아웃라인 두께 기준.
  double? unitScale,
}) {
  final b = path.getBounds();
  if (b.isEmpty || b.width < 0.4 || b.height < 0.4) return;

  final size = math.max(b.shortestSide, 1.0);
  final ramp = _Ramp(s, light);
  final unit = unitScale ?? size;

  // ── 발광체의 외곽 글로우는 형상 밖으로 나가므로 클립 이전에 그린다.
  if (s.emissive != null && s.emissiveStrength > 0 && quality != Quality.low) {
    final g = Paint()
      ..color = s.emissive!.withValues(alpha: 0.34 * s.emissiveStrength)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, size * 0.42)
      ..blendMode = BlendMode.plus;
    canvas.drawPath(path, g);
  }

  canvas.saveLayer(b.inflate(size * 0.6), Paint());
  canvas.clipPath(path, doAntiAlias: true);

  // ── 1. 확산: 광원 축을 따르는 명암 램프.
  final ka = light.keyAlign;
  final Paint basePaint = Paint();
  if (s.metalness > 0.5) {
    basePaint.shader = LinearGradient(
      begin: ka,
      end: -ka,
      colors: [ramp.hot, ramp.lit, ramp.mid, ramp.deep, ramp.shade, ramp.sky, ramp.deep, ramp.shade],
      stops: const [0.0, 0.09, 0.24, 0.40, 0.53, 0.68, 0.84, 1.0],
    ).createShader(b);
  } else if (s.kind == SurfaceKind.cloth) {
    // 천은 대비가 낮고 터미네이터가 넓다.
    basePaint.shader = LinearGradient(
      begin: ka,
      end: -ka,
      colors: [ramp.lit, ramp.mid, ramp.term, ramp.shade, ramp.deep],
      stops: const [0.0, 0.34, 0.58, 0.80, 1.0],
    ).createShader(b);
  } else {
    basePaint.shader = LinearGradient(
      begin: ka,
      end: -ka,
      colors: [ramp.hot, ramp.lit, ramp.mid, ramp.term, ramp.shade, ramp.deep],
      stops: const [0.0, 0.16, 0.42, 0.585, 0.79, 1.0],
    ).createShader(b);
  }
  canvas.drawRect(b.inflate(size * 0.5), basePaint);

  // ── 2. 바닥 반사광: 아래쪽에서 올라오는 따뜻한 되받이 빛.
  canvas.drawRect(
    b,
    Paint()
      ..blendMode = BlendMode.plus
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.center,
        colors: [light.bounce.withValues(alpha: 0.30), light.bounce.withValues(alpha: 0.0)],
      ).createShader(b),
  );

  // ── 3. 표면하 산란: 터미네이터 직전에서 살이 붉게 비친다.
  if (s.sss > 0.01 && quality != Quality.low) {
    final sssColor = shiftColor(s.albedo, dh: -14, ds: 0.35, dl: -0.05);
    canvas.drawRect(
      b,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = LinearGradient(
          begin: ka,
          end: -ka,
          colors: [
            sssColor.withValues(alpha: 0.0),
            sssColor.withValues(alpha: 0.34 * s.sss),
            sssColor.withValues(alpha: 0.0),
          ],
          stops: const [0.40, 0.615, 0.86],
        ).createShader(b),
    );
  }

  // ── 4. 내부 앰비언트 오클루전: 실루엣 안쪽 가장자리를 눌러 부피를 만든다.
  if (s.ao > 0.01) {
    final w = size * 0.55;
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w
        ..color = mix(light.ambient, const Color(0xFF000000), 0.55)
            .withValues(alpha: (0.44 * s.ao + 0.5 * occlusion).clamp(0, 0.92))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.34)
        ..blendMode = BlendMode.multiply,
    );
  }

  // ── 5. 정반사. roughness 가 반경을, metalness 가 색조를 결정한다.
  final specColor = mix(light.keyColor, shiftColor(s.albedo, dl: 0.35), s.metalness * 0.75);
  final specPos = b.center - light.keyDir * (size * 0.34);
  final specR = lerpD(0.20, 1.05, s.roughness);
  final specA = lerpD(0.85, 0.14, s.roughness) * (0.55 + 0.65 * s.metalness);
  canvas.drawRect(
    b,
    Paint()
      ..blendMode = BlendMode.plus
      ..shader = RadialGradient(
        center: alignIn(b, specPos),
        radius: specR,
        colors: [specColor.withValues(alpha: specA.clamp(0, 1)), specColor.withValues(alpha: 0.0)],
        stops: const [0.0, 1.0],
      ).createShader(b),
  );
  // 광택 재질은 좁고 뜨거운 코어 하이라이트를 하나 더 얹는다.
  if (s.roughness < 0.45 && quality == Quality.high) {
    canvas.drawRect(
      b,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(
          center: alignIn(b, specPos - light.keyDir * size * 0.06),
          radius: specR * 0.34,
          colors: [
            mix(specColor, const Color(0xFFFFFFFF), 0.6).withValues(alpha: 0.7 * (1 - s.roughness)),
            specColor.withValues(alpha: 0.0),
          ],
        ).createShader(b),
    );
  }

  // ── 6. 미세 디테일.
  if (s.detail > 0.01 && quality == Quality.high) {
    _paintMicroDetail(canvas, b, s, light, ramp, detailSeed);
  }

  // ── 7. 림라이트: 백라이트를 받는 쪽 실루엣이 빛난다. 배경에서 캐릭터를
  //       떼어내는 가장 강력한 장치다.
  if (s.rim > 0.01) {
    final ra = light.rimAlign;
    final rimMask = LinearGradient(
      begin: ra,
      end: -ra,
      colors: [
        light.rimColor.withValues(alpha: (0.85 * s.rim * light.rimIntensity).clamp(0, 1)),
        light.rimColor.withValues(alpha: 0.0),
      ],
      stops: const [0.0, 0.46],
    ).createShader(b);

    final soft = size * 0.16;
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = soft
        ..shader = rimMask
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, soft * 0.45)
        ..blendMode = BlendMode.plus,
    );
    // 날카로운 코어. 이게 있어야 가장자리가 "금속처럼" 선다.
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(unit * 0.03, size * 0.035)
        ..shader = rimMask
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, size * 0.012)
        ..blendMode = BlendMode.plus,
    );
  }

  // ── 8. 발광 재질의 내부 코어.
  if (s.emissive != null && s.emissiveStrength > 0) {
    canvas.drawRect(
      b,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 0.9,
          colors: [
            s.emissive!.withValues(alpha: 0.55 * s.emissiveStrength),
            s.emissive!.withValues(alpha: 0.0),
          ],
        ).createShader(b),
    );
  }

  canvas.restore();

  // ── 9. 윤곽선. 완전한 검정이 아니라 환경광으로 물든 어두운 색을 쓴다.
  if (s.outline > 0.01) {
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = (unit * 0.018).clamp(0.5, 2.4)
        ..color = mix(ramp.deep, light.ambient, 0.35).withValues(alpha: 0.55 * s.outline)
        ..isAntiAlias = true,
    );
  }
}

void _paintMicroDetail(Canvas canvas, Rect b, Surface s, LightRig light, _Ramp ramp, double seed) {
  final size = b.shortestSide;
  switch (s.kind) {
    case SurfaceKind.metal:
    case SurfaceKind.chitin:
      // 브러시드 스크래치. 광원 축과 직교하는 방향으로 흘려야 금속처럼 읽힌다.
      final dir = light.keyDir.perp;
      final count = (6 * s.detail).round() + 2;
      for (var i = 0; i < count; i++) {
        final t = (i + 1) / (count + 1);
        final n = _detailNoise.at1(seed * 13.7 + i * 3.3);
        final p = Offset(
          b.left + b.width * (t + (n - 0.5) * 0.18),
          b.top + b.height * ((n * 1.7) % 1.0),
        );
        final len = size * (0.35 + n * 0.7);
        canvas.drawLine(
          p - dir * len * 0.5,
          p + dir * len * 0.5,
          Paint()
            ..strokeWidth = size * 0.012 * (0.6 + n)
            ..color = (n > 0.5 ? ramp.hot : ramp.deep).withValues(alpha: 0.12 * s.detail)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, size * 0.008)
            ..blendMode = n > 0.5 ? BlendMode.plus : BlendMode.multiply,
        );
      }
    case SurfaceKind.cloth:
    case SurfaceKind.leather:
      // 접힘 주름. 광원 축을 가로지르는 짧은 곡선이 부드러운 요철을 만든다.
      final dir = light.keyDir.perp;
      final count = (5 * s.detail).round() + 2;
      for (var i = 0; i < count; i++) {
        final n = _detailNoise.at1(seed * 7.1 + i * 5.7);
        final m = _detailNoise.at1(seed * 3.3 + i * 11.9);
        final c = b.center + Offset((n - 0.5) * b.width * 0.8, (m - 0.5) * b.height * 0.85);
        final len = size * (0.5 + n * 0.9);
        final w = size * 0.10 * (0.5 + m);
        final a = c - dir * len * 0.5;
        final bb = c + dir * len * 0.5;
        final ctrl = lerpO(a, bb, 0.5) + light.keyDir * (len * 0.14 * (m - 0.5));
        final p = Path()
          ..moveTo(a.dx, a.dy)
          ..quadraticBezierTo(ctrl.dx, ctrl.dy, bb.dx, bb.dy);
        canvas.drawPath(
          p,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = w
            ..color = ramp.deep.withValues(alpha: 0.22 * s.detail)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.55)
            ..blendMode = BlendMode.multiply,
        );
        canvas.drawPath(
          p.shift(-light.keyDir * w * 0.6),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = w * 0.6
            ..color = ramp.lit.withValues(alpha: 0.16 * s.detail)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.5)
            ..blendMode = BlendMode.plus,
        );
      }
    case SurfaceKind.stone:
    case SurfaceKind.bone:
    case SurfaceKind.flesh:
      final count = (7 * s.detail).round() + 2;
      for (var i = 0; i < count; i++) {
        final n = _detailNoise.at1(seed * 9.9 + i * 4.4);
        final m = _detailNoise.at1(seed * 2.2 + i * 8.8);
        final c = b.center + Offset((n - 0.5) * b.width * 0.85, (m - 0.5) * b.height * 0.85);
        final r = size * (0.08 + n * 0.22);
        canvas.drawCircle(
          c,
          r,
          Paint()
            ..color = ramp.deep.withValues(alpha: 0.16 * s.detail)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.7)
            ..blendMode = BlendMode.multiply,
        );
        canvas.drawCircle(
          c - light.keyDir * r * 0.55,
          r * 0.55,
          Paint()
            ..color = ramp.lit.withValues(alpha: 0.13 * s.detail)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.55)
            ..blendMode = BlendMode.plus,
        );
      }
    default:
      break;
  }
}

/// 한 파츠가 다른 파츠 위에 드리우는 접촉 그림자.
///
/// 파츠를 따로따로 잘 칠해도 서로 붙어 있다는 느낌은 이 그림자에서 나온다.
void paintContactShadow(
  Canvas canvas,
  Path receiver,
  Path occluder,
  LightRig light, {
  double strength = 0.55,
  double spread = 6,
}) {
  canvas.save();
  canvas.clipPath(receiver, doAntiAlias: true);
  canvas.drawPath(
    occluder.shift(light.keyDir * spread * 0.5),
    Paint()
      ..color = mix(light.ambient, const Color(0xFF000000), 0.6).withValues(alpha: strength)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, spread)
      ..blendMode = BlendMode.multiply,
  );
  canvas.restore();
}

/// 지면에 떨어지는 그림자. 접지감을 만든다.
void paintGroundShadow(
  Canvas canvas,
  Offset at,
  double width,
  double height,
  LightRig light, {
  double strength = 0.5,
}) {
  final dir = light.shadowDir;
  final c = at + Offset(dir.dx * width * 0.35, 0);
  final rect = Rect.fromCenter(center: c, width: width, height: height);
  canvas.drawOval(
    rect,
    Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF000000).withValues(alpha: strength),
          const Color(0xFF000000).withValues(alpha: strength * 0.35),
          const Color(0x00000000),
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(rect)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, height * 0.35)
      ..blendMode = BlendMode.multiply,
  );
}

/// 금속 트림/테두리 장식. 갑옷 가장자리, 무기 날의 페룰 등에 쓴다.
void paintTrim(
  Canvas canvas,
  Path path,
  Color color,
  LightRig light, {
  double width = 2.0,
  double alpha = 0.9,
}) {
  final b = path.getBounds();
  final ka = light.keyAlign;
  canvas.drawPath(
    path,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..shader = LinearGradient(
        begin: ka,
        end: -ka,
        colors: [
          mix(color, light.keyColor, 0.6).withValues(alpha: alpha),
          color.withValues(alpha: alpha),
          shiftColor(color, dl: -0.28).withValues(alpha: alpha),
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(b),
  );
}

/// 발광 궤적/오라. 마법 이펙트와 몬스터의 코어에 쓴다.
void paintGlow(Canvas canvas, Path path, Color color, double radius, double strength) {
  canvas.drawPath(
    path,
    Paint()
      ..color = color.withValues(alpha: strength.clamp(0, 1))
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius)
      ..blendMode = BlendMode.plus,
  );
}
