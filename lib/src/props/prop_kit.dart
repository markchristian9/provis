/// 기물을 "덩어리"에서 "물건"으로 바꾸는 공용 도구.
///
/// ## 왜 이 파일이 필요한가
///
/// 나무를 초록 타원으로, 바위를 회색 조약돌로, 벽을 회색 상자로 그리면 형태는
/// 맞지만 전부 **클립아트**가 된다. 실물처럼 보이는 것과 그렇지 않은 것을 가르는
/// 요소는 재질별로 다르지 않고 대개 같은 네 가지다.
///
/// 1. **실루엣이 재질을 말한다.** 잎 뭉치의 윤곽은 매끄러운 곡선이 아니라
///    작은 돌기가 반복되는 울퉁불퉁한 선이다. 이 신호 하나가 없으면 어떤
///    셰이딩을 얹어도 풍선이다. → [leafCluster] · [leafBlade]
/// 2. **덩어리 안에 덩어리가 있다.** 수관은 잎 뭉치 여럿이 겹친 것이고, 벽은
///    돌 하나하나가 쌓인 것이다. 단일 그라디언트로는 절대 나오지 않는
///    내부 요철을 [lobeLight] · [courseTexture] 가 만든다.
/// 3. **접지가 두 겹이다.** 넓고 옅은 드리운 그림자(`propShadow`)만 있으면
///    물체가 그림자 위에 얹힌 스티커가 된다. 접촉선 바로 아래의 좁고 짙은
///    코어(`contactAO`)와 밑동을 감싸는 흙([rootSkirt])이 함께 있어야 박힌다.
/// 4. **위를 향한 면이 밝다.** 아이소는 위에서 내려다보는 시점이므로 상단면이
///    하늘을 정면으로 받는다. 이 위계가 무너지면 입체가 사라진다. → `topPlane`
///
/// 여기 있는 것은 전부 **재질 무관한 형상·배치 도구**다. 빛에 반응하는 방식은
/// `core/shading.dart` 의 [Finish] 가 담당한다 — 셰이딩 계보는 하나뿐이다.
library;

import 'dart:math' as math;
import 'dart:ui';

import '../core/noise.dart';
import '../core/palette.dart';
import '../core/rng.dart';
import '../core/shading.dart';
import '../core/spline.dart';

// ---------------------------------------------------------------------------
// 잎 — 실루엣이 전부다
// ---------------------------------------------------------------------------

/// 잎 뭉치 하나의 실루엣.
///
/// 코어 타원 하나에 둘레 돌기(lobe)를 겹쳐 **하나의 채워진 형상**으로 만든다.
/// [PathFillType.nonZero] 덕분에 겹친 부분의 경계선이 사라지고 바깥 윤곽만
/// 남으므로, 값비싼 불 연산 없이 울퉁불퉁한 구름 형상이 나온다.
///
/// 매끄러운 타원과의 차이가 곧 "나뭇잎으로 보이는가"의 차이다. [lobes] 를 0 으로
/// 두면 그냥 타원이 되므로, 잎에는 절대 0 을 주지 않는다.
Path leafCluster(
  Offset center,
  double rx,
  double ry, {
  int lobes = 8,
  double lobeSize = 0.44,
  double spread = 0.86,
  int seed = 1,
  double roughness = 0.14,
}) {
  final n = Noise(seed * 131 + 17);
  final path = Path()..fillType = PathFillType.nonZero;

  // 코어 — 전체 부피를 담당한다. 이것도 살짝 찌그러뜨려야 로브를 걷어냈을 때
  // 원이 드러나지 않는다.
  path.addPath(
    blob(
      center,
      rx * 0.78,
      ry * 0.78,
      points: 11,
      warp: (a, u) => 1.0 + roughness * n.signed1(u * 4.0 + 3.1),
    ),
    Offset.zero,
  );

  // 둘레 돌기 — 크기를 제각각으로 흔들어야 톱니바퀴가 되지 않는다.
  for (var i = 0; i < lobes; i++) {
    final u = i / lobes;
    final a = u * math.pi * 2 + n.signed1(u * 9.0 + seed * 0.7) * 0.42;
    final d = spread * (0.72 + 0.34 * n.at1(u * 6.3 + 11));
    final sz = lobeSize * (0.62 + 0.62 * n.at1(u * 5.1 + 29));
    path.addPath(
      blob(
        center + Offset(math.cos(a) * rx * d, math.sin(a) * ry * d),
        rx * sz,
        ry * sz * (0.82 + 0.3 * n.at1(u * 3.3)),
        points: 9,
        warp: (ang, t) => 1.0 + 0.16 * n.signed1(t * 5.0 + i * 2.7),
      ),
      Offset.zero,
    );
  }
  return path;
}

