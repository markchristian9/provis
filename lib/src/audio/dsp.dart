import 'dart:math' as math;

import '../core/rng.dart';

/// 효과음의 기본 표본율. 금속 clang·곤충 소리의 고역이 살아야 하므로 넉넉히 준다.
const int kSfxRate = 44100;

/// 배경음의 기본 표본율. 길이가 길어 용량이 문제되고, 패드·드론에는 고역이
/// 거의 없으므로 절반이면 충분하다.
const int kBgmRate = 22050;

// ---------------------------------------------------------------------------
// 곡선 — 레시피가 값을 시간에 따라 움직일 때 쓰는 최소 도구
// ---------------------------------------------------------------------------

double lerpd(double a, double b, double t) => a + (b - a) * t;

/// 0..1 을 부드럽게 가감속한다.
double smoothstep01(double t) {
  final x = t.clamp(0.0, 1.0);
  return x * x * (3 - 2 * x);
}

/// 종 모양 곡선. `u`=0.5 에서 1, 양 끝에서 0.
///
/// 휘두르는 소리의 도플러(주파수가 올라갔다 내려온다)와 진폭 봉우리가 전부
/// 이 하나로 만들어진다. [skew] 를 1 보다 크게 주면 봉우리가 앞으로 당겨져
/// "예비는 길고 지나가는 순간은 짧은" 비대칭이 생긴다.
double bellCurve(double u, {double skew = 1.0, double power = 1.6}) {
  final x = u.clamp(0.0, 1.0);
  final s = math.pow(x, skew).toDouble();
  return math.pow(math.sin(math.pi * s), power).toDouble();
}

/// 지수 감쇠. [curve] 가 클수록 초반이 급하다.
double expFall(double u, {double curve = 4.0}) =>
    math.exp(-curve * u.clamp(0.0, 1.0));

/// tanh 근사 소프트 클립.
///
/// 하드 클립은 홀수 배음을 무한히 뿌려 디지털 잡음처럼 들린다. 이 유리함수는
/// 무릎이 둥글어 **과구동해도 "따뜻하게" 뭉개진다** — 으르렁·금속 타격의
/// 두께가 여기서 나온다.
double softClip(double x) {
  final c = x.clamp(-3.0, 3.0);
  return c * (27 + c * c) / (27 + 9 * c * c);
}

// ---------------------------------------------------------------------------
// 발진기
// ---------------------------------------------------------------------------

/// 위상 하나를 들고 표본을 하나씩 뱉는 발진기.
///
/// ## 왜 PolyBLEP 인가
///
/// 톱니·사각을 그냥 `2p-1` 로 만들면 불연속점에서 나이퀴스트를 넘는 배음이
/// 접혀 들어와(에일리어싱) 화음이 탁해진다. 패드처럼 여러 개를 겹치는 소리에서
/// 특히 티가 난다. PolyBLEP 은 불연속점 주변 두 표본만 보정해 이것을 없앤다 —
/// 비용은 분기 두 개뿐이다.
class Osc {
  Osc(this.rate, {double phase = 0}) : _p = phase % 1.0;

  final int rate;
  double _p;

  double get phase => _p;
  set phase(double v) => _p = v % 1.0;

  double _advance(double freq) {
    _p += freq / rate;
    if (_p >= 1.0) _p -= _p.floorToDouble();
    if (_p < 0) _p += 1.0;
    return _p;
  }

  double sine(double freq) => math.sin(2 * math.pi * _advance(freq));

  /// 코사인 반주기를 [sharpness] 제곱해 만든 펄스열.
  ///
  /// 성대의 여닫힘에 해당한다. [sharpness] 가 클수록 펄스가 좁아 배음이 많고
  /// 밝다 — 비명은 크게, 신음은 작게 준다.
  double pulse(double freq, double sharpness) {
    final p = _advance(freq);
    final c = 0.5 * (1 + math.cos(2 * math.pi * p));
    return math.pow(c, sharpness).toDouble() * 2 - 1;
  }

  double saw(double freq) {
    final dt = freq / rate;
    final p = _advance(freq);
    return (2 * p - 1) - _blep(p, dt);
  }

  double square(double freq, {double duty = 0.5}) {
    final dt = freq / rate;
    final p = _advance(freq);
    var y = p < duty ? 1.0 : -1.0;
    y += _blep(p, dt);
    y -= _blep((p + 1 - duty) % 1.0, dt);
    return y;
  }

