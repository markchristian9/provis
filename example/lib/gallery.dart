import 'package:flutter/material.dart';

import 'ui/entry_screen.dart';

/// 캐릭터 선택 화면의 진입점.
///
/// `flutter run -t lib/entry.dart` 로 실행한다.
void main() {
  runApp(const VisEntryApp());
}

class VisEntryApp extends StatelessWidget {
  const VisEntryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vigil Roster',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF05070C),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE8B84B),
          brightness: Brightness.dark,
        ),
        splashFactory: InkSparkle.splashFactory,
      ),
      home: const EntryScreen(),
    );
  }
}
