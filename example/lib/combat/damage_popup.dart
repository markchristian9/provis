import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/painting.dart' show TextPainter, TextSpan, TextStyle;
import 'package:provis/provis.dart';

/// 타격 순간 피해량이 떠오르는 숫자.
///
/// ## 왜 필요한가
///
/// 이 게임에는 이미 히트스톱·타격음·피격 모션·화면 흔들림이 있다. 전부
/// "맞았다"를 말하지만, 어느 것도 **얼마나** 맞았는지는 말하지 않는다. 콤보
/// 마지막 타가 두 칸을 깎는다는 사실이 화면 어디에도 나오지 않으면 플레이어는
/// 콤보를 이어야 할 이유를 알 수 없다 — 숫자는 장식이 아니라 규칙을 보이게
/// 하는 장치다.
///
/// ## 설계
///
/// - **시간은 초로 센다.** 프레임 수를 세면 120Hz 기기에서 숫자가 두 배로
///   빨리 사라진다. 이 저장소가 애니메이션 전반에서 지키는 규칙과 같다.
/// - **월드에 고정하지 않는다.** 뜬 자리에서 위로 올라가되 타일에 매이지
///   않으므로, 맞은 몬스터가 죽어 사라져도 숫자는 남아 제 수명을 마친다.
/// - **치명타는 다른 물건처럼 보인다.** 색·크기·궤적이 함께 달라야 곁눈으로도
///   구분된다. 숫자만 커지면 그냥 큰 숫자다.
class DamagePopup {
  DamagePopup({
    required this.tile,
    required this.amount,
    required this.color,
    this.crit = false,
    this.airborne = 0,
  })  : _drift = _driftFor(tile, amount),
        duration = crit ? 1.05 : 0.85;

  /// 튀어나온 자리(타일 좌표). 이후로는 갱신되지 않는다.
  final Offset tile;

  final int amount;

  /// 치명타(콤보 마지막 타)인가.
  final bool crit;

  final Color color;

  /// 지면에서 뜬 높이. 공중의 적을 맞혔을 때 숫자도 함께 올라간다.
  final double airborne;

  final double duration;

  /// 좌우로 빗나가는 방향. 같은 자리에서 여러 번 터져도 겹쳐 읽히지 않게
  /// 한다. 난수를 쓰면 같은 프레임을 다시 그릴 때 자리가 흔들리므로,
  /// 자리와 값에서 결정론적으로 뽑는다.
  final double _drift;

  double _elapsed = 0;

  bool get done => _elapsed >= duration;

  /// 0..1 진행도.
  double get progress => (_elapsed / duration).clamp(0.0, 1.0);

  static double _driftFor(Offset tile, int amount) {
    final h = (tile.dx * 73856093).toInt() ^
        (tile.dy * 19349663).toInt() ^
        (amount * 83492791);
    return ((h & 0xFF) / 255.0) * 2 - 1;
  }

  /// [dt] 만큼 진행시키고, 수명이 다했으면 `true`.
  bool update(double dt) {
    _elapsed += dt;
    return done;
  }

