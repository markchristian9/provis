import 'package:flutter_test/flutter_test.dart';
import 'package:provis/provis.dart';

/// `pc` 스킬이 문서에 적어 둔 사실들.
///
/// ## 왜 이 파일이 필요한가
///
/// 스킬 문서는 코드를 읽고 쓰지만, 코드가 바뀔 때 문서는 **조용히 틀린 말이
/// 된다.** 틀린 문서는 없는 문서보다 나쁘다 — 읽는 쪽이 그것을 믿고 배선하기
/// 때문이다. 실제로 이 문서를 쓰는 도중에 애니메이션 API 가 통째로 바뀌어,
/// `progress` 로 판정하라던 설명이 한 시간 만에 낡았다.
///
/// 그래서 문서가 의존하는 **수치와 계약을 여기에 못 박는다.** 라이브러리를
/// 고쳐 이 테스트가 깨지면 그것은 회귀가 아니라 **문서를 갱신하라는 신호**다.
/// 어느 규칙이 깨졌는지 `reason` 이 알려 준다.
///
/// 문서 자체(`.claude/skills/pc/`)는 읽지 않는다. `.pubignore` 가 그 디렉터리를
/// 배포에서 빼기 때문에, 파일을 참조하면 소비자 환경에서 이유 없이 실패한다.
void main() {
  const skill = 'pc 스킬';

  RiggedIsoActor actor() => RiggedIsoActor(
        renderer: HumanoidRenderer(HumanoidSpec.generate(7)),
        tile: Offset.zero,
      );

  group('$skill 규칙 3 — 판정은 progress 가 아니라 ClipEvent 로', () {
    test('strike 는 프레임률과 무관하게 정확히 한 번 터진다', () {
      // 문서가 `animator.fired.contains('strike')` 를 유일한 판정 수단으로
      // 제시한다. 한 번이 아니게 되는 순간 그 배선이 전부 틀린 말이 된다.
      for (final fps in [24.0, 30.0, 60.0, 90.0, 144.0]) {
        final a = actor()..play('attack');
        var n = 0;
        for (var i = 0; i < (Anims.attack.duration * fps).round(); i++) {
          a.update(1 / fps);
          n += a.animator.fired.where((e) => e == 'strike').length;
        }
        expect(n, 1, reason: '$fps fps — 문서의 판정 배선이 무너진다');
      }
    });

    test('문서의 이벤트 표에 적힌 이름이 실제로 있다', () {
      // 워크플로우 2 의 표를 그대로 옮긴 것이다. 이름이 바뀌면 표를 고친다.
      Set<String> names(Clip c) => c.events.map((e) => e.name).toSet();
      expect(names(Anims.attack), {'strike'});
      expect(names(Anims.shoot), {'release'});
      expect(names(Anims.hit), {'impact'});
      expect(names(Anims.death), {'collapse'});
      for (final c in [Anims.walk, Anims.run, Anims.dash]) {
        expect(c.events.where((e) => e.name == 'footfall').length, 2,
            reason: '${c.name} — 사이클당 발소리 두 번');
      }
    });
  });

  group('$skill 규칙 5 — dt 는 kMaxFrameStep 로 잘린다', () {
    test('히치 한 번이 예비 동작을 건너뛰지 않는다', () {
      final a = Animator()..playByName('attack');
      a.update(0.4); // 400ms 짜리 프레임 하나
      expect(a.progress,
          lessThan(kMaxFrameStep / Anims.attack.duration + 1e-6));
      expect(a.fired, isEmpty, reason: '타격 프레임을 뛰어넘으면 안 된다');
    });
  });

  group('$skill 규칙 6 — 이름을 못 찾으면 조용히 idle 로 떨어진다', () {
    test('byName 은 자기 clips 를 먼저 보고, 없으면 idle 을 준다', () {
      const heavy =
          Clip(name: 'attack', label: 'Heavy', duration: 1.15, loop: false);
      expect(identical(Animator(clips: [heavy, ...Anims.all]).byName('attack'),
              heavy),
          isTrue,
          reason: '커스텀 목록이 우선이라는 문서의 콤보 레시피가 여기 걸려 있다');
      expect(Animator().byName('없는_이름').name, 'idle',
          reason: '조용히 떨어진다는 경고가 유효한가');
    });
  });

  group('$skill 규칙 8 — dash 함정', () {
    test('dash 는 여전히 갇힌다', () {
      // 문서가 이것을 **살아 있는 함정**으로 적고 우회법을 준다. 라이브러리가
      // 고쳐지면(_isOneShot 을 `!loop` 로) 이 테스트가 깨지고, 그때 문서에서
      // 규칙 8 과 dash 절을 지우면 된다.
      final a = actor()..play('dash');
      for (var i = 0; i < 60 * 20; i++) {
        a.update(1 / 60);
      }
      expect(a.state, 'dash',
          reason: '고쳐졌다면 규칙 8 · combat-loop.md 의 dash 절을 지운다');
    });

    test('attack 은 정상적으로 idle 로 복귀한다', () {
      final a = actor()..play('attack');
      for (var i = 0; i < 60 * 3; i++) {
        a.update(1 / 60);
      }
      expect(a.state, 'idle');
    });
  });

  group('$skill 규칙 9~12 — 공격 클립의 형태', () {
    test('9키이고 첫 키와 마지막 키가 모든 트랙에서 같다', () {
      final c = Anims.attack;
      final tracks = <String, List<double>?>{
        'rootX': c.rootX, 'rootY': c.rootY, 'rootRot': c.rootRot,
        'spine': c.spine, 'chest': c.chest, 'head': c.head,
        'nearShoulder': c.nearShoulder, 'nearElbow': c.nearElbow,
        'nearWrist': c.nearWrist, 'farShoulder': c.farShoulder,
        'farElbow': c.farElbow, 'nearHip': c.nearHip, 'nearKnee': c.nearKnee,
        'farHip': c.farHip, 'farKnee': c.farKnee, 'farAnkle': c.farAnkle,
        'weaponSwing': c.weaponSwing, 'mouth': c.mouth, 'squash': c.squash,
      };
      for (final e in tracks.entries) {
        final k = e.value;
        expect(k, isNotNull, reason: '${e.key} — 문서의 트랙 해부표에 있다');
        expect(k!.length, 9, reason: '${e.key} — 원샷 9키 규약');
        expect(k.first, k.last, reason: '${e.key} — 가드로 돌아와야 안 튄다');
      }
    });

    test('생략한 트랙은 이전 포즈가 아니라 기본값으로 고정된다', () {
      // 규칙 11 의 근거. 이 값들이 바뀌면 문서의 기본값 표를 고친다.
      const bare = Clip(name: 'bare', label: 'Bare', duration: 1, loop: false);
      final p = bare.sample(0.5);
      expect(p.armNear.shoulder, 0.10);
      expect(p.armNear.elbow, 0.22);
      expect(p.armFar.shoulder, 0.08);
      expect(p.armFar.elbow, 0.20);
      expect(p.legNear.hip, 0.05);
      expect(p.legNear.knee, 0.06);
      expect(p.legFar.hip, -0.05);
      expect(p.legFar.knee, 0.08);
      expect(p.squash, 1.0);
      expect(p.eyeOpen, 1.0);
    });

    test('weaponSwing 정점은 한 곳이고 strike 이벤트와 같은 시각이다', () {
      final w = Anims.attack.weaponSwing!;
      expect(w.where((v) => v >= 1.0).length, 1, reason: '잔상이 뭉개지지 않으려면');
      final peak = w.indexOf(1.0) / (w.length - 1);
      final strike =
          Anims.attack.events.singleWhere((e) => e.name == 'strike').at;
      expect(peak, strike, reason: '판정과 그림이 어긋나면 안 된다');
    });

    test('예비 / 타격 / 회복이 35 / 12 / 53 으로 비대칭이다', () {
      // 규칙 15 와 9키 격자표의 근거.
      //
      // 세 구간의 경계를 어깨 커브에서 찾는다. 어깨가 **한 키 만에 가장 크게
      // 무너지는 구간**이 타격이다(2.55 → 0.85). 그 앞이 예비, 뒤가 회복이다.
      // 최솟값 키를 쓰면 안 된다 — 어깨는 임팩트를 지나 관성으로 더 펴지므로
      // 최솟값은 이미 회복 구간에 있다.
      final s = Anims.attack.nearShoulder!;
      final span = 1 / (s.length - 1);

      var drop = 0.0;
      var at = 0;
      for (var i = 0; i < s.length - 1; i++) {
        final d = s[i] - s[i + 1];
        if (d > drop) {
          drop = d;
          at = i;
        }
      }
      final strikeStart = at * span;
      final strikeEnd = (at + 1) * span;

      expect(strikeEnd,
          Anims.attack.events.singleWhere((e) => e.name == 'strike').at,
          reason: '타격 구간이 strike 이벤트에서 끝나야 판정과 그림이 맞는다');
      expect(strikeStart, inInclusiveRange(0.30, 0.45), reason: '예비 ≈ 35%');
      expect(strikeEnd - strikeStart, lessThanOrEqualTo(0.15), reason: '타격 ≈ 12%');
      expect(1 - strikeEnd, greaterThanOrEqualTo(0.45), reason: '회복 ≈ 53%');
    });
  });

  group('$skill 규칙 14 — 이동 클립만 보폭을 갖는다', () {
    test('strideCycle 이 이동 클립에만 있다', () {
      for (final c in [Anims.walk, Anims.run, Anims.dash]) {
        expect(c.strideCycle, greaterThan(0), reason: '${c.name} — 발이 미끄러진다');
      }
      for (final c in [
        Anims.idle, Anims.wait, Anims.attack,
        Anims.shoot, Anims.hit, Anims.death,
      ]) {
        expect(c.strideCycle, 0,
            reason: '${c.name} — 제자리 동작에 보폭을 주면 판정이 속도에 끌려간다');
      }
    });

    test('보폭이 커질수록 빠른 걸음걸이다', () {
      expect(Anims.walk.strideCycle, lessThan(Anims.run.strideCycle));
      expect(Anims.run.strideCycle, lessThan(Anims.dash.strideCycle));
    });

    test('액터가 보폭을 타일로 환산하고 제자리 동작은 0 을 낸다', () {
      final a = actor();
      expect(a.cycleTiles(Anims.walk), greaterThan(0));
      expect(a.cycleTiles(Anims.attack), 0);
    });
  });

  group('$skill 워크플로우 1 — PC 를 세운다', () {
    test('runThreshold 는 null 이 기본이고 gaitCrossover 가 대신한다', () {
      final a = actor();
      expect(a.runThreshold, isNull, reason: '문서가 비워 두라고 한다');
      expect(a.gaitCrossover.isFinite, isTrue);
      expect(a.gaitCrossover, greaterThan(0));
      // 걷기와 달리기 사이에 있어야 둘이 갈린다.
      expect(a.gaitCrossover, greaterThan(a.naturalSpeed(Anims.walk)));
      expect(a.gaitCrossover, lessThan(a.naturalSpeed(Anims.run)));
    });
  });

  group('$skill combat-loop — 히트스톱', () {
    test('멈췄다가 정확히 그 자리에서 잇는다', () {
      final a = actor()..play('attack');
      for (var i = 0; i < 20; i++) {
        a.update(1 / 60);
      }
      final at = a.animator.progress;
      a.animator.hitstop(0.06);
      expect(a.animator.frozen, isTrue);
      for (var i = 0; i < 3; i++) {
        a.update(1 / 60);
      }
      expect(a.animator.progress, closeTo(at, 1e-9), reason: '멈춘 동안 진행하면 안 된다');
      a.update(1 / 60);
      expect(a.animator.progress, greaterThan(at), reason: '풀리면 이어져야 한다');
    });

    test('겹쳐 부르면 더 긴 쪽이 이긴다', () {
      final a = Animator()..playByName('attack');
      a.hitstop(0.03);
      a.hitstop(0.09);
      var frames = 0;
      while (a.frozen && frames < 60) {
        a.update(1 / 60);
        frames++;
      }
      expect(frames, greaterThan(4), reason: '0.09초면 5프레임 이상 얼어 있어야 한다');
    });
  });
}
