import 'package:flutter_test/flutter_test.dart';
import 'package:provis/provis.dart';

/// 소리는 **눈으로 검사할 수 없다.** 그래서 자동 검사가 그림보다 더 중요하다.
///
/// 여기서 지키는 불변식은 셋이다.
///
/// 1. **유한하다.** NaN 표본 하나가 16비트로 잘리면 최대 진폭 잡음이 되어
///    스피커를 때린다. 그림에서 NaN 이 Path 를 조용히 지우는 것과 달리,
///    소리에서는 조용히 지나가지 않는다.
/// 2. **무음이 아니다.** 포락선이나 필터를 잘못 걸면 전 구간이 0 이 되는데,
///    이건 "소리를 껐다"와 구분이 안 돼 며칠을 잡아먹는다.
/// 3. **클리핑하지 않는다.** 여러 층을 더하는 구조라 한 층의 gain 만 잘못
///    잡아도 통째로 뭉개진다.
void main() {
  /// 버퍼가 들을 만한 소리인지 한 번에 검사한다.
  void expectAudible(Wave w, String what, {double floor = 0.05}) {
    expect(w.length, greaterThan(0), reason: '$what: 길이가 0 이다');
    var energy = 0.0;
    for (var i = 0; i < w.length; i++) {
      final v = w[i];
      expect(v.isFinite, isTrue, reason: '$what: 표본 $i 이 유한하지 않다');
      energy += v * v;
    }
    final rms = (energy / w.length);
    expect(rms, greaterThan(floor * floor * 0.01), reason: '$what: 사실상 무음이다');
    expect(w.peak, lessThanOrEqualTo(1.0), reason: '$what: 클리핑한다');
  }

  group('DSP 기본', () {
    test('발진기가 대역 안에 머문다', () {
      final osc = Osc(kSfxRate);
      for (var i = 0; i < 4000; i++) {
        final s = osc.saw(220);
        expect(s.isFinite, isTrue);
        // PolyBLEP 보정은 불연속 근처에서 1 을 살짝 넘길 수 있다.
        expect(s.abs(), lessThan(2.2));
      }
    });

    test('필터가 컷오프를 극단으로 밀어도 발산하지 않는다', () {
      final svf = Svf(kSfxRate);
      final noise = WhiteNoise(3);
      for (var i = 0; i < 8000; i++) {
        // 매 표본마다 컷오프를 흔든다 — 스윕이 실제로 하는 일이다.
        final y = svf.process(noise.next, i.isEven ? 20 : 19000, 12);
        expect(y.isFinite, isTrue);
        expect(y.abs(), lessThan(60));
      }
    });

    test('포락선이 0..1 을 벗어나지 않는다', () {
      const e = Env(
        attack: 0.01,
        decay: 0.2,
        sustain: 0.4,
        sustainTime: 0.1,
        release: 0.3,
      );
      for (var i = 0; i <= 200; i++) {
        final v = e.at(e.duration * i / 200 * 1.2);
        expect(v, inInclusiveRange(0.0, 1.0));
      }
      expect(e.at(-1), 0);
      expect(e.at(e.duration + 1), 0);
    });
  });

  group('효과음', () {
    test('발소리 — 바닥 5종 × 걷기/달리기가 전부 소리를 낸다', () {
      for (final g in StepGround.values) {
        for (final run in [false, true]) {
          expectAudible(
            Sfx.footstep(seed: 11, ground: g, running: run),
            '발소리 ${g.name} ${run ? 'run' : 'walk'}',
          );
        }
      }
    });

    test('바닥마다 실제로 다른 파형이 나온다', () {
      // 같은 시드에서 바닥만 바꿨는데 파형이 같다면 분기가 죽은 것이다.
      final grass = Sfx.footstep(seed: 5, ground: StepGround.grass);
      final stone = Sfx.footstep(seed: 5, ground: StepGround.stone);
      expect(
        _divergence(grass, stone),
        greaterThan(0.8),
        reason: '풀밭과 돌바닥이 같은 소리다',
      );
    });

    test('무기 8종의 휘두르기', () {
      for (final w in WeaponKind.values) {
        expectAudible(Sfx.swing(seed: 3, weapon: w), '휘두르기 ${w.name}');
      }
    });

    test('타격·방어·사격·쓰러짐', () {
      expectAudible(Sfx.impact(seed: 1), '타격(살)');
      expectAudible(Sfx.impact(seed: 1, armored: true), '타격(갑옷)');
      expectAudible(Sfx.block(seed: 1), '막기(금속)');
      expectAudible(Sfx.block(seed: 1, metal: false), '막기(나무)');
      expectAudible(Sfx.parry(seed: 1), '흘리기');
      expectAudible(Sfx.guardUp(seed: 1), '방어 자세');
      expectAudible(Sfx.bowShot(seed: 1), '사격');
      expectAudible(Sfx.magicCast(seed: 1), '마법 발사');
      expectAudible(Sfx.bodyFall(seed: 1), '쓰러짐');
      expectAudible(Sfx.moveMark(seed: 1), '이동 표식');
      expectAudible(Sfx.uiClick(seed: 1), 'UI');
    });

    test('같은 시드는 같은 소리를 낸다', () {
      final a = Sfx.impact(seed: 42);
      final b = Sfx.impact(seed: 42);
      expect(a.length, b.length);
      for (var i = 0; i < a.length; i += 37) {
        expect(a[i], b[i], reason: '시드가 같은데 표본 $i 이 다르다');
      }
    });

    test('시드가 다르면 다른 소리를 낸다', () {
      expect(
        _divergence(Sfx.footstep(seed: 1), Sfx.footstep(seed: 2)),
        greaterThan(0.8),
        reason: '시드가 변주를 만들지 못한다',
      );
    });
  });

  group('몬스터 목소리', () {
    test('목 7종이 네 가지 발화를 전부 낸다', () {
      for (final k in VoiceKind.values) {
        final v = CreatureVoice(seed: 77, kind: k, size: 0.6);
        expectAudible(v.idle(), '${k.name}.idle');
        expectAudible(v.alert(), '${k.name}.alert');
        expectAudible(v.attack(), '${k.name}.attack');
        expectAudible(v.hurt(), '${k.name}.hurt');
        expectAudible(v.die(), '${k.name}.die');
      }
    });

    test('몸집이 커지면 소리가 길어진다', () {
      final small = CreatureVoice(seed: 5, kind: VoiceKind.growl, size: 0.0);
      final huge = CreatureVoice(seed: 5, kind: VoiceKind.growl, size: 1.0);
      expect(huge.attack().duration, greaterThan(small.attack().duration));
    });

    test('개체마다 목소리가 다르다', () {
      expect(
        _divergence(
          CreatureVoice(seed: 1, kind: VoiceKind.growl).idle(),
          CreatureVoice(seed: 2, kind: VoiceKind.growl).idle(),
        ),
        greaterThan(0.8),
        reason: '같은 종이 전부 같은 소리를 낸다',
      );
    });
  });

  group('배경음', () {
    test('무드 4종이 이음매 없는 스테레오 루프를 낸다', () {
      for (final mood in Mood.values) {
        // 검사용으로 짧게 굽는다 — 실전 길이는 22초다.
        final s = Bgm.bake(mood: mood, seed: 3, seconds: 9.0);
        expectAudible(s.left, '${mood.name}.L');
        expectAudible(s.right, '${mood.name}.R');
        expect(s.left.length, s.right.length);
        // 접힌 만큼 짧아져야 한다.
        expect(s.duration, closeTo(9.0 - 3.5, 0.05));
        // 좌우가 완전히 같으면 스테레오가 아니라 모노다.
        var same = 0;
        for (var i = 0; i < s.left.length; i++) {
          if ((s.left[i] - s.right[i]).abs() < 1e-12) same++;
        }
        expect(
          same / s.left.length,
          lessThan(0.5),
          reason: '${mood.name}: 좌우가 같다',
        );
      }
    });

    test('루프 이음매에서 파형이 튀지 않는다', () {
      final s = Bgm.bake(mood: Mood.dusk, seed: 9, seconds: 9.0);
      final w = s.left;
      // 끝 표본과 첫 표본의 단차가 인접 표본들의 전형적 단차 수준이어야 한다.
      var typical = 0.0;
      for (var i = 1; i < w.length; i++) {
        typical += (w[i] - w[i - 1]).abs();
      }
      typical /= w.length - 1;
      final seam = (w[0] - w[w.length - 1]).abs();
      expect(seam, lessThan(typical * 40 + 0.05), reason: '루프 지점에서 딱 소리가 난다');
    });
  });

  group('WAV 인코딩', () {
    test('헤더가 올바르고 길이가 맞는다', () {
      final w = Wave.seconds(kSfxRate, 0.1);
      for (var i = 0; i < w.length; i++) {
        w[i] = 0.5;
      }
      final bytes = encodeWav(w);
      expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE');
      expect(String.fromCharCodes(bytes.sublist(36, 40)), 'data');
      expect(bytes.length, 44 + w.length * 2);
    });

    test('스테레오는 프레임당 4바이트다', () {
      final l = Wave.seconds(kBgmRate, 0.05);
      final r = Wave.seconds(kBgmRate, 0.05);
      final bytes = encodeWav(l, right: r);
      expect(bytes.length, 44 + l.length * 4);
    });
  });

  group('창고', () {
    test('표준 창고가 필요한 이름을 전부 들고 있다', () {
      final bank = SoundBank.field(seed: 3);
      expect(bank.has(SfxKeys.step(StepGround.grass)), isTrue);
      expect(bank.has(SfxKeys.step(StepGround.stone, running: true)), isTrue);
      expect(bank.has(SfxKeys.swing(WeaponKind.greatsword)), isTrue);
      expect(bank.has(SfxKeys.impactFlesh), isTrue);
      expect(bank.has(SfxKeys.blockMetal), isTrue);
      expect(bank.has(SfxKeys.bowShot), isTrue);
      expect(bank.has(SfxKeys.magicCast), isTrue);
      expect(bank.variants(SfxKeys.step(StepGround.grass)), 4);
    });

    test('늦게 굽고 캐시한다', () {
      final bank = SoundBank.field(seed: 3);
      expect(bank.bakedCount, 0, reason: '만들자마자 굽고 있다');
      final first = bank.bytes(SfxKeys.impactFlesh);
      expect(bank.bakedCount, 1);
      expect(
        identical(bank.bytes(SfxKeys.impactFlesh), first),
        isTrue,
        reason: '두 번째 요청에 다시 굽고 있다',
      );
    });

    test('변주가 서로 다른 바이트다', () {
      final bank = SoundBank.field(seed: 3);
      final key = SfxKeys.step(StepGround.grass);
      final a = bank.bytes(key, 0);
      final b = bank.bytes(key, 1);
      expect(
        a.length == b.length && _same(a, b),
        isFalse,
        reason: '변주 넷이 전부 같은 소리다',
      );
    });

    test('없는 이름은 조용히 무음을 내지 않고 던진다', () {
      expect(() => SoundBank.field().bytes('없는.소리'), throwsStateError);
    });

    test('몬스터 목소리를 창고에 붙인다', () {
      final bank = SoundBank.field(seed: 3);
      final voice = CreatureVoice(seed: 12, kind: VoiceKind.roar, size: 0.9);
      bank.addVoice('gorehide', voice);
      expect(bank.has(VoiceKeys.attack('gorehide')), isTrue);
      expect(bank.bytes(VoiceKeys.attack('gorehide')).length, greaterThan(44));
      // 두 번 붙여도 변주가 쌓이지 않아야 한다.
      bank.addVoice('gorehide', voice);
      expect(bank.variants(VoiceKeys.attack('gorehide')), 1);
    });
  });
}

/// 두 파형이 얼마나 다른가 0..1.
///
/// **양쪽이 모두 무음인 구간은 세지 않는다.** 효과음은 끝에 여유 길이를 두므로
/// 꼬리의 0 을 함께 세면 아무리 다른 소리도 "절반은 같다"로 나와, 변주가
/// 죽어도 검사가 통과한다.
double _divergence(Wave a, Wave b) {
  final n = a.length < b.length ? a.length : b.length;
  var live = 0;
  var diff = 0;
  for (var i = 0; i < n; i++) {
    final x = a[i], y = b[i];
    if (x.abs() < 1e-6 && y.abs() < 1e-6) continue;
    live++;
    if ((x - y).abs() > 1e-6) diff++;
  }
  return live == 0 ? 0 : diff / live;
}

bool _same(List<int> a, List<int> b) {
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
