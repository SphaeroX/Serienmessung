import 'package:flutter/material.dart';

import '../../core/time_format.dart';
import '../../l10n/app_localizations.dart';
import '../domain/cycles.dart';
import '../domain/measurement.dart';
import 'recording_controller.dart';
import 'recording_screen.dart' show editSpecialNote;

/// Measurements grouped by cycle, with delete and undo.
class CyclesView extends StatelessWidget {
  const CyclesView({super.key, required this.controller});

  final RecordingController controller;

  Future<void> _delete(
    BuildContext context,
    Future<List<Measurement>> Function() action,
  ) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final removed = await action();
    if (removed.isEmpty) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(l.deletedTimes(removed.length)),
        action: SnackBarAction(
          label: l.undo,
          onPressed: () => controller.restoreMeasurements(removed),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final c = controller;
    final groups = groupCycles(
      c.measurements,
      stepIds: c.hasSteps ? c.steps.map((s) => s.id).toList() : const [],
    );
    if (groups.isEmpty) {
      return Center(child: Text(l.noTimesYet, textAlign: TextAlign.center));
    }
    String fmt(int us) => formatTime(us, TimeUnit.stopwatch);
    String hm(int us) =>
        formatTime(us, c.displayUnit, decimals: 1, locale: locale);

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      itemCount: groups.length,
      itemBuilder: (context, i) {
        final g = groups[groups.length - 1 - i];
        final label = c.hasSteps
            ? l.cycleNumber(g.cycle)
            : l.lapNumber(g.cycle);
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ExpansionTile(
            key: Key('cycleTile-${g.cycle}'),
            shape: const Border(),
            title: Row(
              children: [
                Text(label, style: theme.textTheme.titleSmall),
                const SizedBox(width: 8),
                if (!g.isComplete)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      l.incomplete,
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
              ],
            ),
            subtitle: Text(
              '${fmt(g.normalTotal)} · ${hm(g.normalTotal)}'
              '${g.specialTotal > 0 ? ' · ${l.specialTime} ${fmt(g.specialTotal)}' : ''}',
              style: const TextStyle(fontFamily: 'monospace'),
            ),
            trailing: IconButton(
              key: Key('deleteCycle-${g.cycle}'),
              tooltip: l.deleteCycle,
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _delete(context, () => c.deleteCycle(g.cycle)),
            ),
            children: [
              for (final m in g.items)
                _MeasurementRow(
                  controller: c,
                  m: m,
                  onDelete: () =>
                      _delete(context, () => c.deleteMeasurement(m.id)),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _MeasurementRow extends StatelessWidget {
  const _MeasurementRow({
    required this.controller,
    required this.m,
    required this.onDelete,
  });

  final RecordingController controller;
  final Measurement m;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final special = m.kind == MeasurementKind.special;
    final step = controller.stepById(m.stepId);
    final title = special
        ? (m.note.isEmpty ? l.specialTime : '${l.specialTime}: ${m.note}')
        : (step?.name ?? (controller.hasSteps ? '?' : l.lapNumber(m.cycle)));
    return ListTile(
      dense: true,
      leading: special
          ? Icon(Icons.pan_tool_alt, color: theme.colorScheme.error, size: 20)
          : Text(
              step == null ? '' : '${step.position + 1}',
              style: theme.textTheme.labelLarge,
            ),
      title: Text(
        title,
        style: special ? TextStyle(color: theme.colorScheme.error) : null,
      ),
      subtitle: Text(
        '${formatTime(m.durationMicros, TimeUnit.stopwatch)} · '
        '${formatTime(m.durationMicros, controller.displayUnit, decimals: 1, locale: locale)}',
        style: const TextStyle(fontFamily: 'monospace'),
      ),
      onTap: special ? () => editSpecialNote(context, controller, m) : null,
      trailing: IconButton(
        key: const Key('deleteMeasurement'),
        tooltip: l.delete,
        icon: const Icon(Icons.close, size: 20),
        onPressed: onDelete,
      ),
    );
  }
}
