import '../data/measurement_repository.dart';
import 'measurement.dart';
import 'recording_engine.dart';

/// Couples a [RecordingEngine] with persistence: every completed measurement
/// is stored before the call returns.
class RecordingSession {
  RecordingSession({
    required this.studyId,
    required this.engine,
    required this.measurements,
  });

  final int studyId;
  final RecordingEngine engine;
  final MeasurementRepository measurements;

  /// Starts a new run. Time studies continue after the last stored cycle;
  /// step-timer studies always use cycle 0.
  Future<void> start({int? at, int? stepId}) async {
    final cycle = engine.freeOrder ? 0 : await measurements.nextCycle(studyId);
    engine.start(cycle: cycle, at: at, stepId: stepId);
  }

  Future<List<Measurement>> next({int? at, int? stepId}) =>
      _store(engine.next(at: at, stepId: stepId));

  Future<List<Measurement>> endCycle({int? at}) =>
      _store(engine.endCycle(at: at));

  void toggleStartStop({int? at}) => engine.toggleStartStop(at: at);

  void beginSpecial({int? at}) => engine.beginSpecial(at: at);

  Future<List<Measurement>> endSpecial({int? at}) =>
      _store(engine.endSpecial(at: at));

  Future<List<Measurement>> discard({int? at}) =>
      _store(engine.discard(at: at));

  Future<List<Measurement>> _store(List<MeasurementDraft> drafts) async {
    final stored = <Measurement>[];
    for (final d in drafts) {
      final id = await measurements.insert(studyId, d);
      stored.add(
        Measurement(
          id: id,
          studyId: studyId,
          cycle: d.cycle,
          stepId: d.stepId,
          kind: d.kind,
          startMicros: d.startMicros,
          endMicros: d.endMicros,
          durationMicros: d.durationMicros,
          note: d.note,
        ),
      );
    }
    return stored;
  }
}
