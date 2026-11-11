import 'package:flutter/foundation.dart';

import '../../core/clock.dart';
import '../../core/platform.dart';
import '../../study/data/study_repository.dart';
import '../../study/domain/study.dart';
import '../data/measurement_repository.dart';
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
    required this.clock,
    required this.feedback,
    required this.wallClock,
  });

  final int studyId;
  final StudyRepository studies;
  final MeasurementRepository measurementRepo;
  final Clock clock;
  final DeviceFeedback feedback;
  final DateTime Function() wallClock;

  Study? study;
  List<StepDefinition> steps = const [];
  List<Measurement> measurements = const [];
  RecordingSession? _session;
  bool _busy = false;

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
    final mode = study?.mode ?? StudyMode.timeStudy;
    final sequence = mode.usesSteps
        ? steps.map<int?>((s) => s.id).toList()
        : <int?>[null];
    _session = RecordingSession(
      studyId: studyId,
      engine: RecordingEngine(
        clock: clock,
        sequence: sequence,
        freeOrder: mode == StudyMode.stepTimer,
      ),
      measurements: measurementRepo,
    );
    displayCycle = mode == StudyMode.stepTimer
        ? 0
        : await measurementRepo.nextCycle(studyId);
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

  Future<void> reloadMeasurements() async {
    measurements = await measurementRepo.listForStudy(studyId);
    notifyListeners();
  }

  void _append(List<Measurement> stored) {
    if (stored.isEmpty) return;
    measurements = [...measurements, ...stored];
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
