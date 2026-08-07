import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provis/provis.dart';

import 'characters/roster.dart';
import 'perf_probe.dart';
import 'screens/game_map.dart';

/// 결정적 성능 벤치마크 — 대표 게임플레이의 프레임 타이밍을 실측한다.
///
///   cd example
///   flutter run --profile -d macos -t lib/bench.dart
///
/// 무엇을 재는가: `main.dart` 가 띄우는 것과 **같은** 아이소 필드다. 기물
/// 100여 개, 골격 구동 액터 5구(주인공 + 몬스터 4), 지면·안개·그림자가 전부
/// 켜진 상태. 메뉴나 빈 씬이 아니라 실제로 무거운 장면이다.
///
/// 왜 창을 고정하는가: raster 비용은 픽셀 수에 비례하므로, 창 크기가 매번
/// 다르면 측정값을 비교할 수 없다. 게임 뷰를 고정 크기 상자에 넣어 어느
/// 머신에서 돌려도 같은 픽셀 수를 그리게 한다.
///
/// 왜 합성 탭인가: 주인공이 서 있기만 하면 걷기 클립·IK·망토가 돌지 않아
/// 실제 플레이보다 싼 장면이 된다. 진짜 포인터 이벤트를 넣어 히트테스트부터
/// 경로탐색까지 전부 거치게 한다.
void main() {
  const w = int.fromEnvironment('BENCH_W', defaultValue: 1280);
  const h = int.fromEnvironment('BENCH_H', defaultValue: 720);
  const warmup = int.fromEnvironment('BENCH_WARMUP', defaultValue: 4);
  const sample = int.fromEnvironment('BENCH_SAMPLE', defaultValue: 20);
  const label = String.fromEnvironment('BENCH_LABEL', defaultValue: 'field');

  runApp(BenchApp(
    viewport: const Size(w * 1.0, h * 1.0),
    probe: PerfProbe(
      label: label,
      warmup: Duration(seconds: warmup),
      sample: Duration(seconds: sample),
    ),
  ));
}

class BenchApp extends StatefulWidget {
  const BenchApp({super.key, required this.viewport, required this.probe});

  final Size viewport;
  final PerfProbe probe;

  @override
  State<BenchApp> createState() => _BenchAppState();
}

class _BenchAppState extends State<BenchApp> {
  final GlobalKey _stageKey = GlobalKey();

  /// 주인공은 항상 같은 인물이어야 비교가 성립한다.
  final Artist _hero = heroes.first;

  Timer? _driver;
  int _pointer = 1;
  late final Rng _rng = Rng(1337);

  @override
  void initState() {
    super.initState();
    widget.probe.context
      ..['viewport'] = '${widget.viewport.width.toInt()}'
          'x${widget.viewport.height.toInt()}'
      ..['dpr'] = ui.PlatformDispatcher.instance.views.first.devicePixelRatio
      ..['hero'] = _hero.name
      ..['mobs'] = monsters.length
      ..['mode'] = kProfileMode
          ? 'profile'
          : (kReleaseMode ? 'release' : 'debug');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.probe.start();
      // 주인공을 계속 걷게 한다. 멈춰 있으면 대기 클립만 돌아 실제보다 싸다.
      _driver = Timer.periodic(const Duration(milliseconds: 900), (_) => _tap());
      _tap();
    });
  }

  @override
  void dispose() {
    _driver?.cancel();
    super.dispose();
  }

  /// 게임 영역 안쪽 임의의 점을 실제 포인터 이벤트로 찍는다.
  void _tap() {
    final box = _stageKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final origin = box.localToGlobal(Offset.zero);
    // 가장자리는 지면 밖이라 경로탐색이 즉시 실패한다. 안쪽만 찍는다.
    final p = origin +
        Offset(
          box.size.width * _rng.range(0.28, 0.72),
          box.size.height * _rng.range(0.34, 0.76),
        );
    final id = _pointer++;
    final binding = GestureBinding.instance;
    binding.handlePointerEvent(PointerDownEvent(
      pointer: id,
      position: p,
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryMouseButton,
    ));
    Timer(const Duration(milliseconds: 40), () {
      binding.handlePointerEvent(PointerUpEvent(
        pointer: id,
        position: p,
        kind: PointerDeviceKind.mouse,
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'provis bench',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: ColoredBox(
        color: const Color(0xFF06080F),
        child: Center(
          child: SizedBox(
            key: _stageKey,
            width: widget.viewport.width,
            height: widget.viewport.height,
            child: GameMapScreen(hero: _hero),
          ),
        ),
      ),
    );
  }
}
