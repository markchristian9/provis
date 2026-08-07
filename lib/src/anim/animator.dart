import 'dart:math' as math;

import '../core/spline.dart';
import '../rig/pose.dart';
import 'clip.dart';
import 'library.dart';

/// 클립 재생기.
///
/// 네 가지 일을 한다.
///
/// 1. **크로스페이드** — 동작이 바뀔 때 이전 클립을 계속 돌리면서 새 클립과
///    섞어, 포즈가 튀지 않게 한다.
/// 2. **속도** — [speed](사람이 조작하는 배속)와 [rate](이동 속도에 맞춘 보폭
///    동기화)를 곱해 클립 시간을 진행시킨다. 둘을 나눠 둔 이유는 성격이 다르기
///    때문이다 — 슬로모션은 전환까지 느려져야 관찰이 되고, 보폭 동기화는
///    전환 시간을 건드리면 안 된다.
/// 3. **이벤트** — 클립 위에 찍힌 시점을 프레임률과 무관하게 정확히 한 번씩
///    알린다. 히트박스·사운드·이펙트가 이것으로 그림과 동기화된다.
/// 4. **AUTO 순환** — 각 클립을 정해진 시간만큼 보여 준 뒤 다음으로 넘어가,
///    손을 대지 않고도 전 동작을 훑을 수 있게 한다.
class Animator {
  Animator({List<Clip>? clips}) : clips = clips ?? Anims.all;

  final List<Clip> clips;

  Clip _current = Anims.idle;
  double _time = 0;

  Clip? _from;
  double _fromTime = 0;

  /// 전환 도중 또 전환이 걸렸을 때 **화면에 실제로 나와 있던** 포즈.
  ///
  /// 이것이 없으면 섞여 있던 결과를 버리고 나가던 클립의 원본 포즈에서
  /// 다시 시작하므로, 연타할 때마다 눈에 보이게 툭 튄다.
  Pose? _fromPose;

  double _blend = 1;
  double _blendDuration = 0.2;

  /// 전환이 시작될 때의 요동 진폭. 여기서 새 클립의 진폭으로 이어진다.
  double _fromAmp = 1.0;

  /// 원샷 클립이 끝난 뒤 다시 시작하기까지 남은 대기.
  double _restWait = 0;

  /// 히트스톱으로 얼어 있는 남은 시간(초).
  double _freeze = 0;

  bool _auto = false;
  double _autoElapsed = 0;

  /// 이번 프레임에 지나간 이벤트 이름. 매 [update] 마다 갱신된다.
  ///
  /// 리스트를 새로 만들지 않고 재사용하므로, 이벤트가 없는 대부분의 프레임에서
  /// 할당이 0 이다.
  final List<String> _fired = [];

  /// 재생 속도 배수. 동작을 뜯어보기 위해 늦추거나 빠르게 볼 수 있다.
  ///
  /// 전환(크로스페이드)에도 함께 걸린다 — 슬로모션에서 전환만 제 속도로
  /// 지나가면 정작 보려던 것을 놓친다.
  double speed = 1.0;

  /// 보폭 동기화 배속. [speed] 와 곱해져 클립 시간에만 걸린다.
  ///
  /// 이동 속도가 클립이 저작된 속도와 다를 때 [RiggedIsoActor] 가 여기에
  /// 비율을 넣는다. 전환 시간은 이 값에 영향받지 않는다 — 빨리 걷는다고
  /// 걷기→대기 전환이 짧아질 이유는 없다.
  double rate = 1.0;

  /// 미세 요동에 쓰는 전역 시계. 클립을 바꿔도 끊기지 않아야 하므로
  /// 클립 시간과 따로 흐른다.
  double clock = 0;

  Clip get current => _current;

  bool get auto => _auto;

  /// 이번 프레임에 지나간 이벤트들. 게임 로직이 이것을 읽어 판정을 낸다.
  Iterable<String> get fired => _fired;

