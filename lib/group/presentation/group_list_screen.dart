import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../backup/data/backup_service.dart';
import '../../backup/presentation/share_actions.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../study/presentation/study_list_screen.dart' show OpenStudy;
import '../domain/group_paths.dart';
import '../domain/study_group.dart';
import 'group_dialogs.dart';
import 'group_screen.dart';

/// List of all study groups.
///
/// A long press selects groups to share (with all their studies) or delete
/// several at once.
class GroupListScreen extends ConsumerStatefulWidget {
  const GroupListScreen({super.key, this.onOpenStudy});

  /// Opens a study of a group (passed on to [GroupScreen]).
  final OpenStudy? onOpenStudy;

  @override
  ConsumerState<GroupListScreen> createState() => _GroupListScreenState();
}

enum _DeleteGroups { keepStudies, withStudies }

class _GroupListScreenState extends ConsumerState<GroupListScreen> {
  /// Selected group ids; selecting while not empty.
  final _selected = <int>{};

  void _toggle(int id) => setState(() {
    if (!_selected.remove(id)) _selected.add(id);
  });

  Future<void> _open(BuildContext context, int id) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            GroupScreen(groupId: id, onOpenStudy: widget.onOpenStudy),
      ),
    );
    ref.invalidate(groupListProvider);
  }

  Future<void> _create(BuildContext context) async {
    final id = await createGroupInteractively(context, ref);
    if (id != null && context.mounted) await _open(context, id);
  }

  Future<void> _shareSelected(BuildContext context) async {
    final ids = {..._selected};
    final groups = ref.read(groupListProvider).value ?? const [];
    final chosen = [
      for (final g in groups)
        if (ids.contains(g.group.id)) g.group,
    ];
    await shareSelection(
      context,
      ref,
      ExportSelection(groupIds: ids),
      label: chosen.length == 1 ? chosen.single.name : 'groups',
    );
  }

  Future<void> _deleteSelected(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final choice = await showDialog<_DeleteGroups>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.deleteGroups),
        content: Text(l.deleteGroupsConfirm(_selected.length)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.cancel),
          ),
          TextButton(
            key: const Key('deleteGroupsWithStudies'),
            onPressed: () => Navigator.pop(ctx, _DeleteGroups.withStudies),
            child: Text(l.deleteGroupsWithStudies),
          ),
          TextButton(
            key: const Key('deleteGroupsKeepStudies'),
            onPressed: () => Navigator.pop(ctx, _DeleteGroups.keepStudies),
            child: Text(l.deleteGroupsKeepStudies),
          ),
        ],
      ),
    );
    if (choice == null) return;
    final groups = ref.read(groupRepositoryProvider);
    for (final id in {..._selected}) {
      // With studies the whole subtree goes (areas and their studies);
      // otherwise the areas become groups of the top level.
      final withStudies = choice == _DeleteGroups.withStudies;
      if (withStudies) {
        final members = await groups.subtreeStudies(id);
        await deleteStudies(ref, [for (final s in members) s.id]);
      }
      await groups.deleteGroup(id, withStudies: withStudies);
    }
    if (mounted) setState(_selected.clear);
    ref
      ..invalidate(groupListProvider)
      ..invalidate(studyListProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final groups = ref.watch(groupListProvider);
    final selecting = _selected.isNotEmpty;
    return PopScope(
      canPop: !selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(_selected.clear);
      },
      child: Scaffold(
        appBar: selecting
            ? SelectionAppBar(
                count: _selected.length,
                onClear: () => setState(_selected.clear),
                onSelectAll: () => setState(
                  () => _selected.addAll([
                    for (final g in groups.value ?? const <GroupSummary>[])
                      g.group.id,
                  ]),
                ),
                onShare: () => _shareSelected(context),
                onDelete: () => _deleteSelected(context),
              )
            : AppBar(
                title: Text(l.groups),
                actions: const [ImportSharedButton()],
              ),
        floatingActionButton: selecting
            ? null
            : FloatingActionButton.extended(
                key: const Key('newGroupFab'),
                onPressed: () => _create(context),
                icon: const Icon(Icons.create_new_folder_outlined),
                label: Text(l.newGroup),
              ),
        body: groups.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (list) => list.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(l.emptyGroups, style: theme.textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Text(l.emptyGroupsHint, textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                )
              : _tree(context, list, theme, l, selecting),
        ),
      ),
    );
  }

  /// All groups as a tree: areas indented under their parent group.
  Widget _tree(
    BuildContext context,
    List<GroupSummary> list,
    ThemeData theme,
    AppLocalizations l,
    bool selecting,
  ) {
    final byId = {for (final g in list) g.group.id: g};
    final order = groupTreeOrder([for (final g in list) g.group]);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
      itemCount: order.length,
      itemBuilder: (context, i) {
        final (group, depth) = order[i];
        final g = byId[group.id]!;
        final id = g.group.id;
        final selected = _selected.contains(id);
        return Card(
          margin: EdgeInsets.only(top: 6, bottom: 6, left: 24.0 * depth),
          color: selected ? theme.colorScheme.secondaryContainer : null,
          child: ListTile(
            key: Key('group_$id'),
            leading: CircleAvatar(
              backgroundColor: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.tertiaryContainer,
              child: Icon(
                selected
                    ? Icons.check
                    : depth > 0
                    ? Icons.account_tree_outlined
                    : Icons.folder_outlined,
                color: selected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onTertiaryContainer,
              ),
            ),
            title: Text(
              g.group.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              [
                if (g.group.description.isNotEmpty) g.group.description,
                g.areaCount > 0
                    ? l.groupAreaCount(g.areaCount, g.totalStudyCount)
                    : l.groupStudyCount(g.studyCount),
              ].join('\n'),
            ),
            isThreeLine: g.group.description.isNotEmpty,
            trailing: selecting ? null : const Icon(Icons.chevron_right),
            onTap: selecting ? () => _toggle(id) : () => _open(context, id),
            onLongPress: () => _toggle(id),
          ),
        );
      },
    );
  }
}
