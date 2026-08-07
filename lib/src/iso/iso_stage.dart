import 'dart:math' as math;
// dart:ui 의 Clip 은 클리핑 동작 열거형이라 애니메이션 클립과 이름이 겹친다.
// 이 파일은 전자를 쓰지 않으므로 감춘다.
import 'dart:ui' hide Clip;

import '../art/creature.dart';
import '../core/noise.dart';
import '../core/palette.dart';
import '../core/rng.dart';
import '../actor/humanoid_renderer.dart';
import '../anim/animator.dart';
import '../anim/clip.dart';
import '../core/shading.dart';
import 'iso_input.dart';
import 'iso_view.dart';

/// 손으로 그린 [Artist] 를 2.5D 아이소 맵 위에 세우는 다리.
///
/// 이 파일이 존재하는 이유는 하나다. 이 저장소에서 AAA 품질이 나오는 곳은
/// `art/` 의 수작업 캐릭터인데, 그들은 [kStage] 라는 초상용 논리 캔버스에
/// 그려지도록 만들어졌다. 반면 게임 맵은 아이소메트릭이다. 둘을 잇지 못하면
/// "품질은 갤러리에, 게임은 저품질 액터로" 라는 분열이 영원히 남는다.
///
/// 다리는 좌표 변환 하나로 충분하다. 셰이딩·부위 형상·마무리는 좌표계를
/// 모르기 때문이다. 그래서 **완성된 캐릭터를 한 줄도 고치지 않고** 아이소
/// 씬에 세울 수 있다.
///
/// ```
/// ① 접지점만 아이소 투영한다        iso.project(tile)
/// ② 원하는 키로 스케일한다           height / kStage.height
/// ③ 세로만 카메라 고도각으로 누른다   × iso.squash
/// ④ Artist 원점을 발밑으로 옮긴다     (-kStage.width/2, -kGround)
/// ```

/// 아이소 맵 위에 선 액터 하나.
class IsoActor {
  IsoActor({
    required this.artist,
    required this.tile,
    this.height = 430,
    this.facesLeft = false,
    this.airborne = 0,
    this.timeOffset = 0,
  });

  final Artist artist;

  /// 월드 타일 좌표. 게임 로직은 이것만 갱신한다.
  Offset tile;

  /// 화면상 키(px). 타일 폭의 1.2~1.6배가 아이소 게임의 인간형 표준이다.
  /// 그보다 크면 격자가 묻혀 지면 평면이 사라진다.
  double height;

  /// 좌우 반전 여부. 아이소 8방향 중 서쪽 절반을 향할 때 켠다.
  bool facesLeft;

  /// 지면에서 뜬 높이(월드 단위). 점프·비행에 쓴다.
  double airborne;

  /// 개체마다 애니메이션 위상을 어긋나게 해 군집이 한 몸처럼 움직이는 것을 막는다.
  double timeOffset;

  /// 깊이 정렬 키. 화면 y 가 아니라 월드 좌표라야 점프해도 순서가 유지된다.
  double get depth => tile.dx + tile.dy;
}

/// [IsoActor] 하나를 그린다.
///
/// [detail] 은 그대로 [Artist.paint] 에 전달된다. 멀리 있는 개체는 낮춰서
/// 미세 텍스처와 파티클을 생략한다 — `detailFor()` 참조.
void paintIsoActor(
  Canvas c,
  IsoActor a,
  IsoView iso,
  double time, {
  double detail = 1.0,
}) {
  final anchor = iso.project(a.tile.dx, a.tile.dy, a.airborne);
  final s = a.height / kStage.height;

  c.save();
  c.translate(anchor.dx, anchor.dy);
  // 세로만 카메라 고도각으로 누른다. 가로까지 누르면 인체가 찌그러진다.
  c.scale(s * (a.facesLeft ? -1 : 1), s * iso.squash);
  // Artist 는 발바닥이 kGround, 가로 중심이 kStage.width/2 인 좌표계로 그린다.
  c.translate(-kStage.width / 2, -kGround);
  a.artist.paint(c, time + a.timeOffset, detail: detail);
  c.restore();
}

