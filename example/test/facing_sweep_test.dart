import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provis/provis.dart';

/// 방향 해상도 검증 — 32 분할과 연속 회전이 실제로 다르게 그려지는지 본다.
void main() {
  // 다른 시트 테스트와 같은 자리에 떨어뜨린다. 절대 경로를 박아 두면 그 경로가
  // 있는 기계에서만 통과한다 — 실제로 다른 세션의 스크래치패드를 가리키고 있었다.
  const out = 'build/art';

  Future<void> sheet(String name, int count, int cols) async {
    Directory(out).createSync(recursive: true);
    final renderer = HumanoidRenderer(HumanoidSpec.generate(3));
    const cw = 132.0, ch = 210.0;
    final rows = (count / cols).ceil();
    final w = cw * cols, h = ch * rows;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec, Rect.fromLTWH(0, 0, w, h));
    c.drawRect(Rect.fromLTWH(0, 0, w, h),
        Paint()..color = const Color(0xFF0B0E17));
    for (var i = 0; i < count; i++) {
      final yaw = i * 2 * 3.141592653589793 / count;
      c.save();
      c.translate(cw * (i % cols) + cw / 2, ch * (i ~/ cols) + ch * 0.88);
      c.scale(0.62);
      renderer.paint(c,
          pose: Anims.walk.sample(0.25),
          light: LightRig.preset(0),
          facing: Facing(yaw),
          detail: 1.0);
      c.restore();
    }
    final img = await rec.endRecording().toImage(w.toInt(), h.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    File('$out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  }

  testWidgets('32 방향 스윕', (tester) async {
    await tester.runAsync(() async => sheet('sweep32', 32, 16));
  });

  testWidgets('방향 해상도별 렌더 비용', (tester) async {
    await tester.runAsync(() async {
      final renderer = HumanoidRenderer(HumanoidSpec.generate(3));
      final pose = Anims.walk.sample(0.25);
      for (final n in [8, 16, 32, 360]) {
        final rec = ui.PictureRecorder();
        final c = Canvas(rec, const Rect.fromLTWH(0, 0, 400, 400));
        final sw = Stopwatch()..start();
        for (var i = 0; i < 200; i++) {
          c.save();
          c.translate(200, 350);
          // n 분할로 스냅한 방향
          final yaw = (i % n) * 2 * 3.141592653589793 / n;
          renderer.paint(c,
              pose: pose,
              light: LightRig.preset(0),
              facing: Facing(yaw),
              detail: 1.0);
          c.restore();
        }
        sw.stop();
        rec.endRecording().dispose();
        // ignore: avoid_print
        print('  $n 분할: 200 프레임 ${sw.elapsedMilliseconds}ms '
            '(${(sw.elapsedMicroseconds / 200).toStringAsFixed(0)}µs/프레임)');
      }
    });
  });
}
