import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provis/provis.dart';

/// 캐릭터 만드는 법 — 실행되는 예제.
///
/// ```bash
/// cd example && flutter run -t lib/create_character.dart
/// ```
///
/// ## 이 예제가 가르치는 것
///
/// provis 로 캐릭터를 만드는 길은 둘이고, 이 앱은 그중 **선언형**을 보여 준다.
/// [CharacterBuild] 하나를 선언하면 명부 초상과 게임 액터가 한꺼번에 나오고,
/// 둘이 같은 [HumanoidRenderer] 로 그려지므로 어긋날 수가 없다.
///
/// 왼쪽 패널의 값을 바꾸면 오른쪽 두 화면이 함께 바뀐다 — 왼쪽 큰 그림이 명부
/// 초상, 아래 여덟 칸이 게임 맵에서 한 바퀴 도는 모습이다. **이 둘이 언제나
/// 같은 인물이라는 것**이 이 구조의 요점이다.
///
/// 화면 하단에 지금 상태를 그대로 붙여 넣을 수 있는 Dart 코드가 나온다.
/// 마음에 드는 조합이 나오면 복사해 `characters/recruits.dart` 에 넣으면 된다.
void main() => runApp(const CreateCharacterApp());

class CreateCharacterApp extends StatelessWidget {
  const CreateCharacterApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'provis — 캐릭터 만들기',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF7AA2FF),
            brightness: Brightness.dark,
          ),
          fontFamily: 'monospace',
        ),
        home: const _Workbench(),
      );
}

/// 고를 수 있는 강조색. 직업마다 대역을 갈라 두면 명부에서 역할이 먼저 읽힌다.
const _accents = <String, Color>{
  '전사 · 금': Color(0xFFD9A441),
  '전사 · 주홍': Color(0xFFE86A3A),
  '마법사 · 청': Color(0xFF6FA8FF),
  '마법사 · 보라': Color(0xFF9A6BFF),
  '궁수 · 연두': Color(0xFF8FD44A),
  '군인 · 황토': Color(0xFFB8A05A),
  '사이보그 · 청록': Color(0xFF3AE0FF),
  '사이보그 · 주황': Color(0xFFFF9A3A),
};

const _skins = <Color>[
  Color(0xFF8A5F44),
  Color(0xFFB07A55),
  Color(0xFFC08A66),
  Color(0xFFD9A882),
  Color(0xFFE8C4A0),
  Color(0xFFCFA98C),
];

const _hairs = <Color>[
  Color(0xFF1E1A22),
  Color(0xFF3A2A1E),
  Color(0xFF6E5432),
  Color(0xFF8C2F2F),
  Color(0xFFDCE8F4),
  Color(0xFFEDE4D6),
];

const _cloths = <Color>[
  Color(0xFF7A2E2E),
  Color(0xFF2C3A78),
  Color(0xFF3E5230),
  Color(0xFF3E4632),
  Color(0xFF1E2630),
  Color(0xFF3B2E6E),
];

class _Workbench extends StatefulWidget {
  const _Workbench();

  @override
  State<_Workbench> createState() => _WorkbenchState();
}

