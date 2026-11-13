import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../export/presentation/export_menu.dart';
import '../../l10n/app_localizations.dart';
import '../../study/domain/study.dart';
import '../../study/presentation/create_study_screen.dart';
import '../../study/presentation/mode_texts.dart';
import '../../study/presentation/study_list_screen.dart' show OpenStudy;
import '../domain/study_group.dart';
import '../../settings/presentation/settings_controller.dart';
import '../../core/time_format.dart';
import '../domain/stations.dart';
import 'group_dialogs.dart';
import 'machine_dialogs.dart';
import 'special_cycles_screen.dart';
import 'line_screen.dart';

/// One group: its studies in order (drag to reorder), adding, moving,
/// copying and removing studies, editing and deleting the group.
class GroupScreen extends ConsumerStatefulWidget {
  const GroupScreen({super.key, required this.groupId, this.onOpenStudy});

  final int groupId;
  final OpenStudy? onOpenStudy;

  @override
  ConsumerState<GroupScreen> createState() => _GroupScreenState();
}

enum _StudyAction {
  moveUp,
  moveDown,
  parallel,
  cycleTime,
  buffer,
  conveyor,
  specialCycles,
  moveToGroup,
  copyToGroup,
  remove,
}

enum _GroupAction { edit, delete }

class _GroupScreenState extends ConsumerState<GroupScreen> {
  StudyGroup? _group;
  List<StudySummary> _members = const [];

