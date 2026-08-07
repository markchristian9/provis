import 'package:flutter/gestures.dart' show kDoubleTapMinTime;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provis/provis.dart';
import 'package:provis_example/characters/roster.dart';
import 'package:provis_example/i18n/character_text.dart';
import 'package:provis_example/i18n/lang.dart';
import 'package:provis_example/i18n/strings.dart';
import 'package:provis_example/screens/start_screen.dart';

/// 명부 화면이 캐릭터의 **직업과 성별을 실제로 보여 주는지**, 그리고 **언어
/// 전환이 화면까지 닿는지** 확인한다.
///
/// 둘 다 조용히 없어지는 종류의 기능이다. 직업 배지가 사라져도 앱은 멀쩡히
/// 돌고, 언어 토글이 상태만 바꾸고 화면을 다시 그리지 않아도 예외 하나 나지
/// 않는다 — 그저 명부를 훑는 사람이 역할을 못 읽고, 영어를 골라도 한국어가
/// 그대로 남을 뿐이다. 여기서 붙들어 둔다.
/// 라우트가 몇 장 쌓였는지 센다. 맵으로 넘어갔는지 확인하는 가장 확실한 자다 —
/// 화면을 실제로 띄우지 않고도 알 수 있다.
class _PushLog extends NavigatorObserver {
  int count = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previous) => count++;
}

