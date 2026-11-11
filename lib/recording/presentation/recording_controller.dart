import 'package:flutter/foundation.dart';

import '../../analysis/domain/statistics.dart';
import '../../core/time_format.dart';

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
  });

  final int studyId;
  final StudyRepository studies;
  final MeasurementRepository measurementRepo;
  final RunStateRepository runStates;
  final Clock clock;
  final DeviceFeedback feedback;
  final DateTime Function() wallClock;

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

  Future<void> load() async {
    study = await studies.getStudy(studyId);
    steps = await studies.getSteps(studyId);
    measurements = await measurementRepo.listForStudy(studyId);
    final savedMethod = study?.cycleTimeMethod;
    cycleTimeMethod = savedMethod == null
        ? defaultMethod
        : CycleTimeMethod.parse(savedMethod);
    final mode = study?.mode ?? StudyMode.timeStudy;
    final sequence = mode.usesSteps
        ? steps.map<int?>((s) => s.id).toList()
        : <int?>[null];
    final saved = await runStates.load(studyId);
    EngineSnapshot? restore;
    if (saved != null) {
      if (clock.nowMicros() < saved.savedClockMicros) {
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

  /// Start/stop button and volume-down key.
  Future<void> startStop({int? at}) => _run(() async {
    if (status == EngineStatus.idle) {
      await _session!.start(at: at);
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