/// 잎 하나. 실루엣 가장자리에서 삐져나와 덩어리의 윤곽을 깨뜨린다.
///
/// 수관을 아무리 잘 칠해도 윤곽선이 매끈하면 젤리로 보인다. 가장자리에 이것을
/// 수십 장 흩뿌리는 것이 가장 값싸고 확실한 처방이다.
Path leafBlade(Offset root, double length, double angle, {double width = 0.42}) {
  final dir = Offset(math.cos(angle), math.sin(angle));
  final nrm = dir.perp;
  final w = length * width;
  final tip = root + dir * length;
  final mid = root + dir * (length * 0.42);
  return smoothClosedPath([
    root,
    mid + nrm * w,
    root + dir * (length * 0.78) + nrm * w * 0.55,
    tip,
    root + dir * (length * 0.78) - nrm * w * 0.55,
    mid - nrm * w,
  ], tension: 0.85);
}

/// 침엽수 가지 한 단. 아래로 처지고 끝이 뾰족한 톱니 실루엣.
///
/// 침엽수를 매끈한 삼각형으로 그리면 크리스마스 장식이 된다. 바늘잎 다발이
/// 축에서 갈라져 **아래로 처진다**는 사실이 실루엣에 나와야 한다.
Path coniferTier(
  Offset apex,
  double halfWidth,
  double drop, {
  int teeth = 7,
  int seed = 3,
  double sag = 0.34,
}) {
  final n = Noise(seed * 71 + 13);
  final pts = <Offset>[];
  // 오른쪽 아래로 내려가며 톱니를 만든다.
  for (var i = 0; i <= teeth; i++) {
    final u = i / teeth;
    final wob = 1.0 + 0.16 * n.signed1(u * 5.0 + seed);
    final x = halfWidth * u * wob;
    final y = drop * (u * u * 0.55 + u * 0.45);
    // 바늘 다발의 끝 — 바깥 아래로 뾰족하게 뻗는다.
    pts.add(apex + Offset(x, y + drop * sag * u * (0.55 + 0.5 * n.at1(u * 7.7))));
    if (i < teeth) {
      final u2 = (i + 0.5) / teeth;
      pts.add(apex +
          Offset(halfWidth * u2 * 0.94, drop * (u2 * u2 * 0.5 + u2 * 0.42)));
    }
  }
  // 밑변을 따라 왼쪽으로 돌아온다.
  pts.add(apex + Offset(0, drop * 1.12));
  for (var i = teeth; i >= 0; i--) {
    final u = i / teeth;
    final wob = 1.0 + 0.16 * n.signed1(u * 5.0 + seed * 1.7 + 40);
    final x = -halfWidth * u * wob;
    final y = drop * (u * u * 0.55 + u * 0.45);
    if (i < teeth) {
      final u2 = (i + 0.5) / teeth;
      pts.add(apex +
          Offset(-halfWidth * u2 * 0.94, drop * (u2 * u2 * 0.5 + u2 * 0.42)));
    }
    pts.add(
        apex + Offset(x, y + drop * sag * u * (0.55 + 0.5 * n.at1(u * 6.1 + 9))));
  }
  return smoothClosedPath(pts, tension: 0.55);
}

