import 'dart:ui';

import 'package:flutter/painting.dart' show HSLColor;

import '../core/rng.dart';

/// 색 조작 헬퍼. 절차적 색상은 RGB 로 다루면 금방 탁해지므로 전부 HSL 에서
/// 조작한 뒤 되돌린다.
Color hsl(double h, double s, double l, [double a = 1]) =>
    HSLColor.fromAHSL(a, h % 360, s.clamp(0, 1), l.clamp(0, 1)).toColor();

Color shiftColor(
  Color c, {
  double dh = 0,
  double ds = 0,
  double dl = 0,
  double? alpha,
}) {
  final x = HSLColor.fromColor(c);
  return HSLColor.fromAHSL(
    alpha ?? x.alpha,
    (x.hue + dh) % 360,
    (x.saturation + ds).clamp(0, 1),
    (x.lightness + dl).clamp(0, 1),
  ).toColor();
}

Color mix(Color a, Color b, double t) => Color.lerp(a, b, t.clamp(0, 1))!;

double luminance(Color c) => 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b;

/// 캐릭터 한 명분의 색 조합.
///
/// 개별 색을 독립적으로 뽑으면 조화가 깨지므로, 하나의 기준 색상환 각도에서
/// 유사색/보색 관계로 파생시킨다. 이것이 절차적 생성물이 "디자이너가 고른 색"
/// 처럼 보이는지 아닌지를 가른다.
class Palette {
  const Palette({
    required this.skin,
    required this.skinDeep,
    required this.hair,
    required this.cloth,
    required this.clothShade,
    required this.accent,
    required this.leather,
    required this.metal,
    required this.metalWarm,
    required this.eye,
    required this.glow,
  });

  final Color skin;
  final Color skinDeep;
  final Color hair;
  final Color cloth;
  final Color clothShade;
  final Color accent;
  final Color leather;
  final Color metal;
  final Color metalWarm;
  final Color eye;
  final Color glow;

  /// 영웅 계열. 채도 높은 주조색 + 금속 + 자연스러운 피부.
  factory Palette.hero(Rng r) {
    // 주조색: 파랑~보라, 청록, 진홍 중 하나. 각 대역 안에서만 흔들어
    // "탁한 중간 색"이 나오지 않게 한다.
    final band = r.weighted([210.0, 265.0, 175.0, 350.0, 30.0], [3, 2, 2, 2, 1]);
    final baseHue = band + r.signed(14);
    final accentHue = baseHue + (r.chance(0.5) ? 150 : -150) + r.signed(18);

    final skinHue = r.range(20, 34);
    final skinLight = r.bell(0.42, 0.78);
    final skinSat = r.range(0.24, 0.46) * (1.25 - skinLight * 0.5);

    final metalHue = r.chance(0.35) ? r.range(38, 48) : r.range(200, 225);
    final metalSat = metalHue < 100 ? r.range(0.30, 0.5) : r.range(0.04, 0.13);

    return Palette(
      skin: hsl(skinHue, skinSat, skinLight),
      skinDeep: hsl(skinHue - 8, (skinSat + 0.22).clamp(0, 1), skinLight * 0.52),
      hair: r.chance(0.25)
          ? hsl(accentHue, r.range(0.45, 0.7), r.range(0.4, 0.6))
          : hsl(r.range(18, 40), r.range(0.12, 0.55), r.range(0.08, 0.34)),
      cloth: hsl(baseHue, r.range(0.42, 0.64), r.range(0.30, 0.44)),
      clothShade: hsl(baseHue - 12, r.range(0.5, 0.7), r.range(0.14, 0.22)),
      accent: hsl(accentHue, r.range(0.6, 0.85), r.range(0.46, 0.60)),
      leather: hsl(r.range(20, 34), r.range(0.28, 0.46), r.range(0.14, 0.26)),
      metal: hsl(metalHue, metalSat, r.range(0.52, 0.68)),
      metalWarm: hsl(metalHue - 10, (metalSat + 0.2).clamp(0, 1), r.range(0.30, 0.42)),
      eye: hsl(accentHue + r.signed(25), r.range(0.55, 0.9), r.range(0.55, 0.72)),
      glow: hsl(accentHue, r.range(0.7, 1.0), r.range(0.6, 0.72)),
    );
  }

  /// 몬스터 계열. 살/키틴/독기. 영웅과 색이 겹치지 않도록 대역을 분리한다.
  ///
  /// ## 왜 몸 색이 이만큼 밝은가
  ///
  /// 예전 대역은 명도 0.13~0.28 이었다. 위협적으로 들리지만 그레이스케일
  /// 감사에서 몬스터가 전부 **구멍 난 검은 덩어리**로 나왔다 — 가죽 얼룩도,
  /// 등줄기 그늘도, 사지의 주름 띠도 그 아래에 그릴 자리가 없었기 때문이다.
  /// 셰이딩은 베이스에서 아래로 내려가며 명암을 만드는데(`Ramp.of` 의 deep 은
  /// 베이스의 28%), 베이스가 이미 바닥이면 내려갈 곳이 없다.
  ///
  /// 그래서 **명암이 들어설 자리**를 남기도록 바닥을 올렸다. 영웅의 피부
  /// 대역(0.42~0.78)과는 여전히 겹치지 않으므로 "사람이 아니다"는 그대로다.
  /// 몬스터의 어둠은 베이스 색이 아니라 조명(`ambient`)과 대비가 만든다.
  factory Palette.monster(Rng r) {
    final family = r.intRange(0, 4);
    late double bodyHue, bodySat, bodyLight;
    late double glowHue;
    switch (family) {
      case 0: // 부패한 살덩이
        bodyHue = r.range(300, 355);
        bodySat = r.range(0.18, 0.34);
        bodyLight = r.range(0.34, 0.46);
        glowHue = r.range(70, 100);
      case 1: // 갑각/키틴
        bodyHue = r.range(230, 275);
        bodySat = r.range(0.24, 0.44);
        bodyLight = r.range(0.26, 0.38);
        glowHue = r.range(150, 185);
      case 2: // 화산암/재
        bodyHue = r.range(10, 28);
        bodySat = r.range(0.10, 0.24);
        bodyLight = r.range(0.24, 0.34);
        glowHue = r.range(18, 40);
      default: // 심연/그림자
        bodyHue = r.range(190, 225);
        bodySat = r.range(0.22, 0.40);
        bodyLight = r.range(0.23, 0.34);
        glowHue = r.range(280, 320);
    }

    return Palette(
      skin: hsl(bodyHue, bodySat, bodyLight),
      skinDeep: hsl(bodyHue - 10, (bodySat + 0.18).clamp(0, 1), bodyLight * 0.45),
      hair: hsl(bodyHue + r.signed(20), bodySat * 0.7, bodyLight * 0.6),
      cloth: hsl(bodyHue + 15, bodySat * 0.8, bodyLight * 0.8),
      clothShade: hsl(bodyHue + 5, bodySat, bodyLight * 0.4),
      accent: hsl(glowHue, r.range(0.55, 0.85), r.range(0.40, 0.55)),
      leather: hsl(bodyHue - 20, bodySat * 0.6, bodyLight * 0.7),
      metal: hsl(bodyHue + 30, r.range(0.05, 0.18), r.range(0.38, 0.52)),
      metalWarm: hsl(bodyHue + 20, r.range(0.10, 0.25), r.range(0.20, 0.30)),
      eye: hsl(glowHue, r.range(0.85, 1.0), r.range(0.58, 0.72)),
      glow: hsl(glowHue, r.range(0.85, 1.0), r.range(0.52, 0.66)),
    );
  }
}
