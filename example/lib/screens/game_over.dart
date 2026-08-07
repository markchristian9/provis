import 'package:flutter/material.dart' hide Colors;
import 'package:flutter/material.dart' as m show Colors;
import 'package:provis/provis.dart';

import '../i18n/lang.dart';

/// 쓰러졌을 때 화면을 덮는 패배 표시.
///
/// ## 왜 라우트가 아니라 오버레이인가
///
/// 게임오버는 **게임이 끝난 상태**가 아니라 게임의 한 상태다. 라우트를 새로
/// 밀면 [FieldGame] 이 화면에서 내려가고, 다시 도전할 때 마을과 소리 창고를
/// 통째로 다시 굽게 된다 — 진 자리에서 곧바로 다시 붙는 리듬이 끊긴다.
/// 그래서 게임 위에 얹고, 뒤에서는 쓰러진 주인공이 그대로 보이게 둔다.
class GameOverOverlay extends StatefulWidget {
  const GameOverOverlay({
    super.key,
    required this.heroName,
    required this.accent,
    required this.slain,
    required this.onRetry,
    required this.onQuit,
  });

  final String heroName;
  final Color accent;

  /// 이번 판에 쓰러뜨린 몬스터 수.
  final int slain;

  final VoidCallback onRetry;
  final VoidCallback onQuit;

  @override
  State<GameOverOverlay> createState() => _GameOverOverlayState();
}

class _GameOverOverlayState extends State<GameOverOverlay>
    with SingleTickerProviderStateMixin {
  /// 덮이는 데 시간을 준다. 즉시 나타나면 플레이어가 방금 무슨 일이
  /// 일어났는지 보기 전에 화면이 바뀐 것으로 느낀다.
  late final AnimationController _in = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  )..forward();

  @override
  void dispose() {
    _in.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return AnimatedBuilder(
      animation: _in,
      builder: (context, _) {
        final k = Curves.easeOutCubic.transform(_in.value);
        return Positioned.fill(
          child: IgnorePointer(
            ignoring: k < 0.5,
            child: Container(
              // 완전한 검정으로 덮지 않는다. 쓰러진 주인공이 비쳐 보여야
              // 이 화면이 어디에 얹혀 있는지 알 수 있다.
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  radius: 1.1,
                  colors: [
                    const Color(0xFF0A0510).withValues(alpha: 0.62 * k),
                    const Color(0xFF04060C).withValues(alpha: 0.93 * k),
                  ],
                ),
              ),
              child: Center(
                child: Opacity(
                  opacity: k,
                  child: Transform.translate(
                    offset: Offset(0, (1 - k) * 26),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 제목 위의 가는 강조선. 캐릭터의 색이 여기 한 번
                        // 나오면 "누가" 쓰러졌는지가 글자보다 먼저 읽힌다.
                        Container(
                          width: 74,
                          height: 2,
                          color: widget.accent.withValues(alpha: 0.85),
                        ),
                        const SizedBox(height: 26),
                        Text(
                          t.defeatTitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 54,
                            height: 1.0,
                            letterSpacing: 14,
                            fontWeight: FontWeight.w200,
                            color: m.Colors.white.withValues(alpha: 0.94),
                            shadows: [
                              Shadow(
                                color: widget.accent.withValues(alpha: 0.45),
                                blurRadius: 34,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          t.defeatLine(widget.heroName),
                          style: TextStyle(
                            fontSize: 14,
                            letterSpacing: 1.2,
                            color: m.Colors.white.withValues(alpha: 0.55),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          t.defeatScore(widget.slain),
                          style: TextStyle(
                            fontSize: 12,
                            letterSpacing: 2.6,
                            fontWeight: FontWeight.w700,
                            color: widget.accent.lighten(0.18).withValues(
                                  alpha: 0.9,
                                ),
                          ),
                        ),
                        const SizedBox(height: 38),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _Button(
                              label: t.retry,
                              accent: widget.accent,
                              filled: true,
                              onTap: widget.onRetry,
                            ),
                            const SizedBox(width: 14),
                            _Button(
                              label: t.backToRoster,
                              accent: widget.accent,
                              filled: false,
                              onTap: widget.onQuit,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Button extends StatelessWidget {
  const _Button({
    required this.label,
    required this.accent,
    required this.filled,
    required this.onTap,
  });

  final String label;
  final Color accent;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
        decoration: BoxDecoration(
          color: filled
              ? accent.withValues(alpha: 0.18)
              : m.Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: filled
                ? accent.withValues(alpha: 0.8)
                : m.Colors.white.withValues(alpha: 0.2),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            letterSpacing: 2.2,
            fontWeight: FontWeight.w700,
            color: filled ? accent.lighten(0.35) : m.Colors.white70,
          ),
        ),
      ),
    );
  }
}
