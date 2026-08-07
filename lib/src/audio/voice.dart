import 'dart:math' as math;

import '../actor/character_build.dart';
import '../actor/spec.dart';
import '../art/creature.dart';
import '../core/rng.dart';
import 'dsp.dart';
import 'sfx.dart';
import 'wave.dart';

/// 목의 성질. 몬스터의 **정체가 소리로 읽히는 축**이다.
///
/// 실루엣이 "저게 무엇인지"를 눈에 말하듯, 이 값이 귀에 말한다. 화면 밖에서
/// 나는 소리 하나로 무엇이 다가오는지 알 수 있어야 한다.
enum VoiceKind {
  /// 낮게 깔리는 으르렁. 짐승형 근접 몬스터의 기본값.
  growl,

  /// 크게 터지는 포효. 거대한 것에만 준다 — 남발하면 무게가 사라진다.
  roar,

  /// 공허한 곡소리. 언데드·유령.
  wail,

  /// 갑각이 부딪는 딱딱거림 + 째지는 고음. 곤충형.
  chitter,

  /// 파충류의 쉭. 거의 잡음이며 음정이 없다.
  hiss,

  /// 새·박쥐의 비명. 짧고 높고 날카롭다.
  screech,

  /// 사람에 가까운 신음. 구울·좀비.
  moan,
}

/// 한 마리의 목소리.
///
/// ## 왜 시드에서 뽑는가
///
/// 같은 종을 열 마리 놓으면 열 마리가 같은 소리를 낸다 — 그 순간 화면은
/// 복제된 인형들의 무리가 된다. 시드에서 기본 주파수·포먼트·거칢을 조금씩
/// 흔들면 같은 종인데 개체가 다르다는 것이 들린다. 나무마다 `timeOffset` 을
/// 다르게 주는 것과 같은 이유다.
///
/// ## 음원-필터 모형
///
/// 목소리는 두 부분의 곱이다. **성대**(주기적 펄스열 + 거칢)가 음원이고,
/// **성도**(포먼트 공명 세 개)가 필터다. 몸집이 커지면 성도가 길어져 포먼트가
/// 통째로 내려간다 — 그래서 [size] 하나만 올려도 같은 레시피가 거인이 된다.
class CreatureVoice {
  const CreatureVoice({
    required this.seed,
    this.kind = VoiceKind.growl,
    this.size = 0.5,
    this.rasp = 0.55,
    this.breath = 0.25,
    this.accentHz = 0,
    this.rate = kSfxRate,
  });

  /// 개체의 시드. 같은 몬스터는 언제나 같은 목소리를 갖는다.
  final int seed;

  final VoiceKind kind;

  /// 몸집 0..1. 0.5 가 사람 크기, 1 이 거인이다.
  final double size;

  /// 성대의 거칢 0..1. 높을수록 부구조(subharmonic)와 거친 변조가 강해진다.
  final double rasp;

  /// 숨이 섞이는 정도 0..1.
  final double breath;

  /// 정체성을 위해 얹는 공명 하나(Hz). 0 이면 쓰지 않는다.
  ///
  /// 용의 불꽃, 유령의 종소리처럼 **그 몬스터에게만 있는 한 겹**이다.
  final double accentHz;

  final int rate;

  /// [Artist] 하나에서 목소리를 추정한다.
  ///
  /// `id` 가 시드이므로 같은 캐릭터는 언제나 같은 목소리를 낸다.
  /// [kind] 를 넘기지 않으면 골격·직업·몸집에서 고른다 — 이름 있는 몬스터는
  /// 직접 지정하는 편이 언제나 낫다.
  factory CreatureVoice.of(Artist a, {VoiceKind? kind, double? size}) {
    final b = a.build;
    final seed = Rng.fromString(a.id).intRange(1, 0x7FFFFFF);
    final scale = b.heightScale;
    final guessSize = ((scale - 0.85) / 0.6).clamp(0.0, 1.0);
    final r = Rng(seed ^ 0x5A17);
    return CreatureVoice(
      seed: seed,
      kind: kind ?? _guessKind(b, a.camp),
      size: size ?? guessSize,
      rasp: (b.muscle ?? 0.5) * 0.7 + r.range(0.05, 0.25),
      breath: b.beast ? r.range(0.15, 0.35) : r.range(0.25, 0.45),
      accentHz: (b.glowRunes ?? false) ? r.range(1400, 2600) : 0,
    );
  }

