import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import 'package:path_provider/path_provider.dart';

import '../../analysis/domain/statistics.dart';
import '../../analysis/presentation/analysis_view.dart' show methodLabel;
import '../../settings/presentation/settings_controller.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../recording/presentation/recording_controller.dart';
import '../../study/domain/study.dart';
import '../../study/presentation/mode_texts.dart';
import '../domain/csv_export.dart';
import '../domain/export_data.dart';
import '../domain/group_report.dart';
import '../domain/group_xlsx_export.dart';
import '../domain/pdf_report.dart';
import '../domain/xlsx_export.dart';
import '../platform/file_sharer.dart';

/// Export file formats.
enum ExportFormat { csv, xlsx, pdf }

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
      notes: l.studyNotes,
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
      revision: revisionLabels(l),
    );

/// Revision texts of the exports in the current language.
RevisionLabels revisionLabels(AppLocalizations l) => RevisionLabels(
  revision: l.exportRevision,
  lastMeasured: l.exportLastMeasured,
  deviationFrom: l.deviationFrom,
  then: l.revisionThen,
  now: l.revisionNow,
  delta: l.revisionDelta,
);

/// Texts of the complete group report in the current language.
LineReportLabels lineReportLabels(AppLocalizations l) => LineReportLabels(
  contents: l.reportContents,
  lineAnalysis: l.lineAnalysis,
  station: l.reportStation,
  totalTime: l.lineTotalLabel,
  lineCycleTime: l.lineCycleLabel,
  bottleneck: l.lineBottleneckLabel,
  balance: l.lineBalanceLabel,
  outputPerHour: l.lineOutputLabel,
  waiting: l.reportWaiting,
  share: l.exportShare,
  sheet: l.reportSheet,
  backToContents: l.reportBackToContents,
  studies: l.reportStudies,
);

/// Texts of the failure risk chapter in the current language.
RiskReportLabels riskReportLabels(AppLocalizations l) => RiskReportLabels(
  title: l.failureRisk,
  hint: l.failureRiskHint,
  machine: l.reportMachine,
  outputDuring: l.reportOutputDuring,
  loss: l.reportLoss,
  standstill: l.standstill,
  noLoss: l.noLoss,
  singlePoints: l.singlePointsOfFailure,
);

/// Group report texts in the current language.
GroupReportLabels groupReportLabels(AppLocalizations l) => GroupReportLabels(
  title: l.groupReportTitle,
  overview: l.reportOverview,
  group: l.exportGroup,
  position: l.exportPosition,
  cycles: l.exportCycles,
  previous: l.exportPreviousRevision,
  total: l.exportTotal,
);

