import '../../analysis/domain/statistics.dart';
import '../../core/database.dart';
import '../../group/data/group_repository.dart';
import '../../group/data/machine_service.dart';
import '../../group/data/special_cycle_repository.dart';
import '../../group/domain/special_cycle.dart';
import '../../recording/data/measurement_repository.dart';
import '../../recording/domain/measurement.dart';
import '../../revision/data/revision_repository.dart';
import '../../study/data/study_repository.dart';
import '../../study/domain/study.dart';
import '../domain/demo_texts.dart';

const _s = 1000000;
const _hour = 3600 * _s;

/// Deterministic deviations (seconds) for the measured times, so the demo
/// looks like real measurements but is the same on every load.
const _jitter = [0.0, 0.6, -0.4, 1.1, -0.8, 0.3, -0.2, 0.5, -0.6, 0.9, -0.3];

/// Adds sample data that shows every feature of the app: a small housing
/// line as a group (parallel machines, buffers, conveyors, special cycles
/// and planned stops, revisions, special times, machines with a typed
/// cycle time, a simple study with laps) and a step-timer study outside
/// the group. Existing data is left alone; every load adds a new copy.
///
/// The line (stations in order):
/// 1. Saw – typed 38 s, blade change every 8 h (10 min).
/// 2. Milling centre 1 (time study, ~115 s, measured before) and milling
///    centre 2 (typed 110 s) in parallel – the bottleneck; buffer before.
/// 3. Washer – typed 30 s; conveyor before.
/// 4. Assembly (time study, ~45 s with one outlier, measured before).
/// 5. Test benches 1–3 in parallel – typed 150 s each; buffer before.
/// 6. Packing – simple study with 15 laps (~36 s); conveyor before.
class DemoDataService {
  DemoDataService(this._db, {required this.now});

  final AppDatabase _db;

  /// Wall clock for creation dates and `recorded_at`.
  final DateTime Function() now;

  /// Loads the demo data and returns the id of the demo group.
  Future<int> load(DemoTexts t) async {
    final today = now();
    final groups = GroupRepository(_db);
    final groupId = await groups.createGroup(
      name: t.groupName,
      description: t.groupDescription,
      now: today.subtract(const Duration(days: 40)),
    );
    final machines = MachineService(
      _db,
      now: () => today.subtract(const Duration(days: 2)),
    );
    final rules = SpecialCycleRepository(_db);

    // 1. Saw.
    final saw = await machines.createMachine(
      name: t.saw,
      groupId: groupId,
      cycleMicros: 38 * _s,
    );
    await rules.add(
      saw,
      name: t.bladeChange,
      kind: SpecialCycleKind.time,
      interval: 8 * _hour,
      durationMicros: 600 * _s,
    );

    // 2. Two milling centres in parallel, a buffer before them.
    final milling = await _timeStudy(
      name: t.millingCentre(1),
      steps: t.millingSteps,
      base: const [12, 58, 31, 14],
      cycles: 12,
      previousScale: 1.08,
      special: (cycle: 5, step: 1, seconds: 25, note: t.chipJam),
      today: today,
    );
    await groups.moveToGroup(milling, groupId);
    await groups.setBuffer(
      milling,
      capacity: 30,
      storeMicros: 15 * _s,
      retrieveMicros: 12 * _s,
    );
    await rules.add(
      milling,
      name: t.measurePart,
      kind: SpecialCycleKind.parts,
      interval: 50,
      durationMicros: 120 * _s,
    );
    await rules.add(
      milling,
      name: t.toolChange,
      kind: SpecialCycleKind.time,
      interval: 24 * _hour,
      durationMicros: 300 * _s,
    );
    await machines.createMachine(
      name: t.millingCentre(2),
      groupId: groupId,
      cycleMicros: 110 * _s,
      parallel: true,
    );

    // 3. Washer, a conveyor before it.
    final washer = await machines.createMachine(
      name: t.washer,
      groupId: groupId,
      cycleMicros: 30 * _s,
    );
    await groups.setConveyor(washer, capacity: 8, transportMicros: 60 * _s);

    // 4. Manual assembly with one disturbed cycle (IQR removes it).
    final assembly = await _timeStudy(
      name: t.assembly,
      steps: t.assemblySteps,
      base: const [6.5, 9, 22, 7.5],
      cycles: 10,
      previousScale: 1.12,
      special: (cycle: 4, step: 0, seconds: 40, note: t.materialMissing),
      outlier: (cycle: 7, step: 2, seconds: 18),
      method: CycleTimeMethod.iqr,
      today: today,
    );
    await groups.moveToGroup(assembly, groupId);

    // 5. Three test benches in parallel, a buffer before them.
    for (var i = 1; i <= 3; i++) {
      final bench = await machines.createMachine(
        name: t.testBench(i),
        groupId: groupId,
        cycleMicros: 150 * _s,
        parallel: i > 1,
      );
      if (i == 1) {
        await groups.setBuffer(
          bench,
          capacity: 40,
          storeMicros: 20 * _s,
          retrieveMicros: 15 * _s,
        );
        await rules.add(
          bench,
          name: t.calibration,
          kind: SpecialCycleKind.parts,
          interval: 200,
          durationMicros: 300 * _s,
        );
      }
    }

    // 6. Packing: laps of a simple study, a conveyor before it.
    final packing = await _laps(t.packing, today);
    await groups.moveToGroup(packing, groupId);
    await groups.setConveyor(packing, capacity: 10, transportMicros: 30 * _s);

    // Outside the group: a changeover timed with the step timer.
    await _changeover(t, today);
    return groupId;
  }

