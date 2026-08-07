import 'dart:ui';

import '../art/creature.dart';
import '../core/palette.dart';
import '../core/rng.dart';
import '../core/scheme.dart';
import '../rig/body.dart';
import 'spec.dart';

/// 캐릭터의 **정체성**을 선언한다.
///
/// ## 왜 필요한가
///
/// 손으로 그린 [Artist] 는 초상에서 가장 예쁘지만 걷지도 돌지도 않는다. 그래서
/// 게임 맵에서는 골격 액터로 바꿔 그리는데, 이때 **무엇을 근거로 같은 인물이라고
/// 할 것인가**가 문제가 된다.
///
/// 시드만 넘기면 완전히 다른 사람이 나온다 — 은발 마법사를 골랐는데 맵에서는
/// 금발 전사가 걸어 다니는 사고가 실제로 있었다. 색·직업·장비를 명시적으로
/// 넘겨야 초상과 게임 액터가 한 인물로 읽힌다.
///
/// ## 두 가지 용도
///
/// 1. **기존 [Artist] 가 오버라이드** — `Artist.build` 를 구현하면 그 캐릭터의
///    실제 색과 장비가 게임 액터로 전달된다.
/// 2. **선언만으로 새 캐릭터** — [BuiltArtist] 에 넘기면 초상과 게임 액터를
///    한꺼번에 얻는다. 40 줄이면 캐릭터 하나가 나오고, 둘이 **같은 렌더러를
///    쓰므로 어긋날 수가 없다.**
///
/// ```dart
/// const CharacterBuild(
///   archetype: Archetype.mage,
///   sex: Sex.female,
///   palette: Palette(hair: Color(0xFFE8F4FF), cloth: Color(0xFF2A3D7A), …),
///   weapon: WeaponKind.staff,
///   hasCape: true,
/// )
/// ```
class CharacterBuild {
  const CharacterBuild({
    required this.archetype,
    this.sex,
    this.palette,
    this.headGear,
    this.weapon,
    this.hasCape,
    this.hasPauldrons,
    this.hasShield,
    this.armorHeaviness,
    this.muscle,
    this.hairLength,
    this.glowRunes,
    this.heightScale = 1.0,
    this.beast = false,
    this.beastForm = BeastForm.brute,
    this.seed,
  });

  /// 직업 원형. 체형 대역과 기본 장비를 결정한다.
  final Archetype archetype;

  final Sex? sex;

  /// 캐릭터의 실제 색. `null` 이면 시드에서 생성한다.
  ///
  /// **이것이 정체성의 핵심이다.** 머리·옷·강조색이 초상과 같아야 같은 인물로
  /// 보인다.
  final Palette? palette;

  final HeadGear? headGear;
  final WeaponKind? weapon;
  final bool? hasCape;
  final bool? hasPauldrons;
  final bool? hasShield;

  /// 0 = 천 위주, 1 = 판금 위주.
  final double? armorHeaviness;

  /// 근육량 0..1.
  final double? muscle;

  /// 머리 길이 0..1.
  final double? hairLength;

  /// 발광 룬을 새긴다.
  final bool? glowRunes;

  /// 표준 키 대비 배율. 거인은 1.2, 소인은 0.8.
  final double heightScale;

  /// 짐승형 골격을 쓴다.
  final bool beast;

  /// 짐승형의 큰 실루엣. 세부 색보다 먼저 전투 역할을 읽히게 한다.
  final BeastForm beastForm;

  /// 명시하지 않으면 [Artist.id] 에서 뽑는다.
  final int? seed;

  /// 이 선언으로부터 렌더러가 쓸 명세를 만든다.
  ///
  /// 지정하지 않은 항목은 시드 생성기가 채우므로, **필요한 것만 선언하면**
  /// 나머지는 원형에 맞게 알아서 정해진다.
  HumanoidSpec toSpec(int fallbackSeed) {
    final s = seed ?? fallbackSeed;
    final base = HumanoidSpec.generate(s, forceArchetype: archetype);
    return base.copyWith(
      palette: palette,
      headGear: headGear,
      weapon: weapon,
      hasCape: hasCape,
      hasPauldrons: hasPauldrons,
      hasShield: hasShield,
      armorHeaviness: armorHeaviness,
      muscle: muscle,
      hairLength: hairLength,
      glowRunes: glowRunes,
      heightScale: heightScale,
    );
  }

