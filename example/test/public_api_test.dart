import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// 소비자와 똑같이 barrel 하나만 import 한다.
// `package:provis/src/...` 를 여기서 쓰면 이 테스트의 의미가 없어진다.
import 'package:provis/provis.dart';

/// 외부 프로젝트가 provis 로 하려는 일이 **barrel 하나로 전부 되는지** 검증한다.
///
/// ## 왜 이 테스트가 필요한가
///
/// 라이브러리가 컴파일된다는 것과 **남이 쓸 수 있다는 것**은 다른 문제다.
/// `lib/provis.dart` 에 export 한 줄을 빠뜨리면 라이브러리 자체는 멀쩡히
/// 빌드되지만 소비자는 그 기능에 닿을 수 없다. 실제로 `prop_kit.dart`(442줄의
/// 형상 헬퍼)가 그렇게 새어 나갔던 적이 있다.
///
/// README 의 예제도 마찬가지다. 시그니처가 바뀌면 문서는 조용히 낡고, 새
/// 사용자가 처음 만나는 코드가 컴파일되지 않는다. 아래 시나리오는 README 의
/// 예제와 같은 API 를 쓰므로, 문서가 낡으면 이 테스트가 먼저 깨진다.
void main() {
  Canvas scratch() =>
      Canvas(ui.PictureRecorder(), const Rect.fromLTWH(0, 0, 1000, 1400));

  group('공개 API — 소비자 시나리오', () {
    test('재질·조명·형상 (README 핵심 개념)', () {
      final c = scratch();
      const light = LightRig.dusk;

      // 모든 Finish 가 예외 없이 그려져야 한다.
      for (final f in Finish.values) {
        final path = blob(const Offset(200, 200), 60, 80);
        paintSurface(c, path, Surface(const Color(0xFF8090A0), f), light,
            detail: 1.0, seed: 3);
      }

      // 마무리 패스 네 가지.
      final p = blob(const Offset(200, 200), 60, 80);
      occlude(c, p, light.dir);
      castShadow(c, p);
      rimBand(c, p, light, width: 5);
      panelLine(c, smoothOpenPath(const [Offset(0, 0), Offset(40, 40)]),
          Ramp.of(const Color(0xFF808080)), light);
      groundShadow(c, const Offset(500, kGround), 240, 42);
      glowAt(c, const Offset(100, 100), 40, const Color(0xFF57E8FF));
      topPlane(c, p, light);
      trimBand(c, p, const Color(0xFFC0A060), light);
      inkOutline(c, p, const Color(0xFF101018), 2);
    });

    test('캐릭터 — Artist 구현에 필요한 것이 전부 열려 있다', () {
      final c = scratch();
      const light = LightRig.heroic;
      final bob = breathe(1.5, amp: 3.4);

      final torso = torsoShape(
        chest: Offset(500, kGround - 900 + bob),
        pelvis: const Offset(500, kGround - 480),
        shoulderW: 150,
        chestW: 130,
        waistW: 96,
        hipW: 118,
      );
      paintSurface(c, torso, Surface(const Color(0xFF7A8AA8), Finish.metal),
          light,
          detail: 1.0);

      final head = headShape(const Offset(500, 400), 78, 96, turn: 0.3);
      paintSurface(c, head, Surface(const Color(0xFFC08A66), Finish.skin), light);
      drawEye(c, const Offset(478, 400), 26, 16,
          iris: const Color(0xFF57E8FF), light: light);

      final arm = limb(const Offset(430, 460), const Offset(410, 560),
          const Offset(420, 650),
          r0: 22, r1: 17, r2: 13);
      paintSurface(c, arm, Surface(const Color(0xFFC08A66), Finish.skin), light);

      expect(jitter(2.0, 3.0), isA<double>());
      expect(bootShape(const Offset(0, 0), 1, 40), isA<Path>());
      expect(handShape(const Offset(0, 0), 20, 0), isA<Path>());
    });

    test('맵 기물 — 라이브러리 것과 내가 만든 것이 같은 계약을 쓴다', () {
      final c = scratch();
      const light = LightRig.daylight;

      final props = <Prop>[
        TreeProp(seed: 1, kind: TreeKind.broadleaf),
        TreeProp(seed: 2, kind: TreeKind.conifer),
        RockProp(seed: 3, mossy: true),
        PebbleField(seed: 4),
        BuildingProp(seed: 5, tiles: const Size(2, 2)),
        WallProp(seed: 6, crenellated: true),
        WaterProp(seed: 7),
        LavaProp(seed: 8),
        GroundPatch(seed: 9, blades: 12),
        PathPatch(seed: 10),
        _MyFence(11), // 소비자가 직접 만든 기물
      ];
      for (final p in props) {
        p.paint(c, 1.0, light, detail: 1.0);
        expect(p.height, greaterThan(0));
        expect(p.footprint.width, greaterThan(0));
      }

      // 숲 심기 헬퍼
      final forest = plantForest(
        seed: 42,
        tiles: const [Offset(1, 1), Offset(2, 2)],
      );
      expect(forest, hasLength(2));
    });

    test('prop_kit — 형상 헬퍼가 소비자에게 열려 있다', () {
      // export 를 빠뜨렸던 파일. 여기서 잡는다.
      expect(leafCluster(Offset.zero, 40, 30, seed: 1), isA<Path>());
      expect(leafBlade(Offset.zero, 30, 0.5), isA<Path>());
      expect(coniferTier(Offset.zero, 40, 20), isA<Path>());
      expect(isoDiamond(1, 1, 75, 0.577), isA<Path>());
      expect(sway(1.0, 3), isA<double>());
    });

    test('아이소 — 투영·배치·정렬', () {
      final c = scratch();
      const iso = IsoView(tileWidth: 150, tileHeight: 75);
      const light = LightRig.moonlit;

      expect(iso.project(2, 3), isA<Offset>());
      // 투영과 역투영이 서로의 역이어야 한다.
      final back = iso.unproject(iso.project(2, 3));
      expect(back.dx, closeTo(2, 1e-9));
      expect(back.dy, closeTo(3, 1e-9));
      expect(iso.squash, closeTo(0.866, 0.01));
      expect(iso.depthKey(2, 3), 5);

      paintIsoGround(c, iso, 4, 4, light);
      paintIsoHaze(c, const Rect.fromLTWH(0, 0, 800, 600), light);
      expect(isoCameraOffset(iso, 8, 8, const Size(800, 600)), isA<Offset>());
      expect(scatterTiles(3, 8, 8, 5), hasLength(3));

      // 기물과 캐릭터가 한 목록에서 정렬되어야 한다.
      paintScene(
        c,
        [
          PropItem(PropInstance(prop: TreeProp(seed: 1), tile: const Offset(1, 1))),
          ActorItem(IsoActor(artist: _MyHero(), tile: const Offset(2, 2))),
        ],
        iso,
        light,
        0.5,
      );
    });

    test('조작 — 경로탐색과 이동', () {
      final grid = IsoGrid(cols: 10, rows: 10);
      grid.blockFootprint(const Offset(4, 4), const Size(2, 2));
      expect(grid.isBlocked(4, 4), isTrue);
      expect(grid.isWalkable(0, 0), isTrue);

      // 장애물을 우회하는 경로가 나와야 한다.
      final path = grid.findPath(const Offset(0.5, 0.5), const Offset(8.5, 8.5));
      expect(path, isNotEmpty);
      for (final p in path) {
        expect(grid.isWalkable(p.dx.floor(), p.dy.floor()), isTrue,
            reason: '경로가 막힌 타일을 지난다');
      }

      // 막힌 목표는 근처 통행 가능 타일로 대체된다.
      expect(grid.findPath(const Offset(0.5, 0.5), const Offset(4.5, 4.5)),
          isNotEmpty);

      final ctrl = IsoController(
          tile: const Offset(0.5, 0.5), grid: grid, speed: 4);
      ctrl.moveTo(const Offset(8.5, 8.5));
      expect(ctrl.isMoving, isTrue);
      for (var i = 0; i < 400; i++) {
        ctrl.update(1 / 60);
      }
      expect(ctrl.isMoving, isFalse, reason: '결국 도착해야 한다');

      const iso = IsoView(tileWidth: 150, tileHeight: 75);
      expect(screenToTile(const Offset(100, 50), iso, Offset.zero), isA<Offset>());
      MoveMarker()
        ..ping(const Offset(3, 3))
        ..update(0.1);
    });

    test('방향 — 연속이며 임의 분할로 스냅할 수 있다', () {
      // 여덟 방향이 서로 다른 골격을 내야 한다.
      final body = Body.humanoid(Rng(1));
      final pose = Anims.walk.sample(0.25);
      final xs = <double>[];
      for (var i = 0; i < 8; i++) {
        final sk = solve(body, pose, yaw: i * 3.14159265 / 4);
        xs.add(sk.armNear.d.dx);
      }
      expect(xs.toSet().length, greaterThan(4),
          reason: '방향마다 팔 위치가 달라야 한다 — 같으면 yaw 가 무시되고 있다');

      // 스냅 API
      const f = Facing(1.3);
      expect(f.snap8.yaw, isA<double>());
      expect(f.snap16.sector(16), inInclusiveRange(0, 15));
      expect(f.snap32.sector(32), inInclusiveRange(0, 31));
      expect(f.snap(24).sector(24), inInclusiveRange(0, 23));
      // 형상 파라미터가 연속이어야 한다.
      expect(const Facing(0).faceVisible, greaterThan(0.9));
      expect(const Facing(3.14159265).faceVisible, lessThan(0.1));
      expect(Facing.lerp(const Facing(0), const Facing(1), 0.5).yaw,
          closeTo(0.5, 1e-9));
    });

    test('절차 생성 — 시드 결정론과 브랜치 격리', () {
      final spec = HumanoidSpec.generate(7);
      expect(HumanoidSpec.generate(7).archetype, spec.archetype);

      // 부모 스트림을 소비한 뒤에도 같은 salt 는 같은 자식을 낸다.
      final early = Rng(99).branch(11).unit;
      final parent = Rng(99);
      for (var i = 0; i < 20; i++) {
        parent.unit;
      }
      expect(parent.branch(11).unit, early);

      expect(Palette.hero(Rng(1)), isA<Palette>());
      expect(Palette.monster(Rng(1)), isA<Palette>());
      expect(Noise(3).fbm2(0.5, 0.5), inInclusiveRange(0.0, 1.0));
      expect(hsl(120, 0.5, 0.5), isA<Color>());
      expect(mix(const Color(0xFF000000), const Color(0xFFFFFFFF), 0.5),
          isA<Color>());
    });

    test('골격 구동 액터 — 클립과 방향이 컨트롤러를 따라간다', () {
      final actor = RiggedIsoActor(
        renderer: HumanoidRenderer(HumanoidSpec.generate(5)),
        tile: const Offset(1, 1),
      );
      final ctrl = IsoController(tile: const Offset(1, 1), speed: 3);
      ctrl.moveTo(const Offset(5, 5));
      actor.follow(ctrl, 1 / 60);
      expect(actor.state, 'walk');
      expect(actor.tile, ctrl.tile);

      // 한 번짜리 클립은 스스로 대기로 돌아간다.
      actor.play('attack');
      expect(actor.state, 'attack');
      for (var i = 0; i < 300; i++) {
        actor.update(1 / 60);
      }
      expect(actor.state, 'idle', reason: '공격 자세로 굳으면 안 된다');

      // Artist 를 골격 액터로 옮기는 헬퍼
      final rigged =
          riggedFromArtist(_MyHero(), tile: const Offset(2, 2), height: 200);
      expect(rigged.renderer, isA<HumanoidRenderer>());

      paintRiggedActor(scratch(), rigged,
          const IsoView(tileWidth: 150, tileHeight: 75), LightRig.daylight, 0.5);
    });
  });
}

