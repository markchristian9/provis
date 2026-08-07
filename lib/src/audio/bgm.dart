import 'dart:math' as math;

import '../core/rng.dart';
import 'dsp.dart';
import 'sfx.dart';
import 'wave.dart';

/// 배경음의 무드. 씬의 `LightRig.preset(0~3)` 과 같은 순서다.
///
/// **빛과 소리는 같은 시각을 말해야 한다.** 정오의 화면에 달빛의 음악이 깔리면
/// 둘 다 거짓말이 된다. 그래서 프리셋을 바꾸면 조명과 음악이 함께 바뀐다.
enum Mood { noon, dusk, moonlight, campfire }

/// 좌우 두 채널.
class StereoWave {
  StereoWave(this.left, this.right);
  final Wave left;
  final Wave right;
  double get duration => left.duration;
}

/// 절차적 배경음.
///
/// ## 왜 루프 하나를 굽는가
///
/// 매 프레임 합성하면 프레임 예산을 음악이 먹는다. 한 번 구워 두면 재생은
/// 공짜이고, 그 대신 **길이가 곧 반복 주기**가 된다. 20초짜리는 금세 지루해
/// 지므로, 서로 다른 주기의 층을 겹쳐(드론 · 화성 · 선율 · 바람) 되풀이가
/// 눈에 띄지 않게 만든다.
///
/// 이음매는 [Wave.foldTail] 이 없앤다 — 꼬리의 잔향이 머리 위로 접혀 들어가므로
/// 반복 지점에서 소리가 끊기지 않는다.
class Bgm {
  Bgm._();

  /// 무드 하나를 굽는다. 무거운 작업이므로 로딩 중에 한 번만 부른다.
  ///
  /// [seconds] 는 접기 전 길이이며, 결과는 `seconds - 3.5` 초짜리 루프다.
  static StereoWave bake({
    Mood mood = Mood.dusk,
    int seed = 7,
    double seconds = 22.0,
    int rate = kBgmRate,
  }) {
    final r = Rng(seed);
    final v = _voicing(mood);
    final n = (seconds * rate).round();

    final drone = Wave(rate, n);
    final pad = Wave(rate, n);
    final mel = Wave(rate, n);
    final air = Wave(rate, n);

    _drone(drone, v, r.branch(11));
    _pad(pad, v, r.branch(23), seconds);
    _melody(mel, v, r.branch(37), seconds);
    _air(air, v, r.branch(53));

    // 층마다 잔향의 양이 다르다. 선율은 멀리, 드론은 가까이.
    final wetMel = reverb(mel, size: 0.78, damp: 0.34, mix: 0.46, tail: 2.4);
    final wetPad = reverb(pad, size: 0.7, damp: 0.42, mix: 0.30, tail: 1.8);

    Wave build(double melPan, double padPan, double airPan) {
      final out = Wave(rate, n);
      out.mixIn(drone, gain: v.droneGain);
      out.mixIn(wetPad, gain: v.padGain * padPan);
      out.mixIn(wetMel, gain: v.melGain * melPan);
      out.mixIn(air, gain: v.airGain * airPan);
      return out;
    }

    // 좌우로 아주 작은 지연을 주면(하스 효과) 모노 층에서 폭이 생긴다.
    final left = build(1.0, 0.92, 1.0);
    final right = build(0.92, 1.0, 0.94);
    _haas(right, 0.009);

    final l = left.foldTail(3.5).normalize(0.72);
    final rr = right.foldTail(3.5).normalize(0.72);
    return StereoWave(l, rr);
  }

  // ── 층 넷 ───────────────────────────────────────────────────────────────

  /// 드론 — 화면이 존재한다는 사실 자체의 소리. 절대 멈추지 않는다.
  static void _drone(Wave out, _Voicing v, Rng r) {
    final rate = out.rate;
    final sub = Osc(rate, phase: r.unit);
    final a = Osc(rate, phase: r.unit);
    final b = Osc(rate, phase: r.unit);
    final lfo = Osc(rate, phase: r.unit);
    final svf = Svf(rate);
    final root = v.root;
    final det = r.range(1.004, 1.010);

    for (var i = 0; i < out.length; i++) {
      final m = 0.5 + 0.5 * lfo.sine(0.031);
      var y = a.saw(root) + b.saw(root * det);
      y = svf.process(y * 0.5, lerpd(140, 420, m), 0.9);
      y += sub.sine(root * 0.5) * 0.55;
      out[i] = y;
    }
    out.normalize(0.85).fadeIn(1.2);
  }

