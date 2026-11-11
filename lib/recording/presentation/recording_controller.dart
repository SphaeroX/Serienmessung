import 'package:flutter/foundation.dart';

import '../../analysis/domain/statistics.dart';
import '../../core/time_format.dart';
import '../../video/domain/boundary.dart';

import '../../core/clock.dart';
import '../../core/platform.dart';
import '../../study/data/study_repository.dart';
import '../../study/domain/study.dart';
import '../data/measurement_repository.dart';
import '../data/run_state_repository.dart';
import '../domain/measurement.dart';
import '../domain/recording_engine.dart';
import '../domain/recording_session.dart';

/// UI-facing controller for one study's recording screen.
///
/// Wraps a [RecordingSession] and keeps the list of stored measurements so
/// widgets can render the live list. All actions persist before notifying.
class RecordingController extends ChangeNotifier {
  RecordingController({
    required this.studyId,
    required this.studies,
    required this.measurementRepo,
    required this.runStates,
    required this.clock,
    required this.feedback,
    required this.wallClock,
    this.detectReboot = true,
  });

  final int studyId;
  final StudyRepository studies;
  final MeasurementRepository measurementRepo;
  final RunStateRepository runStates;
  final Clock clock;
  final DeviceFeedback feedback;
  final DateTime Function() wallClock;

  /// False for video studies: their time base is the video position, which
  /// is legitimately smaller after reopening.
  final bool detectReboot;

  Study? study;
  List<StepDefinition> steps = const [];
  List<Measurement> measurements = const [];
  RecordingSession? _session;
  bool _busy = false;

  /// True when a saved recording could not be continued because the device
  /// was restarted (the monotonic clock was reset).
  bool interruptedByReboot = false;

  bool get loaded => _session != null;
  RecordingEngine get engine => _session!.engine;
  EngineStatus get status => loaded ? engine.status : EngineStatus.idle;

  /// Whether the study records fixed step sequences.
  bool get hasSteps => study?.mode.usesSteps ?? false;

  /// Video study still defining its steps in the first cycle.
  bool get stepsOpen => study?.stepsOpen ?? false;

  /// Name of a step created by a marker (1-based number); set from l10n.
  String Function(int number) newStepName = (n) => 'Step $n';

  StepDefinition? stepById(int? id) {
    if (id == null) return null;
    for (final s in steps) {
      if (s.id == id) return s;
    }
    return null;
  }

  StepDefinition? get currentStep {
    if (!loaded) return null;
    if (status == EngineStatus.idle) return steps.isEmpty ? null : steps.first;
    return stepById(engine.currentStepId);
  }

  StepDefinition? get nextStep {
    if (!loaded) return null;
    if (status == EngineStatus.idle) return steps.length > 1 ? steps[1] : null;
    return stepById(engine.nextStepId);
  }

  /// Index (0-based) of the current step in the definition list.
  int get currentStepIndex => loaded ? engine.stepIndex : 0;

  /// Method for the real cycle time (saved per study).
  CycleTimeMethod cycleTimeMethod = CycleTimeMethod.median;

  /// Default method for studies without their own choice (from settings).
  CycleTimeMethod defaultMethod = CycleTimeMethod.median;

  /// Secondary unit of the live displays (from the settings).
  TimeUnit displayUnit = TimeUnit.hm;

  /// Unit used in the analysis tab.
  TimeUnit analysisUnit = TimeUnit.hm;

  Future<void> setCycleTimeMethod(CycleTimeMethod m) async {
    cycleTimeMethod = m;
    notifyListeners();
    await studies.setCycleTimeMethod(studyId, m.name);
  }

  void setAnalysisUnit(TimeUnit u) {
    analysisUnit = u;
    notifyListeners();
  }

  /// Cycle shown in the overlay: the running one, or the one a start would use.
  int displayCycle = 1;

  /// Sum of all stored durations (steps and special times).
  int get storedTotal =>
      measurements.fold(0, (sum, m) => sum + m.durationMicros);

  /// Total time including the open step and running special time.
  int totalElapsed([int? at]) {
    if (!loaded) return storedTotal;
    return storedTotal +
        engine.currentStepElapsed(at) +
        engine.specialElapsed(at);
  }

  List<int?> get _sequence => (study?.mode ?? StudyMode.timeStudy).usesSteps
      ? steps.map<int?>((s) => s.id).toList()
      : <int?>[null];

