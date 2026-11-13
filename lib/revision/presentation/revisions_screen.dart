import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../analysis/domain/analysis.dart';
import '../../analysis/domain/statistics.dart';
import '../../core/providers.dart';
import '../../core/time_format.dart';
import '../../l10n/app_localizations.dart';
import '../../recording/domain/measurement.dart';
import '../../study/domain/study.dart';
import '../domain/revision.dart';
import '../domain/revision_comparison.dart';

/// Revisions of one study: the current measurement, starting a new one and
/// the deviations of every archived revision to the current times.
///
/// Pops with the new revision number after a new measurement was started.
class RevisionsScreen extends ConsumerStatefulWidget {
  const RevisionsScreen({
    super.key,
    required this.studyId,
    required this.unit,
    required this.method,
    this.canStartNew = true,
  });

  final int studyId;
  final TimeUnit unit;
  final CycleTimeMethod method;

  /// False while a recording is running.
  final bool canStartNew;

  @override
  ConsumerState<RevisionsScreen> createState() => _RevisionsScreenState();
}

class _RevisionsScreenState extends ConsumerState<RevisionsScreen> {
  Study? _study;
  StudyAnalysis? _current;
  bool _hasTimes = false;
  DateTime? _lastMeasured;
  List<Revision> _revisions = const [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  StudyAnalysis _analyse(
    Study study,
    List<StepDefinition> steps,
    List<Measurement> times,
  ) => StudyAnalysis.compute(
    measurements: times,
    steps: study.mode.usesSteps ? steps : const [],
    mode: study.mode,
    method: widget.method,
  );

  Future<void> _load() async {
    final studies = ref.read(studyRepositoryProvider);
    final revisions = ref.read(revisionRepositoryProvider);
    final study = await studies.getStudy(widget.studyId);
    final steps = await studies.getSteps(widget.studyId);
    final times = await ref
        .read(measurementRepositoryProvider)
        .listForStudy(widget.studyId);
    final list = await revisions.listRevisions(widget.studyId);
    final last = await revisions.lastRecordedAt(widget.studyId);
    if (!mounted || study == null) return;
    setState(() {
      _study = study;
      _current = _analyse(study, steps, times);
      _hasTimes = times.isNotEmpty;
      _lastMeasured = last;
      _revisions = list;
      _loaded = true;
    });
  }

  Future<void> _startNew() async {
    final l = AppLocalizations.of(context);
    final study = _study!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.newRevision),
        content: Text(l.newRevisionConfirm(study.revision)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            key: const Key('confirmNewRevision'),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.newRevision),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final number = await ref
        .read(revisionRepositoryProvider)
        .startNewRevision(study.id, now: ref.read(wallClockProvider)());
    ref.invalidate(studyListProvider);
    if (mounted) Navigator.of(context).pop(number);
  }

  Future<void> _delete(Revision r) async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.deleteRevision),
        content: Text(l.deleteRevisionConfirm(r.number)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          TextButton(
            key: const Key('confirmDeleteRevision'),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(revisionRepositoryProvider).deleteRevision(r.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final dateTime = DateFormat.yMd(locale).add_Hm();
    final date = DateFormat.yMd(locale);
    String t(num micros) =>
        formatTime(micros.round(), widget.unit, locale: locale);
    final study = _study;
    final current = _current;
    final hasCycles = study != null && study.mode != StudyMode.stepTimer;
    final cycleLabel = study?.mode.usesSteps ?? true
        ? l.realCycleTime
        : l.realLapTime;
    return Scaffold(
      appBar: AppBar(title: Text(l.revisions)),
      body: !_loaded || study == null || current == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
              children: [
                Card(
                  key: const Key('currentRevision'),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.revisionCurrent(study.revision),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _lastMeasured == null
                              ? l.revisionNoTimes
                              : l.lastMeasured(dateTime.format(_lastMeasured!)),
                        ),
                        if (hasCycles && current.cycleStats.n > 0)
                          Text('$cycleLabel: ${t(current.realCycleTime)}'),
                        const SizedBox(height: 12),
                        Text(
                          l.newRevisionHint,
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          key: const Key('newRevisionButton'),
                          onPressed: widget.canStartNew && _hasTimes
                              ? _startNew
                              : null,
                          icon: const Icon(Icons.replay),
                          label: Text(l.newRevision),
                        ),
                        if (!widget.canStartNew)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              l.stopRecordingFirst,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.error,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (_revisions.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(l.noRevisions, textAlign: TextAlign.center),
                  ),
                for (final r in _revisions)
                  _RevisionCard(
                    revision: r,
                    comparison: RevisionComparison.compare(
                      previous: _analyse(study, r.steps, r.measurements),
                      current: current,
                    ),
                    hasCycles: hasCycles,
                    cycleLabel: cycleLabel,
                    unit: widget.unit,
                    locale: locale,
                    date: date,
                    onDelete: () => _delete(r),
                  ),
              ],
            ),
    );
  }
}

