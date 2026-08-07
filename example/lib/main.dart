import 'package:flutter/material.dart';

import 'i18n/lang.dart';
import 'screens/opening_screen.dart';

/// provis 데모.
///
///   flutter run -t lib/main.dart
///
/// 흐름: 오프닝 → 명부(캐릭터 | 몬스터 탭) → 캐릭터 선택 → 게임 맵 입장 →
/// 클릭 이동 → (쓰러지면) 게임오버.
///
/// 보여 주는 것:
/// - 절차적 맵 기물 (나무·바위·건물·담장·물웅덩이·길·풀)
/// - 8방향 회전과 보행 애니메이션 — 북쪽은 뒷모습, 남쪽은 앞모습
/// - 기물과 캐릭터가 **하나의 깊이 정렬**을 거친다
/// - 조명 프리셋을 바꾸면 화면 전체가 한꺼번에 반응한다
/// - 한국어 · English 를 화면 어디서나 한 번에 전환한다
void main() {
  runApp(const ProvisDemoApp());
}

class ProvisDemoApp extends StatelessWidget {
  const ProvisDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    // LangScope 는 MaterialApp **위**에 둔다. Navigator 가 밀어 올린 게임 맵도
    // 같은 언어를 봐야 하므로, 라우트보다 위에 있어야 한다.
    return LangScope(
      child: MaterialApp(
        title: 'provis',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(useMaterial3: true),
        home: const OpeningScreen(),
      ),
    );
  }
}
