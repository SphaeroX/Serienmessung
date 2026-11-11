import 'dart:convert';

import 'package:cyclescope/analysis/domain/statistics.dart';
import 'package:cyclescope/core/time_format.dart';
import 'package:cyclescope/export/domain/export_data.dart';
import 'package:cyclescope/export/domain/pdf_report.dart';
import 'package:cyclescope/recording/domain/measurement.dart';
import 'package:cyclescope/study/domain/study.dart';
import 'package:flutter_test/flutter_test.dart';

import 'export_test.dart' show labels;

const s = 1000000;

final pdfLabels = PdfLabels(
  title: 'Time study report',
  keyFigures: 'Key figures',
  steps: 'Steps',
  cycles: 'Cycles',
  specialTimes: 'Special times',
  pageOf: (p, n) => 'Page $p of $n',
  noData: 'No times recorded.',
);

ExportInput input(int cycles) {
  var t = 0;
  var id = 0;
  final ms = <Measurement>[];
  for (var c = 1; c <= cycles; c++) {
    for (final step in [1, 2]) {
      final d = (step + c % 3) * s;
      ms.add(
        Measurement(
          id: ++id,
          studyId: 1,
          cycle: c,
          stepId: step,
          kind: MeasurementKind.normal,
          startMicros: t,
          endMicros: t + d,
          durationMicros: d,
          note: '',
        ),
      );
      t += d;
    }
  }
  if (cycles > 0) {
    ms.add(
      Measurement(
        id: ++id,
        studyId: 1,
        cycle: 1,
        stepId: 1,
        kind: MeasurementKind.special,
        startMicros: 0,
        endMicros: 2 * s,
        durationMicros: 2 * s,
        note: 'Material fehlt – Störung',
      ),
    );
  }
  return ExportInput(
    study: Study(
      id: 1,
      name: 'Line 200 Größe',
      description: 'Früh',
      mode: StudyMode.timeStudy,
      createdAt: DateTime(2026),
      lastActiveAt: DateTime(2026),
    ),
    steps: const [
      StepDefinition(id: 1, studyId: 1, position: 0, name: 'Pick'),
      StepDefinition(id: 2, studyId: 1, position: 1, name: 'Place'),
    ],
    measurements: ms,
    unit: TimeUnit.seconds,
    method: CycleTimeMethod.median,
    locale: 'en',
    exportedAt: DateTime(2026, 11, 11, 10, 30),
    labels: labels,
  );
}

void main() {
  for (final n in [0, 1, 150]) {
    test('report with $n cycles is created', () async {
      final bytes = await buildPdfReport(input(n), pdfLabels);
      expect(latin1.decode(bytes.sublist(0, 5)), '%PDF-');
      expect(bytes.length, greaterThan(800));
    });
  }

  test('report contains the study name and the real cycle time', () async {
    final bytes = await buildPdfReport(input(3), pdfLabels, compress: false);
    // Text is written word by word: `[(word)]TJ`.
    final text = latin1.decode(bytes);
    bool has(String words) =>
        words.split(' ').every((w) => text.contains('[($w)]TJ'));
    expect(has('Line 200 Größe'), isTrue);
    expect(has('Real cycle time'), isTrue);
    // Cycle totals 5, 7, 3 s → median 5 s.
    expect(has('5.00 s'), isTrue);
    expect(has('Material fehlt - Störung'), isTrue);
  });
}
