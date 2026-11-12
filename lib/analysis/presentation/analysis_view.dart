import 'package:flutter/material.dart';

import '../../core/time_format.dart';
import '../../l10n/app_localizations.dart';
import '../../recording/presentation/recording_controller.dart';
import '../../study/domain/study.dart';
import '../domain/analysis.dart';
import '../domain/statistics.dart';

/// Decimals used for analysis figures per unit.
int analysisDecimals(TimeUnit unit) => switch (unit) {
  TimeUnit.hm => 1,
  TimeUnit.seconds => 2,
  TimeUnit.tmu => 0,
  TimeUnit.stopwatch => 0,
};

/// Localized name of a cycle time method.
String methodLabel(AppLocalizations l, CycleTimeMethod m) => switch (m) {
  CycleTimeMethod.mean => l.methodMean,
  CycleTimeMethod.median => l.methodMedian,
  CycleTimeMethod.iqr => l.methodIqr,
};

/// Evaluation tab: real cycle time, key figures and per-step statistics.
class AnalysisView extends StatelessWidget {
  const AnalysisView({super.key, required this.controller});

  final RecordingController controller;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final c = controller;
    final mode = c.study?.mode ?? StudyMode.timeStudy;
    final unit = c.analysisUnit;
    final a = StudyAnalysis.compute(
      measurements: c.measurements,
      steps: c.hasSteps ? c.steps : const [],
      mode: mode,
      method: c.cycleTimeMethod,
    );
    String t(num micros) => formatTime(
      micros.round(),
      unit,
      decimals: analysisDecimals(unit),
      locale: locale,
    );
    final hasCycles = mode != StudyMode.stepTimer;

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      children: [
        Wrap(
          spacing: 6,
          children: [
            for (final u in TimeUnit.values)
              ChoiceChip(
                key: Key('unit-${u.name}'),
                label: Text(u.label),
                selected: u == unit,
                onSelected: (_) => c.setAnalysisUnit(u),
              ),
          ],
        ),
        const SizedBox(height: 8),
        _NotesField(controller: c),
        const SizedBox(height: 8),
        if (hasCycles)
          Card(
            color: theme.colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.hasSteps ? l.realCycleTime : l.realLapTime,
                    style: theme.textTheme.labelLarge,
                  ),
                  Text(
                    a.cycleStats.n == 0 ? '–' : t(a.realCycleTime),
                    key: const Key('realCycleTime'),
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<CycleTimeMethod>(
                    showSelectedIcon: false,
                    segments: [
                      for (final m in CycleTimeMethod.values)
                        ButtonSegment(
                          value: m,
                          label: Text(
                            methodLabel(l, m),
                            key: Key('method-${m.name}'),
                          ),
                        ),
                    ],
                    selected: {c.cycleTimeMethod},
                    onSelectionChanged: (s) => c.setCycleTimeMethod(s.first),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    [
                      l.completeCycles(a.cycleStats.n),
                      if (a.incompleteCycles > 0)
                        l.incompleteCycles(a.incompleteCycles),
                      if (c.cycleTimeMethod == CycleTimeMethod.iqr)
                        l.outliersRemoved(a.removedCycles),
                    ].join(' · '),
                    style: theme.textTheme.bodySmall,
                  ),
                  Text(l.methodHint, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ),
        if (hasCycles && a.cycleStats.n > 0)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _Figure(l.mean, t(a.cycleStats.mean)),
                  _Figure(l.median, t(a.cycleStats.median)),
                  _Figure(l.minimum, t(a.cycleStats.min)),
                  _Figure(l.maximum, t(a.cycleStats.max)),
                  _Figure(l.stdDev, t(a.cycleStats.stdDev)),
                  _Figure(
                    l.cv,
                    '${formatNumber(a.cycleStats.cv * 100, 1, locale: locale)} %',
                  ),
                ],
              ),
            ),
          ),
        Card(
          child: ListTile(
            leading: Icon(Icons.pan_tool_alt, color: theme.colorScheme.error),
            title: Text(l.specialTimesTotal),
            subtitle: Text(l.specialTimesExcluded),
            trailing: Text(
              '${t(a.specialTotal)} (${a.specialCount})',
              key: const Key('specialTotal'),
            ),
          ),
        ),
        if (a.steps.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
            child: Text(l.stepsSection, style: theme.textTheme.titleMedium),
          ),
          for (final s in a.steps)
            Card(
              child: ListTile(
                title: Text('${s.step.position + 1}. ${s.step.name}'),
                subtitle: Text(
                  s.stats.n == 0
                      ? l.noTimesShort
                      : [
                          'n=${s.stats.n}',
                          '${l.meanShort} ${t(s.stats.mean)}',
                          '${l.medianShort} ${t(s.stats.median)}',
                          '${t(s.stats.min)}–${t(s.stats.max)}',
                          if (!hasCycles)
                            '${formatNumber(s.share * 100, 1, locale: locale)} %',
                        ].join(' · '),
                ),
                trailing: Text(
                  s.stats.n == 0 ? '–' : t(s.realTime),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

/// Free notes of the study, saved while typing and printed in the reports.
/// Small in the overview; grows to a writing area while it has the focus.
class _NotesField extends StatefulWidget {
  const _NotesField({required this.controller});

  final RecordingController controller;

  @override
  State<_NotesField> createState() => _NotesFieldState();
}

class _NotesFieldState extends State<_NotesField> {
  late final _text = TextEditingController(text: widget.controller.notes);
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return TextField(
      key: const Key('studyNotes'),
      controller: _text,
      focusNode: _focus,
      minLines: _focus.hasFocus ? 10 : 1,
      maxLines: _focus.hasFocus ? 16 : 2,
      keyboardType: TextInputType.multiline,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        labelText: l.studyNotes,
        hintText: l.studyNotesHint,
        prefixIcon: const Icon(Icons.notes),
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      onChanged: widget.controller.setNotes,
      onTapOutside: (_) => FocusScope.of(context).unfocus(),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelSmall),
          Text(value, style: theme.textTheme.titleSmall),
        ],
      ),
    );
  }
}
