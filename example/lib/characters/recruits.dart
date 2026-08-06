import 'dart:ui';

import 'package:provis/provis.dart';

/// 선언만으로 만든 캐릭터 20 인.
///
/// ## 이 파일이 보여 주는 것
///
/// `art/pc/aldric.dart` 같은 손그림 캐릭터는 한 명에 700~1300 줄이 든다. 개성의
/// 상한이 없는 대신 **초상과 게임 액터가 서로 다른 코드**라 어긋나기 쉽다.
///
/// 이쪽은 [BuiltArtist] 에 [CharacterBuild] 하나를 넘긴다. 한 명이 15 줄이고,
/// **초상과 게임 액터가 같은 [HumanoidRenderer] 로 그려지므로 어긋날 수가 없다.**
///
/// 새 캐릭터를 추가하려면 아래 목록에 항목 하나를 더하면 된다.
///
/// ## 색을 고르는 법
///
/// [paletteOf] 는 피부·머리·옷·강조 넷만 받고 나머지 일곱 색을 파생시킨다.
/// 열한 색을 손으로 고르면 조화가 깨지기 쉽고, 무엇보다 지루하다.
///
/// **강조색(`accent`)이 그 캐릭터의 정체성이다.** 명부 카드 테두리, 눈, 발광,
/// 게임 맵의 옷 색이 전부 여기서 나온다. 직업마다 색 대역을 갈라 두면 멀리서도
/// 역할이 읽힌다 — 전사는 붉은 계열, 마법사는 청보라, 궁수는 초록, 군인은
/// 카키·회청, 사이보그는 청록·주황.

// ── 전사 ────────────────────────────────────────────────────────────────
//
// 판금과 방패. 어깨가 넓고 근육량이 많다. 색은 철과 피의 대역.

final garran = BuiltArtist(
  id: 'garran',
  name: 'Garran',
  title: 'Shieldbearer of the Pass',
  blurb: '고갯길을 혼자 막아선 방패병.',
  build: CharacterBuild(
    archetype: Archetype.knight,
    sex: Sex.male,
    palette: paletteOf(
      skin: const Color(0xFFC08A66),
      hair: const Color(0xFF3A2A1E),
      cloth: const Color(0xFF7A2E2E),
      accent: const Color(0xFFD9A441),
      metal: const Color(0xFF9AA6B4),
    ),
    weapon: WeaponKind.sword,
    hasShield: true,
    hasPauldrons: true,
    armorHeaviness: 0.9,
    muscle: 0.8,
    headGear: HeadGear.halfHelm,
  ),
  light: LightRig.heroic,
);

final ilsa = BuiltArtist(
  id: 'ilsa',
  name: 'Ilsa',
  title: 'Breaker of the Iron Line',
  blurb: '대검 한 자루로 전열을 무너뜨린다.',
  build: CharacterBuild(
    archetype: Archetype.berserker,
    sex: Sex.female,
    palette: paletteOf(
      skin: const Color(0xFFD9A882),
      hair: const Color(0xFF8C2F2F),
      cloth: const Color(0xFF5A2622),
      accent: const Color(0xFFE86A3A),
      metal: const Color(0xFF8E8175),
    ),
    weapon: WeaponKind.greatsword,
    hasPauldrons: true,
    armorHeaviness: 0.45,
    muscle: 0.95,
    hairLength: 0.7,
  ),
);

final orvath = BuiltArtist(
  id: 'orvath',
  name: 'Orvath',
  title: 'Oathkeeper of Dawnhold',
  blurb: '맹세를 지키기 위해 마지막까지 선다.',
  build: CharacterBuild(
    archetype: Archetype.paladin,
    sex: Sex.male,
    palette: paletteOf(
      skin: const Color(0xFF8A5F44),
      hair: const Color(0xFF2A2018),
      cloth: const Color(0xFF6E4A8C),
      accent: const Color(0xFFF3D06A),
      metal: const Color(0xFFB9C2CE),
    ),
    weapon: WeaponKind.sword,
    hasShield: true,
    hasCape: true,
    armorHeaviness: 1.0,
    glowRunes: true,
    headGear: HeadGear.fullHelm,
  ),
);