/// 소비자가 직접 만든 캐릭터.
class _MyHero extends Artist {
  @override
  String get id => 'consumer_hero';
  @override
  String get name => 'Hero';
  @override
  String get title => 'The Consumer';
  @override
  String get blurb => '외부 프로젝트가 만든 캐릭터.';
  @override
  Camp get camp => Camp.player;
  @override
  Sex? get sex => Sex.female;
  @override
  Color get accent => const Color(0xFF57E8FF);
  @override
  LightRig get light => LightRig.heroic;
  @override
  List<Color> get moodSky => const [Color(0xFF102030), Color(0xFF203040)];

  @override
  void paint(Canvas c, double t, {double detail = 1.0}) {
    groundShadow(c, const Offset(500, kGround), 200, 40);
    final torso = torsoShape(
      chest: const Offset(500, 500),
      pelvis: const Offset(500, 850),
      shoulderW: 140,
      chestW: 120,
      waistW: 90,
      hipW: 110,
    );
    paintSurface(c, torso, Surface(accent.darken(0.3), Finish.cloth), light,
        detail: detail);
  }
}

/// 소비자가 직접 만든 기물.
class _MyFence extends Prop {
  _MyFence(this.seed);
  final int seed;

  @override
  double get height => 60;
  @override
  bool get walkable => false;

  @override
  void paint(Canvas c, double t, LightRig light, {double detail = 1.0}) {
    propShadow(c, 40, light);
    final r = Rng(seed);
    for (var i = 0; i < 4; i++) {
      final x = i * 22.0 - 33;
      final post = tube(
        [Offset(x, 0), Offset(x, -50 * r.range(0.9, 1.1))],
        [5, 3.5],
        samples: 6,
      );
      paintSurface(c, post, Surface(const Color(0xFF6B4A2E), Finish.bark), light,
          detail: detail, seed: seed + i);
    }
  }
}