/// 잎 덩어리에 내부 요철을 만드는 국소 광량.
///
/// 수관은 잎 뭉치 여럿이 겹친 것이라, 단일 그라디언트로는 절대 나오지 않는
/// **뭉치 단위의 밝기 차**가 있다. 광원 쪽 위에 밝은 로브를, 반대쪽 아래에
/// 어두운 로브를 몇 개 얹으면 같은 실루엣이 갑자기 부피를 갖는다.
///
/// 호출 전에 대상 형상으로 클립되어 있어야 한다.
void lobeLight(
  Canvas c,
  Offset center,
  double rx,
  double ry,
  Color tone,
  LightRig l, {
  int seed = 5,
  int count = 3,
  double strength = 1.0,
}) {
  final n = Noise(seed * 197 + 7);
  for (var i = 0; i < count; i++) {
    final u = (i + 0.5) / count;
    final lit = i.isEven;
    // 밝은 뭉치는 광원 쪽 위, 어두운 뭉치는 반대쪽 아래.
    final base = lit ? l.dir : -l.dir;
    final jitter = Offset(n.signed1(u * 8.0 + seed), n.signed1(u * 5.0 + 31));
    final at = center +
        Offset(base.dx * rx * 0.42, base.dy * ry * 0.46) +
        Offset(jitter.dx * rx * 0.34, jitter.dy * ry * 0.30);
    final rad = rx * (0.34 + 0.24 * n.at1(u * 3.7 + 13));
    final rect = Rect.fromCenter(
      center: at,
      width: rad * 2.4,
      height: rad * 2.0,
    );
    c.drawRect(
      rect,
      Paint()
        ..isAntiAlias = true
        ..blendMode = lit ? BlendMode.plus : BlendMode.multiply
        ..shader = Gradient.radial(
          rect.center,
          rect.width * 0.5,
          lit
              ? [
                  tone.lighten(0.42).fade(0.30 * strength),
                  tone.lighten(0.30).fade(0.0),
                ]
              : [
                  l.ambient.mix(tone, 0.35).fade(0.55 * strength),
                  const Color(0x00FFFFFF),
                ],
          const [0.0, 1.0],
        ),
    );
  }
}

/// 잎·꽃잎을 형상 가장자리에 흩뿌린다.
///
/// [outline] 의 둘레를 따라 [count] 장을 심는다. 매끈한 윤곽을 깨뜨리는 것이
/// 목적이므로, 절반쯤은 실루엣 **바깥으로** 삐져나가야 한다.
void scatterLeaves(
  Canvas c,
  Offset center,
  double rx,
  double ry,
  Color tone,
  LightRig l, {
  required int seed,
  int count = 26,
  double size = 0.20,
  double sway = 0.0,
}) {
  final r = Rng(seed * 31 + 7);
  final paint = Paint()..isAntiAlias = true;
  for (var i = 0; i < count; i++) {
    final a = r.range(0, math.pi * 2);
    final d = 0.80 + r.range(0.0, 0.32);
    final at = center + Offset(math.cos(a) * rx * d, math.sin(a) * ry * d);
    final len = rx * size * r.range(0.6, 1.25);
    // 잎은 바깥을 향해 달린다. 중심에서 벌어지는 방향이 자연스럽다.
    final ang = a + r.signed(0.7) + sway;
    final blade = leafBlade(at, len, ang, width: r.range(0.34, 0.55));
    // 위쪽·광원 쪽 잎이 밝다. 아래로 갈수록 그늘로 잠긴다.
    final up = -math.sin(a);
    final lit = (0.5 + 0.5 * up).clamp(0.0, 1.0);
    paint.color = tone
        .lighten(0.16 * lit)
        .darken(0.26 * (1 - lit))
        .mix(l.ambient, 0.26 * (1 - lit))
        .fade(0.90);
    c.drawPath(blade, paint);
  }
}

