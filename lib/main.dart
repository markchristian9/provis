import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'src/actor/humanoid_renderer.dart';
import 'src/actor/spec.dart';
import 'src/anim/animator.dart';
import 'src/anim/library.dart';
import 'src/core/rng.dart';
import 'src/render/iso.dart';
// flame 이 재수출하는 vector_math 에도 mix() 가 있어 이름이 겹친다.
import 'src/render/palette.dart' as pal;
import 'src/core/shading.dart';
import 'src/rig/body.dart';

void main() {
  runApp(const VisApp());
}

class VisApp extends StatelessWidget {
  const VisApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Procedural Actor Viewer',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF7AA2FF),
            brightness: Brightness.dark,
          ),
          fontFamily: 'monospace',
        ),
        home: const ViewerPage(),
      );
}

/// 뷰어의 모든 가변 상태.
///
/// 게임 루프와 위젯 트리가 같은 인스턴스를 본다. Flame 컴포넌트가 매 프레임
/// 읽고, 버튼이 쓰며, 바뀐 값은 [revision] 으로 알린다.
class ViewerModel extends ChangeNotifier {
  final Animator animator = Animator();

  int seed = 7;
  bool beast = false;
  int lightPreset = 0;
  double yaw = math.pi * 0.30;

  /// 현재 재생 중인 클립 이름. AUTO 가 넘길 때도 갱신되어 버튼 강조가 따라간다.
  String clipName = Anims.idle.name;

  late HumanoidSpec spec = HumanoidSpec.generate(seed);
  late HumanoidRenderer renderer = _buildRenderer();

  LightRig get light => LightRig.preset(lightPreset);

  /// 8방향 나침반 표기. 아이소 씬에서 지금 어느 쪽을 보고 있는지 읽는다.
  String get facingLabel =>
      const ['S', 'SE', 'E', 'NE', 'N', 'NW', 'W', 'SW'][Facing(yaw).octant];

  /// 활을 든 상태로 그릴지. 사격 동작에서만 원거리 무기로 갈아 쥔다.
  bool get ranged =>
      animator.current.name == Anims.shoot.name || spec.weapon == WeaponKind.bow;

  HumanoidRenderer _buildRenderer() {
    if (!beast) return HumanoidRenderer(spec);
    // 짐승형은 같은 골격 코드에 비율과 색만 바꿔 얹는다. 다리가 짧고 팔이
    // 길며 구부정하므로, 같은 걷기 클립이 전혀 다른 걸음걸이로 읽힌다.
    final r = Rng(seed ^ 0x5EED);
    return HumanoidRenderer(
      spec,
      body: Body.beast(r, height: spec.height * 1.12),
      palette: pal.Palette.monster(Rng(seed ^ 0xB0A5)),
      beast: true,
    );
  }

  void _rebuild() {
    spec = HumanoidSpec.generate(seed);
    renderer = _buildRenderer();
    notifyListeners();
  }

  void reroll() {
    seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF;
    _rebuild();
  }

  void toggleBeast() {
    beast = !beast;
    _rebuild();
  }

  void cycleLight() {
    lightPreset = (lightPreset + 1) % 4;
    notifyListeners();
  }

  void turn(int steps) {
    yaw = (yaw + steps * math.pi / 4) % (math.pi * 2);
    notifyListeners();
  }

  void play(String name) {
    animator.auto = false;
    animator.playByName(name);
    clipName = name;
    notifyListeners();
  }

  void toggleAuto() {
    animator.auto = !animator.auto;
    notifyListeners();
  }

  void setSpeed(double v) {
    animator.speed = v;
    notifyListeners();
  }

  /// 게임 루프가 매 프레임 호출한다. AUTO 가 클립을 넘겼으면 UI 에 알린다.
  void tick(double dt) {
    animator.update(dt);
    if (animator.current.name != clipName) {
      clipName = animator.current.name;
      notifyListeners();
    } else if (animator.auto) {
      // 진행 바를 계속 갱신한다.
      notifyListeners();
    }
  }
}

// ───────────────────────────────────────────────────────────── 게임

class ViewerGame extends FlameGame {
  ViewerGame(this.model);

  final ViewerModel model;

