import 'package:flutter_test/flutter_test.dart';
import 'package:provis/provis.dart';

/// 절차적 생성기의 토대는 "같은 시드 → 같은 결과" 하나다. 그 성질이 조용히
/// 깨지면 캐릭터가 왜 바뀌었는지 아무도 재현할 수 없으므로, 여기서 불변식을
/// 못 박아 둔다.
void main() {
  group('Rng 결정론', () {
    test('같은 시드는 같은 수열을 낸다', () {
      final a = Rng(12345);
      final b = Rng(12345);
      for (var i = 0; i < 100; i++) {
        expect(a.unit, b.unit);
      }
    });

    test('다른 시드는 다른 수열을 낸다', () {
      final a = Rng(1);
      final b = Rng(2);
      var same = 0;
      for (var i = 0; i < 50; i++) {
        if (a.unit == b.unit) same++;
      }
      expect(same, lessThan(3));
    });

    test('시드 0 은 고정 상수로 대체된다', () {
      expect(Rng(0).unit, Rng(0x9E3779B9).unit);
    });

    test('unit 은 [0, 1) 범위를 벗어나지 않는다', () {
      final r = Rng(7);
      for (var i = 0; i < 5000; i++) {
        final v = r.unit;
        expect(v, greaterThanOrEqualTo(0.0));
        expect(v, lessThan(1.0));
      }
    });
  });

  group('branch 격리 — 이 그룹이 깨지면 생성기를 손볼 수 없게 된다', () {
    test('부모 스트림을 얼마나 소비했든 같은 salt 는 같은 자식을 낸다', () {
      // 브랜치를 먼저 만든 경우
      final early = Rng(999).branch(11);

      // 부모에서 난수를 잔뜩 뽑은 뒤 만든 경우
      final parent = Rng(999);
      for (var i = 0; i < 37; i++) {
        parent.unit;
      }
      final late = parent.branch(11);

      for (var i = 0; i < 50; i++) {
        expect(late.unit, early.unit,
            reason: 'branch 가 루트 시드가 아니라 현재 상태에서 파생되고 있다');
      }
    });

    test('생성 규칙을 추가해도 다른 하위 시스템의 결과가 보존된다', () {
      // "장비 규칙을 하나 추가했다"를 부모 난수 1회 추가로 모사한다.
      List<double> paletteOf({required bool withNewRule}) {
        final r = Rng(4242);
        r.bell(0.8, 1.2); // 기존 체형 다이얼
        if (withNewRule) r.chance(0.5); // ← 새로 추가된 규칙
        final palette = r.branch(11);
        return [for (var i = 0; i < 10; i++) palette.unit];
      }

      expect(paletteOf(withNewRule: true), paletteOf(withNewRule: false));
    });

    test('salt 가 다르면 자식도 다르다', () {
      final a = Rng(555).branch(11);
      final b = Rng(555).branch(23);
      var same = 0;
      for (var i = 0; i < 50; i++) {
        if (a.unit == b.unit) same++;
      }
      expect(same, lessThan(3));
    });

    test('자식은 부모 스트림을 소비하지 않는다', () {
      final a = Rng(31337);
      final first = a.unit;

      final b = Rng(31337);
      b.branch(11).unit; // 브랜치를 만들고 써 본다
      b.branch(23).unit;

      expect(b.unit, first, reason: 'branch 가 부모 상태를 건드렸다');
    });
  });

  group('분포 형태', () {
    test('bell 은 구간 안에 머물며 중앙이 두껍다', () {
      final r = Rng(2026);
      var mid = 0;
      for (var i = 0; i < 4000; i++) {
        final v = r.bell(0.0, 1.0);
        expect(v, inInclusiveRange(0.0, 1.0));
        if (v > 0.35 && v < 0.65) mid++;
      }
      // 균등분포라면 30% 언저리. 3회 평균이면 확연히 높다.
      expect(mid / 4000, greaterThan(0.45));
    });

    test('weighted 는 가중치에 비례해 뽑는다', () {
      final r = Rng(88);
      var a = 0;
      for (var i = 0; i < 3000; i++) {
        if (r.weighted(['a', 'b'], [3, 1]) == 'a') a++;
      }
      expect(a / 3000, closeTo(0.75, 0.05));
    });

    test('range 는 경계를 넘지 않는다', () {
      final r = Rng(5);
      for (var i = 0; i < 2000; i++) {
        expect(r.range(-3.0, 7.0), inInclusiveRange(-3.0, 7.0));
      }
    });
  });
}