  /// 히트스톱으로 시간이 멈춰 있는가.
  bool get frozen => _freeze > 0;

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

  /// 이름으로 클립을 찾는다. 이 재생기가 들고 있는 [clips] 를 먼저 본다 —
  /// 커스텀 클립 목록을 준 뒤 이름으로 재생하면 그쪽이 나와야 한다.
  Clip byName(String name) {
    for (final c in clips) {
      if (c.name == name) return c;
    }
    return Anims.byName(name);
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
    // 진폭은 클립을 갈아 끼우기 **전에** 읽는다 — 지금 화면에 나와 있는 값이다.
    _fromAmp = _amp;
    if (_blend < 1) {
      // 전환 도중이면 나가던 클립이 아니라 지금 화면에 있는 혼합 결과에서
      // 이어야 한다. 그러지 않으면 A→B 도중 C 를 누를 때 A 로 되돌아갔다가
      // C 로 가는 것처럼 보인다.
      _fromPose = _blended();
      _from = null;
    } else {
      _fromPose = null;
      _from = _current;
      _fromTime = _time;
    }
    _blendDuration = math.max(clip.blendIn, 1e-3);
    _blend = 0;
    _current = clip;
    _time = 0;
    _restWait = 0;
    _autoElapsed = 0;
  }

  void playByName(String name) => play(byName(name));

  /// AUTO 순환의 다음 클립으로 즉시 넘어간다.
  void next() {
    final i = clips.indexOf(_current);
    play(clips[(i + 1) % clips.length]);
  }

  /// 타격 프레임에서 시간을 잠깐 멈춘다(0.05~0.08초 권장).
  ///
  /// 이 정지가 타격감의 상당 부분을 만든다. 클립 시간·전환·요동이 전부 함께
  /// 멈추므로 그림이 한 장으로 굳고, 그 뒤 정확히 멈춘 지점에서 이어진다.
  /// 겹쳐 부르면 더 긴 쪽이 이긴다.
  void hitstop(double seconds) {
    if (seconds > _freeze) _freeze = seconds;
  }

  void update(double dt) {
    if (_fired.isNotEmpty) _fired.clear();
    if (dt <= 0) return;
    // 히치 한 번에 예비동작이 통째로 건너뛰지 않도록 자른다.
    if (dt > kMaxFrameStep) dt = kMaxFrameStep;

    if (_freeze > 0) {
      // 남은 정지가 이 프레임보다 짧으면 그만큼만 쓰고 **나머지로 진행한다**.
      // 통째로 삼키면 히트스톱 0.06초가 프레임 경계에 따라 0.05~0.08초로
      // 들쭉날쭉해져, 같은 공격의 회복 타이밍이 매번 달라진다.
      if (_freeze >= dt) {
        _freeze -= dt;
        return;
      }
      dt -= _freeze;
      _freeze = 0;
    }

    // ds: 사람이 인지하는 시간(전환·AUTO). d: 클립 위상 시간.
    final ds = dt * speed;
    final d = ds * rate;
    clock += dt;

    if (_blend < 1) {
      _blend = math.min(1, _blend + ds / _blendDuration);
      _fromTime += d;
      if (_blend >= 1) {
        // 다 섞였으면 나가던 클립을 놓아 준다. 계속 표본화하면 보이지도 않는
        // 커브를 매 프레임 푸는 셈이다.
        _from = null;
        _fromPose = null;
      }
    }

    if (_restWait > 0) {
      _restWait -= d;
      if (_restWait <= 0) _time = 0;
    } else {
      final before = _time;
      _time += d;
      if (!_current.loop && _time >= _current.duration) {
        _time = _current.duration;
        // 죽음처럼 되돌아오지 않는 동작은 마지막 포즈에서 멈춘다. 그 외
        // 원샷은 잠깐 쉬었다가 반복해, 뷰어에서 계속 관찰할 수 있게 한다.
        if (!_current.holdAtEnd) _restWait = _current.repeatDelay;
      }
      _collect(_current, before, _time);
    }

    // 루프 클립의 시간은 한 사이클 안으로 되감는다. 몇 시간을 돌려도
    // 부동소수 정밀도가 유지되고, 이벤트 시각 계산이 커지지 않는다.
    _time = _wrap(_current, _time);
    final from = _from;
    if (from != null) _fromTime = _wrap(from, _fromTime);

    if (_auto) {
      _autoElapsed += ds;
      if (_autoElapsed >= _current.autoSeconds) {
        final keepAuto = _auto;
        next();
        _auto = keepAuto;
        _autoElapsed = 0;
      }
    }
  }

