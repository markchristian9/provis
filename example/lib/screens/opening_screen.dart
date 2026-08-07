import 'dart:math' as math;
// material 의 Gradient(위젯용 데코레이션)가 dart:ui 의 Gradient(셰이더
// 생성기)를 가린다. 여기서는 캔버스에 직접 셰이더를 만들므로 후자가 필요하다.
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Colors;
import 'package:flutter/material.dart' as m show Colors;
import 'package:provis/provis.dart';

import '../characters/roster.dart';
import '../i18n/lang.dart';
import 'start_screen.dart';

/// 게임을 켜면 처음 나오는 화면.
///
/// ## 오프닝이 해야 하는 한 가지
///
/// 이 저장소의 논제는 "스프라이트 없이 코드로만 그린다"이다. 그런데 지금까지
/// 첫 화면은 곧장 명부였고, 명부는 캐릭터 **카드**를 보여 준다 — 카드는 어떤
/// 게임에나 있으므로 아무것도 증명하지 않는다.
///
/// 그래서 오프닝은 글자로 자랑하는 대신 **한 명을 실제로 세워 둔다.** 실행
/// 중에 골격을 풀고 관절을 움직이는 그 캐릭터가 곧 주장 자체다. 배경의 지면도
/// 게임에서 쓰는 것과 같은 [paintIsoGround] 이므로, 이 화면에 그려진 픽셀 중
/// 파일에서 온 것은 하나도 없다.
class OpeningScreen extends StatefulWidget {
  const OpeningScreen({super.key});

  @override
  State<OpeningScreen> createState() => _OpeningScreenState();
}

class _OpeningScreenState extends State<OpeningScreen>
    with TickerProviderStateMixin {
  /// 화면의 시계. 캐릭터의 호흡과 지면의 안개가 여기서 돈다.
  late final AnimationController _clock = AnimationController(
    vsync: this,
    // 60초를 한 바퀴로 돌린다. 값 자체는 의미가 없고, 멈추지 않는 것이 목적.
    duration: const Duration(seconds: 60),
  )..repeat();

  /// 등장. 제목과 캐릭터가 서로 다른 속도로 들어와야 화면에 깊이가 생긴다.
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..forward();

  /// 세워 둘 캐릭터. 켤 때마다 달라지면 "매번 새로 생성된다"가 저절로 읽힌다.
  late final Artist _star =
      signatureHeroes[DateTime.now().millisecond % signatureHeroes.length];

  late final RiggedIsoActor _actor = riggedFromArtist(
    _star,
    tile: Offset.zero,
    height: 300,
    iso: _iso,
  )..play('idle');

  static const IsoView _iso = IsoView(tileWidth: 150, tileHeight: 75);

  double _last = 0;

  @override
  void initState() {
    super.initState();
    // 액터의 시간은 씬이 아니라 이 화면이 민다. dt 를 직접 재서 넘겨야
    // 프레임률이 흔들려도 호흡이 같은 속도로 돈다.
    _clock.addListener(_step);
  }

  void _step() {
    final now = _clock.value * _clock.duration!.inMilliseconds / 1000.0;
    var dt = now - _last;
    _last = now;
    // 한 바퀴 돌아 0 으로 되돌아온 프레임은 건너뛴다.
    if (dt <= 0 || dt > 0.25) return;
    _actor.update(dt);
  }

  @override
  void dispose() {
    _clock.removeListener(_step);
    _clock.dispose();
    _enter.dispose();
    super.dispose();
  }

  void _begin() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 620),
        pageBuilder: (_, _, _) => const StartScreen(),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Scaffold(
      backgroundColor: const Color(0xFF04060C),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _begin,
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedBuilder(
              animation: Listenable.merge([_clock, _enter]),
              builder: (context, _) => CustomPaint(
                painter: _OpeningPainter(
                  actor: _actor,
                  accent: _star.accent,
                  time: _clock.value * 60,
                  enter: Curves.easeOutCubic.transform(_enter.value),
                ),
              ),
            ),

            // ── 글자 ────────────────────────────────────────────────────
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _enter,
                builder: (context, _) {
                  final k = Curves.easeOutCubic.transform(
                    (_enter.value * 1.35 - 0.2).clamp(0.0, 1.0),
                  );
                  return Opacity(
                    opacity: k,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Spacer(flex: 3),
                        Transform.translate(
                          offset: Offset(0, (1 - k) * 20),
                          child: Column(
                            children: [
                              Text(
                                t.openingTitle,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 72,
                                  height: 1.0,
                                  letterSpacing: 20,
                                  fontWeight: FontWeight.w100,
                                  color: m.Colors.white.withValues(alpha: 0.96),
                                  shadows: [
                                    Shadow(
                                      color: _star.accent.withValues(
                                        alpha: 0.55,
                                      ),
                                      blurRadius: 46,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                              Container(
                                width: 120,
                                height: 1,
                                color: _star.accent.withValues(alpha: 0.7),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                t.openingSubtitle,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  letterSpacing: 3,
                                  color: m.Colors.white.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(flex: 4),
                        _Pulse(
                          clock: _clock,
                          child: Text(
                            t.openingEnter,
                            style: TextStyle(
                              fontSize: 12,
                              letterSpacing: 5,
                              fontWeight: FontWeight.w700,
                              color: _star.accent.lighten(0.3),
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 28),
                          child: Text(
                            t.openingCredit,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10.5,
                              letterSpacing: 1.1,
                              color: m.Colors.white.withValues(alpha: 0.32),
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                      ],
                    ),
                  );
                },
              ),
            ),

            const Positioned(right: 20, top: 18, child: LangToggle()),
          ],
        ),
      ),
    );
  }
}

/// "눌러서 시작"이 숨 쉬듯 밝아졌다 어두워진다.
class _Pulse extends StatelessWidget {
  const _Pulse({required this.clock, required this.child});
  final Animation<double> clock;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: clock,
        builder: (context, _) => Opacity(
          // 0 까지 내려가지 않는다. 완전히 사라지면 고장으로 보인다.
          opacity: 0.45 + 0.55 * (0.5 + 0.5 * math.sin(clock.value * 60 * 2.0)),
          child: child,
        ),
      );
}

