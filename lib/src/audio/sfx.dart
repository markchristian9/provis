import 'dart:math' as math;

import '../actor/spec.dart';
import '../core/rng.dart';
import 'dsp.dart';
import 'wave.dart';

/// 발이 딛는 바닥.
///
/// 발소리는 신발이 아니라 **바닥이 정체를 만든다.** 같은 사람이 걸어도 풀밭과
/// 돌바닥은 완전히 다른 소리이며, 플레이어는 이 차이만으로 자기가 어디에
/// 서 있는지 안다.
enum StepGround { grass, dirt, stone, wood, water }

/// 절차적 효과음 레시피.
///
/// ## 왜 파일을 안 쓰는가
///
/// provis 는 스프라이트 없이 그림을 만든다. 소리도 같은 이유로 파일을 쓰지
/// 않는다 — 시드 하나로 무한한 변주가 나오고, 몬스터의 몸집·성질을 바꾸면
/// 목소리가 **따라서** 바뀌며, 패키지에 바이너리가 한 장도 늘지 않는다.
///
/// ## 모든 레시피의 공통 구조
///
/// 층을 셋으로 나눈다. **몸통**(저역 — 무게), **표면**(중역 잡음 — 재질),
/// **끝단**(고역 순간 — 또렷함). 셋 중 하나가 빠지면 각각 "얇다", "가짜다",
/// "멀다"로 들린다. 그림에서 큰 덩어리·중간 덩어리·작은 디테일의 위계와
/// 정확히 같은 규칙이다.
class Sfx {
  Sfx._();

  // ── 발소리 ──────────────────────────────────────────────────────────────

