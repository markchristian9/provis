import 'package:flutter/painting.dart';

/// 색 조작과 톤 램프.
///
/// 절차적 캐릭터에서 색은 손으로 고른 팔레트가 아니라 "베이스 컬러가 조명에
/// 반응한 결과"로 만들어진다. 그림자를 단순히 검정 쪽으로 어둡게만 하면
/// 진흙처럼 탁해지므로, 여기서는 회화의 관습을 따라 그림자는 차갑게(하늘의
/// 산란광), 하이라이트는 따뜻하게(키라이트의 색온도) 밀어 준다. 이 한 가지
/// 규칙만으로도 같은 형상이 플라스틱과 실물의 차이만큼 달라진다.
extension ColorTune on Color {
  HSLColor get _hsl => HSLColor.fromColor(this);

  /// 명도를 [t] 비율만큼 0 쪽으로 끌어내린다.
  Color darken(double t) {
    final h = _hsl;
    return h.withLightness((h.lightness * (1 - t)).clamp(0.0, 1.0)).toColor();
  }

  /// 명도를 [t] 비율만큼 1 쪽으로 끌어올린다. 어두운 색도 확실히 밝아진다.
  Color lighten(double t) {
    final h = _hsl;
    return h
        .withLightness((h.lightness + (1 - h.lightness) * t).clamp(0.0, 1.0))
        .toColor();
  }

  Color saturate(double t) {
    final h = _hsl;
    return h
        .withSaturation((h.saturation + (1 - h.saturation) * t).clamp(0.0, 1.0))
        .toColor();
  }

  Color desaturate(double t) {
    final h = _hsl;
    return h.withSaturation((h.saturation * (1 - t)).clamp(0.0, 1.0)).toColor();
  }

  Color shiftHue(double deg) {
    final h = _hsl;
    return h.withHue((h.hue + deg) % 360).toColor();
  }

  Color fade(double a) => withValues(alpha: a.clamp(0.0, 1.0));

  Color mix(Color other, double t) => Color.lerp(this, other, t)!;
}

/// 한 재질이 특정 조명 아래에서 갖는 5단계 톤.
///
/// 셰이딩 코드는 언제나 이 램프를 통해 색을 얻는다. 캐릭터마다 베이스 컬러만
/// 지정하면 그림자·하이라이트가 일관된 조명 논리로 따라오므로, 8종의 캐릭터가
/// 서로 다른 색을 쓰면서도 "같은 세계에 서 있는" 것처럼 보인다.
class Ramp {
  const Ramp(this.deep, this.shadow, this.mid, this.light, this.spec);

  /// 베이스 컬러에서 램프를 유도한다.
  ///
  /// [cool] 은 그림자에 섞이는 환경광(하늘빛), [warm] 은 하이라이트에 섞이는
  /// 키라이트 색이다. [contrast] 는 명암 폭 — 금속은 크게, 천은 작게 준다.
  factory Ramp.of(
    Color base, {
    double contrast = 1.0,
    Color cool = const Color(0xFF2B3A63),
    Color warm = const Color(0xFFFFE7BE),
  }) {
    return Ramp(
      base.darken((0.72 * contrast).clamp(0.0, 0.95)).mix(cool, 0.34),
      base.darken((0.42 * contrast).clamp(0.0, 0.9)).mix(cool, 0.17),
      base,
      base.lighten((0.28 * contrast).clamp(0.0, 0.95)).mix(warm, 0.20),
      base.lighten((0.62 * contrast).clamp(0.0, 0.98)).mix(warm, 0.44),
    );
  }

  final Color deep;
  final Color shadow;
  final Color mid;
  final Color light;
  final Color spec;

  /// 밝은 쪽 → 어두운 쪽 순서. 그라디언트에 그대로 넣는다.
  List<Color> get descending => [spec, light, mid, shadow, deep];

  Ramp withAlpha(double a) => Ramp(
        deep.fade(a),
        shadow.fade(a),
        mid.fade(a),
        light.fade(a),
        spec.fade(a),
      );
}

/// 프로젝트 전역에서 재사용하는 색.
///
/// 개별 캐릭터의 고유색은 각 파일에서 정의하고, 여기에는 세계관의 공기색
/// (배경·안개·지면 반사광)만 둔다.
abstract final class Pal {
  static const Color voidDeep = Color(0xFF080A12);
  static const Color voidBlue = Color(0xFF121A2E);
  static const Color fogBlue = Color(0xFF2A3F63);
  static const Color skyCool = Color(0xFF4E76B8);
  static const Color sunWarm = Color(0xFFFFE3B0);
  static const Color emberOrange = Color(0xFFFF7A2E);
  static const Color arcaneCyan = Color(0xFF57E8FF);
  static const Color arcaneViolet = Color(0xFF9A6BFF);
  static const Color soulPale = Color(0xFFBFF3FF);
  static const Color venomGreen = Color(0xFF8DFF4E);
  static const Color bloodRed = Color(0xFFB4212A);
  static const Color goldLeaf = Color(0xFFF3C463);
  static const Color parchment = Color(0xFFE8DCC0);
}
