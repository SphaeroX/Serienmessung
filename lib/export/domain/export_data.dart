import '../../analysis/domain/analysis.dart';
import '../../analysis/domain/statistics.dart';
import '../../core/time_format.dart';
import '../../recording/domain/cycles.dart';
import '../../recording/domain/measurement.dart';
import '../../study/domain/study.dart';

/// Localized texts for exports (filled from AppLocalizations by the UI).
class ExportLabels {
  const ExportLabels({
    required this.study,
    required this.description,
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
  });

  final String study;
  final String description;
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
  });

  final Study study;
  final List<StepDefinition> steps;
  final List<Measurement> measurements;
  final TimeUnit unit;
  final CycleTimeMethod method;
  final String locale;
  final DateTime exportedAt;
  final ExportLabels labels;

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
