import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provis/provis.dart';

import '../characters/roster.dart';
import '../i18n/character_text.dart';
import '../i18n/lang.dart';
import '../ui/portrait_card.dart';
import 'game_map.dart';

/// 캐릭터 선택 허브.
///
/// ## 왜 스테이지 + 명부인가
///
/// 예전 화면은 카드 스물아홉 장을 한 벌로 늘어놓고, 누르면 그대로 맵에
/// 들어갔다. 문제가 셋이었다. 고르기 전에 인물을 **크게 볼 방법이 없었고**,
/// 잘못 누르면 곧바로 맵으로 끌려갔으며, 스물다섯 명이 한 덩어리라 원하는
/// 역할을 찾으려면 눈으로 훑는 수밖에 없었다.
///
/// 지금은 왼쪽이 **스테이지**(고른 인물 하나를 크게, 살아 움직이게), 오른쪽이
/// **명부**(진영 · 직업으로 좁히는 격자)다. 고르는 것과 들어가는 것이 분리되어
/// 있으므로 마음껏 둘러볼 수 있다.
///
/// 스테이지가 보여 주는 장비는 장식이 아니다. 게임 맵이 쓰는 것과 **같은
/// 명세**([CharacterBuild.toSpec])에서 읽으므로, 여기 적힌 무기가 맵에서 손에
/// 들려 나온다.
class StartScreen extends StatefulWidget {
  const StartScreen({super.key});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  /// 격자 한 칸의 세로 길이 + 간격. 화살표 위·아래가 한 행을 건너뛰는 거리이자
  /// 화면 밖 칸으로 스크롤할 때 쓰는 자다.
  static const double _tileExtent = 186;
  static const double _tileGap = 12;

  Camp _camp = Camp.player;

  /// `null` 이면 직업으로 거르지 않는다.
  Archetype? _job;

  late Artist _focus = heroes.first;

  final ScrollController _scroll = ScrollController();
  final FocusNode _keys = FocusNode(debugLabel: 'roster-keys');

  /// 화살표로 고른 칸을 화면 안으로 끌어오기 위한 손잡이.
  final Map<String, GlobalKey> _tileKeys = {};

  /// 명세는 한 번만 만든다 — 매 프레임 생성기를 돌릴 이유가 없다.
  final Map<String, HumanoidSpec> _specs = {};

  /// 격자의 열 수. 배치가 정하고 키보드 조작이 읽는다.
  int _cols = 3;

  @override
  void dispose() {
    _scroll.dispose();
    _keys.dispose();
    super.dispose();
  }

  List<Artist> get _pool => _camp == Camp.player ? heroes : monsters;

  List<Artist> get _list => [
        for (final a in _pool)
          if (_job == null || a.job == _job) a,
      ];

  /// 지금 진영에 실제로 있는 직업만. 비어 있는 필터는 누를 수 있어 봐야
  /// 빈 화면만 낸다.
  List<Archetype> get _jobs => [
        for (final j in Archetype.values)
          if (_pool.any((a) => a.job == j)) j,
      ];

  /// 게임 맵이 이 인물을 세울 때 쓸 명세 그대로.
  ///
  /// 시드 계산은 `riggedFromArtist` 와 **같아야** 한다. 다르면 명부가 검을
  /// 보여 주고 맵에서는 도끼가 나온다.
  HumanoidSpec _specOf(Artist a) => _specs.putIfAbsent(
        a.id,
        () => a.build.toSpec(Rng.fromString(a.id).intRange(1, 0x7FFFFFF)),
      );

  void _setCamp(Camp c) {
    if (c == _camp) return;
    setState(() {
      _camp = c;
      _job = null;
      _focus = _list.first;
    });
    _reveal(_focus);
  }

  void _setJob(Archetype? j) {
    setState(() {
      _job = j;
      if (!_list.contains(_focus)) _focus = _list.first;
    });
    _reveal(_focus);
  }

  void _pick(Artist a) {
    if (a == _focus) return;
    setState(() => _focus = a);
  }

  /// 화살표 이동. 목록의 양 끝에서는 멈춘다 — 감싸 돌면 지금 어디쯤인지
  /// 감각이 사라진다.
  void _step(int delta) {
    final list = _list;
    final at = list.indexOf(_focus);
    final next = ((at < 0 ? 0 : at) + delta).clamp(0, list.length - 1);
    if (list[next] == _focus) return;
    setState(() => _focus = list[next]);
    _reveal(_focus);
  }

