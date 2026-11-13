import 'package:intl/intl.dart';

import '../../core/time_format.dart';
import '../../recording/domain/measurement.dart';
import 'export_data.dart';

/// Builds a CSV file (one row per measurement) with a short header block.
///
/// German exports use `;` and a decimal comma (what German Excel expects),
/// English exports `,` and a decimal point. The text starts with a UTF-8
/// byte order mark so Excel detects umlauts correctly.
String buildCsv(ExportInput x) {
  final german = x.locale.startsWith('de');
  final sep = german ? ';' : ',';
  final l = x.labels;
  final rows = <List<String>>[];
  String num(double v, [int? d]) =>
      formatNumber(v, d ?? x.decimals, locale: x.locale);
  final unitLabel = x.numericUnit.label;

  rows.add([l.study, x.study.name]);
  if (x.study.description.isNotEmpty) {
    rows.add([l.description, x.study.description]);
  }
  if (x.study.notes.isNotEmpty) rows.add([l.notes, x.study.notes]);
  rows.add([l.mode, l.modeName]);
  final r = l.revision;
  if (r != null) {
    rows.add([r.revision, '${x.study.revision}']);
    if (x.lastMeasuredText != null) {
      rows.add([r.lastMeasured, x.lastMeasuredText!]);
    }
  }
  rows.add([l.date, DateFormat('yyyy-MM-dd HH:mm').format(x.exportedAt)]);
  rows.add([l.unit, unitLabel]);
  rows.add([l.method, l.methodName]);
  rows.add([]);
  rows.add([
    l.cycle,
    l.stepNo,
    l.step,
    '${l.start} [$unitLabel]',
    '${l.end} [$unitLabel]',
    '${l.duration} [$unitLabel]',
    if (x.unit == TimeUnit.stopwatch) '${l.duration} [mm:ss.SSS]',
    l.type,
    l.note,
  ]);
  final base = x.timeBase;
  for (final m in x.measurements) {
    final special = m.kind == MeasurementKind.special;
    rows.add([
      '${m.cycle}',
      x.stepNumber(m),
      x.stepName(m),
      num(x.value(m.startMicros - base)),
      num(x.value(m.endMicros - base)),
      num(x.value(m.durationMicros)),
      if (x.unit == TimeUnit.stopwatch)
        formatTime(m.durationMicros, TimeUnit.stopwatch),
      special ? l.special : l.normal,
      m.note,
    ]);
  }
  return '﻿${rows.map((r) => r.map((f) => _escape(f, sep)).join(sep)).join('\r\n')}\r\n';
}

String _escape(String field, String sep) {
  if (field.contains(sep) ||
      field.contains('"') ||
      field.contains('\n') ||
      field.contains('\r')) {
    return '"${field.replaceAll('"', '""')}"';
  }
  return field;
}
