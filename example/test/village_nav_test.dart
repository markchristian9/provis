// 통행 검증 — 지어진 마을을 실제로 걸어 다닐 수 있는가.
//
// ## 왜 이 파일이 필요한가
//
// 스케일을 고치면 통행이 조용히 깨진다. 건물 발자국이 2×2 에서 7×8 로 커지면
// 막히는 칸이 12배가 되고, 그 사이 통로가 닫혔는지는 그림만 봐서는 모른다.
// 사람이 눈으로 하는 검사는 회귀를 막지 못한다.
//
// 여기서 확인하는 것은 넷이다.
//
// 1. 통행 판정이 그림과 **같은 자리**에 있는가 (중심 정렬)
// 2. 등장 지점이 막힌 칸이 아닌가 — 갇힌 채로 시작하면 게임이 시작되지 않는다
// 3. 모든 건물의 **문 앞까지 걸어갈 수 있는가**
// 4. 맵이 하나로 이어져 있는가 — 섬이 생기면 갈 수 없는 땅이 남는다

import 'package:flutter/material.dart' hide Colors;
import 'package:flutter_test/flutter_test.dart';
import 'package:provis/provis.dart';

import 'package:provis_example/world/village.dart';

const iso = IsoView(tileWidth: 150, tileHeight: 75);
const scale = WorldScale(iso: iso);
const mapSeed = 20260806;

(VillageLayout, IsoSceneComponent) _village([int seed = mapSeed]) {
  final scene = IsoSceneComponent(
    iso: iso,
    grid: IsoGrid(cols: kVillageCols, rows: kVillageRows),
  );
  final layout = buildVillage(
    scene: scene,
    seed: seed,
    scale: scale,
    mobCount: 6,
  );
  return (layout, scene);
}

void main() {
  group('통행 격자가 그림과 같은 자리에 있다', () {
    test('발자국은 접지 중심에 놓인다', () {
      // 기물은 예외 없이 접지 중심을 원점으로 그린다. 예전 blockFootprint 는
      // [tile] 을 좌상단으로 삼아 판정을 반 발자국 밀어 놓았다 — 건물 한쪽은
      // 통과되고 반대쪽 빈 땅이 막혔다.
      final g = IsoGrid(cols: 16, rows: 16);
      g.blockFootprint(const Offset(8.0, 8.0), const Size(4, 4));

      // 중심 (8,8) 에 4×4 → x,y 각각 6,7,8,9 가 막힌다.
      for (var y = 6; y <= 9; y++) {
        for (var x = 6; x <= 9; x++) {
          expect(g.isBlocked(x, y), isTrue, reason: '($x,$y) 가 열려 있다');
        }
      }
      // 바로 바깥은 열려 있어야 한다.
      expect(g.isWalkable(5, 8), isTrue);
      expect(g.isWalkable(10, 8), isTrue);
      expect(g.isWalkable(8, 5), isTrue);
      expect(g.isWalkable(8, 10), isTrue);
    });

    test('1×1 기물은 자기가 선 칸만 막는다', () {
      final g = IsoGrid(cols: 8, rows: 8);
      g.blockFootprint(const Offset(3.5, 4.5), const Size(1, 1));
      expect(g.isBlocked(3, 4), isTrue);
      expect(g.isWalkable(4, 4), isTrue);
      expect(g.isWalkable(3, 5), isTrue);
    });
  });

  group('마을을 걸어 다닐 수 있다', () {
    test('주인공은 막힌 칸에서 시작하지 않는다', () {
      final (layout, scene) = _village();
      final g = scene.grid!;
      final s = layout.heroSpawn;
      expect(g.isWalkable(s.dx.floor(), s.dy.floor()), isTrue,
          reason: '주인공이 벽 안에서 시작한다');
    });

    test('몬스터도 막힌 칸에서 시작하지 않는다', () {
      final (layout, scene) = _village();
      final g = scene.grid!;
      for (final (i, m) in layout.mobSpawns.indexed) {
        expect(g.isWalkable(m.dx.floor(), m.dy.floor()), isTrue,
            reason: '몬스터 $i 이 벽 안에서 시작한다 ($m)');
      }
    });

    test('모든 건물의 문 앞까지 걸어갈 수 있다', () {
      final (layout, scene) = _village();
      final g = scene.grid!;
      final from = layout.heroSpawn;

      for (final b in layout.buildings) {
        final e = b.entrance;
        expect(g.isWalkable(e.dx.floor(), e.dy.floor()), isTrue,
            reason: '${b.label} 의 문 앞이 막혀 있다 ($e)');

        final path = g.findPath(from, e);
        expect(path, isNotEmpty,
            reason: '${b.label} 의 문 앞까지 가는 길이 없다 '
                '($from → $e)');
        // A* 는 목표가 막히면 근처 칸으로 대체한다. 정말 문 앞에 닿았는지
        // 마지막 칸으로 확인한다.
        final last = path.last;
        expect((last.dx - e.dx).abs() < 1.5 && (last.dy - e.dy).abs() < 1.5,
            isTrue,
            reason: '${b.label} 의 문 앞 대신 $last 에서 멈췄다');
      }
    });

    test('맵을 다시 생성해도 통행이 유지된다', () {
      // 시드가 바뀌면 나무·바위 자리가 바뀐다. 그것이 길을 막으면 안 된다.
      var seed = mapSeed;
      for (var i = 0; i < 6; i++) {
        seed = seed * 31 + 17;
        final (layout, scene) = _village(seed);
        final g = scene.grid!;
        expect(g.isWalkable(layout.heroSpawn.dx.floor(),
            layout.heroSpawn.dy.floor()), isTrue,
            reason: '시드 $seed 에서 주인공이 갇혔다');
        for (final b in layout.buildings) {
          expect(g.findPath(layout.heroSpawn, b.entrance), isNotEmpty,
              reason: '시드 $seed 에서 ${b.label} 에 갈 수 없다');
        }
      }
    });

    test('길은 끝에서 끝까지 뚫려 있다', () {
      // 길은 마을의 뼈대다. 여기가 막히면 맵이 두 조각으로 갈린다.
      final (_, scene) = _village();
      final g = scene.grid!;
      final y = kVillageRows / 2;
      final path = g.findPath(Offset(1.5, y), Offset(kVillageCols - 1.5, y));
      expect(path, isNotEmpty, reason: '길 한쪽 끝에서 다른 끝으로 갈 수 없다');
    });
  });

  group('통행 가능 면적이 충분하다', () {
    test('맵의 절반 이상이 걸을 수 있는 땅이다', () {
      // 건물이 제 크기를 찾으면서 막히는 칸이 크게 늘었다. 너무 많이 막히면
      // 마을이 미로가 된다.
      final (_, scene) = _village();
      final g = scene.grid!;
      var open = 0;
      for (var y = 0; y < kVillageRows; y++) {
        for (var x = 0; x < kVillageCols; x++) {
          if (g.isWalkable(x, y)) open++;
        }
      }
      final ratio = open / (kVillageCols * kVillageRows);
      expect(ratio, greaterThan(0.5),
          reason: '걸을 수 있는 땅이 ${(ratio * 100).toStringAsFixed(1)}% 뿐이다');
    });
  });
}
