import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provis/provis.dart';
import 'package:provis_example/characters/roster.dart';
import 'package:provis_example/screens/start_screen.dart';

/// 명부 화면이 캐릭터의 **직업과 성별을 실제로 보여 주는지** 확인한다.
///
/// 카드에서 이 두 정보가 사라져도 앱은 멀쩡히 돌고 테스트도 통과한다 — 그저
/// 명부를 훑는 사람이 역할을 못 읽게 될 뿐이다. 조용히 없어지는 종류의 기능이라
/// 여기서 붙들어 둔다.
void main() {
  testWidgets('명부에 직업과 성별이 표시된다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    await tester.pumpWidget(MaterialApp(
      home: const StartScreen(),
    ));
    await tester.pump(const Duration(milliseconds: 60));

    // 첫 카드의 직업 배지와 성별 기호가 화면에 있어야 한다.
    final a = heroes.first;
    expect(find.text(a.job.label.toUpperCase()), findsWidgets);
    expect(find.text(a.sex!.symbol), findsWidgets);
    expect(find.text(a.name.toUpperCase()), findsOneWidget);
    debugPrint('명부 ${heroes.length}명 · 첫 카드 ${a.name} '
        '${a.job.label} ${a.sex!.symbol}');
  });
}
