// 스케일 대조 시트 — 고치기 전과 후를 눈으로 확인할 수 있게 굽는다.
//
// 숫자표만으로는 "2층집 1.74 m" 가 화면에서 어떻게 보이는지 전달되지 않는다.
// 사람이 집보다 큰 그림을 직접 봐야 결함이 무엇이었는지 이해된다.
//
//   flutter test test/scale_shot_test.dart
//   open build/scale/*.png
//
// **라벨은 ASCII 로 쓴다.** 테스트 렌더러에는 한글 폰트가 없어 한글을 넣으면
// 전부 두부(□)로 나온다 — 시트의 설명이 사라진다.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provis/provis.dart';


import 'package:provis_example/world/village.dart';

const iso = IsoView(tileWidth: 150, tileHeight: 75);
const scale = WorldScale(iso: iso);
const mapSeed = 20260806;

Future<void> dump(String name, int w, int h, void Function(Canvas) body) async {
  final rec = ui.PictureRecorder();
  final c = Canvas(rec, Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()));
  body(c);
  final img = await rec.endRecording().toImage(w, h);
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  final f = File('build/scale/$name.png');
  f.parent.createSync(recursive: true);
  f.writeAsBytesSync(data!.buffer.asUint8List());
  // ignore: avoid_print
  print('wrote ${f.path} (${w}x$h)');
}

void label(Canvas c, String text, Offset at,
    {double size = 15, Color color = const Color(0xFFCFE0FF)}) {
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
          fontSize: size, letterSpacing: 0.6, color: color, height: 1.35),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(c, at);
}

/// 사람 하나를 기준자로 세운다. 모든 비교의 기준이다.
void human(Canvas c, LightRig light, Offset tile, double heightPx, int seed) {
  paintRiggedActor(
    c,
    RiggedIsoActor(
      renderer: HumanoidRenderer(HumanoidSpec.generate(seed)),
      tile: tile,
      height: heightPx,
      iso: iso,
    ),
    iso,
    light,
    1.2,
  );
}

