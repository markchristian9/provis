import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../art/creature.dart';
import '../art/roster.dart';
import '../core/palette.dart';
import 'portrait_card.dart';
import 'stage.dart';

/// 대치 선택 화면.
///
/// 화면의 목적은 단 하나다 — 여덟 캐릭터 중 둘을 골라 나란히 세워 보는 것.
/// 그래서 UI 요소는 전부 가장자리로 밀어 두고, 가운데는 언제나 두 실루엣이
/// 차지한다. 카드 탭 한 번이면 무대 조명과 배경색까지 함께 바뀐다.
class EntryScreen extends StatefulWidget {
  const EntryScreen({super.key});

  @override
  State<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends State<EntryScreen> {
  final Matchup _matchup = Matchup();
  late final StageGame _game = StageGame(_matchup);

  @override
  void initState() {
    super.initState();
    _matchup.addListener(_onPick);
  }

  @override
  void dispose() {
    _matchup.removeListener(_onPick);
    _matchup.dispose();
    super.dispose();
  }

  void _onPick() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF05070C),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) {
            final wide = box.maxWidth >= 860;
            return Column(
              children: [
                _Header(hero: _matchup.hero, monster: _matchup.monster),
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(child: GameWidget(game: _game)),
                      Positioned(
                        left: 16,
                        top: 12,
                        width: wide ? 300 : 190,
                        child: _NamePlate(
                          artist: _matchup.hero,
                          align: CrossAxisAlignment.start,
                          compact: !wide,
                        ),
                      ),
                      Positioned(
                        right: 16,
                        top: 12,
                        width: wide ? 300 : 190,
                        child: _NamePlate(
                          artist: _matchup.monster,
                          align: CrossAxisAlignment.end,
                          compact: !wide,
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 10,
                        child: Center(
                          child: _EngageButton(
                            hero: _matchup.hero,
                            monster: _matchup.monster,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                _SelectionStrip(matchup: _matchup, wide: wide),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.hero, required this.monster});

  final Artist hero;
  final Artist monster;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: const Color(0xFF1A2432).fade(0.9)),
        ),
        gradient: LinearGradient(
          colors: [
            hero.accent.fade(0.10),
            const Color(0xFF05070C),
            monster.accent.fade(0.10),
          ],
        ),
      ),
      child: Row(
        children: [
          Container(width: 3, height: 22, color: hero.accent),
          const SizedBox(width: 10),
          const Text(
            'THE VIGIL ROSTER',
            style: TextStyle(
              color: Color(0xFFE4EBF5),
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: 3.4,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              '누가 어떤 밤을 마주할 것인가 — 챔피언과 악몽을 하나씩 고르십시오.',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Color(0xFF6E7C90),
                fontSize: 11.5,
                letterSpacing: 0.4,
              ),
            ),
          ),
          Container(width: 3, height: 22, color: monster.accent),
        ],
      ),
    );
  }
}

class _NamePlate extends StatelessWidget {
  const _NamePlate({
    required this.artist,
    required this.align,
    required this.compact,
  });

  final Artist artist;
  final CrossAxisAlignment align;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final right = align == CrossAxisAlignment.end;
    return IgnorePointer(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        child: Column(
          key: ValueKey(artist.id),
          crossAxisAlignment: align,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              artist.camp == Camp.player ? 'CHAMPION' : 'NIGHTMARE',
              style: TextStyle(
                color: artist.accent.fade(0.85),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 3.0,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              artist.name.toUpperCase(),
              textAlign: right ? TextAlign.right : TextAlign.left,
              style: TextStyle(
                color: const Color(0xFFF0F5FC),
                fontSize: compact ? 22 : 30,
                height: 1.05,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.6,
                shadows: [
                  Shadow(color: artist.accent.fade(0.6), blurRadius: 18),
                  const Shadow(color: Color(0xFF000000), blurRadius: 6),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Container(width: compact ? 60 : 110, height: 2, color: artist.accent),
            const SizedBox(height: 6),
            Text(
              artist.title,
              textAlign: right ? TextAlign.right : TextAlign.left,
              style: const TextStyle(
                color: Color(0xFFA9B6C7),
                fontSize: 11,
                letterSpacing: 1.0,
              ),
            ),
            if (!compact) ...[
              const SizedBox(height: 8),
              Text(
                artist.blurb,
                textAlign: right ? TextAlign.right : TextAlign.left,
                style: const TextStyle(
                  color: Color(0xFF7C8A9C),
                  fontSize: 11.5,
                  height: 1.45,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EngageButton extends StatelessWidget {
  const _EngageButton({required this.hero, required this.monster});

  final Artist hero;
  final Artist monster;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(color: hero.accent.fade(0.30), blurRadius: 26),
          BoxShadow(color: monster.accent.fade(0.30), blurRadius: 26),
        ],
      ),
      child: Material(
        color: const Color(0xE60B111C),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(color: hero.accent.mix(monster.accent, 0.5)),
        ),
        child: InkWell(
          onTap: () {
            ScaffoldMessenger.of(context)
              ..clearSnackBars()
              ..showSnackBar(
                SnackBar(
                  duration: const Duration(seconds: 3),
                  backgroundColor: const Color(0xFF0C1420),
                  content: Text(
                    '${hero.name} 이(가) ${monster.name} 을(를) 마주 봅니다 — '
                    '${hero.title} vs ${monster.title}.',
                    style: const TextStyle(color: Color(0xFFD8E2EE)),
                  ),
                ),
              );
          },
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 26, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  hero.name.toUpperCase(),
                  style: TextStyle(
                    color: hero.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'VS',
                    style: TextStyle(
                      color: Color(0xFFE8EEF7),
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                Text(
                  monster.name.toUpperCase(),
                  style: TextStyle(
                    color: monster.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectionStrip extends StatelessWidget {
  const _SelectionStrip({required this.matchup, required this.wide});

  final Matchup matchup;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final left = _Group(
      label: 'CHAMPIONS',
      hint: '남성 2 · 여성 2',
      accent: matchup.hero.accent,
      list: heroes,
      matchup: matchup,
    );
    final right = _Group(
      label: 'NIGHTMARES',
      hint: '4 종의 이형',
      accent: matchup.monster.accent,
      list: monsters,
      matchup: matchup,
      alignEnd: true,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: const BoxDecoration(
        color: Color(0xFF080C14),
        border: Border(top: BorderSide(color: Color(0xFF1A2432))),
      ),
      child: wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: left),
                Container(
                  width: 1,
                  height: 150,
                  margin: const EdgeInsets.symmetric(horizontal: 18),
                  color: const Color(0xFF1C2735),
                ),
                Expanded(child: right),
              ],
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  left,
                  const SizedBox(width: 18),
                  right,
                ],
              ),
            ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({
    required this.label,
    required this.hint,
    required this.accent,
    required this.list,
    required this.matchup,
    this.alignEnd = false,
  });

  final String label;
  final String hint;
  final Color accent;
  final List<Artist> list;
  final Matchup matchup;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final cards = [
      for (final a in list)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: ArtistCard(
            artist: a,
            selected: matchup.isChosen(a),
            onTap: () => matchup.choose(a),
          ),
        ),
    ];

    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 8, height: 1.6, color: accent),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.6,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                hint,
                style: const TextStyle(
                  color: Color(0xFF5F6C7E),
                  fontSize: 10.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment:
                alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: cards,
          ),
        ),
      ],
    );
  }
}