  /// 루프 클립의 시간을 한 사이클 안으로 되감는다. 원샷은 그대로 둔다 —
  /// 끝났다는 사실 자체가 상태이기 때문이다.
  double _wrap(Clip c, double t) {
    final dur = c.duration;
    if (!c.loop || dur <= 0 || t < dur) return t;
    return t - dur * (t / dur).floorToDouble();
  }

  /// [from] 다음부터 [to] 까지 지나간 이벤트를 모은다.
  ///
  /// 경계는 반열림 `(from, to]` 다. 양끝을 다 포함하면 프레임 경계에 걸린
  /// 이벤트가 두 번 터지고, 다 빼면 배속이 낮을 때 영영 안 터진다.
  void _collect(Clip c, double from, double to) {
    if (c.events.isEmpty || to <= from) return;
    final dur = c.duration;
    if (dur <= 0) return;
    for (final e in c.events) {
      final at = e.at.clamp(0.0, 1.0) * dur;
      if (c.loop) {
        // from 이 속한 사이클을 기준으로 다음 발생 시각을 찾는다.
        var t = (from / dur).floorToDouble() * dur + at;
        if (t <= from) t += dur;
        if (t <= to) _fired.add(e.name);
      } else {
        // 재생 시작 직후의 t=0 이벤트는 놓치지 않는다.
        final lo = from <= 0 ? -1.0 : from;
        if (at > lo && at <= to) _fired.add(e.name);
      }
    }
  }

  Pose _sample(Clip c, double t) {
    final u = c.loop ? t / c.duration : (t / c.duration).clamp(0.0, 1.0);
    return c.sample(u);
  }

  /// 요동을 얹기 전의 혼합 포즈.
  Pose _blended() {
    final p = _sample(_current, _time);
    if (_blend >= 1) return p;
    final src = _fromPose ?? (_from == null ? null : _sample(_from!, _fromTime));
    if (src == null) return p;
    // smoothstep 으로 섞어 전환의 시작과 끝에서 속도가 0 이 되게 한다.
    return Pose.lerp(src, p, smoothstep(0, 1, _blend));
  }

  /// 이 프레임의 포즈. 전환 중이면 두 클립을 섞은 결과다.
  Pose get pose => _liven(_blended());

  /// 요동의 현재 진폭.
  ///
  /// 클립마다 목표 진폭이 다르므로(루프는 1.0, 원샷은 0.35) 전환하는 순간
  /// 값을 갈아 끼우면 어깨가 0.02 라디안쯤 툭 튄다. 전환에 얹어 이어 준다.
  double get _amp {
    // 되돌아오지 않는 동작이 끝나면 요동도 멎어야 한다. 시체가 계속 어깨를
    // 들썩이면 죽은 것으로 안 보인다.
    if (_current.holdAtEnd && _blend >= 1 && _time >= _current.duration) {
      return 0;
    }
    final target = _current.loop ? 1.0 : 0.35;
    if (_blend >= 1) return target;
    return _fromAmp + (target - _fromAmp) * smoothstep(0, 1, _blend);
  }

  /// 완전히 주기적인 커브에 저주파 요동을 얹는다. 이것이 없으면 몇 초만
  /// 봐도 루프가 눈에 띄어 살아 있다는 느낌이 사라진다.
  Pose _liven(Pose p) {
    final amp = _amp;
    if (amp <= 0) return p;
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
