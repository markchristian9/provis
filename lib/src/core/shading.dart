import 'dart:math' as math;

import 'package:flutter/painting.dart';

import 'noise.dart';
import 'palette.dart';
import 'spline.dart';

/// 조명 리그와 재질 셰이딩.
///
/// 이 파일이 프로젝트에서 "그럴듯함"을 담당하는 유일한 지점이다. 캐릭터
/// 파일들은 오직 실루엣(Path)과 재질(Surface)만 만들고, 그것을 픽셀로 바꾸는
/// 일은 전부 여기로 위임한다. 덕분에 조명 방향 한 줄을 바꾸면 8종 캐릭터가
/// 동시에 같은 방식으로 반응한다.

/// 3점 조명 + 환경광.
class LightRig {
  const LightRig({
    this.dir = const Offset(-0.58, -0.81),
    this.rimDir = const Offset(0.80, -0.60),
    this.key = const Color(0xFFFFF0D4),
    this.fill = const Color(0xFF5A7FBF),
    this.rim = const Color(0xFFAFE4FF),
    this.bounce = const Color(0xFF8A6A4E),
    this.ambient = const Color(0xFF243050),
    this.intensity = 1.0,
  });

  /// 피사체에서 키라이트를 바라보는 단위벡터. 화면 좌표계이므로 y 음수가 위쪽.
  final Offset dir;

  /// 림라이트(백라이트)가 있는 방향.
  final Offset rimDir;

  final Color key;
  final Color fill;
  final Color rim;

  /// 지면에서 되튀어 아랫면을 데우는 반사광.
  final Color bounce;
  final Color ambient;
  final double intensity;

  /// 그라디언트 중심으로 쓸 정렬값. 광원 쪽으로 치우친 지점을 가리킨다.
  Alignment get keyAlign => Alignment(dir.dx * 0.78, dir.dy * 0.78);
  Alignment get rimAlign => Alignment(rimDir.dx, rimDir.dy);

  LightRig copyWith({Offset? dir, Color? rim, Color? key, double? intensity}) =>
      LightRig(
        dir: dir ?? this.dir,
        rimDir: rimDir,
        key: key ?? this.key,
        fill: fill,
        rim: rim ?? this.rim,
        bounce: bounce,
        ambient: ambient,
        intensity: intensity ?? this.intensity,
      );

  /// 영웅 프리셋: 좌상단에서 떨어지는 따뜻한 키라이트, 우측 상단의 차가운 림.
  static const heroic = LightRig();

  /// 지옥/화염 프리셋: 아래쪽 용암에서 올라오는 강한 바운스.
  static const infernal = LightRig(
    dir: Offset(-0.45, -0.89),
    rimDir: Offset(0.72, 0.69),
    key: Color(0xFFFFD9A8),
    fill: Color(0xFF7A3320),
    rim: Color(0xFFFF9040),
    bounce: Color(0xFFFF5A18),
    ambient: Color(0xFF2C1216),
  );

  /// 심령 프리셋: 피사체 자신이 광원이므로 키라이트가 약하고 림이 지배적이다.
  static const spectral = LightRig(
    dir: Offset(-0.5, -0.86),
    rimDir: Offset(0.55, -0.83),
    key: Color(0xFFD3E9FF),
    fill: Color(0xFF2E4A7A),
    rim: Color(0xFFBFF3FF),
    bounce: Color(0xFF39627F),
    ambient: Color(0xFF141E33),
  );
}

/// 재질의 종류. 빛에 반응하는 방식이 근본적으로 다른 것들만 나눈다.
enum Finish {
  skin,
  metal,
  gold,
  cloth,
  leather,
  scale,
  chitin,
  fur,
  hair,
  bone,
  wood,
  gem,
  energy,
  slime,
  stone,
  membrane,
}

