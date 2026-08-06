import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provis/provis.dart';
import 'package:provis_example/characters/roster.dart';

/// 캐릭터 하나를 여러 각도로 뜯어보는 검증 시트.
///
///   flutter test test/artist_test.dart
///
/// [render_sheet_test.dart] 가 명부 전원을 굽는 데 반해 이쪽은 작업 중인
/// 캐릭터 하나만 굽는다. 저작 루프에서는 왕복 시간이 곧 품질이기 때문이다.
/// 셰이딩보다 실루엣이 먼저이므로 전신 컷과 함께 (1) 검게 칠한 실루엣,
/// (2) 64px 축소본을 같이 굽는다. 셋 중 하나에서 정체가 읽히지 않으면
/// 셰이딩이 아니라 형상을 고쳐야 한다는 뜻이다.
void main() {
  const target = 'vesper';
  const out = 'build/artists';

  Future<void> dump(String name, int w, int h, void Function(Canvas) body) async {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec, Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()));
    body(c);
    final img = await rec.endRecording().toImage(w, h);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$out/$name.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(data!.buffer.asUint8List());
  }

  void place(Canvas c, Artist a, Rect cell, double t, {double detail = 1.0}) {
    final scale = cell.height * 0.94 / kStage.height;
    c.save();
    c.translate(cell.center.dx, cell.bottom - cell.height * 0.03);
    c.scale(scale);
    c.translate(-kStage.width / 2, -kGround);
    a.paint(c, t, detail: detail);
    c.restore();
  }

  final a = everyone.firstWhere((x) => x.id == target);

  testWidgets('전신 — 두 시점', (tester) async {
    await tester.runAsync(() async {
      for (final (i, t) in [1.4, 3.9].indexed) {
        await dump('${target}_full$i', 900, 1260, (c) {
          c.drawRect(
            const Rect.fromLTWH(0, 0, 900, 1260),
            Paint()
              ..shader = LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: a.moodSky,
              ).createShader(const Rect.fromLTWH(0, 0, 900, 1260)),
          );
          place(c, a, const Rect.fromLTWH(0, 0, 900, 1260), t);
        });
      }
      });
});

  testWidgets('얼굴 클로즈업', (tester) async {
    await tester.runAsync(() async {
      // 눈·입 같은 미세 디테일은 전신 컷에서 확인할 수 없다.
      const f = Rect.fromLTWH(330, 180, 400, 400);
      await dump('${target}_face', 620, 620, (c) {
        c.drawRect(
          const Rect.fromLTWH(0, 0, 620, 620),
          Paint()..color = a.moodSky.first,
        );
        c.save();
        c.scale(620 / f.width);
        c.translate(-f.left, -f.top);
        a.paint(c, 1.4);
        c.restore();
      });
      });
});

  testWidgets('실루엣 — 검게 칠했을 때 정체가 읽히는가', (tester) async {
    await tester.runAsync(() async {
      const cw = 300.0;
      const h = 420.0;
      final w = cw * heroes.length;
      await dump('silhouette', w.toInt(), h.toInt(), (c) {
        final full = Rect.fromLTWH(0, 0, w, h);
        c.drawRect(full, Paint()..color = const Color(0xFFE6ECF5));
        for (var i = 0; i < heroes.length; i++) {
          c.saveLayer(full, Paint());
          place(c, heroes[i], Rect.fromLTWH(cw * i, 0, cw, h), 1.4, detail: 0.2);
          c.drawRect(
            full,
            Paint()
              ..blendMode = BlendMode.srcIn
              ..color = const Color(0xFF12161C),
          );
          c.restore();
        }
      });
      });
});

  testWidgets('게임 크기 — 64px 로 줄여도 구분되는가', (tester) async {
    await tester.runAsync(() async {
      const cell = 72.0;
      const h = 104.0;
      final w = cell * heroes.length;
      await dump('tiny', w.toInt(), h.toInt(), (c) {
        c.drawRect(
          Rect.fromLTWH(0, 0, w, h),
          Paint()..color = const Color(0xFF141A26),
        );
        for (var i = 0; i < heroes.length; i++) {
          place(c, heroes[i], Rect.fromLTWH(cell * i, 0, cell, h), 1.4,
              detail: 0.2);
        }
      });
      });
});
}
