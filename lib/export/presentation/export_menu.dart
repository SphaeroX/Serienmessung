import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../analysis/presentation/analysis_view.dart' show methodLabel;
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../recording/presentation/recording_controller.dart';
import '../../study/domain/study.dart';
import '../../study/presentation/mode_texts.dart';
import '../domain/csv_export.dart';
import '../domain/export_data.dart';
import '../domain/xlsx_export.dart';
import '../platform/file_sharer.dart';

/// Export file formats.
enum ExportFormat { csv, xlsx }

final fileSharerProvider = Provider<FileSharer>((ref) => SystemFileSharer());

/// Directory for export files before sharing; overridden in tests.
final exportDirectoryProvider = Provider<Future<Directory> Function()>(
  (ref) => getTemporaryDirectory,
);

/// Export labels in the current language.
ExportLabels exportLabels(AppLocalizations l, Study study, String method) =>
    ExportLabels(
      study: l.exportStudy,
      description: l.exportDescription,
      mode: l.modeSection,
      modeName: study.mode.title(l),
      date: l.exportDate,
      unit: l.exportUnit,
      method: l.defaultMethod,
      methodName: method,
      cycle: study.mode == StudyMode.simple ? l.exportLap : l.exportCycle,
      stepNo: l.exportStepNo,
      step: l.exportStep,
      start: l.exportStart,
      end: l.exportEnd,
      duration: l.exportDuration,
      type: l.exportType,
      note: l.exportNote,
      normal: l.exportStepTime,
      special: l.specialTime,
      measurementsSheet: l.exportSheetTimes,
      cyclesSheet: study.mode == StudyMode.simple ? l.tabLaps : l.tabCycles,
      analysisSheet: l.tabAnalysis,
      total: l.exportTotal,
      complete: l.exportComplete,
      yes: l.exportYes,
      no: l.exportNo,
      n: 'n',
      mean: l.mean,
      median: l.median,
      min: l.minimum,
      max: l.maximum,
      stdDev: l.stdDev,
      cv: l.cv,
      realCycleTime: study.mode.usesSteps ? l.realCycleTime : l.realLapTime,
      realTime: l.exportRealTime,
      specialTotal: l.specialTimesTotal,
      share: l.exportShare,
      outliersRemoved: l.exportOutliers,
    );

/// Safe file name: study name plus date.
String exportFileName(String studyName, DateTime when, String extension) {
  final base = studyName
      .replaceAll(RegExp(r'[^\w\-äöüÄÖÜß]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  final date = DateFormat('yyyy-MM-dd').format(when);
  return '${base.isEmpty ? 'study' : base}_$date.$extension';
}

/// Share button that offers the export formats.
class ExportButton extends ConsumerWidget {
  const ExportButton({super.key, required this.controller});

  final RecordingController controller;

  Future<void> _export(
    BuildContext context,
    WidgetRef ref,
    ExportFormat format,
  ) async {
    final c = controller;
    final study = c.study;
    if (study == null) return;
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final messenger = ScaffoldMessenger.of(context);
    final now = ref.read(wallClockProvider)();
    final input = ExportInput(
      study: study,
      steps: c.steps,
      measurements: c.measurements,
      unit: c.analysisUnit,
      method: c.cycleTimeMethod,
      locale: locale,
      exportedAt: now,
      labels: exportLabels(l, study, methodLabel(l, c.cycleTimeMethod)),
    );
    try {
      final dir = await ref.read(exportDirectoryProvider)();
      final (bytes, ext, mime) = switch (format) {
        ExportFormat.csv => (utf8.encode(buildCsv(input)), 'csv', 'text/csv'),
        ExportFormat.xlsx => (
          buildXlsx(input),
          'xlsx',
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        ),
      };
      final file = File(p.join(dir.path, exportFileName(study.name, now, ext)));
      await file.writeAsBytes(bytes, flush: true);
      await ref
          .read(fileSharerProvider)
          .share(file.path, mimeType: mime, subject: study.name);
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l.exportFailed('$e'))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return IconButton(
      key: const Key('exportButton'),
      tooltip: l.export,
      icon: const Icon(Icons.ios_share),
      onPressed: controller.loaded
          ? () => showModalBottomSheet<void>(
              context: context,
              showDragHandle: true,
              builder: (sheet) => SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      key: const Key('exportCsv'),
                      leading: const Icon(Icons.table_rows_outlined),
                      title: Text(l.exportCsv),
                      subtitle: Text(l.exportCsvHint),
                      onTap: () {
                        Navigator.pop(sheet);
                        _export(context, ref, ExportFormat.csv);
                      },
                    ),
                    ListTile(
                      key: const Key('exportXlsx'),
                      leading: const Icon(Icons.grid_on),
                      title: Text(l.exportXlsx),
                      subtitle: Text(l.exportXlsxHint),
                      onTap: () {
                        Navigator.pop(sheet);
                        _export(context, ref, ExportFormat.xlsx);
                      },
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}