  static VoiceKind _guessKind(CharacterBuild b, Camp camp) {
    if (camp != Camp.monster) return VoiceKind.moan;
    if (!b.beast) return VoiceKind.moan;
    if (b.heightScale >= 1.3) return VoiceKind.roar;
    return switch (b.archetype) {
      Archetype.mage => VoiceKind.wail,
      Archetype.assassin => VoiceKind.chitter,
      Archetype.ranger => VoiceKind.screech,
      _ => VoiceKind.growl,
    };
  }

  /// 몸집이 만드는 주파수 배율. 커질수록 모든 것이 내려간다.
  double get _scale => math.pow(2, -(size - 0.5) * 1.7).toDouble();

  _VoiceShape get _shape {
    final r = Rng(seed ^ 0x1CE);
    final s = _scale;
    return switch (kind) {
      VoiceKind.growl => _VoiceShape(
          f0: 78 * s * r.range(0.9, 1.12),
          sharpness: 2.6,
          roughHz: 52 * s,
          roughDepth: 0.30 + 0.35 * rasp,
          sub: 0.42,
          drive: 2.4,
          f1: 480, f2: 1020, f3: 2250,
          reverbMix: 0.16,
        ),
      VoiceKind.roar => _VoiceShape(
          f0: 96 * s * r.range(0.9, 1.10),
          sharpness: 4.4,
          roughHz: 38 * s,
          roughDepth: 0.22 + 0.28 * rasp,
          sub: 0.34,
          drive: 3.6,
          f1: 420, f2: 940, f3: 2050,
          reverbMix: 0.30,
        ),
      VoiceKind.wail => _VoiceShape(
          f0: 232 * s * r.range(0.94, 1.08),
          sharpness: 1.25,
          roughHz: 0,
          roughDepth: 0,
          sub: 0.10,
          drive: 1.2,
          f1: 720, f2: 1620, f3: 2950,
          chorus: 3,
          vibratoHz: 5.4,
          vibratoDepth: 0.055,
          reverbMix: 0.52,
        ),
      VoiceKind.moan => _VoiceShape(
          f0: 118 * s * r.range(0.92, 1.10),
          sharpness: 1.7,
          roughHz: 19 * s,
          roughDepth: 0.16 + 0.22 * rasp,
          sub: 0.18,
          drive: 1.5,
          f1: 560, f2: 1180, f3: 2500,
          vibratoHz: 4.2,
          vibratoDepth: 0.02,
          reverbMix: 0.30,
        ),
      VoiceKind.screech => _VoiceShape(
          f0: 620 * s * r.range(0.9, 1.14),
          sharpness: 5.8,
          roughHz: 96 * s,
          roughDepth: 0.28,
          sub: 0.06,
          drive: 4.2,
          f1: 1300, f2: 2700, f3: 4300,
          reverbMix: 0.24,
        ),
      VoiceKind.hiss => _VoiceShape(
          f0: 0,
          sharpness: 1,
          roughHz: 0,
          roughDepth: 0,
          sub: 0,
          drive: 1.4,
          f1: 3600, f2: 5200, f3: 7400,
          reverbMix: 0.18,
        ),
      VoiceKind.chitter => _VoiceShape(
          f0: 420 * s * r.range(0.9, 1.12),
          sharpness: 3.2,
          roughHz: 140 * s,
          roughDepth: 0.5,
          sub: 0.05,
          drive: 2.6,
          f1: 1800, f2: 3200, f3: 5000,
          reverbMix: 0.14,
        ),
    };
  }

  // ── 네 가지 발화 ────────────────────────────────────────────────────────