  Future<void> load() async {
    study = await studies.getStudy(studyId);
    steps = await studies.getSteps(studyId);
    measurements = await measurementRepo.listForStudy(studyId);
    final savedMethod = study?.cycleTimeMethod;
    cycleTimeMethod = savedMethod == null
        ? defaultMethod
        : CycleTimeMethod.parse(savedMethod);
    final mode = study?.mode ?? StudyMode.timeStudy;
    final sequence = _sequence;
    final saved = await runStates.load(studyId);
    EngineSnapshot? restore;
    if (saved != null) {
      if (detectReboot && clock.nowMicros() < saved.savedClockMicros) {
        // Device reboot: timestamps are no longer comparable. Completed
        // measurements are already stored; the unfinished step is dropped.
        interruptedByReboot = true;
        await runStates.delete(studyId);
      } else if (saved.snapshot.status != EngineStatus.idle) {
        restore = saved.snapshot;
      }
    }
    _session = RecordingSession(
      studyId: studyId,
      engine: RecordingEngine(
        clock: clock,
        sequence: sequence,
        freeOrder: mode == StudyMode.stepTimer,
        restore: restore,
      ),
      measurements: measurementRepo,
    );
    if (restore != null) {
      displayCycle = engine.cycle;
      await feedback.setKeepScreenOn(true);
    } else {
      displayCycle = mode == StudyMode.stepTimer
          ? 0
          : await measurementRepo.nextCycle(studyId);
    }
    notifyListeners();
  }

  /// Step timer: tapping a step tile starts it, switches to it, or (when
  /// tapped again) records a new time for the same step.
  Future<void> selectStep(int stepId, {int? at}) async {
    final t = at ?? clock.nowMicros();
    switch (status) {
      case EngineStatus.idle:
        await startStop(at: t, stepId: stepId);
      case EngineStatus.paused:
        await startStop(at: t);
        await next(at: t, stepId: stepId);
      case EngineStatus.running:
        await next(at: t, stepId: stepId);
      case EngineStatus.special:
        break;
    }
  }

  /// Start/stop button and volume-down key.
  Future<void> startStop({int? at, int? stepId}) => _run(() async {
    if (status == EngineStatus.idle) {
      await _session!.start(at: at, stepId: stepId);
      displayCycle = engine.cycle;
      await feedback.setKeepScreenOn(true);
      await feedback.stepChanged();
    } else {
      _session!.toggleStartStop(at: at);
    }
    await _touch();
  });

  /// Next button and volume-up key.
  Future<void> next({int? at, int? stepId}) => _run(() async {
    if (status != EngineStatus.running) return;
    final before = engine.cycle;
    final stored = await _session!.next(at: at, stepId: stepId);
    _append(stored);
    displayCycle = engine.cycle;
    if (engine.cycle != before) {
      await feedback.cycleChanged();
    } else {
      await feedback.stepChanged();
    }
    await _touch();
  });

  Future<void> beginSpecial({int? at}) => _run(() async {
    if (status != EngineStatus.running) return;
    _session!.beginSpecial(at: at);
    await feedback.specialStarted();
  });

  Future<void> endSpecial({int? at}) => _run(() async {
    _append(await _session!.endSpecial(at: at));
    await _touch();
  });

  /// Stops recording and discards the unfinished step.
  Future<void> reset({int? at}) => _run(() async {
    _append(await _session!.discard(at: at));
    displayCycle = await measurementRepo.nextCycle(studyId);
    if (study?.mode == StudyMode.stepTimer) displayCycle = 0;
    await feedback.setKeepScreenOn(false);
  });

  Future<void> updateNote(int measurementId, String note) async {
    await measurementRepo.updateNote(measurementId, note);
    measurements = [
      for (final m in measurements)
        if (m.id == measurementId)
          Measurement(
            id: m.id,
            studyId: m.studyId,
            cycle: m.cycle,
            stepId: m.stepId,
            kind: m.kind,
            startMicros: m.startMicros,
            endMicros: m.endMicros,
            durationMicros: m.durationMicros,
            note: note,
          )
        else
          m,
    ];
    notifyListeners();
  }

  /// Position of the last marker (video studies).
  int get markerPosition => loaded ? engine.segmentStartMicros : 0;

  /// Whether a marker may be set at [at]: never before the last marker and
  /// not during a special time.
  bool canMarkAt(int at) => switch (status) {
    EngineStatus.idle => true,
    EngineStatus.running => at >= engine.segmentStartMicros,
    _ => false,
  };

  /// Video marker: the first marker starts step 1, every further marker
  /// closes the current step. Returns false if rejected.
  ///
  /// While [stepsOpen], a marker on the last defined step creates a new
  /// step instead of starting the next cycle (see [closeCycle]).
  Future<bool> mark({int? at}) async {
    final pos = at ?? clock.nowMicros();
    if (!loaded || !canMarkAt(pos)) return false;
    if (status == EngineStatus.idle) {
      if (stepsOpen && steps.isEmpty) await _appendStep();
      await startStop(at: pos);
    } else {
      if (stepsOpen && engine.stepIndex == steps.length - 1) {
        await _appendStep();
      }
      await next(at: pos);
    }
    return true;
  }

