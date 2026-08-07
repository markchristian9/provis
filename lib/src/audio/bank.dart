import 'dart:typed_data';

import '../actor/spec.dart';
import '../core/rng.dart';
import 'dsp.dart';
import 'sfx.dart';
import 'voice.dart';
import 'wave.dart';

/// 이름 하나에 여러 변주를 매달아 두는 소리 창고.
///
/// ## 왜 변주가 필요한가
///
/// 발소리 하나를 반복 재생하면 **기관총**이 된다. 사람의 귀는 완전히 같은
/// 파형이 두 번 이어지는 것을 즉시 알아채고, 그 순간 소리가 녹음이라는 사실이
/// 드러난다. 나무마다 시드를 바꾸는 것과 정확히 같은 이유로, 걸음마다 다른
/// 표본을 써야 한다.
///
/// ## 왜 늦게 굽는가
///
/// 창고에 등록된 모든 소리를 시작할 때 굽으면 로딩이 몇 초씩 걸린다. 실제로
/// 쓰이는 소리는 그중 일부이므로, 처음 요청될 때 굽고 그 뒤로는 캐시를 준다.
///
/// ```dart
/// final bank = SoundBank.field(seed: 7);
/// final wav = bank.pick(SfxKeys.step(StepGround.grass, running: false), rng);
/// ```
class SoundBank {
  SoundBank({this.rate = kSfxRate});

  final int rate;

  final Map<String, List<Wave Function()>> _recipes = {};
  final Map<String, List<Uint8List?>> _cache = {};

  List<String> get keys => _recipes.keys.toList()..sort();

  bool has(String key) => _recipes.containsKey(key);

  /// 이 이름에 등록된 변주의 수.
  int variants(String key) => _recipes[key]?.length ?? 0;

  /// 이미 구워 둔 표본의 수. 로딩 진행도 표시에 쓴다.
  int get bakedCount => _cache.values
      .expand((v) => v)
      .where((b) => b != null)
      .length;

  /// 변주를 하나 등록한다. 같은 이름으로 여러 번 부르면 변주가 쌓인다.
  void add(String key, Wave Function() bake) {
    (_recipes[key] ??= []).add(bake);
    (_cache[key] ??= []).add(null);
  }

  /// 같은 레시피를 시드만 바꿔 [count] 개 등록한다.
  void addVariants(String key, int count, Wave Function(int seed) bake) {
    for (var i = 0; i < count; i++) {
      final s = key.hashCode ^ (i * 0x9E3779B9);
      add(key, () => bake(s & 0x7FFFFFFF));
    }
  }

  /// WAV 바이트를 얻는다. 처음이면 여기서 굽는다.
  ///
  /// 없는 이름을 물으면 [StateError] 를 던진다 — 조용히 무음을 돌려주면
  /// "소리가 안 난다"의 원인을 영원히 못 찾는다.
  Uint8List bytes(String key, [int variant = 0]) {
    final recipes = _recipes[key];
    if (recipes == null || recipes.isEmpty) {
      throw StateError('등록되지 않은 소리: $key');
    }
    final i = variant % recipes.length;
    final cached = _cache[key]![i];
    if (cached != null) return cached;
    final baked = encodeWav(recipes[i]());
    _cache[key]![i] = baked;
    return baked;
  }

  /// 변주 하나를 무작위로 고른다.
  Uint8List pick(String key, Rng r) => bytes(key, r.intRange(0, 1 << 20));

  /// 캐시만 비운다. 레시피는 남으므로 다음 요청에 다시 구워진다.
  void evict() {
    for (final v in _cache.values) {
      for (var i = 0; i < v.length; i++) {
        v[i] = null;
      }
    }
  }

