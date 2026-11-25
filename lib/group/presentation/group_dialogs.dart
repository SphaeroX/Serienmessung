import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../study/domain/study.dart';
import '../../video/data/video_cleanup.dart';
import '../domain/group_paths.dart';
import '../domain/study_group.dart';

/// Name and description entered in the group dialog.
typedef GroupFields = ({String name, String description});

/// Asks for the name and description of a group; null if cancelled.
Future<GroupFields?> showGroupDialog(
  BuildContext context, {
  String name = '',
  String description = '',
  bool isNew = true,
}) {
  final l = AppLocalizations.of(context);
  final nameCtrl = TextEditingController(text: name);
  final descCtrl = TextEditingController(text: description);
  final formKey = GlobalKey<FormState>();
  return showDialog<GroupFields>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(isNew ? l.newGroup : l.editGroup),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              key: const Key('groupNameField'),
              controller: nameCtrl,
              autofocus: true,
              decoration: InputDecoration(labelText: l.nameLabel),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? l.nameRequired : null,
            ),
            TextFormField(
              key: const Key('groupDescriptionField'),
              controller: descCtrl,
              decoration: InputDecoration(labelText: l.descriptionLabel),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
        FilledButton(
          key: const Key('saveGroupButton'),
          onPressed: () {
            if (!formKey.currentState!.validate()) return;
            Navigator.pop(ctx, (
              name: nameCtrl.text.trim(),
              description: descCtrl.text.trim(),
            ));
          },
          child: Text(l.save),
        ),
      ],
    ),
  );
}

/// Asks for a name and creates a group; returns its id or null.
Future<int?> createGroupInteractively(
  BuildContext context,
  WidgetRef ref,
) async {
  final fields = await showGroupDialog(context);
  if (fields == null) return null;
  final id = await ref
      .read(groupRepositoryProvider)
      .createGroup(
        name: fields.name,
        description: fields.description,
        now: ref.read(wallClockProvider)(),
      );
  ref.invalidate(groupListProvider);
  return id;
}

/// Result of [pickGroup]: the chosen group, null for "no group".
typedef GroupPick = ({int? groupId});

/// Lets the user choose a target group (or create one, or "no group").
/// Returns null if cancelled. Groups are named by their path; [exclude]
/// and [excludeIds] are not offered.
Future<GroupPick?> pickGroup(
  BuildContext context,
  WidgetRef ref, {
  int? exclude,
  Set<int> excludeIds = const {},
}) async {
  final l = AppLocalizations.of(context);
  final all = await ref.read(groupRepositoryProvider).listGroups();
  if (!context.mounted) return null;
  final paths = groupPaths([for (final g in all) g.group]);
  final choice = await showDialog<Object>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: Text(l.chooseGroup),
      children: [
        for (final g in all)
          if (g.group.id != exclude && !excludeIds.contains(g.group.id))
            SimpleDialogOption(
              key: Key('groupChoice_${g.group.id}'),
              onPressed: () => Navigator.pop(ctx, g.group.id),
              child: ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(paths[g.group.id]!.join(groupPathSeparator)),
                subtitle: Text(l.groupStudyCount(g.studyCount)),
              ),
            ),
        SimpleDialogOption(
          key: const Key('newGroupChoice'),
          onPressed: () => Navigator.pop(ctx, 'new'),
          child: ListTile(
            leading: const Icon(Icons.create_new_folder_outlined),
            title: Text(l.newGroup),
          ),
        ),
        SimpleDialogOption(
          key: const Key('noGroupChoice'),
          onPressed: () => Navigator.pop(ctx, 'none'),
          child: ListTile(
            leading: const Icon(Icons.folder_off_outlined),
            title: Text(l.noGroup),
          ),
        ),
      ],
    ),
  );
  if (choice == null || !context.mounted) return null;
  if (choice == 'none') return (groupId: null);
  if (choice == 'new') {
    final id = await createGroupInteractively(context, ref);
    return id == null ? null : (groupId: id);
  }
  return (groupId: choice as int);
}