  @override
  Color backgroundColor() => const Color(0xFF0B0E17);

  @override
  Future<void> onLoad() async {
    world.add(IsoFloor(model));
    world.add(ActorComponent(model));
    camera.viewfinder
      ..zoom = 2.0
      ..position = Vector2(0, -70);
  }

  @override
  void update(double dt) {
    super.update(dt);
    model.tick(dt);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    // 세로가 좁은 창에서도 캐릭터 전신과 무기가 들어오도록 맞춘다.
    camera.viewfinder.zoom = (size.y / 320).clamp(1.1, 2.6);
  }
}

/// 아이소 지면. 캐릭터가 어느 평면 위에 서 있는지 보여 주는 최소한의 격자다.
class IsoFloor extends Component {
  IsoFloor(this.model);

  final ViewerModel model;

  @override
  int get priority => -1000;

  @override
  void render(Canvas canvas) {
    const iso = kIso;
    final light = model.light;
    const span = 4;

    // 지면 자체의 색. 씬 환경광과 같은 계열이어야 캐릭터가 그 위에 놓인다.
    for (var x = -span; x <= span; x++) {
      for (var y = -span; y <= span; y++) {
        final c = iso.project(x.toDouble(), y.toDouble());
        final d = math.sqrt(x * x + y * y) / (span * 1.4);
        final fade = (1 - d).clamp(0.0, 1.0);
        if (fade <= 0.01) continue;
        final tile = Path()
          ..moveTo(c.dx, c.dy - iso.tileHeight / 2)
          ..lineTo(c.dx + iso.tileWidth / 2, c.dy)
          ..lineTo(c.dx, c.dy + iso.tileHeight / 2)
          ..lineTo(c.dx - iso.tileWidth / 2, c.dy)
          ..close();
        final checker = (x + y) % 2 == 0;
        canvas.drawPath(
          tile,
          Paint()
            ..color = pal
                .mix(
                  light.ambient,
                  checker ? light.bounce : const Color(0xFF000000),
                  checker ? 0.16 : 0.35,
                )
                .withValues(alpha: 0.85 * fade),
        );
        canvas.drawPath(
          tile,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.7
            ..color = light.rim.withValues(alpha: 0.06 * fade),
        );
      }
    }
  }
}

/// 캐릭터 한 명. 아이소 접지점에 놓이고, 국소 공간에서 골격이 그려진다.
class ActorComponent extends PositionComponent {
  ActorComponent(this.model);

  final ViewerModel model;

  /// 액터가 서 있는 월드 타일. 깊이 정렬 키의 출처다.
  Vector2 worldTile = Vector2.zero();

  @override
  void update(double dt) {
    super.update(dt);
    // 정렬 키는 화면 y 가 아니라 월드 (wx + wy) 다.
    priority = (kIso.depthKey(worldTile.x, worldTile.y) * 1000).round();
    final anchorAt = kIso.project(worldTile.x, worldTile.y);
    position = Vector2(anchorAt.dx, anchorAt.dy);
  }

  @override
  void render(Canvas canvas) {
    model.renderer.paint(
      canvas,
      pose: model.animator.pose,
      light: model.light,
      facing: Facing(model.yaw),
      time: model.animator.clock,
      detail: 1.0,
      ranged: model.ranged,
    );
  }
}

// ───────────────────────────────────────────────────────────── UI

class ViewerPage extends StatefulWidget {
  const ViewerPage({super.key});

  @override
  State<ViewerPage> createState() => _ViewerPageState();
}

class _ViewerPageState extends State<ViewerPage> {
  late final ViewerModel model = ViewerModel();
  late final ViewerGame game = ViewerGame(model);