  /// 게임 하나가 쓰는 표준 창고.
  ///
  /// 발소리(바닥 5종 × 걷기/달리기) · 무기별 휘두르기 · 타격 · 방어 · 사격 ·
  /// UI 가 전부 들어 있다. 몬스터 목소리는 개체마다 다르므로 [addVoice] 로
  /// 따로 붙인다.
  factory SoundBank.field({int seed = 7, int rate = kSfxRate}) {
    final bank = SoundBank(rate: rate);
    final r = Rng(seed);

    for (final g in StepGround.values) {
      for (final running in [false, true]) {
        final key = SfxKeys.step(g, running: running);
        // 무게도 함께 흔든다 — 같은 사람이라도 걸음마다 체중이 다르게 실린다.
        bank.addVariants(key, 4, (s) {
          final rr = Rng(s);
          return Sfx.footstep(
            seed: s,
            ground: g,
            weight: rr.bell(0.35, 0.72),
            running: running,
            rate: rate,
          ).resampled(rr.range(0.94, 1.07));
        });
      }
    }

    for (final w in WeaponKind.values) {
      bank.addVariants(SfxKeys.swing(w), 3,
          (s) => Sfx.swing(seed: s, weapon: w, power: Rng(s).bell(0.45, 0.85),
              rate: rate));
    }

    bank.addVariants(SfxKeys.impactFlesh, 3,
        (s) => Sfx.impact(seed: s, weight: Rng(s).bell(0.4, 0.75), rate: rate));
    bank.addVariants(SfxKeys.impactArmor, 3,
        (s) => Sfx.impact(
            seed: s, weight: Rng(s).bell(0.5, 0.85), armored: true, rate: rate));

    bank.addVariants(SfxKeys.blockMetal, 3,
        (s) => Sfx.block(seed: s, power: Rng(s).bell(0.5, 0.9), rate: rate));
    bank.addVariants(SfxKeys.blockWood, 2,
        (s) => Sfx.block(seed: s, metal: false, rate: rate));
    bank.addVariants(SfxKeys.parry, 2, (s) => Sfx.parry(seed: s, rate: rate));
    bank.addVariants(SfxKeys.guardUp, 2, (s) => Sfx.guardUp(seed: s, rate: rate));

    bank.addVariants(SfxKeys.bowShot, 2, (s) => Sfx.bowShot(seed: s, rate: rate));
    bank.addVariants(SfxKeys.bodyFall, 2,
        (s) => Sfx.bodyFall(seed: s, weight: Rng(s).bell(0.35, 0.8), rate: rate));

    bank.add(SfxKeys.uiClick, () => Sfx.uiClick(seed: r.intRange(1, 1 << 20), rate: rate));
    bank.add(SfxKeys.uiConfirm,
        () => Sfx.uiClick(seed: r.intRange(1, 1 << 20), confirm: true, rate: rate));
    bank.addVariants(SfxKeys.moveMark, 2, (s) => Sfx.moveMark(seed: s, rate: rate));

    return bank;
  }

  /// 한 마리의 목소리 다섯을 `voice.<id>.*` 로 등록한다.
  ///
  /// 개체마다 다른 목소리를 갖는 것이 핵심이므로, 몬스터를 소환할 때마다
  /// 부르는 것이 정상이다. 이미 등록된 이름이면 아무것도 하지 않는다.
  void addVoice(String id, CreatureVoice voice) {
    if (has(VoiceKeys.idle(id))) return;
    add(VoiceKeys.idle(id), voice.idle);
    add(VoiceKeys.alert(id), voice.alert);
    add(VoiceKeys.attack(id), voice.attack);
    add(VoiceKeys.hurt(id), voice.hurt);
    add(VoiceKeys.die(id), voice.die);
  }
}

/// 표준 창고의 이름표.
///
/// 문자열을 손으로 적으면 오타가 **무음**으로 나타나고, 무음은 디버깅이
/// 불가능하다. 반드시 이 상수를 거친다.
class SfxKeys {
  SfxKeys._();

  static String step(StepGround g, {bool running = false}) =>
      'step.${g.name}.${running ? 'run' : 'walk'}';

  static String swing(WeaponKind w) => 'swing.${w.name}';

  static const impactFlesh = 'impact.flesh';
  static const impactArmor = 'impact.armor';
  static const blockMetal = 'block.metal';
  static const blockWood = 'block.wood';
  static const parry = 'parry';
  static const guardUp = 'guard.up';
  static const bowShot = 'bow.shot';
  static const bodyFall = 'body.fall';
  static const uiClick = 'ui.click';
  static const uiConfirm = 'ui.confirm';
  static const moveMark = 'ui.mark';
}

/// 목소리의 이름표.
class VoiceKeys {
  VoiceKeys._();

  static String idle(String id) => 'voice.$id.idle';
  static String alert(String id) => 'voice.$id.alert';
  static String attack(String id) => 'voice.$id.attack';
  static String hurt(String id) => 'voice.$id.hurt';
  static String die(String id) => 'voice.$id.die';
}
