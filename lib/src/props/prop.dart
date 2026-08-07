import 'dart:ui';

import '../core/shading.dart';
import '../iso/iso_view.dart';

/// 맵에 놓이는 기물 하나.
///
/// 캐릭터([Artist])와 나란히 아이소 씬을 채우는 나무·바위·건물·물웅덩이 따위다.
/// 캐릭터와 달리 기물은 **크기가 제각각**이므로 고정 논리 캔버스를 쓰지 않고,
/// 각자 자기 픽셀 치수로 그린다.
///
/// ## 좌표 규약
///
/// 구현체는 **접지 중심이 원점, `-y` 가 위**인 국소 좌표에 그린다. 캐릭터의
/// 발밑 원점 규약과 같으므로 둘을 같은 씬에 섞어도 접지선이 어긋나지 않는다.
///
/// ## 세워지는 것과 눕는 것
///
/// 나무·바위·건물은 화면에 **수직으로 선다**([grounded] = false). 반면 웅덩이·
/// 길·풀밭은 지면 평면에 **눕는다**([grounded] = true). 눕는 기물은 세로가
/// 카메라 고도각만큼 더 눌려 원이 2:1 타원이 되며, 그래야 바닥에 붙어 보인다.
/// 이 처리는 [paintProp] 이 대신 해 주므로 구현체는 신경 쓰지 않는다.
///
/// ## 왜 시드를 받는가
///
/// 같은 숲에 똑같은 나무가 스무 그루 서 있으면 즉시 가짜로 보인다. 모든 구현체는
/// 시드를 받아 형상·색·기울기를 변주하되, **같은 시드는 언제나 같은 결과**를
/// 내야 한다([Rng] 만 쓰고 `math.Random` 을 쓰지 않는다).
abstract class Prop {
  /// 타일 단위 점유 크기. 경로탐색이 통행 가능 여부를 판단할 때 쓴다.
  ///
  /// 나무 한 그루는 `Size(1, 1)`, 큰 건물은 `Size(2, 3)` 처럼 준다.
  Size get footprint => const Size(1, 1);

  /// 화면상 높이(px). 깊이 정렬과 컬링에 쓰인다.
  double get height;

  /// 지면 평면에 눕는가. 웅덩이·길·풀밭이 `true`.
  bool get grounded => false;

  /// 캐릭터가 통과할 수 있는가. 풀·꽃·얕은 물은 통과, 나무·바위·벽은 막힌다.
  bool get walkable => grounded;

  /// 국소 좌표에 자신을 그린다. 같은 [t] 에는 언제나 같은 그림이 나와야 한다.
  ///
  /// [detail] 은 0..1 이며, 멀리 있는 기물은 낮춰 미세 텍스처를 생략한다.
  void paint(Canvas c, double t, LightRig light, {double detail = 1.0});

  // ── 굽기 ────────────────────────────────────────────────────────────────
  //
  // 실측이 이 절을 만들었다. 40×34 마을에서 화면에 든 나무 21그루가 프레임의
  // **87.5%** 를 먹고 있었다(그루당 6.1ms). 나무 하나가 잎 덩어리 여럿 ×
  // 다패스 셰이딩 × 투과·림이므로, 매 프레임 다시 그리면 그렇게 된다.
  //
  // 그런데 그 그림은 프레임마다 **거의 같다.** 한 번 텍스처로 구워 두면
  // 재생은 사각형 하나이고, 실측으로 그루당 6119µs → 2.7µs 다.

  /// 형상이 시간에 따라 바뀌지 않는가.
  ///
  /// `true` 면 [PropCache] 가 이 기물을 한 번만 그려 텍스처로 굽고, 이후
  /// 프레임에는 그 텍스처만 그린다.
  ///
  /// **바람에 흔들리는 것도 여기 해당할 수 있다.** 흔들림을 형상이 아니라
  /// [motion] 의 변환으로 표현하면 형상 자체는 고정이기 때문이다. 나무가
  /// 그렇게 한다 — 밑동을 축으로 한 전단은 변환으로 정확히 재현된다.
  ///
  /// 기본이 `false` 인 이유는 안전이다. 모르는 기물을 얼려 버리는 것보다
  /// 느린 편이 낫다 — 얼어붙은 물결은 조용한 버그이고, 느린 프레임은
  /// 눈에 보이는 문제다.
  bool get bakeable => false;

