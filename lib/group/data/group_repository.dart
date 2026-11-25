import 'package:sqflite/sqflite.dart';

import '../../core/database.dart';
import '../../study/data/study_repository.dart';
import '../../study/domain/study.dart';
import '../domain/area_selection.dart';
import '../domain/group_member.dart';
import '../domain/stations.dart';
import '../domain/study_group.dart';

/// Persistence of study groups and the membership/order of their members.
///
/// A study belongs to at most one group (`study.group_id`); its place in the
/// group is `study.group_position`. The studies of a group are listed by
/// `StudyRepository.listStudies(groupId: ...)`.
///
/// A group lies in at most one parent group (`study_group.parent_id`); it
/// is then an area of that group, at `study_group.parent_position` – the
/// same position space as the studies of the parent. [listMembers] lists
/// studies and areas together. Groups never form a cycle.
class GroupRepository {
  GroupRepository(this._db);

  final AppDatabase _db;

  Future<int> createGroup({
    required String name,
    String description = '',
    required DateTime now,
  }) => _db.db.insert('study_group', {
    'name': name,
    'description': description,
    'created_at': now.millisecondsSinceEpoch,
  });

  Future<void> updateGroup(
    int id, {
    required String name,
    required String description,
  }) => _db.db.update(
    'study_group',
    {'name': name, 'description': description},
    where: 'id = ?',
    whereArgs: [id],
  );

  /// Deletes the group; its studies stay, without a group, and its areas
  /// become groups of the top level. With [withStudies] the whole subtree
  /// goes: all areas below the group and the studies of the group and of
  /// those areas, with their steps, times, revisions and special cycles
  /// (video files are left to the caller: get the studies from
  /// [subtreeStudies] before and see `deleteUnusedVideo`).
  Future<void> deleteGroup(
    int id, {
    bool withStudies = false,
  }) => _db.db.transaction((txn) async {
    // Areas that stay lose what stood before them in this group.
    await txn.update(
      'study_group',
      _noBuffer,
      where: 'parent_id = ?',
      whereArgs: [id],
    );
    final ids = [id, if (withStudies) ...await _descendants(txn, id)];
    final marks = List.filled(ids.length, '?').join(', ');
    if (withStudies) {
      await txn.delete('study', where: 'group_id IN ($marks)', whereArgs: ids);
    }
    await txn.delete('study_group', where: 'id IN ($marks)', whereArgs: ids);
  });

  /// The studies of group [groupId] and of all areas below it.
  Future<List<Study>> subtreeStudies(int groupId) async {
    final ids = [groupId, ...await _descendants(_db.db, groupId)];
    final rows = await _db.db.query(
      'study',
      where: 'group_id IN (${List.filled(ids.length, '?').join(', ')})',
      whereArgs: ids,
      orderBy: 'id',
    );
    return [for (final r in rows) StudyRepository.studyFromRow(r)];
  }

  Future<StudyGroup?> getGroup(int id) async {
    final rows = await _db.db.query(
      'study_group',
      where: 'id = ?',
      whereArgs: [id],
    );
    return rows.isEmpty ? null : groupFromRow(rows.first);
  }

  /// All groups by name with their number of studies and areas.
  Future<List<GroupSummary>> listGroups() async {
    final rows = await _db.db.rawQuery(
      'SELECT g.*, (SELECT COUNT(*) FROM study s WHERE s.group_id = g.id) '
      'AS n FROM study_group g ORDER BY g.name COLLATE NOCASE, g.id',
    );
    final direct = {for (final r in rows) r['id'] as int: r['n'] as int};
    final children = <int, List<int>>{};
    for (final r in rows) {
      final parent = r['parent_id'] as int?;
      if (parent != null) (children[parent] ??= []).add(r['id'] as int);
    }
    int total(int id) => (children[id] ?? const <int>[]).fold(
      direct[id]!,
      (n, child) => n + total(child),
    );
    return [
      for (final r in rows)
        GroupSummary(
          group: groupFromRow(r),
          studyCount: r['n'] as int,
          areaCount: children[r['id']]?.length ?? 0,
          totalStudyCount: total(r['id'] as int),
        ),
    ];
  }