final brynn = BuiltArtist(
  id: 'brynn',
  name: 'Brynn',
  title: 'Warden of the Redgate',
  blurb: '붉은 문을 지키는 창병.',
  build: CharacterBuild(
    archetype: Archetype.knight,
    sex: Sex.female,
    palette: paletteOf(
      skin: const Color(0xFFE0B48E),
      hair: const Color(0xFF4A3320),
      cloth: const Color(0xFF2E4A6E),
      accent: const Color(0xFFC94F4F),
      metal: const Color(0xFFA8B2BE),
    ),
    weapon: WeaponKind.spear,
    hasPauldrons: true,
    armorHeaviness: 0.75,
    muscle: 0.6,
    headGear: HeadGear.circlet,
  ),
);

// ── 마법사 ──────────────────────────────────────────────────────────────
//
// 지팡이와 룬. 근육량이 낮고 로브가 실루엣을 지배한다. 청보라 대역.

final calder = BuiltArtist(
  id: 'calder',
  name: 'Calder',
  title: 'Reader of the Deep Index',
  blurb: '읽어서는 안 될 목록을 외운 학자.',
  build: CharacterBuild(
    archetype: Archetype.mage,
    sex: Sex.male,
    palette: paletteOf(
      skin: const Color(0xFFCE9A74),
      hair: const Color(0xFFB9B3A8),
      cloth: const Color(0xFF2C3A78),
      accent: const Color(0xFF6FA8FF),
    ),
    weapon: WeaponKind.staff,
    hasCape: true,
    glowRunes: true,
    headGear: HeadGear.hood,
    armorHeaviness: 0.05,
  ),
  light: LightRig.spectral,
);

final maevis = BuiltArtist(
  id: 'maevis',
  name: 'Maevis',
  title: 'Weaver of Cold Lanterns',
  blurb: '차가운 등불을 엮어 길을 밝힌다.',
  build: CharacterBuild(
    archetype: Archetype.mage,
    sex: Sex.female,
    palette: paletteOf(
      skin: const Color(0xFFE8C4A0),
      hair: const Color(0xFFDCE8F4),
      cloth: const Color(0xFF3B2E6E),
      accent: const Color(0xFF9A6BFF),
    ),
    weapon: WeaponKind.staff,
    hasCape: true,
    glowRunes: true,
    hairLength: 0.9,
    armorHeaviness: 0.02,
  ),
  light: LightRig.spectral,
);

final thessaly = BuiltArtist(
  id: 'thessaly',
  name: 'Thessaly',
  title: 'Ember Conjurer',
  blurb: '불씨를 손끝에 담아 두는 술사.',
  build: CharacterBuild(
    archetype: Archetype.mage,
    sex: Sex.female,
    palette: paletteOf(
      skin: const Color(0xFFB07A55),
      hair: const Color(0xFF2A1A16),
      cloth: const Color(0xFF6E2A20),
      accent: const Color(0xFFFF8A3A),
    ),
    weapon: WeaponKind.staff,
    hasCape: true,
    glowRunes: true,
    hairLength: 0.5,
  ),
  light: LightRig.infernal,
);

final vaskin = BuiltArtist(
  id: 'vaskin',
  name: 'Vaskin',
  title: 'Hollow Chanter',
  blurb: '비어 있는 곳에서 노래를 듣는다.',
  build: CharacterBuild(
    archetype: Archetype.mage,
    sex: Sex.male,
    palette: paletteOf(
      skin: const Color(0xFF9E8A7A),
      hair: const Color(0xFF1E1A22),
      cloth: const Color(0xFF232A3E),
      accent: const Color(0xFF57E8C8),
    ),
    weapon: WeaponKind.staff,
    hasCape: true,
    glowRunes: true,
    headGear: HeadGear.hood,
  ),
  light: LightRig.spectral,
);

// ── 궁수 ────────────────────────────────────────────────────────────────
//
// 활과 가벼운 가죽. Lyra(여)가 이미 있으므로 남성을 채운다. 초록·흙 대역.

final rhodan = BuiltArtist(
  id: 'rhodan',
  name: 'Rhodan',
  title: 'Longshot of the Fen',
  blurb: '늪 건너편까지 화살을 보낸다.',
  build: CharacterBuild(
    archetype: Archetype.ranger,
    sex: Sex.male,
    palette: paletteOf(
      skin: const Color(0xFFB98A62),
      hair: const Color(0xFF4E3A22),
      cloth: const Color(0xFF3E5230),
      accent: const Color(0xFF8FD44A),
      leather: const Color(0xFF4A3520),
    ),
    weapon: WeaponKind.bow,
    hasCape: true,
    headGear: HeadGear.hood,
    armorHeaviness: 0.25,
  ),
);