  /// 구운 텍스처에 매 프레임 거는 변환. [bakeable] 이 `true` 일 때만 불린다.
  ///
  /// 접지 중심이 원점이고 `-y` 가 위이므로, 밑동을 고정하고 위를 흔들려면
  /// y 에 비례하는 수평 이동(전단)을 건다.
  void motion(Canvas c, double t) {}

  /// 구울 수 없는 **살아 있는 한 겹**. [paint] 뒤에(구웠으면 텍스처 위에) 그린다.
  ///
  /// 굴뚝 연기처럼 기물의 대부분은 고정인데 아주 일부만 움직이는 경우가 있다.
  /// 그 하나 때문에 기물 전체를 매 프레임 다시 그리면 손해가 크므로, 형상은
  /// [paint] 에 두어 굽고 움직이는 것만 여기로 뺀다.
  ///
  /// [motion] 의 변환 **밖에서** 그려진다 — 연기는 나무처럼 기울지 않는다.
  void live(Canvas c, double t, LightRig light, {double detail = 1.0}) {}

  /// 구울 때 쓰는 국소 경계. 이 밖으로 그린 것은 잘린다.
  ///
  /// 기본값은 [height] 에서 넉넉하게 잡은 상자다. 접지 그림자가 옆으로
  /// 퍼지므로 아래로도 여유를 둔다. 실루엣이 유난히 옆으로 퍼지는 기물은
  /// 직접 주는 편이 텍스처 메모리에 이롭다.
  Rect get bakeBounds {
    final h = height;
    return Rect.fromLTRB(-h * 0.95, -h * 1.28, h * 0.95, h * 0.42);
  }
}

/// 정적 기물을 텍스처로 한 번 굽고 재생한다.
///
/// ## 무엇이 캐시를 무효로 만드는가
///
/// 구운 그림에는 **조명이 이미 칠해져 있다.** 광원이 바뀌면(정오 → 황혼)
/// 전부 버려야 한다. [of] 가 [LightRig] 의 동일성을 보고 알아서 처리하므로
/// 호출부는 신경 쓰지 않아도 된다. 맵을 다시 생성해 기물 목록이 통째로
/// 바뀔 때는 [clear] 를 부른다 — 안 부르면 못 쓰는 텍스처가 남는다.
class PropCache {
  PropCache({this.pixelRatio = 1.0, this.maxEntries = 160});

  /// 굽는 해상도 배수. 기물은 화면 픽셀과 거의 1:1 이므로 1.0 이 기본이다.
  final double pixelRatio;

  /// 담아 둘 텍스처 수의 상한. 넘으면 가장 오래된 것부터 버린다.
  final int maxEntries;

  final Map<(Prop, int), BakedProp> _cache = {};
  LightRig? _light;

  int get length => _cache.length;

  /// 이 기물의 구운 텍스처. 구울 수 없는 기물이면 `null`.
  BakedProp? of(Prop p, LightRig light, double detail) {
    if (!p.bakeable) return null;
    if (!identical(_light, light)) {
      clear();
      _light = light;
    }
    // detail 은 거리에 따라 연속으로 바뀌므로 그대로 키에 쓰면 캐시가
    // 매 프레임 갈린다. 네 단계로 뭉쳐 둔다.
    final step = (detail * 4).round().clamp(0, 4);
    final key = (p, step);
    final hit = _cache[key];
    if (hit != null) return hit;

    if (_cache.length >= maxEntries) {
      final oldest = _cache.keys.first;
      _cache.remove(oldest)?.image.dispose();
    }
    final made = _bake(p, light, step / 4);
    _cache[key] = made;
    return made;
  }