  /// 고른 칸을 화면 안으로.
  ///
  /// 격자는 보이는 칸만 만들므로 멀리 떨어진 칸에는 [BuildContext] 가 없다.
  /// 그때는 행 번호로 위치를 계산해 직접 굴린다.
  void _reveal(Artist a) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      const duration = Duration(milliseconds: 220);
      const curve = Curves.easeOutCubic;

      final ctx = _tileKeys[a.id]?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx,
            alignment: 0.5, duration: duration, curve: curve);
        return;
      }
      if (!_scroll.hasClients) return;
      final at = _list.indexOf(a);
      if (at < 0) return;
      final row = at ~/ _cols;
      final p = _scroll.position;
      final target = (row * (_tileExtent + _tileGap) -
              p.viewportDimension / 2 +
              _tileExtent / 2)
          .clamp(0.0, p.maxScrollExtent);
      _scroll.animateTo(target, duration: duration, curve: curve);
    });
  }

  bool get _playable => _focus.camp == Camp.player;

  void _enter() {
    if (!_playable) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => GameMapScreen(hero: _focus)),
    );
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    switch (e.logicalKey) {
      case LogicalKeyboardKey.arrowLeft:
        _step(-1);
      case LogicalKeyboardKey.arrowRight:
        _step(1);
      case LogicalKeyboardKey.arrowUp:
        _step(-_cols);
      case LogicalKeyboardKey.arrowDown:
        _step(_cols);
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.numpadEnter:
      case LogicalKeyboardKey.space:
        _enter();
      default:
        return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF06080F),
      body: SafeArea(
        child: Focus(
          focusNode: _keys,
          autofocus: true,
          onKeyEvent: _onKey,
          child: Column(
            children: [
              const _HubHeader(),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, box) {
                    // 넓으면 스테이지와 명부가 나란히, 좁으면 스테이지가 띠로
                    // 줄고 명부가 아래를 차지한다.
                    final wide = box.maxWidth >= 940;
                    final panelWidth = wide
                        ? box.maxWidth.clamp(940.0, 1600.0) * 0.34
                        : box.maxWidth;

                    // 열 수는 배치가 정하고 화살표 조작이 읽는다. 여기서 필드에
                    // 적어 두는 것은 다시 그리기를 부르지 않으므로 안전하다.
                    _cols = ((panelWidth - 28) / 152).floor().clamp(2, 6);

                    final roster = _RosterPanel(
                      compact: !wide,
                      artists: _list,
                      jobs: _jobs,
                      camp: _camp,
                      job: _job,
                      focus: _focus,
                      columns: _cols,
                      tileExtent: _tileExtent,
                      gap: _tileGap,
                      scroll: _scroll,
                      tileKeys: _tileKeys,
                      onCamp: _setCamp,
                      onJob: _setJob,
                      onPick: _pick,
                      // 두 번 누르면 그 인물을 고른 뒤 곧바로 입장한다.
                      onEnter: (a) {
                        _pick(a);
                        _enter();
                      },
                    );

                    final stage = _Stage(
                      artist: _focus,
                      spec: _specOf(_focus),
                      compact: !wide,
                      onEnter: _playable ? _enter : null,
                    );

                    if (!wide) {
                      return Column(
                        children: [
                          stage,
                          Expanded(child: roster),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: stage),
                        SizedBox(width: panelWidth, child: roster),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HubHeader extends StatelessWidget {
  const _HubHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 18, 22, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Text(
            'PROVIS',
            style: TextStyle(
              fontSize: 24,
              letterSpacing: 8,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                context.t.tagline,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 1,
                  color: Colors.white.withValues(alpha: 0.45),
                ),
              ),
            ),
          ),
          // 언어 전환은 명부 머리에 둔다. 앱에 들어오자마자 보이는 자리이고,
          // 게임 맵에서 돌아와도 같은 곳에 있다.
          const LangToggle(),
        ],
      ),
    );
  }
}

// ── 스테이지 ──────────────────────────────────────────────────────────────

/// 고른 인물 하나를 크게 보여 주는 무대.
///
/// 초상은 명부 칸과 **같은 [Artist.paint]** 를 부르되 디테일만 올린다.
/// 썸네일용 별도 에셋이 없으므로 카드와 무대가 어긋날 수가 없다.
class _Stage extends StatelessWidget {
  const _Stage({
    required this.artist,
    required this.spec,
    required this.compact,
    required this.onEnter,
  });