// ---------------------------------------------------------------------------
// 접지 — 기물이 지면에 박혀 있게 만드는 것
// ---------------------------------------------------------------------------

/// 밑동을 감싸는 흙·낙엽 자락.
///
/// 줄기가 지면에서 그냥 끊기면 바닥에 꽂아 둔 막대가 된다. 밑동 둘레에 흙이
/// 조금 부풀어 있으면 그 자리에서 자란 것으로 읽힌다.
void rootSkirt(
  Canvas c,
  double radius,
  Color tone,
  LightRig l, {
  int seed = 9,
  double squash = 0.38,
  double alpha = 0.75,
}) {
  final n = Noise(seed * 43 + 5);
  final skirt = blob(
    Offset.zero,
    radius,
    radius * squash,
    points: 11,
    warp: (a, u) => 1.0 + 0.26 * n.signed1(u * 5.5 + seed),
  );
  final b = skirt.getBounds();
  c.drawPath(
    skirt,
    Paint()
      ..isAntiAlias = true
      ..shader = Gradient.radial(
        b.center,
        b.width * 0.5,
        [
          tone.darken(0.10).fade(alpha),
          tone.darken(0.05).fade(alpha * 0.6),
          tone.fade(0.0),
        ],
        const [0.0, 0.6, 1.0],
      ),
  );
  // 광원 반대쪽 자락에 그늘을 넣어 흙더미가 솟아 있음을 알린다.
  c.drawPath(
    skirt,
    Paint()
      ..isAntiAlias = true
      ..blendMode = BlendMode.multiply
      ..shader = Gradient.linear(
        Offset(l.dir.dx * radius, l.dir.dy * radius * squash),
        Offset(-l.dir.dx * radius, -l.dir.dy * radius * squash),
        [const Color(0xFFFFFFFF), l.ambient.mix(const Color(0xFF000000), 0.2)],
      ),
  );
}

// ---------------------------------------------------------------------------
// 인공물 — 반복 단위가 곧 스케일을 알려 준다
// ---------------------------------------------------------------------------

/// 조적·널판·기와처럼 **단위가 반복되는** 면 텍스처.
///
/// 벽을 단색으로 두면 크기를 알 수 없다. 돌 한 장, 널 한 장의 크기가 보여야
/// 관객이 건물의 실제 규모를 읽는다. 줄눈만 긋는 것과 달리 여기서는 단위마다
/// **명도를 흔들고 위쪽 모서리를 밝힌다** — 그래야 쌓인 것으로 보인다.
///
/// [a]→[b] 가 한 켜의 진행 방향, [up] 이 켜가 쌓이는 방향이다. 호출 전에 대상
/// 면으로 클립되어 있어야 한다.
void courseTexture(
  Canvas c,
  Offset a,
  Offset b,
  Offset up,
  Color tone,
  LightRig l, {
  required int seed,
  int courses = 6,
  int perCourse = 5,
  double stagger = 0.5,
  double mortar = 0.10,
  double bevel = 0.35,
  double variance = 0.16,
}) {
  final n = Noise(seed * 89 + 3);
  final span = b - a;
  final rise = up / courses.toDouble();
  final fill = Paint()..isAntiAlias = true;
  final edge = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeWidth = math.max(0.8, up.distance / courses * 0.10);

  for (var row = 0; row < courses; row++) {
    final off = (row.isOdd ? stagger : 0.0) / perCourse;
    final gap = mortar / perCourse;
    for (var col = -1; col <= perCourse; col++) {
      final u0 = col / perCourse + off + gap * 0.5;
      final u1 = (col + 1) / perCourse + off - gap * 0.5;
      if (u1 <= 0 || u0 >= 1) continue;
      final base = a + rise * row.toDouble();
      final p0 = base + span * u0.clamp(0.0, 1.0);
      final p1 = base + span * u1.clamp(0.0, 1.0);
      final v = n.at2(col * 1.7 + row * 0.3, row * 2.1);
      final block = Path()
        ..moveTo(p0.dx, p0.dy)
        ..lineTo(p1.dx, p1.dy)
        ..lineTo(p1.dx + rise.dx * (1 - mortar), p1.dy + rise.dy * (1 - mortar))
        ..lineTo(p0.dx + rise.dx * (1 - mortar), p0.dy + rise.dy * (1 - mortar))
        ..close();
      fill.color = (v > 0.5
              ? tone.lighten(variance * (v - 0.5) * 2)
              : tone.darken(variance * (0.5 - v) * 2))
          .fade(0.55);
      c.drawPath(block, fill);
      // 단위의 위 모서리만 밝힌다. 이 한 줄이 "쌓였다"를 만든다.
      if (bevel > 0.01) {
        edge.color = tone.lighten(0.32).fade(bevel * (0.6 + 0.4 * v));
        c.drawLine(
          p0 + rise * (1 - mortar),
          p1 + rise * (1 - mortar),
          edge,
        );
      }
    }
  }
}