  /// Studies and areas of group [groupId] in group order.
  Future<List<GroupMember>> listMembers(int groupId) async {
    final studyRows = await _db.db.query(
      'study',
      where: 'group_id = ?',
      whereArgs: [groupId],
    );
    final areaRows = await _db.db.query(
      'study_group',
      where: 'parent_id = ?',
      whereArgs: [groupId],
    );
    final members = <GroupMember>[
      for (final r in studyRows) StudyMember(StudyRepository.studyFromRow(r)),
      for (final r in areaRows) AreaMember(groupFromRow(r)),
    ];
    int rank(GroupMember m) => m is AreaMember ? 1 : 0;
    members.sort((a, b) {
      final byPosition = a.position.compareTo(b.position);
      if (byPosition != 0) return byPosition;
      final byKind = rank(a).compareTo(rank(b));
      return byKind != 0 ? byKind : a.key.id.compareTo(b.key.id);
    });
    return members;
  }

  /// The members of group [groupId] and of every area below it, by group
  /// id – the input of `flattenGroup`.
  Future<Map<int, List<GroupMember>>> loadTree(int groupId) async {
    final tree = <int, List<GroupMember>>{};
    final open = [groupId];
    while (open.isNotEmpty) {
      final id = open.removeLast();
      if (tree.containsKey(id)) continue;
      final members = await listMembers(id);
      tree[id] = members;
      open.addAll([
        for (final m in members)
          if (m is AreaMember) m.group.id,
      ]);
    }
    return tree;
  }

  /// Puts group [groupId] as an area at the end of group [parentId]; null
  /// makes it a group of the top level. Throws [GroupCycleException] (and
  /// changes nothing) if [parentId] is the group itself or lies below it.
  Future<void> setParent(int groupId, int? parentId) =>
      _db.db.transaction((txn) async {
        if (parentId != null &&
            (parentId == groupId ||
                (await _descendants(txn, groupId)).contains(parentId))) {
          throw GroupCycleException(groupId, parentId);
        }
        final old = await txn.query(
          'study_group',
          columns: ['parent_id'],
          where: 'id = ?',
          whereArgs: [groupId],
        );
        final oldParent = old.isEmpty ? null : old.first['parent_id'] as int?;
        final position = parentId == null
            ? 0
            : await StudyRepository.nextGroupPosition(txn, parentId);
        await txn.update(
          'study_group',
          {
            'parent_id': parentId,
            'parent_position': position,
            // The link before the area belongs to its old place.
            ..._noBuffer,
          },
          where: 'id = ?',
          whereArgs: [groupId],
        );
        if (oldParent != null) {
          await StudyRepository.tidyStations(txn, oldParent);
        }
      });

  /// Makes [members] of group [groupId] – whole stations in a row (see
  /// `expandToStations`, `isContiguous`) – a new area named [name] at the
  /// place of the first of them; returns its id. Everything inside keeps
  /// its fields (parallel, loaders, waiting, buffers and conveyors, areas
  /// become sub-areas). What stood before the first member (buffer,
  /// conveyor) becomes the link before the new area, unless the members
  /// start the group. The flattened line stays the same. Throws an
  /// [ArgumentError] (and changes nothing) for any other selection.
  Future<int> groupIntoArea(
    int groupId,
    List<MemberKey> members, {
    required String name,
    String description = '',
    required DateTime now,
  }) => _db.db.transaction((txn) async {
    final rows = await StudyRepository.memberRows(txn, groupId);
    final order = [for (final r in rows) _key(r)];
    final selected = members.toSet();
    final flags = StudyRepository.memberStationFlags(rows);
    if (!selected.every(order.contains) ||
        !isContiguous(order, selected) ||
        expandToStations(order, flags, selected).length != selected.length) {
      throw ArgumentError.value(
        members,
        'members',
        'must be whole stations in a row of group $groupId',
      );
    }
    final at = [
      for (var k = 0; k < order.length; k++)
        if (selected.contains(order[k])) k,
    ];
    final first = order[at.first];
    final link = at.first == 0 ? null : await _linkOf(txn, first);
    final id = await txn.insert('study_group', {
      'name': name,
      'description': description,
      'created_at': now.millisecondsSinceEpoch,
      'parent_id': groupId,
      'parent_position': rows[at.first]['pos'],
      ...?link,
    });
    if (link != null) await _setLink(txn, first, _noBuffer);
    for (var k = 0; k < at.length; k++) {
      await _place(txn, order[at[k]], id, k);
    }
    await StudyRepository.tidyStations(txn, groupId);
    await StudyRepository.tidyStations(txn, id);
    return id;
  });