  final Artist artist;
  final HumanoidSpec spec;
  final bool compact;

  /// `null` 이면 입장할 수 없다 — 몬스터를 보고 있다는 뜻이다.
  final VoidCallback? onEnter;

  @override
  Widget build(BuildContext context) {
    return compact ? _buildCompact(context) : _buildWide(context);
  }

  Widget _buildWide(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 8, 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 초상 상자를 오른쪽으로 넘치게 잡아 인물이 화면 오른쪽에 선다.
            // 배경까지 같은 상자가 칠하므로 왼쪽에 빈 띠가 생기지 않는다.
            LayoutBuilder(
              builder: (context, box) => Stack(
                children: [
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    right: -box.maxWidth * 0.26,
                    child: _LivePortrait(
                      artist: artist,
                      detail: 0.9,
                      running: true,
                    ),
                  ),
                ],
              ),
            ),
            // 글이 얹힐 왼쪽을 눌러 준다. 어두운 인물이 와도 이름이 읽힌다.
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    const Color(0xF2060810),
                    const Color(0xC0060810),
                    const Color(0x00060810),
                  ],
                  stops: const [0.0, 0.34, 0.68],
                ),
              ),
            ),
            Positioned(
              left: 34,
              right: 34,
              bottom: 30,
              // Align 이 느슨한 제약을 물려준다. 이것 없이 ConstrainedBox 만
              // 두면 left+right 가 만든 꽉 찬 폭이 이겨서, 막대와 글이 인물
              // 밑까지 늘어난다.
              child: Align(
                alignment: Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: _Identity(
                    artist: artist,
                    spec: spec,
                    compact: false,
                    onEnter: onEnter,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompact(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 132,
              height: 186,
              child: _LivePortrait(
                artist: artist,
                detail: 0.6,
                running: true,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _Identity(
              artist: artist,
              spec: spec,
              compact: true,
              onEnter: onEnter,
            ),
          ),
        ],
      ),
    );
  }
}

/// 이름 · 칭호 · 소개 · 장비 · 입장 버튼.
class _Identity extends StatelessWidget {
  const _Identity({
    required this.artist,
    required this.spec,
    required this.compact,
    required this.onEnter,
  });

  final Artist artist;
  final HumanoidSpec spec;
  final bool compact;
  final VoidCallback? onEnter;

