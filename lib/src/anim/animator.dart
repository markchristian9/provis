import 'dart:math' as math;

import '../core/spline.dart';
import '../rig/pose.dart';
import 'clip.dart';
import 'library.dart';

/// 클립 재생기.
///
/// 두 가지 일을 한다. 하나는 클립 사이의 크로스페이드 — 버튼을 눌러 동작이
/// 바뀔 때 포즈가 튀지 않도록 이전 클립을 계속 돌리면서 새 클립과 섞는다.
/// 다른 하나는 AUTO 순환 — 각 클립을 정해진 시간만큼 보여 준 뒤 다음으로
/// 넘어가, 손을 대지 않고도 전 동작을 훑을 수 있게 한다.
class Animator {
  Animator({List<Clip>? clips}) : clips = clips ?? Anims.all;

  final List<Clip> clips;

  Clip _current = Anims.idle;
  double _time = 0;

  Clip? _from;
  double _fromTime = 0;
  double _blend = 1;
  double _blendDuration = 0.2;

  /// 원샷 클립이 끝난 뒤 다시 시작하기까지 남은 대기.
  double _restWait = 0;

  bool _auto = false;
  double _autoElapsed = 0;

  /// 재생 속도 배수. 동작을 뜯어보기 위해 늦추거나 빠르게 볼 수 있다.
  double speed = 1.0;

  /// 미세 요동에 쓰는 전역 시계. 클립을 바꿔도 끊기지 않아야 하므로
  /// 클립 시간과 따로 흐른다.
  double clock = 0;

  Clip get current => _current;

  bool get auto => _auto;

  /// 현재 클립의 진행도 0..1. UI 의 진행 바가 이 값을 읽는다.
  double get progress => _current.loop
      ? (_time / _current.duration) % 1.0
      : (_time / _current.duration).clamp(0.0, 1.0);

  /// AUTO 순환에서 다음 클립까지 남은 비율 0..1.
  double get autoProgress =>
      _auto ? (_autoElapsed / _current.autoSeconds).clamp(0.0, 1.0) : 0;

  set auto(bool v) {
    if (_auto == v) return;
    _auto = v;
    _autoElapsed = 0;
  }

  /// 클립을 재생한다. 같은 클립을 다시 요청하면 원샷은 처음부터 다시,
  /// 루프는 위상을 유지한다(버튼 연타로 걷기가 끊기지 않게).
  void play(Clip clip) {
    if (identical(clip, _current)) {
      if (!clip.loop) {
        _time = 0;
        _restWait = 0;
      }
      return;
    }
    _from = _current;
    _fromTime = _time;
    _blendDuration = math.max(clip.blendIn, 1e-3);
    _blend = 0;
    _current = clip;
    _time = 0;
    _restWait = 0;
    _autoElapsed = 0;
  }

  void playByName(String name) => play(Anims.byName(name));

  /// AUTO 순환의 다음 클립으로 즉시 넘어간다.
  void next() {
    final i = clips.indexOf(_current);
    play(clips[(i + 1) % clips.length]);
  }

  void update(double dt) {
    final d = dt * speed;
    clock += dt;

    if (_blend < 1) {
      _blend = math.min(1, _blend + dt / _blendDuration);
      _fromTime += d;
    }

    if (_restWait > 0) {
      _restWait -= d;
      if (_restWait <= 0) {
        _time = 0;
      }
    } else {
      _time += d;
      if (!_current.loop && _time >= _current.duration) {
        _time = _current.duration;
        // 죽음처럼 되돌아오지 않는 동작은 마지막 포즈에서 멈춘다. 그 외
        // 원샷은 잠깐 쉬었다가 반복해, 뷰어에서 계속 관찰할 수 있게 한다.
        if (!_current.holdAtEnd) _restWait = _current.repeatDelay;
      }
    }

    if (_auto) {
      _autoElapsed += dt;
      if (_autoElapsed >= _current.autoSeconds) {
        final keepAuto = _auto;
        next();
        _auto = keepAuto;
        _autoElapsed = 0;
      }
    }
  }

  Pose _sample(Clip c, double t) {
    final u = c.loop ? t / c.duration : (t / c.duration).clamp(0.0, 1.0);
    return c.sample(u);
  }

  /// 이 프레임의 포즈. 전환 중이면 두 클립을 섞은 결과다.
  Pose get pose {
    var p = _sample(_current, _time);
    final from = _from;
    if (from != null && _blend < 1) {
      // smoothstep 으로 섞어 전환의 시작과 끝에서 속도가 0 이 되게 한다.
      final k = smoothstep(0, 1, _blend);
      p = Pose.lerp(_sample(from, _fromTime), p, k);
    }
    return _liven(p);
  }

  /// 완전히 주기적인 커브에 저주파 요동을 얹는다. 이것이 없으면 몇 초만
  /// 봐도 루프가 눈에 띄어 살아 있다는 느낌이 사라진다.
  Pose _liven(Pose p) {
    final amp = _current.loop ? 1.0 : 0.35;
    return p.copyWith(
      head: p.head + idleJitter(clock, 0.0, 0.018 * amp),
      neck: p.neck + idleJitter(clock, 2.7, 0.012 * amp),
      spine: p.spine + idleJitter(clock, 5.3, 0.010 * amp),
      armNear: ArmPose(
        shoulder: p.armNear.shoulder + idleJitter(clock, 1.7, 0.022 * amp),
        elbow: p.armNear.elbow + idleJitter(clock, 4.1, 0.018 * amp),
        wrist: p.armNear.wrist,
      ),
      armFar: ArmPose(
        shoulder: p.armFar.shoulder + idleJitter(clock, 3.9, 0.020 * amp),
        elbow: p.armFar.elbow + idleJitter(clock, 6.2, 0.016 * amp),
        wrist: p.armFar.wrist,
      ),
    );
  }
}
