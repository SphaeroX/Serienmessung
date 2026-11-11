import '../../core/clock.dart';
import 'measurement.dart';

/// State of the recording engine.
enum EngineStatus {
  /// Nothing is being timed.
  idle,

  /// The current step is being timed.
  running,

  /// Timing is stopped; the current step stays open and continues on resume.
  paused,

  /// A special time (interruption) is running; the current step is on hold.
  special,
}

/// Serializable engine state, persisted after every change for crash safety.
class EngineSnapshot {
  const EngineSnapshot({
    required this.status,
    required this.cycle,
    required this.stepIndex,
    required this.currentStepId,
    required this.stepStartMicros,
    required this.segmentStartMicros,
    required this.accumulatedMicros,
    required this.specialStartMicros,
  });

  final EngineStatus status;
  final int cycle;
  final int stepIndex;
  final int? currentStepId;
  final int stepStartMicros;
  final int segmentStartMicros;
  final int accumulatedMicros;
  final int specialStartMicros;

  Map<String, Object?> toJson() => {
    'status': status.name,
    'cycle': cycle,
    'stepIndex': stepIndex,
    'currentStepId': currentStepId,
    'stepStartMicros': stepStartMicros,
    'segmentStartMicros': segmentStartMicros,
    'accumulatedMicros': accumulatedMicros,
    'specialStartMicros': specialStartMicros,
  };

  factory EngineSnapshot.fromJson(Map<String, Object?> j) => EngineSnapshot(
    status: EngineStatus.values.byName(j['status'] as String),
    cycle: j['cycle'] as int,
    stepIndex: j['stepIndex'] as int,
    currentStepId: j['currentStepId'] as int?,
    stepStartMicros: j['stepStartMicros'] as int,
    segmentStartMicros: j['segmentStartMicros'] as int,
    accumulatedMicros: j['accumulatedMicros'] as int,
    specialStartMicros: j['specialStartMicros'] as int,
  );
}

/// Pure timing logic for all recording modes.
///
/// * Time study: [sequence] is the ordered list of step ids. Step 1 is active
///   immediately on [start]; [next] closes the current step and activates the
///   following one; after the last step a new cycle begins.
/// * Simple mode: `sequence: [null]` – every [next] is a new lap (= cycle).
/// * Step timer: `freeOrder: true` – [next] switches to the given step id and
///   the cycle number never changes.
///
/// Every action takes an optional timestamp [at] (defaults to the clock), so
/// hardware key events can be applied with their exact press time. Actions
/// return the completed measurements; storing them is the caller's job.
class RecordingEngine {
  RecordingEngine({
    required this.clock,
    required List<int?> sequence,
    this.freeOrder = false,
    EngineSnapshot? restore,
  }) : sequence = List.unmodifiable(sequence) {
    if (restore != null) _restore(restore);
  }

  final Clock clock;
  final List<int?> sequence;
  final bool freeOrder;

  EngineStatus _status = EngineStatus.idle;
  int _cycle = 1;
  int _stepIndex = 0;
  int? _currentStepId;
  int _stepStart = 0;
  int _segmentStart = 0;
  int _accumulated = 0;
  int _specialStart = 0;

  EngineStatus get status => _status;
  int get cycle => _cycle;
  int get stepIndex => _stepIndex;
  int? get currentStepId => _currentStepId;

  /// Start of the current timing segment (the last marker in video studies).
  int get segmentStartMicros => _segmentStart;

  /// Start of the current step (end of the previous one, or the start).
  int get stepStartMicros => _stepStart;

  /// Step after the current one in a fixed sequence (null in free order).
  int? get nextStepId => freeOrder || sequence.isEmpty
      ? null
      : sequence[(_stepIndex + 1) % sequence.length];

  /// Time accumulated by the open step up to [at] (excludes pauses/specials).
  int currentStepElapsed([int? at]) {
    final now = at ?? clock.nowMicros();
    return switch (_status) {
      EngineStatus.running => _accumulated + (now - _segmentStart),
      EngineStatus.paused || EngineStatus.special => _accumulated,
      EngineStatus.idle => 0,
    };
  }

  /// Duration of the running special time (0 if none).
  int specialElapsed([int? at]) => _status == EngineStatus.special
      ? (at ?? clock.nowMicros()) - _specialStart
      : 0;

  /// Starts timing with the first step of [cycle] active.
  ///
  /// In free order mode [stepId] selects the first step.
  void start({required int cycle, int? at, int? stepId}) {
    if (_status != EngineStatus.idle || sequence.isEmpty) return;
    final now = at ?? clock.nowMicros();
    _cycle = cycle;
    final idx = freeOrder && stepId != null ? sequence.indexOf(stepId) : 0;
    _stepIndex = idx < 0 ? 0 : idx;
    _currentStepId = sequence[_stepIndex];
    _openStep(now);
    _status = EngineStatus.running;
  }

