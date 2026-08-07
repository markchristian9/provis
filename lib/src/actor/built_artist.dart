import 'dart:ui';

import '../anim/animator.dart';
import '../anim/library.dart';
import '../art/creature.dart';
import '../core/palette.dart';
import '../core/shading.dart';
import '../iso/iso_view.dart';
import 'character_build.dart';
import 'spec.dart';
import 'humanoid_renderer.dart';

/// 선언만으로 만들어지는 캐릭터.
///
/// ## 손으로 그린 [Artist] 와 무엇이 다른가
///
/// 손으로 그린 캐릭터는 파츠를 하나하나 배치하므로 개성의 상한이 없다 — 대신
/// 한 명에 수백 줄이 들고, **초상과 게임 액터가 서로 다른 코드**라 어긋나기
/// 쉽다. 실제로 명부에서 은발 마법사를 골랐는데 맵에서는 금발 전사가 걷는
/// 사고가 있었다.
///
/// 이쪽은 반대다. [CharacterBuild] 하나를 선언하면 **초상과 게임 액터가 같은
/// [HumanoidRenderer] 로 그려지므로 어긋날 수가 없다.** 40 줄이면 캐릭터가
/// 하나 나온다.
///
/// ```dart
/// final warrior = BuiltArtist(
///   id: 'garran',
///   name: 'Garran',
///   title: 'Shieldbearer of the Pass',
///   blurb: '고갯길을 혼자 막아선 방패병.',
///   build: CharacterBuild(
///     archetype: Archetype.knight,
///     sex: Sex.male,
///     palette: paletteOf(
///       skin: Color(0xFFC08A66), hair: Color(0xFF3A2A1E),
///       cloth: Color(0xFF7A2E2E), accent: Color(0xFFD9A441),
///     ),
///     weapon: WeaponKind.sword,
///     hasShield: true,
///   ),
/// );
/// ```
///
/// 개성이 필요한 간판 캐릭터는 손으로 그리고, 명부를 채우는 인물은 이쪽으로
/// 만드는 것이 실용적인 조합이다.
class BuiltArtist extends Artist {
  BuiltArtist({
    required this.id,
    required this.name,
    required this.title,
    required this.blurb,
    required CharacterBuild build,
    this.camp = Camp.player,
    Color? accent,
    LightRig? light,
    List<Color>? moodSky,
    this.portraitClip = 'wait',
    this.portraitYaw = 0.62,
  }) : _build = build,
       _accent = accent,
       _light = light,
       _moodSky = moodSky;

  // 아래 넷은 게터가 기본값 대체 로직을 갖고 있어 initializing formal 로
  // 바꿀 수 없다. private 필드로 받아 두고 게터에서 채운다.
  // ignore_for_file: prefer_initializing_formals

  @override
  final String id;
  @override
  final String name;
  @override
  final String title;
  @override
  final String blurb;
  @override
  final Camp camp;

  final CharacterBuild _build;
  final Color? _accent;
  final LightRig? _light;
  final List<Color>? _moodSky;

  /// 명부 초상에서 재생할 클립. 정지 자세도 숨은 쉬어야 한다.
  final String portraitClip;

  /// 명부 초상의 방향. 완전 정면(0)보다 살짝 튼 3/4 가 인물 사진처럼 보인다.
  final double portraitYaw;

  @override
  CharacterBuild get build => _build;

  @override
  Sex? get sex => _build.sex;

  @override
  Color get accent =>
      _accent ?? _build.palette?.accent ?? const Color(0xFF9AC7FF);

  /// 조명을 지정하지 않으면 **강조색을 역광에 실어** 준다.
  ///
  /// 선언형 캐릭터를 여럿 만들면 전부 같은 리그를 쓰게 되어, 은색 판금 계열이
  /// 죄다 한 인물처럼 보인다. 림라이트에 그 캐릭터의 색을 태우면 재질이 같아도
  /// 실루엣 가장자리에서 서로 갈린다 — 조명 하나로 개성이 생긴다.
  @override
  LightRig get light =>
      _light ??
      LightRig.heroic.copyWith(
        rim: accent.lighten(0.18),
        bounce: accent.darken(0.42).desaturate(0.35),
      );

  @override
  List<Color> get moodSky =>
      _moodSky ??
      [
        accent.darken(0.62).desaturate(0.3),
        accent.darken(0.44).desaturate(0.15),
      ];

  late final HumanoidSpec _spec = _build.toSpec(
    _build.seed ?? id.hashCode & 0x7FFFFFF,
  );

  late final HumanoidRenderer _renderer = HumanoidRenderer(
    _spec,
    body: _build.bodyFor(_spec),
    beast: _build.beast,
    beastForm: _build.beastForm,
  );

  /// 초상용 애니메이터. 시간의 순수 함수여야 하므로 상태를 갖지 않는다.
  late final Animator _animator = Animator()..playByName(portraitClip);

  @override
  Rect get framing => const Rect.fromLTWH(120, 120, 760, 1230);

  @override
  void paint(Canvas c, double t, {double detail = 1.0}) {
    // 초상은 게임 액터와 **같은 렌더러**로 그린다. 이 한 줄 때문에 명부에서
    // 본 인물과 맵에서 걷는 인물이 같아진다.
    final pose = Anims.byName(
      portraitClip,
    ).sample(Anims.byName(portraitClip).loop ? (t * 0.35) % 1.0 : 0.35);

    c.save();
    // kStage 좌표계의 발밑으로 옮기고, 초상에 맞게 키운다.
    c.translate(kStage.width * 0.5, kGround);
    final k = kGround * 0.86 / _renderer.body.height;
    c.scale(k);
    _renderer.paint(
      c,
      pose: pose,
      light: light,
      facing: Facing(portraitYaw),
      time: t,
      detail: detail,
    );
    c.restore();
  }

  /// 명부 초상이 숨 쉬게 하려면 이걸 매 프레임 부른다(선택).
  void tick(double dt) => _animator.update(dt);
}