  BakedProp _bake(Prop p, LightRig light, double detail) {
    final b = p.bakeBounds;
    final w = (b.width * pixelRatio).ceil().clamp(1, 2048);
    final h = (b.height * pixelRatio).ceil().clamp(1, 2048);

    final rec = PictureRecorder();
    final c = Canvas(rec, Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()));
    c.scale(pixelRatio);
    c.translate(-b.left, -b.top);
    // t = 0 이 기준 자세다. [Prop.motion] 은 이 자세로부터의 차이만 건다.
    p.paint(c, 0, light, detail: detail);
    final pic = rec.endRecording();
    final img = pic.toImageSync(w, h);
    pic.dispose();
    return BakedProp(img, b);
  }

  /// 텍스처를 전부 버린다. 맵을 다시 생성했을 때 부른다.
  void clear() {
    for (final b in _cache.values) {
      b.image.dispose();
    }
    _cache.clear();
  }
}

/// 구운 기물 하나 — 텍스처와 그것이 차지하는 국소 사각형.
class BakedProp {
  BakedProp(this.image, this.bounds);
  final Image image;
  final Rect bounds;
}

/// 구운 텍스처를 그릴 때 쓰는 붓. 매 프레임 새로 만들지 않는다.
final Paint _bakedPaint = Paint()
  ..isAntiAlias = true
  ..filterQuality = FilterQuality.low;

/// 맵 위 특정 타일에 놓인 기물 한 개.
///
/// [Prop] 은 "무엇"이고 이것은 "어디에"다. 같은 [Prop] 인스턴스를 여러 타일에
/// 재사용하면 나무 한 그루의 형상 계산을 숲 전체가 공유한다.
class PropInstance {
  PropInstance({
    required this.prop,
    required this.tile,
    this.facesLeft = false,
    this.timeOffset = 0,
    this.scale = 1.0,
  });

  final Prop prop;

  /// 월드 타일 좌표.
  Offset tile;

  /// 좌우 반전. 같은 기물을 뒤집어 놓으면 반복이 덜 눈에 띈다.
  final bool facesLeft;

  /// 바람·명멸의 위상. 개체마다 다르게 주어야 숲이 한 몸처럼 흔들리지 않는다.
  final double timeOffset;

  /// 개체별 크기 변주. 0.85~1.15 정도가 자연스럽다.
  final double scale;

  /// 깊이 정렬 키. 화면 y 가 아니라 월드 좌표라야 높은 기물이 뒤로 밀리지 않는다.
  double get depth => tile.dx + tile.dy;

  /// 지금 그려질 불투명도(0..1). **씬이 관리한다** — 직접 건드리지 않는다.
  ///
  /// 주인공이 이 기물 뒤로 들어가면 씬이 목표값을 낮추고, 여기 담긴 값이 그
  /// 목표를 향해 매 프레임 다가간다. 즉시 갈아 끼우지 않는 이유는 하나다 —
  /// 알파가 한 프레임에 튀면 건물이 **깜빡이는 것처럼** 보이고, 주인공이
  /// 모서리를 스칠 때마다 화면이 번쩍인다.
  double opacity = 1.0;
}