  @override
  Widget build(BuildContext context) {
    final a = artist;
    final t = context.t;
    final lang = context.lang;
    final beast = a.build.beast;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: Text(
                a.name.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: compact ? 24 : 40,
                  height: 1.05,
                  letterSpacing: compact ? 3 : 6,
                  fontWeight: FontWeight.w800,
                  color: a.accent,
                  shadows: [
                    Shadow(color: a.accent.fade(0.35), blurRadius: 24),
                    const Shadow(color: Color(0xCC000000), blurRadius: 8),
                  ],
                ),
              ),
            ),
            if (a.sex != null) ...[
              const SizedBox(width: 10),
              Padding(
                padding: EdgeInsets.only(bottom: compact ? 2 : 6),
                child: Text(
                  a.sex!.symbol,
                  style: TextStyle(
                    fontSize: compact ? 16 : 20,
                    height: 1.0,
                    color: a.accent.fade(0.8),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          a.titleIn(lang),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: compact ? 12 : 14,
            letterSpacing: 1,
            color: Colors.white.withValues(alpha: 0.62),
          ),
        ),
        if (!compact) ...[
          const SizedBox(height: 10),
          Text(
            a.blurbIn(lang),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ],
        SizedBox(height: compact ? 8 : 16),

        // 장비는 게임 맵이 쓰는 명세에서 그대로 읽는다.
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _Tag(label: t.job(a.job), accent: a.accent, solid: true),
            if (beast)
              _Tag(label: t.beast, accent: a.accent)
            else ...[
              _Tag(label: t.weapon(spec.weapon), accent: a.accent),
              _Tag(label: t.headGear(spec.headGear), accent: a.accent),
              if (spec.hasShield) _Tag(label: t.shieldGear, accent: a.accent),
              if (spec.hasCape) _Tag(label: t.capeGear, accent: a.accent),
              if (spec.hasPauldrons)
                _Tag(label: t.pauldronGear, accent: a.accent),
              if (spec.glowRunes) _Tag(label: t.runeGear, accent: a.accent),
            ],
          ],
        ),
        SizedBox(height: compact ? 10 : 16),

        Row(
          children: [
            Expanded(
              child: _Bar(
                label: t.armorStat,
                value: spec.armorHeaviness,
                accent: a.accent,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _Bar(
                label: t.mightStat,
                value: spec.muscle,
                accent: a.accent,
              ),
            ),
          ],
        ),
        SizedBox(height: compact ? 10 : 18),

        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _EnterButton(accent: a.accent, onTap: onEnter, label: t.enterMap),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                onEnter == null ? t.monsterLocked : _origin(context, a),
                maxLines: 2,
                style: TextStyle(
                  fontSize: 10.5,
                  height: 1.4,
                  color: Colors.white.withValues(alpha: 0.38),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 이 인물이 어느 길로 만들어졌는지 — 데모의 논지 그 자체다.
  static String _origin(BuildContext context, Artist a) =>
      a is BuiltArtist ? context.t.declaredBuild : context.t.handDrawn;
}

/// 값 하나를 막대로. 인물을 바꾸면 막대가 새 값으로 흘러간다.
class _Bar extends StatelessWidget {
  const _Bar({required this.label, required this.value, required this.accent});

  final String label;
  final double value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                letterSpacing: 1.6,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ),
            const Spacer(),
            Text(
              (value * 100).round().toString(),
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: accent.fade(0.75),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        LayoutBuilder(
          builder: (context, box) => ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Stack(
              children: [
                Container(
                  height: 5,
                  width: box.maxWidth,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
                  duration: const Duration(milliseconds: 340),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, _) => Container(
                    height: 5,
                    width: box.maxWidth * v,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [accent.fade(0.55), accent],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.accent, this.solid = false});

  final String label;
  final Color accent;

  /// 직업만 채워서 강조한다 — 장비 목록에 묻히면 역할이 안 읽힌다.
  final bool solid;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: accent.fade(solid ? 0.18 : 0.06),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: accent.fade(solid ? 0.5 : 0.22)),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 9.5,
          letterSpacing: 1.2,
          fontWeight: solid ? FontWeight.w700 : FontWeight.w500,
          color: accent.fade(solid ? 1.0 : 0.72),
        ),
      ),
    );
  }
}

class _EnterButton extends StatefulWidget {
  const _EnterButton({
    required this.accent,
    required this.onTap,
    required this.label,
  });

  final Color accent;
  final VoidCallback? onTap;
  final String label;

  @override
  State<_EnterButton> createState() => _EnterButtonState();
}

class _EnterButtonState extends State<_EnterButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final on = widget.onTap != null;
    final accent = widget.accent;
    final lit = on && _hover;
    return MouseRegion(
      cursor: on ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          decoration: BoxDecoration(
            color: on ? accent.fade(lit ? 0.26 : 0.14) : const Color(0x14FFFFFF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: on ? accent.fade(lit ? 1.0 : 0.6) : const Color(0x22FFFFFF),
              width: lit ? 1.8 : 1.2,
            ),
            boxShadow: lit
                ? [BoxShadow(color: accent.fade(0.3), blurRadius: 20)]
                : null,
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 2.4,
              fontWeight: FontWeight.w700,
              color: on
                  ? accent.fade(lit ? 1.0 : 0.86)
                  : Colors.white.withValues(alpha: 0.25),
            ),
          ),
        ),
      ),
    );
  }
}

// ── 명부 ──────────────────────────────────────────────────────────────────

/// 오른쪽 명부 — 진영 · 직업으로 좁히고 격자에서 고른다.
class _RosterPanel extends StatelessWidget {
  const _RosterPanel({
    required this.artists,
    required this.jobs,
    required this.camp,
    required this.job,
    required this.focus,
    required this.columns,
    required this.tileExtent,
    required this.gap,
    required this.scroll,
    required this.tileKeys,
    required this.onCamp,
    required this.onJob,
    required this.onPick,
    required this.onEnter,
    required this.compact,
  });

