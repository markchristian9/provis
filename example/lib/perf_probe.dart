import 'dart:convert';
import 'dart:io';

import 'package:flutter/scheduler.dart';

/// 프레임 타이밍 기록기 — `flutter run --profile` 에서만 의미가 있다.
///
/// `SchedulerBinding.addTimingsCallback` 이 프레임마다 주는 [FrameTiming] 을
/// 모아 워밍업 구간을 버리고 표본 구간의 통계를 JSON 한 줄로 뱉는다.
///
/// **왜 UI 와 raster 를 따로 보는가.** 두 스레드는 파이프라인으로 겹쳐 돈다.
/// 그래서 프레임 예산을 넘기는 것은 둘의 합이 아니라 **둘 중 긴 쪽**이다.
/// raster 가 길면 `saveLayer`·블러·그리기 명령의 문제이고, build 가 길면
/// Dart 쪽 경로 생성·정렬·할당의 문제다. 어느 쪽인지 모르고 고치면 헛수고다.
///
/// 표본이 끝나면 결과를 stdout 에 찍고 프로세스를 끝낸다 — CI 나 셸에서
/// 그대로 검증 명령으로 쓸 수 있다.
class PerfProbe {
  PerfProbe({
    required this.label,
    this.warmup = const Duration(seconds: 4),
    this.sample = const Duration(seconds: 20),
    this.exitWhenDone = true,
  });

  /// 결과에 함께 찍히는 이름. 어떤 씬·어떤 커밋인지 구분한다.
  final String label;

  /// 버리는 구간. 셰이더 컴파일·맵 생성·첫 레이아웃이 여기 들어간다.
  final Duration warmup;

  /// 실제로 재는 구간.
  final Duration sample;

  /// 표본이 끝나면 프로세스를 끝낼지. 검증 명령으로 쓸 때 켠다.
  final bool exitWhenDone;

  final List<int> _build = [];
  final List<int> _raster = [];
  final List<int> _total = [];

  final Stopwatch _clock = Stopwatch();
  bool _done = false;

  /// 부가 정보 — 창 크기, 액터 수처럼 결과 해석에 필요한 것.
  final Map<String, Object?> context = {};

  void start() {
    _clock.start();
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  void _onTimings(List<FrameTiming> timings) {
    if (_done) return;
    final t = _clock.elapsed;
    if (t < warmup) return;
    if (t >= warmup + sample) {
      _done = true;
      _report();
      return;
    }
    for (final f in timings) {
      _build.add(f.buildDuration.inMicroseconds);
      _raster.add(f.rasterDuration.inMicroseconds);
      _total.add(f.totalSpan.inMicroseconds);
    }
  }

  void _report() {
    final frames = _total.length;
    final elapsedUs = sample.inMicroseconds;
    // 넘긴 프레임까지 세려면 프레임 수를 벽시계로 나눈다. 파이프라인이
    // 막히면 프레임이 아예 배달되지 않으므로 이 값이 진짜 체감 FPS 다.
    final fps = frames == 0 ? 0.0 : frames * 1e6 / elapsedUs;

    var over = 0;
    for (var i = 0; i < frames; i++) {
      if (_build[i] > 16667 || _raster[i] > 16667) over++;
    }
    var jank = 0;
    for (final t in _total) {
      if (t > 33333) jank++;
    }

    final out = <String, Object?>{
      'label': label,
      'frames': frames,
      'sampleSeconds': sample.inMilliseconds / 1000.0,
      'fps': _round(fps),
      'overBudgetFrames': over,
      'overBudgetPct': frames == 0 ? 0.0 : _round(over * 100 / frames),
      'jankFrames': jank,
      'build': _stats(_build),
      'raster': _stats(_raster),
      'total': _stats(_total),
      ...context,
    };

    stdout.writeln('PERF_RESULT ${jsonEncode(out)}');
    stdout.writeln(_human(out));
    if (exitWhenDone) {
      // flush 를 기다렸다가 끝낸다. 바로 exit 하면 마지막 줄이 잘린다.
      Future<void>.delayed(const Duration(milliseconds: 250), () => exit(0));
    }
  }

  static Map<String, Object?> _stats(List<int> v) {
    if (v.isEmpty) return {'p50': 0, 'p90': 0, 'p99': 0, 'max': 0, 'mean': 0};
    final s = [...v]..sort();
    double at(double q) => s[((s.length - 1) * q).round()] / 1000.0;
    final mean = s.reduce((a, b) => a + b) / s.length / 1000.0;
    return {
      'p50': _round(at(0.50)),
      'p90': _round(at(0.90)),
      'p99': _round(at(0.99)),
      'max': _round(s.last / 1000.0),
      'mean': _round(mean),
    };
  }

  static double _round(double v) => (v * 100).roundToDouble() / 100;

  static String _human(Map<String, Object?> o) {
    final b = o['build']! as Map<String, Object?>;
    final r = o['raster']! as Map<String, Object?>;
    final t = o['total']! as Map<String, Object?>;
    String row(String n, Map<String, Object?> m) =>
        '  ${n.padRight(7)} p50 ${m['p50']}ms   p90 ${m['p90']}ms   '
        'p99 ${m['p99']}ms   max ${m['max']}ms';
    return [
      '── ${o['label']} ${'─' * 40}',
      '  fps ${o['fps']}   frames ${o['frames']}   '
          'over-budget ${o['overBudgetPct']}%   jank ${o['jankFrames']}',
      row('build', b),
      row('raster', r),
      row('total', t),
    ].join('\n');
  }
}