/// 하나의 파츠가 무엇으로 만들어졌는지.
class Surface {
  const Surface(
    this.base,
    this.finish, {
    this.contrast = 1.0,
    this.sss,
    this.glow = 0.0,
    this.glowColor,
    this.alpha = 1.0,
  });

  final Color base;
  final Finish finish;
  final double contrast;

  /// 표면 아래 산란색. 피부·막·슬라임처럼 빛이 통과하는 재질에서 명암 경계에
  /// 배어 나온다.
  final Color? sss;

  final double glow;
  final Color? glowColor;
  final double alpha;

  Ramp get ramp => Ramp.of(base, contrast: contrast);

  Surface tinted(Color c, double t) => Surface(
        base.mix(c, t),
        finish,
        contrast: contrast,
        sss: sss,
        glow: glow,
        glowColor: glowColor,
        alpha: alpha,
      );

  Surface withAlpha(double a) => Surface(
        base,
        finish,
        contrast: contrast,
        sss: sss,
        glow: glow,
        glowColor: glowColor,
        alpha: a,
      );
}

Paint _p() => Paint()..isAntiAlias = true;

Shader _radial(Rect b, Alignment c, List<Color> colors, List<double> stops,
        {double radius = 1.15}) =>
    RadialGradient(center: c, radius: radius, colors: colors, stops: stops)
        .createShader(b);

Shader _linear(Rect b, Alignment from, Alignment to, List<Color> colors,
        List<double> stops) =>
    LinearGradient(begin: from, end: to, colors: colors, stops: stops)
        .createShader(b);

/// 형상 하나를 재질에 맞게 칠한다. 프로젝트에서 가장 많이 호출되는 함수.
///
/// [path] 로 클립한 뒤 그 안에 확산광 → 재질 고유 레이어 → 접촉 그림자 →
/// 림라이트 순으로 쌓는다. 순서 자체가 결과를 좌우하므로 바꾸지 않는다.
void paintSurface(
  Canvas c,
  Path path,
  Surface s,
  LightRig l, {
  double detail = 1.0,
  int seed = 7,
  bool rim = true,
  bool ao = true,
}) {
  final b = path.getBounds();
  if (b.width < 0.5 || b.height < 0.5) return;
  final r = s.alpha < 1 ? s.ramp.withAlpha(s.alpha) : s.ramp;

  c.save();
  c.clipPath(path);

  switch (s.finish) {
    case Finish.metal:
      _metal(c, b, r, l, s, detail, seed);
    case Finish.gold:
      _metal(c, b, r, l, s, detail, seed, warm: true);
    case Finish.skin:
      _skin(c, b, r, l, s);
    case Finish.cloth:
      _cloth(c, b, r, l, s, detail, seed);
    case Finish.leather:
      _leather(c, b, r, l, s, detail, seed);
    case Finish.scale:
      _diffuse(c, b, r, l, softness: 0.45);
      _sheen(c, b, r, l, 0.22, 0.30);
    case Finish.chitin:
      _chitin(c, b, r, l, s);
    case Finish.fur:
      _diffuse(c, b, r, l, softness: 0.7);
      _sheen(c, b, r, l, 0.16, 0.5);
    case Finish.hair:
      _hair(c, b, r, l);
    case Finish.bone:
      _bone(c, b, r, l, detail, seed);
    case Finish.wood:
      _wood(c, b, r, l, detail, seed);
    case Finish.gem:
      _gem(c, b, r, l, s);
    case Finish.energy:
      _energy(c, b, r, s);
    case Finish.slime:
      _slime(c, b, r, l, s);
    case Finish.stone:
      _stone(c, b, r, l, detail, seed);
    case Finish.membrane:
      _membrane(c, b, r, l, s);
  }

  if (ao) _ambientOcclusion(c, b, l, s);
  if (rim && s.finish != Finish.energy) _rimInside(c, b, l, s);

  c.restore();

  if (s.glow > 0) {
    glowPath(c, path, s.glowColor ?? s.base, 18 * s.glow, alpha: 0.5 * s.glow);
  }
}

