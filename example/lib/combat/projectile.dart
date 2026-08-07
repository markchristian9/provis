import 'dart:math' as math;
import 'dart:ui';

import 'package:provis/provis.dart';

enum CombatProjectileKind { arrow, spell }

/// 타일 좌표계에서 날아가는 화살 또는 마법 탄환.
///
/// 타격 판정은 [duration] 이 끝난 순간 [onImpact]에서 단 한 번만
/// 난다. 발사하자마자 적이 맞는 즉시 판정이 아니므로 그림과 게임 결과가
/// 같은 시간을 말한다.
class CombatProjectile {
  CombatProjectile({
    required this.kind,
    required this.start,
    required this.destination,
    required this.color,
    required this.duration,
    this.targetTile,
    this.onImpact,
    this.startHeight = 1.25,
    this.endHeight = 0.95,
  }) : assert(duration > 0);

  final CombatProjectileKind kind;
  final Offset start;
  final Offset destination;
  final Color color;
  final double duration;
  final Offset Function()? targetTile;
  final void Function()? onImpact;
  final double startHeight;
  final double endHeight;

  double _elapsed = 0;
  double _impactAge = 0;
  bool _impacted = false;

  bool get impacted => _impacted;
  double get progress => (_elapsed / duration).clamp(0.0, 1.0);

  Offset get _end => targetTile?.call() ?? destination;

  /// 완전히 사라졌으면 `true`.
  bool update(double dt) {
    if (_impacted) {
      _impactAge += dt;
      return _impactAge >= 0.28;
    }

    _elapsed += dt;
    if (_elapsed >= duration) {
      _elapsed = duration;
      _impacted = true;
      onImpact?.call();
    }
    return false;
  }

  void paint(Canvas canvas, IsoView iso, Offset cameraOffset) {
    if (_impacted) {
      _paintImpact(canvas, iso, cameraOffset);
      return;
    }
    switch (kind) {
      case CombatProjectileKind.arrow:
        _paintArrow(canvas, iso, cameraOffset);
      case CombatProjectileKind.spell:
        _paintSpell(canvas, iso, cameraOffset);
    }
  }

  double _ease(double t) => 1 - math.pow(1 - t, 1.45).toDouble();

  Offset _tileAt(double t) => Offset.lerp(start, _end, _ease(t))!;

  double _heightAt(double t) {
    final base = startHeight + (endHeight - startHeight) * t;
    final arc = kind == CombatProjectileKind.arrow ? 0.42 : 0.18;
    return base + math.sin(t * math.pi) * arc;
  }

  Offset _screenAt(double t, IsoView iso, Offset cameraOffset) {
    final tile = _tileAt(t);
    return iso.project(tile.dx, tile.dy, _heightAt(t)) + cameraOffset;
  }

  void _paintArrow(Canvas canvas, IsoView iso, Offset cameraOffset) {
    final t = progress;
    final tip = _screenAt(t, iso, cameraOffset);
    final tail = _screenAt(math.max(0, t - 0.045), iso, cameraOffset);
    final delta = tip - tail;
    final length = delta.distance;
    if (length < 0.1) return;
    final d = delta / length;
    final n = Offset(-d.dy, d.dx);
    final shaftEnd = tip - d * 19;

    canvas.drawLine(
      tip - d * 24,
      tip,
      Paint()
        ..isAntiAlias = true
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF9A6A37),
    );
    canvas.drawPath(
      Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo((tip - d * 7 + n * 3.5).dx, (tip - d * 7 + n * 3.5).dy)
        ..lineTo((tip - d * 7 - n * 3.5).dx, (tip - d * 7 - n * 3.5).dy)
        ..close(),
      Paint()..color = const Color(0xFFE5EDF4),
    );
    final feather = Path()
      ..moveTo(shaftEnd.dx, shaftEnd.dy)
      ..lineTo((shaftEnd - d * 6 + n * 3).dx, (shaftEnd - d * 6 + n * 3).dy)
      ..lineTo((shaftEnd - d * 5).dx, (shaftEnd - d * 5).dy)
      ..lineTo((shaftEnd - d * 6 - n * 3).dx, (shaftEnd - d * 6 - n * 3).dy)
      ..close();
    canvas.drawPath(feather, Paint()..color = color.withValues(alpha: 0.9));
  }

  void _paintSpell(Canvas canvas, IsoView iso, Offset cameraOffset) {
    final t = progress;
    final head = _screenAt(t, iso, cameraOffset);

    canvas.save();
    for (var i = 5; i >= 1; i--) {
      final u = math.max(0.0, t - i * 0.025);
      final p = _screenAt(u, iso, cameraOffset);
      final alpha = (1 - i / 6) * 0.28;
      canvas.drawCircle(
        p,
        3.0 + (5 - i) * 0.5,
        Paint()
          ..blendMode = BlendMode.plus
          ..color = color.withValues(alpha: alpha),
      );
    }

    final pulse = 1 + math.sin(_elapsed * 28) * 0.12;
    canvas.drawCircle(
      head,
      15 * pulse,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = Gradient.radial(
          head,
          15 * pulse,
          [
            const Color(0xFFFFFFFF),
            color.withValues(alpha: 0.86),
            color.withValues(alpha: 0),
          ],
          const [0, 0.34, 1],
        ),
    );
    canvas.drawCircle(
      head,
      8.5 * pulse,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..blendMode = BlendMode.plus
        ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.86),
    );
    canvas.restore();
  }

  void _paintImpact(Canvas canvas, IsoView iso, Offset cameraOffset) {
    final end = _end;
    final center = iso.project(end.dx, end.dy, endHeight) + cameraOffset;
    final life = (1 - _impactAge / 0.28).clamp(0.0, 1.0);
    if (kind == CombatProjectileKind.arrow) {
      for (var i = 0; i < 5; i++) {
        final a = i / 5 * math.pi * 2 + 0.35;
        final d = Offset(math.cos(a), math.sin(a));
        canvas.drawLine(
          center + d * 3,
          center + d * (5 + 10 * (1 - life)),
          Paint()
            ..strokeWidth = 1.4
            ..color = color.withValues(alpha: life * 0.8),
        );
      }
      return;
    }

    final radius = 12 + 34 * (1 - life);
    canvas.save();
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5 * life
        ..blendMode = BlendMode.plus
        ..color = color.withValues(alpha: life * 0.9),
    );
    canvas.drawCircle(
      center,
      radius * 0.58,
      Paint()
        ..blendMode = BlendMode.plus
        ..color = color.withValues(alpha: life * 0.22),
    );
    canvas.restore();
  }
}
