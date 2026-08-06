import '../core/rng.dart';
import '../core/scheme.dart';

/// 영웅 원형. 비율·장비·색을 한꺼번에 결정하는 상위 다이얼이다.
///
/// 절차적 생성에서 모든 파라미터를 독립적으로 무작위화하면 "특징 없는 평균"
/// 만 쏟아진다. 원형을 먼저 뽑고 그 안에서 변주해야 실루엣이 서로 구별된다.
enum Archetype { knight, berserker, ranger, mage, assassin, paladin }

extension ArchetypeLabel on Archetype {
  String get label => switch (this) {
        Archetype.knight => 'Knight',
        Archetype.berserker => 'Berserker',
        Archetype.ranger => 'Ranger',
        Archetype.mage => 'Mage',
        Archetype.assassin => 'Assassin',
        Archetype.paladin => 'Paladin',
      };
}

enum WeaponKind { sword, greatsword, axe, staff, spear, daggers, bow, none }

enum HeadGear { none, circlet, hood, halfHelm, fullHelm, hornedHelm }

/// 휴머노이드 한 명분의 완전한 명세. 렌더러는 이것만 보고 그린다.
class HumanoidSpec {
  HumanoidSpec._({
    required this.seed,
    required this.archetype,
    required this.palette,
    required this.height,
    required this.headHeight,
    required this.shoulderWidth,
    required this.hipWidth,
    required this.chestWidth,
    required this.waistWidth,
    required this.neckWidth,
    required this.hipY,
    required this.kneeY,
    required this.ankleY,
    required this.waistY,
    required this.chestY,
    required this.shoulderY,
    required this.neckY,
    required this.chinY,
    required this.thigh,
    required this.shin,
    required this.upperArm,
    required this.foreArm,
    required this.handLen,
    required this.footLen,
    required this.armThickness,
    required this.legThickness,
    required this.muscle,
    required this.depthOffset,
    required this.weapon,
    required this.headGear,
    required this.hasCape,
    required this.hasPauldrons,
    required this.pauldronScale,
    required this.hasShield,
    required this.armorHeaviness,
    required this.hairLength,
    required this.capeLength,
    required this.trimAccent,
    required this.glowRunes,
  });

  final int seed;
  final Archetype archetype;
  final Palette palette;

  /// 발바닥(y=0)에서 정수리까지. 모든 길이의 기준 단위.
  final double height;
  final double headHeight;

  final double shoulderWidth;
  final double hipWidth;
  final double chestWidth;
  final double waistWidth;
  final double neckWidth;

  /// 지면 기준 높이(양수). 렌더 시 y = -값 으로 쓴다.
  final double hipY, kneeY, ankleY, waistY, chestY, shoulderY, neckY, chinY;

  final double thigh, shin, upperArm, foreArm, handLen, footLen;
  final double armThickness, legThickness;

  /// 근육량. 사지 두께 프로파일의 부풀림 정도.
  final double muscle;

  /// 3/4 시점에서 먼 쪽 팔다리를 뒤로 밀어내는 거리.
  final double depthOffset;

  final WeaponKind weapon;
  final HeadGear headGear;
  final bool hasCape;
  final bool hasPauldrons;
  final double pauldronScale;
  final bool hasShield;

  /// 0 = 천 위주, 1 = 판금 위주.
  final double armorHeaviness;
  final double hairLength;
  final double capeLength;
  final bool trimAccent;
  final bool glowRunes;

  double get armReach => upperArm + foreArm;
  double get legReach => thigh + shin;