  void paint(Canvas c, IsoView iso, Offset cameraOffset, PopupFonts fonts) {
    final t = progress;
    final anchor =
        iso.project(tile.dx, tile.dy, airborne) + cameraOffset;

    // 솟아오르는 높이 — 처음에 빠르고 끝에서 느려진다(ease-out). 등속으로
    // 올리면 숫자가 풍선처럼 떠올라 타격의 순간성이 사라진다.
    final rise = (1 - math.pow(1 - t, 2.2)).toDouble() * (crit ? 74.0 : 54.0);
    // 튀어나오는 순간의 크기 오버슈트. 이 0.12초가 "터졌다"를 만든다.
    final pop = t < 0.16
        ? 0.55 + 0.65 * smoothstep(0, 0.16, t) * (1 + 0.35 * (1 - t / 0.16))
        : 1.0 + 0.06 * math.sin(t * math.pi);
    // 끝에서만 사라진다. 처음부터 흐려지면 읽기 전에 없어진다.
    final alpha = t < 0.66 ? 1.0 : 1 - smoothstep(0.66, 1.0, t);

    final painter = fonts.of(amount, crit, color);
    final at = Offset(
      anchor.dx + _drift * (crit ? 26 : 18) * t,
      anchor.dy - 34 - rise,
    );

    c.save();
    c.translate(at.dx, at.dy);
    c.scale(pop.clamp(0.4, 1.9));
    // 크리티컬은 살짝 기울여 세운다. 같은 폰트라도 각도가 다르면 다른
    // 사건으로 읽힌다.
    if (crit) c.rotate(-0.09 + 0.05 * t);

    final w = painter.width, h = painter.height;
    final origin = Offset(-w / 2, -h / 2);

    // 지면·나무 위 어디에 떠도 읽히도록 뒤에 어두운 후광을 깐다. 외곽선을
    // 긋는 것보다 싸고, 밝은 지붕 위에서도 숫자가 살아남는다.
    c.drawOval(
      Rect.fromCenter(center: Offset.zero, width: w * 1.7, height: h * 1.25),
      Paint()
        ..color = const Color(0xFF05070E).fade(0.42 * alpha)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, h * 0.34),
    );

    if (crit) {
      // 치명타에만 발광 한 겹. 10% 강조가 어디에 쓰이는지를 화면이 스스로
      // 설명하게 한다.
      c.saveLayer(
        Rect.fromCenter(center: Offset.zero, width: w * 2.4, height: h * 2.4),
        Paint()..color = white.fade(alpha),
      );
      painter.paint(c, origin);
      c.restore();
      c.drawOval(
        Rect.fromCenter(center: Offset.zero, width: w * 1.15, height: h * 0.8),
        Paint()
          ..blendMode = BlendMode.plus
          ..color = color.fade(0.30 * alpha)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, h * 0.30),
      );
    } else {
      c.saveLayer(
        Rect.fromCenter(center: Offset.zero, width: w * 2.0, height: h * 2.0),
        Paint()..color = white.fade(alpha),
      );
      painter.paint(c, origin);
      c.restore();
    }
    c.restore();
  }
}

/// 숫자 하나당 [TextPainter] 하나를 재사용한다.
///
/// 레이아웃은 비싸고 피해량은 몇 종류뿐이다. 매 프레임 새로 만들면 전투가
/// 격해질수록 UI 스레드가 문자 배치에 시간을 쓴다.
class PopupFonts {
  final Map<(int, bool, int), TextPainter> _cache = {};

  TextPainter of(int amount, bool crit, Color color) {
    final key = (amount, crit, color.toARGB32());
    final hit = _cache[key];
    if (hit != null) return hit;
    if (_cache.length > 64) _cache.clear();
    return _cache[key] = TextPainter(
      text: TextSpan(
        text: '$amount',
        style: TextStyle(
          color: crit ? color.lighten(0.42) : const Color(0xFFFFF3DC),
          fontSize: crit ? 34 : 23,
          fontWeight: FontWeight.w900,
          letterSpacing: crit ? 1.4 : 0.6,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
  }
}

/// 화면에 떠 있는 피해 숫자 전부.
class DamagePopupField {
  final List<DamagePopup> _live = [];
  final PopupFonts _fonts = PopupFonts();

  /// 화면이 숫자로 뒤덮이지 않게 한다. 넘치면 가장 오래된 것부터 버린다 —
  /// 새 타격이 옛 숫자보다 중요하다.
  static const int maxLive = 28;

  int get length => _live.length;
  bool get isEmpty => _live.isEmpty;

  void add(DamagePopup p) {
    if (_live.length >= maxLive) _live.removeAt(0);
    _live.add(p);
  }

  void clear() => _live.clear();

  void update(double dt) {
    for (var i = _live.length - 1; i >= 0; i--) {
      if (_live[i].update(dt)) _live.removeAt(i);
    }
  }

  void paint(Canvas c, IsoView iso, Offset cameraOffset) {
    for (final p in _live) {
      p.paint(c, iso, cameraOffset, _fonts);
    }
  }
}
