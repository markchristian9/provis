// 지면 한 겹의 래스터 비용 — 맵을 키웠을 때 무엇이 비싸졌는지 격리해 잰다.
//
// 기물을 컬링해도 프레임이 크게 줄지 않았다(1.26배). 그렇다면 남은 시간은
// 기물이 아닌 곳에 있다. 지면은 컬링 대상이 아니고 **한 장이 화면 전체를
// 덮으므로** 첫 번째 용의자다.
//
// 여기서 확인하는 가설: `paintIsoGround` 의 얼룩 크기가 **맵 전체 크기에
// 비례**한다. 그렇다면 맵을 키운 것만으로 얼룩 하나가 수백 픽셀짜리 블러가
// 되고, 맵 크기와 무관해야 할 "흙이 드러난 자리"가 맵과 함께 자란다.

import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provis/provis.dart';

const iso = IsoView(tileWidth: 150, tileHeight: 75);
const viewW = 1600.0, viewH = 900.0;

Future<double> groundMs(int cols, int rows, {int frames = 8}) async {
  final samples = <double>[];
  for (var i = 0; i < frames; i++) {
    final sw = Stopwatch()..start();
    final rec = ui.PictureRecorder();
    final c = Canvas(rec, const Rect.fromLTWH(0, 0, viewW, viewH));
    // 실제 게임처럼 카메라를 걸고 그린다.
    c.translate(viewW / 2, viewH / 2);
    paintIsoGround(c, iso, cols, rows, LightRig.preset(1), lineAlpha: 0);
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
  test('지면 비용이 맵 크기를 따라 커지는가', () async {
    final small = await groundMs(15, 15);
    final big = await groundMs(40, 34);
    // ignore: avoid_print
    print('\n  지면만 래스터 (1600×900 창)\n'
        '  15×15 맵  ${small.toStringAsFixed(2)} ms\n'
        '  40×34 맵  ${big.toStringAsFixed(2)} ms\n'
        '  배율      ${(big / small).toStringAsFixed(2)}배\n');

    // 화면 크기가 같으므로 지면 비용은 맵 크기와 **무관해야 한다.**
    // 화면에 보이는 땅의 넓이는 창 크기가 정하지 맵 크기가 정하지 않는다.
    expect(big, lessThan(small * 1.6),
        reason: '맵을 키웠다는 이유만으로 지면이 ${(big / small).toStringAsFixed(1)}배 '
            '비싸졌다 — 얼룩 크기가 맵 전체에 비례한다는 뜻이다');
  });
}