// ---------------------------------------------------------------------------
// 재질별 레이어
// ---------------------------------------------------------------------------

void _diffuse(Canvas c, Rect b, Ramp r, LightRig l, {double softness = 0.4}) {
  // 램버트 확산의 회화적 근사. softness 가 클수록 명암 경계가 넓게 퍼진다.
  final mid = 0.30 + softness * 0.28;
  c.drawRect(
    b,
    _p()
      ..shader = _radial(
        b,
        l.keyAlign,
        [r.light, r.mid, r.shadow, r.deep],
        [0.0, mid, 0.80, 1.0],
        radius: 1.05 + softness * 0.5,
      ),
  );
}

void _metal(Canvas c, Rect b, Ramp r, LightRig l, Surface s, double detail,
    int seed,
    {bool warm = false}) {
  // 금속은 확산이 거의 없고 환경을 반사한다. 위쪽에는 차가운 하늘, 중간에는
  // 어두운 지평선, 아래쪽에는 따뜻한 지면이 비친 3단 띠가 생기고 그 사이에
  // 좁고 강한 하이라이트가 끼어든다. 이 밴딩이 금속을 금속으로 읽히게 한다.
  final sky = warm ? const Color(0xFFFFF0C4) : const Color(0xFFBCD8FF);
  final ground = warm ? const Color(0xFFB0620F) : const Color(0xFF6B5236);
  final a = l.dir;
  c.drawRect(
    b,
    _p()
      ..shader = _linear(
        b,
        Alignment(a.dx, a.dy),
        Alignment(-a.dx, -a.dy),
        [
          r.spec.mix(sky, 0.35),
          r.light,
          r.mid,
          r.deep,
          r.shadow,
          r.mid.mix(ground, 0.30),
          r.shadow.mix(ground, 0.45),
          r.deep,
        ],
        const [0.0, 0.10, 0.24, 0.40, 0.55, 0.74, 0.90, 1.0],
      ),
  );

  // 좁은 스펙큘러 스트라이프. 광원과 정확히 정렬된 지점에서만 터진다.
  final n = a.perp;
  c.drawRect(
    b,
    _p()
      ..blendMode = BlendMode.plus
      ..shader = _linear(
        b,
        Alignment(a.dx + n.dx * 0.3, a.dy + n.dy * 0.3),
        Alignment(-a.dx + n.dx * 0.3, -a.dy + n.dy * 0.3),
        [
          r.spec.fade(0.0),
          r.spec.fade(warm ? 0.55 : 0.42),
          r.spec.fade(0.0),
        ],
        const [0.02, 0.13, 0.30],
      ),
  );

  if (detail > 0.4) _scratches(c, b, r, seed, warm ? 0.10 : 0.16);
}

void _skin(Canvas c, Rect b, Ramp r, LightRig l, Surface s) {
  // 피부는 표면 아래로 들어간 빛이 되돌아 나오면서 명암 경계에 붉은 띠를
  // 남긴다. 이 띠가 없으면 아무리 형태가 좋아도 밀랍 인형처럼 보인다.
  final sss = s.sss ?? r.mid.mix(const Color(0xFFC24A38), 0.5).darken(0.06);
  c.drawRect(
    b,
    _p()
      ..shader = _radial(
        b,
        l.keyAlign,
        [r.light, r.mid, sss, r.shadow, r.deep],
        const [0.0, 0.34, 0.60, 0.83, 1.0],
        radius: 1.25,
      ),
  );
  // 피지막이 만드는 넓고 흐릿한 스펙큘러.
  c.drawRect(
    b,
    _p()
      ..blendMode = BlendMode.plus
      ..shader = _radial(
        b,
        Alignment(l.dir.dx * 0.55, l.dir.dy * 0.62),
        [r.spec.fade(0.20), r.spec.fade(0.0)],
        const [0.0, 0.55],
        radius: 0.9,
      ),
  );
}