  /// Dissolves area [areaId]: its members take its place in its parent
  /// group in their order (sub-areas move up one level), the link before
  /// the area goes to its first member, and the empty group is deleted.
  /// The flattened line stays the same. Throws a [StateError] for a group
  /// of the top level.
  Future<void> dissolveArea(int areaId) => _db.db.transaction((txn) async {
    final area = await txn.query(
      'study_group',
      where: 'id = ?',
      whereArgs: [areaId],
    );
    final parent = area.isEmpty ? null : area.first['parent_id'] as int?;
    if (parent == null) {
      throw StateError('group $areaId lies in no other group');
    }
    final outer = [
      for (final r in await StudyRepository.memberRows(txn, parent)) _key(r),
    ];
    final inner = [
      for (final r in await StudyRepository.memberRows(txn, areaId)) _key(r),
    ];
    final at = outer.indexOf(MemberKey.area(areaId));
    final order = [...outer.take(at), ...inner, ...outer.skip(at + 1)];
    final link = {
      for (final c in StudyRepository.stationLinkColumns) c: area.first[c],
    };
    if (inner.isNotEmpty && link.values.any((v) => v != 0)) {
      await _setLink(txn, inner.first, link);
    }
    for (var k = 0; k < order.length; k++) {
      await _place(txn, order[k], parent, k);
    }
    await txn.delete('study_group', where: 'id = ?', whereArgs: [areaId]);
    await StudyRepository.tidyStations(txn, parent);
  });

  /// What stands before member [key] (buffer and conveyor columns).
  static Future<Map<String, Object?>> _linkOf(
    DatabaseExecutor db,
    MemberKey key,
  ) async {
    final rows = await db.query(
      key.isArea ? 'study_group' : 'study',
      columns: StudyRepository.stationLinkColumns,
      where: 'id = ?',
      whereArgs: [key.id],
    );
    return rows.first;
  }

  static Future<void> _setLink(
    DatabaseExecutor db,
    MemberKey key,
    Map<String, Object?> link,
  ) => db.update(
    key.isArea ? 'study_group' : 'study',
    link,
    where: 'id = ?',
    whereArgs: [key.id],
  );

  /// Puts member [key] into group [groupId] at [position].
  static Future<void> _place(
    DatabaseExecutor db,
    MemberKey key,
    int groupId,
    int position,
  ) => key.isArea
      ? db.update(
          'study_group',
          {'parent_id': groupId, 'parent_position': position},
          where: 'id = ?',
          whereArgs: [key.id],
        )
      : db.update(
          'study',
          {'group_id': groupId, 'group_position': position},
          where: 'id = ?',
          whereArgs: [key.id],
        );

  /// The groups above group [groupId], from the top level down to its
  /// parent; empty for a group of the top level.
  Future<List<StudyGroup>> ancestors(int groupId) async {
    final result = <StudyGroup>[];
    final seen = {groupId};
    var parent = (await getGroup(groupId))?.parentId;
    while (parent != null && seen.add(parent)) {
      final group = await getGroup(parent);
      if (group == null) break;
      result.insert(0, group);
      parent = group.parentId;
    }
    return result;
  }

  /// Ids of all groups below group [groupId] (its areas, their areas and
  /// so on), without the group itself.
  Future<List<int>> descendants(int groupId) => _descendants(_db.db, groupId);