/// 오프닝의 배경 — 지면 위에 선 캐릭터 한 명.
class _OpeningPainter extends CustomPainter {
  _OpeningPainter({
    required this.actor,
    required this.accent,
    required this.time,
    required this.enter,
  });

  final RiggedIsoActor actor;
  final Color accent;
  final double time;

  /// 0 → 1 등장 진행도.
  final double enter;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // 캐릭터의 강조색에서 유도한 밤하늘. 누가 서 있느냐에 따라 하늘색이
    // 바뀌므로, 켤 때마다 다른 화면이 된다.
    final sky = accent.darken(0.72).desaturate(0.35);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          rect.topCenter,
          rect.bottomCenter,
          [
            const Color(0xFF04060C),
            sky.mix(const Color(0xFF04060C), 0.45),
            sky.lighten(0.06),
          ],
          const [0.0, 0.55, 1.0],
        ),
    );

    // 지면. 게임에서 쓰는 것과 **같은 함수**다 — 오프닝을 위해 따로 그린
    // 배경이 아니라, 실제로 그 위를 걷게 될 땅이다.
    final light = LightRig.dusk.copyWith(intensity: 1.0);
    canvas.save();
    canvas.translate(size.width * 0.5, size.height * 0.94);
    canvas.clipRect(Rect.fromLTWH(-size.width, -size.height, size.width * 2,
        size.height * 2));
    paintIsoGround(
      canvas,
      _OpeningScreenState._iso,
      9,
      9,
      light,
      lineAlpha: 0.0,
      seed: 20260807,
      skirt: 0.0,
    );
    canvas.restore();

    // 지평선을 향해 어두워지는 안개. 지면의 먼 가장자리를 감춰 잘린 종이로
    // 보이지 않게 한다.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          rect.topCenter,
          Offset(rect.center.dx, size.height * 0.86),
          [
            const Color(0xFF04060C),
            const Color(0xFF04060C).withValues(alpha: 0.0),
          ],
          const [0.42, 1.0],
        ),
    );

    // 캐릭터. 아래에서 솟아오르며 들어온다.
    canvas.save();
    canvas.translate(
      size.width * 0.5,
      size.height * 0.86 + (1 - enter) * 40,
    );
    final s = (size.height / 900).clamp(0.55, 1.25);
    canvas.scale(s);
    canvas.saveLayer(
      Rect.fromCenter(center: Offset.zero, width: 1400, height: 1400),
      Paint()..color = white.fade(enter),
    );
    actor.renderer.paint(
      canvas,
      pose: actor.animator.pose,
      light: light,
      facing: const Facing(1.05),
      iso: _OpeningScreenState._iso,
      time: time,
      detail: 1.0,
    );
    canvas.restore();
    canvas.restore();

    // 발치에서 번지는 강조색. 캐릭터를 어두운 화면에 붙들어 둔다.
    final glowAt = Offset(size.width * 0.5, size.height * 0.86);
    canvas.drawCircle(
      glowAt,
      size.height * 0.24,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = ui.Gradient.radial(
          glowAt,
          size.height * 0.24,
          [
            accent.withValues(alpha: 0.16 * enter),
            accent.withValues(alpha: 0.0),
          ],
        ),
    );
  }

  @override
  bool shouldRepaint(covariant _OpeningPainter old) => true;
}
