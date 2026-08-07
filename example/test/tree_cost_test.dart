// 나무 한 그루의 비용 — 크기에 따라 어떻게 변하는가.
//
// 실측(`bench.dart`, PROVIS_PROFILE=true)에서 `TreeProp` 이 씬 빌드 시간의
// **82%** 를 먹었다. 그루당 11.6~12.9 ms 로, 한 그루가 60 FPS 예산(16.67 ms)을
// 거의 통째로 쓴다.
//
// 고치기 전에 알아야 할 것: 이게 **스케일 교정 때문에 생긴 회귀**인가, 아니면
// 원래 비쌌는데 나무가 작아서 가려져 있었을 뿐인가. 둘은 처방이 다르다.
// 전자면 크기 의존 비용을 잘라야 하고, 후자면 나무 렌더 자체를 손봐야 한다.

import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provis/provis.dart';

const iso = IsoView(tileWidth: 150, tileHeight: 75);
const viewW = 1200.0, viewH = 900.0;

Future<double> treeMs(double trunkHeight, {int frames = 6}) async {
  final tree = TreeProp(seed: 11, trunkHeight: trunkHeight);
  final samples = <double>[];
  for (var i = 0; i < frames; i++) {
    final sw = Stopwatch()..start();
    final rec = ui.PictureRecorder();
    final c = Canvas(rec, const Rect.fromLTWH(0, 0, viewW, viewH));
    c.translate(viewW / 2, viewH * 0.85);
    tree.paint(c, 1.2 + i * 0.1, LightRig.preset(1));
    final pic = rec.endRecording();
    final img = await pic.toImage(viewW.toInt(), viewH.toInt());
    sw.stop();
    samples.add(sw.elapsedMicroseconds / 1000.0);
    img.dispose();
    pic.dispose();
  }
  samples.sort();
  return samples[samples.length ~/ 2];
}

void main() {
  test('나무 비용이 크기를 따라 어떻게 자라는가', () async {
    // 고치기 전 게임 맵의 나무: baseHeight 150 → 총 키 약 3.0 m.
    final small = await treeMs(150);
    // 지금: kTreeTrunkM 4.2 m → 445 px → 총 키 약 9.8 m.
    final big = await treeMs(445);

    // ignore: avoid_print
    print('\n  나무 한 그루 래스터 (1200×900)\n'
        '  밑동 150 px (총 3.0 m)   ${small.toStringAsFixed(2)} ms\n'
        '  밑동 445 px (총 9.8 m)   ${big.toStringAsFixed(2)} ms\n'
        '  배율                     ${(big / small).toStringAsFixed(2)}배\n'
        '  선형 배율 2.97배 대비    ${(big / small / 2.97).toStringAsFixed(2)}\n');

    // 비용이 면적(선형²≈8.8배)보다 심하게 자라면 크기 의존 항이 따로 있다는 뜻.
    expect(big / small, lessThan(12.0),
        reason: '나무 비용이 면적 증가보다 훨씬 빠르게 자란다');
  });
}