  static HumanoidSpec generate(int seed, {Archetype? forceArchetype}) {
    final r = Rng(seed);
    final Archetype arch = forceArchetype ?? r.pick<Archetype>(Archetype.values);

    // 원형별 체형 다이얼.
    late double heads, broad, bulk, poise;
    switch (arch) {
      case Archetype.knight:
        heads = r.bell(7.2, 7.8);
        broad = r.bell(1.05, 1.16);
        bulk = r.bell(0.55, 0.75);
        poise = 0.5;
      case Archetype.berserker:
        heads = r.bell(6.6, 7.1);
        broad = r.bell(1.16, 1.34);
        bulk = r.bell(0.82, 1.0);
        poise = 0.2;
      case Archetype.ranger:
        heads = r.bell(7.6, 8.1);
        broad = r.bell(0.94, 1.02);
        bulk = r.bell(0.34, 0.5);
        poise = 0.7;
      case Archetype.mage:
        heads = r.bell(7.4, 8.0);
        broad = r.bell(0.86, 0.96);
        bulk = r.bell(0.18, 0.36);
        poise = 0.85;
      case Archetype.assassin:
        heads = r.bell(7.8, 8.3);
        broad = r.bell(0.90, 0.99);
        bulk = r.bell(0.32, 0.48);
        poise = 0.9;
      case Archetype.paladin:
        heads = r.bell(7.0, 7.6);
        broad = r.bell(1.10, 1.24);
        bulk = r.bell(0.62, 0.82);
        poise = 0.45;
    }

    const h = 180.0;
    final headH = h / heads;

    // 인체 비율의 표준 랜드마크. 여기서 크게 벗어나면 아무리 잘 칠해도
    // 사람으로 안 보이므로, 변주는 ±몇 퍼센트로만 준다.
    final ankleY = h * r.bell(0.043, 0.052);
    final kneeY = h * r.bell(0.272, 0.292) * (1 + (poise - 0.5) * 0.03);
    final hipY = h * r.bell(0.508, 0.532);
    final waistY = h * r.bell(0.610, 0.632);
    final chestY = h * r.bell(0.735, 0.755);
    final shoulderY = h * r.bell(0.812, 0.832);
    final neckY = h * 0.848;
    final chinY = h - headH * r.bell(0.94, 1.02);

    return HumanoidSpec._(
      seed: seed,
      archetype: arch,
      palette: Palette.hero(r.branch(11)),
      height: h,
      headHeight: headH,
      shoulderWidth: h * 0.232 * broad,
      chestWidth: h * 0.196 * broad,
      waistWidth: h * 0.146 * (0.85 + broad * 0.18),
      hipWidth: h * 0.166 * (0.9 + broad * 0.12),
      neckWidth: h * 0.050 * (0.85 + bulk * 0.4),
      hipY: hipY,
      kneeY: kneeY,
      ankleY: ankleY,
      waistY: waistY,
      chestY: chestY,
      shoulderY: shoulderY,
      neckY: neckY,
      chinY: chinY,
      thigh: hipY - kneeY,
      shin: kneeY - ankleY,
      upperArm: h * r.bell(0.163, 0.176),
      foreArm: h * r.bell(0.150, 0.162),
      handLen: h * 0.052,
      footLen: h * r.bell(0.062, 0.074),
      armThickness: h * 0.030 * (0.78 + bulk * 0.62),
      legThickness: h * 0.040 * (0.80 + bulk * 0.52),
      muscle: bulk,
      depthOffset: h * r.bell(0.030, 0.048),
      weapon: switch (arch) {
        Archetype.knight => r.weighted(
            [WeaponKind.sword, WeaponKind.spear, WeaponKind.axe],
            [5, 2, 2],
          ),
        Archetype.berserker => r.weighted(
            [WeaponKind.axe, WeaponKind.greatsword],
            [3, 3],
          ),
        Archetype.ranger => r.weighted(
            [WeaponKind.bow, WeaponKind.daggers, WeaponKind.spear],
            [4, 2, 1],
          ),
        Archetype.mage => WeaponKind.staff,
        Archetype.assassin => r.weighted(
            [WeaponKind.daggers, WeaponKind.sword],
            [5, 1],
          ),
        Archetype.paladin => r.weighted(
            [WeaponKind.sword, WeaponKind.greatsword],
            [4, 2],
          ),
      },
      headGear: switch (arch) {
        Archetype.knight => r.weighted(
            [HeadGear.halfHelm, HeadGear.fullHelm, HeadGear.hornedHelm, HeadGear.none],
            [3, 3, 2, 1],
          ),
        Archetype.berserker => r.weighted(
            [HeadGear.hornedHelm, HeadGear.none, HeadGear.halfHelm],
            [4, 3, 2],
          ),
        Archetype.ranger => r.weighted([HeadGear.hood, HeadGear.none, HeadGear.circlet], [4, 3, 1]),
        Archetype.mage => r.weighted([HeadGear.hood, HeadGear.circlet, HeadGear.none], [5, 2, 1]),
        Archetype.assassin => r.weighted([HeadGear.hood, HeadGear.none], [6, 1]),
        Archetype.paladin => r.weighted([HeadGear.fullHelm, HeadGear.halfHelm, HeadGear.circlet], [3, 3, 2]),
      },
      hasCape: switch (arch) {
        Archetype.knight => r.chance(0.75),
        Archetype.berserker => r.chance(0.3),
        Archetype.ranger => r.chance(0.55),
        Archetype.mage => r.chance(0.9),
        Archetype.assassin => r.chance(0.7),
        Archetype.paladin => r.chance(0.95),
      },
      hasPauldrons: switch (arch) {
        Archetype.mage => r.chance(0.25),
        Archetype.assassin => r.chance(0.2),
        Archetype.ranger => r.chance(0.35),
        _ => r.chance(0.9),
      },
      pauldronScale: r.bell(0.9, 1.5),
      hasShield: arch == Archetype.knight || arch == Archetype.paladin ? r.chance(0.45) : false,
      armorHeaviness: switch (arch) {
        Archetype.knight => r.bell(0.7, 0.95),
        Archetype.paladin => r.bell(0.75, 1.0),
        Archetype.berserker => r.bell(0.25, 0.5),
        Archetype.ranger => r.bell(0.2, 0.42),
        Archetype.assassin => r.bell(0.12, 0.32),
        Archetype.mage => r.bell(0.02, 0.16),
      },
      hairLength: r.bell(0.0, 1.0),
      capeLength: r.bell(0.5, 1.0),
      trimAccent: r.chance(0.7),
      glowRunes: switch (arch) {
        Archetype.mage => r.chance(0.9),
        Archetype.paladin => r.chance(0.6),
        _ => r.chance(0.2),
      },
    );
  }

