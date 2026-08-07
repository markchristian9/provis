import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:provis/provis.dart';

void main() {
  const families = <String, List<Clip>>{
    'melee': Anims.meleeCombo,
    'bow': Anims.bowCombo,
    'spell': Anims.spellCombo,
  };

  group('distinct three-stage attack animation', () {
    test('every attack mode has three uniquely named clips', () {
      for (final entry in families.entries) {
        expect(entry.value, hasLength(3), reason: entry.key);
        expect(
          entry.value.map((clip) => clip.name).toSet(),
          hasLength(3),
          reason: '${entry.key} reuses an animation name',
        );
      }
    });

    test('each impact/release pose is materially different', () {
      for (final entry in families.entries) {
        final poses = [
          for (final clip in entry.value) clip.sample(clip.events.single.at),
        ];
        for (var a = 0; a < poses.length; a++) {
          for (var b = a + 1; b < poses.length; b++) {
            expect(
              _poseDistance(poses[a], poses[b]),
              greaterThan(1.4),
              reason:
                  '${entry.key} stages ${a + 1} and ${b + 1} '
                  'have effectively the same impact pose',
            );
          }
        }
      }
    });

    test('every clip fires one synchronized gameplay event', () {
      for (final entry in families.entries) {
        final eventName = entry.key == 'melee' ? 'strike' : 'release';
        for (final clip in entry.value) {
          expect(clip.events.map((event) => event.name), [eventName]);
          final swing = clip.weaponSwing!;
          final peak =
              swing.indexOf(swing.reduce((a, b) => a > b ? a : b)) /
              (swing.length - 1);
          expect(
            peak,
            clip.events.single.at,
            reason: '${clip.name} effect and hit timing diverge',
          );

          for (final fps in const [24.0, 60.0, 144.0]) {
            final animator = Animator()..playByName(clip.name);
            var fired = 0;
            final frames = (clip.duration * fps).ceil();
            for (var i = 0; i < frames; i++) {
              animator.update(1 / fps);
              fired += animator.fired.where((name) => name == eventName).length;
            }
            expect(fired, 1, reason: '${clip.name} at $fps fps');
          }
        }
      }
    });

    test('the three stages render visibly different silhouettes', () async {
      final renderers = <String, HumanoidRenderer>{
        'melee': HumanoidRenderer(
          HumanoidSpec.generate(
            7,
            forceArchetype: Archetype.knight,
          ).copyWith(weapon: WeaponKind.sword),
        ),
        'bow': HumanoidRenderer(
          HumanoidSpec.generate(
            11,
            forceArchetype: Archetype.ranger,
          ).copyWith(weapon: WeaponKind.bow),
        ),
        'spell': HumanoidRenderer(
          HumanoidSpec.generate(
            17,
            forceArchetype: Archetype.mage,
          ).copyWith(weapon: WeaponKind.staff, glowRunes: true),
        ),
      };

      for (final entry in families.entries) {
        final images = <Uint8List>[];
        for (final clip in entry.value) {
          images.add(
            await _render(
              renderers[entry.key]!,
              clip,
              ranged: entry.key == 'bow',
            ),
          );
        }
        for (var a = 0; a < images.length; a++) {
          for (var b = a + 1; b < images.length; b++) {
            var differentPixels = 0;
            for (var i = 0; i < images[a].length; i += 4) {
              if (images[a][i] != images[b][i] ||
                  images[a][i + 1] != images[b][i + 1] ||
                  images[a][i + 2] != images[b][i + 2] ||
                  images[a][i + 3] != images[b][i + 3]) {
                differentPixels++;
              }
            }
            expect(
              differentPixels,
              greaterThan(900),
              reason:
                  '${entry.key} stages ${a + 1} and ${b + 1} '
                  'look the same after rendering',
            );
          }
        }
      }
    });
  });
}

double _poseDistance(Pose a, Pose b) {
  final av = _poseValues(a);
  final bv = _poseValues(b);
  var total = 0.0;
  for (var i = 0; i < av.length; i++) {
    total += (av[i] - bv[i]).abs();
  }
  return total;
}

List<double> _poseValues(Pose pose) => [
  pose.rootX,
  pose.rootY,
  pose.rootRot,
  pose.spine,
  pose.chest,
  pose.head,
  pose.armNear.shoulder,
  pose.armNear.elbow,
  pose.armNear.wrist,
  pose.armFar.shoulder,
  pose.armFar.elbow,
  pose.armFar.wrist,
  pose.legNear.hip,
  pose.legNear.knee,
  pose.legNear.ankle,
  pose.legFar.hip,
  pose.legFar.knee,
  pose.legFar.ankle,
  pose.squash,
  pose.weaponSwing,
];

Future<Uint8List> _render(
  HumanoidRenderer renderer,
  Clip clip, {
  required bool ranged,
}) async {
  const size = 270;
  final recorder = PictureRecorder();
  final canvas = Canvas(
    recorder,
    Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
  );
  canvas.translate(size * 0.5, size * 0.90);
  renderer.paint(
    canvas,
    pose: clip.sample(clip.events.single.at),
    light: LightRig.daylight,
    facing: const Facing(0.85),
    iso: const IsoView(tileWidth: 150, tileHeight: 75),
    time: 0.4,
    detail: 0.85,
    ranged: ranged,
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(size, size);
  final data = await image.toByteData(format: ImageByteFormat.rawRgba);
  final bytes = Uint8List.fromList(data!.buffer.asUint8List());
  image.dispose();
  picture.dispose();
  return bytes;
}
