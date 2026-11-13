import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../study/presentation/study_list_screen.dart' show OpenStudy;
import 'group_dialogs.dart';
import 'group_screen.dart';

/// List of all study groups.
class GroupListScreen extends ConsumerWidget {
  const GroupListScreen({super.key, this.onOpenStudy});

  /// Opens a study of a group (passed on to [GroupScreen]).
  final OpenStudy? onOpenStudy;

  Future<void> _open(BuildContext context, WidgetRef ref, int id) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GroupScreen(groupId: id, onOpenStudy: onOpenStudy),
      ),
    );
    ref.invalidate(groupListProvider);
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final id = await createGroupInteractively(context, ref);
    if (id != null && context.mounted) await _open(context, ref, id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final groups = ref.watch(groupListProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.groups)),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('newGroupFab'),
        onPressed: () => _create(context, ref),
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
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final g = list[i];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      key: Key('group_${g.group.id}'),
                      leading: CircleAvatar(
                        backgroundColor: theme.colorScheme.tertiaryContainer,
                        child: Icon(
                          Icons.folder_outlined,
                          color: theme.colorScheme.onTertiaryContainer,
                        ),
                      ),
                      title: Text(
                        g.group.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        [
                          if (g.group.description.isNotEmpty)
                            g.group.description,
                          l.groupStudyCount(g.studyCount),
                        ].join('\n'),
                      ),
                      isThreeLine: g.group.description.isNotEmpty,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _open(context, ref, g.group.id),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
