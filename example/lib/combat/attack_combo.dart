/// 영웅의 3단 공격 콤보.
///
/// 공격 중 입력은 다음 단계 하나를 예약한다. 애니메이션이 끝난 뒤
/// [takeQueued] 가 그 입력을 소비하고, 게임이 `begin(chained: true)`
/// 로 다음 타격을 시작한다. 프레임 수를 세지 않으므로 어떤 주사율에서도
/// 같은 입력 규칙을 유지한다.
class AttackCombo {
  AttackCombo({this.maxSteps = 3, this.holdSeconds = 0.8})
    : assert(maxSteps > 1),
      assert(holdSeconds > 0);

  final int maxSteps;

  /// 공격이 끝난 뒤에도 콤보 표시를 남겨 두는 시간.
  final double holdSeconds;

  int _step = 0;
  bool _queued = false;
  double _visibleFor = 0;

  int get step => _step;
  bool get queued => _queued;
  bool get visible => _step > 0 && _visibleFor > 0;

  /// 마지막 단계는 두 칸을 깎는다.
  int get damage => _step == maxSteps ? 2 : 1;

  /// 뒤의 타격일수록 조금씩 빨라져 연결감을 만든다.
  double get attackRate => 1.0 + (_step - 1).clamp(0, maxSteps - 1) * 0.1;

  void begin({required bool chained}) {
    if (chained && _step > 0 && _step < maxSteps) {
      _step++;
    } else {
      _step = 1;
    }
    _queued = false;
    _visibleFor = holdSeconds;
  }

  /// 현재 공격 뒤에 다음 단계를 연결한다.
  ///
  /// 동일한 동작 중 여러 번 눌러도 예약은 하나만 유지한다.
  bool queue() {
    if (_step <= 0 || _step >= maxSteps) return false;
    _queued = true;
    _visibleFor = holdSeconds;
    return true;
  }

  bool takeQueued() {
    if (!_queued) return false;
    _queued = false;
    return true;
  }

  void update(double dt, {required bool attacking}) {
    if (_step <= 0) return;
    if (attacking || _queued) {
      _visibleFor = holdSeconds;
      return;
    }
    _visibleFor -= dt;
    if (_visibleFor <= 0) reset();
  }

  void reset() {
    _step = 0;
    _queued = false;
    _visibleFor = 0;
  }
}