void _cloth(
    Canvas c, Rect b, Ramp r, LightRig l, Surface s, double detail, int seed) {
  _diffuse(c, b, r, l, softness: 0.75);
  // 천은 실 끝에서 빛이 산란해 형상의 가장자리가 안쪽보다 밝아진다(shear).
  c.drawRect(
    b,
    _p()
      ..blendMode = BlendMode.plus
      ..shader = _radial(
        b,
        Alignment.center,
        [r.mid.fade(0.0), r.light.fade(0.16)],
        const [0.55, 1.0],
        radius: 1.0,
      ),
  );
  if (detail > 0.5) _fiber(c, b, r, seed);
}

void _leather(
    Canvas c, Rect b, Ramp r, LightRig l, Surface s, double detail, int seed) {
  _diffuse(c, b, r, l, softness: 0.35);
  _sheen(c, b, r, l, 0.24, 0.38);
  if (detail > 0.5) _grain(c, b, r, seed, 0.10);
}

void _chitin(Canvas c, Rect b, Ramp r, LightRig l, Surface s) {
  // 키틴은 매끄러운 다층 구조라 좁고 날카로운 하이라이트가 두 줄 생기고,
  // 층 사이 간섭으로 각도에 따라 색이 도는 이리데센스가 나타난다.
  c.drawRect(
    b,
    _p()
      ..shader = _radial(
        b,
        l.keyAlign,
        [r.mid, r.shadow, r.deep, r.deep.darken(0.35)],
        const [0.0, 0.42, 0.78, 1.0],
        radius: 1.2,
      ),
  );
  c.drawRect(
    b,
    _p()
      ..blendMode = BlendMode.plus
      ..shader = _linear(
        b,
        Alignment(l.dir.dx, l.dir.dy),
        Alignment(-l.dir.dx, -l.dir.dy),
        [
          const Color(0xFF7C4BFF).fade(0.30),
          const Color(0xFF2BE0C8).fade(0.18),
          const Color(0xFF1B2A6B).fade(0.0),
        ],
        const [0.0, 0.34, 0.78],
      ),
  );
  c.drawRect(
    b,
    _p()
      ..blendMode = BlendMode.plus
      ..shader = _radial(
        b,
        Alignment(l.dir.dx * 0.72, l.dir.dy * 0.78),
        [r.spec.fade(0.85), r.spec.fade(0.15), r.spec.fade(0.0)],
        const [0.0, 0.14, 0.34],
        radius: 0.7,
      ),
  );
}

void _hair(Canvas c, Rect b, Ramp r, LightRig l) {
  // 모발의 광택은 원통 다발에 생기는 띠 모양(앤이소트로픽)이다. 점이 아니라
  // 결을 가로지르는 링으로 나타나야 머리카락으로 읽힌다.
  _diffuse(c, b, r, l, softness: 0.3);
  final a = l.dir;
  c.drawRect(
    b,
    _p()
      ..blendMode = BlendMode.plus
      ..shader = _linear(
        b,
        Alignment(a.dx, a.dy),
        Alignment(-a.dx, -a.dy),
        [
          r.spec.fade(0.0),
          r.spec.fade(0.45),
          r.light.fade(0.10),
          r.spec.fade(0.18),
          r.spec.fade(0.0),
        ],
        const [0.10, 0.24, 0.40, 0.58, 0.80],
      ),
  );
}

void _bone(Canvas c, Rect b, Ramp r, LightRig l, double detail, int seed) {
  c.drawRect(
    b,
    _p()
      ..shader = _radial(
        b,
        l.keyAlign,
        [
          r.spec,
          r.light,
          r.mid,
          r.shadow.mix(const Color(0xFF6B5A34), 0.35),
          r.deep,
        ],
        const [0.0, 0.22, 0.52, 0.82, 1.0],
        radius: 1.2,
      ),
  );
  if (detail > 0.5) _grain(c, b, r, seed, 0.08);
}

