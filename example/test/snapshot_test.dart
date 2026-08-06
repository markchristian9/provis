import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provis/provis.dart';

/// 눈으로 확인하기 위한 시트를 굽는다.
///
/// 절차적 캐릭터는 한 프레임만 봐서는 판단할 수 없다 — 클립마다 실루엣이
/// 무너지는 구간이 따로 있기 때문이다. 전 클립 × 여러 시점을 한 장에 모아
/// 놓고 봐야 어느 동작의 어느 순간이 깨지는지 바로 짚힌다.
///
///   flutter test test/snapshot_test.dart
///
/// 결과는 /private/tmp/claude-501/-Users-thruthesky-tmp-games-vis/9b49c4f1-d75a-46f9-a56b-81e8fd36373f/scratchpad/snapshots/ 에 떨어진다.
void main() {
  const cell = Size(190, 300);
  const phases = [0.0, 0.25, 0.5, 0.75];

  Future<void> bake(String name, HumanoidRenderer renderer, int lightPreset) async {
    final cols = phases.length;
    final rows = Anims.all.length;
    final w = cell.width * cols + 120;
    final h = cell.height * rows;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..color = const Color(0xFF0B0E17),
    );

    final light = LightRig.preset(lightPreset);
    for (var r = 0; r < rows; r++) {
      final clip = Anims.all[r];
      final label = TextPainter(
        text: TextSpan(
          text: clip.label.toUpperCase(),
          style: const TextStyle(
            color: Color(0xFF9FB2D8),
            fontSize: 13,
            letterSpacing: 2,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, Offset(14, r * cell.height + cell.height * 0.5));

      for (var c = 0; c < cols; c++) {
        canvas.save();
        canvas.translate(
          120 + c * cell.width + cell.width * 0.5,
          r * cell.height + cell.height * 0.86,
        );
        renderer.paint(
          canvas,
          pose: clip.sample(phases[c]),
          light: light,
          facing: const Facing(0.9),
          time: phases[c] * clip.duration,
          detail: 1.0,
          ranged: clip.name == 'shoot',
        );
        canvas.restore();
      }
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(w.round(), h.round());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir = Directory('/private/tmp/claude-501/-Users-thruthesky-tmp-games-vis/9b49c4f1-d75a-46f9-a56b-81e8fd36373f/scratchpad/snapshots')..createSync(recursive: true);
    File('${dir.path}/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  }

  testWidgets('영웅 애니메이션 시트', (tester) async {
    await tester.runAsync(() async {
      await bake('hero', HumanoidRenderer(HumanoidSpec.generate(7)), 0);
      await bake('knight', HumanoidRenderer(HumanoidSpec.generate(3, forceArchetype: Archetype.knight)), 0);
      });
});

  testWidgets('짐승 애니메이션 시트', (tester) async {
    await tester.runAsync(() async {
      final spec = HumanoidSpec.generate(7);
      await bake(
        'beast',
        HumanoidRenderer(
          spec,
          body: Body.beast(Rng(7 ^ 0x5EED), height: spec.height * 1.12),
          palette: Palette.monster(Rng(7 ^ 0xB0A5)),
          beast: true,
        ),
        3,
      );
      });
});

  testWidgets('8방향 시트', (tester) async {
    await tester.runAsync(() async {
      final renderer = HumanoidRenderer(HumanoidSpec.generate(7));
      const w = 190.0 * 8;
      const h = 300.0;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, w, h));
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, w, h),
        Paint()..color = const Color(0xFF0B0E17),
      );
      for (var i = 0; i < 8; i++) {
        canvas.save();
        canvas.translate(190.0 * i + 95, h * 0.86);
        renderer.paint(
          canvas,
          pose: Anims.wait.sample(0.2),
          light: LightRig.preset(1),
          facing: Facing(i * 3.14159265 / 4),
          detail: 1.0,
        );
        canvas.restore();
      }
      final image = await recorder.endRecording().toImage(w.round(), h.round());
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      Directory('/private/tmp/claude-501/-Users-thruthesky-tmp-games-vis/9b49c4f1-d75a-46f9-a56b-81e8fd36373f/scratchpad/snapshots').createSync(recursive: true);
      File('/private/tmp/claude-501/-Users-thruthesky-tmp-games-vis/d83a6054-46af-4fe1-ad43-82da4277d273/scratchpad/facing.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      });
});
}