  /// 삼각파. 불연속이 없어 보정 없이도 에일리어싱이 적고, 배음이 부드러워
  /// 저역 드론에 어울린다.
  double triangle(double freq) {
    final p = _advance(freq);
    return 4 * (p < 0.5 ? p : 1 - p) - 1;
  }

  static double _blep(double t, double dt) {
    if (dt <= 0) return 0;
    if (t < dt) {
      final x = t / dt;
      return x + x - x * x - 1.0;
    }
    if (t > 1.0 - dt) {
      final x = (t - 1.0) / dt;
      return x * x + x + x + 1.0;
    }
    return 0.0;
  }
}

/// 백색 잡음. 결정론을 지키기 위해 `math.Random` 이 아니라 [Rng] 를 쓴다.
class WhiteNoise {
  WhiteNoise(int seed) : _r = Rng(seed);
  final Rng _r;
  double get next => _r.unit * 2 - 1;
}

/// 분홍 잡음 — 옥타브당 3dB 씩 기운다.
///
/// 바람·흙·천처럼 **자연에 있는 잡음은 거의 전부 분홍에 가깝다.** 백색을
/// 그대로 쓰면 쉬익거리는 라디오 잡음이 되므로, 바람과 발소리의 바탕은
/// 이쪽이다. (Paul Kellet 의 3극 근사)
class PinkNoise {
  PinkNoise(int seed) : _w = WhiteNoise(seed);
  final WhiteNoise _w;
  double _b0 = 0, _b1 = 0, _b2 = 0;

  double get next {
    final w = _w.next;
    _b0 = 0.99765 * _b0 + w * 0.0990460;
    _b1 = 0.96300 * _b1 + w * 0.2965164;
    _b2 = 0.57000 * _b2 + w * 1.0526913;
    return (_b0 + _b1 + _b2 + w * 0.1848) * 0.32;
  }
}

// ---------------------------------------------------------------------------
// 포락선
// ---------------------------------------------------------------------------

/// 진폭 포락선.
///
/// 타격음의 정체는 스펙트럼이 아니라 **포락선**이다. 같은 잡음도 어택 1ms 에
/// 감쇠 60ms 면 딱딱한 타격이고, 어택 40ms 에 감쇠 900ms 면 바람 소리다.
class Env {
  const Env({
    this.attack = 0.004,
    this.hold = 0.0,
    this.decay = 0.20,
    this.sustain = 0.0,
    this.sustainTime = 0.0,
    this.release = 0.06,
    this.curve = 3.5,
  });

  /// 타악형 — 순간 솟았다가 지수로 꺼진다.
  const Env.perc({
    double attack = 0.002,
    double decay = 0.16,
    double curve = 4.0,
  }) : this(
          attack: attack,
          decay: decay,
          curve: curve,
          sustain: 0,
          sustainTime: 0,
          release: 0,
        );

  final double attack;
  final double hold;
  final double decay;

  /// 감쇠가 도달하는 유지 레벨 0..1.
  final double sustain;

  /// 유지 레벨에 머무는 시간(초).
  final double sustainTime;
  final double release;

  /// 감쇠·릴리스의 지수 곡률. 클수록 초반이 급하다.
  final double curve;

  double get duration => attack + hold + decay + sustainTime + release;

  double at(double t) {
    if (t <= 0) return 0;
    if (t < attack) {
      // 어택은 살짝 볼록하게 — 완전 선형이면 시작이 무디게 들린다.
      return math.pow(t / attack, 0.72).toDouble();
    }
    var x = t - attack;
    if (x < hold) return 1;
    x -= hold;
    if (x < decay) {
      final u = x / decay;
      final k = (math.exp(-curve * u) - math.exp(-curve)) / (1 - math.exp(-curve));
      return sustain + (1 - sustain) * k;
    }
    x -= decay;
    if (x < sustainTime) return sustain;
    x -= sustainTime;
    if (release <= 0) return 0;
    if (x >= release) return 0;
    final u = x / release;
    return sustain *
        (math.exp(-curve * u) - math.exp(-curve)) /
        (1 - math.exp(-curve));
  }
}

// ---------------------------------------------------------------------------
// 필터
// ---------------------------------------------------------------------------

enum FilterMode { lowpass, bandpass, highpass, notch }

