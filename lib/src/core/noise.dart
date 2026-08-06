import 'dart:math' as math;

/// 결정론적 값 노이즈. 절차적 실루엣의 요철, 천의 결, 금속 스크래치,
/// 애니메이션의 미세 흔들림 등 "완벽하지 않은 자연스러움"을 만드는 데 쓴다.
class Noise {
  Noise(this.seed);

  final int seed;

  double _hash(int x, int y) {
    var h = seed ^ (x * 374761393) ^ (y * 668265263);
    h = (h ^ (h >> 13)) & 0xFFFFFFFF;
    h = (h * 1274126177) & 0xFFFFFFFF;
    h = (h ^ (h >> 16)) & 0xFFFFFFFF;
    return h / 0xFFFFFFFF;
  }

  static double _smooth(double t) => t * t * (3 - 2 * t);

  /// 1D 값 노이즈. 0..1
  double at1(double x) {
    final xi = x.floor();
    final xf = x - xi;
    final a = _hash(xi, 0);
    final b = _hash(xi + 1, 0);
    return a + (b - a) * _smooth(xf);
  }

  /// 2D 값 노이즈. 0..1
  double at2(double x, double y) {
    final xi = x.floor();
    final yi = y.floor();
    final xf = _smooth(x - xi);
    final yf = _smooth(y - yi);
    final v00 = _hash(xi, yi);
    final v10 = _hash(xi + 1, yi);
    final v01 = _hash(xi, yi + 1);
    final v11 = _hash(xi + 1, yi + 1);
    final top = v00 + (v10 - v00) * xf;
    final bot = v01 + (v11 - v01) * xf;
    return top + (bot - top) * yf;
  }

  /// 프랙탈 브라운 모션. 옥타브를 겹쳐 디테일의 층위를 만든다.
  double fbm1(double x, {int octaves = 4, double gain = 0.5, double lacunarity = 2.0}) {
    var sum = 0.0, amp = 1.0, norm = 0.0, f = 1.0;
    for (var i = 0; i < octaves; i++) {
      sum += at1(x * f + i * 37.13) * amp;
      norm += amp;
      amp *= gain;
      f *= lacunarity;
    }
    return sum / norm;
  }

  double fbm2(double x, double y, {int octaves = 4, double gain = 0.5, double lacunarity = 2.0}) {
    var sum = 0.0, amp = 1.0, norm = 0.0, f = 1.0;
    for (var i = 0; i < octaves; i++) {
      sum += at2(x * f + i * 17.7, y * f - i * 23.1) * amp;
      norm += amp;
      amp *= gain;
      f *= lacunarity;
    }
    return sum / norm;
  }

  /// -1..1 로 정규화된 값. 변위(displacement)에 바로 곱해 쓴다.
  double signed1(double x, {int octaves = 3}) => fbm1(x, octaves: octaves) * 2 - 1;

  double signed2(double x, double y, {int octaves = 3}) => fbm2(x, y, octaves: octaves) * 2 - 1;
}

/// 여러 사인파를 합쳐 주기적이면서도 반복이 눈에 띄지 않는 요동을 만든다.
/// 호흡, 근육 떨림, 불꽃 명멸처럼 "살아 있는" 정지 상태를 표현할 때 쓴다.
double wobble(double t, double seed) {
  return math.sin(t * 1.0 + seed) * 0.6 +
      math.sin(t * 1.71 + seed * 2.3) * 0.28 +
      math.sin(t * 2.93 + seed * 5.1) * 0.12;
}
