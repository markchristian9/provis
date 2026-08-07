@Tags(['sheets'])
library;

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provis/provis.dart';
import 'package:provis_example/characters/roster.dart';

/// 명부 초상과 게임 액터가 **같은 인물로 보이는지** 눈으로 확인하는 시트.
///
/// ## 왜 이 테스트가 있는가
///
/// 실제로 어긋났었다. 명부에서 은발에 파란 로브를 걸친 마법사 Seraphine 을
/// 골랐는데 맵에서는 금발에 하늘색 갑옷을 입은 인물이 걸어 나왔다. 원인은
/// [riggedFromArtist] 가 `Artist` 의 실제 디자인 대신 시드로 새 캐릭터를
/// 만들어 버린 것이었다.
///
/// 이런 종류의 회귀는 컴파일러도 단위 테스트도 잡지 못한다 — 양쪽 다 멀쩡히
/// 돌기 때문이다. **두 그림을 나란히 놓고 사람이 보는 것**만이 검증이 된다.
/// 그래서 자동 판정 대신 시트를 뽑는다.
///
///   flutter test test/identity_sheet_test.dart
///   open build/art/identity_*.png
///
/// ## 무엇을 보는가
///
/// 한 줄이 캐릭터 하나다. 맨 왼쪽이 명부 초상이고 오른쪽 여덟 칸이 게임 맵에서
/// 돌아설 때의 모습이다. 확인할 것:
///
/// - **색이 같은가** — 머리·옷·강조색이 초상과 이어지는가
/// - **장비가 같은가** — 초상이 지팡이면 맵에서도 지팡이인가
/// - **여덟 방향이 다 다른가** — 남쪽은 앞모습, 북쪽은 뒷모습, 동/서는 옆모습
void main() {
  final outDir = Platform.environment['VIS_OUT'] ?? 'build/art';

  const iso = IsoView(tileWidth: 128, tileHeight: 64);
  const cell = Size(150, 210);
  const cols = 9; // 초상 1 + 방향 8

  Future<void> sheet(String name, List<Artist> cast) async {
    final w = (cell.width * cols).round();
    final h = (cell.height * cast.length).round();

    final rec = ui.PictureRecorder();
    final c = Canvas(rec, Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()));
    c.drawRect(
      Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      Paint()..color = const Color(0xFF0A0E16),
    );

    for (var row = 0; row < cast.length; row++) {
      final a = cast[row];
      final top = row * cell.height;

      // ── 왼쪽 칸: 명부 초상 ──────────────────────────────────────────
      final portraitCell =
          Rect.fromLTWH(0, top, cell.width, cell.height).deflate(3);
      c.save();
      c.clipRect(portraitCell);
      c.drawRect(
        portraitCell,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: a.moodSky,
          ).createShader(portraitCell),
      );
      final f = a.framing;
      final k = (portraitCell.height * 0.92 / f.height)
          .clamp(0.0, portraitCell.width * 0.94 / f.width);
      c.translate(portraitCell.center.dx, portraitCell.bottom - 6);
      c.scale(k);
      c.translate(-f.center.dx, -f.bottom);
      a.paint(c, 0.7);
      c.restore();
      c.drawRect(
        portraitCell,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = a.accent.withValues(alpha: 0.55),
      );

      // ── 오른쪽 여덟 칸: 게임 액터가 한 바퀴 돈다 ────────────────────
      //
      // 매 칸 새 액터를 만드는 것은 낭비처럼 보이지만, 이 시트가 검증하려는
      // 것이 바로 `riggedFromArtist` 자체다. 재사용하면 그 변환을 한 번밖에
      // 안 거치게 되어 검증 범위가 줄어든다.
      for (var d = 0; d < 8; d++) {
        final yaw = d * math.pi / 4;
        final rect = Rect.fromLTWH(
          (d + 1) * cell.width,
          top,
          cell.width,
          cell.height,
        ).deflate(3);

        final actor = riggedFromArtist(a, tile: Offset.zero, height: 150)
          ..yaw = yaw
          ..play('walk')
          ..update(0.42); // 보폭이 가장 벌어진 순간

        c.save();
        c.clipRect(rect);
        c.drawRect(rect, Paint()..color = const Color(0xFF141A26));
        c.translate(rect.center.dx, rect.bottom - 22);
        paintRiggedActor(c, actor, iso, a.light, 0.7);
        c.restore();
        c.drawRect(
          rect,
          Paint()
            ..style = PaintingStyle.stroke
            ..color = const Color(0x11FFFFFF),
        );
      }
    }

    final img = await rec.endRecording().toImage(w, h);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$outDir/$name.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(data!.buffer.asUint8List());
    // ignore: avoid_print
    print('wrote ${file.path} (${w}x$h)');
  }

  test('간판 캐릭터의 초상과 게임 액터를 나란히 뽑는다', () async {
    await sheet('identity_signature', signatureHeroes);
  });

  test('선언으로 만든 캐릭터를 나란히 뽑는다', () async {
    await sheet('identity_recruits_a', recruits.sublist(0, 10));
    await sheet('identity_recruits_b', recruits.sublist(10));
  });

  test('몬스터를 나란히 뽑는다', () async {
    await sheet('identity_monsters', monsters);
  });

  test('모든 캐릭터가 build 를 통해 자기 색을 게임 액터로 넘긴다', () {
    // 시트는 사람이 보지만, 이것만은 기계가 잡을 수 있다 — `build` 가
    // 팔레트를 비워 두면 게임 액터의 색이 시드에서 나오므로 초상과 어긋난다.
    for (final a in everyone) {
      expect(
        a.build.palette,
        isNotNull,
        reason: '${a.id} 가 build.palette 를 선언하지 않았다 — '
            '게임 맵에서 다른 색으로 나타난다',
      );
    }
  });
}
