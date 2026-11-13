import 'package:intl/intl.dart';

import '../../analysis/domain/analysis.dart';
import '../../analysis/domain/statistics.dart';
import '../../core/time_format.dart';
import '../../recording/domain/cycles.dart';
import '../../recording/domain/measurement.dart';
import '../../revision/domain/revision.dart';
import '../../revision/domain/revision_comparison.dart';
import '../../study/domain/study.dart';

/// Localized texts for exports (filled from AppLocalizations by the UI).
class ExportLabels {
  const ExportLabels({
    required this.study,
    required this.description,
    required this.notes,
    required this.mode,
    required this.modeName,
    required this.date,
    required this.unit,
    required this.method,
    required this.methodName,
    required this.cycle,
    required this.stepNo,
    required this.step,
    required this.start,
    required this.end,
    required this.duration,
    required this.type,
    required this.note,
    required this.normal,
    required this.special,
    required this.measurementsSheet,
    required this.cyclesSheet,
    required this.analysisSheet,
    required this.total,
    required this.complete,
    required this.yes,
    required this.no,
    required this.n,
    required this.mean,
    required this.median,
    required this.min,
    required this.max,
    required this.stdDev,
    required this.cv,
    required this.realCycleTime,
    required this.realTime,
    required this.specialTotal,
    required this.share,
    required this.outliersRemoved,
    this.revision,
  });

  /// Texts for revision and last-measurement lines; without them those
  /// lines are left out.
  final RevisionLabels? revision;

  ExportLabels withRevision(RevisionLabels revision) => ExportLabels(
    study: study,
    description: description,
    notes: notes,
    mode: mode,
    modeName: modeName,
    date: date,
    unit: unit,
    method: method,
    methodName: methodName,
    cycle: cycle,
    stepNo: stepNo,
    step: step,
    start: start,
    end: end,
    duration: duration,
    type: type,
    note: note,
    normal: normal,
    special: special,
    measurementsSheet: measurementsSheet,
    cyclesSheet: cyclesSheet,
    analysisSheet: analysisSheet,
    total: total,
    complete: complete,
    yes: yes,
    no: no,
    n: n,
    mean: mean,
    median: median,
    min: min,
    max: max,
    stdDev: stdDev,
    cv: cv,
    realCycleTime: realCycleTime,
    realTime: realTime,
    specialTotal: specialTotal,
    share: share,
    outliersRemoved: outliersRemoved,
    revision: revision,
  );

  final String study;
  final String description;
  final String notes;
  final String mode;
  final String modeName;
  final String date;
  final String unit;
  final String method;
  final String methodName;
  final String cycle;
  final String stepNo;
  final String step;
  final String start;
  final String end;
  final String duration;
  final String type;
  final String note;
  final String normal;
  final String special;
  final String measurementsSheet;
  final String cyclesSheet;
  final String analysisSheet;
  final String total;
  final String complete;
  final String yes;
  final String no;
  final String n;
  final String mean;
  final String median;
  final String min;
  final String max;
  final String stdDev;
  final String cv;
  final String realCycleTime;
  final String realTime;
  final String specialTotal;
  final String share;
  final String outliersRemoved;
}

/// Texts about revisions and the time of measurement.
class RevisionLabels {
  const RevisionLabels({
    required this.revision,
    required this.lastMeasured,
    required this.deviationFrom,
    required this.then,
    required this.now,
    required this.delta,
  });

  final String revision;
  final String lastMeasured;

  /// Section title, e.g. "Deviation from revision 1".
  final String Function(int number) deviationFrom;
  final String then;
  final String now;
  final String delta;
}

/// Everything an export needs; independent of Flutter.
class ExportInput {
  const ExportInput({
    required this.study,
    required this.steps,
    required this.measurements,
    required this.unit,
    required this.method,
    required this.locale,
    required this.exportedAt,
    required this.labels,
    this.previous,
  });

  final Study study;
  final List<StepDefinition> steps;
  final List<Measurement> measurements;
  final TimeUnit unit;
  final CycleTimeMethod method;
  final String locale;
  final DateTime exportedAt;
  final ExportLabels labels;

  /// The most recently archived revision, for deviations (optional).
  final Revision? previous;

  /// Wall-clock time of the newest time; times from before timestamps
  /// existed fall back to the study's last activity. Null without times.
  DateTime? get lastMeasuredAt {
    if (measurements.isEmpty) return null;
    DateTime? last;
    for (final m in measurements) {
      final t = m.recordedAt;
      if (t != null && (last == null || t.isAfter(last))) last = t;
    }
    return last ?? study.lastActiveAt;
  }

  /// Analysis of [previous] with this export's method.
  StudyAnalysis? get previousAnalysis => previous == null
      ? null
      : StudyAnalysis.compute(
          measurements: previous!.measurements,
          steps: study.mode.usesSteps ? previous!.steps : const [],
          mode: study.mode,
          method: method,
        );

  /// Deviation of the current times from [previous]; null without one.
  RevisionComparison? get comparison => previous == null
      ? null
      : RevisionComparison.compare(
          previous: previousAnalysis!,
          current: analysis,
        );

  /// Formatted [lastMeasuredAt] for the header blocks.
  String? get lastMeasuredText => lastMeasuredAt == null
      ? null
      : DateFormat('yyyy-MM-dd HH:mm').format(lastMeasuredAt!);

  /// Times are exported relative to the first recorded start (live studies)
  /// or as video positions (video studies).
  int get timeBase => study.mode == StudyMode.video || measurements.isEmpty
      ? 0
      : measurements.map((m) => m.startMicros).reduce((a, b) => a < b ? a : b);

  StudyAnalysis get analysis => StudyAnalysis.compute(
    measurements: measurements,
    steps: study.mode.usesSteps ? steps : const [],
    mode: study.mode,
    method: method,
  );

  List<CycleGroup> get cycles => groupCycles(
    measurements,
    stepIds: study.mode.usesSteps ? steps.map((s) => s.id).toList() : const [],
  );

  StepDefinition? stepById(int? id) {
    for (final s in steps) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// Unit for numeric cells: the stopwatch format is exported as seconds.
  TimeUnit get numericUnit =>
      unit == TimeUnit.stopwatch ? TimeUnit.seconds : unit;

  /// Decimals used for numbers in [numericUnit].
  int get decimals => switch (numericUnit) {
    TimeUnit.hm => 2,
    TimeUnit.seconds || TimeUnit.stopwatch => 3,
    TimeUnit.tmu => 1,
  };

  double value(num micros) => numericUnit.fromMicros(micros.round());

  /// Name of the step column for a measurement.
  String stepName(Measurement m) => study.mode.usesSteps
      ? (stepById(m.stepId)?.name ?? '')
      : '${labels.cycle} ${m.cycle}';

  String stepNumber(Measurement m) {
    final s = stepById(m.stepId);
    return s == null ? '' : '${s.position + 1}';
  }
}