  @override
  void dispose() {
    model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0E17),
      body: Stack(
        children: [
          Positioned.fill(child: GameWidget(game: game)),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: SafeArea(
              child: AnimatedBuilder(
                animation: model,
                builder: (_, _) => _TopBar(model: model),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: AnimatedBuilder(
                animation: model,
                builder: (_, _) => _AnimationBar(model: model),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.model});

  final ViewerModel model;

  @override
  Widget build(BuildContext context) {
    final s = model.spec;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  model.beast ? 'BEAST' : s.archetype.label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3,
                    color: Color(0xFFE8EEFF),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'seed ${model.seed}  ·  ${s.weapon.name}  ·  ${s.headGear.name}'
                  '  ·  facing ${model.facingLabel}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
          ),
          _IconChip(icon: Icons.casino, tip: '새 시드', onTap: model.reroll),
          const SizedBox(width: 6),
          _IconChip(
            icon: model.beast ? Icons.pets : Icons.person,
            tip: '영웅 / 몬스터',
            active: model.beast,
            onTap: model.toggleBeast,
          ),
          const SizedBox(width: 6),
          _IconChip(icon: Icons.wb_twilight, tip: '조명', onTap: model.cycleLight),
          const SizedBox(width: 6),
          _IconChip(
            icon: Icons.rotate_left,
            tip: '왼쪽으로 회전',
            onTap: () => model.turn(-1),
          ),
          const SizedBox(width: 6),
          _IconChip(
            icon: Icons.rotate_right,
            tip: '오른쪽으로 회전',
            onTap: () => model.turn(1),
          ),
        ],
      ),
    );
  }
}

/// 애니메이션 선택 바. 요청된 9개 동작과 AUTO 순환이 여기 모여 있다.
class _AnimationBar extends StatelessWidget {
  const _AnimationBar({required this.model});

  final ViewerModel model;

  @override
  Widget build(BuildContext context) {
    final auto = model.animator.auto;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF0B0E17).withValues(alpha: 0.0),
            const Color(0xFF0B0E17).withValues(alpha: 0.88),
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // AUTO 가 켜져 있으면 다음 동작까지 남은 시간을 보여 준다.
          if (auto)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: model.animator.autoProgress,
                  minHeight: 3,
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  valueColor: const AlwaysStoppedAnimation(Color(0xFF7AA2FF)),
                ),
              ),
            ),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final clip in Anims.all)
                _ClipChip(
                  label: clip.label,
                  selected: model.clipName == clip.name,
                  dimmed: auto,
                  onTap: () => model.play(clip.name),
                ),
              _AutoChip(active: auto, onTap: model.toggleAuto),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'SPEED',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 2,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              ),
              SizedBox(
                width: 220,
                child: Slider(
                  value: model.animator.speed,
                  min: 0.1,
                  max: 2.0,
                  onChanged: model.setSpeed,
                ),
              ),
              SizedBox(
                width: 42,
                child: Text(
                  '${model.animator.speed.toStringAsFixed(2)}x',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ClipChip extends StatelessWidget {
  const _ClipChip({
    required this.label,
    required this.selected,
    required this.dimmed,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool dimmed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF7AA2FF);
    return Material(
      color: selected
          ? accent.withValues(alpha: dimmed ? 0.22 : 0.34)
          : Colors.white.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        borderRadius: BorderRadius.circular(7),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: selected
                  ? accent.withValues(alpha: 0.9)
                  : Colors.white.withValues(alpha: 0.10),
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 0.6,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.68),
            ),
          ),
        ),
      ),
    );
  }
}

/// AUTO 토글. 켜면 애니메이터가 전 동작을 순서대로 돌린다.
class _AutoChip extends StatelessWidget {
  const _AutoChip({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const on = Color(0xFF4ADE9B);
    return Material(
      color: active ? on.withValues(alpha: 0.30) : Colors.white.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        borderRadius: BorderRadius.circular(7),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: active ? on : Colors.white.withValues(alpha: 0.10),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                active ? Icons.autorenew : Icons.play_circle_outline,
                size: 14,
                color: active ? on : Colors.white.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 6),
              Text(
                'AUTO',
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 1.6,
                  fontWeight: FontWeight.w700,
                  color: active ? Colors.white : Colors.white.withValues(alpha: 0.68),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconChip extends StatelessWidget {
  const _IconChip({
    required this.icon,
    required this.tip,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String tip;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tip,
      child: Material(
        color: active
            ? const Color(0xFF7AA2FF).withValues(alpha: 0.26)
            : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(7),
        child: InkWell(
          borderRadius: BorderRadius.circular(7),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, size: 17, color: Colors.white.withValues(alpha: 0.85)),
          ),
        ),
      ),
    );
  }
}
