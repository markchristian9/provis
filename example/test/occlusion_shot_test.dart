@Tags(['sheets'])
library;

// 가림 처리 대조 시트 — 끄고 켠 두 장을 나란히 굽는다.
//
//   flutter test --run-skipped --tags sheets test/occlusion_shot_test.dart
//   open build/scale/occlusion.png
//
// 왼쪽이 처리 없음(주인공이 건물에 먹혀 사라진다), 오른쪽이 처리 있음.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provis/provis.dart';

const iso = IsoView(tileWidth: 150, tileHeight: 75);
const scale = WorldScale(iso: iso);

void main() {
  testWidgets('가림 처리 전/후', (tester) async {
    const w = 1400, h = 760;
    final light = LightRig.preset(1);

    final rec = ui.PictureRecorder();
    final c = Canvas(rec, const Rect.fromLTWH(0, 0, 1400, 760));
    c.drawRect(const Rect.fromLTWH(0, 0, 1400, 760),
        Paint()..color = const Color(0xFF090D18));

    for (final (side, on) in [(0.0, false), (700.0, true)]) {
      final scene = IsoSceneComponent(
        iso: iso,
        grid: IsoGrid(cols: 16, rows: 16),
        showGrid: false,
        light: light,
      );
      scene.addProp(PropInstance(
        prop: BuildingProp(
          seed: 3,
          tiles: const Size(5, 6),
          storeys: 2,
          tileWidth: iso.tileWidth,
          isoRatio: iso.elevationSin,
        ),
        tile: const Offset(9.0, 9.0),
      ));
      // 주인공은 건물 **뒤**에 선다 — depth 가 더 작다.
      final hero = RiggedIsoActor(
        renderer: HumanoidRenderer(HumanoidSpec.generate(7)),
        tile: const Offset(7.6, 7.6),
        height: scale.humanPx,
        iso: iso,
      );
      scene.rigged.add(hero);
      if (on) scene.occlusionFocus = hero;
      // 페이드가 자리를 잡을 때까지 돌린다.
      for (var i = 0; i < 60; i++) {
        scene.update(1 / 60);
      }
      scene.cameraOffset = Offset.zero;

      c.save();
      c.clipRect(Rect.fromLTWH(side, 0, 700, 760));
      c.translate(side + 350, 250);
      c.scale(0.55);
      scene.render(c);
      c.restore();

      // 상태 띠 — 빨강이 처리 없음, 초록이 처리 있음.
      c.drawRect(Rect.fromLTWH(side, 0, 700, 10),
          Paint()..color = on ? const Color(0xFF3FD98A) : const Color(0xFFFF5A5A));
    }

    c.drawLine(const Offset(700, 0), const Offset(700, 760),
        Paint()..color = const Color(0x33FFFFFF));

    final img = await rec.endRecording().toImage(w, h);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    final f = File('build/scale/occlusion.png');
    f.parent.createSync(recursive: true);
    f.writeAsBytesSync(data!.buffer.asUint8List());
    // ignore: avoid_print
    print('wrote ${f.path} (${w}x$h)');
  });
}
