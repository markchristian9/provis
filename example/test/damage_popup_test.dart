// 피해 숫자 — 규칙을 보이게 하는 장치이므로 규칙처럼 검사한다.
//
// 여기서 지키는 것은 넷이다.
//
// 1. **수명이 초 단위다.** 프레임 수를 세면 120Hz 기기에서 숫자가 두 배로
//    빨리 사라진다. 이 저장소가 애니메이션 전반에서 지키는 규칙과 같다.
// 2. **죽는 타격의 숫자도 남는다.** 몬스터가 사라져도 마지막 한 대의 피해량은
//    읽혀야 한다 — 팝업이 대상에 매여 있으면 그 순간 함께 사라진다.
// 3. **상한이 있다.** 전투가 격해져도 화면이 숫자로 덮이면 안 된다.
// 4. **자리가 흔들리지 않는다.** 같은 프레임을 다시 그렸을 때 숫자가 튀면
//    난수를 프레임마다 굴리고 있다는 뜻이다.

import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:provis/provis.dart';
import 'package:provis_example/combat/damage_popup.dart';

DamagePopup popup({
  Offset tile = const Offset(3, 4),
  int amount = 1,
  bool crit = false,
}) => DamagePopup(
  tile: tile,
  amount: amount,
  crit: crit,
  color: const Color(0xFF57E8FF),
);

void main() {
  group('수명', () {
    test('진행도는 프레임률이 아니라 경과 시간을 따른다', () {
      // 같은 1초를 30fps 와 144fps 로 흘려 보낸다. 남은 수명이 다르면
      // 고사양 기기에서 숫자가 먼저 사라진다.
      final slow = popup();
      for (var i = 0; i < 30; i++) {
        slow.update(1 / 30);
      }
      final fast = popup();
      for (var i = 0; i < 144; i++) {
        fast.update(1 / 144);
      }
      expect((slow.progress - fast.progress).abs(), lessThan(0.01));
    });

    test('수명이 다하면 스스로 끝났다고 알린다', () {
      final p = popup();
      expect(p.update(p.duration * 0.5), isFalse);
      expect(p.done, isFalse);
      expect(p.update(p.duration * 0.6), isTrue);
      expect(p.done, isTrue);
      // 진행도는 1 을 넘지 않는다 — 넘으면 알파·크기 계산이 뒤집힌다.
      p.update(10);
      expect(p.progress, 1.0);
    });

    test('치명타가 보통 타격보다 오래 남는다', () {
      expect(popup(crit: true).duration, greaterThan(popup().duration));
    });
  });

  group('무리', () {
    test('수명이 끝난 숫자는 스스로 빠진다', () {
      final field = DamagePopupField()..add(popup());
      expect(field.length, 1);
      field.update(2.0);
      expect(field.isEmpty, isTrue);
    });

    test('상한을 넘으면 가장 오래된 것부터 버린다', () {
      final field = DamagePopupField();
      for (var i = 0; i < DamagePopupField.maxLive + 12; i++) {
        field.add(popup(tile: Offset(i.toDouble(), 0)));
      }
      expect(field.length, DamagePopupField.maxLive);
    });

    test('맵을 다시 세우면 남은 숫자가 사라진다', () {
      final field = DamagePopupField()
        ..add(popup())
        ..add(popup(amount: 2, crit: true));
      field.clear();
      expect(field.isEmpty, isTrue);
    });
  });

  group('자리', () {
    const iso = IsoView(tileWidth: 150, tileHeight: 75);
    const box = Size(360, 260);

    /// 팝업 하나를 실제로 래스터화해 픽셀로 돌려준다.
    Future<Uint8List> shot(DamagePopup p) async {
      final rec = PictureRecorder();
      final c = Canvas(rec, Offset.zero & box);
      c.drawRect(Offset.zero & box, Paint()..color = const Color(0xFF101520));
      // 타일 (0,0) 이 상자 한가운데 오도록 카메라를 옮긴다.
      p.paint(c, iso, Offset(box.width / 2, box.height * 0.8), PopupFonts());
      final pic = rec.endRecording();
      final img = pic.toImageSync(box.width.toInt(), box.height.toInt());
      pic.dispose();
      final bytes = (await img.toByteData())!.buffer.asUint8List();
      img.dispose();
      return Uint8List.fromList(bytes);
    }

    testWidgets('같은 타격은 언제 만들어도 같은 그림이다', (tester) async {
      // 빗나가는 방향을 난수로 뽑으면 같은 프레임을 다시 그릴 때 숫자가
      // 흔들린다. 자리와 값에서 결정론적으로 나와야 한다.
      await tester.runAsync(() async {
        final a = popup(tile: Offset.zero, amount: 2)..update(0.3);
        final b = popup(tile: Offset.zero, amount: 2)..update(0.3);
        expect(await shot(a), await shot(b));
      });
    });

    testWidgets('자리가 다르면 빗나가는 방향도 다르다', (tester) async {
      // 같은 곳에서 연달아 터진 숫자가 정확히 포개지면 하나로만 읽힌다.
      await tester.runAsync(() async {
        final a = popup(tile: Offset.zero, amount: 1)..update(0.4);
        final b = popup(tile: const Offset(0.3, 0.2), amount: 1)..update(0.4);
        expect(await shot(a), isNot(await shot(b)));
      });
    });

    testWidgets('죽은 몬스터의 숫자도 제 수명을 살고 화면에 남는다', (tester) async {
      // 팝업은 타일 좌표를 **값으로** 들고 있으므로 대상이 사라져도 그려진다.
      await tester.runAsync(() async {
        final p = popup(tile: Offset.zero, amount: 2, crit: true)..update(0.2);
        expect(p.done, isFalse);
        final lit = await shot(p);
        final blank = await shot(popup(tile: Offset.zero)..update(99));
        expect(lit, isNot(blank), reason: '수명이 남았는데 아무것도 안 그렸다');
      });
    });
  });
}