  /// 이 선언에 맞는 몬스터 골격. 인간형이면 `null` 이다.
  Body? bodyFor(HumanoidSpec spec) {
    if (!beast) return null;
    final r = Rng(spec.seed ^ 0x5EED);
    final height = spec.height * 1.1;
    return switch (beastForm) {
      BeastForm.brute => Body.beast(r, height: height),
      BeastForm.drake => Body.drake(r, height: height),
      BeastForm.wraith => Body.wraith(r, height: height),
      BeastForm.arachnid => Body.arachnid(r, height: height),
    };
  }

  CharacterBuild copyWith({
    Archetype? archetype,
    Sex? sex,
    Palette? palette,
    HeadGear? headGear,
    WeaponKind? weapon,
    bool? hasCape,
    double? heightScale,
    bool? beast,
    BeastForm? beastForm,
    int? seed,
  }) => CharacterBuild(
    archetype: archetype ?? this.archetype,
    sex: sex ?? this.sex,
    palette: palette ?? this.palette,
    headGear: headGear ?? this.headGear,
    weapon: weapon ?? this.weapon,
    hasCape: hasCape ?? this.hasCape,
    hasPauldrons: hasPauldrons,
    hasShield: hasShield,
    armorHeaviness: armorHeaviness,
    muscle: muscle,
    hairLength: hairLength,
    glowRunes: glowRunes,
    heightScale: heightScale ?? this.heightScale,
    beast: beast ?? this.beast,
    beastForm: beastForm ?? this.beastForm,
    seed: seed ?? this.seed,
  );

  /// 선언이 없는 [Artist] 를 위한 추정.
  ///
  /// 이름·강조색만 아는 상태에서 최선을 다한 결과이므로, 초상과 정확히 같지는
  /// 않다. 캐릭터가 `build` 를 오버라이드하면 이 추정은 쓰이지 않는다.
  factory CharacterBuild.guess(Artist a) {
    final seed = Rng.fromString(a.id).intRange(1, 0x7FFFFFF);
    final r = Rng(seed);
    final monster = a.camp == Camp.monster;
    return CharacterBuild(
      archetype: monster ? Archetype.berserker : r.pick(Archetype.values),
      sex: a.sex,
      palette: tintedPalette(a.accent, Rng(seed ^ 0xC0107), monster: monster),
      beast: monster,
      beastForm: BeastForm.values[seed % BeastForm.values.length],
      seed: seed,
    );
  }
}

/// 강조색으로 물들인 팔레트.
///
/// 옷·강조·발광·눈만 갈아 끼우고 피부·금속은 생성기에 맡긴다. 전부 한 색으로
/// 칠하면 단색 인형이 되므로, **색이 얹히는 자리를 한정하는 것**이 오히려
/// 정체성을 살린다.
Palette tintedPalette(Color accent, Rng r, {bool monster = false}) {
  final base = monster ? Palette.monster(r) : Palette.hero(r);
  return Palette(
    skin: base.skin,
    skinDeep: base.skinDeep,
    hair: base.hair,
    cloth: accent.darken(0.42).desaturate(0.15),
    clothShade: accent.darken(0.66).desaturate(0.1),
    accent: accent,
    leather: base.leather,
    metal: base.metal,
    metalWarm: base.metalWarm,
    eye: accent.lighten(0.34),
    glow: accent.lighten(0.12),
  );
}

/// 색 몇 개로 캐릭터 팔레트를 만든다.
///
/// 전체 11색을 손으로 고르는 것은 지루하고 조화도 깨지기 쉽다. 머리·옷·강조
/// 셋만 정하면 나머지는 그 셋에서 파생된다.
Palette paletteOf({
  required Color skin,
  required Color hair,
  required Color cloth,
  required Color accent,
  Color? metal,
  Color? leather,
  Color? eye,
  Color? glow,
}) {
  final m = metal ?? const Color(0xFF8E9AAE);
  return Palette(
    skin: skin,
    skinDeep: skin.darken(0.42).saturate(0.22),
    hair: hair,
    cloth: cloth,
    clothShade: cloth.darken(0.34).saturate(0.12),
    accent: accent,
    leather: leather ?? cloth.darken(0.5).mix(const Color(0xFF4A3520), 0.5),
    metal: m,
    metalWarm: m.darken(0.28).mix(const Color(0xFFB08040), 0.35),
    eye: eye ?? accent.lighten(0.30),
    glow: glow ?? accent.lighten(0.15),
  );
}