  /// Number of special cycles per member study.
  Map<int, int> _specialCounts = const {};
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final group = await ref
        .read(groupRepositoryProvider)
        .getGroup(widget.groupId);
    final members = await ref
        .read(studyRepositoryProvider)
        .listStudies(groupId: widget.groupId);
    final counts = await ref.read(specialCycleRepositoryProvider).countFor([
      for (final m in members) m.study.id,
    ]);
    if (!mounted) return;
    setState(() {
      _group = group;
      _members = members;
      _specialCounts = counts;
      _loaded = true;
    });
  }

  /// Reloads after a change and refreshes the other lists.
  Future<void> _changed() async {
    ref
      ..invalidate(groupListProvider)
      ..invalidate(studyListProvider);
    await _load();
  }

  /// Stores the new order; [moved] is the member that changed its place, so
  /// the stations of the other members stay together.
  Future<void> _reorder(List<int> ids, int moved) async {
    await ref
        .read(groupRepositoryProvider)
        .reorder(widget.groupId, ids, moved: moved);
    await _changed();
  }

  /// Drag reorder; [to] is already adjusted for the removed item.
  Future<void> _onReorder(int from, int to) async {
    final moved = _members[from];
    setState(() {
      _members = [..._members]
        ..removeAt(from)
        ..insert(to, moved);
    });
    await _reorder([for (final m in _members) m.study.id], moved.study.id);
  }

  Future<void> _studyAction(_StudyAction action, int index) async {
    final study = _members[index].study;
    final ids = [for (final m in _members) m.study.id];
    switch (action) {
      case _StudyAction.moveUp:
        if (index == 0) return;
        ids.insert(index - 1, ids.removeAt(index));
        await _reorder(ids, study.id);
      case _StudyAction.moveDown:
        if (index == ids.length - 1) return;
        ids.insert(index + 1, ids.removeAt(index));
        await _reorder(ids, study.id);
      case _StudyAction.parallel:
        await ref
            .read(groupRepositoryProvider)
            .setParallel(study.id, !study.parallel);
        await _changed();
      case _StudyAction.cycleTime:
        final micros = await showCycleTimeDialog(
          context,
          ref.read(settingsProvider).defaultUnit,
        );
        if (micros == null) return;
        await ref.read(machineServiceProvider).setCycleTime(study.id, micros);
        await _changed();
      case _StudyAction.buffer:
        await _editBuffer(study);
      case _StudyAction.conveyor:
        await _editConveyor(study);
      case _StudyAction.specialCycles:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                SpecialCyclesScreen(studyId: study.id, studyName: study.name),
          ),
        );
        await _load();
      case _StudyAction.moveToGroup:
        if (await moveStudyToGroup(context, ref, study)) await _changed();
      case _StudyAction.copyToGroup:
        if (await copyStudyToGroup(context, ref, study) != null) {
          await _changed();
        }
      case _StudyAction.remove:
        await ref.read(groupRepositoryProvider).moveToGroup(study.id, null);
        await _changed();
    }
  }

  Future<void> _groupAction(_GroupAction action) async {
    final group = _group;
    if (group == null) return;
    final l = AppLocalizations.of(context);
    switch (action) {
      case _GroupAction.edit:
        final fields = await showGroupDialog(
          context,
          name: group.name,
          description: group.description,
          isNew: false,
        );
        if (fields == null) return;
        await ref
            .read(groupRepositoryProvider)
            .updateGroup(
              group.id,
              name: fields.name,
              description: fields.description,
            );
        await _changed();
      case _GroupAction.delete:
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l.deleteGroup),
            content: Text(l.deleteGroupConfirm(group.name)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l.cancel),
              ),
              TextButton(
                key: const Key('confirmDeleteGroup'),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l.delete),
              ),
            ],
          ),
        );
        if (ok != true) return;
        await ref.read(groupRepositoryProvider).deleteGroup(group.id);
        ref
          ..invalidate(groupListProvider)
          ..invalidate(studyListProvider);
        if (mounted) Navigator.of(context).maybePop();
    }
  }

  Future<void> _add() async {
    final l = AppLocalizations.of(context);
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const Key('addNewStudy'),
              leading: const Icon(Icons.add),
              title: Text(l.addNewStudy),
              onTap: () => Navigator.pop(sheet, 'new'),
            ),
            ListTile(
              key: const Key('addMachine'),
              leading: const Icon(Icons.precision_manufacturing_outlined),
              title: Text(l.addMachine),
              subtitle: Text(l.addMachineHint),
              onTap: () => Navigator.pop(sheet, 'machine'),
            ),
            ListTile(
              key: const Key('addExistingStudies'),
              leading: const Icon(Icons.playlist_add),
              title: Text(l.addExistingStudies),
              subtitle: Text(l.addExistingHint),
              onTap: () => Navigator.pop(sheet, 'existing'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (choice == 'new') await _addNew();
    if (choice == 'existing') await _addExisting();
    if (choice == 'machine') await _addMachine();
  }

  /// Adds, edits or removes the buffer before the station of [study].
  Future<void> _editBuffer(Study study) async {
    final fields = await showBufferDialog(
      context,
      ref.read(settingsProvider).defaultUnit,
      existing: study.hasBuffer
          ? (
              capacity: study.bufferCapacity,
              storeMicros: study.bufferStoreMicros,
              retrieveMicros: study.bufferRetrieveMicros,
            )
          : null,
    );
    if (fields == null) return;
    final groups = ref.read(groupRepositoryProvider);
    if (fields.remove) {
      await groups.removeBuffer(study.id);
    } else {
      await groups.setBuffer(
        study.id,
        capacity: fields.capacity,
        storeMicros: fields.storeMicros,
        retrieveMicros: fields.retrieveMicros,
      );
    }
    await _changed();
  }

  /// Adds, edits or removes the conveyor before the station of [study].
  Future<void> _editConveyor(Study study) async {
    final fields = await showConveyorDialog(
      context,
      ref.read(settingsProvider).defaultUnit,
      existing: study.hasConveyor
          ? (
              capacity: study.conveyorCapacity,
              transportMicros: study.conveyorTransportMicros,
            )
          : null,
    );
    if (fields == null) return;
    final groups = ref.read(groupRepositoryProvider);
    if (fields.remove) {
      await groups.removeConveyor(study.id);
    } else {
      await groups.setConveyor(
        study.id,
        capacity: fields.capacity,
        transportMicros: fields.transportMicros,
      );
    }
    await _changed();
  }

  Future<void> _addMachine() async {
    final fields = await showMachineDialog(
      context,
      ref.read(settingsProvider).defaultUnit,
      canBeParallel: _members.isNotEmpty,
    );
    if (fields == null) return;
    await ref
        .read(machineServiceProvider)
        .createMachine(
          name: fields.name,
          groupId: widget.groupId,
          cycleMicros: fields.cycleMicros,
          parallel: fields.parallel,
        );
    await _changed();
  }

  Future<void> _addNew() async {
    final id = await Navigator.of(
      context,
    ).push<int>(MaterialPageRoute(builder: (_) => const CreateStudyScreen()));
    if (id == null) return;
    await ref.read(groupRepositoryProvider).moveToGroup(id, widget.groupId);
    await _changed();
    if (mounted && widget.onOpenStudy != null) {
      await widget.onOpenStudy!(context, id);
      await _load();
    }
  }

  Future<void> _addExisting() async {
    final l = AppLocalizations.of(context);
    final candidates = [
      for (final s in await ref.read(studyRepositoryProvider).listStudies())
        if (s.study.groupId != widget.groupId) s,
    ];
    if (!mounted) return;
    final chosen = await showDialog<List<int>>(
      context: context,
      builder: (ctx) => _PickStudiesDialog(candidates: candidates, l: l),
    );
    if (chosen == null || chosen.isEmpty) return;
    final repo = ref.read(groupRepositoryProvider);
    for (final id in chosen) {
      await repo.moveToGroup(id, widget.groupId);
    }
    await _changed();
  }

  Future<void> _open(int studyId) async {
    if (widget.onOpenStudy == null) return;
    await widget.onOpenStudy!(context, studyId);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_group?.name ?? ''),
        actions: [
          IconButton(
            key: const Key('lineAnalysisButton'),
            tooltip: l.lineAnalysis,
            icon: const Icon(Icons.stacked_bar_chart),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => LineScreen(groupId: widget.groupId),
              ),
            ),
          ),
          GroupExportButton(groupId: widget.groupId),
          PopupMenuButton<_GroupAction>(
            key: const Key('groupMenu'),
            onSelected: _groupAction,
            itemBuilder: (_) => [
              PopupMenuItem(
                key: const Key('editGroup'),
                value: _GroupAction.edit,
                child: Text(l.editGroup),
              ),
              PopupMenuItem(
                key: const Key('deleteGroup'),
                value: _GroupAction.delete,
                child: Text(l.deleteGroup),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('addStudiesFab'),
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: Text(l.addStudies),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : _members.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(l.emptyGroupStudies, textAlign: TextAlign.center),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_group!.description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Text(_group!.description),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text(l.reorderHint, style: theme.textTheme.bodySmall),
                ),
                Expanded(child: _list()),
              ],
            ),
    );
  }

  Widget _list() {
    final labels = stationLabels([for (final m in _members) m.study.parallel]);
    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
      itemCount: _members.length,
      onReorderItem: _onReorder,
      itemBuilder: (context, i) => _MemberTile(
        key: ValueKey(_members[i].study.id),
        index: i,
        count: _members.length,
        label: labels[i],
        // Parallel machines carry a letter ("2a").
        inStation: RegExp('[a-z]').hasMatch(labels[i]),
        summary: _members[i],
        onTap: () => _open(_members[i].study.id),
        onAction: (a) => _studyAction(a, i),
        onBuffer: () => _editBuffer(_members[i].study),
        onConveyor: () => _editConveyor(_members[i].study),
        specialCount: _specialCounts[_members[i].study.id] ?? 0,
        unit: ref.read(settingsProvider).defaultUnit,
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    super.key,
    required this.index,
    required this.count,
    required this.label,
    required this.inStation,
    required this.summary,
    required this.onTap,
    required this.onAction,
    required this.onBuffer,
    required this.onConveyor,
    required this.unit,
    this.specialCount = 0,
  });

  /// Number of special cycles of the member.
  final int specialCount;

  final VoidCallback onBuffer;
  final VoidCallback onConveyor;
  final TimeUnit unit;
  final int index;
  final int count;

  /// Station label ("2" or "2b" for parallel machines).
  final String label;

  /// Part of a station with several parallel machines.
  final bool inStation;
  final StudySummary summary;
  final VoidCallback onTap;
  final ValueChanged<_StudyAction> onAction;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final study = summary.study;
    final theme = Theme.of(context);
    // A buffer sits before the first machine of a station (not the first).
    final stationStart = index > 0 && !study.parallel;
    final showBuffer = study.hasBuffer && stationStart;
    final showConveyor = study.hasConveyor && stationStart;
    final card = _card(context, l, study, theme);
    if (!showBuffer && !showConveyor) return card;
    String t(int micros) => formatTime(
      micros,
      unit,
      locale: Localizations.localeOf(context).languageCode,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showConveyor)
          Card(
            key: Key('conveyor_${study.id}'),
            margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 32),
            color: theme.colorScheme.surfaceContainerHighest,
            child: ListTile(
              dense: true,
              onTap: onConveyor,
              leading: const Icon(Icons.linear_scale),
              title: Text(l.conveyorCard(study.conveyorCapacity)),
              subtitle: Text(
                l.conveyorTransport(t(study.conveyorTransportMicros)),
              ),
              trailing: const Icon(Icons.edit_outlined, size: 18),
            ),
          ),
        if (showBuffer)
          Card(
            key: Key('buffer_${study.id}'),
            margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 32),
            color: theme.colorScheme.secondaryContainer,
            child: ListTile(
              dense: true,
              onTap: onBuffer,
              leading: const Icon(Icons.inventory_2_outlined),
              title: Text(l.bufferPlaces(study.bufferCapacity)),
              subtitle: Text(
                l.bufferTimes(
                  t(study.bufferStoreMicros),
                  t(study.bufferRetrieveMicros),
                ),
              ),
              trailing: const Icon(Icons.edit_outlined, size: 18),
            ),
          ),
        card,
      ],
    );
  }

  Widget _card(
    BuildContext context,
    AppLocalizations l,
    Study study,
    ThemeData theme,
  ) {
    return Card(
      margin: EdgeInsets.only(
        top: 4,
        bottom: 4,
        left: study.parallel && index > 0 ? 24 : 0,
      ),
      shape: inStation
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.colorScheme.tertiary, width: 1.5),
            )
          : null,
      child: ListTile(
        onTap: onTap,
        leading: ReorderableDragStartListener(
          index: index,
          child: const Padding(
            padding: EdgeInsets.all(8),
            child: Icon(Icons.drag_handle),
          ),
        ),
        title: Text(
          '$label. ${study.name}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${study.mode.title(l)} · ${summary.cycleCount} '
          '${study.mode == StudyMode.simple
              ? l.lapsLabel
              : study.mode == StudyMode.stepTimer
              ? l.measurementsLabel
              : l.cyclesLabel}'
          '${specialCount > 0 ? ' · ${l.specialCycleCount(specialCount)}' : ''}',
        ),
        trailing: PopupMenuButton<_StudyAction>(
          key: Key('groupStudyMenu_${study.id}'),
          onSelected: onAction,
          itemBuilder: (_) => [
            if (index > 0)
              PopupMenuItem(
                key: const Key('moveUp'),
                value: _StudyAction.moveUp,
                child: Text(l.moveUp),
              ),
            if (index < count - 1)
              PopupMenuItem(
                key: const Key('moveDown'),
                value: _StudyAction.moveDown,
                child: Text(l.moveDown),
              ),
            if (index > 0)
              CheckedPopupMenuItem(
                key: const Key('toggleParallel'),
                value: _StudyAction.parallel,
                checked: study.parallel,
                child: Text(l.parallelToPrevious),
              ),
            if (index > 0 && !study.parallel && !study.hasConveyor)
              PopupMenuItem(
                key: const Key('addConveyor'),
                value: _StudyAction.conveyor,
                child: Text(l.addConveyor),
              ),
            if (index > 0 && !study.parallel && !study.hasBuffer)
              PopupMenuItem(
                key: const Key('addBuffer'),
                value: _StudyAction.buffer,
                child: Text(l.addBuffer),
              ),
            if (study.mode == StudyMode.simple)
              PopupMenuItem(
                key: const Key('setCycleTime'),
                value: _StudyAction.cycleTime,
                child: Text(l.setCycleTime),
              ),
            PopupMenuItem(
              key: const Key('specialCycles'),
              value: _StudyAction.specialCycles,
              child: Text(l.specialCyclesMenu),
            ),
            PopupMenuItem(
              key: const Key('moveToGroup'),
              value: _StudyAction.moveToGroup,
              child: Text(l.moveToGroup),
            ),
            PopupMenuItem(
              key: const Key('copyToGroup'),
              value: _StudyAction.copyToGroup,
              child: Text(l.copyToGroup),
            ),
            PopupMenuItem(
              key: const Key('removeFromGroup'),
              value: _StudyAction.remove,
              child: Text(l.removeFromGroup),
            ),
          ],
        ),
      ),
    );
  }
}