class _RevisionCard extends StatelessWidget {
  const _RevisionCard({
    required this.revision,
    required this.comparison,
    required this.hasCycles,
    required this.cycleLabel,
    required this.unit,
    required this.locale,
    required this.date,
    required this.onDelete,
  });

  final Revision revision;
  final RevisionComparison comparison;
  final bool hasCycles;
  final String cycleLabel;
  final TimeUnit unit;
  final String locale;
  final DateFormat date;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    // One decimal more than the live displays: deviations are often small.
    final decimals = switch (unit) {
      TimeUnit.hm => 1,
      TimeUnit.seconds => 2,
      _ => 0,
    };
    String t(double? micros) => micros == null
        ? '–'
        : formatTime(micros.round(), unit, decimals: decimals, locale: locale);
    String d(double? micros) => micros == null
        ? '–'
        : formatDelta(micros, unit, decimals: decimals, locale: locale);
    Color? color(double? delta) => delta == null || delta.round() == 0
        ? null
        : delta > 0
        ? theme.colorScheme.error
        : Colors.green.shade700;
    final from = revision.firstRecordedAt ?? revision.lastRecordedAt;
    final to = revision.lastRecordedAt;
    final cycleDelta = comparison.cycleDelta;
    final small = theme.textTheme.bodySmall;
    final bold = small?.copyWith(fontWeight: FontWeight.bold);

    TableRow row(
      String name,
      double? then,
      double? now,
      double? delta, {
      TextStyle? style,
    }) => TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(name, style: style ?? small),
        ),
        Text(t(then), style: style ?? small, textAlign: TextAlign.end),
        Text(t(now), style: style ?? small, textAlign: TextAlign.end),
        Text(
          d(delta),
          style: (style ?? small)?.copyWith(color: color(delta)),
          textAlign: TextAlign.end,
        ),
      ],
    );

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ExpansionTile(
        key: Key('revision_${revision.number}'),
        shape: const Border(),
        title: Text(
          l.revisionTitle(revision.number),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (to != null)
              Text(l.measuredRange(date.format(from!), date.format(to))),
            if (hasCycles && cycleDelta != null)
              Text(
                '${d(cycleDelta)} (${formatRatioDelta(comparison.cycleDeltaRatio ?? 0, locale: locale)})',
                style: TextStyle(
                  color: color(cycleDelta),
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        children: [
          Table(
            columnWidths: const {
              0: FlexColumnWidth(2.2),
              1: FlexColumnWidth(),
              2: FlexColumnWidth(),
              3: FlexColumnWidth(),
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              TableRow(
                children: [
                  const SizedBox.shrink(),
                  Text(l.revisionThen, style: bold, textAlign: TextAlign.end),
                  Text(l.revisionNow, style: bold, textAlign: TextAlign.end),
                  Text(l.revisionDelta, style: bold, textAlign: TextAlign.end),
                ],
              ),
              if (hasCycles)
                row(
                  cycleLabel,
                  comparison.previousCycleTime,
                  comparison.currentCycleTime,
                  cycleDelta,
                  style: bold,
                ),
              for (final s in comparison.steps)
                row(
                  s.position == null ? l.removedStep(s.name) : s.name,
                  s.previous,
                  s.current,
                  s.delta,
                ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              key: Key('deleteRevision_${revision.number}'),
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
              label: Text(l.deleteRevision),
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens the revisions of the study shown by a recording screen and returns
/// the new revision number if a new measurement was started.
Future<int?> openRevisions(
  BuildContext context, {
  required int studyId,
  required TimeUnit unit,
  required CycleTimeMethod method,
  required bool canStartNew,
}) {
  return Navigator.of(context).push<int>(
    MaterialPageRoute(
      builder: (_) => RevisionsScreen(
        studyId: studyId,
        unit: unit,
        method: method,
        canStartNew: canStartNew,
      ),
    ),
  );
}
