import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import '../../core/providers.dart';
import '../../export/presentation/export_menu.dart';
import '../../l10n/app_localizations.dart';
import '../../video/data/video_cleanup.dart';
import '../data/backup_service.dart';
import 'backup_tiles.dart';

/// File name for sharing [label] (a study or group name, or a generic word)
/// on [now]: characters that are no letters or digits become `_`.
String shareFileName(String label, DateTime now) {
  final slug = label
      .replaceAll(RegExp(r'[^\p{L}\p{N}_-]+', unicode: true), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  final date = DateFormat('yyyy-MM-dd').format(now);
  return 'cyclescope_${slug.isEmpty ? 'export' : slug}_$date.json';
}

/// Writes [selection] to a file named after [label] and hands it to the
/// share sheet. The receiver imports it with [importSharedFile].
Future<void> shareSelection(
  BuildContext context,
  WidgetRef ref,
  ExportSelection selection, {
  required String label,
}) async {
  final l = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  try {
    final now = ref.read(wallClockProvider)();
    final json = await BackupService(ref.read(databaseProvider))
        .exportJson(now: now, selection: selection);
    final dir = await ref.read(exportDirectoryProvider)();
    final file = File(p.join(dir.path, shareFileName(label, now)));
    await file.writeAsString(json, flush: true);
    await ref
        .read(fileSharerProvider)
        .share(file.path, mimeType: 'application/json');
  } on Object catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(l.exportFailed('$e'))));
  }
}

/// Lets the user pick a file someone shared (or a backup) and adds its
/// studies and groups to the existing ones. Studies already present are
/// skipped, so importing the same file twice changes nothing.
Future<void> importSharedFile(BuildContext context, WidgetRef ref) async {
  final json = await ref.read(backupPickerProvider).pickBackup();
  if (json == null || !context.mounted) return;
  await importSharedJson(context, ref, json);
}

/// Adds the studies and groups of [json] (a shared file or a backup) to the
/// existing ones and reports the result.
Future<void> importSharedJson(
  BuildContext context,
  WidgetRef ref,
  String json,
) async {
  final l = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  try {
    final r = await BackupService(ref.read(databaseProvider))
        .importJson(json, replace: false);
    ref
      ..invalidate(studyListProvider)
      ..invalidate(groupListProvider);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          [
            l.importResult(r.imported),
            if (r.skipped > 0) l.importSkipped(r.skipped),
            if (r.videoStudies > 0) l.restoreVideoHint,
          ].join(' '),
        ),
      ),
    );
  } on Object catch (e) {
    // Anything else (an unexpected error in the transaction, which rolls
    // back) also changed nothing.
    final tooNew = e is BackupException && e.error == BackupError.tooNew;
    messenger.showSnackBar(
      SnackBar(content: Text(tooNew ? l.importTooNew : l.importInvalid)),
    );
  }
}

/// Deletes the studies [ids] and video files no other study uses.
///
/// The recording notification shows the recording that was saved last; if
/// that study is deleted, the notification goes too (it is ongoing and
/// cannot be swiped away). Recordings of other studies keep it.
Future<void> deleteStudies(WidgetRef ref, Iterable<int> ids) async {
  final runs = await ref.read(runStateRepositoryProvider).activeRuns();
  final shown = runs.isEmpty ? null : runs.first.studyId;
  final studies = ref.read(studyRepositoryProvider);
  for (final id in ids) {
    final study = await studies.getStudy(id);
    if (study == null) continue;
    await studies.deleteStudy(id);
    await deleteUnusedVideo(
      studies,
      ref.read(videoFilesProvider),
      study.videoPath,
    );
  }
  if (shown != null && ids.contains(shown)) {
    await ref.read(recordingNotifierProvider).hide();
  }
}

/// App bar shown while items of a list are selected.
class SelectionAppBar extends StatelessWidget implements PreferredSizeWidget {
  const SelectionAppBar({
    super.key,
    required this.count,
    required this.onClear,
    required this.onSelectAll,
    required this.onShare,
    required this.onDelete,
  });

  final int count;
  final VoidCallback onClear;
  final VoidCallback onSelectAll;
  final VoidCallback onShare;
  final VoidCallback onDelete;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AppBar(
      leading: IconButton(
        key: const Key('clearSelection'),
        tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
        icon: const Icon(Icons.close),
        onPressed: onClear,
      ),
      title: Text(l.selectedCount(count)),
      actions: [
        IconButton(
          key: const Key('selectAll'),
          tooltip: l.selectAll,
          icon: const Icon(Icons.select_all),
          onPressed: onSelectAll,
        ),
        IconButton(
          key: const Key('shareSelected'),
          tooltip: l.share,
          icon: const Icon(Icons.share_outlined),
          onPressed: onShare,
        ),
        IconButton(
          key: const Key('deleteSelected'),
          tooltip: l.delete,
          icon: const Icon(Icons.delete_outline),
          onPressed: onDelete,
        ),
      ],
    );
  }
}

/// Button that imports a shared file.
class ImportSharedButton extends ConsumerWidget {
  const ImportSharedButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => IconButton(
    key: const Key('importButton'),
    tooltip: AppLocalizations.of(context).importShared,
    icon: const Icon(Icons.file_open_outlined),
    onPressed: () => importSharedFile(context, ref),
  );
}