/// 기물 하나를 아이소 맵에 그린다.
///
/// 세워지는 기물은 캐릭터와 똑같이 세로만 `iso.squash` 로 누르고, 눕는 기물은
/// 지면 평면에 맞춰 `iso.shadowRatio`(=sin 고도각)로 더 강하게 누른다.
void paintProp(
  Canvas c,
  PropInstance it,
  IsoView iso,
  LightRig light,
  double time, {
  double detail = 1.0,
  PropCache? cache,
  double opacity = 1.0,
}) {
  final anchor = iso.project(it.tile.dx, it.tile.dy);
  final s = it.scale;

  // 가림 페이드. 완전히 투명하면 그릴 이유가 없다.
  final a = opacity.clamp(0.0, 1.0);
  if (a <= 0.01) return;
  final faded = a < 0.999;

  c.save();
  c.translate(anchor.dx, anchor.dy);
  if (it.prop.grounded) {
    // 지면 평면에 눕는다. 원이 2:1 타원이 되어 바닥에 붙어 보인다.
    c.scale(s * (it.facesLeft ? -1 : 1), s * iso.shadowRatio);
  } else {
    c.scale(s * (it.facesLeft ? -1 : 1), s * iso.squash);
  }

  final tt = time + it.timeOffset;
  final baked = cache?.of(it.prop, light, detail);
  if (baked != null) {
    // 형상은 구운 그대로, 움직임만 변환으로 얹는다. 텍스처가 국소 좌표계
    // 안에서 재생되므로 접지점·좌우 반전·크기가 그대로 유지된다.
    c.save();
    it.prop.motion(c, tt);
    final img = baked.image;
    c.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      baked.bounds,
      // 구운 기물은 **레이어가 필요 없다.** 텍스처 한 장이므로 알파를 그리기
      // 페인트에 그대로 실으면 되고, 그러면 saveLayer 한 번(가림이 걸린 동안
      // 매 프레임, 건물 한 채가 화면의 큰 사각형)을 통째로 아낀다.
      faded ? (Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: a)) : _bakedPaint,
    );
    c.restore();
  } else if (faded) {
    // 굽지 않은 기물은 파츠가 여러 겹이다. 파츠마다 알파를 곱하면 겹친
    // 부분이 두 번 어두워져 속이 비쳐 보이므로, 한 겹으로 묶어야 한다.
    // 경계를 주어 레이어를 기물 크기로 좁힌다 — null 이면 클립 전체가 된다.
    c.saveLayer(it.prop.bakeBounds,
        Paint()..color = const Color(0xFF000000).withValues(alpha: a));
    it.prop.paint(c, tt, light, detail: detail);
    c.restore();
  } else {
    it.prop.paint(c, tt, light, detail: detail);
  }
  // 살아 있는 한 겹은 구웠든 아니든 언제나 지금 그린다.
  if (faded) {
    c.saveLayer(it.prop.bakeBounds,
        Paint()..color = const Color(0xFF000000).withValues(alpha: a));
    it.prop.live(c, tt, light, detail: detail);
    c.restore();
  } else {
    it.prop.live(c, tt, light, detail: detail);
  }
  c.restore();
}

/// 기물과 액터를 **한 목록으로 묶어** 깊이 순으로 그린다.
///
/// 기물과 캐릭터를 따로 그리면 나무 뒤로 걸어 들어간 캐릭터가 나무 앞에
/// 나타난다. 아이소 씬에서 그리기 순서는 곧 앞뒤 관계이므로, 화면에 있는
/// 모든 것이 같은 정렬을 거쳐야 한다.
///
/// ```dart
/// paintDepthSorted(canvas, [
///   ...props.map(DepthItem.prop),
///   ...actors.map(DepthItem.actor),
/// ], iso, light, time);
/// ```
void paintProps(
  Canvas c,
  List<PropInstance> props,
  IsoView iso,
  LightRig light,
  double time, {
  double Function(PropInstance)? detailOf,
}) {
  final sorted = [...props]..sort((a, b) => a.depth.compareTo(b.depth));
  for (final it in sorted) {
    paintProp(c, it, iso, light, time, detail: detailOf?.call(it) ?? 1.0);
  }
}

/// 기물이 지면에 드리우는 그림자.
///
/// 세워지는 기물에는 예외 없이 필요하다. 아이소 뷰에는 원근이 없어, 그림자가
/// 없으면 나무가 지면에 서 있는지 공중에 떠 있는지 구별할 수 없다.
void propShadow(
  Canvas c,
  double radius,
  LightRig l, {
  double alpha = 0.42,
  double stretch = 1.35,
}) {
  // 광원 반대쪽으로 늘어난 타원. 지면에 눕는 것이므로 세로를 절반으로 누른다.
  final dir = l.dir;
  final cx = -dir.dx * radius * 0.45;
  final rect = Rect.fromCenter(
    center: Offset(cx, 0),
    width: radius * 2 * stretch,
    height: radius * 1.0,
  );
  c.drawOval(
    rect,
    Paint()
      ..isAntiAlias = true
      ..shader = Gradient.radial(
        rect.center,
        rect.width * 0.5,
        [
          const Color(0xFF05070E).withValues(alpha: alpha),
          const Color(0xFF05070E).withValues(alpha: alpha * 0.42),
          const Color(0x0005070E),
        ],
        const [0.0, 0.55, 1.0],
      ),
  );
}
