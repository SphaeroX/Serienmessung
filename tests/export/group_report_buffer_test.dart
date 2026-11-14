import 'dart:convert';

import 'package:cyclescope/analysis/domain/statistics.dart';
import 'package:cyclescope/core/time_format.dart';
import 'package:cyclescope/export/domain/export_data.dart';
import 'package:cyclescope/export/domain/group_report.dart';
import 'package:cyclescope/export/domain/group_xlsx_export.dart';
import 'package:cyclescope/export/domain/pdf_report.dart';
import 'package:cyclescope/group/domain/line_simulation.dart';
import 'package:cyclescope/group/domain/study_group.dart';
import 'package:cyclescope/recording/domain/measurement.dart';
import 'package:cyclescope/study/domain/study.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

import 'export_test.dart' show numOf;
import 'group_report_full_test.dart' show lineLabels;
import 'group_report_parallel_test.dart' show riskLabels;
import 'group_report_test.dart' show fullLabels, groupLabels;
import 'pdf_report_test.dart' show pdfLabels;

const s = 1000000;

final labels = lineLabels
    .withRisk(
      riskLabels.withSimulation(
        lostWithoutBuffers: 'Lost without buffers',
        lostWithBuffers: 'Lost with buffers',
        note: (period, minutes) => 'Simulated: $minutes min failure in $period',
      ),
    )
    .withBuffers(
      const BufferReportLabels(
        title: 'Buffers',
        before: 'Before station',
        places: 'Places',
        store: 'Store time',
        retrieve: 'Retrieve time',
      ),
    );

ExportInput machine(
  int id,
  String name,
  int seconds, {
  int bufferCapacity = 0,
  bool parallel = false,
}) => ExportInput(
  study: Study(
    id: id,
    name: name,
    description: '',
    mode: StudyMode.simple,
    createdAt: DateTime(2026),
    lastActiveAt: DateTime(2026),
    parallel: parallel,
    bufferCapacity: bufferCapacity,
    bufferStoreMicros: bufferCapacity > 0 ? 2 * s : 0,
    bufferRetrieveMicros: bufferCapacity > 0 ? 2 * s : 0,
  ),
  steps: const [],
  measurements: [
    Measurement(
      id: id,
      studyId: id,
      cycle: 1,
      stepId: null,
      kind: MeasurementKind.normal,
      startMicros: 0,
      endMicros: seconds * s,
      durationMicros: seconds * s,
    ),
  ],
  unit: TimeUnit.seconds,
  method: CycleTimeMethod.median,
  locale: 'en',
  exportedAt: DateTime(2026, 3, 20),
  labels: fullLabels,
);

GroupReportInput report({bool simulate = true}) => GroupReportInput(
  group: StudyGroup(
    id: 1,
    name: 'Buffered line',
    description: '',
    createdAt: DateTime(2026),
  ),
  entries: [machine(1, 'A', 10), machine(2, 'B', 5, bufferCapacity: 20)],
  unit: TimeUnit.seconds,
  locale: 'en',
  exportedAt: DateTime(2026, 3, 20),
  labels: groupLabels,
  exportLabels: fullLabels,
  simulationHorizonMicros: simulate ? 3600 * s : null,
  simulationFailureMicros: simulate ? 600 * s : null,
);

List<List<String?>> rows(Sheet sheet) => [
  for (final r in sheet.rows) [for (final c in r) c?.value.toString()],
];

void main() {
  test('the scenarios come from the line simulation', () {
    final scenarios = report().failureScenarios!;
    final direct = LineSimulation.fromLine(report().line).failureScenarios(
      horizonMicros: 3600 * s,
      durationMicros: 600 * s,
      startMicros: 900 * s,
    );
    expect(
      scenarios.map(
        (x) => (x.machine, x.lostWithBuffers, x.lostWithoutBuffers),
      ),
      direct.map((x) => (x.machine, x.lostWithBuffers, x.lostWithoutBuffers)),
    );
    expect(report(simulate: false).failureScenarios, isNull);
  });

  test(
    'Excel: buffers on the line sheet, simulated losses on the risk sheet',
    () {
      final book = Excel.decodeBytes(buildGroupReportXlsx(report(), labels));
      final line = rows(book.tables['Line analysis']!);
      final header = line.indexWhere((r) => r.contains('Places'));
      expect(header, greaterThan(0));
      expect(line[header + 1], contains('2'));
      expect(
        numOf(book.tables['Line analysis']!.rows[header + 1][2]!.value),
        20,
      );

      final risk = rows(book.tables['Failure risk']!);
      final head = risk.firstWhere((r) => r.contains('Lost with buffers'));
      final withCol = head.indexOf('Lost with buffers');
      final withoutCol = head.indexOf('Lost without buffers');
      final b = risk.firstWhere((r) => r.length > 1 && r[1] == 'B');
      final scenario = report().failureScenarios!.firstWhere(
        (x) => x.machine == 'B',
      );
      expect(b[withCol], '${scenario.lostWithBuffers}');
      expect(b[withoutCol], '${scenario.lostWithoutBuffers}');
      expect(
        risk.any(
          (r) => r.any((c) => c?.contains('Simulated: 10 min') ?? false),
        ),
        isTrue,
      );
    },
  );

  test('Excel: a parallel station is named like in the station table', () {
    final input = GroupReportInput(
      group: StudyGroup(
        id: 1,
        name: 'Parallel line',
        description: '',
        createdAt: DateTime(2026),
      ),
      entries: [
        machine(1, 'A', 10),
        machine(2, 'B', 5, bufferCapacity: 20),
        machine(3, 'C', 5, parallel: true),
      ],
      unit: TimeUnit.seconds,
      locale: 'en',
      exportedAt: DateTime(2026, 3, 20),
      labels: groupLabels,
      exportLabels: fullLabels,
    );
    final book = Excel.decodeBytes(buildGroupReportXlsx(input, labels));
    final line = rows(book.tables['Line analysis']!);
    final stations = line.indexWhere((r) => r.contains('Pos.'));
    final buffers = line.indexWhere((r) => r.contains('Places'));
    expect(line[stations + 2][1], 'B / C (×2)');
    expect(line[buffers + 1][1], 'B / C (×2)');
  });

  test('PDF: buffer table and simulated losses', () async {
    final bytes = await buildGroupReportPdf(
      report(),
      pdfLabels,
      labels,
      compress: false,
    );
    final text = latin1.decode(bytes);
    bool has(String words) =>
        words.split(' ').every((w) => text.contains('[($w)]TJ'));
    expect(has('Buffers'), isTrue);
    expect(has('Before station'), isTrue);
    expect(has('Lost with buffers'), isTrue);
    expect(has('Simulated: 10 min failure in 1 h'), isTrue);
  });

  test('without simulation the risk sheet has no simulated columns', () {
    final book = Excel.decodeBytes(
      buildGroupReportXlsx(report(simulate: false), labels),
    );
    final risk = rows(book.tables['Failure risk']!);
    expect(risk.any((r) => r.contains('Lost with buffers')), isFalse);
  });
}
