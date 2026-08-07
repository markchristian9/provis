@Tags(['sheets'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provis/provis.dart';

/// 굽는다고 그림이 달라지면 안 된다.
///
/// [PropCache] 는 기물을 한 번 그려 텍스처로 만들고 이후엔 그것만 그린다.
/// 속도를 위해 그림을 바꾸는 것은 거래가 아니라 회귀이므로, 구운 것과 굽지
/// 않은 것을 **픽셀로 대조**한다.
///
/// 나무는 예외적으로 완전히 같지 않다 — 바람을 잎 덩어리마다가 아니라 밑동
/// 전단으로 주므로 잎의 위상차가 사라진다. 그래서 나무는 `t = 0`(구운 자세)
/// 에서만 대조한다. 그 시점에서는 두 경로가 같은 그림이어야 한다.
void main() {
  const iso = IsoView(tileWidth: 150, tileHeight: 75);
  const light = LightRig.dusk;
  // 건물은 국소 좌표에서 500px 이 넘는다. 상자가 작으면 굴뚝과 연기가
  // 화면 밖으로 나가 '아무 차이 없음' 이 되어 버린다.
  const box = Size(620, 780);

  Future<ui.Image> shot(PropInstance it, {PropCache? cache, double t = 0}) async {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec, Offset.zero & box);
    c.drawRect(Offset.zero & box, Paint()..color = const Color(0xFF10141F));
    c.translate(box.width / 2, box.height * 0.94);
    // paintProp 은 타일 좌표를 투영하므로 원점 타일을 쓰고 위에서 옮겨 둔다.
    paintProp(c, it, iso, light, t, cache: cache);
    return rec.endRecording().toImage(box.width.toInt(), box.height.toInt());
  }

  /// 두 이미지의 평균 채널 차이(0..255).
  Future<double> diff(ui.Image a, ui.Image b) async {
    final da = (await a.toByteData())!.buffer.asUint8List();
    final db = (await b.toByteData())!.buffer.asUint8List();
    expect(da.length, db.length);
    var sum = 0;
    for (var i = 0; i < da.length; i++) {
      sum += (da[i] - db[i]).abs();
    }
    return sum / da.length;
  }

  final subjects = <String, Prop>{
    'tree': TreeProp(seed: 7, kind: TreeKind.broadleaf, trunkHeight: 120),
    'conifer': TreeProp(seed: 11, kind: TreeKind.conifer, trunkHeight: 130),
    'rock': RockProp(seed: 3, size: 52, mossy: true),
    'stump': StumpProp(seed: 5, size: 30, isoRatio: iso.elevationSin),
    'log': LogProp(seed: 9, length: 120, isoRatio: iso.elevationSin),
    'building': BuildingProp(
      seed: 13,
      tiles: const Size(1, 1),
      storeys: 1,
      tileWidth: iso.tileWidth,
      isoRatio: iso.elevationSin,
    ),
    'wall': WallProp(
      seed: 17,
      tileWidth: iso.tileWidth,
      isoRatio: iso.elevationSin,
    ),
    'pebbles': PebbleField(seed: 19, radius: 70),
  };

  testWidgets('구운 기물이 굽지 않은 것과 같은 그림이다', (tester) async {
    final report = StringBuffer();
    await tester.runAsync(() async {
      for (final (name, prop) in subjects.entries.map((e) => (e.key, e.value))) {
        expect(prop.bakeable, isTrue, reason: '$name 은 구울 수 있어야 한다');
        final it = PropInstance(prop: prop, tile: Offset.zero);
        final cache = PropCache();

        final plain = await shot(it);
        final baked = await shot(it, cache: cache);
        final d = await diff(plain, baked);
        report.writeln('  ${name.padRight(10)} 평균 차이 ${d.toStringAsFixed(3)}');

        // 텍스처를 한 번 거치므로 리샘플링 오차가 조금 생긴다. 눈에 보이는
        // 차이(색이 바뀌거나 파츠가 사라지는 것)는 이보다 훨씬 크게 나온다.
        expect(d, lessThan(3.0), reason: '$name 이 구운 뒤 달라졌다');
        plain.dispose();
        baked.dispose();
        cache.clear();
      }
    });
    // ignore: avoid_print
    print('BAKE_FIDELITY\n$report');
  }, timeout: const Timeout(Duration(minutes: 4)));

  testWidgets('구운 나무도 바람에 흔들린다', (tester) async {
    await tester.runAsync(() async {
      final prop = TreeProp(seed: 7, kind: TreeKind.broadleaf, trunkHeight: 120);
      final it = PropInstance(prop: prop, tile: Offset.zero);
      final cache = PropCache();

      final atRest = await shot(it, cache: cache, t: 0);
      final blown = await shot(it, cache: cache, t: 1.7);
      final moved = await diff(atRest, blown);

      // 움직이지 않으면 굽기가 나무를 얼려 버린 것이다.
      expect(moved, greaterThan(0.15), reason: '구운 나무가 얼어붙었다');
      atRest.dispose();
      blown.dispose();
      cache.clear();
    });
  }, timeout: const Timeout(Duration(minutes: 4)));

  testWidgets('굴뚝 연기는 구운 뒤에도 살아 있다', (tester) async {
    await tester.runAsync(() async {
      final prop = BuildingProp(
        seed: 13,
        tiles: const Size(1, 1),
        storeys: 1,
        tileWidth: iso.tileWidth,
        isoRatio: iso.elevationSin,
      );
      final it = PropInstance(prop: prop, tile: Offset.zero);
      final cache = PropCache();

      final a = await shot(it, cache: cache, t: 0.2);
      final b = await shot(it, cache: cache, t: 2.9);
      // 연기가 구워져 버렸다면 두 프레임이 완전히 같다.
      expect(await diff(a, b), greaterThan(0.005), reason: '연기가 얼어붙었다');
      a.dispose();
      b.dispose();
      cache.clear();
    });
  }, timeout: const Timeout(Duration(minutes: 4)));

  testWidgets('광원이 바뀌면 구운 것을 버린다', (tester) async {
    await tester.runAsync(() async {
      // 구운 그림에는 조명이 이미 칠해져 있다. 안 버리면 정오의 나무가
      // 달빛 씬에 그대로 서 있게 된다.
      final prop = RockProp(seed: 3, size: 52);
      final cache = PropCache();
      expect(cache.of(prop, LightRig.daylight, 1.0), isNotNull);
      expect(cache.length, 1);
      expect(cache.of(prop, LightRig.moonlit, 1.0), isNotNull);
      expect(cache.length, 1, reason: '낡은 텍스처가 남아 있으면 안 된다');
      cache.clear();
      expect(cache.length, 0);
    });
  });

  tearDownAll(() {
    // 눈으로도 한 번 보라고 시트를 남긴다.
    Directory('build/art').createSync(recursive: true);
  });
}