  /// 배회하며 흘리는 소리. 짧고 작다 — 이것이 크면 맵이 시끄러워 못 듣는다.
  Wave idle() {
    if (kind == VoiceKind.chitter) return _chitter(0.42, 0.55, seed * 3);
    final s = _shape;
    return _speak(
      seed: seed * 3 + 1,
      duration: lerpd(0.55, 0.95, size),
      shape: s,
      pitch: (u) => 0.82 + 0.10 * bellCurve(u, skew: 0.8),
      env: const Env(attack: 0.09, decay: 0.22, sustain: 0.55,
          sustainTime: 0.14, release: 0.34, curve: 2.4),
      gain: 0.55,
    );
  }

  /// 플레이어를 발견했다. 게임이 "지금부터 위험하다"고 말하는 순간이다.
  Wave alert() {
    if (kind == VoiceKind.chitter) return _chitter(0.55, 0.9, seed * 5);
    final s = _shape;
    return _speak(
      seed: seed * 5 + 3,
      duration: lerpd(0.7, 1.25, size),
      shape: s,
      // 위로 꺾였다가 유지 — 놀람과 위협이 한 문장에 들어간다.
      pitch: (u) => u < 0.18
          ? lerpd(0.78, 1.22, smoothstep01(u / 0.18))
          : lerpd(1.22, 0.94, smoothstep01((u - 0.18) / 0.82)),
      env: const Env(attack: 0.02, decay: 0.16, sustain: 0.72,
          sustainTime: 0.24, release: 0.4, curve: 2.6),
      gain: 0.85,
    );
  }

  /// 덤비며 지르는 소리. 공격 클립의 **예비 정점**(t≈0.25)에 맞춘다.
  Wave attack() {
    if (kind == VoiceKind.chitter) return _chitter(0.5, 1.0, seed * 7);
    final s = _shape;
    return _speak(
      seed: seed * 7 + 5,
      duration: lerpd(0.55, 0.95, size),
      shape: s.copyWith(drive: s.drive * 1.35, roughDepth: s.roughDepth * 1.2),
      pitch: (u) => lerpd(1.34, 0.86, math.pow(u, 0.7).toDouble()),
      env: const Env(attack: 0.008, decay: 0.28, sustain: 0.42,
          sustainTime: 0.08, release: 0.22, curve: 3.2),
      gain: 1.0,
    );
  }

  /// 맞았다. 짧고 위로 꺾인다.
  Wave hurt() {
    final s = _shape;
    if (kind == VoiceKind.chitter) return _chitter(0.26, 1.0, seed * 11);
    return _speak(
      seed: seed * 11 + 7,
      duration: lerpd(0.3, 0.5, size),
      shape: s.copyWith(drive: s.drive * 1.5, breathBias: 0.15),
      pitch: (u) => lerpd(1.42, 0.92, math.pow(u, 0.5).toDouble()),
      env: const Env(attack: 0.004, decay: 0.30, curve: 3.6),
      gain: 0.92,
    );
  }

  /// 죽는다. 길게 내려앉으며 숨으로 흩어진다.
  Wave die() {
    final s = _shape;
    final body = kind == VoiceKind.chitter
        ? _chitter(0.9, 0.8, seed * 13, dying: true)
        : _speak(
            seed: seed * 13 + 9,
            duration: lerpd(1.1, 1.8, size),
            shape: s.copyWith(breathBias: 0.35, roughDepth: s.roughDepth * 1.3),
            pitch: (u) => lerpd(1.15, 0.42, math.pow(u, 0.62).toDouble()),
            env: const Env(attack: 0.01, decay: 0.5, sustain: 0.34,
                sustainTime: 0.2, release: 0.9, curve: 2.2),
            gain: 0.95,
          );
    // 몸이 쓰러지는 소리를 뒤에 붙인다 — 목소리만 있으면 시체가 공중에 남는다.
    final out = Wave.seconds(rate, body.duration + 0.5);
    out.mixIn(body);
    out.mixIn(
      Sfx.bodyFall(seed: seed * 17, weight: 0.35 + 0.6 * size, rate: rate),
      gain: 0.75,
      at: body.duration * 0.62,
    );
    return out.normalize(0.92);
  }