/// 아이소 지면 평면에 눕는 마름모.
///
/// 건물 밑면·지붕·기단처럼 **바닥과 같은 각도로 누워야 하는** 면에 쓴다.
/// [k] 는 세워지는 기물의 `squash` 를 상쇄하는 보정 계수다.
Path isoDiamond(double hx, double hy, double u, double k, {double lift = 0}) {
  final f = Offset(u * (hx - hy), u * k * (hx + hy) - lift);
  final r = Offset(u * (hx + hy), u * k * (hx - hy) - lift);
  final bk = Offset(u * (hy - hx), -u * k * (hx + hy) - lift);
  final lf = Offset(-u * (hx + hy), u * k * (hy - hx) - lift);
  return Path()
    ..moveTo(f.dx, f.dy)
    ..lineTo(r.dx, r.dy)
    ..lineTo(bk.dx, bk.dy)
    ..lineTo(lf.dx, lf.dy)
    ..close();
}

/// 돌출부가 벽에 드리우는 그림자 띠.
///
/// 처마·차양·난간 밑에 반드시 필요하다. 지붕이 벽 위에 그냥 얹혀 있으면
/// 종이 두 장을 겹친 것으로 보이지만, 이 띠 하나로 지붕이 벽 **앞으로**
/// 튀어나온 것이 된다.
void eaveShadow(
  Canvas c,
  Path face,
  Offset from,
  Offset to, {
  double depth = 14,
  double alpha = 0.55,
  double blur = 5,
}) {
  c.save();
  c.clipPath(face);
  final band = Path()
    ..moveTo(from.dx, from.dy)
    ..lineTo(to.dx, to.dy)
    ..lineTo(to.dx, to.dy + depth)
    ..lineTo(from.dx, from.dy + depth)
    ..close();
  c.drawPath(
    band,
    Paint()
      ..isAntiAlias = true
      ..blendMode = BlendMode.multiply
      ..shader = Gradient.linear(
        from,
        Offset(from.dx, from.dy + depth),
        [
          const Color(0xFF10131E).fade(alpha),
          const Color(0xFF10131E).fade(alpha * 0.15),
        ],
      )
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur),
  );
  c.restore();
}

/// 바람 위상. 개체마다 다른 값이 나오도록 시드를 섞는다.
///
/// 숲이 한 몸처럼 흔들리는 것을 막는 유일한 수단이다. 같은 나무 안에서도
/// 덩어리마다 [phase] 를 어긋나게 준다.
double sway(double t, int seed, {double phase = 0, double speed = 1.0}) =>
    math.sin(t * speed + seed * 0.37 + phase) * 0.7 +
    math.sin(t * speed * 1.63 + seed * 0.91 + phase * 1.7) * 0.3;