/// 여러 액터를 깊이 순으로 그린다.
///
/// 아이소 씬에서 그리기 순서는 곧 앞뒤 관계다. 정렬을 빠뜨리면 뒤에 선
/// 캐릭터가 앞 캐릭터를 덮어 장면이 무너진다.
void paintIsoActors(
  Canvas c,
  List<IsoActor> actors,
  IsoView iso,
  double time, {
  double Function(IsoActor)? detailOf,
}) {
  final sorted = [...actors]..sort((x, y) => x.depth.compareTo(y.depth));
  for (final a in sorted) {
    paintIsoActor(c, a, iso, time, detail: detailOf?.call(a) ?? 1.0);
  }
}

/// 아이소 지면.
///
/// 캐릭터가 서 있는 평면이 보여야 2.5D 로 읽힌다. 지면이 없으면 캐릭터가
/// 허공에 뜬 카드로 보인다.
///
/// ## 왜 체커 타일이 아닌가
///
/// 타일마다 명도를 번갈아 칠하면 지면이 **장판**이 된다. 격자는 개발 중
/// 좌표를 확인하는 도구이지 땅이 아니다. 진짜 땅으로 보이려면 세 가지가
/// 필요하다.
///
/// 1. **큰 얼룩 → 작은 얼룩의 층위.** 흙이 드러난 곳, 풀이 짙은 곳이 타일
///    경계와 무관하게 번져야 한다. 한 겹만 있으면 노이즈 텍스처로 보인다.
/// 2. **거리 감쇠.** 먼 쪽이 어두워지고 환경광으로 밀리면 평면에 깊이가 생긴다.
/// 3. **가장자리의 흙 두께.** 맵 경계에서 지면이 그냥 끊기면 종이가 잘린
///    것이지만, 흙 단면이 보이면 **두께를 가진 땅덩어리**가 된다. 비용 대비
///    3D 감각 개선이 가장 큰 한 겹이다.
///
/// [lineAlpha] 를 0 으로 주면 격자선 없이 땅만 그린다 — 인게임 기본값이다.
///
/// [visible] 은 지금 화면에 들어오는 영역(이 캔버스와 같은 좌표계)이다. 주면
/// 그 밖의 얼룩을 그리지 않는다 — 맵이 40×34 로 커지면 얼룩이 수백 개가 되고,
/// 그 대부분은 화면 밖이다. 안 주면 전부 그린다.
void paintIsoGround(
  Canvas c,
  IsoView iso,
  int cols,
  int rows,
  LightRig l, {
  Color? base,
  double lineAlpha = 0.10,
  Color? soil,
  int seed = 7,
  double detail = 1.0,
  double skirt = 0.55,
  Rect? visible,
}) {
  // 땅에는 땅의 고유색이 있다. 환경광을 베이스로 삼으면 지면이 그 시각의
  // 하늘색을 뒤집어써 회보라 장판이 되고, 그 위에 선 모든 것이 떠 보인다.
  // 고유색을 먼저 두고 환경광은 **위에 섞는다**.
  final ground = base ??
      const Color(0xFF5C6B3C).mix(l.ambient, 0.38).lighten(0.06 * l.intensity);
  final dirt = soil ?? const Color(0xFF6A4E2E).mix(l.ambient, 0.34);

  final far = iso.project(0, 0);
  final near = iso.project(cols.toDouble(), rows.toDouble());
  final left = iso.project(0, rows.toDouble());
  final right = iso.project(cols.toDouble(), 0);

  final field = Path()
    ..moveTo(far.dx, far.dy)
    ..lineTo(right.dx, right.dy)
    ..lineTo(near.dx, near.dy)
    ..lineTo(left.dx, left.dy)
    ..close();

  // ── 가장자리 흙 두께. 지면보다 **먼저** 그려야 위에서 덮인다.
  if (skirt > 0.01) {
    final depth = iso.tileHeight * skirt;
    final wall = Path()
      ..moveTo(left.dx, left.dy)
      ..lineTo(near.dx, near.dy)
      ..lineTo(right.dx, right.dy)
      ..lineTo(right.dx, right.dy + depth)
      ..lineTo(near.dx, near.dy + depth)
      ..lineTo(left.dx, left.dy + depth)
      ..close();
    final wb = wall.getBounds();
    c.drawPath(
      wall,
      Paint()
        ..isAntiAlias = true
        ..shader = Gradient.linear(
          Offset(wb.center.dx, wb.top),
          Offset(wb.center.dx, wb.bottom),
          [
            dirt.darken(0.12),
            dirt.darken(0.34).mix(l.ambient, 0.30),
            dirt.darken(0.55).mix(l.ambient, 0.45),
          ],
          const [0.0, 0.5, 1.0],
        ),
    );
    // 지층 두 줄 — 흙벽이 단조롭지 않게.
    if (detail > 0.4) {
      final n = Noise(seed * 13 + 3);
      final line = Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, depth * 0.07);
      for (var i = 1; i <= 2; i++) {
        final v = i / 3;
        line.color = dirt.darken(0.45).fade(0.4);
        c.drawPath(
          Path()
            ..moveTo(left.dx, left.dy + depth * v)
            ..lineTo(near.dx, near.dy + depth * v * (1 + 0.08 * n.signed1(i * 3.1)))
            ..lineTo(right.dx, right.dy + depth * v),
          line,
        );
      }
    }
  }

  c.save();
  c.clipPath(field);

  // ── 베이스 + 거리 감쇠. 먼 쪽이 환경광으로 밀린다.
  final fb = field.getBounds();
  c.drawRect(
    fb,
    Paint()
      ..isAntiAlias = true
      ..shader = Gradient.linear(
        Offset(fb.center.dx, fb.top),
        Offset(fb.center.dx, fb.bottom),
        [
          ground.darken(0.20).mix(l.ambient, 0.40),
          ground.darken(0.04).mix(l.ambient, 0.12),
          ground.lighten(0.06),
        ],
        const [0.0, 0.55, 1.0],
      ),
  );

  // ── 얼룩 두 층. 타일 경계와 무관하게 번져야 땅이 된다.
  //
  // **크기의 기준은 타일이지 필드가 아니다.** 예전에는 필드의 긴 변에
  // 비례시켰는데, 그러면 맵을 8×8 에서 40×34 로 키우는 순간 얼룩 하나가
  // 반지름 800px 짜리 블러가 된다. 실측에서 이 한 겹이 지면 래스터의
  // 거의 전부(36.9ms/프레임)였다. 그림으로도 틀렸다 — 그 크기는 땅의
  // 결이 아니라 화면을 가로지르는 거대한 얼룩 하나다.
  //
  // 개수는 넓이에 비례시켜 밀도를 일정하게 유지한다. 맵이 커지면 얼룩이
  // 커지는 것이 아니라 많아져야 한다.
  if (detail > 0.25) {
    final r = Rng(seed * 31 + 5);
    final unit = iso.tileWidth;
    final tiles = cols * rows;

    /// 얼룩 한 층.
    ///
    /// 블러는 **하나에 하나씩** 태운다. 흩어진 얼룩을 한 [Path] 에 모아 한 번에
    /// 태우고 싶어지지만(그것이 나무 수관에서는 옳다) 여기서는 정반대다 —
    /// 맵 전체에 흩어진 타원의 합집합은 필드 전체를 덮으므로, 블러 한 번이
    /// 5550×2775 영역에 걸린다. 실측에서 그 "최적화"가 21fps 를 14fps 로
    /// 떨어뜨렸다. 모아서 태우는 규칙은 **점들이 한 파츠 안에 모여 있을 때**만
    /// 맞는다.
    ///
    /// 대신 [visible] 밖의 얼룩은 아예 그리지 않는다. 맵이 커져도 비용이
    /// 화면 크기에 묶인다.
    void layer(int count, double lo, double hi, double blurK, Color a, Color b,
        double alpha) {
      final paint = Paint()..isAntiAlias = true;
      for (var i = 0; i < count; i++) {
        final at = Offset(
          fb.left + r.unit * fb.width,
          fb.top + r.unit * fb.height,
        );
        final s = unit * r.range(lo, hi);
        final box = Rect.fromCenter(center: at, width: s * 2.4, height: s * 1.2);
        // 시드 소비는 컬링과 무관해야 한다 — 그래야 카메라가 움직여도
        // 같은 자리에 같은 얼룩이 남는다. 그래서 뽑기는 끝낸 뒤 거른다.
        if (visible != null && !visible.overlaps(box.inflate(s * blurK * 2))) {
          continue;
        }
        paint
          ..color = (r.chance(0.5) ? a : b).fade(alpha)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * blurK);
        c.drawOval(box, paint);
      }
    }

    // 개수는 넓이에 비례시켜 밀도를 일정하게 유지한다. 맵이 커지면 얼룩이
    // 커지는 것이 아니라 많아져야 한다.
    layer((tiles * 0.035).round().clamp(6, 70), 0.85, 2.1, 0.42, dirt,
        ground.darken(0.14), 0.20);
    layer((tiles * 0.09).round().clamp(10, 170), 0.18, 0.46, 0.55,
        ground.darken(0.20), ground.lighten(0.14), 0.21);

    // ── 낟알 층. 얼룩이 명도의 **대역**을 만들었으면, 이쪽은 손에 잡히는
    // **결**을 만든다 — 풀 이삭은 짧게 기운 획으로, 흙 알갱이는 납작한
    // 점으로. 블러가 전혀 없어서 얼룩보다 개수가 몇 배라도 싸다. 시드
    // 소비를 컬링보다 먼저 끝내는 규칙은 위와 같다.
    if (detail > 0.45) {
      final grain = Paint()..isAntiAlias = true;
      final blade = Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      // 타일당 너덧 개는 있어야 결로 읽힌다. 얼룩과 달리 개수를 크게 잡는
      // 이유는 하나 — 블러가 없으면 점 하나의 비용이 수백 분의 일이다.
      final count = (tiles * 6.0).round().clamp(320, 8000);
      for (var i = 0; i < count; i++) {
        final at = Offset(
          fb.left + r.unit * fb.width,
          fb.top + r.unit * fb.height,
        );
        final grass = r.chance(0.62);
        final s = unit * r.range(0.026, 0.070);
        final lean = r.signed(0.55);
        final tone = r.unit;
        if (visible != null &&
            !visible.overlaps(Rect.fromCircle(center: at, radius: s * 3))) {
          continue;
        }
        if (grass) {
          blade
            ..strokeWidth = math.max(1.0, s * 0.28)
            ..color = ground.lighten(0.12 + 0.20 * tone).fade(0.45);
          c.drawLine(
            at,
            at + Offset(s * lean, -s * (0.9 + 0.5 * tone)),
            blade,
          );
        } else {
          grain.color =
              (tone > 0.5 ? dirt.darken(0.18) : ground.darken(0.30)).fade(0.34);
          c.drawOval(
            Rect.fromCenter(center: at, width: s * 1.7, height: s * 0.8),
            grain,
          );
        }
      }
    }
  }
  c.restore();

  // ── 격자선. 0 이면 그리지 않는다.
  if (lineAlpha > 0.001) {
    final line = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = l.rim.fade(lineAlpha);
    for (var x = 0; x <= cols; x++) {
      final a = iso.project(x.toDouble(), 0);
      final b = iso.project(x.toDouble(), rows.toDouble());
      c.drawLine(a, b, line);
    }
    for (var y = 0; y <= rows; y++) {
      final a = iso.project(0, y.toDouble());
      final b = iso.project(cols.toDouble(), y.toDouble());
      c.drawLine(a, b, line);
    }
  }

  // ── 지면 가장자리의 밝은 선. 땅덩어리의 윤곽을 세운다.
  c.drawPath(
    field,
    Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = ground.lighten(0.26).fade(0.35),
  );
}