void main() {
  setUp(() => LangScope.use(Lang.ko));
  tearDown(() => LangScope.use(Lang.ko));

  Future<void> pumpRoster(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    await tester.pumpWidget(LangScope(
      child: const MaterialApp(home: StartScreen()),
    ));
    await tester.pump(const Duration(milliseconds: 60));
  }

  testWidgets('명부에 직업과 성별이 표시된다', (tester) async {
    await pumpRoster(tester);

    // 첫 카드의 직업 배지와 성별 기호가 화면에 있어야 한다.
    final a = heroes.first;
    expect(find.text(Strings.ko.job(a.job).toUpperCase()), findsWidgets);
    expect(find.text(a.sex!.symbol), findsWidgets);
    expect(find.text(a.name.toUpperCase()), findsWidgets);
    debugPrint('명부 ${heroes.length}명 · 첫 카드 ${a.name} '
        '${Strings.ko.job(a.job)} ${a.sex!.symbol}');
  });

  testWidgets('EN 을 누르면 화면이 영어로 바뀐다', (tester) async {
    await pumpRoster(tester);

    final job = heroes.first.job;
    expect(find.text(Strings.ko.job(job).toUpperCase()), findsWidgets);
    expect(find.text(Strings.ko.tagline), findsOneWidget);

    await tester.tap(find.text(Lang.en.code));
    await tester.pump();

    expect(find.text(Strings.en.job(job).toUpperCase()), findsWidgets);
    expect(find.text(Strings.en.tagline), findsOneWidget);
    expect(find.text(Strings.ko.tagline), findsNothing);

    // 되돌아오는 길도 있어야 한다.
    await tester.tap(find.text(Lang.ko.code));
    await tester.pump();
    expect(find.text(Strings.ko.tagline), findsOneWidget);
  });

  testWidgets('칸을 고르면 스테이지가 그 인물로 바뀐다', (tester) async {
    await pumpRoster(tester);

    // 소개문은 스테이지에만 있다 — 무대에 누가 서 있는지 가리키는 표식이다.
    expect(find.text(heroes.first.blurbIn(Lang.ko)), findsOneWidget);

    final other = heroes[3];
    await tester.tap(find.byKey(ValueKey('tile-${other.id}')));
    await tester.pump(const Duration(milliseconds: 60));

    expect(find.text(other.blurbIn(Lang.ko)), findsOneWidget);
    expect(find.text(heroes.first.blurbIn(Lang.ko)), findsNothing);

    // 스테이지의 장비는 게임 맵이 세울 명세에서 읽는다. 배선이 끊기면
    // 명부는 검을 보여 주고 맵에서는 다른 것이 나온다.
    final spec =
        other.build.toSpec(Rng.fromString(other.id).intRange(1, 0x7FFFFFF));
    expect(find.text(Strings.ko.weapon(spec.weapon).toUpperCase()), findsWidgets);
  });

  testWidgets('직업 필터가 명부를 좁힌다', (tester) async {
    await pumpRoster(tester);

    const job = Archetype.mage;
    final mages = heroes.where((a) => a.job == job).toList();
    expect(mages, isNotEmpty, reason: '마법사가 하나도 없으면 이 검사는 무의미하다');

    await tester.tap(find.text('${Strings.ko.job(job)}  ${mages.length}'));
    await tester.pump(const Duration(milliseconds: 60));

    for (final a in mages) {
      expect(find.byKey(ValueKey('tile-${a.id}')), findsOneWidget,
          reason: '${a.id} 이(가) 필터에서 빠졌다');
    }
    final other = heroes.firstWhere((a) => a.job != job);
    expect(find.byKey(ValueKey('tile-${other.id}')), findsNothing);
  });

  testWidgets('몬스터는 미리 볼 수만 있고 맵에는 못 들어간다', (tester) async {
    final pushes = _PushLog();
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    await tester.pumpWidget(LangScope(
      child: MaterialApp(
        navigatorObservers: [pushes],
        home: const StartScreen(),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 60));
    expect(find.text(Strings.ko.monsterLocked), findsNothing);

    await tester.tap(find.text(Strings.ko.monstersTab(monsters.length)));
    await tester.pump(const Duration(milliseconds: 60));

    final m = monsters.first;
    expect(find.text(m.name.toUpperCase()), findsWidgets);
    expect(find.text(Strings.ko.monsterLocked), findsOneWidget);

    // 두 번 눌러도 맵으로 넘어가지 않는다 — 몬스터는 조작 대상이 아니다.
    final tile = find.byKey(ValueKey('tile-${m.id}'));
    await tester.tap(tile);
    await tester.pump(kDoubleTapMinTime);
    await tester.tap(tile);
    await tester.pump(const Duration(milliseconds: 60));
    expect(pushes.count, 1, reason: '명부 화면 하나만 떠 있어야 한다');
  });

  testWidgets('좁은 화면에서는 스테이지가 띠로 접힌다', (tester) async {
    // 넘침(overflow)은 테스트에서 예외로 터진다. 세로 화면에서 스테이지가
    // 명부를 밀어내지 않는지 여기서 붙든다.
    await tester.binding.setSurfaceSize(const Size(420, 780));
    await tester.pumpWidget(LangScope(
      child: const MaterialApp(home: StartScreen()),
    ));
    await tester.pump(const Duration(milliseconds: 60));

    expect(find.text(heroes.first.name.toUpperCase()), findsWidgets);
    expect(find.byKey(ValueKey('tile-${heroes.first.id}')), findsOneWidget);
    expect(find.text(Strings.ko.enterMap), findsOneWidget);
    // 좁으면 소개문은 접는다 — 이름과 장비가 먼저다.
    expect(find.text(heroes.first.blurbIn(Lang.ko)), findsNothing);

    await tester.binding.setSurfaceSize(const Size(1400, 1000));
  });

  testWidgets('칭호와 소개가 두 언어를 모두 갖는다', (tester) async {
    // 표에서 빠진 캐릭터는 화면에 원문이 그대로 나온다 — 한국어를 골랐는데
    // 영어 칭호가 섞이는 식이다. 명부에 세운 전원을 훑는다.
    for (final a in everyone) {
      expect(a.titleIn(Lang.ko), isNotEmpty, reason: '${a.id} 칭호(ko)');
      expect(a.titleIn(Lang.en), isNotEmpty, reason: '${a.id} 칭호(en)');
      expect(a.titleIn(Lang.ko), isNot(a.titleIn(Lang.en)),
          reason: '${a.id} 칭호가 번역되지 않았다');
      expect(a.blurbIn(Lang.ko), isNot(a.blurbIn(Lang.en)),
          reason: '${a.id} 소개가 번역되지 않았다');
    }
    debugPrint('번역 확인 ${everyone.length}명');
  });
}
