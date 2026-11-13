import '../../core/time_format.dart';
import '../../group/domain/line_analysis.dart';
import '../../group/domain/study_group.dart';
import 'export_data.dart';

/// Texts only the group report needs.
class GroupReportLabels {
  const GroupReportLabels({
    required this.title,
    required this.overview,
    required this.group,
    required this.position,
    required this.cycles,
    required this.previous,
    required this.total,
  });

  final String title;

  /// Overview section and sheet name.
  final String overview;
  final String group;
  final String position;

  /// Column with the number of (complete) cycles.
  final String cycles;

  /// Column with the real cycle time of the previous revision.
  final String previous;
  final String total;
}

/// Texts of the full group report (contents, line analysis, links).
class LineReportLabels {
  const LineReportLabels({
    required this.contents,
    required this.lineAnalysis,
    required this.station,
    required this.totalTime,
    required this.lineCycleTime,
    required this.bottleneck,
    required this.balance,
    required this.outputPerHour,
    required this.waiting,
    required this.share,
    required this.sheet,
    required this.backToContents,
    required this.studies,
    this.risk,
  });

  /// Texts of the failure risk chapter/sheet; without them it is left out.
  final RiskReportLabels? risk;

  LineReportLabels withRisk(RiskReportLabels risk) => LineReportLabels(
    contents: contents,
    lineAnalysis: lineAnalysis,
    station: station,
    totalTime: totalTime,
    lineCycleTime: lineCycleTime,
    bottleneck: bottleneck,
    balance: balance,
    outputPerHour: outputPerHour,
    waiting: waiting,
    share: share,
    sheet: sheet,
    backToContents: backToContents,
    studies: studies,
    risk: risk,
  );

  final String contents;
  final String lineAnalysis;
  final String station;
  final String totalTime;
  final String lineCycleTime;
  final String bottleneck;
  final String balance;
  final String outputPerHour;
  final String waiting;
  final String share;

  /// Overview column with the link to the study sheet.
  final String sheet;
  final String backToContents;
  final String studies;
}

/// Texts of the failure risk chapter (PDF) and sheet (Excel).
class RiskReportLabels {
  const RiskReportLabels({
    required this.title,
    required this.hint,
    required this.machine,
    required this.outputDuring,
    required this.loss,
    required this.standstill,
    required this.noLoss,
    required this.singlePoints,
  });

  final String title;
  final String hint;
  final String machine;

  /// Column: output of the line while the machine is down (per hour).
  final String outputDuring;
  final String loss;
  final String standstill;
  final String noLoss;

  /// Summary of the stations without a spare machine.
  final String Function(int count) singlePoints;
}

/// Everything a group report needs; one [ExportInput] per study in group
/// order. Independent of Flutter.
class GroupReportInput {
  const GroupReportInput({
    required this.group,
    required this.entries,
    required this.unit,
    required this.locale,
    required this.exportedAt,
    required this.labels,
    required this.exportLabels,
  });

  final StudyGroup group;
  final List<ExportInput> entries;
  final TimeUnit unit;
  final String locale;
  final DateTime exportedAt;
  final GroupReportLabels labels;

  /// Generic export texts for the overview (study, mode, real cycle time,
  /// revision ...).
  final ExportLabels exportLabels;

  /// The studies looked at as one line (stations in group order).
  LineAnalysis get line => LineAnalysis.of([
    for (final x in entries)
      LineStationInput(
        name: x.study.name,
        mode: x.study.mode,
        current: x.analysis,
        previous: x.previousAnalysis,
        parallel: x.study.parallel,
      ),
  ]);
}

/// Excel sheet names: at most 31 characters, none of `[]:*?/\`, unique
/// (case-insensitive). Each name is the position and the study name.
List<String> studySheetNames(
  List<String> studyNames, {
  String reserved = '',
  List<String> alsoReserved = const [],
}) {
  final used = <String>{
    reserved.toLowerCase(),
    for (final r in alsoReserved) r.toLowerCase(),
  };
  final result = <String>[];
  for (var i = 0; i < studyNames.length; i++) {
    final clean = '${i + 1} ${studyNames[i]}'
        .replaceAll(RegExp(r'[\[\]:*?/\\]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    var name = clean.length > 31 ? clean.substring(0, 31).trimRight() : clean;
    var n = 2;
    while (used.contains(name.toLowerCase())) {
      final suffix = ' ($n)';
      final base = clean.length + suffix.length > 31
          ? clean.substring(0, 31 - suffix.length).trimRight()
          : clean;
      name = '$base$suffix';
      n++;
    }
    used.add(name.toLowerCase());
    result.add(name);
  }
  return result;
}