final teodor = BuiltArtist(
  id: 'teodor',
  name: 'Teodor',
  title: 'Quiver of the Pinewatch',
  blurb: '소나무 초소에서 자란 사냥꾼.',
  build: CharacterBuild(
    archetype: Archetype.ranger,
    sex: Sex.male,
    palette: paletteOf(
      skin: const Color(0xFFD6A87C),
      hair: const Color(0xFF6E5432),
      cloth: const Color(0xFF2E4438),
      accent: const Color(0xFFC7E06A),
      leather: const Color(0xFF3E2C1C),
    ),
    weapon: WeaponKind.bow,
    armorHeaviness: 0.2,
    muscle: 0.45,
  ),
);

// ── 군인 ────────────────────────────────────────────────────────────────
//
// 규율과 제복. 장비가 균일하고 색이 절제돼 있다. 카키·회청 대역.

final holt = BuiltArtist(
  id: 'holt',
  name: 'Holt',
  title: 'Sergeant of the Ninth',
  blurb: '아홉 번째 부대를 끝까지 붙들었다.',
  build: CharacterBuild(
    archetype: Archetype.knight,
    sex: Sex.male,
    palette: paletteOf(
      skin: const Color(0xFFA8764E),
      hair: const Color(0xFF2E2820),
      cloth: const Color(0xFF3E4632),
      accent: const Color(0xFFB8A05A),
      metal: const Color(0xFF7E8790),
    ),
    weapon: WeaponKind.spear,
    hasPauldrons: true,
    armorHeaviness: 0.6,
    headGear: HeadGear.halfHelm,
  ),
);

final serel = BuiltArtist(
  id: 'serel',
  name: 'Serel',
  title: 'Marshal of the Gate Watch',
  blurb: '성문 경비를 지휘한다.',
  build: CharacterBuild(
    archetype: Archetype.paladin,
    sex: Sex.female,
    palette: paletteOf(
      skin: const Color(0xFFE2B892),
      hair: const Color(0xFF3A3028),
      cloth: const Color(0xFF34435A),
      accent: const Color(0xFFDCC27A),
      metal: const Color(0xFF8E97A2),
    ),
    weapon: WeaponKind.sword,
    hasShield: true,
    hasCape: true,
    armorHeaviness: 0.8,
    headGear: HeadGear.circlet,
  ),
);

final dvorak = BuiltArtist(
  id: 'dvorak',
  name: 'Dvorak',
  title: 'Trenchbreaker',
  blurb: '참호를 먼저 넘는 것이 그의 일이다.',
  build: CharacterBuild(
    archetype: Archetype.berserker,
    sex: Sex.male,
    palette: paletteOf(
      skin: const Color(0xFF8E6242),
      hair: const Color(0xFF1E1A14),
      cloth: const Color(0xFF46402E),
      accent: const Color(0xFFE0703A),
      metal: const Color(0xFF6E7278),
    ),
    weapon: WeaponKind.axe,
    hasPauldrons: true,
    armorHeaviness: 0.5,
    muscle: 0.9,
  ),
);

final noor = BuiltArtist(
  id: 'noor',
  name: 'Noor',
  title: 'Signal Officer',
  blurb: '깃발 하나로 전열을 돌려세운다.',
  build: CharacterBuild(
    archetype: Archetype.ranger,
    sex: Sex.female,
    palette: paletteOf(
      skin: const Color(0xFF8A5C3E),
      hair: const Color(0xFF241C16),
      cloth: const Color(0xFF3A4A52),
      accent: const Color(0xFF6ED0C4),
    ),
    weapon: WeaponKind.spear,
    armorHeaviness: 0.4,
    hairLength: 0.3,
  ),
);

// ── 사이보그 ────────────────────────────────────────────────────────────
//
// 금속과 발광. 룬 대신 회로가 빛난다. 청록·주황 대역.

final kestrelUnit = BuiltArtist(
  id: 'kestrel_unit',
  name: 'Kestrel',
  title: 'Frame Nine, Reissued',
  blurb: '아홉 번째 몸으로 걸어 나온 사람.',
  build: CharacterBuild(
    archetype: Archetype.assassin,
    sex: Sex.female,
    palette: paletteOf(
      skin: const Color(0xFFCFA98C),
      hair: const Color(0xFF1A1E24),
      cloth: const Color(0xFF1E2630),
      accent: const Color(0xFF3AE0FF),
      metal: const Color(0xFFB4BEC8),
    ),
    weapon: WeaponKind.daggers,
    glowRunes: true,
    armorHeaviness: 0.55,
    hairLength: 0.2,
  ),
  light: LightRig.spectral,
);