  static Future<List<int>> _descendants(
    DatabaseExecutor db,
    int groupId,
  ) async {
    final rows = await db.rawQuery(
      'WITH RECURSIVE sub(id) AS ('
      'SELECT id FROM study_group WHERE parent_id = ? '
      'UNION SELECT g.id FROM study_group g JOIN sub ON g.parent_id = sub.id'
      ') SELECT id FROM sub',
      [groupId],
    );
    return [for (final r in rows) r['id'] as int];
  }

  /// Puts study [studyId] at the end of group [groupId]; null removes it
  /// from its group.
  Future<void> moveToGroup(int studyId, int? groupId) =>
      _db.db.transaction((txn) async {
        final left = await StudyRepository.handOverStation(txn, studyId);
        final position = groupId == null
            ? 0
            : await StudyRepository.nextGroupPosition(txn, groupId);
        await txn.update(
          'study',
          {
            'group_id': groupId,
            'group_position': position,
            'parallel': 0,
            ..._noCell,
            StudyRepository.waitColumn: 0,
            ..._noBuffer,
          },
          where: 'id = ?',
          whereArgs: [studyId],
        );
        if (left != null) await StudyRepository.tidyStations(txn, left);
      });

  /// Marks study [studyId] as working in parallel with the group member
  /// before it.
  ///
  /// A member working in parallel is no station of its own, so it loses
  /// its buffer; its station follows the option of the station it joins. A
  /// member switched back to serial keeps the option of the station it
  /// leaves for itself and the machines behind it.
  ///
  /// Either way the member is no loader of a cell (any more), see
  /// [setCellLoader].
  ///
  /// A study right behind an area cannot work in parallel (an area is
  /// always a station boundary); switching it on does nothing there.
  Future<void> setParallel(int studyId, bool parallel) =>
      _db.db.transaction((txn) async {
        if (parallel && await _behindArea(txn, studyId)) return;
        final station = await _stationOf(txn, studyId);
        await txn.update(
          'study',
          {
            'parallel': parallel ? 1 : 0,
            'cell_loader': 0,
            if (parallel) ..._noBuffer,
            if (!parallel && station != null)
              StudyRepository.waitColumn: station.waits ? 1 : 0,
          },
          where: 'id = ?',
          whereArgs: [studyId],
        );
        if (station != null) {
          await StudyRepository.tidyStations(txn, station.groupId);
        }
      });

  /// Sets whether the station of study [studyId] (any of its machines)
  /// waits for its slowest machine: the parallel machines each make a part
  /// of one unit instead of sharing the work. Nothing happens for a
  /// station with a single machine and for a loader cell.
  Future<void> setWaitForSlowest(int studyId, bool wait) =>
      _db.db.transaction((txn) async {
        final station = await _stationOf(txn, studyId);
        if (station == null || station.ids.length < 2 || station.isCell) {
          return;
        }
        await txn.update(
          'study',
          {StudyRepository.waitColumn: wait ? 1 : 0},
          where: 'id = ?',
          whereArgs: [station.ids.first],
        );
      });

  /// The station of group member [studyId]: its machines in order,
  /// whether it waits for its slowest machine and whether it is a loader
  /// cell. Null without a group.
  static Future<({int groupId, List<int> ids, bool waits, bool isCell})?>
  _stationOf(DatabaseExecutor db, int studyId) async {
    final groupId = await StudyRepository.groupOf(db, studyId);
    if (groupId == null) return null;
    final members = await StudyRepository.memberRows(db, groupId);
    final station = stationGroups(StudyRepository.memberStationFlags(members))
        .firstWhere((s) => s.any((k) => _isStudy(members[k], studyId)));
    return (
      groupId: groupId,
      ids: [for (final k in station) members[k]['id'] as int],
      waits: members[station.first][StudyRepository.waitColumn] == 1,
      isCell: station.skip(1).any((k) => members[k]['cell_loader'] == 1),
    );
  }

  static bool _isStudy(Map<String, Object?> row, int studyId) =>
      row['area'] == 0 && row['id'] == studyId;