/// 씬 전체에 얹는 대기 원근(aerial perspective).
///
/// 먼 곳이 환경광 쪽으로 흐려지면 평면이던 화면에 깊이가 생긴다. 실사 렌더의
/// 안개와 같은 역할이며, 2D 에서는 이 한 겹이 비용 대비 효과가 가장 크다.
void paintIsoHaze(Canvas c, Rect view, LightRig l, {double strength = 0.5}) {
  c.drawRect(
    view,
    Paint()
      ..blendMode = BlendMode.srcOver
      ..shader = Gradient.linear(
        view.topCenter,
        view.bottomCenter,
        [
          l.ambient.fade((0.72 * strength).clamp(0.0, 1.0)),
          l.ambient.fade(0.0),
        ],
        const [0.0, 0.62],
      ),
  );
}

/// 화면 크기와 역할로 디테일 레벨을 정한다.
///
/// 아이소 씬은 캐릭터가 작게 보이므로, 전원을 최고 품질로 그리면 보이지도
/// 않는 텍스처에 프레임을 쓴다.
double isoDetailFor(IsoActor a, {bool isHero = false}) {
  if (isHero) return 1.0;
  if (a.height > 260) return 1.0;
  if (a.height > 160) return 0.7;
  return 0.35;
}

/// 타일 좌표를 격자로 흩뿌린다. 데모·군집 배치용.
List<Offset> scatterTiles(int count, int cols, int rows, int seed) {
  final out = <Offset>[];
  var h = seed & 0x7FFFFFFF;
  int next() {
    h = (h * 1103515245 + 12345) & 0x7FFFFFFF;
    return h;
  }

  final taken = <String>{};
  var guard = 0;
  while (out.length < count && guard++ < count * 40) {
    final x = next() % cols;
    final y = next() % rows;
    final key = '$x:$y';
    if (taken.contains(key)) continue;
    taken.add(key);
    out.add(Offset(x + 0.5, y + 0.5));
  }
  return out;
}

