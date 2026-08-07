import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provis/provis.dart';

import 'package:provis_example/characters/roster.dart';
import 'package:provis_example/world/village.dart';

/// 프레임 예산 실측 — **기기 없이** UI 스레드와 래스터 비용을 갈라서 잰다.
///
/// ## 왜 두 단계로 재는가
///
/// `canvas.drawPath` 는 그리지 않는다. 디스플레이 리스트에 명령을 **적을**
/// 뿐이고, 실제 픽셀은 `Picture.toImage()` 에서 나온다. 그래서 녹화 시간은
/// Dart 쪽 비용(경로 생성·셰이더 생성·정렬·할당)이고, 래스터 시간은 Skia
/// 쪽 비용(블러·클립·그라디언트 채우기)이다.
///
/// 두 스레드는 파이프라인으로 겹쳐 돌기 때문에 프레임 예산을 넘기는 것은
/// 둘의 합이 아니라 **둘 중 긴 쪽**이다. 어느 쪽이 긴지 모르고 고치면 헛수고다.
///
/// ```bash
/// flutter test test/frame_budget_test.dart
/// ```
void main() {
  const iso = IsoView(tileWidth: 150, tileHeight: 75);
  const scale = WorldScale(iso: iso);
  const view = Size(1280, 720);

  /// 게임 맵과 **같은** 씬을 만든다. 벤치가 실제보다 싼 장면을 재면 의미가 없다.
  IsoSceneComponent build() {
    final scene = IsoSceneComponent(
      iso: iso,
      grid: IsoGrid(cols: kVillageCols, rows: kVillageRows),
      light: LightRig.preset(1),
    )..marker = MoveMarker();

    buildVillage(scene: scene, seed: 20260806, scale: scale);

    // 주인공 + 몬스터. 전부 골격 구동이라 매 프레임 관절을 다시 푼다.
    final start = Offset(kVillageCols / 2 + 0.5, kVillageRows / 2 + 2.5);
    scene.rigged.add(
      riggedFromArtist(heroes.first, tile: start, height: 200, iso: iso)
        ..play('walk'),
    );
    for (final (i, m) in monsters.indexed) {
      scene.rigged.add(
        riggedFromArtist(
          m,
          tile: start + Offset(1.5 + i * 1.1, i.isEven ? 1.0 : -1.0),
          height: 215,
          iso: iso,
        )..play('walk'),
      );
    }

    scene.cameraOffset =
        isoCameraOffset(iso, kVillageCols, kVillageRows, view);
    scene.cullToViewport = true;
    scene.viewport =
        Rect.fromLTWH(0, 0, view.width, view.height).inflate(iso.tileWidth);
    return scene;
  }

  /// [frames] 프레임을 돌려 (녹화 ms, 래스터 ms) 중앙값을 낸다.
  Future<(double, double)> measure(
    IsoSceneComponent scene, {
    int frames = 24,
    int warmup = 6,
  }) async {
    final rec = <double>[];
    final ras = <double>[];
    for (var i = 0; i < frames + warmup; i++) {
      scene.update(1 / 60);

      final sw = Stopwatch()..start();
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, Offset.zero & view);
      canvas.drawRect(Offset.zero & view, Paint()..color = const Color(0xFF090D18));
      scene.render(canvas);
      final picture = recorder.endRecording();
      final recordUs = sw.elapsedMicroseconds;

      sw.reset();
      final image = await picture.toImage(view.width.toInt(), view.height.toInt());
      final rasterUs = sw.elapsedMicroseconds;
      image.dispose();
      picture.dispose();

      if (i >= warmup) {
        rec.add(recordUs / 1000);
        ras.add(rasterUs / 1000);
      }
    }
    rec.sort();
    ras.sort();
    return (rec[rec.length ~/ 2], ras[ras.length ~/ 2]);
  }

  testWidgets('대표 장면의 프레임 비용', (tester) async {
    late double record, raster, rawRecord, rawRaster;
    late int props, actors, baked;
    await tester.runAsync(() async {
      // 굽지 않은 기준선. 캐시를 껐을 때 무엇이 드는지 알아야 개선폭이
      // 측정값이 되지 추정이 되지 않는다.
      final raw = build()..propCache = null;
      (rawRecord, rawRaster) = await measure(raw);

      final scene = build();
      props = scene.props.length;
      actors = scene.rigged.length;
      // 굽기는 첫 프레임에 몰린다. 정상 상태를 재려면 먼저 다 구워 둔다.
      await measure(scene, frames: 2, warmup: 2);
      baked = scene.propCache?.length ?? 0;
      (record, raster) = await measure(scene);
    });

    // ignore: avoid_print
    print('FRAME_BUDGET  props=$props rigged=$actors baked=$baked  '
        '${view.width.toInt()}x${view.height.toInt()}\n'
        '  굽기 없음   record ${rawRecord.toStringAsFixed(2)} ms  '
        'raster ${rawRaster.toStringAsFixed(2)} ms\n'
        '  구운 뒤     record ${record.toStringAsFixed(2)} ms  '
        'raster ${raster.toStringAsFixed(2)} ms\n'
        '  ⟶ 예산 16.7ms 대비 '
        '${(100 * (record > raster ? record : raster) / 16.7).toStringAsFixed(0)}%');

    // 60fps 예산은 16.7ms 다. 둘 중 긴 쪽이 이것을 넘으면 프레임이 무너진다.
    // 여유가 필요하므로 12ms 를 상한으로 둔다 — 게임 로직·오디오·위젯이
    // 같은 스레드를 나눠 쓰기 때문이다.
    expect(record, lessThan(12.0), reason: 'UI 스레드가 프레임 예산을 넘는다');
    expect(raster, lessThan(12.0), reason: '래스터가 프레임 예산을 넘는다');
  }, timeout: const Timeout(Duration(minutes: 5)));
}
