import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:provis/provis.dart';

import 'wav_source.dart';

/// 한 마리(또는 한 사람)의 목소리 설계도.
///
/// [CreatureVoice] 를 그대로 격리 스레드에 보낼 수 없으므로(그 안의 로직이
/// 아니라 **값만** 건너가야 한다) 원시 값으로 풀어 놓는다.
@immutable
class VoiceSpec {
  const VoiceSpec({
    required this.id,
    required this.seed,
    required this.kind,
    required this.size,
    required this.rasp,
    required this.breath,
    required this.accentHz,
  });

  /// [Artist.id]. 창고의 이름표가 된다.
  final String id;
  final int seed;
  final int kind;
  final double size;
  final double rasp;
  final double breath;
  final double accentHz;

  /// 캐릭터 하나에서 뽑는다. [kind] 를 주면 추정을 덮어쓴다 — 이름 있는
  /// 몬스터는 직접 정하는 편이 언제나 낫다.
  factory VoiceSpec.of(Artist a, {VoiceKind? kind}) {
    final v = CreatureVoice.of(a, kind: kind);
    return VoiceSpec(
      id: a.id,
      seed: v.seed,
      kind: v.kind.index,
      size: v.size,
      rasp: v.rasp,
      breath: v.breath,
      accentHz: v.accentHz,
    );
  }

  CreatureVoice toVoice(int rate) => CreatureVoice(
    seed: seed,
    kind: VoiceKind.values[kind],
    size: size,
    rasp: rasp,
    breath: breath,
    accentHz: accentHz,
    rate: rate,
  );
}

/// 이 게임이 실제로 쓰는 소리만 굽기 위한 주문서.
///
/// 표준 창고를 통째로 구우면 쓰지도 않는 무기의 휘두르기까지 만든다. 맵이
/// 아는 것만 굽는 편이 로딩이 몇 배 빠르다.
@immutable
class BakeOrder {
  const BakeOrder({
    required this.seed,
    required this.grounds,
    required this.weapons,
    required this.voices,
    this.sfxRate = kSfxRate,
    this.voiceRate = kBgmRate,
  });

  final int seed;

  /// [StepGround] 의 인덱스들.
  final List<int> grounds;

  /// [WeaponKind] 의 인덱스들.
  final List<int> weapons;

  final List<VoiceSpec> voices;

  final int sfxRate;

  /// 목소리는 어둡고 길어 고역이 거의 없다. 절반 표본율이면 충분하고,
  /// 굽는 시간도 절반이다.
  final int voiceRate;
}

