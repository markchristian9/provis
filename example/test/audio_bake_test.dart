import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provis/provis.dart';
import 'package:provis_example/audio/game_audio.dart';
import 'package:provis_example/characters/roster.dart';

/// 소리 굽기는 **격리 스레드**에서 돈다. 그 경계를 검사한다.
///
/// ## 왜 이 테스트가 필요한가
///
/// `compute` 로 넘기는 값은 격리 스레드 경계를 건너갈 수 있어야 한다. 클로저나
/// 네이티브 자원을 품은 객체가 하나라도 섞이면 **실행 시점에** 터지는데, 소리는
/// 눈에 보이지 않으므로 그 예외가 조용히 삼켜지면 "왜 아무 소리도 안 나지"로만
/// 남는다. 합성 자체는 라이브러리 테스트가 지키므로, 여기서는 경계만 본다.
void main() {
  test('주문서가 격리 스레드를 건너가 WAV 를 들고 돌아온다', () async {
    final order = BakeOrder(
      seed: 3,
      grounds: const [
        StepGround.grass,
        StepGround.stone,
      ].map((g) => g.index).toList(),
      weapons: const [WeaponKind.sword].map((w) => w.index).toList(),
      voices: [VoiceSpec.of(monsters.first, kind: VoiceKind.growl)],
    );

    final clips = await compute(bakeClips, order);

    expect(clips, isNotEmpty);
    expect(clips.containsKey(SfxKeys.step(StepGround.grass)), isTrue);
    expect(
      clips.containsKey(SfxKeys.step(StepGround.stone, running: true)),
      isTrue,
    );
    expect(clips.containsKey(SfxKeys.swing(WeaponKind.sword)), isTrue);
    expect(
      clips.containsKey(SfxKeys.blockMetal),
      isTrue,
      reason: '방어 소리가 없으면 막았는지 알 수 없다',
    );
    expect(
      clips.containsKey(SfxKeys.magicCast),
      isTrue,
      reason: '마법사의 release 이벤트가 무음이면 안 된다',
    );
    expect(clips.containsKey(VoiceKeys.attack(monsters.first.id)), isTrue);

    for (final e in clips.entries) {
      expect(e.value, isNotEmpty, reason: '${e.key}: 변주가 없다');
      for (final wav in e.value) {
        expect(
          String.fromCharCodes(wav.sublist(0, 4)),
          'RIFF',
          reason: '${e.key}: WAV 헤더가 아니다',
        );
        expect(wav.length, greaterThan(44), reason: '${e.key}: 표본이 비었다');
      }
    }
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('배경음도 격리 스레드에서 스테레오로 돌아온다', () async {
    final Uint8List wav = await compute(bakeBgm, [Mood.dusk.index, 5]);
    expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
    // fmt 청크의 채널 수(오프셋 22)가 2 여야 스테레오다.
    expect(ByteData.sublistView(wav).getUint16(22, Endian.little), 2);
    expect(wav.length, greaterThan(44));
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('명부의 몬스터마다 서로 다른 목이 배정된다', () {
    // 목소리가 겹치면 화면 밖에서 무엇이 오는지 구분할 수 없다.
    final specs = [for (final m in monsters) VoiceSpec.of(m)];
    expect(
      specs.map((s) => s.seed).toSet(),
      hasLength(monsters.length),
      reason: '몬스터들이 같은 시드를 공유한다',
    );
    for (final s in specs) {
      expect(s.size, inInclusiveRange(0.0, 1.0));
      expect(s.rasp, inInclusiveRange(0.0, 1.0));
      expect(s.toVoice(kBgmRate).rate, kBgmRate);
    }
  });
}