void main() {
  final light = LightRig.preset(1);

  testWidgets('고치기 전/후 대조 시트', (tester) async {
    const w = 1560, h = 820;
    // 두 칸 모두 **같은 줌**으로 그린다. 각자 맞춰 그리면 비교가 거짓말이 된다.
    const zoom = 0.42;

    await dump('before_after', w, h, (c) {
      c.drawRect(Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
          Paint()..color = const Color(0xFF090D18));

      for (final (side, isBefore) in [(0.0, true), (780.0, false)]) {
        c.save();
        c.clipRect(Rect.fromLTWH(side, 0, 780, h.toDouble()));
        c.translate(side + 390, 690);
        c.scale(zoom);
        paintIsoGround(c, iso, 7, 7, light, lineAlpha: 0.05);

        final props = <PropInstance>[
          PropInstance(
            prop: BuildingProp(
              seed: 3,
              tiles: isBefore ? const Size(2, 2) : const Size(5, 6),
              storeys: 2,
              tileWidth: iso.tileWidth,
              isoRatio: iso.elevationSin,
              // 고치기 전 층고: tileWidth × 0.36 = 54 px = 0.51 m
              storeyHeightOverride: isBefore ? iso.tileWidth * 0.36 : null,
            ),
            tile: const Offset(2.6, 2.6),
          ),
          PropInstance(
            prop: WallProp(
              seed: 4,
              tileWidth: iso.tileWidth,
              isoRatio: iso.elevationSin,
              wallHeight: isBefore ? 52 : null,
              crenellated: true,
              alongX: true,
            ),
            tile: const Offset(6.0, 1.2),
          ),
          ...plantForest(
            seed: 77,
            tiles: const [Offset(0.8, 5.4)],
            scale: scale,
            baseHeight: isBefore ? 150 : null,
            kinds: const [TreeKind.conifer],
          ),
        ];

        paintProps(c, props, iso, light, 1.2);
        // 사람은 양쪽 모두 **같은 키**다. 변한 것은 기물뿐이라는 사실을 보인다.
        human(c, light, const Offset(5.4, 5.6), scale.humanPx, 7);
        c.restore();

        label(
          c,
          isBefore
              ? 'BEFORE\n2-storey house 1.74 m  ·  wall 0.49 m  ·  tree 3.0 m\n'
                  'The 1.8 m hero is TALLER than the whole house.'
              : 'AFTER\n2-storey house 8.4 m  ·  wall 2.6 m  ·  tree 9.8 m\n'
                  'The same 1.8 m hero now stands at the doorway.',
          Offset(side + 26, 24),
          size: 16,
          color: isBefore ? const Color(0xFFFF9B9B) : const Color(0xFF9BFFC4),
        );
      }

      c.drawLine(const Offset(780, 0), Offset(780, h.toDouble()),
          Paint()..color = const Color(0x33FFFFFF));
      label(c, 'same camera  ·  same light  ·  same hero  ·  1 tile = 1 m',
          const Offset(26, 782),
          size: 13, color: const Color(0x88CFE0FF));
    });
  });

  testWidgets('사람과 출입문 — 기준자 대조', (tester) async {
    const w = 1100, h = 820;
    await dump('human_vs_door', w, h, (c) {
      c.drawRect(Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
          Paint()..color = const Color(0xFF090D18));
      c.save();
      c.translate(w / 2 - 40, 700);
      c.scale(0.62);
      paintIsoGround(c, iso, 7, 7, light, lineAlpha: 0.04);

      paintProps(
        c,
        [
          PropInstance(
            prop: BuildingProp(
              seed: 11,
              tiles: const Size(5, 6),
              storeys: 1,
              tileWidth: iso.tileWidth,
              isoRatio: iso.elevationSin,
              wall: WallStyle.timber,
              chimney: false,
            ),
            tile: const Offset(3.0, 2.4),
          ),
        ],
        iso,
        light,
        1.2,
      );
      // 문은 +y 면에 난다. 그 앞에 사람을 세운다.
      human(c, light, const Offset(3.0, 5.8), scale.humanPx, 7);
      c.restore();

      label(
        c,
        'Hero 1.80 m  vs  door 2.05 m  ·  storey 2.9 m\n'
        'The doorway clears the head; shoulders clear the jambs.',
        const Offset(26, 24),
        size: 16,
      );
    });
  });

  testWidgets('마을 전경', (tester) async {
    const w = 1700, h = 950;
    final scene = IsoSceneComponent(
      iso: iso,
      grid: IsoGrid(cols: kVillageCols, rows: kVillageRows),
      showGrid: false,
      light: light,
    );
    final layout = buildVillage(
      scene: scene,
      seed: mapSeed,
      scale: scale,
      mobCount: 6,
    );
    scene.rigged.add(RiggedIsoActor(
      renderer: HumanoidRenderer(HumanoidSpec.generate(7)),
      tile: layout.heroSpawn,
      height: scale.humanPx,
      iso: iso,
    ));
    for (final (i, m) in layout.mobSpawns.indexed) {
      scene.rigged.add(RiggedIsoActor(
        renderer: HumanoidRenderer(HumanoidSpec.generate(100 + i)),
        tile: m,
        height: scale.px(2.0 + (i % 3) * 0.15),
        iso: iso,
      ));
    }

    await dump('village_overview', w, h, (c) {
      c.drawRect(Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
          Paint()..color = const Color(0xFF090D18));
      c.save();
      // 문서용 축소. 게임은 이 줌으로 돌지 않는다 — 배치를 한눈에 보이려는
      // 것뿐이다.
      c.translate(w / 2, 150);
      c.scale(0.30);
      scene.cameraOffset = Offset.zero;
      scene.cullToViewport = false;
      scene.render(c);
      c.restore();
      label(
        c,
        'Village ${kVillageCols}x$kVillageRows m  ·  1 tile = 1 m  ·  '
        '${scene.props.length} props  ·  ${scene.rigged.length} actors\n'
        'Road 3 m wide, 7 buildings 5x5..9x6 m, every doorway reachable.',
        const Offset(26, 24),
        size: 16,
      );
    });
  });
}
