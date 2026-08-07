// 프레임 예산 측정 — 고치기 전에 **먼저 잰다.**
//
// ## 왜 재고 나서 고치는가
//
// 맵이 15×15 에서 40×34 로 커지고 건물이 5배 높아졌다. "느려졌을 것"은
// 추측이고, 추측으로 최적화하면 엉뚱한 곳의 화질을 깎는다. 어디에 시간이
// 가는지 숫자로 본 다음에만 손댄다.
//
// ## 이 테스트가 재는 것과 재지 못하는 것
//
// `flutter test` 는 **소프트웨어 래스터라이저**로 그린다. GPU 가 없으므로
// 절대 시간은 실기의 수십 배가 나온다 — 여기서 나온 600 ms 를 "16 ms 예산
// 초과"라고 읽으면 완전히 틀린 결론이다.
//
// 그래서 이 파일은 **상대 비교만** 한다: 같은 조건에서 컬링을 껐다 켰을 때
// 얼마나 줄어드는가. 절대 프레임 시간(60 FPS 검증)은 실제 GPU 가 도는
// `lib/bench.dart` 를 `flutter run --profile` 로 돌려서 얻는다.
//
//   cd example && flutter run --profile -d macos -t lib/bench.dart

import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provis/provis.dart';

import 'package:provis_example/world/camera.dart';
import 'package:provis_example/world/village.dart';

const iso = IsoView(tileWidth: 150, tileHeight: 75);
const scale = WorldScale(iso: iso);
const mapSeed = 20260806;

/// 대표 해상도. 1080p 창에서 재는 것이 가장 흔한 조건이다.
const viewW = 1600.0, viewH = 900.0;

/// 60 FPS 예산.
const budgetMs = 16.67;

void main() {
  late IsoSceneComponent scene;
  late VillageLayout layout;

  setUp(() {
    scene = IsoSceneComponent(
      iso: iso,
      grid: IsoGrid(cols: kVillageCols, rows: kVillageRows),
      showGrid: false,
    );
    layout = buildVillage(
      scene: scene,
      seed: mapSeed,
      scale: scale,
      mobCount: 6,
    );
  });

  /// 씬을 [frames] 번 그려 프레임당 중앙값(ms)을 돌려준다.
  Future<({double median, double p90, int props})> measure({
    required int frames,
    required bool cull,
  }) async {
    scene.cullToViewport = cull;
    scene.cameraOffset = followCamera(
      iso: iso,
      focusTile: layout.heroSpawn,
      view: const Size(viewW, viewH),
      cols: kVillageCols,
      rows: kVillageRows,
    );
    scene.viewport = const Rect.fromLTWH(0, 0, viewW, viewH);

    final samples = <double>[];
    for (var i = 0; i < frames; i++) {
      final sw = Stopwatch()..start();
      final rec = ui.PictureRecorder();
      final c = Canvas(rec, const Rect.fromLTWH(0, 0, viewW, viewH));
      scene.render(c);
      final pic = rec.endRecording();
      // 래스터까지 돌려야 블러·saveLayer 의 실제 비용이 잡힌다.
      final img = await pic.toImage(viewW.toInt(), viewH.toInt());
      sw.stop();
      samples.add(sw.elapsedMicroseconds / 1000.0);
      img.dispose();
      pic.dispose();
      scene.update(1 / 60);
    }
    samples.sort();
    return (
      median: samples[samples.length ~/ 2],
      p90: samples[(samples.length * 0.9).floor().clamp(0, frames - 1)],
      props: scene.props.length,
    );
  }

  test('컬링 없이 / 컬링 켜고 — 프레임 시간을 비교한다', () async {
    final before = await measure(frames: 24, cull: false);
    final after = await measure(frames: 24, cull: true);

    final b = StringBuffer()
      ..writeln()
      ..writeln('  맵 $kVillageCols×$kVillageRows m  ·  '
          '기물 ${before.props}개  ·  화면 ${viewW.toInt()}×${viewH.toInt()}')
      ..writeln('  예산 ${budgetMs.toStringAsFixed(2)} ms (60 FPS)')
      ..writeln()
      ..writeln('  ${'조건'.padRight(16)}${'중앙값'.padLeft(10)}'
          '${'p90'.padLeft(10)}${'FPS'.padLeft(9)}')
      ..writeln('  ${'─' * 46}')
      ..writeln('  ${'컬링 없음'.padRight(16)}'
          '${'${before.median.toStringAsFixed(2)}ms'.padLeft(10)}'
          '${'${before.p90.toStringAsFixed(2)}ms'.padLeft(10)}'
          '${(1000 / before.median).toStringAsFixed(0).padLeft(9)}')
      ..writeln('  ${'컬링 켬'.padRight(16)}'
          '${'${after.median.toStringAsFixed(2)}ms'.padLeft(10)}'
          '${'${after.p90.toStringAsFixed(2)}ms'.padLeft(10)}'
          '${(1000 / after.median).toStringAsFixed(0).padLeft(9)}')
      ..writeln()
      ..writeln('  개선 ${(before.median / after.median).toStringAsFixed(2)}배');
    // ignore: avoid_print
    print(b);

    expect(after.median, lessThan(budgetMs),
        reason: '컬링을 켜고도 60 FPS 예산을 넘는다 '
            '(${after.median.toStringAsFixed(2)} ms)');
  });

  test('화면 밖 기물은 그리지 않는다', () {
    scene.cullToViewport = true;
    scene.viewport = const Rect.fromLTWH(0, 0, viewW, viewH);
    scene.cameraOffset = followCamera(
      iso: iso,
      focusTile: layout.heroSpawn,
      view: const Size(viewW, viewH),
      cols: kVillageCols,
      rows: kVillageRows,
    );
    final drawn = scene.visiblePropCount();
    expect(drawn, lessThan(scene.props.length),
        reason: '40×34 맵 전체가 1600×900 화면에 들어갈 리 없다');
    // ignore: avoid_print
    print('\n  화면 안 기물 $drawn / 전체 ${scene.props.length}\n');
  });
}