  /// Ends the first cycle of a video study with open steps: closes the
  /// current (last) step, fixes the steps as the sequence and starts the
  /// next cycle at step 1. Returns false if not possible.
  Future<bool> closeCycle({int? at}) async {
    final pos = at ?? clock.nowMicros();
    if (!loaded ||
        !stepsOpen ||
        status != EngineStatus.running ||
        !canMarkAt(pos) ||
        engine.stepIndex != steps.length - 1) {
      return false;
    }
    await next(at: pos);
    await studies.closeSteps(studyId);
    study = await studies.getStudy(studyId);
    notifyListeners();
    return true;
  }

  /// Adds a step at the end of the sequence and keeps the running state.
  Future<void> _appendStep() => _run(() async {
    await studies.addStep(studyId, newStepName(steps.length + 1));
    steps = await studies.getSteps(studyId);
    final running = engine.status != EngineStatus.idle;
    _session = RecordingSession(
      studyId: studyId,
      engine: RecordingEngine(
        clock: clock,
        sequence: _sequence,
        restore: running ? engine.snapshot() : null,
      ),
      measurements: measurementRepo,
    );
  });

  /// Reloads the step names (e.g. after renaming during a recording).
  Future<void> reloadSteps() async {
    steps = await studies.getSteps(studyId);
    notifyListeners();
  }

  /// Removes the last marker: the last step time is deleted and its step is
  /// timed again from its start. Undoing the start marker returns to idle.
  Future<void> undoLastMarker() => _run(() async {
    if (status == EngineStatus.special) return;
    final normals = measurements
        .where((m) => m.kind == MeasurementKind.normal)
        .toList();
    final last = normals.isEmpty ? null : normals.last;
    // The current step was opened by the start marker (not by closing
    // [last]) when its start differs from the end of the last step time.
    final runningOwnMarker =
        status != EngineStatus.idle &&
        (last == null || last.endMicros != engine.stepStartMicros);
    if (runningOwnMarker) {
      // Only the start marker of this run exists.
      _session!.discard();
      return;
    }
    if (last == null) return;
    await measurementRepo.deleteById(last.id);
    measurements = await measurementRepo.listForStudy(studyId);
    engine.rewindTo(last);
    displayCycle = engine.cycle;
  });

  /// Moves a video marker between two step times. Returns false if the move
  /// is not possible (a marker cannot pass its neighbours).
  Future<bool> moveMarker(Boundary b, int to) async {
    final moved = moveBoundary(b, to);
    if (moved == null) return false;
    await measurementRepo.updateTimes(moved.$1);
    await measurementRepo.updateTimes(moved.$2);
    await reloadMeasurements();
    return true;
  }

  Future<List<Measurement>> deleteCycle(int cycle) async {
    final removed = await measurementRepo.deleteCycle(studyId, cycle);
    await reloadMeasurements();
    return removed;
  }

  Future<List<Measurement>> deleteMeasurement(int id) async {
    final removed = await measurementRepo.deleteById(id);
    await reloadMeasurements();
    return removed;
  }

  Future<void> restoreMeasurements(List<Measurement> items) async {
    await measurementRepo.restore(items);
    await reloadMeasurements();
  }

  Future<void> reloadMeasurements() async {
    measurements = await measurementRepo.listForStudy(studyId);
    notifyListeners();
  }

  void _append(List<Measurement> stored) {
    if (stored.isEmpty) return;
    measurements = [...measurements, ...stored];
  }

  /// Saves the engine state after every action (crash safety).
  Future<void> _persistState() async {
    if (engine.status == EngineStatus.idle) {
      await runStates.delete(studyId);
    } else {
      await runStates.save(
        studyId,
        engine.snapshot(),
        clockMicros: clock.nowMicros(),
        now: wallClock(),
      );
    }
  }

  Future<void> _touch() => studies.touch(studyId, wallClock());

  /// Serializes actions so fast key presses are applied in order.
  Future<void> _pending = Future.value();

  Future<void> _run(Future<void> Function() action) {
    final f = _pending.then((_) async {
      if (!loaded) return;
      _busy = true;
      try {
        await action();
        await _persistState();
      } finally {
        _busy = false;
        notifyListeners();
      }
    });
    _pending = f.catchError((Object _) {});
    return f;
  }

  bool get busy => _busy;
}
