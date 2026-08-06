import 'package:flutter_test/flutter_test.dart';
import 'package:provis/provis.dart';

void main() {
  test('모든 클립이 유한한 포즈를 만든다', () {
    // 커브에 NaN 이 하나라도 섞이면 Path 생성이 조용히 실패해 파츠가
    // 통째로 사라진다. 화면을 보기 전에 여기서 걸러 낸다.
    for (final clip in Anims.all) {
      for (var i = 0; i <= 20; i++) {
        final p = clip.sample(i / 20);
        for (final v in [
          p.rootX,
          p.rootY,
          p.rootRot,
          p.spine,
          p.chest,
          p.neck,
          p.head,
          p.armNear.shoulder,
          p.armNear.elbow,
          p.armFar.shoulder,
          p.legNear.hip,
          p.legNear.knee,
          p.legFar.hip,
          p.legFar.knee,
          p.squash,
        ]) {
          expect(v.isFinite, isTrue, reason: '${clip.name} @ ${i / 20}');
        }
      }
    }
  });

  test('굽힘 관절은 해부학적으로 반대로 꺾이지 않는다', () {
    for (final clip in Anims.all) {
      for (var i = 0; i <= 20; i++) {
        final p = clip.sample(i / 20);
        // Catmull-Rom 은 키 사이에서 오버슈트하므로 약간의 여유를 둔다.
        expect(p.armNear.elbow, greaterThan(-0.25), reason: clip.name);
        expect(p.legNear.knee, greaterThan(-0.25), reason: clip.name);
        expect(p.legFar.knee, greaterThan(-0.25), reason: clip.name);
      }
    }
  });

  test('AUTO 가 켜지면 클립이 순환한다', () {
    final a = Animator()..auto = true;
    final first = a.current.name;
    var changed = false;
    for (var i = 0; i < 60 * 10; i++) {
      a.update(1 / 60);
      if (a.current.name != first) {
        changed = true;
        break;
      }
    }
    expect(changed, isTrue);
  });

  test('원샷 클립은 끝난 뒤 되감겨 반복된다', () {
    final a = Animator()..playByName('attack');
    for (var i = 0; i < 60 * 3; i++) {
      a.update(1 / 60);
    }
    expect(a.current.name, 'attack');
    expect(a.progress, lessThan(1.0));
  });

  test('죽음은 마지막 포즈에서 멈춘다', () {
    final a = Animator()..playByName('death');
    for (var i = 0; i < 60 * 6; i++) {
      a.update(1 / 60);
    }
    expect(a.progress, closeTo(1.0, 1e-6));
  });

  test('골격이 풀리고 머리가 골반 위에 온다', () {
    final renderer = HumanoidRenderer(HumanoidSpec.generate(12));
    final sk = solve(renderer.body, Anims.walk.sample(0.3));
    expect(sk.headTop.dy, lessThan(sk.pelvis.dy));
    expect(sk.bounds.isFinite, isTrue);
  });
}
