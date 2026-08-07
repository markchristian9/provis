import 'dart:math' as math;
import 'dart:typed_data';

import 'dsp.dart';

/// 표본 하나하나를 담는 모노 버퍼.
///
/// 그림에서 `Canvas` 가 하는 일을 소리에서는 이것이 한다 — 레시피는 층을
/// 하나씩 [mixIn] 으로 얹고, 마지막에 [normalize] 로 균형을 잡는다.
///
/// 배정밀도를 쓰는 이유는 정확도가 아니라 **레이어를 겹칠 때 클리핑을
/// 신경 쓰지 않기 위해서**다. 중간 합이 1 을 넘어도 마지막에 한 번 줄이면
/// 된다.
class Wave {
  Wave(this.rate, int frames) : data = Float64List(math.max(1, frames));

  Wave.seconds(this.rate, double seconds)
      : data = Float64List(math.max(1, (seconds * rate).round()));

  /// 표본율(Hz).
  final int rate;

  final Float64List data;

  int get length => data.length;
  double get duration => data.length / rate;

  double operator [](int i) => data[i];
  void operator []=(int i, double v) => data[i] = v;

  /// 초 단위 위치를 표본 인덱스로.
  int frameOf(double seconds) => (seconds * rate).round();

  void add(int i, double v) {
    if (i >= 0 && i < data.length) data[i] += v;
  }

  /// 다른 버퍼를 [at] 초 위치에 얹는다.
  void mixIn(Wave other, {double gain = 1.0, double at = 0.0}) {
    assert(other.rate == rate, '표본율이 다른 버퍼를 섞을 수 없다');
    final off = frameOf(at);
    final n = math.min(other.length, data.length - off);
    for (var i = 0; i < n; i++) {
      final j = off + i;
      if (j >= 0) data[j] += other.data[i] * gain;
    }
  }

  void scale(double g) {
    for (var i = 0; i < data.length; i++) {
      data[i] *= g;
    }
  }

  double get peak {
    var m = 0.0;
    for (final v in data) {
      final a = v.abs();
      if (a > m) m = a;
    }
    return m;
  }

  /// 최대 진폭을 [target] 에 맞춘다. 무음이면 아무것도 하지 않는다.
  Wave normalize([double target = 0.92]) {
    final p = peak;
    if (p > 1e-9) scale(target / p);
    return this;
  }

  Wave fadeIn(double seconds) {
    final n = math.min(frameOf(seconds), data.length);
    for (var i = 0; i < n; i++) {
      data[i] *= smoothstep01(i / n);
    }
    return this;
  }

  Wave fadeOut(double seconds) {
    final n = math.min(frameOf(seconds), data.length);
    for (var i = 0; i < n; i++) {
      data[data.length - 1 - i] *= smoothstep01(i / n);
    }
    return this;
  }

  /// 전체에 소프트 클립을 걸어 두께를 만든다.
  Wave drive(double amount) {
    for (var i = 0; i < data.length; i++) {
      data[i] = softClip(data[i] * amount);
    }
    return this;
  }

  /// 꼬리를 머리에 접어 **이음매 없는 루프**로 만든다.
  ///
  /// 배경음을 그냥 잘라 반복하면 이어지는 지점에서 파형이 튀어 "딱" 소리가
  /// 난다. 페이드로 덮으면 그 순간 음악이 사라진다. 정답은 잘라낸 꼬리를
  /// 머리 위에 크로스페이드로 얹는 것이다 — 잔향과 여운이 루프를 건너
  /// 이어지므로 반복 지점이 들리지 않는다.
  ///
  /// 결과 길이는 `length - tail` 이다. 꼬리가 남는 몸통보다 길 수는 없으므로
  /// 전체 길이의 절반으로 자른다 — 짧게 구워 놓고 긴 꼬리를 접으려 하면
  /// 루프가 자기 자신을 덮어 음악이 사라진다.
  Wave foldTail(double tailSeconds) {
    var tail = frameOf(tailSeconds);
    if (tail <= 0) return this;
    if (tail > data.length ~/ 2) tail = data.length ~/ 2;
    if (tail <= 0) return this;
    final keep = data.length - tail;
    final out = Wave(rate, keep);
    out.data.setRange(0, keep, data);
    for (var i = 0; i < tail; i++) {
      final u = i / tail;
      // 등출력 크로스페이드 — 선형으로 섞으면 겹치는 구간의 음량이 꺼진다.
      final fadeIn = math.sin(u * math.pi / 2);
      final fadeOut = math.cos(u * math.pi / 2);
      out.data[i] = out.data[i] * fadeIn + data[keep + i] * fadeOut;
    }
    return out;
  }

  /// 재생 속도를 바꿔 음높이를 옮긴다.
  ///
  /// 같은 레시피에서 값싸게 변주를 만드는 수단이다. [ratio] 1.06 이면 반음
  /// 위, 0.94 면 반음 아래. 발소리 네 개를 굽고 여기에 미세한 비율을 곱하면
  /// 같은 소리가 반복된다는 인상이 사라진다.
  Wave resampled(double ratio) {
    final n = math.max(1, (data.length / ratio).round());
    final out = Wave(rate, n);
    for (var i = 0; i < n; i++) {
      final src = i * ratio;
      final i0 = src.floor();
      final i1 = math.min(i0 + 1, data.length - 1);
      if (i0 >= data.length) break;
      final f = src - i0;
      out.data[i] = data[i0] * (1 - f) + data[i1] * f;
    }
    return out;
  }