  /// Closes the current step and activates the next one.
  ///
  /// In free order mode [stepId] selects the next step.
  List<MeasurementDraft> next({int? at, int? stepId}) {
    if (_status != EngineStatus.running) return const [];
    final now = _clamp(at ?? clock.nowMicros());
    final done = _closeStep(now);
    if (freeOrder) {
      final idx = stepId == null ? -1 : sequence.indexOf(stepId);
      _stepIndex = idx >= 0 ? idx : (_stepIndex + 1) % sequence.length;
    } else {
      _stepIndex++;
      if (_stepIndex >= sequence.length) {
        _stepIndex = 0;
        _cycle++;
      }
    }
    _currentStepId = sequence[_stepIndex];
    _openStep(now);
    return [done];
  }

  /// Start/stop toggle: idle → [start] is not handled here (needs a cycle),
  /// running → paused, paused → running.
  void toggleStartStop({int? at}) {
    final now = at ?? clock.nowMicros();
    switch (_status) {
      case EngineStatus.running:
        _accumulated += _clamp(now) - _segmentStart;
        _status = EngineStatus.paused;
      case EngineStatus.paused:
        _segmentStart = now;
        _status = EngineStatus.running;
      case EngineStatus.idle:
      case EngineStatus.special:
        break;
    }
  }

  /// Begins a special time; the current step is put on hold.
  void beginSpecial({int? at}) {
    if (_status != EngineStatus.running) return;
    final now = _clamp(at ?? clock.nowMicros());
    _accumulated += now - _segmentStart;
    _specialStart = now;
    _status = EngineStatus.special;
  }

  /// Ends the special time; the interrupted step continues.
  List<MeasurementDraft> endSpecial({int? at, String note = ''}) {
    if (_status != EngineStatus.special) return const [];
    var now = at ?? clock.nowMicros();
    if (now < _specialStart) now = _specialStart;
    final draft = MeasurementDraft(
      cycle: _cycle,
      stepId: _currentStepId,
      kind: MeasurementKind.special,
      startMicros: _specialStart,
      endMicros: now,
      durationMicros: now - _specialStart,
      note: note,
    );
    _segmentStart = now;
    _status = EngineStatus.running;
    return [draft];
  }

  /// Stops recording and drops the unfinished step (it was not completed).
  /// A running special time is still returned because it is complete data.
  List<MeasurementDraft> discard({int? at}) {
    final out = endSpecial(at: at);
    _status = EngineStatus.idle;
    _accumulated = 0;
    return out;
  }

  /// Reopens the step of [m] as if it had never been closed (undo of the
  /// last marker): timing continues from its start.
  void rewindTo(MeasurementDraft m) {
    final idx = sequence.indexOf(m.stepId);
    _stepIndex = idx >= 0 ? idx : 0;
    _currentStepId = sequence.isEmpty ? null : sequence[_stepIndex];
    _cycle = m.cycle;
    _stepStart = m.startMicros;
    _segmentStart = m.startMicros;
    _accumulated = 0;
    _status = EngineStatus.running;
  }

  EngineSnapshot snapshot() => EngineSnapshot(
    status: _status,
    cycle: _cycle,
    stepIndex: _stepIndex,
    currentStepId: _currentStepId,
    stepStartMicros: _stepStart,
    segmentStartMicros: _segmentStart,
    accumulatedMicros: _accumulated,
    specialStartMicros: _specialStart,
  );

  void _restore(EngineSnapshot s) {
    _status = s.status;
    _cycle = s.cycle;
    _stepIndex = s.stepIndex.clamp(
      0,
      sequence.isEmpty ? 0 : sequence.length - 1,
    );
    _currentStepId = s.currentStepId;
    // The step may have been removed or reordered meanwhile.
    final idx = sequence.indexOf(s.currentStepId);
    if (idx >= 0) {
      _stepIndex = idx;
    } else if (sequence.isNotEmpty) {
      _currentStepId = sequence[_stepIndex];
    }
    _stepStart = s.stepStartMicros;
    _segmentStart = s.segmentStartMicros;
    _accumulated = s.accumulatedMicros;
    _specialStart = s.specialStartMicros;
  }

  void _openStep(int now) {
    _stepStart = now;
    _segmentStart = now;
    _accumulated = 0;
  }

  MeasurementDraft _closeStep(int now) {
    final duration = _accumulated + (now - _segmentStart);
    return MeasurementDraft(
      cycle: _cycle,
      stepId: _currentStepId,
      kind: MeasurementKind.normal,
      startMicros: _stepStart,
      endMicros: now,
      durationMicros: duration,
    );
  }

  /// A key press can never lie before the start of the current segment.
  int _clamp(int t) => t < _segmentStart ? _segmentStart : t;
}