/// 격리 스레드에서 창고를 통째로 굽는다.
///
/// **UI 스레드에서 구우면 안 된다.** 몬스터 목소리 하나가 100~200ms 이므로
/// 스무 개를 앞에서 구우면 화면이 몇 초 얼어붙는다.
Map<String, List<Uint8List>> bakeClips(BakeOrder order) {
  final bank = SoundBank(rate: order.sfxRate);

  for (final gi in order.grounds) {
    final g = StepGround.values[gi];
    for (final running in [false, true]) {
      bank.addVariants(SfxKeys.step(g, running: running), 4, (s) {
        final r = Rng(s);
        return Sfx.footstep(
          seed: s,
          ground: g,
          weight: r.bell(0.35, 0.72),
          running: running,
          rate: order.sfxRate,
        ).resampled(r.range(0.94, 1.07));
      });
    }
  }

  for (final wi in order.weapons) {
    final w = WeaponKind.values[wi];
    bank.addVariants(
      SfxKeys.swing(w),
      3,
      (s) => Sfx.swing(
        seed: s,
        weapon: w,
        power: Rng(s).bell(0.45, 0.85),
        rate: order.sfxRate,
      ),
    );
  }

  bank.addVariants(
    SfxKeys.impactFlesh,
    3,
    (s) => Sfx.impact(
      seed: s,
      weight: Rng(s).bell(0.4, 0.75),
      rate: order.sfxRate,
    ),
  );
  bank.addVariants(
    SfxKeys.impactArmor,
    2,
    (s) => Sfx.impact(
      seed: s,
      weight: Rng(s).bell(0.5, 0.85),
      armored: true,
      rate: order.sfxRate,
    ),
  );
  bank.addVariants(
    SfxKeys.blockMetal,
    3,
    (s) =>
        Sfx.block(seed: s, power: Rng(s).bell(0.5, 0.9), rate: order.sfxRate),
  );
  bank.addVariants(
    SfxKeys.parry,
    2,
    (s) => Sfx.parry(seed: s, rate: order.sfxRate),
  );
  bank.addVariants(
    SfxKeys.guardUp,
    2,
    (s) => Sfx.guardUp(seed: s, rate: order.sfxRate),
  );
  // 원거리 소리는 선택한 영웅과 상관없이 굽는다. `release` 클립 이벤트가
  // 활과 마법 중 하나를 부르므로, 빠뜨리면 해당 영웅의 첫 발사에서 게임
  // 루프가 죽는다.
  bank.addVariants(
    SfxKeys.bowShot,
    2,
    (s) => Sfx.bowShot(seed: s, rate: order.sfxRate),
  );
  bank.addVariants(
    SfxKeys.magicCast,
    2,
    (s) => Sfx.magicCast(seed: s, rate: order.sfxRate),
  );
  bank.addVariants(
    SfxKeys.bodyFall,
    2,
    (s) => Sfx.bodyFall(
      seed: s,
      weight: Rng(s).bell(0.35, 0.8),
      rate: order.sfxRate,
    ),
  );
  bank.addVariants(
    SfxKeys.moveMark,
    2,
    (s) => Sfx.moveMark(seed: s, rate: order.sfxRate),
  );
  bank.add(
    SfxKeys.uiClick,
    () => Sfx.uiClick(seed: order.seed, rate: order.sfxRate),
  );

  for (final v in order.voices) {
    bank.addVoice(v.id, v.toVoice(order.voiceRate));
  }

  // 전부 굽는다 — 이 함수가 도는 곳이 격리 스레드이므로 여기서 다 끝내야
  // 게임 중에 다시 구울 일이 없다.
  final out = <String, List<Uint8List>>{};
  for (final key in bank.keys) {
    out[key] = [
      for (var i = 0; i < bank.variants(key); i++) bank.bytes(key, i),
    ];
  }
  return out;
}

/// 격리 스레드에서 배경음 한 곡을 굽는다.
Uint8List bakeBgm(List<int> moodAndSeed) {
  final s = Bgm.bake(
    mood: Mood.values[moodAndSeed[0]],
    seed: moodAndSeed[1],
    seconds: 22.0,
  );
  return encodeWav(s.left, right: s.right);
}

/// 게임의 소리 담당.
///
/// ## 세 겹으로 나뉜다
///
/// | 겹 | 하는 일 | 어디에 있나 |
/// |---|---|---|
/// | 합성 | 파형을 만든다 | `provis` — 오디오 백엔드를 모른다 |
/// | 굽기 | WAV 바이트로 굳힌다 | 격리 스레드 ([bakeClips]) |
/// | 재생 | 스피커로 보낸다 | 이 클래스 |
///
/// 이렇게 갈라 두면 라이브러리는 재생 패키지에 묶이지 않고, 게임은 합성
/// 비용을 프레임 예산에서 뺀다.
class GameAudio {
  GameAudio({this.seed = 7, int voices = 12})
    : _pool = List.generate(
        voices,
        (_) => AudioPlayer()..setReleaseMode(ReleaseMode.stop),
      );

  final int seed;

  /// 동시에 울릴 수 있는 효과음의 수.
  ///
  /// 하나로 돌리면 새 소리가 이전 소리를 자른다 — 발소리가 타격음을 잘라
  /// 먹으면 전투가 통째로 조용해진다.
  final List<AudioPlayer> _pool;
  int _next = 0;

  final AudioPlayer _bgmPlayer = AudioPlayer()
    ..setReleaseMode(ReleaseMode.loop);

  final Map<String, List<Uint8List>> _clips = {};
  final Map<String, Source> _sources = {};
  final Map<int, Uint8List> _bgmCache = {};

  /// 변주를 고르는 난수. `math.Random` 을 쓰지 않는 것은 저장소의 규칙이다.
  final Rng _rng = Rng(0x50D5);

  bool _ready = false;
  bool _disposed = false;
  Mood? _mood;