  final bool compact;
  final List<Artist> artists;
  final List<Archetype> jobs;
  final Camp camp;
  final Archetype? job;
  final Artist focus;
  final int columns;
  final double tileExtent;
  final double gap;
  final ScrollController scroll;
  final Map<String, GlobalKey> tileKeys;
  final void Function(Camp) onCamp;
  final void Function(Archetype?) onJob;
  final void Function(Artist) onPick;
  final void Function(Artist) onEnter;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final pool = camp == Camp.player ? heroes : monsters;

    return Padding(
      padding: EdgeInsets.fromLTRB(compact ? 20 : 8, 8, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _Toggle(
                  label: t.heroesTab(heroes.length),
                  on: camp == Camp.player,
                  onTap: () => onCamp(Camp.player),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Toggle(
                  label: t.monstersTab(monsters.length),
                  on: camp == Camp.monster,
                  onTap: () => onCamp(Camp.monster),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            camp == Camp.player ? t.heroesHint : t.monstersHint,
            maxLines: 2,
            style: TextStyle(
              fontSize: 11,
              height: 1.4,
              color: Colors.white.withValues(alpha: 0.38),
            ),
          ),

          // 직업 필터. 몬스터는 넷뿐이라 거를 것이 없다.
          if (camp == Camp.player) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _Filter(
                  label: t.allFilter(pool.length),
                  on: job == null,
                  accent: const Color(0xFF57E8FF),
                  onTap: () => onJob(null),
                ),
                for (final j in jobs)
                  _Filter(
                    label:
                        '${t.job(j)}  ${pool.where((a) => a.job == j).length}',
                    on: job == j,
                    accent: _jobAccent(pool, j),
                    onTap: () => onJob(j),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),

          Expanded(
            child: GridView.builder(
              controller: scroll,
              padding: const EdgeInsets.only(bottom: 8),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisExtent: tileExtent,
                crossAxisSpacing: gap,
                mainAxisSpacing: gap,
              ),
              itemCount: artists.length,
              itemBuilder: (context, i) {
                final a = artists[i];
                // 바깥은 화살표 조작이 화면 안으로 끌어올 때 쓰는 손잡이,
                // 안쪽은 이 인물의 칸이라는 표시다.
                return KeyedSubtree(
                  key: tileKeys.putIfAbsent(a.id, GlobalKey.new),
                  child: _RosterTile(
                    key: ValueKey('tile-${a.id}'),
                    artist: a,
                    selected: a == focus,
                    onTap: () => onPick(a),
                    onDoubleTap: () => onEnter(a),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Text(
            t.pickHint,
            maxLines: 2,
            style: TextStyle(
              fontSize: 10,
              height: 1.4,
              color: Colors.white.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }

  /// 필터 칩의 색은 그 직업 첫 인물의 강조색에서 빌린다. 직업마다 색 대역을
  /// 갈라 두었으므로 필터 줄만 봐도 역할이 읽힌다.
  static Color _jobAccent(List<Artist> pool, Archetype j) =>
      pool.firstWhere((a) => a.job == j).accent;
}

class _Toggle extends StatelessWidget {
  const _Toggle({required this.label, required this.on, required this.onTap});

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: on
                ? const Color(0xFF57E8FF).withValues(alpha: 0.14)
                : Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: on
                  ? const Color(0xFF57E8FF).withValues(alpha: 0.6)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 2,
              fontWeight: FontWeight.w700,
              color: on
                  ? const Color(0xFFBFF3FF)
                  : Colors.white.withValues(alpha: 0.42),
            ),
          ),
        ),
      ),
    );
  }
}

class _Filter extends StatelessWidget {
  const _Filter({
    required this.label,
    required this.on,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final bool on;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: on ? accent.fade(0.18) : Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color:
                  on ? accent.fade(0.7) : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 0.6,
              fontWeight: on ? FontWeight.w700 : FontWeight.w500,
              color: on ? accent : Colors.white.withValues(alpha: 0.45),
            ),
          ),
        ),
      ),
    );
  }
}

/// 명부의 한 칸.
///
/// 초상은 **멈춰 있다.** 스물다섯 칸이 동시에 매 프레임 절차 렌더를 돌리면
/// 화면이 무거워지고, 어차피 눈은 한 칸에만 머문다. 마우스를 올리거나 고른
/// 칸만 시간이 흐른다.
class _RosterTile extends StatefulWidget {
  const _RosterTile({
    super.key,
    required this.artist,
    required this.selected,
    required this.onTap,
    required this.onDoubleTap,
  });