  /// Time study with [cycles] measured cycles of about [base] seconds per
  /// step. With [previousScale] an older, slower measurement is archived
  /// as revision 1 first.
  Future<int> _timeStudy({
    required String name,
    required List<String> steps,
    required List<num> base,
    required int cycles,
    required DateTime today,
    double? previousScale,
    ({int cycle, int step, int seconds, String note})? special,
    ({int cycle, int step, int seconds})? outlier,
    CycleTimeMethod? method,
  }) async {
    final studies = StudyRepository(_db);
    final id = await studies.createStudy(
      name: name,
      mode: StudyMode.timeStudy,
      steps: steps,
      now: today.subtract(const Duration(days: 40)),
      cycleTimeMethod: method?.name,
    );
    final stepIds = [for (final st in await studies.getSteps(id)) st.id];
    if (previousScale != null) {
      await _cycles(
        id,
        stepIds,
        [for (final b in base) b * previousScale],
        cycles: 8,
        recordedAt: today.subtract(const Duration(days: 35)),
      );
      await RevisionRepository(_db)
          .startNewRevision(id, now: today.subtract(const Duration(days: 3)));
    }
    await _cycles(
      id,
      stepIds,
      base,
      cycles: cycles,
      recordedAt: today.subtract(const Duration(days: 2)),
      special: special,
      outlier: outlier,
    );
    return id;
  }

  Future<void> _cycles(
    int studyId,
    List<int> stepIds,
    List<num> base, {
    required int cycles,
    required DateTime recordedAt,
    ({int cycle, int step, int seconds, String note})? special,
    ({int cycle, int step, int seconds})? outlier,
  }) async {
    final times = MeasurementRepository(_db, now: () => recordedAt);
    var at = 0;
    for (var c = 1; c <= cycles; c++) {
      for (var i = 0; i < stepIds.length; i++) {
        var seconds = base[i] + _jitter[(c + i) % _jitter.length];
        if (outlier != null && outlier.cycle == c && outlier.step == i) {
          seconds += outlier.seconds;
        }
        final d = (seconds * _s).round();
        await times.insert(
          studyId,
          MeasurementDraft(
            cycle: c,
            stepId: stepIds[i],
            kind: MeasurementKind.normal,
            startMicros: at,
            endMicros: at + d,
            durationMicros: d,
          ),
        );
        at += d;
        if (special != null && special.cycle == c && special.step == i) {
          final p = special.seconds * _s;
          await times.insert(
            studyId,
            MeasurementDraft(
              cycle: c,
              stepId: stepIds[i],
              kind: MeasurementKind.special,
              startMicros: at,
              endMicros: at + p,
              durationMicros: p,
              note: special.note,
            ),
          );
          at += p;
        }
      }
    }
  }

  /// Simple study with 15 laps of about 36 s.
  Future<int> _laps(String name, DateTime today) async {
    final id = await StudyRepository(_db).createStudy(
      name: name,
      mode: StudyMode.simple,
      steps: const [],
      now: today.subtract(const Duration(days: 4)),
    );
    final times = MeasurementRepository(
      _db,
      now: () => today.subtract(const Duration(days: 1)),
    );
    var at = 0;
    for (var lap = 1; lap <= 15; lap++) {
      final d = ((36 + _jitter[lap % _jitter.length] * 2) * _s).round();
      await times.insert(
        id,
        MeasurementDraft(
          cycle: lap,
          stepId: null,
          kind: MeasurementKind.normal,
          startMicros: at,
          endMicros: at + d,
          durationMicros: d,
        ),
      );
      at += d;
    }
    return id;
  }

  /// Step-timer study: two changeovers of the milling centre.
  Future<void> _changeover(DemoTexts t, DateTime today) async {
    final studies = StudyRepository(_db);
    final id = await studies.createStudy(
      name: t.changeover,
      mode: StudyMode.stepTimer,
      steps: t.changeoverSteps,
      now: today.subtract(const Duration(days: 6)),
    );
    final stepIds = [for (final st in await studies.getSteps(id)) st.id];
    final times = MeasurementRepository(
      _db,
      now: () => today.subtract(const Duration(days: 5)),
    );
    const seconds = [
      [240, 185, 410, 300],
      [225, 170, 455, 280],
    ];
    var at = 0;
    for (final round in seconds) {
      for (var i = 0; i < stepIds.length; i++) {
        final d = round[i] * _s;
        await times.insert(
          id,
          MeasurementDraft(
            cycle: 0,
            stepId: stepIds[i],
            kind: MeasurementKind.normal,
            startMicros: at,
            endMicros: at + d,
            durationMicros: d,
          ),
        );
        at += d;
      }
    }
  }
}
