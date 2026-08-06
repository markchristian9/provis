import 'dart:math' as math;

/// 시드 기반 결정론적 난수 생성기.
///
/// 같은 시드는 항상 같은 캐릭터를 만든다. 절차적 생성의 재현성을 보장하는
/// 유일한 난수원이므로, 캐릭터 생성 경로에서는 `math.Random` 을 쓰지 않는다.
class Rng {
  Rng(int seed)
      : _root = (seed == 0 ? 0x9E3779B9 : seed) & 0xFFFFFFFF,
        _s = (seed == 0 ? 0x9E3779B9 : seed) & 0xFFFFFFFF;

  /// 문자열 시드(캐릭터 이름 등)로부터 생성.
  factory Rng.fromString(String s) {
    var h = 0x811C9DC5;
    for (final c in s.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return Rng(h);
  }

  /// 생성 당시의 시드. 소비되지 않으며 [branch] 의 유일한 기준점이다.
  final int _root;

  int _s;

  int _next() {
    var x = _s;
    x ^= (x << 13) & 0xFFFFFFFF;
    x ^= x >> 17;
    x ^= (x << 5) & 0xFFFFFFFF;
    _s = x & 0xFFFFFFFF;
    return _s;
  }

  /// 0.0 이상 1.0 미만.
  double get unit => _next() / 0x100000000;

  double range(double a, double b) => a + (b - a) * unit;

  int intRange(int a, int b) => a + (_next() % (b - a));

  bool chance(double p) => unit < p;

  T pick<T>(List<T> xs) => xs[_next() % xs.length];

  /// 가중치 기반 선택.
  T weighted<T>(List<T> xs, List<double> w) {
    var total = 0.0;
    for (final v in w) {
      total += v;
    }
    var t = unit * total;
    for (var i = 0; i < xs.length; i++) {
      t -= w[i];
      if (t <= 0) return xs[i];
    }
    return xs.last;
  }

  /// 종 모양 분포. 평균 근처가 잦고 극단값이 드물어 자연스러운 변주를 만든다.
  double bell(double a, double b, {int k = 3}) {
    var sum = 0.0;
    for (var i = 0; i < k; i++) {
      sum += unit;
    }
    return a + (b - a) * (sum / k);
  }

  /// -1..1 사이의 부호 있는 변주.
  double signed([double scale = 1]) => (unit * 2 - 1) * scale;

  /// 평균 0, 표준편차 1 의 정규분포 근사.
  double gaussian() {
    final u1 = math.max(unit, 1e-9);
    final u2 = unit;
    return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2);
  }

  /// 독립적으로 진행하는 자식 생성기.
  ///
  /// **호출 시점의 상태가 아니라 루트 시드에서 파생한다.** 그래서 부모 스트림을
  /// 얼마나 소비한 뒤에 부르든 같은 salt 는 언제나 같은 자식을 낸다. 이 성질이
  /// 없으면 체형 난수 한 줄을 추가하는 것만으로 기존 모든 캐릭터의 색과 장비가
  /// 바뀌어, 절차적 생성기를 손볼 수 없게 된다.
  ///
  /// salt 는 하위 시스템마다 고정 상수를 쓴다(11 색, 23 장비, 37 변이 …).
  /// 한 번 정한 salt 를 바꾸면 그 하위 시스템의 모든 결과가 바뀐다.
  Rng branch(int salt) => Rng((_root ^ (salt * 0x9E3779B9)) & 0xFFFFFFFF);
}
