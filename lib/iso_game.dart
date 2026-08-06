import 'dart:math' as math;

import 'package:flame/components.dart' hide mix;
import 'package:flame/game.dart' hide mix;
import 'package:flutter/material.dart';
import 'dart:ui' as ui;

import 'src/art/roster.dart';
import 'src/core/palette.dart';
import 'src/core/shading.dart';
import 'src/iso/iso_stage.dart';
import 'src/render/iso.dart';

/// 2.5D 아이소메트릭 게임 화면.
///
///   flutter run -t lib/iso_game.dart
///
/// 이 화면의 요점은 **완성된 수작업 캐릭터가 아이소 맵 위에 그대로 선다**는
/// 것이다. `art/pc`·`art/mob` 의 9종은 한 줄도 고치지 않았다 — 좌표 변환만
/// `iso_stage.dart` 가 맡는다.
void main() {
  runApp(const IsoGameApp());
}

class IsoGameApp extends StatelessWidget {
  const IsoGameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vis — Isometric Field',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const _IsoScreen(),
    );
  }
}

class _IsoScreen extends StatefulWidget {
  const _IsoScreen();

  @override
  State<_IsoScreen> createState() => _IsoScreenState();
}

class _IsoScreenState extends State<_IsoScreen> {
  late final IsoField _field = IsoField();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF05070C),
      body: Stack(
        children: [
          GameWidget(game: _field),
          Positioned(
            left: 24,
            top: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ISOMETRIC FIELD',
                  style: TextStyle(
                    fontSize: 22,
                    letterSpacing: 4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '수작업 캐릭터 9종이 2.5D 타일 위에 그대로 선다 — art/ 는 무수정',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 24,
            top: 16,
            child: Row(
              children: [
                for (final (i, name) in const [
                  (0, '정오'),
                  (1, '황혼'),
                  (2, '달빛'),
                  (3, '화톳불'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: _Chip(
                      label: name,
                      on: _field.preset == i,
                      onTap: () => setState(() => _field.preset = i),
                    ),
                  ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 22,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Chip(
                    label: '카메라 −',
                    on: false,
                    onTap: () => setState(() => _field.zoomOut()),
                  ),
                  const SizedBox(width: 10),
                  _Chip(
                    label: '카메라 +',
                    on: false,
                    onTap: () => setState(() => _field.zoomIn()),
                  ),
                  const SizedBox(width: 10),
                  _Chip(
                    label: _field.showGrid ? '격자 끄기' : '격자 켜기',
                    on: _field.showGrid,
                    onTap: () => setState(() => _field.showGrid = !_field.showGrid),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.on, required this.onTap});

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: on
              ? const Color(0xFF57E8FF).withValues(alpha: 0.16)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: on
                ? const Color(0xFF57E8FF).withValues(alpha: 0.7)
                : Colors.white.withValues(alpha: 0.15),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            letterSpacing: 1,
            color: on ? const Color(0xFFBFF3FF) : Colors.white70,
          ),
        ),
      ),
    );
  }
}

/// 아이소 필드 본체.
class IsoField extends FlameGame {
  static const int cols = 7;
  static const int rows = 7;

  double clock = 0;
  int preset = 0;
  bool showGrid = true;
  double zoom = 1.0;

  LightRig get light => LightRig.preset(preset);

  IsoView get iso => IsoView(tileWidth: 156 * zoom, tileHeight: 78 * zoom);

  void zoomIn() => zoom = math.min(1.6, zoom + 0.15);
  void zoomOut() => zoom = math.max(0.55, zoom - 0.15);

  late final List<IsoActor> actors = _layout();

  /// 영웅은 앞줄, 괴물은 뒷줄에 세운다.
  ///
  /// 배치의 요점은 **타일 대비 캐릭터 키**다. 실제 아이소 게임에서 인간형은
  /// 타일 폭의 1.2~1.6배로 서고, 그보다 크면 격자가 묻혀 평면이 사라진다.
  /// 여기서는 타일 150px 에 인간형 210px(1.4배), 대형 몬스터 280px 를 쓴다.
  /// 대각선으로 흩어 세워 아이소의 깊이가 드러나게 했다.
  List<IsoActor> _layout() {
    final out = <IsoActor>[];

    // 영웅 — 앞줄 대각선. 열마다 한 칸씩 앞으로 나와 겹침을 피한다.
    const heroSpots = [
      Offset(0.7, 5.9),
      Offset(2.0, 6.3),
      Offset(3.3, 5.7),
      Offset(4.6, 6.2),
      Offset(5.9, 5.6),
    ];
    for (final (i, a) in heroes.indexed) {
      out.add(IsoActor(
        artist: a,
        tile: heroSpots[i % heroSpots.length],
        height: a.id == 'seraphine' ? 225 : 210,
        timeOffset: i * 0.63,
      ));
    }

    // 괴물 — 뒷줄. 덩치 차이를 키로 드러낸다.
    const mobSpots = [
      Offset(1.1, 1.0),
      Offset(2.9, 0.7),
      Offset(4.7, 1.2),
      Offset(6.1, 0.6),
    ];
    const mobHeight = {
      'gorehide': 250.0,
      'vaelmorth': 285.0,
      'mourne': 240.0,
      'chitinis': 235.0,
    };
    for (final (i, a) in monsters.indexed) {
      out.add(IsoActor(
        artist: a,
        tile: mobSpots[i % mobSpots.length],
        height: mobHeight[a.id] ?? 235,
        facesLeft: true,
        timeOffset: 0.4 + i * 0.87,
      ));
    }
    return out;
  }

  @override
  Color backgroundColor() => const Color(0xFF05070C);

  @override
  Future<void> onLoad() async {
    await add(_FieldLayer());
  }

  @override
  void update(double dt) {
    super.update(dt);
    clock += dt;
  }
}

class _FieldLayer extends Component with HasGameReference<IsoField> {
  @override
  void render(Canvas canvas) {
    final g = game;
    final iso = g.iso;
    final l = g.light;
    final view = g.size.toSize();

    // 하늘/원경 — 조명 프리셋의 환경광에서 파생시켜 캐릭터와 같은 공기를 쓴다.
    canvas.drawRect(
      Offset.zero & view,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(view.width / 2, 0),
          Offset(view.width / 2, view.height),
          [
            l.ambient.darken(0.35),
            l.ambient.lighten(0.05),
            l.bounce.darken(0.45),
          ],
          const [0.0, 0.55, 1.0],
        ),
    );

    final off = isoCameraOffset(iso, IsoField.cols, IsoField.rows, view) +
        Offset(0, view.height * 0.06);

    canvas.save();
    canvas.translate(off.dx, off.dy);

    if (g.showGrid) {
      paintIsoGround(canvas, iso, IsoField.cols, IsoField.rows, l);
    }

    paintIsoActors(
      canvas,
      g.actors,
      iso,
      g.clock,
      detailOf: (a) => isoDetailFor(a),
    );

    canvas.restore();

    // 대기 원근. 먼 곳이 환경광으로 흐려지면 평면이던 화면에 깊이가 생긴다.
    paintIsoHaze(canvas, Offset.zero & view, l, strength: 0.45);
  }
}