/// 상태 변수 필터(TPT/ZDF, Cytomic 판).
///
/// 매 표본마다 컷오프를 바꿔도 발산하지 않는다. 휘두르는 소리의 대역을 훑거나
/// 포먼트를 움직이려면 이 성질이 필수다 — 고전 biquad 는 계수를 급히 바꾸면
/// 튄다.
class Svf {
  Svf(this.rate);
  final int rate;
  double _ic1 = 0, _ic2 = 0;

  void reset() {
    _ic1 = 0;
    _ic2 = 0;
  }

  double process(
    double x,
    double cutoff,
    double q, [
    FilterMode mode = FilterMode.lowpass,
  ]) {
    final fc = cutoff.clamp(15.0, rate * 0.45);
    final g = math.tan(math.pi * fc / rate);
    final k = 1.0 / q.clamp(0.35, 40.0);
    final a1 = 1.0 / (1.0 + g * (g + k));
    final a2 = g * a1;
    final a3 = g * a2;

    final v3 = x - _ic2;
    final v1 = a1 * _ic1 + a2 * v3;
    final v2 = _ic2 + a2 * _ic1 + a3 * v3;
    _ic1 = 2 * v1 - _ic1;
    _ic2 = 2 * v2 - _ic2;

    switch (mode) {
      case FilterMode.lowpass:
        return v2;
      case FilterMode.bandpass:
        return v1;
      case FilterMode.highpass:
        return x - k * v1 - v2;
      case FilterMode.notch:
        return x - k * v1;
    }
  }
}

/// 1극 저역 통과. 감쇠는 완만하지만 값이 싸서 잡음 다듬기에 쓴다.
class OnePole {
  OnePole(this.rate);
  final int rate;
  double _y = 0;

  double lp(double x, double cutoff) {
    final a = 1 - math.exp(-2 * math.pi * cutoff.clamp(1.0, rate * 0.49) / rate);
    _y += a * (x - _y);
    return _y;
  }

  double hp(double x, double cutoff) => x - lp(x, cutoff);
}

/// DC 제거기. 펄스열과 소프트 클립은 직류가 남아 스피커를 밀어내므로
/// 목소리 계열 끝에는 반드시 건다.
class DcBlock {
  double _x1 = 0, _y1 = 0;
  double process(double x) {
    final y = x - _x1 + 0.9975 * _y1;
    _x1 = x;
    _y1 = y;
    return y;
  }
}

/// 포먼트 세 개를 병렬로 물린 공명기.
///
/// 목소리가 "누구의 목소리"로 들리는 이유는 기본 주파수가 아니라 **성도의
/// 공명(포먼트)** 이다. 몸집이 커지면 성도가 길어져 포먼트가 통째로 내려간다 —
/// [scale] 하나로 사람에서 거인까지 이어진다.
class FormantBank {
  FormantBank(
    int rate, {
    required this.f1,
    required this.f2,
    required this.f3,
    this.q1 = 9,
    this.q2 = 11,
    this.q3 = 13,
    this.g1 = 1.0,
    this.g2 = 0.62,
    this.g3 = 0.30,
  })  : _a = Svf(rate),
        _b = Svf(rate),
        _c = Svf(rate);

  final Svf _a, _b, _c;
  final double f1, f2, f3;
  final double q1, q2, q3;
  final double g1, g2, g3;

  double process(double x, {double scale = 1.0, double spread = 1.0}) {
    final s = scale;
    return _a.process(x, f1 * s, q1, FilterMode.bandpass) * g1 +
        _b.process(x, f2 * s * spread, q2, FilterMode.bandpass) * g2 +
        _c.process(x, f3 * s * spread, q3, FilterMode.bandpass) * g3;
  }
}

// ---------------------------------------------------------------------------
// 지연선 — 공간과 몸통
// ---------------------------------------------------------------------------

/// 보간 없는 고정 지연선. 콤 필터·리버브·플럭의 뼈대다.
class DelayLine {
  DelayLine(int frames) : _buf = List<double>.filled(math.max(1, frames), 0);
  final List<double> _buf;
  int _i = 0;

  int get length => _buf.length;

  double read([int back = 0]) {
    var idx = (_i - back) % _buf.length;
    if (idx < 0) idx += _buf.length;
    return _buf[idx];
  }

  void write(double v) {
    _buf[_i] = v;
    _i = (_i + 1) % _buf.length;
  }

  /// 한 칸 읽고 한 칸 쓴다 — 순환 지연선의 기본 동작.
  double tick(double input) {
    final out = _buf[_i];
    _buf[_i] = input;
    _i = (_i + 1) % _buf.length;
    return out;
  }
}