  // ── 합성 ────────────────────────────────────────────────────────────────

  /// 음원-필터 한 문장.
  Wave _speak({
    required int seed,
    required double duration,
    required _VoiceShape shape,
    required double Function(double u) pitch,
    required Env env,
    double gain = 1.0,
  }) {
    final r = Rng(seed);
    final n = (duration * rate).round();
    final dry = Wave(rate, n);
    final s = _scale;

    // 코러스 성부. 하나면 단성, 셋이면 "천 개의 목소리"가 된다.
    final voices = shape.chorus;
    final detunes = List<double>.generate(
        voices, (i) => voices == 1 ? 1.0 : r.range(0.985, 1.017));
    final phases = List<double>.generate(voices, (i) => r.unit);

    final oscs = [for (var i = 0; i < voices; i++) Osc(rate, phase: phases[i])];
    final subs = [for (var i = 0; i < voices; i++) Osc(rate, phase: r.unit)];
    final rough = Osc(rate, phase: r.unit);
    final vib = Osc(rate);
    final noise = WhiteNoise(seed * 31 + 7);
    final noiseHp = OnePole(rate);
    final formants = FormantBank(rate,
        f1: shape.f1, f2: shape.f2, f3: shape.f3);
    final accent = accentHz > 0 ? Svf(rate) : null;
    final dc = DcBlock();
    // 성대의 미세 흔들림(jitter). 완전히 고른 음정은 신시사이저로 들린다.
    var jitter = 0.0;

    final breathAmt = (breath + shape.breathBias).clamp(0.0, 1.0);
    final noiseOnly = shape.f0 <= 0;

    for (var i = 0; i < n; i++) {
      final u = i / n;
      final t = i / rate;

      jitter += (r.signed(1.0) * 0.5 - jitter) * 0.004;
      var f0 = shape.f0 * pitch(u) * (1 + 0.012 * jitter);
      if (shape.vibratoHz > 0) {
        f0 *= 1 + shape.vibratoDepth * vib.sine(shape.vibratoHz);
      }

      var src = 0.0;
      if (!noiseOnly) {
        for (var v = 0; v < voices; v++) {
          src += oscs[v].pulse(f0 * detunes[v], shape.sharpness);
          if (shape.sub > 0) {
            src += subs[v].sine(f0 * 0.5 * detunes[v]) * shape.sub;
          }
        }
        src /= voices;
        // 거친 변조 — 으르렁의 정체. 성대가 불규칙하게 여닫히는 것을 흉내낸다.
        if (shape.roughDepth > 0 && shape.roughHz > 0) {
          final m = 0.5 + 0.5 * rough.sine(shape.roughHz);
          src *= 1 - shape.roughDepth + shape.roughDepth * m;
        }
      }

      // 숨. 고역 잡음이며, 없으면 살아 있는 목이 아니라 악기가 된다.
      final air = noiseHp.hp(noise.next, 900);
      src = src * (1 - breathAmt * 0.75) + air * (noiseOnly ? 1.0 : breathAmt);

      var y = formants.process(src, scale: s * 0.55 + 0.45) + src * 0.22;
      if (accent != null) {
        y += accent.process(src, accentHz, 14, FilterMode.bandpass) * 0.20;
      }
      y = softClip(y * shape.drive);
      y = dc.process(y);
      dry[i] = y * env.at(t) * gain;
    }

    dry.normalize(0.9);
    return reverb(dry,
        size: 0.35 + 0.45 * shape.reverbMix,
        damp: 0.42,
        mix: shape.reverbMix,
        tail: 0.3 + shape.reverbMix)
        .normalize(0.9);
  }

