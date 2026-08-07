@Tags(['sheets'])
library;

// 가독성 감사 — 업계가 쓰는 세 가지 검사를 그대로 건다.
//
// 아이소 게임의 캐릭터는 화면에서 200px 남짓이다. 초상 시트에서 좋아 보이는
// 것은 아무 보증도 되지 않으므로, **실제 게임 배율에서** 다음 셋을 본다.
//
//   ① 실루엣  — 검게 칠했을 때 정체와 직군이 구분되는가
//   ② 그레이스케일 — 색을 빼면 명도만 남는다. 여기서 뭉개지면 어떤 팔레트도
//                    구제하지 못한다. "탁한 팔레트는 색 선택이 아니라 명도
//                    대비의 실패다."
//   ③ 배경 위 — 채도 높은 배경에 얹었을 때 캐릭터가 떠오르는가
//
//   flutter test --run-skipped --tags sheets test/readability_audit_test.dart
//   open build/art/audit_*.png

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provis/provis.dart';

const iso = IsoView(tileWidth: 150, tileHeight: 75);

/// 게임에서 쓰는 실제 키. 초상 배율로 감사하면 아무 의미가 없다.
const kGameHeight = 200.0;

Future<void> dump(String name, int w, int h, void Function(Canvas) body) async {
  final rec = ui.PictureRecorder();
  final c = Canvas(rec, Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()));
  body(c);
  final img = await rec.endRecording().toImage(w, h);
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  final f = File('build/art/$name.png');
  f.parent.createSync(recursive: true);
  f.writeAsBytesSync(data!.buffer.asUint8List());
  // ignore: avoid_print
  print('wrote ${f.path} (${w}x$h)');
}

List<(String, HumanoidRenderer)> cast() => [
      ('knight', HumanoidRenderer(
          HumanoidSpec.generate(7, forceArchetype: Archetype.knight))),
      ('mage', HumanoidRenderer(
          HumanoidSpec.generate(11, forceArchetype: Archetype.mage))),
      ('ranger', HumanoidRenderer(
          HumanoidSpec.generate(23, forceArchetype: Archetype.ranger))),
      ('berserker', HumanoidRenderer(
          HumanoidSpec.generate(31, forceArchetype: Archetype.berserker))),
      ('beast-a', HumanoidRenderer(
          HumanoidSpec.generate(5),
          body: Body.beast(Rng(5), height: 190),
          palette: Palette.monster(Rng(9)),
          beast: true)),
      ('beast-b', HumanoidRenderer(
          HumanoidSpec.generate(17),
          body: Body.beast(Rng(17), height: 210),
          palette: Palette.monster(Rng(3)),
          beast: true)),
    ];

void drawActor(Canvas c, HumanoidRenderer r, LightRig light, {double yaw = 0.85}) {
  c.save();
  c.scale(kGameHeight / r.body.height);
  r.paint(c,
      pose: const Pose(),
      light: light,
      facing: Facing(yaw),
      iso: iso,
      detail: 1.0);
  c.restore();
}

void main() {
  const light = LightRig.daylight;
  const cw = 230.0, ch = 300.0;

  testWidgets('① 실루엣 — 검게 칠했을 때 구분되는가', (tester) async {
    await tester.runAsync(() async {
      final actors = cast();
      await dump('audit_silhouette', (cw * actors.length).toInt(), ch.toInt(),
          (c) {
        c.drawRect(Rect.fromLTWH(0, 0, cw * actors.length, ch),
            Paint()..color = const Color(0xFFEDEDED));
        for (var i = 0; i < actors.length; i++) {
          final cell = Rect.fromLTWH(cw * i, 0, cw, ch);
          // saveLayer + srcIn 으로 그려진 픽셀을 통째로 검게 덮는다.
          c.saveLayer(cell, Paint());
          c.translate(cell.center.dx, ch * 0.92);
          drawActor(c, actors[i].$2, light);
          c.translate(-cell.center.dx, -ch * 0.92);
          c.drawRect(cell, Paint()
            ..blendMode = BlendMode.srcIn
            ..color = const Color(0xFF101014));
          c.restore();
        }
      });
    });
  }, timeout: const Timeout(Duration(minutes: 3)));

  testWidgets('② 그레이스케일 — 명도만 남겼을 때 읽히는가', (tester) async {
    await tester.runAsync(() async {
      final actors = cast();
      // 채도를 0 으로 미는 색행렬. 색을 빼면 남는 것이 명도 설계다.
      const desat = ColorFilter.matrix(<double>[
        0.2126, 0.7152, 0.0722, 0, 0,
        0.2126, 0.7152, 0.0722, 0, 0,
        0.2126, 0.7152, 0.0722, 0, 0,
        0, 0, 0, 1, 0,
      ]);
      await dump('audit_grayscale', (cw * actors.length).toInt(), ch.toInt(),
          (c) {
        c.drawRect(Rect.fromLTWH(0, 0, cw * actors.length, ch),
            Paint()..color = const Color(0xFF3A4152));
        c.saveLayer(
            Rect.fromLTWH(0, 0, cw * actors.length, ch),
            Paint()..colorFilter = desat);
        for (var i = 0; i < actors.length; i++) {
          c.save();
          c.translate(cw * i + cw / 2, ch * 0.92);
          drawActor(c, actors[i].$2, light);
          c.restore();
        }
        c.restore();
      });
    });
  }, timeout: const Timeout(Duration(minutes: 3)));

  testWidgets('③ 배경 위 — 채도 높은 지면에서 떠오르는가', (tester) async {
    await tester.runAsync(() async {
      final actors = cast();
      for (final preset in [0, 1, 2, 3]) {
        final l = LightRig.preset(preset);
        await dump('audit_onground_$preset',
            (cw * actors.length).toInt(), ch.toInt(), (c) {
          c.save();
          c.translate(cw * actors.length / 2, ch * 0.55);
          paintIsoGround(c, iso, 14, 14, l, lineAlpha: 0.0, skirt: 0.0);
          c.restore();
          for (var i = 0; i < actors.length; i++) {
            c.save();
            c.translate(cw * i + cw / 2, ch * 0.92);
            drawActor(c, actors[i].$2, l);
            c.restore();
          }
        });
      }
    });
  }, timeout: const Timeout(Duration(minutes: 4)));
}
