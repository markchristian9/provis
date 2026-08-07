// 가림 처리 — 주인공이 건물 뒤로 들어가도 보이는가.
//
// ## 왜 이 테스트가 필요한가
//
// 기물이 제 크기를 찾으면서 건물은 8 m 가 되었다. 아이소 뷰에서 주인공이
// 건물 뒤로 한 걸음 들어가면 1.8 m 짜리 사람을 8 m 짜리 벽이 통째로 덮어
// **화면에서 사라진다.** 어디 있는지 모르는 캐릭터는 조작할 수 없으므로
// 이것은 취향이 아니라 조작 가능성의 문제다.
//
// 여기서 확인하는 것은 넷이다.
//
// 1. 앞을 가로막은 기물이 실제로 흐려지는가
// 2. **뒤에 있는 기물은 건드리지 않는가** — 뒤엣것까지 흐리면 맵이 통째로
//    깜빡인다
// 3. 옆으로 비켜난 기물은 건드리지 않는가
// 4. 주인공이 나오면 원래대로 돌아오는가

import 'package:flutter/material.dart' hide Colors;
import 'package:flutter_test/flutter_test.dart';
import 'package:provis/provis.dart';

const iso = IsoView(tileWidth: 150, tileHeight: 75);
const scale = WorldScale(iso: iso);

/// 주인공 하나와 건물 하나만 있는 최소 씬.
({IsoSceneComponent scene, RiggedIsoActor hero, PropInstance house}) _stage({
  required Offset heroTile,
  required Offset houseTile,
}) {
  final scene = IsoSceneComponent(
    iso: iso,
    grid: IsoGrid(cols: 24, rows: 24),
    showGrid: false,
  );
  final house = PropInstance(
    prop: BuildingProp(
      seed: 3,
      tiles: const Size(5, 6),
      storeys: 2,
      tileWidth: iso.tileWidth,
      isoRatio: iso.elevationSin,
    ),
    tile: houseTile,
  );
  scene.addProp(house);
  final hero = RiggedIsoActor(
    renderer: HumanoidRenderer(HumanoidSpec.generate(7)),
    tile: heroTile,
    height: scale.humanPx,
    iso: iso,
  );
  scene.rigged.add(hero);
  scene.occlusionFocus = hero;
  return (scene: scene, hero: hero, house: house);
}

/// 페이드가 자리를 잡을 때까지 충분히 돌린다.
void settle(IsoSceneComponent scene, {double seconds = 1.0}) {
  for (var i = 0; i < (seconds * 60).round(); i++) {
    scene.update(1 / 60);
  }
}

void main() {
  group('주인공을 가린 것만 흐려진다', () {
    test('앞을 막아선 건물은 흐려진다', () {
      // 건물의 depth 가 주인공보다 크면 주인공보다 나중에(= 앞에) 그려진다.
      final s = _stage(
        heroTile: const Offset(10.5, 10.5),
        houseTile: const Offset(12.0, 12.0),
      );
      expect(s.house.depth, greaterThan(s.hero.depth),
          reason: '전제가 틀렸다 — 건물이 주인공 앞에 있어야 한다');

      settle(s.scene);
      expect(s.house.opacity, lessThan(0.5),
          reason: '주인공을 가린 건물이 그대로다 (${s.house.opacity})');
    });

    test('뒤에 선 건물은 건드리지 않는다', () {
      // 뒤엣것은 애초에 가리지 못한다. 이것까지 흐리면 맵이 통째로 깜빡인다.
      final s = _stage(
        heroTile: const Offset(12.5, 12.5),
        houseTile: const Offset(9.0, 9.0),
      );
      expect(s.house.depth, lessThan(s.hero.depth));

      settle(s.scene);
      expect(s.house.opacity, equals(1.0),
          reason: '뒤에 있는 건물이 흐려졌다 (${s.house.opacity})');
    });

    test('옆으로 비켜난 건물은 건드리지 않는다', () {
      // depth 는 더 크지만 화면에서 멀찍이 떨어져 있다 — 가리지 않는다.
      final s = _stage(
        heroTile: const Offset(4.5, 18.5),
        houseTile: const Offset(20.0, 4.0),
      );
      settle(s.scene);
      expect(s.house.opacity, equals(1.0),
          reason: '겹치지도 않는 건물이 흐려졌다 (${s.house.opacity})');
    });

    test('주인공이 나오면 원래대로 돌아온다', () {
      final s = _stage(
        heroTile: const Offset(10.5, 10.5),
        houseTile: const Offset(12.0, 12.0),
      );
      settle(s.scene);
      expect(s.house.opacity, lessThan(0.5));

      // 건물 앞으로 걸어 나온다.
      s.hero.tile = const Offset(17.5, 17.5);
      settle(s.scene);
      expect(s.house.opacity, equals(1.0),
          reason: '주인공이 나왔는데 건물이 흐린 채로 남았다');
    });
  });

  group('전환은 부드럽다', () {
    test('한 프레임에 튀지 않는다', () {
      // 알파가 한 프레임에 갈아 끼워지면 건물이 깜빡이는 것처럼 보인다.
      final s = _stage(
        heroTile: const Offset(10.5, 10.5),
        houseTile: const Offset(12.0, 12.0),
      );
      s.scene.update(1 / 60);
      expect(s.house.opacity, greaterThan(0.8),
          reason: '첫 프레임에 이미 다 흐려졌다 — 보간이 안 된다');
      expect(s.house.opacity, lessThan(1.0), reason: '전혀 움직이지 않았다');
    });
  });

  group('초점이 없으면 아무것도 흐리지 않는다', () {
    test('occlusionFocus 를 끄면 되돌아온다', () {
      final s = _stage(
        heroTile: const Offset(10.5, 10.5),
        houseTile: const Offset(12.0, 12.0),
      );
      settle(s.scene);
      expect(s.house.opacity, lessThan(0.5));

      s.scene.occlusionFocus = null;
      settle(s.scene);
      expect(s.house.opacity, equals(1.0),
          reason: '초점을 껐는데 반투명한 건물이 남았다');
    });
  });

  group('발치의 작은 것은 가림 대상이 아니다', () {
    test('풀 포기는 흐려지지 않는다', () {
      // 발목까지 오는 것은 사람을 가릴 수 없다. 그것까지 흐리면 주인공이
      // 지날 때마다 땅이 깜빡인다.
      final scene = IsoSceneComponent(
        iso: iso,
        grid: IsoGrid(cols: 24, rows: 24),
        showGrid: false,
      );
      final grass = PropInstance(
        prop: GrassTuft(seed: 5, size: scale.px(0.4)),
        tile: const Offset(12.0, 12.0),
      );
      scene.addProp(grass);
      final hero = RiggedIsoActor(
        renderer: HumanoidRenderer(HumanoidSpec.generate(7)),
        tile: const Offset(10.5, 10.5),
        height: scale.humanPx,
        iso: iso,
      );
      scene.rigged.add(hero);
      scene.occlusionFocus = hero;

      settle(scene);
      expect(grass.opacity, equals(1.0),
          reason: '풀 포기가 흐려졌다 (${grass.opacity})');
    });
  });
}