/// Multi-select of studies to add to the group.
class _PickStudiesDialog extends StatefulWidget {
  const _PickStudiesDialog({required this.candidates, required this.l});

  final List<StudySummary> candidates;
  final AppLocalizations l;

  @override
  State<_PickStudiesDialog> createState() => _PickStudiesDialogState();
}

class _PickStudiesDialogState extends State<_PickStudiesDialog> {
  final _chosen = <int>[];

  @override
  Widget build(BuildContext context) {
    final l = widget.l;
    return AlertDialog(
      title: Text(l.addExistingStudies),
      content: widget.candidates.isEmpty
          ? Text(l.noStudiesToAdd)
          : SizedBox(
              width: double.maxFinite,
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final s in widget.candidates)
                    CheckboxListTile(
                      key: Key('pickStudy_${s.study.id}'),
                      value: _chosen.contains(s.study.id),
                      title: Text(s.study.name),
                      subtitle: s.groupName == null ? null : Text(s.groupName!),
                      onChanged: (v) => setState(() {
                        if (v == true) {
                          _chosen.add(s.study.id);
                        } else {
                          _chosen.remove(s.study.id);
                        }
                      }),
                    ),
                ],
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          key: const Key('addSelectedButton'),
          onPressed: _chosen.isEmpty
              ? null
              : () => Navigator.pop(context, List<int>.of(_chosen)),
          child: Text(l.add),
        ),
      ],
    );
  }
}