final oreb = BuiltArtist(
  id: 'oreb',
  name: 'Oreb',
  title: 'Loader Chassis',
  blurb: '항만에서 일하다 전장으로 옮겨졌다.',
  build: CharacterBuild(
    archetype: Archetype.berserker,
    sex: Sex.male,
    palette: paletteOf(
      skin: const Color(0xFF9A6B4A),
      hair: const Color(0xFF20242A),
      cloth: const Color(0xFF2A3038),
      accent: const Color(0xFFFF9A3A),
      metal: const Color(0xFF98A2AC),
    ),
    weapon: WeaponKind.axe,
    hasPauldrons: true,
    glowRunes: true,
    armorHeaviness: 0.95,
    muscle: 1.0,
    heightScale: 1.08,
  ),
);

final sable = BuiltArtist(
  id: 'sable',
  name: 'Sable',
  title: 'Ghost Protocol',
  blurb: '기록에 남지 않는 임무만 받는다.',
  build: CharacterBuild(
    archetype: Archetype.assassin,
    sex: Sex.female,
    palette: paletteOf(
      skin: const Color(0xFF7E6250),
      hair: const Color(0xFF16181E),
      cloth: const Color(0xFF14181F),
      accent: const Color(0xFFB06BFF),
      metal: const Color(0xFF6E7682),
    ),
    weapon: WeaponKind.daggers,
    headGear: HeadGear.hood,
    glowRunes: true,
    armorHeaviness: 0.3,
  ),
  light: LightRig.spectral,
);

final vantIron = BuiltArtist(
  id: 'vant_iron',
  name: 'Vant',
  title: 'Ironlung',
  blurb: '숨을 기계에 맡기고 앞줄에 선다.',
  build: CharacterBuild(
    archetype: Archetype.paladin,
    sex: Sex.male,
    palette: paletteOf(
      skin: const Color(0xFFB08868),
      hair: const Color(0xFF2A2A2E),
      cloth: const Color(0xFF243440),
      accent: const Color(0xFF4ADFB0),
      metal: const Color(0xFFA6B0BA),
    ),
    weapon: WeaponKind.greatsword,
    hasPauldrons: true,
    glowRunes: true,
    armorHeaviness: 1.0,
    headGear: HeadGear.fullHelm,
    heightScale: 1.05,
  ),
);

final lumen = BuiltArtist(
  id: 'lumen',
  name: 'Lumen',
  title: 'Field Medic, Augmented',
  blurb: '고치는 손에 회로를 심었다.',
  build: CharacterBuild(
    archetype: Archetype.mage,
    sex: Sex.female,
    palette: paletteOf(
      skin: const Color(0xFFE0BFA0),
      hair: const Color(0xFFEDE4D6),
      cloth: const Color(0xFF2E3C46),
      accent: const Color(0xFF7CF0D0),
    ),
    weapon: WeaponKind.staff,
    glowRunes: true,
    armorHeaviness: 0.2,
    hairLength: 0.4,
  ),
  light: LightRig.spectral,
);

final corvid = BuiltArtist(
  id: 'corvid',
  name: 'Corvid',
  title: 'Recon Frame',
  blurb: '정찰만 하고 절대 교전하지 않는다.',
  build: CharacterBuild(
    archetype: Archetype.ranger,
    sex: Sex.female,
    palette: paletteOf(
      skin: const Color(0xFF8E7058),
      hair: const Color(0xFF1C2028),
      cloth: const Color(0xFF20303A),
      accent: const Color(0xFF5AC8FF),
      metal: const Color(0xFF8A94A0),
    ),
    weapon: WeaponKind.bow,
    glowRunes: true,
    armorHeaviness: 0.35,
  ),
);

/// 새로 합류한 20 인.
final List<Artist> recruits = List<Artist>.unmodifiable([
  // 전사
  garran, ilsa, orvath, brynn,
  // 마법사
  calder, maevis, thessaly, vaskin,
  // 궁수
  rhodan, teodor,
  // 군인
  holt, serel, dvorak, noor,
  // 사이보그
  kestrelUnit, oreb, sable, vantIron, lumen, corvid,
]);
