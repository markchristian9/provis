import 'dart:math' as math;

/// 시드 기반 결정론적 난수 생성기.
///
/// 같은 시드는 항상 같은 캐릭터를 만든다. 절차적 생성의 재현성을 보장하는
/// 유일한 난수원이므로, 캐릭터 생성 경로에서는 `math.Random` 을 쓰지 않는다.
class Rng {
  Rng(int seed) : _s = (seed == 0 ? 0x9E3779B9 : seed) & 0xFFFFFFFF;

  /// 문자열 시드(캐릭터 이름 등)로부터 생성.
  factory Rng.fromString(String s) {
    var h = 0x811C9DC5;
    for (final c in s.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return Rng(h);
  }

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

  /// 독립적으로 진행하는 자식 생성기. 부모의 상태를 소비하지 않는 브랜치가
  /// 필요할 때 쓴다(예: 장비 생성은 몸 비율 생성과 분리).
  Rng branch(int salt) => Rng((_s ^ (salt * 0x9E3779B9)) & 0xFFFFFFFF);
}