  /// Whether study [studyId] stands right behind an area in its group.
  static Future<bool> _behindArea(DatabaseExecutor db, int studyId) async {
    final groupId = await StudyRepository.groupOf(db, studyId);
    if (groupId == null) return false;
    final members = await StudyRepository.memberRows(db, groupId);
    final i = members.indexWhere((m) => _isStudy(m, studyId));
    return i > 0 && members[i - 1]['area'] == 1;
  }

  /// Makes study [studyId] a loader of the station of the group member
  /// before it, which turns that station into a loader cell: the loader
  /// serves the station's machines instead of being a machine itself. Like
  /// a parallel machine it is no station of its own (no buffer, no
  /// conveyor). Switching the role off makes it a station of its own.
  ///
  /// A loader cell never waits for its slowest machine, see
  /// [StudyRepository.tidyStations]. A study right behind an area cannot be
  /// a loader; switching it on does nothing there.
  Future<void> setCellLoader(int studyId, bool loader) =>
      _db.db.transaction((txn) async {
        if (loader && await _behindArea(txn, studyId)) return;
        await txn.update(
          'study',
          {
            'parallel': loader ? 1 : 0,
            'cell_loader': loader ? 1 : 0,
            if (loader) ..._noBuffer,
          },
          where: 'id = ?',
          whereArgs: [studyId],
        );
        final groupId = await StudyRepository.groupOf(txn, studyId);
        if (groupId != null) {
          await StudyRepository.tidyStations(txn, groupId);
        }
      });

  /// Parts the loader [studyId] handles per own cycle (at least 1).
  Future<void> setCellParts(int studyId, int parts) =>
      _setCount(studyId, 'cell_parts', parts);

  /// Number of equal machines study [studyId] stands for in a loader cell
  /// (at least 1).
  Future<void> setCellMachines(int studyId, int machines) =>
      _setCount(studyId, 'cell_machines', machines);

  Future<void> _setCount(int studyId, String column, int value) {
    if (value < 1) throw ArgumentError.value(value, column, 'must be >= 1');
    return _db.db.update(
      'study',
      {column: value},
      where: 'id = ?',
      whereArgs: [studyId],
    );
  }

  /// Puts a buffer before the station of study [studyId].
  Future<void> setBuffer(
    int studyId, {
    required int capacity,
    required int storeMicros,
    required int retrieveMicros,
  }) => _db.db.update(
    'study',
    {
      'buffer_capacity': capacity,
      'buffer_store_us': storeMicros,
      'buffer_retrieve_us': retrieveMicros,
    },
    where: 'id = ?',
    whereArgs: [studyId],
  );

  Future<void> removeBuffer(int studyId) =>
      _db.db.update('study', _noBuffer, where: 'id = ?', whereArgs: [studyId]);

  /// Puts a conveyor before the station of study [studyId].
  Future<void> setConveyor(
    int studyId, {
    required int capacity,
    required int transportMicros,
  }) => _db.db.update(
    'study',
    {'conveyor_capacity': capacity, 'conveyor_transport_us': transportMicros},
    where: 'id = ?',
    whereArgs: [studyId],
  );

  Future<void> removeConveyor(int studyId) => _db.db.update(
    'study',
    {'conveyor_capacity': 0, 'conveyor_transport_us': 0},
    where: 'id = ?',
    whereArgs: [studyId],
  );

  /// Puts a buffer before area [groupId] in its parent group. It belongs
  /// to the plant: it works on the area's first station in the parent's
  /// line, not in the area alone, and is dropped when the area leaves its
  /// parent.
  Future<void> setAreaBuffer(
    int groupId, {
    required int capacity,
    required int storeMicros,
    required int retrieveMicros,
  }) => _db.db.update(
    'study_group',
    {
      'buffer_capacity': capacity,
      'buffer_store_us': storeMicros,
      'buffer_retrieve_us': retrieveMicros,
    },
    where: 'id = ?',
    whereArgs: [groupId],
  );

  Future<void> removeAreaBuffer(int groupId) => _db.db.update(
    'study_group',
    {'buffer_capacity': 0, 'buffer_store_us': 0, 'buffer_retrieve_us': 0},
    where: 'id = ?',
    whereArgs: [groupId],
  );