void _wood(Canvas c, Rect b, Ramp r, LightRig l, double detail, int seed) {
  _diffuse(c, b, r, l, softness: 0.4);
  if (detail <= 0.4) return;
  final n = Noise(seed * 31 + 5);
  final long = b.height >= b.width;
  final count = 9;
  final paint = _p()
    ..style = PaintingStyle.stroke
    ..strokeWidth = math.max(0.7, (long ? b.width : b.height) * 0.035);
  for (var i = 0; i < count; i++) {
    final t = (i + 0.5) / count;
    final pts = <Offset>[];
    for (var j = 0; j <= 8; j++) {
      final u = j / 8;
      final w = n.signed1(i * 4.3 + u * 3.1) * 0.06;
      pts.add(long
          ? Offset(b.left + b.width * (t + w), b.top + b.height * u)
          : Offset(b.left + b.width * u, b.top + b.height * (t + w)));
    }
    paint.color = (i.isEven ? r.deep : r.shadow).fade(0.28);
    c.drawPath(smoothOpenPath(pts), paint);
  }
}

void _gem(Canvas c, Rect b, Ramp r, LightRig l, Surface s) {
  // 보석은 내부 전반사 때문에 중심이 어둡고 가장자리와 반대쪽 면이 밝다.
  c.drawRect(
    b,
    _p()
      ..shader = _radial(
        b,
        Alignment(-l.dir.dx * 0.4, -l.dir.dy * 0.4),
        [r.spec, r.mid, r.deep, r.mid.mix(r.spec, 0.4)],
        const [0.0, 0.32, 0.72, 1.0],
        radius: 1.0,
      ),
  );
  c.drawRect(
    b,
    _p()
      ..blendMode = BlendMode.plus
      ..shader = _radial(
        b,
        l.keyAlign,
        [white.fade(0.9), r.spec.fade(0.2), r.spec.fade(0.0)],
        const [0.0, 0.16, 0.42],
        radius: 0.55,
      ),
  );
}

void _energy(Canvas c, Rect b, Ramp r, Surface s) {
  // 발광체는 중심이 센서를 포화시켜 흰색으로 날아가고, 바깥으로 갈수록
  // 고유색이 드러난다. 가산 합성이 필수다.
  final core = s.glowColor ?? s.base;
  c.drawRect(
    b,
    _p()
      ..blendMode = BlendMode.plus
      ..shader = _radial(
        b,
        Alignment.center,
        [
          white.fade(0.95 * s.alpha),
          core.lighten(0.35).fade(0.85 * s.alpha),
          core.fade(0.55 * s.alpha),
          core.darken(0.4).fade(0.0),
        ],
        const [0.0, 0.22, 0.58, 1.0],
        radius: 0.85,
      ),
  );
}

void _slime(Canvas c, Rect b, Ramp r, LightRig l, Surface s) {
  // 점액은 반투명하다. 가장자리가 두꺼워 진해지고 중심이 비쳐 밝다.
  c.drawRect(
    b,
    _p()
      ..shader = _radial(
        b,
        Alignment.center,
        [
          r.mid.fade(0.45 * s.alpha),
          r.mid.fade(0.72 * s.alpha),
          r.deep.fade(0.95 * s.alpha),
        ],
        const [0.0, 0.6, 1.0],
        radius: 1.0,
      ),
  );
  c.drawRect(
    b,
    _p()
      ..blendMode = BlendMode.plus
      ..shader = _radial(
        b,
        Alignment(l.dir.dx * 0.6, l.dir.dy * 0.7),
        [white.fade(0.65), r.spec.fade(0.1), r.spec.fade(0.0)],
        const [0.0, 0.12, 0.30],
        radius: 0.6,
      ),
  );
}

