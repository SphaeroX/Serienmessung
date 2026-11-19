import 'dart:convert';

import 'package:cyclescope/analysis/domain/statistics.dart';
import 'package:cyclescope/core/time_format.dart';
import 'package:cyclescope/export/domain/export_data.dart';
import 'package:cyclescope/export/domain/group_report.dart';
import 'package:cyclescope/export/domain/group_xlsx_export.dart';
import 'package:cyclescope/export/domain/pdf_report.dart';
import 'package:cyclescope/group/domain/study_group.dart';
import 'package:cyclescope/recording/domain/measurement.dart';
import 'package:cyclescope/revision/domain/revision.dart';
import 'package:cyclescope/study/domain/study.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

import 'export_test.dart' show numOf;
import 'group_report_full_test.dart' show formulaOf, lineLabels;
import 'group_report_test.dart' show fullLabels, groupLabels;
import 'pdf_report_test.dart' show pdfLabels;

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

final labels = lineLabels.withCells(
  CellReportLabels(
    title: 'Loader cell',
    hint: 'Machines served in turn by loaders.',
    resource: 'Resource',
    perPart: 'Per part',
    utilization: 'Utilization',
    waiting: 'Waiting per cycle',
    machines: 'Machines',
    cycleTime: 'Cell cycle time',
    optionsTitle: 'Cycle time by number of machines',
    notMeasured: 'The cell needs times.',
    machineCount: (name, count) => '$name x$count',
    loaderParts: (name, count) => '$name ($count parts per cycle)',
    best: (count, loader) => 'From $count machines on: $loader',
  ),
);

/// Rows of the line sheet as texts ('' for empty cells).
List<List<String>> lineRows(GroupReportInput input) => [
  for (final r in Excel.decodeBytes(
    buildGroupReportXlsx(input, labels),
  ).tables['Line analysis']!.rows)
    [for (final c in r) c?.value?.toString() ?? ''],
];

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

  group('Excel report with a loader cell', () {
    test('the cell station carries its cell cycle time as a value', () {
      final book = Excel.decodeBytes(buildGroupReportXlsx(example(), labels));
      final line = book.tables['Line analysis']!;
      final station = line.rows.firstWhere(
        (r) => r.length > 2 && r[0]?.value.toString() == '2',
      );
      expect(station[1]!.value.toString(), 'Machine (×3)');
      expect(formulaOf(station[2]), isNull);
      expect(numOf(station[2]!.value), 32);
      // The other stations still refer to their study sheets.
      final saw = line.rows.firstWhere(
        (r) => r.length > 2 && r[0]?.value.toString() == '1',
      );
      expect(formulaOf(saw[2]), contains("'1 Saw'!B"));
    });

    test('the cell section lists resources and the machine table', () {
      final rows = lineRows(example());
      final title = rows.indexWhere(
        (r) => r.isNotEmpty && r[0] == 'Loader cell: 2. Machine',
      );
      expect(title, greaterThan(0));
      final header = rows.indexWhere(
        (r) => r.isNotEmpty && r[0] == 'Resource',
        title,
      );
      expect(rows[header].take(4), [
        'Resource',
        'Per part [s]',
        'Utilization [%]',
        'Waiting per cycle [s]',
      ]);
      expect(rows[header + 1].take(4), ['Machine x3', '29.333', '91.7', '8']);
      expect(rows[header + 2].take(4), ['Loader 1', '32', '100', '0']);
      expect(rows[header + 3].take(4), ['Loader 2', '20', '62.5', '12']);
      expect(rows[header + 4].take(4), ['Loader 3', '15', '46.9', '17']);

      final options = rows.indexWhere(
        (r) => r.isNotEmpty && r[0] == 'Machines',
        header,
      );
      expect(rows[options].take(3), [
        'Machines',
        'Cell cycle time [s]',
        'Bottleneck',
      ]);
      expect(rows[options + 1].take(3), ['1', '88', 'Machines']);
      expect(rows[options + 2].take(3), ['2', '44', 'Machines']);
      expect(rows[options + 3].take(3), ['3', '32', 'Loader 1']);
      expect(rows[options + 6].take(3), ['6', '32', 'Loader 1']);
      expect(
        rows.any((r) => r.isNotEmpty && r[0] == 'From 3 machines on: Loader 1'),
        isTrue,
      );
    });

    test('a cell without loader times is listed as not measured', () {
      final input = report([
        member(1, 'Saw', 12),
        member(2, 'Machine', 88),
        ExportInput(
          study: member(3, 'Gantry', 1, loader: true).study,
          steps: const [],
          measurements: const [],
          unit: TimeUnit.seconds,
          method: CycleTimeMethod.median,
          locale: 'en',
          exportedAt: DateTime(2026, 3, 20),
          labels: fullLabels,
        ),
      ]);
      final rows = lineRows(input);
      final station = rows.firstWhere((r) => r.length > 2 && r[0] == '2');
      expect(station[1], 'Machine');
      expect(station[2], '');
      expect(
        rows.any((r) => r.isNotEmpty && r[0] == 'The cell needs times.'),
        isTrue,
      );
      expect(rows.any((r) => r.isNotEmpty && r[0] == 'Machines'), isFalse);
    });

    test('without the cell texts the section is left out', () {
      final book = Excel.decodeBytes(
        buildGroupReportXlsx(example(), lineLabels),
      );
      final rows = book.tables['Line analysis']!.rows;
      expect(
        rows.any(
          (r) =>
              r.isNotEmpty &&
              (r[0]?.value.toString() ?? '').startsWith('Loader cell'),
        ),
        isFalse,
      );
    });
  });

  group('PDF report with a loader cell', () {
    test('the line chapter describes the cell', () async {
      final text = latin1.decode(
        await buildGroupReportPdf(
          example(),
          pdfLabels,
          labels,
          compress: false,
        ),
      );
      bool has(String words) =>
          words.split(' ').every((w) => text.contains('[($w)]TJ'));
      expect(has('Loader cell: 2. Machine'), isTrue);
      expect(has('Resource'), isTrue);
      expect(has('Utilization'), isTrue);
      expect(has('Machine x3'), isTrue);
      expect(has('Cycle time by number of machines'), isTrue);
      expect(has('From 3 machines on: Loader 1'), isTrue);
    });

    test('a cell that is not measured does not break the report', () async {
      final bytes = await buildGroupReportPdf(
        report([
          member(1, 'Machine', 88),
          ExportInput(
            study: member(2, 'Gantry', 1, loader: true).study,
            steps: const [],
            measurements: const [],
            unit: TimeUnit.seconds,
            method: CycleTimeMethod.median,
            locale: 'en',
            exportedAt: DateTime(2026, 3, 20),
            labels: fullLabels,
          ),
        ]),
        pdfLabels,
        labels,
        compress: false,
      );
      expect(latin1.decode(bytes), contains('[(needs)]TJ'));
    });
  });
}