/// PDF report texts in the current language.
PdfLabels pdfLabels(AppLocalizations l, Study? study) => PdfLabels(
  title: l.reportTitle,
  keyFigures: l.reportKeyFigures,
  steps: l.stepsSection,
  cycles: study?.mode == StudyMode.simple ? l.tabLaps : l.tabCycles,
  specialTimes: l.specialTimesTotal,
  pageOf: l.reportPageOf,
  noData: l.reportNoData,
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
    final previous = await ref
        .read(revisionRepositoryProvider)
        .latestRevision(study.id);
    final input = ExportInput(
      study: study,
      steps: c.steps,
      measurements: c.measurements,
      unit: c.analysisUnit,
      method: c.cycleTimeMethod,
      locale: locale,
      exportedAt: now,
      labels: exportLabels(l, study, methodLabel(l, c.cycleTimeMethod)),
      previous: previous,
    );
    try {
      final dir = await ref.read(exportDirectoryProvider)();
      final (List<int> bytes, ext, mime) = switch (format) {
        ExportFormat.csv => (utf8.encode(buildCsv(input)), 'csv', 'text/csv'),
        ExportFormat.pdf => (
          await buildPdfReport(input, pdfLabels(l, study)),
          'pdf',
          'application/pdf',
        ),
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
                      key: const Key('exportPdf'),
                      leading: const Icon(Icons.picture_as_pdf_outlined),
                      title: Text(l.exportPdf),
                      subtitle: Text(l.exportPdfHint),
                      onTap: () {
                        Navigator.pop(sheet);
                        _export(context, ref, ExportFormat.pdf);
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

/// Loads everything a group report or the line analysis needs: all studies
/// of group [groupId] in group order with their latest revision, in the
/// default unit (method per study, else the default method).
Future<GroupReportInput?> loadGroupReport(
  WidgetRef ref,
  AppLocalizations l,
  String locale,
  int groupId,
) async {
  final group = await ref.read(groupRepositoryProvider).getGroup(groupId);
  if (group == null) return null;
  final settings = ref.read(settingsProvider);
  final studies = ref.read(studyRepositoryProvider);
  final times = ref.read(measurementRepositoryProvider);
  final revisions = ref.read(revisionRepositoryProvider);
  final now = ref.read(wallClockProvider)();
  final entries = <ExportInput>[];
  for (final m in await studies.listStudies(groupId: groupId)) {
    final study = m.study;
    final method = study.cycleTimeMethod == null
        ? settings.defaultMethod
        : CycleTimeMethod.parse(study.cycleTimeMethod!);
    entries.add(
      ExportInput(
        study: study,
        steps: await studies.getSteps(study.id),
        measurements: await times.listForStudy(study.id),
        unit: settings.defaultUnit,
        method: method,
        locale: locale,
        exportedAt: now,
        labels: exportLabels(l, study, methodLabel(l, method)),
        previous: await revisions.latestRevision(study.id),
      ),
    );
  }
  return GroupReportInput(
    group: group,
    entries: entries,
    unit: settings.defaultUnit,
    locale: locale,
    exportedAt: now,
    labels: groupReportLabels(l),
    exportLabels: exportLabels(
      l,
      Study(
        id: 0,
        name: group.name,
        description: group.description,
        mode: StudyMode.timeStudy,
        createdAt: now,
        lastActiveAt: now,
      ),
      '',
    ),
  );
}

/// Share button of the group screen: PDF report or Excel workbook of all
/// studies of the group in group order.
class GroupExportButton extends ConsumerWidget {
  const GroupExportButton({super.key, required this.groupId});

  final int groupId;

  Future<void> _export(
    BuildContext context,
    WidgetRef ref,
    ExportFormat format, {
    bool complete = false,
  }) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final labels = pdfLabels(l, null);
    final lineOnly = lineReportLabels(l);
    final risk = riskReportLabels(l);
    try {
      final input = await loadGroupReport(
        ref,
        l,
        Localizations.localeOf(context).languageCode,
        groupId,
      );
      if (input == null) return;
      // The failure risk chapter is added when the line has parallel
      // machines (otherwise every failure simply stops the line).
      final line = input.line.stations.any((s) => s.isParallel)
          ? lineOnly.withRisk(risk)
          : lineOnly;
      final dir = await ref.read(exportDirectoryProvider)();
      final (List<int> bytes, ext, mime) = switch (format) {
        ExportFormat.pdf => (
          complete
              ? await buildGroupReportPdf(input, labels, line)
              : await buildGroupPdf(input, labels),
          'pdf',
          'application/pdf',
        ),
        _ => (
          complete ? buildGroupReportXlsx(input, line) : buildGroupXlsx(input),
          'xlsx',
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        ),
      };
      final file = File(
        p.join(
          dir.path,
          exportFileName(input.group.name, input.exportedAt, ext),
        ),
      );
      await file.writeAsBytes(bytes, flush: true);
      await ref
          .read(fileSharerProvider)
          .share(file.path, mimeType: mime, subject: input.group.name);
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l.exportFailed('$e'))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return IconButton(
      key: const Key('groupExportButton'),
      tooltip: l.exportGroupReport,
      icon: const Icon(Icons.ios_share),
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (sheet) => SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  key: const Key('groupReportPdf'),
                  leading: const Icon(Icons.picture_as_pdf),
                  title: Text(l.groupFullPdf),
                  subtitle: Text(l.groupFullPdfHint),
                  onTap: () {
                    Navigator.pop(sheet);
                    _export(context, ref, ExportFormat.pdf, complete: true);
                  },
                ),
                ListTile(
                  key: const Key('groupReportXlsx'),
                  leading: const Icon(Icons.table_chart),
                  title: Text(l.groupFullXlsx),
                  subtitle: Text(l.groupFullXlsxHint),
                  onTap: () {
                    Navigator.pop(sheet);
                    _export(context, ref, ExportFormat.xlsx, complete: true);
                  },
                ),
                const Divider(),
                ListTile(
                  key: const Key('groupExportPdf'),
                  leading: const Icon(Icons.picture_as_pdf_outlined),
                  title: Text(l.groupCompactPdf),
                  subtitle: Text(l.groupPdfHint),
                  onTap: () {
                    Navigator.pop(sheet);
                    _export(context, ref, ExportFormat.pdf);
                  },
                ),
                ListTile(
                  key: const Key('groupExportXlsx'),
                  leading: const Icon(Icons.grid_on),
                  title: Text(l.groupCompactXlsx),
                  subtitle: Text(l.groupXlsxHint),
                  onTap: () {
                    Navigator.pop(sheet);
                    _export(context, ref, ExportFormat.xlsx);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