void _stone(Canvas c, Rect b, Ramp r, LightRig l, double detail, int seed) {
  _diffuse(c, b, r, l, softness: 0.5);
  if (detail > 0.4) _grain(c, b, r, seed, 0.16);
}

void _membrane(Canvas c, Rect b, Ramp r, LightRig l, Surface s) {
  // 얇은 막은 빛을 투과시킨다. 뒤에서 빛이 들어오므로 조명 방향과 무관하게
  // 막 전체가 은은히 빛나고, 두꺼운 뼈대 근처만 어둡다.
  final glow = s.sss ?? r.mid.mix(const Color(0xFFFF8A4C), 0.55);
  c.drawRect(
    b,
    _p()
      ..shader = _radial(
        b,
        Alignment.center,
        [
          glow.fade(0.85 * s.alpha),
          r.mid.fade(0.88 * s.alpha),
          r.shadow.fade(0.95 * s.alpha),
          r.deep.fade(s.alpha),
        ],
        const [0.0, 0.42, 0.78, 1.0],
        radius: 1.1,
      ),
  );
}

// ---------------------------------------------------------------------------
// 공통 레이어
// ---------------------------------------------------------------------------

void _ambientOcclusion(Canvas c, Rect b, LightRig l, Surface s) {
  // 형상의 아랫면은 하늘이 가려져 어두워지고, 대신 지면 반사광이 살짝 낀다.
  if (s.finish == Finish.energy || s.finish == Finish.gem) return;
  c.drawRect(
    b,
    _p()
      ..blendMode = BlendMode.multiply
      ..shader = _linear(
        b,
        Alignment.topCenter,
        Alignment.bottomCenter,
        [
          const Color(0xFFFFFFFF),
          const Color(0xFFFFFFFF),
          const Color(0xFF8E96B4),
        ],
        const [0.0, 0.62, 1.0],
      ),
  );
  c.drawRect(
    b,
    _p()
      ..blendMode = BlendMode.plus
      ..shader = _linear(
        b,
        Alignment.bottomCenter,
        Alignment.center,
        [l.bounce.fade(0.16 * s.alpha), l.bounce.fade(0.0)],
        const [0.0, 1.0],
      ),
  );
}

void _rimInside(Canvas c, Rect b, LightRig l, Surface s) {
  // 클립 내부에서 림 방향 끝만 밝히는 값싼 백라이트. 실루엣을 배경에서
  // 떼어 놓는 역할을 하며, 정확한 윤곽이 필요한 파츠는 rimBand() 를 쓴다.
  c.drawRect(
    b,
    _p()
      ..blendMode = BlendMode.plus
      ..shader = _linear(
        b,
        Alignment(-l.rimDir.dx, -l.rimDir.dy),
        Alignment(l.rimDir.dx, l.rimDir.dy),
        [
          l.rim.fade(0.0),
          l.rim.fade(0.0),
          l.rim.fade(0.30 * s.alpha * l.intensity),
        ],
        const [0.0, 0.68, 1.0],
      ),
  );
}

void _sheen(Canvas c, Rect b, Ramp r, LightRig l, double alpha, double width) {
  c.drawRect(
    b,
    _p()
      ..blendMode = BlendMode.plus
      ..shader = _radial(
        b,
        Alignment(l.dir.dx * 0.7, l.dir.dy * 0.75),
        [r.spec.fade(alpha), r.spec.fade(alpha * 0.3), r.spec.fade(0.0)],
        [0.0, width * 0.5, width],
        radius: 0.8,
      ),
  );
}