class _WorkbenchState extends State<_Workbench>
    with SingleTickerProviderStateMixin {
  // ── 선언할 값들 ─────────────────────────────────────────────────────
  Archetype archetype = Archetype.knight;
  Sex sex = Sex.male;
  WeaponKind weapon = WeaponKind.sword;
  HeadGear headGear = HeadGear.halfHelm;
  Color accent = _accents['전사 · 금']!;
  Color skin = _skins[2];
  Color hair = _hairs[1];
  Color cloth = _cloths[0];
  double armorHeaviness = 0.9;
  double muscle = 0.8;
  double hairLength = 0.3;
  bool hasCape = true;
  bool hasPauldrons = true;
  bool hasShield = true;
  bool glowRunes = false;

  late final Ticker _ticker = Ticker((d) {
    setState(() => _t = d.inMilliseconds / 1000.0);
  })
    ..start();
  double _t = 0;

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  /// 지금 상태로부터 캐릭터를 만든다.
  ///
  /// **이 메서드가 이 예제의 핵심이다.** 캐릭터 하나는 결국 이 선언 하나다.
  BuiltArtist get artist => BuiltArtist(
        id: 'workbench',
        name: 'New Recruit',
        title: '작업대에서 만드는 중',
        blurb: '왼쪽 값을 바꾸면 이 인물이 바뀐다.',
        build: CharacterBuild(
          archetype: archetype,
          sex: sex,
          palette: paletteOf(
            skin: skin,
            hair: hair,
            cloth: cloth,
            accent: accent,
          ),
          weapon: weapon,
          headGear: headGear,
          hasCape: hasCape,
          hasPauldrons: hasPauldrons,
          hasShield: hasShield,
          armorHeaviness: armorHeaviness,
          muscle: muscle,
          hairLength: hairLength,
          glowRunes: glowRunes,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final a = artist;
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E16),
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: 330, child: _panel()),
            const VerticalDivider(width: 1),
            Expanded(
              child: Column(
                children: [
                  Expanded(flex: 5, child: _portrait(a)),
                  const Divider(height: 1),
                  Expanded(flex: 4, child: _turntable(a)),
                  const Divider(height: 1),
                  SizedBox(height: 168, child: _code()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 명부 초상 ───────────────────────────────────────────────────────

  Widget _portrait(Artist a) => Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _PortraitPainter(a, _t)),
          ),
          const Positioned(
            left: 14,
            top: 10,
            child: Text('명부 초상 — Artist.paint()',
                style: TextStyle(fontSize: 11, color: Colors.white38)),
          ),
        ],
      );

  // ── 게임 액터 8방향 ─────────────────────────────────────────────────

  Widget _turntable(Artist a) => Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _TurntablePainter(a, _t)),
          ),
          const Positioned(
            left: 14,
            top: 8,
            child: Text('게임 액터 — riggedFromArtist() · 걷기 · 8방향',
                style: TextStyle(fontSize: 11, color: Colors.white38)),
          ),
        ],
      );

  // ── 붙여 넣을 코드 ──────────────────────────────────────────────────

  String get _source {
    String hex(Color c) =>
        '0x${(c.toARGB32() & 0xFFFFFFFF).toRadixString(16).toUpperCase().padLeft(8, '0')}';
    final opts = <String>[
      if (hasCape) 'hasCape: true',
      if (hasPauldrons) 'hasPauldrons: true',
      if (hasShield) 'hasShield: true',
      if (glowRunes) 'glowRunes: true',
    ];
    return '''
final myCharacter = BuiltArtist(
  id: 'my_character', name: 'Name', title: 'Title', blurb: '한 줄 소개.',
  build: CharacterBuild(
    archetype: Archetype.${archetype.name},
    sex: Sex.${sex.name},
    palette: paletteOf(
      skin: Color(${hex(skin)}), hair: Color(${hex(hair)}),
      cloth: Color(${hex(cloth)}), accent: Color(${hex(accent)}),
    ),
    weapon: WeaponKind.${weapon.name},
    headGear: HeadGear.${headGear.name},
    armorHeaviness: ${armorHeaviness.toStringAsFixed(2)}, muscle: ${muscle.toStringAsFixed(2)}, hairLength: ${hairLength.toStringAsFixed(2)},
    ${opts.join(', ')}${opts.isEmpty ? '' : ','}
  ),
);''';
  }

  Widget _code() => Container(
        width: double.infinity,
        color: const Color(0xFF070A11),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('이 값을 그대로 characters/recruits.dart 에 붙여 넣으면 된다',
                style: TextStyle(
                    fontSize: 10, color: accent.withValues(alpha: 0.8))),
            const SizedBox(height: 6),
            Expanded(
              child: SingleChildScrollView(
                child: SelectableText(
                  _source.trim(),
                  style: const TextStyle(
                      fontSize: 10.5, height: 1.45, color: Color(0xFFB8C4D8)),
                ),
              ),
            ),
          ],
        ),
      );

  // ── 조작 패널 ───────────────────────────────────────────────────────

  Widget _panel() => ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          const Text('CharacterBuild',
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 1)),
          const SizedBox(height: 4),
          const Text('캐릭터 하나 = 이 선언 하나',
              style: TextStyle(fontSize: 10, color: Colors.white38)),
          const SizedBox(height: 18),

          _label('archetype — 체형과 기본 장비의 대역'),
          _chips(Archetype.values, archetype, (v) {
            setState(() {
              archetype = v;
              // 원형을 바꾸면 그 원형에 맞는 기본값으로 따라가는 편이 편하다.
              weapon = switch (v) {
                Archetype.mage => WeaponKind.staff,
                Archetype.ranger => WeaponKind.bow,
                Archetype.berserker => WeaponKind.greatsword,
                Archetype.assassin => WeaponKind.daggers,
                _ => WeaponKind.sword,
              };
              armorHeaviness = switch (v) {
                Archetype.mage => 0.05,
                Archetype.ranger => 0.25,
                Archetype.assassin => 0.35,
                Archetype.berserker => 0.5,
                _ => 0.9,
              };
            });
          }, (v) => v.label),

          _label('sex'),
          _chips(Sex.values, sex, (v) => setState(() => sex = v),
              (v) => v.label),

          _label('weapon'),
          _chips(WeaponKind.values, weapon, (v) => setState(() => weapon = v),
              (v) => v.name),

          _label('headGear — 비워 두면 시드가 정한다. 반드시 명시할 것'),
          _chips(HeadGear.values, headGear,
              (v) => setState(() => headGear = v), (v) => v.name),

          _label('accent — 이 색이 정체성이다'),
          _swatches(_accents.values.toList(), accent,
              (c) => setState(() => accent = c)),

          _label('skin'),
          _swatches(_skins, skin, (c) => setState(() => skin = c)),
          _label('hair'),
          _swatches(_hairs, hair, (c) => setState(() => hair = c)),
          _label('cloth'),
          _swatches(_cloths, cloth, (c) => setState(() => cloth = c)),

          _slider('armorHeaviness — 0 천, 1 판금', armorHeaviness,
              (v) => setState(() => armorHeaviness = v)),
          _slider('muscle', muscle, (v) => setState(() => muscle = v)),
          _slider('hairLength', hairLength,
              (v) => setState(() => hairLength = v)),

          const SizedBox(height: 8),
          _toggle('hasCape', hasCape, (v) => setState(() => hasCape = v)),
          _toggle('hasPauldrons', hasPauldrons,
              (v) => setState(() => hasPauldrons = v)),
          _toggle('hasShield', hasShield, (v) => setState(() => hasShield = v)),
          _toggle('glowRunes', glowRunes, (v) => setState(() => glowRunes = v)),
        ],
      );

  Widget _label(String s) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 7),
        child: Text(s,
            style: const TextStyle(fontSize: 10, color: Colors.white54)),
      );

  Widget _chips<T>(List<T> all, T current, ValueChanged<T> onPick,
          String Function(T) label) =>
      Wrap(
        spacing: 5,
        runSpacing: 5,
        children: [
          for (final v in all)
            GestureDetector(
              onTap: () => onPick(v),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: v == current
                      ? accent.withValues(alpha: 0.20)
                      : Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: v == current
                        ? accent.withValues(alpha: 0.7)
                        : Colors.white12,
                  ),
                ),
                child: Text(label(v), style: const TextStyle(fontSize: 10)),
              ),
            ),
        ],
      );

  Widget _swatches(List<Color> all, Color current, ValueChanged<Color> onPick) =>
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final c in all)
            GestureDetector(
              onTap: () => onPick(c),
              child: Container(
                width: 30,
                height: 22,
                decoration: BoxDecoration(
                  color: c,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: c == current ? Colors.white : Colors.white24,
                    width: c == current ? 2 : 1,
                  ),
                ),
              ),
            ),
        ],
      );

  Widget _slider(String name, double v, ValueChanged<double> onChanged) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('$name  ·  ${v.toStringAsFixed(2)}'),
          SizedBox(
            height: 22,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 6),
                activeTrackColor: accent,
                thumbColor: accent,
              ),
              child: Slider(value: v, onChanged: onChanged),
            ),
          ),
        ],
      );

  Widget _toggle(String name, bool v, ValueChanged<bool> onChanged) => SizedBox(
        height: 32,
        child: Row(
          children: [
            SizedBox(
              width: 40,
              child: Transform.scale(
                scale: 0.72,
                alignment: Alignment.centerLeft,
                child: Switch(
                    value: v, onChanged: onChanged, activeThumbColor: accent),
              ),
            ),
            Text(name, style: const TextStyle(fontSize: 11)),
          ],
        ),
      );
}