  /// 선언된 항목만 갈아 끼운다.
  ///
  /// [CharacterBuild] 가 캐릭터의 정체성(색·장비)을 덮어쓸 때 쓴다. 지정하지
  /// 않은 것은 원래 생성 결과가 그대로 남으므로, **필요한 것만 선언하면** 나머지
  /// 는 원형에 맞게 유지된다.
  HumanoidSpec copyWith({
    Palette? palette,
    WeaponKind? weapon,
    HeadGear? headGear,
    bool? hasCape,
    bool? hasPauldrons,
    bool? hasShield,
    double? armorHeaviness,
    double? muscle,
    double? hairLength,
    bool? glowRunes,
    double heightScale = 1.0,
  }) {
    final k = heightScale;
    return HumanoidSpec._(
      seed: seed,
      archetype: archetype,
      palette: palette ?? this.palette,
      height: height * k,
      headHeight: headHeight * k,
      shoulderWidth: shoulderWidth * k,
      hipWidth: hipWidth * k,
      chestWidth: chestWidth * k,
      waistWidth: waistWidth * k,
      neckWidth: neckWidth * k,
      hipY: hipY * k,
      kneeY: kneeY * k,
      ankleY: ankleY * k,
      waistY: waistY * k,
      chestY: chestY * k,
      shoulderY: shoulderY * k,
      neckY: neckY * k,
      chinY: chinY * k,
      thigh: thigh * k,
      shin: shin * k,
      upperArm: upperArm * k,
      foreArm: foreArm * k,
      handLen: handLen * k,
      footLen: footLen * k,
      armThickness: armThickness * k,
      legThickness: legThickness * k,
      muscle: muscle ?? this.muscle,
      depthOffset: depthOffset * k,
      weapon: weapon ?? this.weapon,
      headGear: headGear ?? this.headGear,
      hasCape: hasCape ?? this.hasCape,
      hasPauldrons: hasPauldrons ?? this.hasPauldrons,
      pauldronScale: pauldronScale,
      hasShield: hasShield ?? this.hasShield,
      armorHeaviness: armorHeaviness ?? this.armorHeaviness,
      hairLength: hairLength ?? this.hairLength,
      capeLength: capeLength,
      trimAccent: trimAccent,
      glowRunes: glowRunes ?? this.glowRunes,
    );
  }
}