  /// 화성 — 느리게 부풀었다 꺼지는 패드. 진행이 여기에 있다.
  static void _pad(Wave out, _Voicing v, Rng r, double seconds) {
    final chords = v.progression;
    final per = seconds / chords.length;

    for (var c = 0; c < chords.length; c++) {
      final start = c * per;
      final notes = chords[c];
      for (final semi in notes) {
        final f = v.root * math.pow(2, semi / 12).toDouble();
        // 성부마다 조금씩 어긋나게 들어와야 화음이 "숨을 쉰다".
        final at = start + r.range(0.0, 0.35);
        final len = per + r.range(0.6, 1.4);
        _padVoice(out, f, at, len, r, v);
      }
    }
    out.normalize(0.85);
  }

  static void _padVoice(
      Wave out, double freq, double at, double len, Rng r, _Voicing v) {
    final rate = out.rate;
    final off = out.frameOf(at);
    final n = math.min((len * rate).round(), out.length - off);
    if (n <= 0) return;

    final a = Osc(rate, phase: r.unit);
    final b = Osc(rate, phase: r.unit);
    final c = Osc(rate, phase: r.unit);
    final svf = Svf(rate);
    final lfo = Osc(rate, phase: r.unit);
    final d1 = r.range(0.994, 0.998);
    final d2 = r.range(1.003, 1.008);
    final cutHz = v.padCutoff * r.range(0.85, 1.2);
    final wobbleHz = r.range(0.05, 0.11);
    final env = Env(
      attack: len * 0.35,
      decay: len * 0.2,
      sustain: 0.7,
      sustainTime: len * 0.1,
      release: len * 0.35,
      curve: 1.8,
    );

    for (var i = 0; i < n; i++) {
      final t = i / rate;
      // 성부마다 다른 속도로 열리고 닫혀야 패드가 한 덩어리로 뭉치지 않는다.
      final m = 0.5 + 0.5 * lfo.sine(wobbleHz);
      var y = a.saw(freq) * 0.5 + b.saw(freq * d1) * 0.4 + c.saw(freq * d2) * 0.4;
      y = svf.process(y, cutHz * (0.7 + 0.6 * m), 1.1);
      out.add(off + i, y * env.at(t) * 0.32);
    }
  }

  /// 선율 — 드물게 떨어지는 한 음. **비어 있는 시간이 음악을 만든다.**
  static void _melody(Wave out, _Voicing v, Rng r, double seconds) {
    final beat = 60.0 / v.bpm;
    var t = beat * 2;
    while (t < seconds - 0.5) {
      if (r.chance(v.density)) {
        final semi = r.pick(v.scale) + (r.chance(0.28) ? 12 : 0);
        final f = v.root * 2 * math.pow(2, semi / 12).toDouble();
        final note = pluck(
          freq: f,
          seconds: math.min(2.6, seconds - t),
          bright: v.pluckBright,
          decayTime: v.pluckDecay * r.range(0.85, 1.2),
          seed: r.intRange(1, 1 << 20),
          rate: out.rate,
        );
        out.mixIn(note, gain: r.range(0.5, 0.95), at: t);
      }
      t += beat * r.pick(const [1.0, 1.0, 1.5, 2.0, 0.5]);
    }
    out.normalize(0.85);
  }

  /// 공기 — 바람, 그리고 화톳불이면 불티.
  ///
  /// 이 층이 없으면 음악과 화면 사이가 비어 "메뉴 화면 BGM" 처럼 들린다.
  static void _air(Wave out, _Voicing v, Rng r) {
    final rate = out.rate;
    final pink = PinkNoise(r.intRange(1, 1 << 20));
    final svf = Svf(rate);
    final drift = Osc(rate, phase: r.unit);
    final swell = Osc(rate, phase: r.unit);

    for (var i = 0; i < out.length; i++) {
      final d = 0.5 + 0.5 * drift.sine(0.041);
      final s = 0.45 + 0.55 * (0.5 + 0.5 * swell.sine(0.017));
      out[i] = svf.process(pink.next, lerpd(240, 1500, d), 0.8) * s;
    }
    out.normalize(0.7);

    if (v.embers) {
      // 불티 — 짧고 밝은 알갱이가 불규칙하게 튄다.
      final n = out.length;
      var t = 0.0;
      final total = n / rate;
      while (t < total) {
        final svf2 = Svf(rate);
        final noise = WhiteNoise(r.intRange(1, 1 << 20));
        final env = Env.perc(attack: 0.0005, decay: r.range(0.006, 0.03), curve: 6);
        final off = out.frameOf(t);
        final len = math.min((0.05 * rate).round(), n - off);
        final f = r.range(1800, 5200);
        for (var i = 0; i < len; i++) {
          final y = svf2.process(noise.next, f, 7, FilterMode.bandpass);
          out.add(off + i, y * 2.4 * env.at(i / rate) * r.range(0.15, 0.5));
        }
        t += r.range(0.12, 0.9);
      }
    }
  }