  /// 굽기가 끝나 소리가 나기 시작했는가. 그전의 [play] 는 조용히 넘어간다 —
  /// 게임을 붙잡아 둘 이유가 없다.
  bool get ready => _ready;

  bool muted = false;
  double sfxVolume = 0.85;
  double bgmVolume = 0.34;

  /// 굽기가 끝났을 때 한 번 불린다. 화면이 "합성 중" 표시를 지우는 데 쓴다.
  VoidCallback? onReady;

  /// 창고를 굽고 재생 준비까지 마친다. 실패해도 게임은 계속 돌아간다.
  Future<void> warmUp(BakeOrder order) async {
    try {
      final clips = await compute(bakeClips, order);
      if (_disposed) return;
      _clips.addAll(clips);
      // 소스를 미리 만들어 둔다. 네이티브에서는 임시 파일 쓰기가 여기서
      // 한꺼번에 일어나므로, 첫 발소리가 파일 쓰기를 기다리지 않는다.
      for (final e in _clips.entries) {
        for (var i = 0; i < e.value.length; i++) {
          if (_disposed) return;
          _sources['${e.key}#$i'] = await makeSource('${e.key}_$i', e.value[i]);
        }
      }
      _ready = true;
      onReady?.call();
    } catch (e, st) {
      debugPrint('소리를 굽지 못했다 — 무음으로 계속한다: $e\n$st');
    }
  }

  /// 효과음 하나. 변주는 자동으로 골라진다.
  ///
  /// [volume] 은 거리 감쇠, [pan] 은 -1(왼쪽)..1(오른쪽) 이다. 아이소 맵에서
  /// 화면 어디서 난 소리인지가 들려야 몬스터가 다가오는 것을 등 뒤로도 안다.
  void play(String key, {double volume = 1.0, double pan = 0.0}) {
    if (muted || !_ready || _disposed) return;
    final variants = _clips[key];
    assert(variants != null, '등록되지 않은 소리: $key');
    if (variants == null || variants.isEmpty) return;

    final v = (volume * sfxVolume).clamp(0.0, 1.0);
    if (v < 0.012) return; // 들리지도 않을 소리에 플레이어를 쓰지 않는다

    final i = _rng.intRange(0, variants.length);
    final src = _sources['$key#$i'];
    if (src == null) return;

    final p = _pool[_next++ % _pool.length];
    unawaited(
      p
          .play(src, volume: v, balance: pan.clamp(-1.0, 1.0))
          .catchError((Object e) => debugPrint('재생 실패 $key: $e')),
    );
  }

  /// 배경음을 무드에 맞춰 바꾼다. 굽지 않았으면 여기서 굽는다.
  Future<void> setMood(Mood mood) async {
    if (_mood == mood || _disposed) return;
    _mood = mood;
    try {
      final cached = _bgmCache[mood.index];
      final Uint8List wav;
      if (cached != null) {
        wav = cached;
      } else {
        wav = await compute(bakeBgm, [mood.index, seed]);
        if (_disposed) return;
        _bgmCache[mood.index] = wav;
      }
      // 무드를 바꾸는 사이에 또 바뀌었다면 이 곡은 버린다.
      if (_mood != mood) return;
      final src = await makeSource('bgm_${mood.name}', wav);
      if (_disposed || _mood != mood) return;
      await _bgmPlayer.stop();
      await _bgmPlayer.play(src, volume: muted ? 0 : bgmVolume);
    } catch (e) {
      debugPrint('배경음을 틀지 못했다: $e');
    }
  }

  /// 전체 음소거. 배경음은 멈추지 않고 음량만 0 으로 내린다 — 다시 켤 때
  /// 곡이 처음부터 시작하면 이어 듣던 흐름이 끊긴다.
  Future<void> setMuted(bool value) async {
    muted = value;
    if (_disposed) return;
    try {
      await _bgmPlayer.setVolume(value ? 0 : bgmVolume);
      if (value) {
        for (final p in _pool) {
          unawaited(p.stop());
        }
      }
    } catch (_) {
      // 음소거 실패는 게임을 멈출 이유가 못 된다.
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    _ready = false;
    for (final p in _pool) {
      await p.dispose();
    }
    await _bgmPlayer.dispose();
  }
}
