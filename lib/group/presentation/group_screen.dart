import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../backup/data/backup_service.dart';
import '../../backup/presentation/share_actions.dart';
import '../../core/providers.dart';
import '../../export/presentation/export_menu.dart';
import '../../l10n/app_localizations.dart';
import '../../study/domain/study.dart';
import '../../study/presentation/create_study_screen.dart';
import '../../study/presentation/mode_texts.dart';
import '../../study/presentation/study_list_screen.dart' show OpenStudy;
import '../domain/area_selection.dart';
import '../domain/group_member.dart';
import '../domain/group_paths.dart';
import '../domain/study_group.dart';
import '../../settings/presentation/settings_controller.dart';
import '../../core/time_format.dart';
import '../domain/stations.dart';
import 'group_dialogs.dart';
import 'machine_dialogs.dart';
import 'special_cycles_screen.dart';
import 'line_screen.dart';

/// One group: its studies and areas (groups inside the group) in order
/// (drag to reorder), adding, moving, copying and removing studies, adding
/// and arranging areas, editing and deleting the group.
///
/// Station numbers run through the areas like in the line analysis: an
/// area shows the range of its stations ("3–7").
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
  cellLoader,
  cellMachines,
  cellParts,
  waitForSlowest,
  cycleTime,
  buffer,
  conveyor,
  specialCycles,
  moveToGroup,
  copyToGroup,
  remove,
}

enum _GroupAction { edit, share, detach, delete }

enum _AreaAction {
  moveUp,
  moveDown,
  buffer,
  conveyor,
  moveToGroup,
  detach,
  dissolve,
  delete,
}

/// What a group member is within a loader cell.
enum _CellRole { none, machine, loader }

/// An area as its card shows it.
typedef _AreaInfo = ({
  StudyGroup group,
  String label,
  int studies,
  double? cycleTime,
});

class _GroupScreenState extends ConsumerState<GroupScreen> {
  StudyGroup? _group;

  /// The groups above this one, from the top level down.
  List<StudyGroup> _path = const [];

  /// The studies of the group in order (without the areas).
  List<StudySummary> _members = const [];

  /// Studies and areas in group order.
  List<MemberKey> _order = const [];
  Map<int, _AreaInfo> _areas = const {};

  /// Station label per study id, numbered through the areas.
  Map<int, String> _labels = const {};

  /// Number of special cycles per member study.
  Map<int, int> _specialCounts = const {};