/// 씬 전체가 화면에 들어오도록 카메라 오프셋을 계산한다.
Offset isoCameraOffset(IsoView iso, int cols, int rows, Size view) {
  final corners = [
    iso.project(0, 0),
    iso.project(cols.toDouble(), 0),
    iso.project(cols.toDouble(), rows.toDouble()),
    iso.project(0, rows.toDouble()),
  ];
  var minX = double.infinity, maxX = -double.infinity;
  var minY = double.infinity, maxY = -double.infinity;
  for (final p in corners) {
    minX = math.min(minX, p.dx);
    maxX = math.max(maxX, p.dx);
    minY = math.min(minY, p.dy);
    maxY = math.max(maxY, p.dy);
  }
  return Offset(
    view.width / 2 - (minX + maxX) / 2,
    view.height / 2 - (minY + maxY) / 2,
  );
}

// ---------------------------------------------------------------------------
// 골격 구동 액터 — 8방향 회전과 보행 애니메이션
// ---------------------------------------------------------------------------

/// 관절이 움직이고 방향에 따라 몸이 도는 액터.
///
/// ## [IsoActor] 와 무엇이 다른가
///
/// [IsoActor] 는 손으로 그린 [Artist] 를 그대로 세운다 — 품질은 가장 높지만
/// **고정된 3/4 초상**이라 걸어도 자세가 그대로고, 좌우 반전 말고는 방향이
/// 없다. 게임플레이 캐릭터로 쓰면 정지 자세로 미끄러진다.
///
/// 이쪽은 [HumanoidRenderer] 를 쓴다. 매 프레임 [Pose] 를 풀어 그리므로
/// **다리가 실제로 교차하고**, [Facing] 에 따라 어깨 폭·사지 앞뒤·얼굴 표시가
/// 바뀌어 북쪽을 보면 뒷모습이, 남쪽을 보면 앞모습이, 동서로는 옆모습이 나온다.
///
/// ```dart
/// final hero = RiggedIsoActor(
///   renderer: HumanoidRenderer(HumanoidSpec.generate(7)),
///   tile: const Offset(6.5, 9.5),
///   height: 200,
/// );
/// // 매 프레임 — 컨트롤러의 위치·방향·이동 여부를 그대로 따른다
/// hero.follow(controller, dt);
/// ```
class RiggedIsoActor {
  RiggedIsoActor({
    required this.renderer,
    required this.tile,
    this.height = 200,
    Animator? animator,
    this.yaw = 0,
    this.runThreshold,
    this.iso = kIso,
  }) : animator = animator ?? Animator();