  /// 곤충. 목소리가 아니라 **갑각이 부딪는 소리**이므로 따로 만든다.
  ///
  /// 딱딱거림의 간격이 불규칙해야 살아 있다. 균등하면 기계다.
  Wave _chitter(double duration, double intensity, int s,
      {bool dying = false}) {
    final r = Rng(s);
    final out = Wave.seconds(rate, duration + 0.25);
    final sc = _scale;

    var t = 0.0;
    while (t < duration) {
      final f = r.range(1600, 4200) / sc;
      final ring = Wave.seconds(rate, 0.05);
      final osc = Osc(rate);
      final env = Env.perc(attack: 0.0004, decay: r.range(0.006, 0.018), curve: 6);
      for (var i = 0; i < ring.length; i++) {
        final e = env.at(i / rate);
        if (e <= 0) break;
        ring[i] = (osc.square(f, duty: 0.32) * 0.6 + osc.sine(f * 1.71) * 0.4) * e;
      }
      out.mixIn(ring, gain: intensity * r.range(0.5, 1.0), at: t);
      // 죽어 갈 때는 간격이 벌어진다.
      final slow = dying ? lerpd(1.0, 3.4, t / duration) : 1.0;
      t += r.range(0.018, 0.062) * slow;
    }

    // 째지는 고음 한 겹 — 딱딱거림만 있으면 타자기다.
    _screechLayer(out, seed: s * 7, duration: duration * 0.8,
        from: 3200 / sc, to: dying ? 900 / sc : 5200 / sc,
        gain: 0.42 * intensity);
    return reverb(out, size: 0.3, damp: 0.5, mix: 0.14, tail: 0.3)
        .normalize(0.88);
  }

  void _screechLayer(Wave out,
      {required int seed,
      required double duration,
      required double from,
      required double to,
      double gain = 0.4}) {
    final n = math.min((duration * rate).round(), out.length);
    final noise = WhiteNoise(seed);
    final svf = Svf(rate);
    final env = Env(attack: duration * 0.12, decay: duration * 0.85, curve: 2.6);
    final trem = Osc(rate);
    for (var i = 0; i < n; i++) {
      final u = i / n;
      final f = lerpd(from, to, math.pow(u, 0.7).toDouble());
      final y = svf.process(noise.next, f, 9, FilterMode.bandpass);
      final m = 0.65 + 0.35 * trem.sine(34);
      out.add(i, y * 3.0 * env.at(i / rate) * gain * m);
    }
  }
}

/// 한 목소리의 물리 상수. [CreatureVoice] 가 [VoiceKind] 에서 뽑아 쓴다.
class _VoiceShape {
  const _VoiceShape({
    required this.f0,
    required this.sharpness,
    required this.roughHz,
    required this.roughDepth,
    required this.sub,
    required this.drive,
    required this.f1,
    required this.f2,
    required this.f3,
    this.chorus = 1,
    this.vibratoHz = 0,
    this.vibratoDepth = 0,
    this.reverbMix = 0.2,
    this.breathBias = 0,
  });

  /// 기본 주파수. 0 이면 잡음만 쓴다(쉭 소리).
  final double f0;

  /// 펄스의 좁기. 클수록 배음이 많고 밝다.
  final double sharpness;

  final double roughHz;
  final double roughDepth;

  /// 반옥타브 아래 부구조. 짐승이 사람보다 커 보이게 만드는 값이다.
  final double sub;

  final double drive;
  final double f1, f2, f3;
  final int chorus;
  final double vibratoHz;
  final double vibratoDepth;
  final double reverbMix;
  final double breathBias;

  _VoiceShape copyWith({
    double? drive,
    double? roughDepth,
    double? breathBias,
  }) =>
      _VoiceShape(
        f0: f0,
        sharpness: sharpness,
        roughHz: roughHz,
        roughDepth: roughDepth ?? this.roughDepth,
        sub: sub,
        drive: drive ?? this.drive,
        f1: f1,
        f2: f2,
        f3: f3,
        chorus: chorus,
        vibratoHz: vibratoHz,
        vibratoDepth: vibratoDepth,
        reverbMix: reverbMix,
        breathBias: breathBias ?? this.breathBias,
      );
}