void _scratches(Canvas c, Rect b, Ramp r, int seed, double alpha) {
  final n = Noise(seed * 977 + 13);
  final paint = _p()
    ..style = PaintingStyle.stroke
    ..strokeWidth = math.max(0.6, b.shortestSide * 0.012)
    ..blendMode = BlendMode.plus;
  final count = 7;
  for (var i = 0; i < count; i++) {
    final y = b.top + b.height * ((i + n.at1(i * 3.7)) / count);
    final x0 = b.left + b.width * n.at1(i * 7.1 + 0.5) * 0.5;
    final x1 = x0 + b.width * (0.18 + n.at1(i * 2.3) * 0.5);
    paint.color = r.spec.fade(alpha * (0.4 + n.at1(i * 5.9) * 0.6));
    c.drawLine(
      Offset(x0, y),
      Offset(x1, y + b.height * n.signed1(i * 1.7) * 0.02),
      paint,
    );
  }
}

void _grain(Canvas c, Rect b, Ramp r, int seed, double alpha) {
  // 미세 요철. 점을 무수히 찍으면 느리므로 성긴 사각 격자에 값을 흩뿌린다.
  final n = Noise(seed * 131 + 71);
  final step = math.max(3.0, b.shortestSide / 14);
  final paint = _p();
  for (var y = b.top; y < b.bottom; y += step) {
    for (var x = b.left; x < b.right; x += step) {
      final v = n.at2(x / step, y / step);
      if (v < 0.55) continue;
      paint.color = (v > 0.78 ? r.light : r.deep).fade(alpha * (v - 0.5));
      c.drawCircle(Offset(x, y), step * 0.42, paint);
    }
  }
}

void _fiber(Canvas c, Rect b, Ramp r, int seed) {
  final n = Noise(seed * 17 + 3);
  final paint = _p()
    ..style = PaintingStyle.stroke
    ..strokeWidth = math.max(0.6, b.shortestSide * 0.014);
  for (var i = 0; i < 5; i++) {
    final t = (i + 0.5) / 5;
    final pts = <Offset>[];
    for (var j = 0; j <= 6; j++) {
      final u = j / 6;
      pts.add(Offset(
        b.left + b.width * (t + n.signed1(i * 5.1 + u * 2.4) * 0.10),
        b.top + b.height * u,
      ));
    }
    paint.color = r.deep.fade(0.14);
    c.drawPath(smoothOpenPath(pts), paint);
  }
}

// ---------------------------------------------------------------------------
// 독립 효과
// ---------------------------------------------------------------------------

const Color white = Color(0xFFFFFFFF);

/// 형상의 윤곽을 정확히 따라가는 림라이트 밴드.
///
/// 클립 그라디언트로 만드는 값싼 림과 달리 실루엣을 그대로 훑으므로,
/// 얼굴·어깨·무기날처럼 시선이 머무는 곳에만 선택적으로 쓴다.
void rimBand(
  Canvas c,
  Path p,
  LightRig l, {
  double width = 5,
  Color? color,
  double alpha = 0.85,
  double blur = 2.5,
}) {
  final inner = p.shift(-l.rimDir * width);
  final band = Path.combine(PathOperation.difference, p, inner);
  c.drawPath(
    band,
    _p()
      ..color = (color ?? l.rim).fade(alpha)
      ..blendMode = BlendMode.plus
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur),
  );
}

/// 형상 바깥으로 번지는 발광.
void glowPath(Canvas c, Path p, Color color, double blur,
    {double alpha = 0.6, BlendMode mode = BlendMode.plus}) {
  c.drawPath(
    p,
    _p()
      ..color = color.fade(alpha)
      ..blendMode = mode
      ..maskFilter = MaskFilter.blur(BlurStyle.outer, blur),
  );
}

