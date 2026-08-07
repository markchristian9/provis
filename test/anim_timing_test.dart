import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:provis/provis.dart';

/// 애니메이션 타이밍의 불변식.
///
/// 여기서 깨지는 것들은 전부 "화면을 보면 이상한데 원인을 못 찾는" 부류다 —
/// 두 배로 빨라진 재생, 프레임률에 끌려가는 속도, 전환할 때 튀는 포즈,
/// 얼음판을 지치는 발. 눈으로 잡으려면 오래 걸리므로 수치로 고정해 둔다.
void main() {
  /// 포즈 하나를 스칼라로 요약한다. 프레임 사이 변화량을 재는 데만 쓴다.
  double digest(Pose p) =>
      p.rootX.abs() +
      p.rootY.abs() +
      p.rootRot.abs() +
      p.spine.abs() +
      p.chest.abs() +
      p.head.abs() +
      p.armNear.shoulder.abs() +
      p.armNear.elbow.abs() +
      p.armFar.shoulder.abs() +
      p.legNear.hip.abs() +
      p.legNear.knee.abs() +
      p.legFar.hip.abs() +
      p.legFar.knee.abs();

  group('시간 진행', () {
    test('클립 시간은 프레임률과 무관하게 흐른다', () {
      // 같은 벽시계 시간을 30 / 60 / 144 fps 로 나눠 먹인다. 위상이 갈리면
      // 기기마다 걷기 속도가 달라진다.
      double phaseAfter(double fps) {
        final a = Animator()..playByName('walk');
        final dt = 1 / fps;
        for (var i = 0; i < fps * 2; i++) {
          a.update(dt);
        }
        return a.progress;
      }

      final at60 = phaseAfter(60);
      expect(phaseAfter(30), closeTo(at60, 0.01));
      expect(phaseAfter(144), closeTo(at60, 0.01));
    });

    test('히치 한 번이 동작을 건너뛰지 않는다', () {
      // 400ms 짜리 프레임이 한 번 들어와도 공격의 예비동작이 통째로 사라지면
      // 안 된다. dt 를 자르면 최악의 경우 잠깐 느려질 뿐이다.
      final a = Animator()..playByName('attack');
      a.update(0.4);
      expect(a.progress, lessThan(kMaxFrameStep / Anims.attack.duration + 1e-6));
      expect(a.fired, isEmpty, reason: '타격 프레임을 뛰어넘어서는 안 된다');
    });

    test('배속은 전환에도 함께 걸린다', () {
      // 슬로모션에서 전환만 제 속도로 지나가면 정작 보려던 것을 놓친다.
      final slow = Animator()
        ..speed = 0.25
        ..playByName('walk');
      final normal = Animator()..playByName('walk');
      for (var i = 0; i < 12; i++) {
        slow.update(1 / 60);
        normal.update(1 / 60);
      }
      // 같은 프레임 수에서 느린 쪽이 아직 덜 섞여 있어야 한다.
      expect(digest(slow.pose), isNot(closeTo(digest(normal.pose), 1e-9)));
    });
  });

  group('전환', () {
    test('클립을 바꾸는 순간 포즈가 이어진다', () {
      // 전환은 blend=0 에서 시작하므로 `play` 직후의 포즈는 직전 프레임과
      // **정확히 같아야** 한다. 전환 도중에 또 갈아탈 때 이것이 깨지던 것이
      // 연타할 때 눈에 보이던 튐의 정체다 — 섞여 있던 결과를 버리고 나가던
      // 클립의 원본 포즈로 되돌아가기 때문이었다.
      final a = Animator()..playByName('idle');

      // 전환이 끝나기 전에 갈아타는 순서. 마지막 둘은 루프↔원샷이라
      // 요동 진폭까지 함께 이어져야 한다.
      const script = ['run', 'walk', 'wait', 'attack', 'idle', 'hit'];
      for (final (i, name) in script.indexed) {
        // 전환 시간(0.04~0.18초)보다 짧게 돌려 항상 전환 도중에 끼어든다.
        for (var f = 0; f < 3; f++) {
          a.update(1 / 60);
        }
        final before = digest(a.pose);
        a.playByName(name);
        expect(digest(a.pose), closeTo(before, 1e-9), reason: '$i: $name');
      }
    });

    test('전환 도중 갈아타도 한 프레임에 몰아서 움직이지 않는다', () {
      // 위 테스트가 전환의 첫 프레임을 보장한다면, 이쪽은 그 뒤로도 계속
      // 매끄러운지를 본다. 기준값은 끼어들지 않은 같은 전환의 최대 변화량이다.
      double worstDelta({required bool interrupt}) {
        final a = Animator()..playByName('idle');
        for (var i = 0; i < 30; i++) {
          a.update(1 / 60);
        }
        var prev = digest(a.pose);
        var worst = 0.0;
        for (var i = 0; i < 90; i++) {
          // 끼어드는 쪽은 전환이 끝나기 전에, 아닌 쪽은 충분히 지난 뒤에.
          final gap = interrupt ? 5 : 30;
          if (i % gap == 0) {
            a.playByName(const ['run', 'walk', 'wait'][(i ~/ gap) % 3]);
          }
          a.update(1 / 60);
          final now = digest(a.pose);
          worst = math.max(worst, (now - prev).abs());
          prev = now;
        }
        return worst;
      }

      // 짧은 간격으로 끼어들면 같은 변화를 더 짧은 시간에 소화하므로 조금
      // 커지는 것은 정상이다. 두 배를 넘으면 섞이지 않고 튄 것이다.
      expect(worstDelta(interrupt: true),
          lessThan(worstDelta(interrupt: false) * 2));
    });

    test('죽음은 끝난 뒤 완전히 멎는다', () {
      // 시체가 계속 어깨를 들썩이면 죽은 것으로 안 보인다.
      final a = Animator()..playByName('death');
      for (var i = 0; i < 60 * 3; i++) {
        a.update(1 / 60);
      }
      final first = digest(a.pose);
      for (var i = 0; i < 60; i++) {
        a.update(1 / 60);
      }
      expect(digest(a.pose), closeTo(first, 1e-9));
    });
  });

  group('이벤트', () {
    test('타격은 프레임률과 무관하게 정확히 한 번 터진다', () {
      int strikes(double fps) {
        final a = Animator()..playByName('attack');
        final dt = 1 / fps;
        var n = 0;
        // 한 사이클 + 반복 대기까지 지나지 않을 만큼만 돌린다.
        for (var i = 0; i < (Anims.attack.duration * fps).round(); i++) {
          a.update(dt);
          n += a.fired.where((e) => e == 'strike').length;
        }
        return n;
      }

      for (final fps in [24.0, 30.0, 60.0, 90.0, 144.0]) {
        expect(strikes(fps), 1, reason: '$fps fps');
      }
    });

    test('루프 클립의 발소리는 사이클마다 두 번 난다', () {
      final a = Animator()..playByName('walk');
      var n = 0;
      // 두 사이클.
      final frames = (Anims.walk.duration * 2 * 60).round();
      for (var i = 0; i < frames; i++) {
        a.update(1 / 60);
        n += a.fired.where((e) => e == 'footfall').length;
      }
      expect(n, 4);
    });

    test('히트스톱은 시간을 멈췄다가 그 자리에서 잇는다', () {
      final a = Animator()..playByName('attack');
      for (var i = 0; i < 20; i++) {
        a.update(1 / 60);
      }
      final at = a.progress;
      a.hitstop(0.06);
      expect(a.frozen, isTrue);
      for (var i = 0; i < 3; i++) {
        a.update(1 / 60);
      }
      expect(a.progress, closeTo(at, 1e-9), reason: '멈춘 동안 진행하면 안 된다');
      a.update(1 / 60);
      expect(a.progress, greaterThan(at), reason: '풀리면 이어져야 한다');
    });
  });

  group('보폭', () {
    RiggedIsoActor actorAt(double tileWidth) => RiggedIsoActor(
          renderer: HumanoidRenderer(HumanoidSpec.generate(5)),
          tile: Offset.zero,
          height: 200,
          iso: IsoView(tileWidth: tileWidth, tileHeight: tileWidth / 2),
        );

    test('클립 배속이 이동 속도를 따라간다 — 발이 미끄러지지 않는다', () {
      final actor = actorAt(150);
      // 클립의 저작 속도. 여기서는 배속이 1 이어야 한다.
      final natural = actor.naturalSpeed(Anims.walk);
      expect(natural, greaterThan(0));

      for (final k in [0.7, 1.0, 1.4]) {
        final ctrl = IsoController(tile: Offset.zero, speed: natural * k);
        ctrl.moveTo(const Offset(40, 40));
        actor.play('walk');
        actor.follow(ctrl, 1 / 60);

        // 한 사이클에 나아가는 거리 ÷ 그 사이클에 걸리는 시간 = 이동 속도.
        final cycleTime = Anims.walk.duration / actor.animator.rate;
        final clipSpeed = actor.cycleTiles(Anims.walk) / cycleTime;
        expect(clipSpeed, closeTo(ctrl.speed, ctrl.speed * 0.02),
            reason: '배속 $k');
      }
    });

    test('보폭은 타일 크기에 따라간다', () {
      // 같은 캐릭터라도 타일이 크면 한 걸음이 차지하는 타일 수가 줄어든다.
      expect(actorAt(300).naturalSpeed(Anims.walk),
          closeTo(actorAt(150).naturalSpeed(Anims.walk) / 2, 1e-9));
    });

    test('제자리 동작에는 배속을 걸지 않는다', () {
      // 빨리 걷는다고 칼이 빨리 나가면 판정 타이밍이 속도에 따라 달라진다.
      final actor = actorAt(150);
      final ctrl = IsoController(tile: Offset.zero, speed: 6.0);
      ctrl.moveTo(const Offset(40, 40));
      actor.play('attack');
      actor.follow(ctrl, 1 / 60);
      expect(actor.animator.rate, 1.0);
    });

    test('걷기와 달리기는 보폭에서 갈린다', () {
      final actor = actorAt(150);
      final crossover = actor.gaitCrossover;
      expect(crossover, greaterThan(actor.naturalSpeed(Anims.walk)));
      expect(crossover, lessThan(actor.naturalSpeed(Anims.run)));

      for (final (speed, want) in [
        (crossover * 0.6, 'walk'),
        (crossover * 1.6, 'run'),
      ]) {
        final a = actorAt(150);
        final ctrl = IsoController(tile: Offset.zero, speed: speed);
        ctrl.moveTo(const Offset(40, 40));
        a.follow(ctrl, 1 / 60);
        expect(a.state, want, reason: '$speed 타일/초');
      }
    });
  });

  group('씬과 액터', () {
    test('씬과 follow 가 시간을 두 번 밀지 않는다', () {
      // 이게 깨지면 모든 동작이 정확히 두 배 빨라진다 — 걷기가 종종걸음이 되고
      // 공격이 절반 시간에 끝난다.
      final scene = IsoSceneComponent(iso: kIso, grid: IsoGrid(cols: 8, rows: 8));
      final actor = RiggedIsoActor(
        renderer: HumanoidRenderer(HumanoidSpec.generate(3)),
        tile: const Offset(1, 1),
      );
      scene.rigged.add(actor);
      final ctrl = IsoController(tile: const Offset(1, 1), speed: 2);
      ctrl.moveTo(const Offset(6, 6));

      const dt = 1 / 60;
      for (var i = 0; i < 60; i++) {
        scene.update(dt);
        ctrl.update(dt);
        actor.follow(ctrl, dt);
      }
      expect(actor.animator.clock, closeTo(60 * dt, 1e-6));
    });

    test('씬 없이 쓰면 follow 가 시간을 민다', () {
      final actor = RiggedIsoActor(
        renderer: HumanoidRenderer(HumanoidSpec.generate(3)),
        tile: const Offset(1, 1),
      );
      final ctrl = IsoController(tile: const Offset(1, 1), speed: 2);
      const dt = 1 / 60;
      for (var i = 0; i < 60; i++) {
        ctrl.update(dt);
        actor.follow(ctrl, dt);
      }
      expect(actor.animator.clock, closeTo(60 * dt, 1e-6));
    });
  });

  group('이동과 회전', () {
    test('회전 속도가 프레임률에 끌려가지 않는다', () {
      double yawAfter(double fps) {
        final c = IsoController(tile: Offset.zero, speed: 3, turnTime: 0.14);
        c.moveTo(const Offset(0, 20)); // 남서 방향 — 초기 yaw 에서 크게 돈다
        final dt = 1 / fps;
        for (var i = 0; i < (0.2 * fps).round(); i++) {
          c.update(dt);
        }
        return c.yaw;
      }

      final at60 = yawAfter(60);
      expect(yawAfter(30), closeTo(at60, 0.02));
      expect(yawAfter(144), closeTo(at60, 0.02));
    });

    test('히치가 캐릭터를 순간이동시키지 않는다', () {
      final c = IsoController(tile: Offset.zero, speed: 6);
      c.moveTo(const Offset(30, 30));
      c.update(1.0); // 1초짜리 프레임
      expect(c.tile.distance, lessThanOrEqualTo(6 * kMaxFrameStep + 1e-6));
    });

    test('오래 돌아도 각도 정밀도가 유지된다', () {
      final c = IsoController(tile: Offset.zero, speed: 3, turnTime: 0.05);
      for (var i = 0; i < 4000; i++) {
        c.moveTo(Offset(math.cos(i * 1.7) * 20, math.sin(i * 1.7) * 20));
        c.update(1 / 60);
      }
      expect(c.yaw.abs(), lessThan(math.pi * 2 + 1e-9));
      expect(c.yaw.isFinite, isTrue);
    });
  });
}
