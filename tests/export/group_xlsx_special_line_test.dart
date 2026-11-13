import 'package:cyclescope/core/time_format.dart';
import 'package:cyclescope/export/domain/export_data.dart';
import 'package:cyclescope/export/domain/group_report.dart';
import 'package:cyclescope/export/domain/group_xlsx_export.dart';
import 'package:cyclescope/group/domain/special_cycle.dart';
import 'package:cyclescope/group/domain/study_group.dart';
import 'package:cyclescope/study/domain/study.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

import 'export_test.dart' show numOf;
import 'group_report_full_test.dart' show formulaOf, resolve;
import 'group_report_special_test.dart' show labels, machine, report;
import 'group_report_test.dart' show fullLabels, groupLabels;

const s = 1000000;

/// Value of a station formula: every sheet reference is replaced by the
/// number in that cell, then `(ref+extra)/availability` is computed.
double valueOf(Excel book, String formula) {
  final m = RegExp(
    r"^\(?('(?:[^']|'')+'![A-Z]+\d+)(?:\+([\d.]+)\))?(?:/([\d.]+))?$",
  ).firstMatch(formula);
  expect(m, isNotNull, reason: 'unexpected formula $formula');
  final base = numOf(resolve(book, m!.group(1)!)!.value)!.toDouble();
  final extra = m.group(2) == null ? 0.0 : double.parse(m.group(2)!);
  final availability = m.group(3) == null ? 1.0 : double.parse(m.group(3)!);
  return (base + extra) / availability;
}

String stationFormula(Sheet sheet, String name) {
  final row = sheet.rows.firstWhere(
    (r) => r.length > 1 && (formulaOf(r[1]) ?? '').contains('"$name"'),
  );
  return formulaOf(row[2])!;
}

void main() {
  test('the line sheet uses the effective cycle time of a machine', () {
    final g = report();
    final book = Excel.decodeBytes(buildGroupReportXlsx(g, labels));
    final sheet = book.tables['Line analysis']!;
    // No rules: the plain reference to the study sheet.
    expect(stationFormula(sheet, 'Saw'), matches(RegExp(r"^'1 Saw'!B\d+$")));
    // 40 s + 120 s every 50 parts, stopped 300 s every 24 h.
    final press = stationFormula(sheet, 'Press');
    expect(press, contains("'2 Press'!B"));
    expect(valueOf(book, press), closeTo(g.line.lineCycleTime! / s, 0.000001));
  });

  test('the extra time per part is written in the report unit', () {
    final g = GroupReportInput(
      group: StudyGroup(
        id: 1,
        name: 'Line',
        description: '',
        createdAt: DateTime(2026),
      ),
      entries: [machine(1, 'Saw', 30), machine(2, 'Press', 40)],
      unit: TimeUnit.hm,
      locale: 'en',
      exportedAt: DateTime(2026, 3, 20),
      labels: groupLabels,
      exportLabels: fullLabels,
      specialCycles: const {
        2: [
          SpecialCycle(
            id: 1,
            studyId: 2,
            name: 'Measure part',
            kind: SpecialCycleKind.parts,
            interval: 50,
            durationMicros: 120 * s,
          ),
        ],
      },
    );
    final book = Excel.decodeBytes(buildGroupReportXlsx(g, labels));
    final press = stationFormula(book.tables['Line analysis']!, 'Press');
    // 2.4 s per part are 4 HM.
    expect(press, matches(RegExp(r"^\('2 Press'!B\d+\+4\)$")));
  });

  test('parallel machines add their effective capacities', () {
    Study parallel(Study st) => Study(
      id: st.id,
      name: st.name,
      description: st.description,
      mode: st.mode,
      createdAt: st.createdAt,
      lastActiveAt: st.lastActiveAt,
      parallel: true,
    );
    final a = machine(1, 'Mill 1', 100);
    final b = machine(2, 'Mill 2', 100);
    final g = GroupReportInput(
      group: StudyGroup(
        id: 1,
        name: 'Line',
        description: '',
        createdAt: DateTime(2026),
      ),
      entries: [
        a,
        ExportInput(
          study: parallel(b.study),
          steps: b.steps,
          measurements: b.measurements,
          unit: b.unit,
          method: b.method,
          locale: b.locale,
          exportedAt: b.exportedAt,
          labels: b.labels,
        ),
      ],
      unit: TimeUnit.seconds,
      locale: 'en',
      exportedAt: DateTime(2026, 3, 20),
      labels: groupLabels,
      exportLabels: fullLabels,
      specialCycles: const {
        2: [
          SpecialCycle(
            id: 1,
            studyId: 2,
            name: 'Measure part',
            kind: SpecialCycleKind.parts,
            interval: 10,
            durationMicros: 50 * s,
          ),
        ],
      },
    );
    final sheet = Excel.decodeBytes(buildGroupReportXlsx(g, labels))
        .tables['Line analysis']!;
    final row = sheet.rows.firstWhere(
      (r) => r.length > 1 && '${r[1]?.value}'.contains('Mill 1 / Mill 2'),
    );
    final formula = formulaOf(row[2])!;
    expect(
      formula,
      matches(
        RegExp(r"^1/\(1/'1 Mill 1'!B(\d+)\+1/\('2 Mill 2'!B(\d+)\+5\)\)$"),
      ),
    );
  });
}
