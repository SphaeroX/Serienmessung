import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../settings/presentation/settings_controller.dart';
import '../../study/domain/study.dart';
import '../domain/staleness.dart';

/// Before a study opens: if its last measurement is older than the
/// configured number of days, asks whether to start a new measurement
/// (archiving the current times as a revision) or to continue.
///
/// Not for video studies (the video defines the measurement) and not while
/// a recording of the study is running.
Future<void> offerNewRevisionIfStale(
  BuildContext context,
  ProviderContainer container,
  Study study,
) async {
  if (study.mode == StudyMode.video) return;
  final days = container.read(settingsProvider).staleDays;
  if (days <= 0) return;
  if (await container.read(runStateRepositoryProvider).load(study.id) != null) {
    return;
  }
  final revisions = container.read(revisionRepositoryProvider);
  final last = await revisions.lastRecordedAt(study.id);
  final now = container.read(wallClockProvider)();
  if (!isMeasurementStale(lastMeasured: last, now: now, days: days)) return;
  if (!context.mounted) return;
  final l = AppLocalizations.of(context);
  final date = DateFormat.yMd(Localizations.localeOf(context).toString())
      .format(last!);
  final startNew = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.history),
      title: Text(l.staleTitle(daysSince(last, now))),
      content: Text(l.staleText(study.name, date, study.revision)),
      actions: [
        TextButton(
          key: const Key('staleContinue'),
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l.staleContinue),
        ),
        FilledButton(
          key: const Key('staleNewRevision'),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(l.staleNewRevision),
        ),
      ],
    ),
  );
  if (startNew == true) {
    await revisions.startNewRevision(study.id, now: now);
  }
}