  final HumanoidRenderer renderer;

  /// 클립 재생기. 기본값은 [Anims.all] 전체를 들고 있다.
  final Animator animator;

  /// 월드 타일 좌표.
  Offset tile;

  /// 화면상 키(px). 타일 폭의 1.2~1.6배가 표준이다.
  double height;

  /// 보폭 동기화가 쓰는 카메라. **맵과 같은 것을 준다.**
  ///
  /// 타일이 얼마나 큰지 모르면 "초당 3 타일"이 빠른 것인지 느린 것인지 알
  /// 수 없고, 그러면 클립을 실제 이동에 맞출 수 없다. 기본값은 [kIso] 이므로
  /// 다른 타일 크기를 쓰는 맵은 반드시 넘겨야 한다.
  IsoView iso;

  /// 이 속도(타일/초)를 넘으면 걷기 대신 달리기 클립을 쓴다.
  ///
  /// `null`(기본)이면 [gaitCrossover] 로 **골격에서 자동으로 정한다**. 고정
  /// 임계값을 기본으로 두지 않는 이유는, 타일 크기나 캐릭터 키가 바뀌는
  /// 순간 그 숫자가 반드시 틀리기 때문이다 — 다리가 짧은 몬스터는 같은
  /// 속도에서 더 일찍 뛰어야 한다.
  double? runThreshold;