  /// 한 걸음.
  ///
  /// [weight] 0 은 맨발의 도적, 1 은 판금을 두른 기사다. [running] 이면
  /// 접지가 급해지고 저역이 커진다 — 걷기와 달리기는 다른 소리를 쓰는 것이
  /// 아니라 **같은 소리의 다른 접지**다.
  static Wave footstep({
    int seed = 1,
    StepGround ground = StepGround.grass,
    double weight = 0.5,
    bool running = false,
    int rate = kSfxRate,
  }) {
    final r = Rng(seed);
    final w = weight.clamp(0.0, 1.0);
    final hard = running ? 1.0 : 0.0;

    final dur = switch (ground) {
      StepGround.stone => 0.34,
      StepGround.wood => 0.30,
      StepGround.water => 0.46,
      _ => 0.28,
    };
    final out = Wave.seconds(rate, dur);

    // ① 몸통 — 발뒤꿈치가 땅을 누르는 저역. 음정이 급히 떨어져야 "쿵"이 된다.
    final body = lerpd(128, 58, w) * r.range(0.94, 1.07);
    final bodyDecay = lerpd(0.075, 0.105, w) * (running ? 0.85 : 1.0);
    _tone(
      out,
      seed: seed * 3 + 1,
      from: body * 2.3,
      to: body,
      pitchCurve: 9.0,
      env: Env.perc(attack: 0.0016, decay: bodyDecay, curve: 4.6),
      gain: (0.34 + 0.36 * w) * (1 + 0.22 * hard),
    );

    // ② 표면 — 재질이 여기서 갈린다.
    switch (ground) {
      case StepGround.grass:
        _sweepNoise(
          out,
          seed: seed * 7 + 3,
          pink: true,
          env: Env(attack: 0.0035, decay: 0.13 - 0.03 * hard, curve: 3.2),
          freq: (u) => lerpd(2900, 780, math.pow(u, 0.55).toDouble()),
          q: 1.15,
          gain: 0.50 - 0.10 * w,
        );
        // 마른 풀이 부러지는 잔알갱이. 이것이 없으면 "쉬익"으로만 들린다.
        _grains(
          out,
          seed: seed * 11 + 5,
          count: 5 + r.intRange(0, 4),
          spread: 0.11,
          freq: 4200,
          q: 6,
          gain: 0.16,
        );
      case StepGround.dirt:
        _sweepNoise(
          out,
          seed: seed * 7 + 3,
          pink: true,
          env: Env(attack: 0.003, decay: 0.10, curve: 3.6),
          freq: (u) => lerpd(1500, 420, u),
          q: 0.9,
          gain: 0.42,
        );
        _grains(
          out,
          seed: seed * 11 + 5,
          count: 4,
          spread: 0.07,
          freq: 2600,
          q: 5,
          gain: 0.12,
        );
      case StepGround.stone:
        // 돌은 짧고 밝은 끝단 + 짧은 공명. 잡음만 있으면 모래가 된다.
        _sweepNoise(
          out,
          seed: seed * 7 + 3,
          env: Env(attack: 0.0006, decay: 0.045, curve: 5.0),
          freq: (u) => lerpd(5200, 2600, u),
          q: 1.4,
          mode: FilterMode.highpass,
          gain: 0.34,
        );
        _ring(
          out,
          seed: seed * 13,
          f0: 3300 * r.range(0.95, 1.06),
          ratios: const [1.0, 1.62, 2.31],
          decay: 0.085,
          gain: 0.16,
        );
      case StepGround.wood:
        // 나무는 속이 비었다 — 낮은 공명 두 개가 그 사실을 말한다.
        _ring(
          out,
          seed: seed * 13,
          f0: 205 * r.range(0.93, 1.08),
          ratios: const [1.0, 1.74, 2.85],
          decay: 0.16,
          gain: 0.30,
        );
        _sweepNoise(
          out,
          seed: seed * 7 + 3,
          env: Env(attack: 0.001, decay: 0.06, curve: 4.2),
          freq: (u) => lerpd(2400, 1100, u),
          q: 1.2,
          gain: 0.24,
        );
      case StepGround.water:
        _sweepNoise(
          out,
          seed: seed * 7 + 3,
          env: Env(attack: 0.004, decay: 0.24, curve: 2.6),
          freq: (u) => lerpd(3400, 380, math.pow(u, 0.7).toDouble()),
          q: 0.8,
          gain: 0.55,
        );
        // 물방울 — 위로 올라가는 음정이 물의 신호다.
        for (var i = 0; i < 3; i++) {
          final f = r.range(700, 1600);
          _tone(
            out,
            seed: seed * 17 + i,
            from: f * 0.62,
            to: f,
            pitchCurve: -5.0,
            env: Env.perc(attack: 0.001, decay: 0.055, curve: 5),
            gain: 0.13,
            at: r.range(0.03, 0.20),
          );
        }
    }

    // ③ 끝단 — 접지 순간의 딱. 달릴 때만 확실히 들려야 한다.
    if (running || ground == StepGround.stone) {
      _sweepNoise(
        out,
        seed: seed * 19 + 7,
        env: Env(attack: 0.0004, decay: 0.016, curve: 6),
        freq: (u) => 6200,
        q: 0.9,
        mode: FilterMode.highpass,
        gain: 0.12 + 0.10 * hard,
      );
    }

    // 판금은 걸을 때마다 짤그랑거린다.
    if (w > 0.6) {
      _grains(
        out,
        seed: seed * 23 + 9,
        count: 3,
        spread: 0.09,
        freq: 5200,
        q: 14,
        gain: 0.10 * (w - 0.6) / 0.4,
      );
    }

    return out.normalize(0.62 + 0.16 * w + (running ? 0.08 : 0.0));
  }

  // ── 휘두르기 ────────────────────────────────────────────────────────────

