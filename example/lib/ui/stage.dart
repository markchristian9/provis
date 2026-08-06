import 'dart:math' as math;

import 'package:flame/components.dart' hide mix;
import 'package:flame/extensions.dart' hide mix;
import 'package:flame/game.dart' hide mix;
import 'package:flutter/material.dart';

import 'package:provis/provis.dart';
import '../characters/roster.dart';
import 'backdrop.dart';

/// 화면이 들고 있는 선택 상태.
///
/// Flame 게임 루프와 위젯 트리가 같은 인스턴스를 본다. 게임은 매 프레임
/// 읽기만 하고, 쓰는 쪽은 카드 탭뿐이다.
class Matchup extends ChangeNotifier {
  Artist _hero = heroes.first;
  Artist _monster = monsters.first;

  Artist get hero => _hero;
  Artist get monster => _monster;

  void choose(Artist a) {
    if (a.camp == Camp.player) {
      if (identical(a, _hero)) return;
      _hero = a;
    } else {
      if (identical(a, _monster)) return;
      _monster = a;
    }
    notifyListeners();
  }

  bool isChosen(Artist a) => identical(a, _hero) || identical(a, _monster);
}

/// 영웅과 괴물이 마주 서는 무대.
class StageGame extends FlameGame {
  StageGame(this.matchup);

  final Matchup matchup;

  /// 누적 시간. 모든 캐릭터 애니메이션이 이 값 하나의 함수다.
  double clock = 0;

  @override
  Color backgroundColor() => const Color(0xFF05070C);

  @override
  Future<void> onLoad() async {
    await addAll([
      _BackdropLayer(),
      _ActorLayer(Camp.player),
      _ActorLayer(Camp.monster),
      _ForegroundLayer(),
    ]);
  }

  @override
  void update(double dt) {
    super.update(dt);
    clock += dt;
  }
}

class _BackdropLayer extends Component with HasGameReference<StageGame> {
  _BackdropLayer() : super(priority: 0);

  @override
  void render(Canvas c) {
    final s = game.size.toSize();
    paintBackdrop(
      c,
      s,
      game.matchup.hero.moodSky,
      game.matchup.monster.moodSky,
      game.clock,
    );
  }
}

class _ActorLayer extends Component with HasGameReference<StageGame> {
  _ActorLayer(this.camp)
      : super(priority: camp == Camp.player ? 2 : 1);

  final Camp camp;

  @override
  void render(Canvas c) {
    final s = game.size.toSize();
    if (s.width < 8 || s.height < 8) return;
    final a =
        camp == Camp.player ? game.matchup.hero : game.matchup.monster;

    // 두 캐릭터가 서로를 바라보도록 필요한 쪽만 좌우를 뒤집는다.
    final flip = camp == Camp.player && a.facesLeft;

    final scale = math.min(
      s.height * 0.96 / kStage.height,
      s.width * 0.56 / kStage.width,
    );
    final cx = s.width * (camp == Camp.player ? 0.29 : 0.71);
    final baseY = s.height * 0.965;

    c.save();
    c.translate(cx, baseY);
    c.scale(scale);
    if (flip) c.scale(-1, 1);
    c.translate(-kStage.width / 2, -kGround);
    a.paint(c, game.clock);
    c.restore();
  }
}

class _ForegroundLayer extends Component with HasGameReference<StageGame> {
  _ForegroundLayer() : super(priority: 3);

  @override
  void render(Canvas c) {
    paintForeground(
      c,
      game.size.toSize(),
      game.clock,
      game.matchup.hero.accent,
      game.matchup.monster.accent,
    );
  }
}