  /// 바라보는 각도(라디안). 0 이 카메라 정면(남).
  double yaw;

  double get depth => tile.dx + tile.dy;

  /// 지면에서 뜬 높이(월드 단위).
  double airborne = 0;

  /// 원거리 무기 자세로 그린다.
  bool ranged = false;

  String _state = 'idle';

  /// 시간을 씬이 대신 돌리고 있는가.
  ///
  /// [IsoSceneComponent] 는 자기 목록의 액터를 매 프레임 진행시키고, 게임
  /// 코드는 같은 프레임에 [follow] 를 부른다. **둘 다 시간을 밀면 모든 동작이
  /// 정확히 두 배 빨라진다** — 걷기가 종종걸음이 되고 공격이 절반 시간에
  /// 끝난다. 씬이 표시를 남기면 [follow] 는 입력만 갱신하고 시간은 건드리지
  /// 않는다.
  bool _sceneDriven = false;

  /// 현재 재생 중인 상태 이름.
  String get state => _state;

  /// 걷기와 달리기가 갈리는 속도(타일/초).
  ///
  /// 두 클립이 발을 미끄러뜨리지 않고 낼 수 있는 속도([naturalSpeed])를
  /// 로그 축에서 가른 값이다. 이 아래로는 걷기를 조금 빠르게 돌리는 것이,
  /// 위로는 달리기를 조금 느리게 돌리는 것이 자연스럽다.
  double get gaitCrossover {
    final w = naturalSpeed(animator.byName('walk'));
    final r = naturalSpeed(animator.byName('run'));
    if (w <= 0 || r <= 0) return double.infinity;
    return math.sqrt(w * r);
  }

  /// [c] 를 저작된 속도 그대로 재생했을 때 나오는 이동 속도(타일/초).
  double naturalSpeed(Clip c) =>
      c.duration <= 0 ? 0 : cycleTiles(c) / c.duration;

  /// [c] 한 사이클이 나아가는 거리(타일).
  ///
  /// 클립은 다리 길이의 배수로 보폭을 적고([Clip.strideCycle]), 여기서 이
  /// 액터의 실제 다리 길이와 타일 크기로 환산한다.
  double cycleTiles(Clip c) {
    if (c.strideCycle <= 0) return 0;
    final b = renderer.body;
    final scale = iso.worldScale;
    if (b.height <= 0 || scale <= 0) return 0;
    // 화면상 다리 길이 — 렌더러가 body.height 를 this.height 로 스케일한다.
    final legPx = b.legLength * (height / b.height);
    return c.strideCycle * legPx / scale;
  }