  /// 무기가 공기를 가르는 소리.
  ///
  /// 정체는 **도플러**다. 날이 다가올 때 대역 중심이 올라가고 지나가면
  /// 내려간다. 고정 대역 잡음을 페이드시키면 아무리 다듬어도 "바람 소리"에
  /// 머문다.
  ///
  /// 공격 클립(`Anims.attack`)의 임팩트는 t≈0.5 다. 이 소리의 봉우리는 앞으로
  /// 당겨져 있으므로(skew) **스윙 시작에 맞춰 재생하면** 봉우리가 임팩트에
  /// 떨어진다.
  static Wave swing({
    int seed = 1,
    WeaponKind weapon = WeaponKind.sword,
    double power = 0.6,
    int rate = kSfxRate,
  }) {
    final r = Rng(seed);
    final p = power.clamp(0.0, 1.0);
    final (base, span, q, dur, metal, sub) = switch (weapon) {
      WeaponKind.sword => (620.0, 3.4, 3.0, 0.36, 0.26, 0.12),
      WeaponKind.greatsword => (330.0, 3.0, 2.4, 0.52, 0.30, 0.42),
      WeaponKind.axe => (300.0, 2.8, 2.0, 0.46, 0.12, 0.46),
      WeaponKind.spear => (900.0, 3.6, 4.0, 0.30, 0.18, 0.08),
      WeaponKind.daggers => (1500.0, 3.2, 5.0, 0.22, 0.30, 0.0),
      WeaponKind.staff => (420.0, 2.6, 1.6, 0.42, 0.0, 0.28),
      WeaponKind.bow => (700.0, 2.4, 3.0, 0.26, 0.0, 0.05),
      WeaponKind.none => (500.0, 2.6, 1.4, 0.34, 0.0, 0.30),
    };

    final length = dur * lerpd(1.12, 0.88, p) * r.range(0.95, 1.06);
    final out = Wave.seconds(rate, length + 0.06);
    final tilt = r.range(0.92, 1.09);

    // 대역 중심이 올라갔다 내려온다 — 이 곡선 하나가 도플러의 전부다.
    _sweepNoise(
      out,
      seed: seed * 5 + 1,
      pink: weapon == WeaponKind.staff || weapon == WeaponKind.none,
      env: Env(attack: length * 0.20, decay: length * 0.72, curve: 2.2),
      freq: (u) => base * tilt * (1 + span * bellCurve(u, skew: 1.35)),
      q: q,
      gain: 0.55 + 0.35 * p,
      duration: length,
    );

    // 무거운 것은 저역 덩어리가 따라온다.
    if (sub > 0.01) {
      _sweepNoise(
        out,
        seed: seed * 5 + 11,
        pink: true,
        env: Env(attack: length * 0.28, decay: length * 0.66, curve: 2.0),
        freq: (u) => lerpd(70, 190, bellCurve(u, skew: 1.35)),
        q: 1.1,
        gain: sub * (0.5 + 0.5 * p),
        duration: length,
      );
    }

    // 날붙이는 스치는 순간 아주 짧게 운다.
    if (metal > 0.01) {
      final peak = length * 0.42;
      _ring(
        out,
        seed: seed * 29,
        f0: 2600 * r.range(0.92, 1.10),
        ratios: const [1.0, 1.51, 2.17],
        decay: 0.09,
        gain: metal * 0.22 * (0.4 + 0.6 * p),
        at: peak,
      );
    }
    return out.normalize(0.55 + 0.30 * p);
  }

  // ── 타격 ────────────────────────────────────────────────────────────────

  /// 무언가를 때린 순간.
  ///
  /// 판정 창(`progress` 0.375~0.5)에서 재생한다. 스윙과 타격이 **다른 소리**
  /// 라는 점이 중요하다 — 하나로 합치면 빗나갔을 때도 맞은 것처럼 들린다.
  static Wave impact({
    int seed = 1,
    double weight = 0.6,
    bool armored = false,
    int rate = kSfxRate,
  }) {
    final r = Rng(seed);
    final w = weight.clamp(0.0, 1.0);
    final out = Wave.seconds(rate, armored ? 0.85 : 0.42);

    // ① 몸통 — 음정이 급락하는 사인. 타격감의 8할이 여기 있다.
    final f = lerpd(190, 95, w);
    _tone(
      out,
      seed: seed * 3,
      from: f * r.range(0.95, 1.06),
      to: f * 0.32,
      pitchCurve: 11.0,
      env: Env.perc(attack: 0.001, decay: lerpd(0.12, 0.20, w), curve: 4.0),
      gain: 0.55 + 0.30 * w,
    );

    // ② 끝단 — 1ms 어택의 잡음. 이것이 "때린" 느낌을 만든다.
    _sweepNoise(
      out,
      seed: seed * 7,
      env: Env(attack: 0.0005, decay: 0.055, curve: 5.5),
      freq: (u) => lerpd(2400, 900, u),
      q: 1.3,
      gain: 0.45,
    );

    // ③ 표면 — 살이면 둔탁하게, 갑옷이면 금속이 운다.
    if (armored) {
      _ring(
        out,
        seed: seed * 13,
        f0: 640 * r.range(0.9, 1.12),
        ratios: const [1.0, 1.71, 2.43, 3.19, 4.11, 5.37],
        decay: 0.55,
        gain: 0.34,
        detune: 1.8,
      );
      _sweepNoise(
        out,
        seed: seed * 17,
        env: Env(attack: 0.0004, decay: 0.03, curve: 6),
        freq: (u) => 7000,
        q: 0.8,
        mode: FilterMode.highpass,
        gain: 0.22,
      );
    } else {
      _sweepNoise(
        out,
        seed: seed * 17,
        pink: true,
        env: Env(attack: 0.002, decay: 0.11, curve: 3.4),
        freq: (u) => lerpd(900, 320, u),
        q: 0.85,
        gain: 0.34,
      );
    }
    return reverb(
      out,
      size: 0.35,
      damp: 0.55,
      mix: 0.16,
      tail: 0.35,
    ).normalize(0.90);
  }

