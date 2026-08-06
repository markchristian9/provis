import 'package:flutter/material.dart';
import 'package:provis/provis.dart';

import '../characters/roster.dart';
import '../ui/portrait_card.dart';
import 'game_map.dart';

/// 시작 화면 — 챔피언과 나이트메어를 탭으로 나눠 보여 준다.
///
/// 챔피언 카드를 누르면 그 캐릭터로 게임 맵에 입장한다. 나이트메어 탭은
/// 맵에서 마주칠 상대를 미리 보는 용도다.
class StartScreen extends StatefulWidget {
  const StartScreen({super.key});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _enter(Artist hero) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => GameMapScreen(hero: hero)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF06080F),
      body: SafeArea(
        child: Column(
          children: [
            const _Header(),
            TabBar(
              controller: _tabs,
              indicatorColor: const Color(0xFF57E8FF),
              indicatorWeight: 2,
              labelColor: const Color(0xFFBFF3FF),
              unselectedLabelColor: Colors.white38,
              labelStyle: const TextStyle(
                fontSize: 13,
                letterSpacing: 3,
                fontWeight: FontWeight.w700,
              ),
              tabs: [
                Tab(text: '캐릭터  ${heroes.length}'),
                Tab(text: '몬스터  ${monsters.length}'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _Roster(
                    artists: heroes,
                    hint: '캐릭터를 선택하면 게임 맵에 입장합니다',
                    onPick: _enter,
                  ),
                  _Roster(
                    artists: monsters,
                    hint: '맵에서 마주칠 상대들 — 전원이 한 마리씩 배치됩니다',
                    onPick: null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 22, 28, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Text(
            'PROVIS',
            style: TextStyle(
              fontSize: 26,
              letterSpacing: 8,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 14),
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Text(
              '절차적 2.5D 아이소메트릭',
              style: TextStyle(
                fontSize: 12,
                letterSpacing: 1,
                color: Colors.white.withValues(alpha: 0.45),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 한 진영의 명부 그리드.
class _Roster extends StatelessWidget {
  const _Roster({
    required this.artists,
    required this.hint,
    required this.onPick,
  });

  final List<Artist> artists;
  final String hint;

  /// `null` 이면 선택할 수 없다(미리보기 전용).
  final void Function(Artist)? onPick;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 16, 28, 10),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              hint,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.42),
              ),
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final a in artists)
                  _PickCard(
                    artist: a,
                    enabled: onPick != null,
                    onTap: () => onPick?.call(a),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 명부 카드 — 초상과 이름·칭호를 함께 보여 준다.
///
/// [ArtistCard] 는 대치 화면용이라 선택 상태가 토글이지만, 여기서는 누르면
/// 곧바로 입장하므로 별도 카드를 쓴다.
class _PickCard extends StatefulWidget {
  const _PickCard({
    required this.artist,
    required this.enabled,
    required this.onTap,
  });

  final Artist artist;
  final bool enabled;
  final VoidCallback onTap;

  @override
  State<_PickCard> createState() => _PickCardState();
}

class _PickCardState extends State<_PickCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final a = widget.artist;
    final lit = _hover && widget.enabled;
    return MouseRegion(
      cursor: widget.enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.enabled ? widget.onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: 176,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: lit
                  ? a.accent.withValues(alpha: 0.9)
                  : Colors.white.withValues(alpha: 0.10),
              width: lit ? 2 : 1,
            ),
            boxShadow: lit
                ? [
                    BoxShadow(
                      color: a.accent.withValues(alpha: 0.28),
                      blurRadius: 22,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(13)),
                child: SizedBox(
                  height: 208,
                  // 카드마다 시간을 흘려 초상이 숨 쉬게 한다. 정지 화면이면
                  // 명부가 카탈로그처럼 죽어 보인다.
                  child: _BreathingPortrait(artist: a),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius:
                      const BorderRadius.vertical(bottom: Radius.circular(13)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            a.name.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              letterSpacing: 2,
                              fontWeight: FontWeight.w700,
                              color: lit ? a.accent : Colors.white,
                            ),
                          ),
                        ),
                        // 성별은 이름 옆 기호 하나로 족하다. 카드가 좁다.
                        if (a.sex != null)
                          Text(
                            a.sex!.symbol,
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.0,
                              color: a.accent.withValues(alpha: 0.85),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      a.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // 직업 배지. 강조색을 옅게 깔아 두면 명부를 훑을 때 역할이
                    // 이름보다 먼저 읽힌다.
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: a.accent.withValues(alpha: 0.13),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: a.accent.withValues(alpha: 0.32),
                        ),
                      ),
                      child: Text(
                        a.job.label.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9,
                          letterSpacing: 1.4,
                          fontWeight: FontWeight.w600,
                          color: a.accent.withValues(alpha: 0.95),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 시간이 흐르는 초상. 호흡과 이펙트가 살아 있어야 명부가 죽지 않는다.
class _BreathingPortrait extends StatefulWidget {
  const _BreathingPortrait({required this.artist});
  final Artist artist;

  @override
  State<_BreathingPortrait> createState() => _BreathingPortraitState();
}

class _BreathingPortraitState extends State<_BreathingPortrait>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) => CustomPaint(
        painter: ArtistPortrait(
          widget.artist,
          detail: 0.42,
          time: _c.value * 12,
        ),
        size: Size.infinite,
      ),
    );
  }
}