  /// Puts a conveyor before area [groupId] in its parent group, see
  /// [setAreaBuffer].
  Future<void> setAreaConveyor(
    int groupId, {
    required int capacity,
    required int transportMicros,
  }) => _db.db.update(
    'study_group',
    {'conveyor_capacity': capacity, 'conveyor_transport_us': transportMicros},
    where: 'id = ?',
    whereArgs: [groupId],
  );

  Future<void> removeAreaConveyor(int groupId) => _db.db.update(
    'study_group',
    {'conveyor_capacity': 0, 'conveyor_transport_us': 0},
    where: 'id = ?',
    whereArgs: [groupId],
  );

  /// A member outside a loader cell.
  static const _noCell = {
    'cell_loader': 0,
    'cell_parts': 1,
    'cell_machines': 1,
  };

  /// Everything that connects a station to the one before it.
  static const _noBuffer = {
    'buffer_capacity': 0,
    'buffer_store_us': 0,
    'buffer_retrieve_us': 0,
    'conveyor_capacity': 0,
    'conveyor_transport_us': 0,
  };

  /// Sets the order of the studies of group [groupId] to
  /// [studyIdsInOrder].
  ///
  /// With [moved] (the one member that changed its place) the stations are
  /// kept together, see [parallelAfterMove]: a first machine that moves
  /// away hands its station (with buffer, conveyor and the option to wait
  /// for the slowest machine) to the next machine, a member dropped inside
  /// a station joins it (and loses its own buffer and conveyor), anywhere
  /// else it becomes a station of its own.
  ///
  /// Areas of the group stay where they are: the moved study goes right
  /// before the study it now stands in front of (or to the end); without
  /// [moved] the studies fill the places of the studies in the new order.
  Future<void> reorder(int groupId, List<int> studyIdsInOrder, {int? moved}) =>
      _db.db.transaction((txn) async {
        final rows = await StudyRepository.memberRows(txn, groupId);
        final order = _withAreas(
          [for (final r in rows) _key(r)],
          studyIdsInOrder,
          moved,
        );
        await _reorder(
          txn,
          groupId,
          order,
          moved == null ? null : MemberKey.study(moved),
        );
      });

  /// Sets the order of the studies and areas of group [groupId] to
  /// [order]. [moved] keeps the stations together like in [reorder]; an
  /// area dropped inside a station splits it: the machine behind the area
  /// becomes the first of a station of its own (no loader, no buffer or
  /// conveyor of its own – they stay before the first part) and keeps the
  /// option to wait for the slowest machine, as far as
  /// [StudyRepository.tidyStations] leaves it.
  Future<void> reorderMembers(
    int groupId,
    List<MemberKey> order, {
    MemberKey? moved,
  }) => _db.db.transaction((txn) => _reorder(txn, groupId, order, moved));

  static MemberKey _key(Map<String, Object?> row) => row['area'] == 1
      ? MemberKey.area(row['id'] as int)
      : MemberKey.study(row['id'] as int);

  /// The order of all members for a new order of the studies only.
  static List<MemberKey> _withAreas(
    List<MemberKey> old,
    List<int> studyIds,
    int? moved,
  ) {
    final newStudies = [for (final id in studyIds) MemberKey.study(id)];
    if (!old.any((k) => k.isArea)) return newStudies;
    final oldStudies = [
      for (final k in old)
        if (!k.isArea) k,
    ];
    if (oldStudies.length != newStudies.length) {
      return [
        ...newStudies,
        for (final k in old)
          if (k.isArea) k,
      ];
    }
    if (moved != null) {
      final key = MemberKey.study(moved);
      final from = oldStudies.indexOf(key);
      final to = newStudies.indexOf(key);
      if (from >= 0 &&
          to >= 0 &&
          _sameKeys(
            [...oldStudies]..removeAt(from),
            [...newStudies]..removeAt(to),
          )) {
        final result = [...old]..remove(key);
        final at = to + 1 < newStudies.length
            ? result.indexOf(newStudies[to + 1])
            : result.length;
        return result..insert(at, key);
      }
    }
    var k = 0;
    return [for (final m in old) m.isArea ? m : newStudies[k++]];
  }