/// 명부 초상 — `Artist.paint()` 를 그대로 부른다.
class _PortraitPainter extends CustomPainter {
  _PortraitPainter(this.artist, this.t);
  final Artist artist;
  final double t;

  @override
  void paint(Canvas c, Size size) {
    final rect = Offset.zero & size;
    c.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: artist.moodSky,
        ).createShader(rect),
    );
    final f = artist.framing;
    final k = math.min(size.height * 0.92 / f.height, size.width * 0.9 / f.width);
    c.save();
    c.translate(size.width / 2, size.height - size.height * 0.04);
    c.scale(k);
    c.translate(-f.center.dx, -f.bottom);
    artist.paint(c, t);
    c.restore();
  }

  @override
  bool shouldRepaint(_PortraitPainter old) =>
      old.t != t || old.artist != artist;
}

/// 게임 액터 8방향 — `riggedFromArtist()` 가 만든 골격을 걷게 한다.
class _TurntablePainter extends CustomPainter {
  _TurntablePainter(this.artist, this.t);
  final Artist artist;
  final double t;

  static const _iso = IsoView(tileWidth: 128, tileHeight: 64);

  @override
  void paint(Canvas c, Size size) {
    c.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF141A26));
    final cw = size.width / 8;
    for (var d = 0; d < 8; d++) {
      final actor = riggedFromArtist(
        artist,
        tile: Offset.zero,
        height: math.min(size.height * 0.74, cw * 1.5),
      )
        ..yaw = d * math.pi / 4
        ..play('walk')
        // 칸마다 위상을 어긋내면 정지 화면에서도 걸음이 읽힌다.
        ..update(t * 0.9 + d * 0.11);

      c.save();
      c.clipRect(Rect.fromLTWH(d * cw, 0, cw, size.height));
      c.translate(d * cw + cw / 2, size.height * 0.94);
      paintRiggedActor(c, actor, _iso, artist.light, t);
      c.restore();
    }
  }

  @override
  bool shouldRepaint(_TurntablePainter old) =>
      old.t != t || old.artist != artist;
}

/// 매 프레임 콜백. `flutter/scheduler.dart` 의 것과 같은 역할이지만, 예제가
/// import 를 하나라도 덜 갖도록 최소 구현을 둔다.
class Ticker {
  Ticker(this.onTick);
  final void Function(Duration) onTick;
  bool _running = false;
  Duration _elapsed = Duration.zero;
  Duration? _last;

  void start() {
    if (_running) return;
    _running = true;
    WidgetsBinding.instance.addPersistentFrameCallback(_frame);
  }

  void _frame(Duration now) {
    if (!_running) return;
    _elapsed += now - (_last ?? now);
    _last = now;
    onTick(_elapsed);
    WidgetsBinding.instance.scheduleFrame();
  }

  void dispose() => _running = false;
}