  // ── 방어 ────────────────────────────────────────────────────────────────

  /// 방패를 들어 올리는 순간. 조용해야 한다 — 이건 준비 동작이지 사건이 아니다.
  static Wave guardUp({int seed = 1, int rate = kSfxRate}) {
    final r = Rng(seed);
    final out = Wave.seconds(rate, 0.34);
    // 가죽끈이 스치는 소리.
    _sweepNoise(
      out,
      seed: seed * 5,
      pink: true,
      env: Env(attack: 0.03, decay: 0.16, curve: 2.4),
      freq: (u) => lerpd(1600, 620, u),
      q: 1.0,
      gain: 0.34,
    );
    // 팔에 닿는 둔한 소리.
    _tone(
      out,
      seed: seed * 3,
      from: 150 * r.range(0.9, 1.1),
      to: 82,
      pitchCurve: 7,
      env: Env.perc(attack: 0.004, decay: 0.10, curve: 4),
      gain: 0.30,
      at: 0.05,
    );
    _ring(
      out,
      seed: seed * 11,
      f0: 880 * r.range(0.9, 1.1),
      ratios: const [1.0, 1.66, 2.38],
      decay: 0.18,
      gain: 0.12,
      at: 0.05,
    );
    return out.normalize(0.42);
  }

  /// 막아 냈다.
  ///
  /// **방어가 성공했다는 사실은 소리로만 전달된다.** 공격 애니메이션은
  /// 그대로 나오고 피격 모션만 없을 뿐이므로, 이 소리가 없으면 플레이어는
  /// 자기가 막았는지 빗나갔는지 구분하지 못한다. 그래서 다른 어떤 효과음과도
  /// 헷갈리지 않는 **금속의 비화성 배음**을 쓴다.
  static Wave block({
    int seed = 1,
    bool metal = true,
    double power = 0.7,
    int rate = kSfxRate,
  }) {
    final r = Rng(seed);
    final p = power.clamp(0.0, 1.0);
    final out = Wave.seconds(rate, metal ? 1.15 : 0.55);

    // 부딪는 순간.
    _sweepNoise(
      out,
      seed: seed * 7,
      env: Env(attack: 0.0004, decay: 0.028, curve: 6.5),
      freq: (u) => lerpd(6000, 2200, u),
      q: 1.0,
      mode: FilterMode.highpass,
      gain: 0.42,
    );
    _tone(
      out,
      seed: seed * 3,
      from: 210,
      to: 74,
      pitchCurve: 12,
      env: Env.perc(attack: 0.0008, decay: 0.11, curve: 4.4),
      gain: 0.40 + 0.20 * p,
    );

    if (metal) {
      // 비화성 배음 + 미세 디튠. 디튠이 없으면 종이 아니라 신시사이저다.
      _ring(
        out,
        seed: seed * 13,
        f0: 430 * r.range(0.92, 1.10),
        ratios: const [1.0, 1.732, 2.412, 3.147, 4.213, 5.026, 6.41],
        decay: 0.62 + 0.35 * p,
        gain: 0.52,
        detune: 2.4,
      );
      _ring(
        out,
        seed: seed * 31,
        f0: 1870 * r.range(0.94, 1.08),
        ratios: const [1.0, 1.39, 2.06],
        decay: 0.20,
        gain: 0.18,
      );
    } else {
      // 나무 방패 — 낮은 통 울림에 곧 죽는다.
      _ring(
        out,
        seed: seed * 13,
        f0: 240 * r.range(0.92, 1.10),
        ratios: const [1.0, 1.78, 2.61, 3.44],
        decay: 0.22,
        gain: 0.44,
      );
      _sweepNoise(
        out,
        seed: seed * 17,
        pink: true,
        env: Env(attack: 0.002, decay: 0.09, curve: 3.6),
        freq: (u) => lerpd(1400, 500, u),
        q: 1.0,
        gain: 0.24,
      );
    }
    return reverb(
      out,
      size: 0.5,
      damp: 0.4,
      mix: 0.22,
      tail: 0.5,
    ).normalize(0.94);
  }

