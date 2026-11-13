import '../../core/time_format.dart';
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
}

/// Excel sheet names: at most 31 characters, none of `[]:*?/\`, unique
/// (case-insensitive). Each name is the position and the study name.
List<String> studySheetNames(List<String> studyNames, {String reserved = ''}) {
  final used = <String>{reserved.toLowerCase()};
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
