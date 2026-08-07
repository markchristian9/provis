import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:provis/provis.dart';
import 'package:provis_example/combat/attack_combo.dart';
import 'package:provis_example/combat/attack_mode.dart';
import 'package:provis_example/combat/projectile.dart';

void main() {
  group('hero attack mode', () {
    test('bows fire arrows regardless of archetype', () {
      expect(
        attackModeFor(weapon: WeaponKind.bow, archetype: Archetype.mage),
        HeroAttackMode.bow,
      );
    });

    test('mages without bows cast spells and other heroes stay melee', () {
      expect(
        attackModeFor(weapon: WeaponKind.staff, archetype: Archetype.mage),
        HeroAttackMode.spell,
      );
      expect(
        attackModeFor(weapon: WeaponKind.staff, archetype: Archetype.paladin),
        HeroAttackMode.melee,
      );
    });
  });

  group('three-step attack combo', () {
    test('requires one queued input for each follow-up', () {
      final combo = AttackCombo()..begin(chained: false);

      expect(combo.step, 1);
      expect(combo.queue(), isTrue);
      expect(combo.takeQueued(), isTrue);
      combo.begin(chained: true);
      expect(combo.step, 2);

      expect(combo.queue(), isTrue);
      expect(combo.takeQueued(), isTrue);
      combo.begin(chained: true);
      expect(combo.step, 3);
      expect(combo.queue(), isFalse, reason: 'the finisher must end the chain');
    });

    test('finisher is faster and deals two damage', () {
      final combo = AttackCombo()..begin(chained: false);
      final openingRate = combo.attackRate;
      combo
        ..begin(chained: true)
        ..begin(chained: true);

      expect(combo.step, 3);
      expect(combo.damage, 2);
      expect(combo.attackRate, greaterThan(openingRate));
    });

    test('expires after its hold window and can be broken immediately', () {
      final combo = AttackCombo(holdSeconds: 0.5)..begin(chained: false);
      combo.update(0.4, attacking: false);
      expect(combo.visible, isTrue);
      combo.update(0.2, attacking: false);
      expect(combo.step, 0);

      combo
        ..begin(chained: false)
        ..queue()
        ..reset();
      expect(combo.step, 0);
      expect(combo.queued, isFalse);
    });
  });

  group('ranged projectile timing', () {
    test('applies its impact exactly once after travel completes', () {
      var impacts = 0;
      final projectile = CombatProjectile(
        kind: CombatProjectileKind.arrow,
        start: Offset.zero,
        destination: const Offset(4, 2),
        color: const Color(0xFFFFFFFF),
        duration: 0.4,
        onImpact: () => impacts++,
      );

      expect(projectile.update(0.2), isFalse);
      expect(impacts, 0, reason: 'damage cannot arrive before the arrow');
      expect(projectile.update(0.2), isFalse);
      expect(projectile.impacted, isTrue);
      expect(impacts, 1);
      expect(projectile.update(0.1), isFalse);
      expect(projectile.update(0.2), isTrue);
      expect(impacts, 1, reason: 'impact callback fired more than once');
    });

    test('can track a moving target until impact', () {
      var target = const Offset(3, 3);
      final projectile = CombatProjectile(
        kind: CombatProjectileKind.spell,
        start: Offset.zero,
        destination: target,
        targetTile: () => target,
        color: const Color(0xFF57E8FF),
        duration: 0.5,
      );

      projectile.update(0.25);
      target = const Offset(5, 4);
      projectile.update(0.25);
      expect(projectile.impacted, isTrue);
    });

    test('both arrow and spell render visible pixels', () async {
      for (final kind in CombatProjectileKind.values) {
        final recorder = PictureRecorder();
        final canvas = Canvas(recorder);
        final projectile = CombatProjectile(
          kind: kind,
          start: Offset.zero,
          destination: const Offset(4, 2),
          color: const Color(0xFF57E8FF),
          duration: 0.6,
        )..update(0.3);

        projectile.paint(
          canvas,
          const IsoView(tileWidth: 80, tileHeight: 40),
          const Offset(100, 100),
        );
        final picture = recorder.endRecording();
        final image = await picture.toImage(420, 220);
        final bytes = await image.toByteData(format: ImageByteFormat.rawRgba);

        expect(bytes, isNotNull);
        expect(
          bytes!.buffer.asUint32List().any((pixel) => pixel != 0),
          isTrue,
          reason: '$kind rendered no visible projectile pixels',
        );
        image.dispose();
        picture.dispose();
      }
    });
  });
}