  /// 빗나가서 흘렸다(패링). 막기보다 짧고 높다.
  static Wave parry({int seed = 1, int rate = kSfxRate}) {
    final r = Rng(seed);
    final out = Wave.seconds(rate, 0.75);
    _sweepNoise(
      out,
      seed: seed * 7,
      env: Env(attack: 0.0003, decay: 0.02, curve: 7),
      freq: (u) => 7600,
      q: 0.9,
      mode: FilterMode.highpass,
      gain: 0.40,
    );
    _ring(
      out,
      seed: seed * 13,
      f0: 1240 * r.range(0.94, 1.09),
      ratios: const [1.0, 1.68, 2.44, 3.31, 4.62],
      decay: 0.40,
      gain: 0.55,
      detune: 3.2,
    );
    // 날이 미끄러지는 짧은 상승.
    _sweepNoise(
      out,
      seed: seed * 19,
      env: Env(attack: 0.004, decay: 0.10, curve: 3),
      freq: (u) => lerpd(2600, 5400, u),
      q: 5.0,
      gain: 0.22,
    );
    return reverb(
      out,
      size: 0.45,
      damp: 0.35,
      mix: 0.24,
      tail: 0.4,
    ).normalize(0.88);
  }

  // ── 원거리 ──────────────────────────────────────────────────────────────

  /// 시위를 놓는다.
  static Wave bowShot({int seed = 1, int rate = kSfxRate}) {
    final r = Rng(seed);
    final out = Wave.seconds(rate, 0.55);
    // 시위 — 뜯은 현 그 자체다.
    out.mixIn(
      pluck(
        freq: 132 * r.range(0.93, 1.08),
        seconds: 0.30,
        bright: 0.72,
        decayTime: 0.16,
        seed: seed * 3,
        rate: rate,
      ),
      gain: 0.6,
    );
    // 놓는 순간의 파열.
    _sweepNoise(
      out,
      seed: seed * 7,
      env: Env(attack: 0.0006, decay: 0.055, curve: 5),
      freq: (u) => lerpd(3200, 1100, u),
      q: 1.6,
      gain: 0.42,
    );
    // 화살이 멀어진다.
    _sweepNoise(
      out,
      seed: seed * 11,
      env: Env(attack: 0.01, decay: 0.34, curve: 2.4),
      freq: (u) => lerpd(2200, 620, u),
      q: 3.4,
      gain: 0.20,
      at: 0.02,
    );
    return out.normalize(0.80);
  }

  /// 지팡이 끝에서 마력을 모아 탄환으로 날린다.
  static Wave magicCast({int seed = 1, int rate = kSfxRate}) {
    final r = Rng(seed);
    final out = Wave.seconds(rate, 0.72);

    // 시작의 상승음이 마력이 모이는 방향을 말한다.
    _tone(
      out,
      seed: seed * 3,
      from: 310 * r.range(0.94, 1.06),
      to: 1280 * r.range(0.96, 1.05),
      pitchCurve: 1.8,
      env: Env.perc(attack: 0.018, decay: 0.42, curve: 2.2),
      gain: 0.42,
    );
    // 유리처럼 깨끗한 비정수 공명이 화살의 시위와 다른 재질을 만든다.
    _ring(
      out,
      seed: seed * 7,
      f0: 720 * r.range(0.95, 1.08),
      ratios: const [1.0, 1.41, 2.17, 3.03],
      decay: 0.48,
      gain: 0.34,
    );
    _sweepNoise(
      out,
      seed: seed * 11,
      env: Env(attack: 0.004, decay: 0.24, curve: 2.8),
      freq: (u) => lerpd(5200, 1500, u),
      q: 3.8,
      gain: 0.18,
      at: 0.05,
    );
    return reverb(
      out,
      size: 0.62,
      damp: 0.28,
      mix: 0.34,
      tail: 0.55,
    ).normalize(0.82);
  }

  // ── 몸이 쓰러진다 ───────────────────────────────────────────────────────