  Wave copy() {
    final out = Wave(rate, data.length);
    out.data.setAll(0, data);
    return out;
  }
}

/// 슈뢰더 잔향. 병렬 콤 4 + 직렬 올패스 2.
///
/// ## 왜 필요한가
///
/// 완전히 마른 효과음은 **머릿속에서 난다.** 같은 검이 부딪는 소리라도 짧은
/// 잔향이 붙는 순간 "골짜기에서 난 소리"가 되고, 씬 전체가 한 공간에 있는
/// 것처럼 묶인다. 조명에서 `LightRig` 하나를 씬이 공유하는 것과 같은 역할이다.
Wave reverb(
  Wave dry, {
  double size = 0.5,
  double damp = 0.45,
  double mix = 0.28,
  double tail = 0.6,
}) {
  final rate = dry.rate;
  final out = Wave(rate, dry.length + (tail * rate).round());
  out.data.setRange(0, dry.length, dry.data);
  if (mix <= 0) return out;

  // 서로소에 가까운 지연 길이. 배수 관계면 공명이 뭉쳐 금속통 소리가 난다.
  const combMs = [29.7, 37.1, 41.1, 43.7];
  const allpassMs = [5.0, 1.7];

  final combs = <DelayLine>[];
  final lows = <double>[];
  for (final ms in combMs) {
    combs.add(DelayLine((ms * 0.001 * rate * (0.6 + size)).round()));
    lows.add(0);
  }
  final aps = allpassMs
      .map((ms) => DelayLine((ms * 0.001 * rate).round()))
      .toList();

  final feedback = 0.70 + 0.26 * size.clamp(0.0, 1.0);
  for (var i = 0; i < out.length; i++) {
    final x = i < dry.length ? dry.data[i] : 0.0;
    var wet = 0.0;
    for (var c = 0; c < combs.length; c++) {
      final y = combs[c].read();
      // 콤 안의 저역 통과가 고역부터 먼저 죽인다 — 실제 방의 흡음과 같다.
      lows[c] = y * (1 - damp) + lows[c] * damp;
      combs[c].write(x + lows[c] * feedback);
      wet += y;
    }
    wet *= 0.25;
    for (final ap in aps) {
      final y = ap.read();
      ap.write(wet + y * 0.5);
      wet = y - wet * 0.5;
    }
    out.data[i] = x + wet * mix;
  }
  return out;
}

/// 지연(에코)을 제자리에서 건다. 포효의 골짜기 반향에 쓴다.
void delayInPlace(
  Wave w, {
  double time = 0.16,
  double feedback = 0.35,
  double mix = 0.3,
  double damp = 0.4,
}) {
  final line = DelayLine(math.max(1, (time * w.rate).round()));
  var lo = 0.0;
  for (var i = 0; i < w.length; i++) {
    final y = line.read();
    lo = y * (1 - damp) + lo * damp;
    line.write(w.data[i] + lo * feedback);
    w.data[i] += y * mix;
  }
}

// ---------------------------------------------------------------------------
// WAV 인코딩
// ---------------------------------------------------------------------------

/// 버퍼를 16비트 PCM WAV 바이트로 굽는다.
///
/// [right] 를 주면 스테레오로 인터리브한다. 재생 계층은 이 바이트만 알면
/// 되므로, 합성과 재생이 완전히 분리된다 — 라이브러리는 오디오 백엔드를
/// 하나도 알 필요가 없다.
Uint8List encodeWav(Wave left, {Wave? right}) {
  final channels = right == null ? 1 : 2;
  final frames = right == null
      ? left.length
      : math.min(left.length, right.length);
  final rate = left.rate;
  const bits = 16;
  final blockAlign = channels * bits ~/ 8;
  final dataBytes = frames * blockAlign;

  final out = ByteData(44 + dataBytes);
  var p = 0;
  void ascii(String s) {
    for (final c in s.codeUnits) {
      out.setUint8(p++, c);
    }
  }

  void u32(int v) {
    out.setUint32(p, v, Endian.little);
    p += 4;
  }

  void u16(int v) {
    out.setUint16(p, v, Endian.little);
    p += 2;
  }

  ascii('RIFF');
  u32(36 + dataBytes);
  ascii('WAVE');
  ascii('fmt ');
  u32(16); // PCM 청크 크기
  u16(1); // PCM
  u16(channels);
  u32(rate);
  u32(rate * blockAlign); // 초당 바이트
  u16(blockAlign);
  u16(bits);
  ascii('data');
  u32(dataBytes);

  for (var i = 0; i < frames; i++) {
    out.setInt16(p, _pcm16(left.data[i]), Endian.little);
    p += 2;
    if (right != null) {
      out.setInt16(p, _pcm16(right.data[i]), Endian.little);
      p += 2;
    }
  }
  return out.buffer.asUint8List();
}

int _pcm16(double v) {
  final c = v.clamp(-1.0, 1.0);
  // 32767 을 곱하면 -1.0 이 -32767 이 되어 비대칭이 된다. 부호별로 나눈다.
  final s = (c < 0 ? c * 32768.0 : c * 32767.0).round();
  return s.clamp(-32768, 32767);
}
