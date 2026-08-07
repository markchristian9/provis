import 'package:flutter/material.dart';

import 'strings.dart';

/// 앱이 지원하는 언어.
///
/// 새 언어를 붙이려면 여기에 값을 하나 더하고 [Strings] 의 `_pick` 을 그
/// 언어까지 다루도록 넓히면 된다. 화면 코드는 손대지 않아도 된다.
enum Lang {
  ko('한국어', 'KO'),
  en('English', 'EN');

  const Lang(this.nativeName, this.code);

  /// 그 언어로 적은 언어 이름. 언어 선택은 언제나 그 언어로 읽혀야 한다.
  final String nativeName;

  /// 토글 버튼에 넣을 두 글자.
  final String code;

  Lang get other => this == Lang.ko ? Lang.en : Lang.ko;
}

/// 앱 전역 언어 상태.
///
/// 화면마다 언어를 따로 들고 다니면 게임 맵에 들어갔다 나온 순간 어긋난다.
/// 하나뿐인 값을 [LangScope] 가 위젯 트리에 흘려 준다.
final ValueNotifier<Lang> appLang = ValueNotifier<Lang>(Lang.ko);

/// 언어를 트리 아래로 흘리는 스코프.
///
/// `MaterialApp` **위**에 두어야 `Navigator` 로 밀어 올린 화면까지 닿는다.
/// [InheritedNotifier] 이므로 [appLang] 이 바뀌면 이 값을 읽은 위젯만
/// 다시 그려진다.
class LangScope extends InheritedNotifier<ValueNotifier<Lang>> {
  LangScope({super.key, required super.child}) : super(notifier: appLang);

  /// 현재 언어. 스코프가 없으면 전역 값을 그대로 돌려준다 — 테스트나
  /// 위젯 단독 미리보기에서 트리를 감싸지 않아도 터지지 않는다.
  static Lang of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LangScope>()?.notifier?.value ??
      appLang.value;

  static void use(Lang lang) => appLang.value = lang;

  static void toggle() => appLang.value = appLang.value.other;
}

extension LangContext on BuildContext {
  /// 현재 언어.
  Lang get lang => LangScope.of(this);

  /// 현재 언어의 문자열 묶음. 화면 코드에서는 `context.t.playHint` 처럼 쓴다.
  Strings get t => Strings.of(LangScope.of(this));
}

/// 언어 토글 — `KO | EN` 두 칸짜리 세그먼트.
///
/// 드롭다운을 쓰지 않는 이유는 하나다. 언어가 둘뿐일 때 드롭다운은 두 번
/// 눌러야 하고, 세그먼트는 한 번이면 된다. 그리고 지금 어느 쪽인지가 닫힌
/// 메뉴 안에 숨지 않는다.
class LangToggle extends StatelessWidget {
  const LangToggle({super.key, this.accent = const Color(0xFF57E8FF)});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    final current = context.lang;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final lang in Lang.values)
            _Segment(
              lang: lang,
              on: lang == current,
              accent: accent,
              first: lang == Lang.values.first,
              last: lang == Lang.values.last,
            ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.lang,
    required this.on,
    required this.accent,
    required this.first,
    required this.last,
  });

  final Lang lang;
  final bool on;
  final Color accent;
  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.horizontal(
      left: Radius.circular(first ? 7 : 0),
      right: Radius.circular(last ? 7 : 0),
    );
    return Tooltip(
      message: lang.nativeName,
      child: GestureDetector(
        onTap: () => LangScope.use(lang),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: on ? accent.withValues(alpha: 0.18) : Colors.transparent,
            borderRadius: radius,
          ),
          child: Text(
            lang.code,
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.4,
              fontWeight: on ? FontWeight.w700 : FontWeight.w500,
              color: on ? accent : Colors.white.withValues(alpha: 0.45),
            ),
          ),
        ),
      ),
    );
  }
}
