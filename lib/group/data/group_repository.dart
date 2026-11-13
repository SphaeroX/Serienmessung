import '../../core/database.dart';
import '../../study/data/study_repository.dart';
import '../domain/stations.dart';
import '../domain/study_group.dart';

/// Persistence of study groups and the membership/order of their studies.
///
/// A study belongs to at most one group (`study.group_id`); its place in the
/// group is `study.group_position`. The studies of a group are listed by
/// `StudyRepository.listStudies(groupId: ...)`.
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

  /// Deletes the group; its studies stay, without a group.
  Future<void> deleteGroup(int id) =>
      _db.db.delete('study_group', where: 'id = ?', whereArgs: [id]);

  Future<StudyGroup?> getGroup(int id) async {
    final rows = await _db.db.query(
      'study_group',
      where: 'id = ?',
      whereArgs: [id],
    );
    return rows.isEmpty ? null : groupFromRow(rows.first);
  }

  /// All groups by name with their number of studies.
  Future<List<GroupSummary>> listGroups() async {
    final rows = await _db.db.rawQuery(
      'SELECT g.*, (SELECT COUNT(*) FROM study s WHERE s.group_id = g.id) '
      'AS n FROM study_group g ORDER BY g.name COLLATE NOCASE, g.id',
    );
    return [
      for (final r in rows)
        GroupSummary(group: groupFromRow(r), studyCount: r['n'] as int),
    ];
  }

  /// Puts study [studyId] at the end of group [groupId]; null removes it
  /// from its group.
  Future<void> moveToGroup(int studyId, int? groupId) =>
      _db.db.transaction((txn) async {
        await StudyRepository.handOverStation(txn, studyId);
        final position = groupId == null
            ? 0
            : await StudyRepository.nextGroupPosition(txn, groupId);
        await txn.update(
          'study',
          {
            'group_id': groupId,
            'group_position': position,
            'parallel': 0,
            ..._noBuffer,
          },
          where: 'id = ?',
          whereArgs: [studyId],
        );
      });

  /// Marks study [studyId] as working in parallel with the group member
  /// before it.
  ///
  /// A member working in parallel is no station of its own, so it loses
  /// its buffer.
  Future<void> setParallel(int studyId, bool parallel) => _db.db.update(
    'study',
    {'parallel': parallel ? 1 : 0, if (parallel) ..._noBuffer},
    where: 'id = ?',
    whereArgs: [studyId],
  );

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

  /// Everything that connects a station to the one before it.
  static const _noBuffer = {
    'buffer_capacity': 0,
    'buffer_store_us': 0,
    'buffer_retrieve_us': 0,
    'conveyor_capacity': 0,
    'conveyor_transport_us': 0,
  };

  /// Sets the group order to [studyIdsInOrder].
  ///
  /// With [moved] (the one member that changed its place) the stations are
  /// kept together, see [parallelAfterMove]: a first machine that moves
  /// away hands its station (with buffer and conveyor) to the next machine,
  /// a member dropped inside a station joins it (and loses its own buffer
  /// and conveyor), anywhere else it becomes a station of its own.
  Future<void> reorder(
    int groupId,
    List<int> studyIdsInOrder, {
    int? moved,
  }) => _db.db.transaction((txn) async {
    final members = await txn.query(
      'study',
      columns: ['id', 'parallel', ...StudyRepository.stationLinkColumns],
      where: 'group_id = ?',
      whereArgs: [groupId],
      orderBy: 'group_position, id',
    );
    final old = [for (final m in members) m['id'] as int];
    final from = moved == null ? -1 : old.indexOf(moved);
    final to = moved == null ? -1 : studyIdsInOrder.indexOf(moved);
    final single =
        from >= 0 &&
        to >= 0 &&
        old.length == studyIdsInOrder.length &&
        _equal([...old]..removeAt(from), [...studyIdsInOrder]..removeAt(to));
    final move = single
        ? parallelAfterMove(
            [for (final m in members) m['parallel'] == 1],
            from,
            to,
          )
        : null;
    for (var i = 0; i < studyIdsInOrder.length; i++) {
      await txn.update(
        'study',
        {
          'group_position': i,
          if (move != null) 'parallel': move.parallel[i] ? 1 : 0,
        },
        where: 'id = ? AND group_id = ?',
        whereArgs: [studyIdsInOrder[i], groupId],
      );
    }
    if (move == null) return;
    final newHead = move.newHead;
    if (newHead != null && from > 0) {
      await txn.update(
        'study',
        {
          for (final c in StudyRepository.stationLinkColumns)
            c: members[from][c],
        },
        where: 'id = ?',
        whereArgs: [studyIdsInOrder[newHead]],
      );
    }
    // The buffer stays with the station the member left; a member that
    // joins a station is no station of its own.
    if (newHead != null || move.parallel[to]) {
      await txn.update('study', _noBuffer, where: 'id = ?', whereArgs: [moved]);
    }
  });

  static bool _equal(List<int> a, List<int> b) {
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
  );
}
