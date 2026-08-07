import 'package:provis/provis.dart';

enum HeroAttackMode { melee, bow, spell }

/// 장비와 직업을 함께 보고 영웅의 공격 표현을 고른다.
///
/// 활은 직업보다 우선한다. 그 외의 마법사는 지팡이를 활로 바꾸지 않고
/// 자기 팔레트의 마법 탄환을 쏜다.
HeroAttackMode attackModeFor({
  required WeaponKind weapon,
  required Archetype archetype,
}) {
  if (weapon == WeaponKind.bow) return HeroAttackMode.bow;
  if (archetype == Archetype.mage) return HeroAttackMode.spell;
  return HeroAttackMode.melee;
}
