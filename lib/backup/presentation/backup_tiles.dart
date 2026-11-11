import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import '../../core/providers.dart';
import '../../export/presentation/export_menu.dart';
import '../../l10n/app_localizations.dart';
import '../data/backup_service.dart';
import '../platform/backup_picker.dart';

final backupPickerProvider = Provider<BackupPicker>(
  (ref) => FileBackupPicker(),
);

enum _RestoreMode { merge, replace }

/// Settings tiles to create and restore a backup file.
class BackupTiles extends ConsumerWidget {
  const BackupTiles({super.key});

  Future<void> _backup(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final now = ref.read(wallClockProvider)();
      final json = await BackupService(ref.read(databaseProvider))
          .exportJson(now: now);
      final dir = await ref.read(exportDirectoryProvider)();
      final name =
          'cyclescope_backup_${DateFormat('yyyy-MM-dd').format(now)}.json';
      final file = File(p.join(dir.path, name));
      await file.writeAsString(json, flush: true);
      await ref
          .read(fileSharerProvider)
          .share(file.path, mimeType: 'application/json', subject: name);
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l.exportFailed('$e'))));
    }
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final json = await ref.read(backupPickerProvider).pickBackup();
    if (json == null || !context.mounted) return;

    final mode = await showDialog<_RestoreMode>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.restoreBackup),
        content: Text(l.restoreChoice),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.cancel),
          ),
          TextButton(
            key: const Key('restoreReplace'),
            onPressed: () => Navigator.pop(ctx, _RestoreMode.replace),
            child: Text(l.restoreReplace),
          ),
          FilledButton(
            key: const Key('restoreMerge'),
            onPressed: () => Navigator.pop(ctx, _RestoreMode.merge),
            child: Text(l.restoreMerge),
          ),
        ],
      ),
    );
    if (mode == null || !context.mounted) return;
    if (mode == _RestoreMode.replace) {
      final sure = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l.restoreReplace),
          content: Text(l.restoreReplaceWarning),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.cancel),
            ),
            TextButton(
              key: const Key('restoreReplaceConfirm'),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.restoreReplace),
            ),
          ],
        ),
      );
      if (sure != true) return;
    }

    try {
      final r = await BackupService(ref.read(databaseProvider))
          .importJson(json, replace: mode == _RestoreMode.replace);
      ref.invalidate(studyListProvider);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            [
              l.restoreResult(r.imported, r.skipped),
              if (r.videoStudies > 0) l.restoreVideoHint,
            ].join(' '),
          ),
        ),
      );
    } on BackupException catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e.error == BackupError.tooNew ? l.restoreTooNew : l.restoreInvalid,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return Column(
      children: [
        ListTile(
          key: const Key('createBackupTile'),
          leading: const Icon(Icons.backup_outlined),
          title: Text(l.createBackup),
          subtitle: Text(l.createBackupHint),
          onTap: () => _backup(context, ref),
        ),
        ListTile(
          key: const Key('restoreBackupTile'),
          leading: const Icon(Icons.settings_backup_restore),
          title: Text(l.restoreBackup),
          subtitle: Text(l.restoreBackupHint),
          onTap: () => _restore(context, ref),
        ),
      ],
    );
  }
}