  /// 하스 지연 — 한쪽 채널만 몇 밀리초 늦추면 폭이 생긴다.
  static void _haas(Wave w, double seconds) {
    final d = w.frameOf(seconds);
    if (d <= 0 || d >= w.length) return;
    for (var i = w.length - 1; i >= d; i--) {
      w[i] = w[i] * 0.72 + w[i - d] * 0.34;
    }
  }

  static _Voicing _voicing(Mood mood) => switch (mood) {
        // 정오 — 열린 5도와 장2도. 밝지만 달지 않게.
        Mood.noon => const _Voicing(
            root: 146.83, // D3
            bpm: 64,
            scale: [0, 2, 4, 7, 9, 12],
            progression: [
              [0, 7, 16],
              [5, 12, 21],
              [7, 14, 19],
              [2, 9, 16],
            ],
            padCutoff: 1500,
            density: 0.5,
            pluckBright: 0.62,
            pluckDecay: 1.5,
            droneGain: 0.26,
            padGain: 0.52,
            melGain: 0.42,
            airGain: 0.16,
          ),
        // 황혼 — 도리안. 따뜻하되 이미 그늘이 내려앉았다.
        Mood.dusk => const _Voicing(
            root: 110.0, // A2
            bpm: 56,
            scale: [0, 3, 5, 7, 10, 12],
            progression: [
              [0, 7, 15],
              [10, 17, 24],
              [3, 10, 19],
              [7, 14, 22],
            ],
            padCutoff: 1050,
            density: 0.42,
            pluckBright: 0.5,
            pluckDecay: 1.8,
            droneGain: 0.30,
            padGain: 0.56,
            melGain: 0.40,
            airGain: 0.20,
          ),
        // 달빛 — 에올리안. 음이 드물고 잔향이 길다.
        Mood.moonlight => const _Voicing(
            root: 98.0, // G2
            bpm: 48,
            scale: [0, 3, 7, 10, 14, 15],
            progression: [
              [0, 7, 15],
              [0, 8, 15],
              [-2, 5, 14],
              [0, 7, 12],
            ],
            padCutoff: 780,
            density: 0.26,
            pluckBright: 0.78,
            pluckDecay: 2.6,
            droneGain: 0.34,
            padGain: 0.46,
            melGain: 0.44,
            airGain: 0.24,
          ),
        // 화톳불 — 낮고 좁은 화성. 불티가 튄다.
        Mood.campfire => const _Voicing(
            root: 87.31, // F2
            bpm: 52,
            scale: [0, 2, 3, 7, 10],
            progression: [
              [0, 7, 12],
              [3, 10, 15],
              [0, 7, 14],
              [-2, 5, 10],
            ],
            padCutoff: 620,
            density: 0.34,
            pluckBright: 0.42,
            pluckDecay: 1.3,
            droneGain: 0.36,
            padGain: 0.48,
            melGain: 0.34,
            airGain: 0.30,
            embers: true,
          ),
      };
}

/// 무드 하나의 음악 상수.
class _Voicing {
  const _Voicing({
    required this.root,
    required this.bpm,
    required this.scale,
    required this.progression,
    required this.padCutoff,
    required this.density,
    required this.pluckBright,
    required this.pluckDecay,
    required this.droneGain,
    required this.padGain,
    required this.melGain,
    required this.airGain,
    this.embers = false,
  });

  final double root;
  final double bpm;

  /// 선율이 고를 수 있는 음(반음 단위).
  final List<int> scale;

  /// 화성 진행. 각 원소가 한 화음의 구성음이다.
  final List<List<int>> progression;

  final double padCutoff;

  /// 한 박에 음이 놓일 확률. 낮을수록 여백이 많다.
  final double density;

  final double pluckBright;
  final double pluckDecay;
  final double droneGain;
  final double padGain;
  final double melGain;
  final double airGain;
  final bool embers;
}