  final Artist artist;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;

  @override
  State<_RosterTile> createState() => _RosterTileState();
}

class _RosterTileState extends State<_RosterTile> {
  bool _hover = false;

  /// 칸마다 다른 시각에서 멈춰 있어야 명부가 복제 인간 줄로 보이지 않는다.
  late final double _phase = Rng.fromString(widget.artist.id).range(0, 6);

  DateTime? _lastTap;

  /// 두 번 누르기를 손으로 센다.
  ///
  /// [GestureDetector.onDoubleTap] 을 걸면 두 번째 누름을 기다리느라 **한 번
  /// 누르기가 0.3초 늦게** 도착한다. 명부를 훑는 내내 스테이지가 한 박자씩
  /// 뒤처지므로, 선택은 즉시 반영하고 연타만 따로 센다.
  void _tapped() {
    widget.onTap();
    final now = DateTime.now();
    final quick = _lastTap != null &&
        now.difference(_lastTap!) < const Duration(milliseconds: 400);
    _lastTap = now;
    if (quick) {
      _lastTap = null;
      widget.onDoubleTap();
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.artist;
    final on = widget.selected;
    final lit = on || _hover;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: _tapped,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          transform: Matrix4.translationValues(0, lit ? -3 : 0, 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: on
                  ? a.accent.fade(0.95)
                  : (_hover
                      ? a.accent.fade(0.5)
                      : Colors.white.withValues(alpha: 0.08)),
              width: on ? 2 : 1,
            ),
            boxShadow: on
                ? [BoxShadow(color: a.accent.fade(0.3), blurRadius: 20)]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(11)),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _LivePortrait(
                        artist: a,
                        detail: 0.3,
                        running: lit,
                        phase: _phase,
                      ),
                      // 고르지 않은 칸은 한 겹 눌러 둔다. 스물다섯 장이 전부
                      // 같은 밝기면 지금 무엇을 보고 있는지 사라진다.
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 140),
                        opacity: on ? 0.0 : (_hover ? 0.08 : 0.34),
                        child: const ColoredBox(color: Color(0xFF05070C)),
                      ),
                      if (a.sex != null)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Text(
                            a.sex!.symbol,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.0,
                              color: a.accent.fade(0.9),
                              shadows: const [
                                Shadow(color: Color(0xCC000000), blurRadius: 4),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 7),
                decoration: BoxDecoration(
                  color: on
                      ? a.accent.fade(0.10)
                      : Colors.white.withValues(alpha: 0.03),
                  borderRadius:
                      const BorderRadius.vertical(bottom: Radius.circular(11)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      a.name.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w700,
                        color: lit ? a.accent : Colors.white,
                      ),
                    ),
                    const SizedBox(height: 3),
                    // 직업 배지. 강조색을 옅게 깔아 두면 명부를 훑을 때 역할이
                    // 이름보다 먼저 읽힌다.
                    Text(
                      context.t.job(a.job).toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 8.5,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w600,
                        color: a.accent.fade(0.7),
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

/// 시간이 흐르는 초상.
///
/// [running] 이 `false` 면 [phase] 에서 멈춘 한 장을 그린다 — 그때는 티커가
/// 아예 돌지 않으므로 화면이 놀고 있는 칸에 프레임을 쓰지 않는다.
class _LivePortrait extends StatefulWidget {
  const _LivePortrait({
    required this.artist,
    required this.detail,
    required this.running,
    this.phase = 0,
  });

  final Artist artist;
  final double detail;
  final bool running;
  final double phase;

  @override
  State<_LivePortrait> createState() => _LivePortraitState();
}

class _LivePortraitState extends State<_LivePortrait>
    with SingleTickerProviderStateMixin {
  static const Duration _cycle = Duration(seconds: 12);

  late final AnimationController _c =
      AnimationController(vsync: this, duration: _cycle);

  @override
  void initState() {
    super.initState();
    if (widget.running) _c.repeat();
  }

  @override
  void didUpdateWidget(_LivePortrait old) {
    super.didUpdateWidget(old);
    if (widget.running && !_c.isAnimating) {
      _c.repeat();
    } else if (!widget.running && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => CustomPaint(
          painter: ArtistPortrait(
            widget.artist,
            detail: widget.detail,
            time: widget.phase + _c.value * _cycle.inSeconds,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}