  static Future<void> _reorder(
    Transaction txn,
    int groupId,
    List<MemberKey> order,
    MemberKey? moved,
  ) async {
    final members = await StudyRepository.memberRows(txn, groupId);
    final old = [for (final m in members) _key(m)];
    final from = moved == null ? -1 : old.indexOf(moved);
    final to = moved == null ? -1 : order.indexOf(moved);
    final single =
        from >= 0 &&
        to >= 0 &&
        old.length == order.length &&
        _sameKeys([...old]..removeAt(from), [...order]..removeAt(to));
    final move = single
        ? parallelAfterMove(
            [for (final m in members) m['parallel'] == 1],
            from,
            to,
            isArea: [for (final m in members) m['area'] == 1],
          )
        : null;
    for (var i = 0; i < order.length; i++) {
      final key = order[i];
      if (key.isArea) {
        await txn.update(
          'study_group',
          {'parent_position': i},
          where: 'id = ? AND parent_id = ?',
          whereArgs: [key.id, groupId],
        );
        continue;
      }
      await txn.update(
        'study',
        {
          'group_position': i,
          if (move != null) 'parallel': move.parallel[i] ? 1 : 0,
          // Only a member of a station can be a loader of its cell.
          if (move != null && !move.parallel[i]) 'cell_loader': 0,
        },
        where: 'id = ? AND group_id = ?',
        whereArgs: [key.id, groupId],
      );
    }
    if (move == null) {
      await StudyRepository.tidyStations(txn, groupId);
      return;
    }
    final newHead = move.newHead;
    if (newHead != null) {
      await txn.update(
        'study',
        {
          StudyRepository.waitColumn: members[from][StudyRepository.waitColumn],
          // Nothing stands before the first member of a group.
          if (from > 0)
            for (final c in StudyRepository.stationLinkColumns)
              c: members[from][c],
        },
        where: 'id = ?',
        whereArgs: [order[newHead].id],
      );
    }
    final split = move.split;
    if (split != null) {
      // The part behind the area keeps the option of the station it came
      // from; buffer and conveyor stay before the first part.
      final oldIndex = old.indexOf(order[split]);
      final station = stationGroups(StudyRepository.memberStationFlags(members))
          .firstWhere((s) => s.contains(oldIndex));
      await txn.update(
        'study',
        {
          ..._noBuffer,
          StudyRepository.waitColumn:
              members[station.first][StudyRepository.waitColumn],
        },
        where: 'id = ?',
        whereArgs: [order[split].id],
      );
    }
    // The buffer stays with the station the member left; a member that
    // joins a station is no station of its own.
    if (!moved!.isArea && (newHead != null || move.parallel[to])) {
      await txn.update(
        'study',
        {..._noBuffer, StudyRepository.waitColumn: 0},
        where: 'id = ?',
        whereArgs: [moved.id],
      );
    }
    await StudyRepository.tidyStations(txn, groupId);
  }

  static bool _sameKeys(List<MemberKey> a, List<MemberKey> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static StudyGroup groupFromRow(Map<String, Object?> r) => StudyGroup(
    id: r['id'] as int,
    name: r['name'] as String,
    description: r['description'] as String,
    createdAt: DateTime.fromMillisecondsSinceEpoch(r['created_at'] as int),
    parentId: r['parent_id'] as int?,
    parentPosition: (r['parent_position'] as int?) ?? 0,
    bufferCapacity: (r['buffer_capacity'] as int?) ?? 0,
    bufferStoreMicros: (r['buffer_store_us'] as int?) ?? 0,
    bufferRetrieveMicros: (r['buffer_retrieve_us'] as int?) ?? 0,
    conveyorCapacity: (r['conveyor_capacity'] as int?) ?? 0,
    conveyorTransportMicros: (r['conveyor_transport_us'] as int?) ?? 0,
  );
}