  /// 시체가 땅에 닿는 소리. `death` 클립의 끝(t≈0.75)에 맞춘다.
  static Wave bodyFall({
    int seed = 1,
    double weight = 0.6,
    int rate = kSfxRate,
  }) {
    final r = Rng(seed);
    final w = weight.clamp(0.0, 1.0);
    final out = Wave.seconds(rate, 0.9);
    _tone(
      out,
      seed: seed * 3,
      from: lerpd(120, 74, w),
      to: lerpd(44, 30, w),
      pitchCurve: 8,
      env: Env.perc(attack: 0.004, decay: 0.26, curve: 3.4),
      gain: 0.70,
    );
    _sweepNoise(
      out,
      seed: seed * 7,
      pink: true,
      env: Env(attack: 0.006, decay: 0.30, curve: 2.8),
      freq: (u) => lerpd(1300, 260, u),
      q: 0.8,
      gain: 0.40,
    );
    // 흙과 장비가 흩어진다.
    _grains(
      out,
      seed: seed * 11,
      count: 6 + r.intRange(0, 5),
      spread: 0.42,
      freq: 3400,
      q: 6,
      gain: 0.14,
    );
    return reverb(
      out,
      size: 0.5,
      damp: 0.5,
      mix: 0.18,
      tail: 0.5,
    ).normalize(0.86);
  }

  // ── UI ──────────────────────────────────────────────────────────────────

  /// 클릭 표식이 지면에 찍힐 때. `MoveMarker.ping` 과 짝이다.
  static Wave moveMark({int seed = 1, int rate = kSfxRate}) {
    final out = Wave.seconds(rate, 0.24);
    _tone(
      out,
      seed: seed,
      from: 1180,
      to: 1760,
      pitchCurve: -3.0,
      env: Env(attack: 0.002, decay: 0.13, curve: 4),
      gain: 0.30,
    );
    _tone(
      out,
      seed: seed + 1,
      from: 2360,
      to: 3520,
      pitchCurve: -3.0,
      env: Env(attack: 0.002, decay: 0.07, curve: 5),
      gain: 0.10,
    );
    return out.normalize(0.30);
  }

  /// 버튼.
  static Wave uiClick({
    int seed = 1,
    bool confirm = false,
    int rate = kSfxRate,
  }) {
    final out = Wave.seconds(rate, confirm ? 0.34 : 0.14);
    _tone(
      out,
      seed: seed,
      from: confirm ? 620 : 900,
      to: confirm ? 930 : 900,
      pitchCurve: -4,
      env: Env(attack: 0.001, decay: confirm ? 0.10 : 0.05, curve: 5),
      gain: 0.34,
    );
    if (confirm) {
      _tone(
        out,
        seed: seed + 1,
        from: 1240,
        to: 1860,
        pitchCurve: -4,
        env: Env(attack: 0.002, decay: 0.16, curve: 4),
        gain: 0.22,
        at: 0.07,
      );
    }
    return out.normalize(0.34);
  }
}

// ---------------------------------------------------------------------------
// 공용 층 — 레시피는 전부 이 넷의 조합이다
// ---------------------------------------------------------------------------

/// 음정이 움직이는 사인. 모든 "쿵"과 "핑"의 몸통.
///
/// [pitchCurve] 가 양수면 지수적으로 떨어지고, 음수면 올라간다. 선형으로
/// 움직이면 사이렌처럼 들리므로 반드시 지수여야 한다.
void _tone(
  Wave out, {
  required int seed,
  required double from,
  required double to,
  required Env env,
  double pitchCurve = 8.0,
  double gain = 1.0,
  double at = 0.0,
  double? duration,
}) {
  final rate = out.rate;
  final len = duration ?? env.duration;
  final n = math.min((len * rate).round(), out.length - out.frameOf(at));
  if (n <= 0) return;
  final osc = Osc(rate);
  final off = out.frameOf(at);
  for (var i = 0; i < n; i++) {
    final u = i / n;
    final k = pitchCurve >= 0
        ? math.exp(-pitchCurve * u)
        : 1 - math.exp(pitchCurve * u);
    final f = to + (from - to) * k;
    out.add(off + i, osc.sine(f) * env.at(i / rate) * gain);
  }
}

