// 스케일 감사 — 실제로 지어진 마을의 모든 기물을 미터로 환산해 한 표에 놓는다.
//
// ## 왜 이 파일이 필요한가
//
// 기물과 캐릭터는 각자 자기 국소 픽셀 치수로 그린다. 픽셀은 만드는 사람마다
// 다른 기준으로 고르므로, **각자 그럴듯한 숫자를 넣었는데도 한 화면에 모으면
// 사람이 2층집보다 크다.** 실제로 이 저장소가 그랬다 — 2층집 1.74 m, 성벽
// 0.49 m, PC 1.89 m.
//
// 눈으로 보며 숫자를 흔들면 다음 기물에서 또 어긋난다. 픽셀을 미터로 환산해
// 한 줄에 세우면 "층고 0.51 m" 같은 값이 즉시 드러나고, 그 자리에서 끝난다.
//
// ## 리터럴이 아니라 실제 맵을 잰다
//
// 감사가 손으로 옮겨 적은 숫자를 재면, 맵이 바뀌었을 때 감사만 통과하고 게임은
// 깨진다. 그래서 `buildVillage()` 로 **게임과 똑같은 마을을 짓고** 그 안의
// 기물을 전수 조사한다.
//
// 환산식과 "1 타일 = 1 m" 의 근거는 `WorldScale` 문서에 있다.

import 'package:flutter/material.dart' hide Colors;
import 'package:flutter_test/flutter_test.dart';
import 'package:provis/provis.dart';

import 'package:provis_example/world/village.dart';

/// 감사 대상 — 게임 맵이 실제로 쓰는 카메라와 스케일.
const iso = IsoView(tileWidth: 150, tileHeight: 75);
const scale = WorldScale(iso: iso);
const mapSeed = 20260806;

/// 현실 대역(미터). 세워지는 기물만 잰다 — 눕는 기물(길·풀밭·물)의 `height`
/// 는 깊이 정렬용 토큰 값이라 의미가 없다.
const bands = <String, (double, double)>{
  'BuildingProp': (3.5, 13.0),
  'WallProp': (2.0, 4.5),
  'FenceProp': (0.9, 1.7),
  'TreeProp': (0.5, 22.0),
  'RockProp': (0.3, 2.5),
  'StumpProp': (0.25, 1.4),
  'LogProp': (0.25, 1.6),
  'GrassTuft': (0.2, 0.9),
  'FlowerBed': (0.2, 0.9),
  'MoundProp': (0.4, 3.0),
};

class _Stat {
  double lo = double.infinity;
  double hi = -double.infinity;
  int n = 0;

  void add(double m) {
    lo = m < lo ? m : lo;
    hi = m > hi ? m : hi;
    n++;
  }
}

/// 게임과 똑같은 마을을 짓고 기물을 돌려준다.
(VillageLayout, IsoSceneComponent) _village() {
  final scene = IsoSceneComponent(
    iso: iso,
    grid: IsoGrid(cols: kVillageCols, rows: kVillageRows),
  );
  final layout = buildVillage(
    scene: scene,
    seed: mapSeed,
    scale: scale,
    mobCount: 6,
  );
  return (layout, scene);
}

