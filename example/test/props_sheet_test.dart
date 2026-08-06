import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provis/provis.dart';

/// 맵 기물을 PNG 로 덤프하는 도구.
///
/// 기물은 코드를 읽어서는 품질을 알 수 없다. 실제로 래스터화해 눈으로 봐야만
/// "나무로 보이는가 / 초록 풍선인가" 가 판별된다.
///
///   flutter test test/props_sheet_test.dart
///
/// 출력 경로는 `VIS_OUT` 환경 변수로 바꾼다.
void main() {
  final outDir = Platform.environment['VIS_OUT'] ?? 'build/props';
  const iso = IsoView(tileWidth: 150, tileHeight: 75);

  Future<void> dump(String name, int w, int h, void Function(Canvas) body) async {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec, Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()));
    body(c);
    final img = await rec.endRecording().toImage(w, h);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$outDir/$name.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(data!.buffer.asUint8List());
    // ignore: avoid_print
    print('wrote ${file.path} (${w}x$h)');
  }

  void label(Canvas c, String text, Offset at, {double size = 13}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: size,
          letterSpacing: 1.2,
          color: const Color(0xFFBFD2F0).withValues(alpha: 0.75),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, at);
  }

  /// 셀 하나 — 지면 타일 몇 장을 깔고 그 위에 기물을 세운다.
  void cell(Canvas c, Rect box, LightRig light, String name, Prop prop,
      {double t = 1.2}) {
    // 3×3 지면의 한가운데 타일이 셀 중앙-아래에 오도록 원점을 옮긴다.
    final o = iso.project(1.5, 1.5);
    c.save();
    c.clipRect(box);
    c.translate(box.center.dx - o.dx, box.bottom - box.height * 0.30 - o.dy);

    // 기물이 서 있는 지면. 이것이 없으면 접지 판정을 할 수 없다.
    paintIsoGround(c, iso, 3, 3, light, lineAlpha: 0.05);

    paintProp(
      c,
      PropInstance(prop: prop, tile: const Offset(1.5, 1.5)),
      iso,
      light,
      t,
    );
    c.restore();
    label(c, name, box.topLeft + const Offset(10, 8));
  }

  testWidgets('기물 시트를 굽는다', (tester) async {
    for (final (pi, preset) in [1, 0].indexed) {
      final light = LightRig.preset(preset);
      const cols = 4;
      const cw = 380.0, ch = 440.0;

      final entries = <(String, Prop)>[
        ('tree · broadleaf', TreeProp(seed: 11, trunkHeight: 150)),
        ('tree · broadleaf 2', TreeProp(seed: 17, trunkHeight: 160)),
        ('tree · conifer',
            TreeProp(seed: 12, kind: TreeKind.conifer, trunkHeight: 160)),
        ('tree · pine',
            TreeProp(seed: 16, kind: TreeKind.pine, trunkHeight: 170)),
        ('tree · blossom',
            TreeProp(seed: 13, kind: TreeKind.blossom, trunkHeight: 150)),
        ('tree · dead',
            TreeProp(seed: 14, kind: TreeKind.dead, trunkHeight: 150)),
        ('tree · willow',
            TreeProp(seed: 15, kind: TreeKind.willow, trunkHeight: 150)),
        ('bush', TreeProp(seed: 18, kind: TreeKind.bush, trunkHeight: 52)),
        ('rock', RockProp(seed: 21, size: 58, mossy: true, shards: 3)),
        ('pebbles', PebbleField(seed: 22, radius: 90)),
        ('water', WaterProp(seed: 31, radius: 120)),
        ('lava', LavaProp(seed: 32, radius: 110)),
        (
          'building · timber',
          BuildingProp(
              seed: 41,
              tiles: const Size(2, 2),
              storeys: 2,
              tileWidth: iso.tileWidth,
              isoRatio: iso.elevationSin)
        ),
        (
          'building · stone/cone',
          BuildingProp(
              seed: 42,
              tiles: const Size(1, 1),
              storeys: 2,
              wall: WallStyle.stone,
              roof: RoofStyle.cone,
              tileWidth: iso.tileWidth,
              isoRatio: iso.elevationSin)
        ),
        (
          'building · log',
          BuildingProp(
              seed: 43,
              tiles: const Size(2, 1),
              wall: WallStyle.log,
              tileWidth: iso.tileWidth,
              isoRatio: iso.elevationSin)
        ),
        (
          'wall',
          WallProp(
              seed: 51,
              crenellated: true,
              tileWidth: iso.tileWidth,
              isoRatio: iso.elevationSin)
        ),
        ('grass patch', GroundPatch(seed: 61, radius: 100, blades: 26)),
        (
          'flower patch',
          GroundPatch(
              seed: 62,
              radius: 100,
              blades: 26,
              flowerColor: const Color(0xFFFF7FB0))
        ),
        (
          'path',
          PathPatch(
              seed: 71, tileWidth: iso.tileWidth, isoRatio: iso.elevationSin)
        ),
      ];

      final rows = (entries.length / cols).ceil();
      final w = (cw * cols).round();
      final h = (ch * rows).round();

      await dump('props_${preset == 1 ? 'dusk' : 'noon'}', w, h, (c) {
        c.drawRect(
          Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
          Paint()..color = light.ambient.darken(0.45),
        );
        for (final (i, e) in entries.indexed) {
          final box = Rect.fromLTWH(
            (i % cols) * cw,
            (i ~/ cols) * ch,
            cw,
            ch,
          );
          cell(c, box, light, e.$1, e.$2);
        }
      });
      expect(pi, greaterThanOrEqualTo(0));
    }
  });

  testWidgets('작은 마을 씬을 굽는다', (tester) async {
    const w = 1500, h = 1100;
    final light = LightRig.preset(1);

    await dump('scene_village', w, h, (c) {
      c.drawRect(
        Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
        Paint()..color = const Color(0xFF090D18),
      );
      c.save();
      c.translate(w / 2, 130);

      const cols = 9, rows = 9;
      paintIsoGround(c, iso, cols, rows, light, lineAlpha: 0.06);

      final props = <PropInstance>[
        PropInstance(
          prop: BuildingProp(
            seed: 3,
            tiles: const Size(2, 2),
            storeys: 2,
            tileWidth: iso.tileWidth,
            isoRatio: iso.elevationSin,
          ),
          tile: const Offset(2.0, 2.0),
        ),
        PropInstance(
          prop: BuildingProp(
            seed: 9,
            tiles: const Size(1, 1),
            wall: WallStyle.log,
            tileWidth: iso.tileWidth,
            isoRatio: iso.elevationSin,
          ),
          tile: const Offset(6.5, 1.5),
        ),
        for (var i = 0; i < 4; i++)
          PropInstance(
            prop: PathPatch(
                seed: 100 + i,
                tileWidth: iso.tileWidth,
                isoRatio: iso.elevationSin),
            tile: Offset(i + 2.5, 5.5),
          ),
        PropInstance(
          prop: WaterProp(seed: 5, radius: 140),
          tile: const Offset(7.0, 7.0),
        ),
        PropInstance(prop: RockProp(seed: 7, size: 46, mossy: true),
            tile: const Offset(4.5, 7.5)),
        ...plantForest(
          seed: 77,
          tiles: const [
            Offset(0.6, 3.4),
            Offset(1.4, 7.2),
            Offset(3.2, 8.4),
            Offset(7.6, 3.6),
            Offset(8.4, 5.4),
            Offset(5.6, 2.6),
          ],
          kinds: const [
            TreeKind.broadleaf,
            TreeKind.conifer,
            TreeKind.blossom,
          ],
          baseHeight: 150,
        ),
        for (var i = 0; i < 6; i++)
          PropInstance(
            prop: GroundPatch(seed: 200 + i * 13, radius: 80, blades: 22),
            tile: Offset(1.0 + i * 1.4, 3.0 + (i % 3) * 1.7),
          ),
      ];

      paintProps(c, props, iso, light, 1.4);
      c.restore();
    });
  });
}
