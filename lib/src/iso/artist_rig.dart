import 'dart:ui';

import '../actor/humanoid_renderer.dart';
import '../art/creature.dart';
import '../core/rng.dart';
import 'iso_stage.dart';
import 'iso_view.dart';

/// 초상용 [Artist] 를 게임 맵에서 걷는 액터로 바꾼다.
///
/// ## 왜 변환이 필요한가
///
/// `Artist` 는 고정된 3/4 초상이다 — 갤러리에서는 가장 예쁘지만 걸어도 자세가
/// 그대로고 방향이 없다. 게임 맵에서는 다리가 교차하고 북/남/동/서로 몸이
/// 돌아야 하므로 [RiggedIsoActor] 가 필요하다.
///
/// ## 정체성을 어떻게 잇는가
///
/// 두 가지로 잇는다.
///
/// 1. **시드를 `id` 에서 뽑는다.** `Rng.fromString('aldric')` 이므로 같은
///    캐릭터는 언제나 같은 체형·장비를 갖는다. 게임에 들어갈 때마다 몸이
///    바뀌면 같은 인물로 안 보인다.
/// 2. **`accent` 색으로 팔레트를 물들인다.** 갤러리에서 본 그 색이 옷과 발광에
///    그대로 나타나므로, 초상과 게임 액터가 한 인물로 읽힌다.
///
/// 완전히 같은 그림은 아니다 — 그건 캐릭터마다 측면·후면을 손으로 그려야
/// 가능하다. 여기서는 **색과 실루엣 계열을 유지한 대역**을 목표로 한다.
RiggedIsoActor riggedFromArtist(
  Artist a, {
  required Offset tile,
  double height = 200,
  IsoView iso = kIso,
}) {
  final build = a.build;
  final fallback = Rng.fromString(a.id).intRange(1, 0x7FFFFFF);
  final spec = build.toSpec(fallback);
  final beast = build.beast;

  return RiggedIsoActor(
    renderer: HumanoidRenderer(
      spec,
      body: build.bodyFor(spec),
      beast: beast,
      beastForm: build.beastForm,
    ),
    tile: tile,
    height: height,
    // 보폭 동기화는 타일이 얼마나 큰지 알아야 한다. 맵의 카메라를 넘기지
    // 않으면 기본 타일 크기로 계산해 발이 미끄러진다.
    iso: iso,
  );
}
