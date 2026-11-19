import 'package:cyclescope/analysis/domain/statistics.dart';
import 'package:cyclescope/core/time_format.dart';
import 'package:cyclescope/export/domain/export_data.dart';
import 'package:cyclescope/export/domain/group_report.dart';
import 'package:cyclescope/group/domain/study_group.dart';
import 'package:cyclescope/recording/domain/measurement.dart';
import 'package:cyclescope/revision/domain/revision.dart';
import 'package:cyclescope/study/domain/study.dart';
import 'package:flutter_test/flutter_test.dart';

import 'group_report_test.dart' show fullLabels, groupLabels;

const s = 1000000;

var _time = 0;

Measurement time(int study, int? stepId, int seconds) => Measurement(
  id: ++_time,
  studyId: study,
  cycle: 1,
  stepId: stepId,
  kind: MeasurementKind.normal,
  startMicros: 0,
  endMicros: seconds * s,
  durationMicros: seconds * s,
);

/// A cell member with one lap of [seconds] (a simple study).
ExportInput member(
  int id,
  String name,
  int seconds, {
  bool loader = false,
  int parts = 1,
  int machines = 1,
}) => ExportInput(
  study: Study(
    id: id,
    name: name,
    description: '',
    mode: StudyMode.simple,
    createdAt: DateTime(2026),
    lastActiveAt: DateTime(2026),
    parallel: loader,
    cellLoader: loader,
    cellParts: parts,
    cellMachines: machines,
  ),
  steps: const [],
  measurements: [time(id, null, seconds)],
  unit: TimeUnit.seconds,
  method: CycleTimeMethod.median,
  locale: 'en',
  exportedAt: DateTime(2026, 3, 20),
  labels: fullLabels,
);

/// A loader measured as a time study: work, then waiting for the machine
/// (marked); archived revision with the same steps.
ExportInput loaderWithWaiting(int id, String name) {
  final steps = [
    StepDefinition(id: id * 10, studyId: id, position: 0, name: 'Work'),
    StepDefinition(
      id: id * 10 + 1,
      studyId: id,
      position: 1,
      name: 'Wait for machine',
      waiting: true,
    ),
  ];
  return ExportInput(
    study: Study(
      id: id,
      name: name,
      description: '',
      mode: StudyMode.timeStudy,
      createdAt: DateTime(2026),
      lastActiveAt: DateTime(2026),
      parallel: true,
      cellLoader: true,
    ),
    steps: steps,
    measurements: [time(id, id * 10, 32), time(id, id * 10 + 1, 9)],
    unit: TimeUnit.seconds,
    method: CycleTimeMethod.median,
    locale: 'en',
    exportedAt: DateTime(2026, 3, 20),
    labels: fullLabels,
    previous: Revision(
      id: 1,
      studyId: id,
      number: 1,
      closedAt: DateTime(2026),
      firstRecordedAt: null,
      lastRecordedAt: null,
      cycleTimeMethod: null,
      notes: '',
      // Archived steps carry no waiting mark of their own.
      steps: [
        StepDefinition(id: id * 10, studyId: id, position: 0, name: 'Work'),
        StepDefinition(
          id: id * 10 + 1,
          studyId: id,
          position: 1,
          name: 'Wait for machine',
        ),
      ],
      measurements: [time(id, id * 10, 36), time(id, id * 10 + 1, 20)],
    ),
  );
}

GroupReportInput report(List<ExportInput> entries) => GroupReportInput(
  group: StudyGroup(
    id: 1,
    name: 'Cell line',
    description: '',
    createdAt: DateTime(2026),
  ),
  entries: entries,
  unit: TimeUnit.seconds,
  locale: 'en',
  exportedAt: DateTime(2026, 3, 20),
  labels: groupLabels,
  exportLabels: fullLabels,
);

/// Saw, then the cell of the roadmap example, then packing.
GroupReportInput example({int machines = 3}) => report([
  member(1, 'Saw', 12),
  member(2, 'Machine', 88, machines: machines),
  member(3, 'Loader 1', 32, loader: true),
  member(4, 'Loader 2', 20, loader: true),
  member(5, 'Loader 3', 15, loader: true),
  member(6, 'Packing', 20),
]);

void main() {
  group('report data of a loader cell', () {
    test('the line is built with the cell from the study data', () {
      final line = example().line;
      expect(line.stations, hasLength(3));
      final cell = line.stations[1];
      expect(cell.isCell, isTrue);
      expect(cell.cycleTime, closeTo(32 * s, 1));
      expect(cell.cell!.resources.map((r) => (r.name, r.factor)), [
        ('Machine', 3),
        ('Loader 1', 1),
        ('Loader 2', 1),
        ('Loader 3', 1),
      ]);
    });

    test('parts per cycle come from the study', () {
      final line = report([
        member(1, 'Machine', 30, machines: 2),
        member(2, 'L1', 30, loader: true),
        member(3, 'L2', 62, loader: true, parts: 2),
      ]).line;
      expect(line.stations.single.cycleTime, closeTo(31 * s, 1));
    });

    test('waiting marks of the current steps also apply to the archived '
        'revision', () {
      final entry = loaderWithWaiting(2, 'Loader');
      expect(entry.analysis.workCycleTime, 32 * s);
      expect(entry.previousAnalysis!.realCycleTime, 56 * s);
      expect(entry.previousAnalysis!.workCycleTime, 36 * s);
      final line = report([
        ExportInput(
          study: member(1, 'Machine', 30).study,
          steps: const [],
          measurements: [time(1, null, 30)],
          unit: TimeUnit.seconds,
          method: CycleTimeMethod.median,
          locale: 'en',
          exportedAt: DateTime(2026, 3, 20),
          labels: fullLabels,
          previous: Revision(
            id: 2,
            studyId: 1,
            number: 1,
            closedAt: DateTime(2026),
            firstRecordedAt: null,
            lastRecordedAt: null,
            cycleTimeMethod: null,
            notes: '',
            steps: const [],
            measurements: [time(1, null, 30)],
          ),
        ),
        entry,
      ]).line;
      expect(line.stations.single.cycleTime, closeTo(32 * s, 1));
      expect(line.stations.single.previousCycleTime, closeTo(36 * s, 1));
    });
  });
}