  /// 이동 컨트롤러를 그대로 따라간다 — 위치·방향·클립·보폭을 한 번에 맞춘다.
  ///
  /// 이동 여부와 속도에 따라 걷기/달리기/대기로 자동 전환하고, 클립의 재생
  /// 배속을 실제 이동 속도에 맞춘다. 게임 쪽에서는 컨트롤러만 조작하면 된다.
  /// 공격·피격처럼 이동과 무관한 동작은 [play] 로 끼워 넣는다.
  void follow(IsoController c, double dt) {
    tile = c.tile;
    yaw = c.yaw;

    if (c.isMoving) {
      final want = _gaitFor(c.speed);
      if (want != _state && !_isOneShot(_state)) play(want);
      // 클립 한 사이클이 나아가는 거리를 실제 이동 거리에 맞춘다. 이걸
      // 빼먹으면 캐릭터가 얼음판을 지치듯 미끄러진다.
      animator.rate = _rateFor(animator.current, c.speed);
    } else {
      animator.rate = 1.0;
      if (_state != 'idle' && !_isOneShot(_state)) play('idle');
    }

    // 씬이 시간의 주인이면 여기서 또 밀지 않는다.
    if (!_sceneDriven) update(dt);
  }

  /// 클립을 이름으로 재생한다. 기본 이동·상태 클립과 `attack1..3`,
  /// `shoot1..3`, `cast1..3` 콤보를 쓴다. 1타의 이름은 호환을 위해
  /// 각각 `attack`·`shoot`·`cast`다.
  void play(String name) {
    _state = name;
    animator.playByName(name);
  }

  void update(double dt) {
    animator.update(dt);
    // 한 번짜리 동작이 끝나면 대기로 돌아간다. 이게 없으면 공격 자세로
    // 굳은 채 걸어 다닌다.
    if (_isOneShot(_state) && animator.progress >= 1.0) {
      play('idle');
    }
  }

  /// [IsoSceneComponent] 전용 진입점. 게임 코드는 [follow] 나 [update] 를 쓴다.
  void driveByScene(double dt) {
    _sceneDriven = true;
    update(dt);
  }

  String _gaitFor(double speed) {
    final t = runThreshold ?? gaitCrossover;
    return speed >= t ? 'run' : 'walk';
  }

  /// 이동 속도에 맞춘 재생 배속.
  ///
  /// 제자리 동작(공격·피격)에는 걸지 않는다 — 빨리 걷는다고 칼이 빨리
  /// 나가면 판정 타이밍이 속도에 따라 달라진다.
  double _rateFor(Clip c, double speed) {
    final cycle = cycleTiles(c);
    if (cycle <= 1e-6) return 1.0;
    // 대역을 열어 두면 극단에서 클립이 무너진다. 걷기를 두 배로 돌리면
    // 종종걸음이 되고, 절반으로 돌리면 발이 공중에 멎는다.
    return (c.duration * speed / cycle).clamp(0.55, 1.9);
  }

  bool _isOneShot(String name) =>
      name.startsWith('attack') ||
      name.startsWith('shoot') ||
      name.startsWith('cast') ||
      name == 'hit' ||
      name == 'dash';
}

/// [RiggedIsoActor] 하나를 그린다.
///
/// [HumanoidRenderer] 가 내부에서 세로 단축과 좌우 미러를 처리하므로, 여기서는
/// 접지점으로 옮기고 원하는 키로 스케일하기만 한다.
void paintRiggedActor(
  Canvas c,
  RiggedIsoActor a,
  IsoView iso,
  LightRig light,
  double time, {
  double detail = 1.0,
}) {
  final anchor = iso.project(a.tile.dx, a.tile.dy, a.airborne);
  final s = a.height / a.renderer.body.height;

  c.save();
  c.translate(anchor.dx, anchor.dy);
  c.scale(s);
  a.renderer.paint(
    c,
    pose: a.animator.pose,
    light: light,
    facing: Facing(a.yaw),
    iso: iso,
    time: time,
    detail: detail,
    ranged: a.ranged,
  );
  c.restore();
}
