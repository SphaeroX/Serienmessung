import '../../core/database.dart';
import '../domain/special_cycle.dart';

/// Special cycles and planned stops of the machines (studies).
class SpecialCycleRepository {
  SpecialCycleRepository(this._db);

  final AppDatabase _db;

  Future<List<SpecialCycle>> list(int studyId) async {
    final rows = await _db.db.query(
      'special_cycle',
      where: 'study_id = ?',
      whereArgs: [studyId],
      orderBy: 'id',
    );
    return rows.map(fromRow).toList();
  }

  /// Rules per study for [studyIds] (studies without rules are left out).
  Future<Map<int, List<SpecialCycle>>> listFor(List<int> studyIds) async {
    final result = <int, List<SpecialCycle>>{};
    for (final id in studyIds) {
      final cycles = await list(id);
      if (cycles.isNotEmpty) result[id] = cycles;
    }
    return result;
  }

  /// Number of rules per study for [studyIds].
  Future<Map<int, int>> countFor(List<int> studyIds) async => {
    for (final e in (await listFor(studyIds)).entries) e.key: e.value.length,
  };

  Future<int> add(
    int studyId, {
    required String name,
    required SpecialCycleKind kind,
    required int interval,
    required int durationMicros,
  }) => _db.db.insert('special_cycle', {
    'study_id': studyId,
    'name': name,
    'kind': kind.name,
    'interval': interval,
    'duration_us': durationMicros,
  });

  Future<void> delete(int id) =>
      _db.db.delete('special_cycle', where: 'id = ?', whereArgs: [id]);

  static SpecialCycle fromRow(Map<String, Object?> r) => SpecialCycle(
    id: r['id'] as int,
    studyId: r['study_id'] as int,
    name: r['name'] as String,
    kind: SpecialCycleKind.parse(r['kind'] as String),
    interval: r['interval'] as int,
    durationMicros: r['duration_us'] as int,
  );
}