/// Asks whether to delete [group] (with a checkbox to delete its studies
/// and areas too, counted over the whole subtree) and deletes it. Without
/// the checkbox its studies stay without a group and its areas become
/// groups of the top level; with it the whole subtree goes, with the videos
/// no other study plays. Returns true if deleted.
///
/// [subtree] (the studies of the group and its areas, see
/// `GroupRepository.subtreeStudies`) and [areaCount] (all areas below it)
/// can be passed when already loaded, so the dialog opens at once.
Future<bool> deleteGroupInteractively(
  BuildContext context,
  WidgetRef ref,
  StudyGroup group, {
  List<Study>? subtree,
  int? areaCount,
}) async {
  final l = AppLocalizations.of(context);
  final groups = ref.read(groupRepositoryProvider);
  final studies = subtree ?? await groups.subtreeStudies(group.id);
  final areas = areaCount ?? (await groups.descendants(group.id)).length;
  if (!context.mounted) return false;
  final n = studies.length;
  // null = cancelled, otherwise whether the studies go too.
  final withStudies = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      var studiesToo = false;
      return StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(l.deleteGroup),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(switch ((studiesToo, areas > 0)) {
                (true, true) => l.deleteGroupWithAreasConfirm(
                  group.name,
                  areas,
                  n,
                ),
                (true, false) => l.deleteGroupWithStudiesConfirm(group.name, n),
                (false, true) => l.deleteGroupKeepAreasConfirm(group.name),
                (false, false) => l.deleteGroupConfirm(group.name),
              }),
              if (n > 0 || areas > 0)
                CheckboxListTile(
                  key: const Key('deleteGroupStudies'),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: studiesToo,
                  title: Text(
                    areas > 0
                        ? l.deleteGroupStudiesAndAreasOption(n, areas)
                        : l.deleteGroupStudiesOption(n),
                  ),
                  onChanged: (v) => setState(() => studiesToo = v ?? false),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l.cancel),
            ),
            TextButton(
              key: const Key('confirmDeleteGroup'),
              onPressed: () => Navigator.pop(ctx, studiesToo),
              child: Text(l.delete),
            ),
          ],
        ),
      );
    },
  );
  if (withStudies == null) return false;
  final ids = {for (final s in studies) s.id};
  final recording =
      withStudies &&
      (await ref.read(studyRepositoryProvider).listStudies()).any(
        (s) => s.isRecording && ids.contains(s.study.id),
      );
  await groups.deleteGroup(group.id, withStudies: withStudies);
  if (withStudies) {
    // Videos no study plays any more go with their studies.
    final repo = ref.read(studyRepositoryProvider);
    final files = ref.read(videoFilesProvider);
    for (final path in {for (final s in studies) ?s.videoPath}) {
      await deleteUnusedVideo(repo, files, path);
    }
    // A recording of a deleted study cannot go on.
    if (recording) await ref.read(recordingNotifierProvider).hide();
  }
  ref
    ..invalidate(groupListProvider)
    ..invalidate(studyListProvider);
  return true;
}

/// Moves [study] into a group chosen by the user. Returns true if moved.
Future<bool> moveStudyToGroup(
  BuildContext context,
  WidgetRef ref,
  Study study,
) async {
  final pick = await pickGroup(context, ref, exclude: study.groupId);
  if (pick == null) return false;
  await ref.read(groupRepositoryProvider).moveToGroup(study.id, pick.groupId);
  ref
    ..invalidate(groupListProvider)
    ..invalidate(studyListProvider);
  return true;
}

/// Copies [study] (steps and times) into a group chosen by the user.
/// Returns the id of the copy, or null if cancelled.
Future<int?> copyStudyToGroup(
  BuildContext context,
  WidgetRef ref,
  Study study,
) async {
  final l = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final pick = await pickGroup(context, ref);
  if (pick == null) return null;
  final name = l.copyName(study.name);
  final id = await ref
      .read(studyRepositoryProvider)
      .copyStudy(
        study.id,
        name: name,
        groupId: pick.groupId,
        now: ref.read(wallClockProvider)(),
      );
  ref
    ..invalidate(groupListProvider)
    ..invalidate(studyListProvider);
  messenger.showSnackBar(SnackBar(content: Text(l.studyCopied(name))));
  return id;
}
