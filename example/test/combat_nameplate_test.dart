import 'package:flutter_test/flutter_test.dart';
import 'package:provis_example/screens/game_map.dart';

void main() {
  group('combat health-bar visibility', () {
    test('is hidden while both combatants are idle', () {
      expect(
        shouldShowCombatHealthBar(
          heroAlive: true,
          mobAlive: true,
          mobAlerted: false,
          mobTargeted: false,
        ),
        isFalse,
      );
    });

    test('appears for aggro or an explicitly targeted monster', () {
      for (final state in const [
        (alerted: true, targeted: false),
        (alerted: false, targeted: true),
      ]) {
        expect(
          shouldShowCombatHealthBar(
            heroAlive: true,
            mobAlive: true,
            mobAlerted: state.alerted,
            mobTargeted: state.targeted,
          ),
          isTrue,
        );
      }
    });

    test('is hidden as soon as either combatant is dead', () {
      for (final state in const [
        (heroAlive: false, mobAlive: true),
        (heroAlive: true, mobAlive: false),
      ]) {
        expect(
          shouldShowCombatHealthBar(
            heroAlive: state.heroAlive,
            mobAlive: state.mobAlive,
            mobAlerted: true,
            mobTargeted: true,
          ),
          isFalse,
        );
      }
    });
  });
}