  /// Studies of the group and all its areas, and the number of areas below
  /// it (for the delete dialog).
  List<Study> _subtree = const [];
  int _areaCount = 0;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final groups = ref.read(groupRepositoryProvider);
    final group = await groups.getGroup(widget.groupId);
    final below = await groups.descendants(widget.groupId);
    final members = await ref
        .read(studyRepositoryProvider)
        .listStudies(groupId: widget.groupId);
    final counts = await ref.read(specialCycleRepositoryProvider).countFor([
      for (final m in members) m.study.id,
    ]);
    // A plain group (no areas, no parent) needs no more than before.
    final path = group?.parentId == null
        ? const <StudyGroup>[]
        : await groups.ancestors(widget.groupId);
    final areaCount = below.length;
    final mixed = below.isEmpty
        ? [for (final m in members) StudyMember(m.study)]
        : await groups.listMembers(widget.groupId);
    final subtree = below.isEmpty
        ? [for (final m in members) m.study]
        : await groups.subtreeStudies(widget.groupId);
    var labels = <int, String>{};
    final areas = <int, _AreaInfo>{};
    if (mixed.every((m) => m is StudyMember)) {
      final list = stationLabels([for (final m in members) m.study.parallel]);
      labels = {
        for (var i = 0; i < members.length; i++) members[i].study.id: list[i],
      };
    } else {
      // Number the stations through the areas, like the line analysis.
      if (!mounted) return;
      final input = await loadGroupReport(
        ref,
        AppLocalizations.of(context),
        Localizations.localeOf(context).languageCode,
        widget.groupId,
      );
      if (input == null) return;
      final list = stationLabels([
        for (final e in input.entries) e.study.parallel,
      ]);
      labels = {
        for (var i = 0; i < input.entries.length; i++)
          input.entries[i].study.id: list[i],
      };
      for (final f in input.areaFigures) {
        final first = f.firstStation;
        final last = f.lastStation;
        areas[f.area.group.id] = (
          group: f.area.group,
          label: first == null
              ? '–'
              : first == last
              ? '${first + 1}'
              : '${first + 1}–${last! + 1}',
          studies: f.area.end - f.area.start,
          cycleTime: f.cycleTime,
        );
      }
    }
    if (!mounted) return;
    setState(() {
      _group = group;
      _path = path;
      _subtree = subtree;
      _areaCount = areaCount;
      _members = members;
      _order = [for (final m in mixed) m.key];
      _areas = areas;
      _labels = labels;
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

  /// Stores the new order of studies and areas; [moved] is the member that
  /// changed its place, so the stations of the other members stay together.
  Future<void> _reorder(List<MemberKey> order, MemberKey moved) async {
    await ref
        .read(groupRepositoryProvider)
        .reorderMembers(widget.groupId, order, moved: moved);
    await _changed();
  }

  /// Drag reorder; [to] is already adjusted for the removed item.
  Future<void> _onReorder(int from, int to) async {
    final moved = _order[from];
    setState(() {
      _order = [..._order]
        ..removeAt(from)
        ..insert(to, moved);
    });
    await _reorder(_order, moved);
  }

  /// Moves member [key] one place up ([by] = -1) or down (+1).
  Future<void> _step(MemberKey key, int by) async {
    final k = _order.indexOf(key);
    if (k + by < 0 || k + by >= _order.length) return;
    final order = [..._order];
    order.insert(k + by, order.removeAt(k));
    await _reorder(order, key);
  }

  Future<void> _studyAction(_StudyAction action, int index) async {
    final study = _members[index].study;
    switch (action) {
      case _StudyAction.moveUp:
        await _step(MemberKey.study(study.id), -1);
      case _StudyAction.moveDown:
        await _step(MemberKey.study(study.id), 1);
      case _StudyAction.parallel:
        // A loader becomes a plain parallel machine.
        await ref
            .read(groupRepositoryProvider)
            .setParallel(study.id, !study.parallel || study.isCellLoader);
        await _changed();
      case _StudyAction.cellLoader:
        await ref
            .read(groupRepositoryProvider)
            .setCellLoader(study.id, !study.isCellLoader);
        await _changed();
      case _StudyAction.cellMachines:
        final l = AppLocalizations.of(context);
        final n = await showCellCountDialog(
          context,
          title: l.cellMachinesTitle,
          hint: l.cellMachinesHint,
          initial: study.cellMachines,
        );
        if (n == null) return;
        await ref.read(groupRepositoryProvider).setCellMachines(study.id, n);
        await _changed();
      case _StudyAction.cellParts:
        final l = AppLocalizations.of(context);
        final n = await showCellCountDialog(
          context,
          title: l.cellPartsTitle,
          hint: l.cellPartsHint,
          initial: study.cellParts,
        );
        if (n == null) return;
        await ref.read(groupRepositoryProvider).setCellParts(study.id, n);
        await _changed();
      case _StudyAction.waitForSlowest:
        await ref
            .read(groupRepositoryProvider)
            .setWaitForSlowest(study.id, !_stationWaits(index));
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
      case _GroupAction.share:
        await shareSelection(
          context,
          ref,
          ExportSelection(groupIds: {group.id}),
          label: group.name,
        );
      case _GroupAction.detach:
        await ref.read(groupRepositoryProvider).setParent(group.id, null);
        await _changed();
      case _GroupAction.delete:
        final deleted = await deleteGroupInteractively(
          context,
          ref,
          group,
          subtree: _subtree,
          areaCount: _areaCount,
        );
        if (deleted && mounted) {
          Navigator.of(context).maybePop();
        }
    }
  }

  Future<void> _areaAction(_AreaAction action, StudyGroup area) async {
    final groups = ref.read(groupRepositoryProvider);
    switch (action) {
      case _AreaAction.moveUp:
        await _step(MemberKey.area(area.id), -1);
      case _AreaAction.moveDown:
        await _step(MemberKey.area(area.id), 1);
      case _AreaAction.buffer:
        await _editAreaBuffer(area);
      case _AreaAction.conveyor:
        await _editAreaConveyor(area);
      case _AreaAction.moveToGroup:
        final below = await groups.descendants(area.id);
        if (!mounted) return;
        final pick = await pickGroup(
          context,
          ref,
          excludeIds: {area.id, widget.groupId, ...below},
        );
        if (pick == null) return;
        await groups.setParent(area.id, pick.groupId);
        await _changed();
      case _AreaAction.dissolve:
        final l = AppLocalizations.of(context);
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l.dissolveArea),
            content: Text(l.dissolveAreaConfirm(area.name)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l.cancel),
              ),
              TextButton(
                key: const Key('confirmDissolveArea'),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l.dissolveArea),
              ),
            ],
          ),
        );
        if (ok != true) return;
        await groups.dissolveArea(area.id);
        await _changed();
      case _AreaAction.detach:
        await groups.setParent(area.id, null);
        await _changed();
      case _AreaAction.delete:
        if (await deleteGroupInteractively(context, ref, area)) {
          await _changed();
        }
    }
  }

  /// Adds, edits or removes the buffer before [area] in this group.
  Future<void> _editAreaBuffer(StudyGroup area) async {
    final fields = await showBufferDialog(
      context,
      ref.read(settingsProvider).defaultUnit,
      existing: area.hasBuffer
          ? (
              capacity: area.bufferCapacity,
              storeMicros: area.bufferStoreMicros,
              retrieveMicros: area.bufferRetrieveMicros,
            )
          : null,
    );
    if (fields == null) return;
    final groups = ref.read(groupRepositoryProvider);
    if (fields.remove) {
      await groups.removeAreaBuffer(area.id);
    } else {
      await groups.setAreaBuffer(
        area.id,
        capacity: fields.capacity,
        storeMicros: fields.storeMicros,
        retrieveMicros: fields.retrieveMicros,
      );
    }
    await _changed();
  }

  /// Adds, edits or removes the conveyor before [area] in this group.
  Future<void> _editAreaConveyor(StudyGroup area) async {
    final fields = await showConveyorDialog(
      context,
      ref.read(settingsProvider).defaultUnit,
      existing: area.hasConveyor
          ? (
              capacity: area.conveyorCapacity,
              transportMicros: area.conveyorTransportMicros,
            )
          : null,
    );
    if (fields == null) return;
    final groups = ref.read(groupRepositoryProvider);
    if (fields.remove) {
      await groups.removeAreaConveyor(area.id);
    } else {
      await groups.setAreaConveyor(
        area.id,
        capacity: fields.capacity,
        transportMicros: fields.transportMicros,
      );
    }
    await _changed();
  }

  Future<void> _openArea(int id) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            GroupScreen(groupId: id, onOpenStudy: widget.onOpenStudy),
      ),
    );
    await _changed();
  }

  /// Adds a group of the top level as an area (not this group itself and
  /// none of the groups it lies in).
  Future<void> _addExistingGroup() async {
    final l = AppLocalizations.of(context);
    final blocked = {widget.groupId, for (final g in _path) g.id};
    final candidates = [
      for (final g in await ref.read(groupRepositoryProvider).listGroups())
        if (g.group.parentId == null && !blocked.contains(g.group.id)) g,
    ];
    if (!mounted) return;
    final chosen = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l.addExistingGroup),
        children: [
          if (candidates.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(l.noGroupsToAdd),
            ),
          for (final g in candidates)
            SimpleDialogOption(
              key: Key('addGroupChoice_${g.group.id}'),
              onPressed: () => Navigator.pop(ctx, g.group.id),
              child: ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(g.group.name),
                subtitle: Text(
                  g.areaCount > 0
                      ? l.groupAreaCount(g.areaCount, g.totalStudyCount)
                      : l.groupStudyCount(g.studyCount),
                ),
              ),
            ),
        ],
      ),
    );
    if (chosen == null) return;
    await ref.read(groupRepositoryProvider).setParent(chosen, widget.groupId);
    await _changed();
  }

  /// Creates a new group inside this one and opens it.
  Future<void> _addNewArea() async {
    final fields = await showGroupDialog(context);
    if (fields == null) return;
    final groups = ref.read(groupRepositoryProvider);
    final id = await groups.createGroup(
      name: fields.name,
      description: fields.description,
      now: ref.read(wallClockProvider)(),
    );
    await groups.setParent(id, widget.groupId);
    await _changed();
    if (mounted) await _openArea(id);
  }

  Future<void> _add() async {
    final l = AppLocalizations.of(context);
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      // Five entries need more than half of a phone screen.
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: SingleChildScrollView(
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
              ListTile(
                key: const Key('addNewArea'),
                leading: const Icon(Icons.account_tree_outlined),
                title: Text(l.addNewArea),
                subtitle: Text(l.addNewAreaHint),
                onTap: () => Navigator.pop(sheet, 'newArea'),
              ),
              ListTile(
                key: const Key('addExistingGroup'),
                leading: const Icon(Icons.drive_file_move_outline),
                title: Text(l.addExistingGroup),
                subtitle: Text(l.addExistingGroupHint),
                onTap: () => Navigator.pop(sheet, 'existingGroup'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (choice == 'new') await _addNew();
    if (choice == 'existing') await _addExisting();
    if (choice == 'machine') await _addMachine();
    if (choice == 'newArea') await _addNewArea();
    if (choice == 'existingGroup') await _addExistingGroup();
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
      // Nothing works in parallel with an area.
      canBeParallel: _order.isNotEmpty && !_order.last.isArea,
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

  /// Members selected to become an area (long press); empty = no
  /// selection. Always whole stations.
  Set<MemberKey> _selected = const {};

  /// Station flags of the current order (an area is a station of its own).
  List<bool> get _flags {
    final byId = {for (final m in _members) m.study.id: m.study.parallel};
    return stationFlags(
      [for (final k in _order) !k.isArea && (byId[k.id] ?? false)],
      [for (final k in _order) k.isArea],
    );
  }

  /// Selects or deselects [key] with its whole station.
  void _toggle(MemberKey key) => setState(() {
    final station = expandToStations(_order, _flags, {key});
    _selected = _selected.contains(key)
        ? _selected.difference(station)
        : {..._selected, ...station};
  });

  /// Makes the selected members an area named by the user.
  Future<void> _groupSelected() async {
    final fields = await showGroupDialog(context);
    if (fields == null) return;
    await ref
        .read(groupRepositoryProvider)
        .groupIntoArea(
          widget.groupId,
          [
            for (final k in _order)
              if (_selected.contains(k)) k,
          ],
          name: fields.name,
          description: fields.description,
          now: ref.read(wallClockProvider)(),
        );
    setState(() => _selected = const {});
    await _changed();
  }

  PreferredSizeWidget _selectionBar(AppLocalizations l) {
    final contiguous = isContiguous(_order, _selected);
    return AppBar(
      leading: IconButton(
        key: const Key('clearSelection'),
        tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
        icon: const Icon(Icons.close),
        onPressed: () => setState(() => _selected = const {}),
      ),
      title: Text(l.selectedCount(_selected.length)),
      actions: [
        IconButton(
          key: const Key('groupIntoArea'),
          tooltip: l.groupIntoArea,
          icon: const Icon(Icons.account_tree_outlined),
          onPressed: contiguous ? _groupSelected : null,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final selecting = _selected.isNotEmpty;
    return PopScope(
      canPop: !selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _selected = const {});
      },
      child: _scaffold(l, theme, selecting),
    );
  }

  Widget _scaffold(AppLocalizations l, ThemeData theme, bool selecting) {
    return Scaffold(
      appBar: selecting
          ? _selectionBar(l)
          : AppBar(
              title: _path.isEmpty
                  ? Text(_group?.name ?? '')
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          [for (final g in _path) g.name]
                              .join(groupPathSeparator),
                          key: const Key('groupPath'),
                          style: theme.textTheme.labelMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _group?.name ?? '',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
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
                      key: const Key('shareGroup'),
                      value: _GroupAction.share,
                      child: Text(l.shareGroup),
                    ),
                    if (_group?.parentId != null)
                      PopupMenuItem(
                        key: const Key('detachFromParent'),
                        value: _GroupAction.detach,
                        child: Text(l.detachFromParent),
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
      floatingActionButton: selecting
          ? null
          : FloatingActionButton.extended(
              key: const Key('addStudiesFab'),
              onPressed: _add,
              icon: const Icon(Icons.add),
              label: Text(l.addStudies),
            ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : _order.isEmpty
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
                if (selecting && !isContiguous(_order, _selected))
                  Padding(
                    key: const Key('selectionGapHint'),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Text(
                      l.selectionGapHint,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Text(
                      l.reorderHint,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                Expanded(child: _list()),
              ],
            ),
    );
  }

  /// Index of the first machine of the station of member [index].
  int _stationHead(int index) =>
      stationGroups([for (final m in _members) m.study.parallel])
          .firstWhere((station) => station.contains(index))
          .first;

  /// Whether the station of member [index] waits for its slowest machine.
  bool _stationWaits(int index) =>
      _members[_stationHead(index)].study.waitForSlowest;

  Widget _list() {
    final parallel = [for (final m in _members) m.study.parallel];
    final unit = ref.read(settingsProvider).defaultUnit;
    final studyIndex = {
      for (var i = 0; i < _members.length; i++) _members[i].study.id: i,
    };
    // A station with a loader is a loader cell: its other members are the
    // machines the loaders serve.
    final roles = List.filled(_members.length, _CellRole.none);
    for (final station in stationGroups(parallel)) {
      bool loader(int i) =>
          i != station.first && _members[i].study.isCellLoader;
      if (!station.any(loader)) continue;
      for (final i in station) {
        roles[i] = loader(i) ? _CellRole.loader : _CellRole.machine;
      }
    }
    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
      itemCount: _order.length,
      onReorderItem: _onReorder,
      itemBuilder: (context, k) {
        final key = _order[k];
        if (key.isArea) {
          final area = _areas[key.id];
          return _AreaTile(
            key: ValueKey('areaItem_${key.id}'),
            index: k,
            count: _order.length,
            area: area,
            areaId: key.id,
            unit: unit,
            selected: _selected.contains(key),
            onLongPress: () => _toggle(key),
            onTap: _selected.isNotEmpty
                ? () => _toggle(key)
                : () => _openArea(key.id),
            onAction: (a) {
              if (area != null) _areaAction(a, area.group);
            },
          );
        }
        final i = studyIndex[key.id]!;
        final label = _labels[key.id] ?? '';
        return _MemberTile(
          key: ValueKey(key.id),
          index: k,
          count: _order.length,
          afterArea: k > 0 && _order[k - 1].isArea,
          label: label,
          cellRole: roles[i],
          // Parallel machines carry a letter ("2a").
          inStation: RegExp('[a-z]').hasMatch(label),
          stationWaits: _stationWaits(i),
          stationHead: _stationHead(i) == i,
          summary: _members[i],
          selected: _selected.contains(key),
          onLongPress: () => _toggle(key),
          onTap: _selected.isNotEmpty
              ? () => _toggle(key)
              : () => _open(key.id),
          onAction: (a) => _studyAction(a, i),
          onBuffer: () => _editBuffer(_members[i].study),
          onConveyor: () => _editConveyor(_members[i].study),
          specialCount: _specialCounts[key.id] ?? 0,
          unit: unit,
        );
      },
    );
  }
}

/// Card of an area (a group inside the group): its station range, its
/// studies and its cycle time; opens the area on tap.
class _AreaTile extends StatelessWidget {
  const _AreaTile({
    super.key,
    required this.index,
    required this.count,
    required this.area,
    required this.areaId,
    required this.unit,
    required this.onTap,
    required this.onAction,
    this.selected = false,
    this.onLongPress,
  });

  /// Part of the selection that may become an area.
  final bool selected;
  final VoidCallback? onLongPress;

  final int index;
  final int count;

  /// Null while the figures are loading.
  final _AreaInfo? area;
  final int areaId;
  final TimeUnit unit;
  final VoidCallback onTap;
  final ValueChanged<_AreaAction> onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final group = area?.group;
    // What stands before the area in this group (not before the first
    // member, where nothing stands).
    final showConveyor = index > 0 && (group?.hasConveyor ?? false);
    final showBuffer = index > 0 && (group?.hasBuffer ?? false);
    final card = _card(context, theme);
    if (group == null || (!showBuffer && !showConveyor)) return card;
    final l = AppLocalizations.of(context);
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
            key: Key('areaConveyor_$areaId'),
            margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 32),
            color: theme.colorScheme.surfaceContainerHighest,
            child: ListTile(
              dense: true,
              onTap: () => onAction(_AreaAction.conveyor),
              leading: const Icon(Icons.linear_scale),
              title: Text(l.conveyorCard(group.conveyorCapacity)),
              subtitle: Text(
                l.conveyorTransport(t(group.conveyorTransportMicros)),
              ),
              trailing: const Icon(Icons.edit_outlined, size: 18),
            ),
          ),
        if (showBuffer)
          Card(
            key: Key('areaBuffer_$areaId'),
            margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 32),
            color: theme.colorScheme.secondaryContainer,
            child: ListTile(
              dense: true,
              onTap: () => onAction(_AreaAction.buffer),
              leading: const Icon(Icons.inventory_2_outlined),
              title: Text(l.bufferPlaces(group.bufferCapacity)),
              subtitle: Text(
                l.bufferTimes(
                  t(group.bufferStoreMicros),
                  t(group.bufferRetrieveMicros),
                ),
              ),
              trailing: const Icon(Icons.edit_outlined, size: 18),
            ),
          ),
        card,
      ],
    );
  }

  Widget _card(BuildContext context, ThemeData theme) {
    final l = AppLocalizations.of(context);
    final a = area;
    final cycle = a?.cycleTime;
    return Card(
      key: Key('area_$areaId'),
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: selected
          ? theme.colorScheme.secondaryContainer
          : theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
      child: ListTile(
        onTap: onTap,
        onLongPress: onLongPress,
        leading: ReorderableDragStartListener(
          index: index,
          child: const Padding(
            padding: EdgeInsets.all(8),
            child: Icon(Icons.drag_handle),
          ),
        ),
        title: Row(
          children: [
            Icon(
              Icons.account_tree_outlined,
              size: 18,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '${a?.label ?? '–'}. ${a?.group.name ?? ''}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        subtitle: Text(
          [
            l.areaLabel,
            l.groupStudyCount(a?.studies ?? 0),
            if (cycle != null)
              l.areaCycleTime(
                formatTime(
                  cycle.round(),
                  unit,
                  locale: Localizations.localeOf(context).languageCode,
                ),
              ),
          ].join(' · '),
        ),
        trailing: PopupMenuButton<_AreaAction>(
          key: Key('areaMenu_$areaId'),
          onSelected: onAction,
          itemBuilder: (_) => [
            if (index > 0)
              PopupMenuItem(
                key: const Key('areaMoveUp'),
                value: _AreaAction.moveUp,
                child: Text(l.moveUp),
              ),
            if (index < count - 1)
              PopupMenuItem(
                key: const Key('areaMoveDown'),
                value: _AreaAction.moveDown,
                child: Text(l.moveDown),
              ),
            if (index > 0 && !(a?.group.hasConveyor ?? true))
              PopupMenuItem(
                key: const Key('areaAddConveyor'),
                value: _AreaAction.conveyor,
                child: Text(l.addConveyor),
              ),
            if (index > 0 && !(a?.group.hasBuffer ?? true))
              PopupMenuItem(
                key: const Key('areaAddBuffer'),
                value: _AreaAction.buffer,
                child: Text(l.addBuffer),
              ),
            PopupMenuItem(
              key: const Key('areaMoveToGroup'),
              value: _AreaAction.moveToGroup,
              child: Text(l.moveToGroup),
            ),
            PopupMenuItem(
              key: const Key('detachArea'),
              value: _AreaAction.detach,
              child: Text(l.detachArea),
            ),
            PopupMenuItem(
              key: const Key('dissolveArea'),
              value: _AreaAction.dissolve,
              child: Text(l.dissolveArea),
            ),
            PopupMenuItem(
              key: const Key('deleteArea'),
              value: _AreaAction.delete,
              child: Text(l.deleteGroup),
            ),
          ],
        ),
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
    required this.stationWaits,
    required this.stationHead,
    required this.summary,
    required this.onTap,
    required this.onAction,
    required this.onBuffer,
    required this.onConveyor,
    required this.unit,
    this.specialCount = 0,
    this.cellRole = _CellRole.none,
    this.afterArea = false,
    this.selected = false,
    this.onLongPress,
  });

  /// Part of the selection that may become an area.
  final bool selected;
  final VoidCallback? onLongPress;

  /// Stands right behind an area: nothing can work in parallel with an
  /// area, so it is always the first machine of its station.
  final bool afterArea;

  /// Role of the member in the loader cell its station forms.
  final _CellRole cellRole;

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

  /// The station waits for its slowest machine (only with [inStation]).
  final bool stationWaits;

  /// First machine of its station.
  final bool stationHead;
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
    final figures = Text(
      '${study.mode.title(l)} · ${summary.cycleCount} '
      '${study.mode == StudyMode.simple
          ? l.lapsLabel
          : study.mode == StudyMode.stepTimer
          ? l.measurementsLabel
          : l.cyclesLabel}'
      '${specialCount > 0 ? ' · ${l.specialCycleCount(specialCount)}' : ''}'
      '${switch (cellRole) {
        _CellRole.none => '',
        _CellRole.machine => '\n${l.cellRoleMachines(study.cellMachines)}',
        _CellRole.loader => '\n${l.cellRoleLoaderParts(study.cellParts)}',
      }}',
    );
    // A loader cell is no station of parallel machines: it cannot wait for
    // its slowest machine.
    final canWait = inStation && cellRole == _CellRole.none;
    return Card(
      margin: EdgeInsets.only(
        top: 4,
        bottom: 4,
        left: study.parallel && index > 0 ? 24 : 0,
      ),
      color: selected ? theme.colorScheme.secondaryContainer : null,
      shape: inStation
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.colorScheme.tertiary, width: 1.5),
            )
          : null,
      child: ListTile(
        onTap: onTap,
        onLongPress: onLongPress,
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
        subtitle: canWait && stationWaits && stationHead
            // Said once per station, on its first machine.
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  figures,
                  Text(
                    l.stationWaitsForSlowest,
                    key: Key('stationWaits_${study.id}'),
                    style: TextStyle(color: theme.colorScheme.tertiary),
                  ),
                ],
              )
            : figures,
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
            if (index > 0 && !afterArea)
              CheckedPopupMenuItem(
                key: const Key('toggleParallel'),
                value: _StudyAction.parallel,
                checked: study.parallel && !study.isCellLoader,
                child: Text(l.parallelToPrevious),
              ),
            if (index > 0 && !afterArea)
              CheckedPopupMenuItem(
                key: const Key('toggleCellLoader'),
                value: _StudyAction.cellLoader,
                checked: study.isCellLoader,
                child: Text(l.cellLoaderToggle),
              ),
            if (cellRole == _CellRole.machine)
              PopupMenuItem(
                key: const Key('setCellMachines'),
                value: _StudyAction.cellMachines,
                child: Text(l.cellMachinesMenu),
              ),
            if (cellRole == _CellRole.loader)
              PopupMenuItem(
                key: const Key('setCellParts'),
                value: _StudyAction.cellParts,
                child: Text(l.cellPartsMenu),
              ),
            if (canWait)
              CheckedPopupMenuItem(
                key: const Key('toggleWaitForSlowest'),
                value: _StudyAction.waitForSlowest,
                checked: stationWaits,
                child: Text(l.waitForSlowest),
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
