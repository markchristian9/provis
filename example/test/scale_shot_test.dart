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

/// 텍스트 대신 **눈금자**를 그린다.
///
/// `flutter test` 의 렌더러에는 폰트가 실려 있지 않아 어떤 글자를 넣어도
/// 두부(□)로 나온다 — ASCII 도 마찬가지다. 그래서 설명은 벡터로 그린다.
/// 어차피 스케일을 말하는 데는 글자보다 눈금이 정확하다.
///
/// [zoom] 은 그림에 걸린 축소율, [metres] 는 눈금 개수다.
void ruler(Canvas c, Offset at, double zoom, int metres, Color color) {
  // 화면에서 1 m 가 차지하는 세로 픽셀 = pxPerMeter × squash × zoom.
  final unit = scale.pxPerMeter * iso.squash * zoom;
  final p = Paint()
    ..color = color
    ..strokeWidth = 2
    ..isAntiAlias = true;
  c.drawLine(at, at.translate(0, -unit * metres), p);
  for (var i = 0; i <= metres; i++) {
    final y = at.dy - unit * i;
    // 매 미터마다 짧은 눈금, 5 m 마다 길게.
    final len = i % 5 == 0 ? 18.0 : 9.0;
    c.drawLine(Offset(at.dx, y), Offset(at.dx + len, y), p);
  }
}

/// 칸을 구분하는 색 띠. 어느 쪽이 전/후인지 글자 없이 알린다.
void banner(Canvas c, Rect box, Color color) {
  c.drawRect(box, Paint()..color = color);
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
    const zoom = 0.30;

    await dump('before_after', w, h, (c) {
      c.drawRect(Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
          Paint()..color = const Color(0xFF090D18));

      for (final (side, isBefore) in [(0.0, true), (780.0, false)]) {
        c.save();
        c.clipRect(Rect.fromLTWH(side, 0, 780, h.toDouble()));
        c.translate(side + 300, 700);
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

        // 같은 눈금자를 두 칸에 똑같이 세운다. 기물만 달라졌다는 사실이
        // 눈금 대비 높이로 즉시 보인다.
        ruler(c, Offset(side + 60, 760), zoom, 10,
            isBefore ? const Color(0xFFFF9B9B) : const Color(0xFF9BFFC4));
        banner(c, Rect.fromLTWH(side, 0, 780, 10),
            isBefore ? const Color(0xFFFF5A5A) : const Color(0xFF3FD98A));
      }

      c.drawLine(const Offset(780, 0), Offset(780, h.toDouble()),
          Paint()..color = const Color(0x33FFFFFF));
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

      ruler(c, const Offset(60, 770), 0.62, 4, const Color(0xFF9BFFC4));
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
    });
  });
}