/// 점광원. 코어 → 헤일로 → 스타버스트 3단으로 그린다.
void glowAt(
  Canvas c,
  Offset at,
  double radius,
  Color color, {
  double intensity = 1.0,
  bool star = false,
}) {
  final b = Rect.fromCircle(center: at, radius: radius);
  c.drawCircle(
    at,
    radius,
    _p()
      ..blendMode = BlendMode.plus
      ..shader = _radial(
        b,
        Alignment.center,
        [
          white.fade(0.95 * intensity),
          color.fade(0.75 * intensity),
          color.fade(0.22 * intensity),
          color.fade(0.0),
        ],
        const [0.0, 0.16, 0.45, 1.0],
      ),
  );
  if (!star) return;
  final paint = _p()
    ..blendMode = BlendMode.plus
    ..color = color.fade(0.5 * intensity)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
  final r2 = radius * 2.4;
  c.drawPath(
    Path()
      ..moveTo(at.dx - r2, at.dy)
      ..lineTo(at.dx, at.dy - radius * 0.16)
      ..lineTo(at.dx + r2, at.dy)
      ..lineTo(at.dx, at.dy + radius * 0.16)
      ..close(),
    paint,
  );
  c.drawPath(
    Path()
      ..moveTo(at.dx, at.dy - r2)
      ..lineTo(at.dx + radius * 0.16, at.dy)
      ..lineTo(at.dx, at.dy + r2)
      ..lineTo(at.dx - radius * 0.16, at.dy)
      ..close(),
    paint,
  );
}

/// 파츠 아래로 떨어지는 그림자. 겹친 파츠를 분리해 깊이를 만든다.
void castShadow(
  Canvas c,
  Path p, {
  Offset offset = const Offset(6, 10),
  double blur = 10,
  double alpha = 0.45,
}) {
  c.drawPath(
    p.shift(offset),
    _p()
      ..color = const Color(0xFF060810).fade(alpha)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur),
  );
}

/// 형상 안쪽 가장자리를 어둡게 하는 접촉 그림자.
///
/// [from] 방향에서 다른 파츠가 덮고 있다고 가정한다. 팔이 몸통 위에 얹힐 때
/// 이 한 겹이 없으면 파츠가 종이처럼 겹쳐 보인다.
void occlude(Canvas c, Path p, Offset from,
    {double depth = 0.35, double alpha = 0.55}) {
  final b = p.getBounds();
  if (b.isEmpty) return;
  c.save();
  c.clipPath(p);
  c.drawRect(
    b,
    _p()
      ..blendMode = BlendMode.multiply
      ..shader = _linear(
        b,
        Alignment(from.dx, from.dy),
        Alignment(-from.dx, -from.dy),
        [
          Color.lerp(const Color(0xFF3A3F55), white, 1 - alpha)!,
          white,
        ],
        [0.0, depth],
      ),
  );
  c.restore();
}

/// 두께를 가진 윤곽선. 실루엣을 다지는 마무리용.
void inkOutline(Canvas c, Path p, Color color, double width,
    {double alpha = 0.5}) {
  c.drawPath(
    p,
    _p()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeJoin = StrokeJoin.round
      ..color = color.fade(alpha),
  );
}

/// 갑옷 패널의 경계선. 홈은 어둡고 그 위 모서리는 밝다.
void panelLine(Canvas c, Path line, Ramp r, LightRig l,
    {double width = 3, double alpha = 1.0}) {
  c.drawPath(
    line,
    _p()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..color = r.deep.fade(0.75 * alpha),
  );
  c.drawPath(
    line.shift(-l.dir * width * 0.75),
    _p()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width * 0.55
      ..strokeCap = StrokeCap.round
      ..color = r.light.fade(0.55 * alpha),
  );
}

/// 지면 접촉 그림자. 캐릭터를 바닥에 붙여 놓는다.
void groundShadow(Canvas c, Offset at, double rx, double ry,
    {double alpha = 0.55, Color color = const Color(0xFF05070E)}) {
  final b = Rect.fromCenter(center: at, width: rx * 2, height: ry * 2);
  c.drawOval(
    b,
    _p()
      ..shader = _radial(
        b,
        Alignment.center,
        [color.fade(alpha), color.fade(alpha * 0.45), color.fade(0.0)],
        const [0.0, 0.5, 1.0],
      ),
  );
}
