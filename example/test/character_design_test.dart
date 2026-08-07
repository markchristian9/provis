import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:provis/provis.dart';
import 'package:provis_example/characters/roster.dart';

void main() {
  group('modern character design language', () {
    test('named monsters declare four different primary forms', () {
      expect({
        for (final monster in monsters) monster.build.beastForm,
      }, BeastForm.values.toSet());
      expect(monsters.every((monster) => monster.build.beast), isTrue);
    });

    test('monster forms use materially different body proportions', () {
      final bodies = <BeastForm, Body>{};
      for (final form in BeastForm.values) {
        final build = CharacterBuild(
          archetype: Archetype.berserker,
          beast: true,
          beastForm: form,
          seed: 73,
        );
        final spec = build.toSpec(73);
        bodies[form] = build.bodyFor(spec)!;
      }

      for (var a = 0; a < BeastForm.values.length; a++) {
        for (var b = a + 1; b < BeastForm.values.length; b++) {
          final aa = BeastForm.values[a];
          final bb = BeastForm.values[b];
          expect(
            _bodyDistance(bodies[aa]!, bodies[bb]!),
            greaterThan(0.08),
            reason: '$aa and $bb collapse to the same body plan',
          );
        }
      }
    });

    test(
      'monster forms remain distinct as silhouettes at game scale',
      () async {
        final masks = <BeastForm, Uint8List>{};
        for (final form in BeastForm.values) {
          final build = CharacterBuild(
            archetype: Archetype.berserker,
            beast: true,
            beastForm: form,
            seed: 91,
          );
          final spec = build.toSpec(91);
          masks[form] = await _renderAlpha(
            HumanoidRenderer(
              spec,
              body: build.bodyFor(spec),
              beast: true,
              beastForm: form,
            ),
          );
        }

        for (var a = 0; a < BeastForm.values.length; a++) {
          for (var b = a + 1; b < BeastForm.values.length; b++) {
            final aa = BeastForm.values[a];
            final bb = BeastForm.values[b];
            expect(
              _maskDifference(masks[aa]!, masks[bb]!),
              greaterThan(600),
              reason: '$aa and $bb are not readable as different silhouettes',
            );
          }
        }
      },
    );

    test('hero classes also retain different game-scale silhouettes', () async {
      final masks = <Archetype, Uint8List>{};
      for (final archetype in Archetype.values) {
        masks[archetype] = await _renderAlpha(
          HumanoidRenderer(
            HumanoidSpec.generate(37, forceArchetype: archetype),
          ),
        );
      }

      for (var a = 0; a < Archetype.values.length; a++) {
        for (var b = a + 1; b < Archetype.values.length; b++) {
          final aa = Archetype.values[a];
          final bb = Archetype.values[b];
          expect(
            _maskDifference(masks[aa]!, masks[bb]!),
            greaterThan(120),
            reason: '$aa and $bb lose their class identity at game scale',
          );
        }
      }
    });
  });
}

double _bodyDistance(Body a, Body b) {
  final av = _bodyValues(a);
  final bv = _bodyValues(b);
  var distance = 0.0;
  for (var i = 0; i < av.length; i++) {
    distance += (av[i] - bv[i]).abs();
  }
  return distance;
}

List<double> _bodyValues(Body body) => [
  body.hipHeight / body.height,
  body.torso / body.height,
  body.headLen / body.height,
  body.shoulderHalf / body.height,
  body.upperArm / body.height,
  body.foreArm / body.height,
  body.thigh / body.height,
  body.shin / body.height,
  body.bulk,
  body.hunch,
  body.depth,
];

int _maskDifference(Uint8List a, Uint8List b) {
  var different = 0;
  for (var i = 0; i < a.length; i++) {
    if ((a[i] > 36) != (b[i] > 36)) different++;
  }
  return different;
}

Future<Uint8List> _renderAlpha(HumanoidRenderer renderer) async {
  const size = 320;
  const actorHeight = 220.0;
  final recorder = PictureRecorder();
  final canvas = Canvas(
    recorder,
    Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
  );
  canvas.translate(size * 0.5, size * 0.91);
  canvas.scale(actorHeight / renderer.body.height);
  renderer.paint(
    canvas,
    pose: Anims.idle.sample(0.36),
    light: LightRig.daylight,
    facing: const Facing(0.85),
    iso: const IsoView(tileWidth: 150, tileHeight: 75),
    time: 0.7,
    detail: 0.9,
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(size, size);
  final data = await image.toByteData(format: ImageByteFormat.rawRgba);
  final rgba = data!.buffer.asUint8List();
  final alpha = Uint8List(size * size);
  for (var pixel = 0; pixel < alpha.length; pixel++) {
    alpha[pixel] = rgba[pixel * 4 + 3];
  }
  image.dispose();
  picture.dispose();
  return alpha;
}