/// 대역이 움직이는 잡음. 모든 "쉬익"과 "촤악"의 표면.
void _sweepNoise(
  Wave out, {
  required int seed,
  required Env env,
  required double Function(double u) freq,
  double q = 2.0,
  FilterMode mode = FilterMode.bandpass,
  double gain = 1.0,
  bool pink = false,
  double at = 0.0,
  double? duration,
}) {
  final rate = out.rate;
  final len = duration ?? env.duration;
  final off = out.frameOf(at);
  final n = math.min((len * rate).round(), out.length - off);
  if (n <= 0) return;
  final white = WhiteNoise(seed);
  final pinkGen = pink ? PinkNoise(seed * 7 + 13) : null;
  final svf = Svf(rate);
  // 대역 통과는 통과 대역이 좁을수록 출력이 작다. Q 로 보정하지 않으면
  // 날카로운 소리일수록 조용해져 레시피의 gain 이 의미를 잃는다.
  final comp = mode == FilterMode.bandpass ? math.sqrt(q).clamp(1.0, 6.0) : 1.0;
  for (var i = 0; i < n; i++) {
    final u = i / n;
    final src = pinkGen != null ? pinkGen.next : white.next;
    final y = svf.process(src, freq(u), q, mode);
    out.add(off + i, y * comp * env.at(i / rate) * gain);
  }
}

/// 비화성 배음 다발. 금속·돌·나무의 공명.
///
/// [ratios] 가 정수배(1, 2, 3…)면 악기 음정으로 들린다. 부딪는 물건은 정수배가
/// **아니어야** 한다 — 1.732 같은 무리수 비율이 "종"과 "때린 쇳덩이"를 가른다.
void _ring(
  Wave out, {
  required int seed,
  required double f0,
  required List<double> ratios,
  required double decay,
  double gain = 1.0,
  double at = 0.0,
  double detune = 0.0,
}) {
  final rate = out.rate;
  final r = Rng(seed);
  final off = out.frameOf(at);
  for (var p = 0; p < ratios.length; p++) {
    final f = f0 * ratios[p] + r.signed(detune);
    if (f >= rate * 0.45) continue;
    // 높은 배음일수록 빨리 죽는다 — 실제 금속의 감쇠 법칙이다.
    final d = decay / (1 + 0.85 * p);
    final env = Env.perc(attack: 0.0008, decay: d, curve: 3.6);
    final g = gain / (1 + 1.25 * p) * r.range(0.82, 1.12);
    final n = math.min((d * 1.05 * rate).round(), out.length - off);
    if (n <= 0) continue;
    final osc = Osc(rate, phase: r.unit);
    for (var i = 0; i < n; i++) {
      out.add(off + i, osc.sine(f) * env.at(i / rate) * g);
    }
  }
}

/// 짧은 잡음 알갱이를 흩뿌린다. 부스러기·짤그랑거림.
void _grains(
  Wave out, {
  required int seed,
  required int count,
  required double spread,
  required double freq,
  double q = 8,
  double gain = 0.2,
  double at = 0.0,
}) {
  final r = Rng(seed);
  for (var i = 0; i < count; i++) {
    _sweepNoise(
      out,
      seed: seed * 131 + i * 17,
      env: Env(attack: 0.0004, decay: r.range(0.008, 0.026), curve: 6),
      freq: (u) => freq * r.range(0.7, 1.45),
      q: q,
      gain: gain * r.range(0.5, 1.2),
      at: at + r.range(0.0, spread),
    );
  }
}

/// 카플러스-스트롱 플럭 — 뜯은 현.
///
/// 잡음 한 줌을 현 길이만큼의 지연선에 넣고 매 바퀴 저역 통과로 깎으면,
/// 고역부터 먼저 사라지는 **진짜 현의 감쇠**가 나온다. 스무 줄로 활시위와
/// 하프를 동시에 얻는다.
Wave pluck({
  required double freq,
  required double seconds,
  double bright = 0.5,
  double decayTime = 0.4,
  int seed = 1,
  int rate = kSfxRate,
}) {
  final n = math.max(2, (rate / freq).round());
  final line = DelayLine(n);
  final noise = WhiteNoise(seed);
  var lo = 0.0;
  final a = bright.clamp(0.05, 1.0);
  for (var i = 0; i < n; i++) {
    lo += a * (noise.next - lo);
    line.write(lo);
  }

  final out = Wave.seconds(rate, seconds);
  final loops = seconds / (n / rate);
  final perLoop = math.pow(0.001, 1 / math.max(1.0, decayTime / (n / rate)));
  final fb = perLoop.toDouble().clamp(0.0, 0.9999);
  var prev = 0.0;
  for (var i = 0; i < out.length; i++) {
    final cur = line.read();
    final y = 0.5 * (cur + prev) * fb;
    prev = cur;
    line.write(y);
    out[i] = cur;
  }
  // loops 는 계산에 쓰이지 않지만, 감쇠가 버퍼 길이를 넘지 않는지 확인하는
  // 근거로 남긴다.
  assert(loops > 0);
  return out;
}
