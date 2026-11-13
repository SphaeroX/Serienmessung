import '../../core/database.dart';
import '../../study/data/study_repository.dart';
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
        final position = groupId == null
            ? 0
            : await StudyRepository.nextGroupPosition(txn, groupId);
        await txn.update(
          'study',
          {'group_id': groupId, 'group_position': position},
          where: 'id = ?',
          whereArgs: [studyId],
        );
      });

  /// Sets the group order to [studyIdsInOrder].
  Future<void> reorder(int groupId, List<int> studyIdsInOrder) =>
      _db.db.transaction((txn) async {
        for (var i = 0; i < studyIdsInOrder.length; i++) {
          await txn.update(
            'study',
            {'group_position': i},
            where: 'id = ? AND group_id = ?',
            whereArgs: [studyIdsInOrder[i], groupId],
          );
        }
      });

  static StudyGroup groupFromRow(Map<String, Object?> r) => StudyGroup(
    id: r['id'] as int,
    name: r['name'] as String,
    description: r['description'] as String,
    createdAt: DateTime.fromMillisecondsSinceEpoch(r['created_at'] as int),
  );
}
