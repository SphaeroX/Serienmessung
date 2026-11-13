import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import '../../group/presentation/group_dialogs.dart';
import '../../l10n/app_localizations.dart';
import '../../video/data/video_cleanup.dart';
import '../domain/study.dart';
import 'create_study_screen.dart';
import 'mode_texts.dart';

/// Opens a study by id. Replaced by the study screen once it exists.
typedef OpenStudy = Future<void> Function(BuildContext context, int studyId);

/// Home screen: list of all studies.
///
/// On first show it offers to continue a recording that was still running
/// when the app was closed or killed.
class StudyListScreen extends ConsumerStatefulWidget {
  const StudyListScreen({
    super.key,
    this.onOpenStudy,
    this.onOpenSettings,
    this.onOpenGroups,
    this.checkActiveRuns = true,
  });

  final OpenStudy? onOpenStudy;
  final void Function(BuildContext context)? onOpenSettings;

  /// Opens the group list.
  final Future<void> Function(BuildContext context)? onOpenGroups;
  final bool checkActiveRuns;

  @override
  ConsumerState<StudyListScreen> createState() => _StudyListScreenState();
}

class _StudyListScreenState extends ConsumerState<StudyListScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.checkActiveRuns) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _offerResume());
    }
  }

  Future<void> _offerResume() async {
    final runs = await ref.read(runStateRepositoryProvider).activeRuns();
    if (runs.isEmpty || !mounted) return;
    final run = runs.first;
    final l = AppLocalizations.of(context);
    final open = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.recordingInProgress),
        content: Text(l.recordingInProgressText(run.studyName)),
        actions: [
          TextButton(
            key: const Key('discardRunButton'),
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.discard),
          ),
          FilledButton(
            key: const Key('openRunButton'),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.open),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (open == true) {
      if (widget.onOpenStudy != null) {
        await widget.onOpenStudy!(context, run.studyId);
      }
    } else if (open == false) {
      await ref.read(runStateRepositoryProvider).delete(run.studyId);
      await ref.read(recordingNotifierProvider).hide();
      ref.invalidate(studyListProvider);
    }
  }

  Future<void> _create(BuildContext context) async {
    final id = await Navigator.of(
      context,
    ).push<int>(MaterialPageRoute(builder: (_) => const CreateStudyScreen()));
    if (id != null && context.mounted && widget.onOpenStudy != null) {
      await widget.onOpenStudy!(context, id);
    }
  }

  Future<void> _confirmDelete(BuildContext context, Study study) async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.deleteStudy),
        content: Text(l.deleteStudyConfirm(study.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (ok == true) {
      final studies = ref.read(studyRepositoryProvider);
      await studies.deleteStudy(study.id);
      await deleteUnusedVideo(
        studies,
        ref.read(videoFilesProvider),
        study.videoPath,
      );
      ref.invalidate(studyListProvider);
    }
  }

  Future<void> _cardAction(
    BuildContext context,
    StudyCardAction action,
    Study study,
  ) async {
    switch (action) {
      case StudyCardAction.move:
        await moveStudyToGroup(context, ref, study);
      case StudyCardAction.copy:
        await copyStudyToGroup(context, ref, study);
      case StudyCardAction.delete:
        await _confirmDelete(context, study);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final studies = ref.watch(studyListProvider);
    final onOpenStudy = widget.onOpenStudy;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.appTitle),
        actions: [
          if (widget.onOpenGroups != null)
            IconButton(
              key: const Key('groupsButton'),
              tooltip: l.groups,
              icon: const Icon(Icons.folder_outlined),
              onPressed: () async {
                await widget.onOpenGroups!(context);
                ref.invalidate(studyListProvider);
              },
            ),
          if (widget.onOpenSettings != null)
            IconButton(
              key: const Key('settingsButton'),
              icon: const Icon(Icons.settings),
              onPressed: () => widget.onOpenSettings!(context),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('newStudyFab'),
        onPressed: () => _create(context),
        icon: const Icon(Icons.add),
        label: Text(l.createStudy),
      ),
      body: studies.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) => list.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(l.emptyStudies, textAlign: TextAlign.center),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
                itemCount: list.length,
                itemBuilder: (context, i) => _StudyCard(
                  summary: list[i],
                  onTap: onOpenStudy == null
                      ? null
                      : () => onOpenStudy(context, list[i].study.id),
                  onLongPress: () => _confirmDelete(context, list[i].study),
                  onAction: (a) => _cardAction(context, a, list[i].study),
                ),
              ),
      ),
    );
  }
}

/// Actions of the menu on a study card.
enum StudyCardAction { move, copy, delete }

class _StudyCard extends StatelessWidget {
  const _StudyCard({
    required this.summary,
    this.onTap,
    this.onLongPress,
    this.onAction,
  });

  final StudySummary summary;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final ValueChanged<StudyCardAction>? onAction;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final study = summary.study;
    final fmt = DateFormat.yMd(Localizations.localeOf(context).toString())
        .add_Hm();
    final countLabel = switch (study.mode) {
      StudyMode.simple => l.lapsLabel,
      StudyMode.stepTimer => l.measurementsLabel,
      _ => l.cyclesLabel,
    };
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Icon(
                      study.mode.icon,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          study.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                study.mode.badge(l),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSecondaryContainer,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                            if (summary.groupName != null)
                              Container(
                                key: Key('groupLabel_${study.id}'),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.tertiaryContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.folder_outlined,
                                      size: 12,
                                      color:
                                          theme.colorScheme.onTertiaryContainer,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      summary.groupName!,
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onTertiaryContainer,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (summary.isRecording)
                    Container(
                      key: const Key('recBadge'),
                      margin: const EdgeInsets.only(right: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.error,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        l.recBadge,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onError,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  if (onAction == null)
                    const Icon(Icons.chevron_right)
                  else
                    PopupMenuButton<StudyCardAction>(
                      key: Key('studyMenu_${study.id}'),
                      onSelected: onAction,
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          key: const Key('moveStudy'),
                          value: StudyCardAction.move,
                          child: Text(l.moveToGroup),
                        ),
                        PopupMenuItem(
                          key: const Key('copyStudy'),
                          value: StudyCardAction.copy,
                          child: Text(l.copyToGroup),
                        ),
                        PopupMenuItem(
                          key: const Key('deleteStudyItem'),
                          value: StudyCardAction.delete,
                          child: Text(l.delete),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DefaultTextStyle(
                      style: theme.textTheme.bodySmall!,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${l.createdLabel}  ${fmt.format(study.createdAt)}',
                          ),
                          Text(
                            '${l.activeLabel}  ${fmt.format(study.lastActiveAt)}',
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${summary.cycleCount} ',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextSpan(
                            text: countLabel,
                            style: theme.textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
