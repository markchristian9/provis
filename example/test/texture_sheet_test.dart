import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provis/provis.dart';
import 'package:provis_example/characters/roster.dart';
import 'package:provis_example/world/village.dart';

/// 재질 텍스처를 PNG 로 덤프하는 도구.
///
/// 렌더러에 얹은 매크로 텍스처(주름·끈·판 경계·사슬·가죽 얼룩)와 지면의
/// 낟알 층은 코드를 읽어서는 검증할 수 없다. 갑주 세 단계와 짐승, 그리고
/// 지면 한 장을 실제로 래스터화해 눈으로 본다.
///
///   flutter test test/texture_sheet_test.dart && open build/art/texture_*.png
void main() {
  final outDir = Platform.environment['VIS_OUT'] ?? 'build/art';

  Future<void> dump(String name, int w, int h, void Function(Canvas) body) async {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec, Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()));
    c.drawRect(
      Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      Paint()..color = const Color(0xFF141A28),
    );
    body(c);
    final img = await rec.endRecording().toImage(w, h);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$outDir/$name.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(data!.buffer.asUint8List());
    // ignore: avoid_print
    print('wrote ${file.path} (${w}x$h)');
  }

  testWidgets('갑주 단계별 몸통 텍스처 시트', (tester) async {
    await tester.runAsync(() async {
      const light = LightRig.daylight;
      const cw = 430.0, ch = 660.0;

      // 천 → 가죽 → 판금 → 짐승. 각 단계가 다른 텍스처 경로를 지난다.
      final subjects = <HumanoidRenderer>[
        HumanoidRenderer(
            HumanoidSpec.generate(11, forceArchetype: Archetype.mage)),
        HumanoidRenderer(
            HumanoidSpec.generate(23, forceArchetype: Archetype.ranger)),
        HumanoidRenderer(
            HumanoidSpec.generate(7, forceArchetype: Archetype.knight)),
        HumanoidRenderer(
          HumanoidSpec.generate(5),
          body: Body.beast(Rng(5), height: 200),
          palette: Palette.monster(Rng(9)),
          beast: true,
        ),
      ];

      await dump('texture_actors', (cw * subjects.length).toInt(), ch.toInt(),
          (c) {
        for (var i = 0; i < subjects.length; i++) {
          final r = subjects[i];
          c.save();
          c.translate(cw * i + cw / 2, ch * 0.90);
          final s = ch * 0.80 / r.body.height;
          c.scale(s);
          r.paint(c,
              pose: const Pose(),
              light: light,
              facing: const Facing(0.85),
              detail: 1.0);
          c.restore();
          c.drawRect(
            Rect.fromLTWH(cw * i, 0, cw, ch).deflate(0.5),
            Paint()
              ..style = PaintingStyle.stroke
              ..color = const Color(0x33FFFFFF),
          );
        }
      });
    });
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('지면 낟알 층 시트', (tester) async {
    await tester.runAsync(() async {
      const iso = IsoView(tileWidth: 150, tileHeight: 75);
      const w = 1400, h = 900;
      await dump('texture_ground', w, h, (c) {
        final off = isoCameraOffset(iso, 10, 8, const Size(1400, 900));
        c.translate(off.dx, off.dy);
        paintIsoGround(c, iso, 10, 8, LightRig.daylight, lineAlpha: 0.0);
      });
    });
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('인게임 프레이밍으로 마을 한 컷', (tester) async {
    // 텍스처는 시트가 아니라 실제 화면 배율에서 판정해야 한다 — 초상에서
    // 좋아 보이는 결이 게임 줌에서는 노이즈가 되고, 그 반대도 흔하다.
    await tester.runAsync(() async {
      const iso = IsoView(tileWidth: 150, tileHeight: 75);
      const scale = WorldScale(iso: iso);
      const view = Size(1280, 720);

      final scene = IsoSceneComponent(
        iso: iso,
        grid: IsoGrid(cols: kVillageCols, rows: kVillageRows),
        light: LightRig.preset(1),
      );
      buildVillage(scene: scene, seed: 20260806, scale: scale);

      final start = Offset(kVillageCols / 2 + 0.5, kVillageRows / 2 + 2.5);
      scene.rigged.add(
        riggedFromArtist(heroes.first, tile: start, height: 200, iso: iso),
      );
      for (final (i, m) in monsters.indexed) {
        scene.rigged.add(
          riggedFromArtist(
            m,
            tile: start + Offset(1.5 + i * 1.1, i.isEven ? 1.0 : -1.0),
            height: 215,
            iso: iso,
          ),
        );
      }

      // 주인공 발치를 화면 중앙에 둔다.
      final anchor = iso.project(start.dx, start.dy);
      scene.cameraOffset =
          Offset(view.width / 2 - anchor.dx, view.height / 2 - anchor.dy);
      scene.cullToViewport = true;
      scene.viewport = (Offset.zero & view).inflate(iso.tileWidth);
      scene.update(0.4);

      await dump('texture_scene', view.width.toInt(), view.height.toInt(),
          scene.render);
    });
  }, timeout: const Timeout(Duration(minutes: 3)));
}
