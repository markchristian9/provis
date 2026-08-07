import 'dart:io';

/// 씬 항목별 UI 스레드 비용 집계기 — **임시 진단 도구**.
///
/// `--dart-define=PROVIS_PROFILE=true` 일 때만 켜진다. 꺼져 있으면 [enabled]
/// 가 컴파일 타임 상수 false 이므로 호출부가 통째로 죽은 코드가 되어
/// 릴리스·프로파일 빌드에서 비용이 0 이다.
///
/// 왜 필요한가: 프레임이 느리다는 사실만으로는 무엇을 고칠지 알 수 없다.
/// "기물 114개가 느리다" 와 "나무 22그루가 전체의 70%다" 는 완전히 다른
/// 처방으로 이어진다. 타입별 실측 없이 고치면 안 아픈 곳을 수술하게 된다.
class SceneProfile {
  static const bool enabled =
      bool.fromEnvironment('PROVIS_PROFILE', defaultValue: false);

  static final Map<String, int> _us = {};
  static final Map<String, int> _n = {};
  static int _frames = 0;
  static final Stopwatch _since = Stopwatch()..start();

  static void add(String key, int micros) {
    _us[key] = (_us[key] ?? 0) + micros;
    _n[key] = (_n[key] ?? 0) + 1;
  }

  static void endFrame() {
    _frames++;
    if (_since.elapsed < const Duration(seconds: 6)) return;
    dump();
    _us.clear();
    _n.clear();
    _frames = 0;
    _since.reset();
  }

  static void dump() {
    if (_frames == 0) return;
    final rows = _us.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = _us.values.fold<int>(0, (a, b) => a + b);
    final b = StringBuffer('SCENE_PROFILE frames=$_frames '
        'total=${(total / _frames / 1000).toStringAsFixed(2)}ms/frame\n');
    for (final e in rows) {
      final perFrame = e.value / _frames / 1000;
      final count = _n[e.key]! / _frames;
      b.writeln('  ${e.key.padRight(18)} '
          '${perFrame.toStringAsFixed(2).padLeft(8)} ms/frame  '
          '${count.toStringAsFixed(1).padLeft(6)} draws  '
          '${(e.value / _n[e.key]! / 1000).toStringAsFixed(3)} ms each  '
          '${(e.value * 100 / total).toStringAsFixed(1)}%');
    }
    stdout.write(b.toString());
  }
}