void main() {
  test('[스케일 회귀 가드] 마을의 모든 기물이 사람과 같은 자로 재어진다', () {
    final (_, scene) = _village();

    final stats = <String, _Stat>{};
    for (final it in scene.props) {
      final name = it.prop.runtimeType.toString();
      if (!bands.containsKey(name)) continue;
      // scale 은 개체별 크기 변주다. 화면에 나오는 실제 높이를 재야 한다.
      (stats[name] ??= _Stat()).add(scale.meters(it.prop.height * it.scale));
    }

    final human = scale.meters(scale.humanPx);
    final b = StringBuffer()
      ..writeln()
      ..writeln('  타일 ${iso.tileWidth.toStringAsFixed(0)}×'
          '${iso.tileHeight.toStringAsFixed(0)} px  ·  '
          '1 타일 = ${scale.metersPerTile} m  ·  '
          '1 m = ${scale.pxPerMeter.toStringAsFixed(1)} px  ·  '
          '맵 $kVillageCols×$kVillageRows m')
      ..writeln()
      ..writeln('  ${'기물'.padRight(16)}${'수'.padLeft(5)}'
          '${'최소m'.padLeft(9)}${'최대m'.padLeft(9)}'
          '${'사람배'.padLeft(11)}  판정')
      ..writeln('  ${'─' * 62}')
      ..writeln('  ${'PC (사람)'.padRight(16)}${1.toString().padLeft(5)}'
          '${human.toStringAsFixed(2).padLeft(9)}'
          '${human.toStringAsFixed(2).padLeft(9)}'
          '${'1.00×'.padLeft(11)}  기준');

    final bad = <String>[];
    for (final name in bands.keys) {
      final s = stats[name];
      if (s == null) continue;
      final (lo, hi) = bands[name]!;
      final ok = s.lo >= lo && s.hi <= hi;
      if (!ok) {
        bad.add('$name ${s.lo.toStringAsFixed(2)}~'
            '${s.hi.toStringAsFixed(2)}m (기대 $lo~$hi)');
      }
      b.writeln('  ${name.padRight(16)}${s.n.toString().padLeft(5)}'
          '${s.lo.toStringAsFixed(2).padLeft(9)}'
          '${s.hi.toStringAsFixed(2).padLeft(9)}'
          '${'${(s.lo / human).toStringAsFixed(1)}~'
              '${(s.hi / human).toStringAsFixed(1)}×'.padLeft(11)}'
          '  ${ok ? 'OK' : '벗어남'}');
    }
    // ignore: avoid_print
    print(b);

    expect(bad, isEmpty, reason: '현실 대역을 벗어남 → ${bad.join(' / ')}');
  });

  test('[스케일 회귀 가드] 2층집이 사람보다 충분히 높다', () {
    // 이번 과제의 핵심 결함을 그대로 옮긴 것이다. 고치기 전 값은 1.74 m 로
    // 1.89 m 인 PC 보다 **낮았다.**
    final house = BuildingProp(
      seed: mapSeed,
      tiles: const Size(7, 8),
      tileWidth: iso.tileWidth,
      isoRatio: iso.elevationSin,
      storeys: 2,
    );
    expect(scale.meters(house.height), greaterThan(6.0));
    expect(house.height, greaterThan(scale.humanPx * 3));
  });

  test('층고는 사람 키보다 크고 두 배보다 작다', () {
    final b = BuildingProp(
      seed: mapSeed,
      tiles: const Size(5, 6),
      tileWidth: iso.tileWidth,
      isoRatio: iso.elevationSin,
    );
    expect(b.storeyHeight, greaterThan(scale.humanPx));
    expect(b.storeyHeight, lessThan(scale.humanPx * 2));
  });

  test('사람이 출입문을 통과할 수 있다', () {
    final b = BuildingProp(
      seed: mapSeed,
      tiles: const Size(5, 6),
      tileWidth: iso.tileWidth,
      isoRatio: iso.elevationSin,
    );
    // 문이 사람보다 낮으면 머리가 인방에 걸린다.
    expect(scale.meters(b.doorHeight), greaterThan(kHumanHeightM));
    // 어깨가 문설주에 걸리면 안 된다.
    expect(scale.meters(b.doorWidth), greaterThan(kShoulderWidthM));
  });

  test('캐릭터 키는 타일 폭의 1.2~1.6배 규약을 지킨다', () {
    // provis 아이소 규약. 이쪽은 처음부터 옳았다 — 어긋난 것은 기물뿐이었다.
    expect(scale.humanTileRatio, inInclusiveRange(1.2, 1.6));
  });
}
