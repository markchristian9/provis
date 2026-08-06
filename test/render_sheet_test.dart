import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vis/src/art/creature.dart';
import 'package:vis/src/art/roster.dart';

/// 캐릭터를 PNG 로 덤프하는 도구.
///
/// 절차적 아트는 코드를 읽어서는 결과를 알 수 없다. 실제로 래스터화해 눈으로
/// 봐야만 검증이 되므로, 앱을 띄우지 않고도 전원을 한 장에 뽑을 수 있게
/// 해 두었다. 출력 경로는 `VIS_OUT` 환경 변수로 바꾼다.
///
///   flutter test test/render_sheet_test.dart
void main() {
  final outDir = Platform.environment['VIS_OUT'] ?? 'build/art';

  Future<void> dump(String name, int w, int h, void Function(Canvas) body) async {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec, Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()));
    c.drawRect(
      Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      Paint()..color = const Color(0xFF0A0E16),
    );
    body(c);
    final img = await rec.endRecording().toImage(w, h);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$outDir/$name.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(data!.buffer.asUint8List());
    // ignore: avoid_print
    print('wrote ${file.path} (${w}x$h)');
  }

  void drawOne(Canvas c, Artist a, Rect cell, double t) {
    final f = a.framing;
    final scale = (cell.height * 0.94 / f.height)
        .clamp(0.0, cell.width * 0.98 / f.width);
    c.save();
    c.clipRect(cell);
    // 캐릭터별 무드로 셀 배경을 깔아 실루엣 대비를 확인한다.
    c.drawRect(
      cell,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: a.moodSky,
        ).createShader(cell),
    );
    c.translate(cell.center.dx, cell.bottom - cell.height * 0.03);
    c.scale(scale);
    c.translate(-f.center.dx, -f.bottom);
    a.paint(c, t);
    c.restore();
    c.drawRect(
      cell.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = a.accent.withValues(alpha: 0.55),
    );
  }

  testWidgets('전체 캐릭터 시트를 렌더한다', (tester) async {
    const cw = 620.0;
    const ch = 880.0;
    const cols = 4;
    final rows = (everyone.length + cols - 1) ~/ cols;
    await dump('sheet_all', (cw * cols).toInt(), (ch * rows).toInt(), (c) {
      for (var i = 0; i < everyone.length; i++) {
        final col = i % cols;
        final row = i ~/ cols;
        drawOne(
          c,
          everyone[i],
          Rect.fromLTWH(col * cw, row * ch, cw, ch),
          1.7 + i * 0.4,
        );
      }
    });
  });

  testWidgets('캐릭터별 고해상도 개별 컷을 렌더한다', (tester) async {
    for (final a in everyone) {
      await dump('solo_${a.id}', 900, 1260, (c) {
        drawOne(c, a, const Rect.fromLTWH(0, 0, 900, 1260), 2.3);
      });
    }
  });

  testWidgets('얼굴 클로즈업을 렌더한다', (tester) async {
    // 눈·입 같은 미세 디테일은 전신 컷에서 확인할 수 없다.
    const faces = <String, Rect>{
      'aldric': Rect.fromLTWH(330, 200, 340, 340),
      'kaelen': Rect.fromLTWH(300, 250, 340, 340),
      'seraphine': Rect.fromLTWH(330, 190, 340, 340),
      'lyra': Rect.fromLTWH(360, 200, 340, 340),
      'vesper': Rect.fromLTWH(360, 190, 320, 320),
      'gorehide': Rect.fromLTWH(340, 380, 360, 360),
      'vaelmorth': Rect.fromLTWH(100, 280, 420, 420),
      'mourne': Rect.fromLTWH(330, 180, 360, 360),
      'chitinis': Rect.fromLTWH(160, 690, 400, 400),
    };
    for (final a in everyone) {
      // 명부는 다른 작업자도 건드리므로, 좌표를 등록하지 않은 캐릭터는 건너뛴다.
      final f = faces[a.id];
      if (f == null) continue;
      await dump('face_${a.id}', 560, 560, (c) {
        c.save();
        c.scale(560 / f.width);
        c.translate(-f.left, -f.top);
        a.paint(c, 2.3);
        c.restore();
      });
    }
  });
}
