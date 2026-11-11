import '../../core/database.dart';
import '../domain/measurement.dart';

/// Persistence of measurements.
class MeasurementRepository {
  MeasurementRepository(this._db);

  final AppDatabase _db;

  Future<int> insert(int studyId, MeasurementDraft m) =>
      _db.db.insert('measurement', {
        'study_id': studyId,
        'cycle': m.cycle,
        'step_id': m.stepId,
        'kind': m.kind.name,
        'start_us': m.startMicros,
        'end_us': m.endMicros,
        'duration_us': m.durationMicros,
        'note': m.note,
      });

  Future<void> updateNote(int id, String note) => _db.db.update(
    'measurement',
    {'note': note},
    where: 'id = ?',
    whereArgs: [id],
  );

  /// All measurements of a study in chronological order.
  Future<List<Measurement>> listForStudy(int studyId) async {
    final rows = await _db.db.query(
      'measurement',
      where: 'study_id = ?',
      whereArgs: [studyId],
      orderBy: 'cycle, end_us, id',
    );
    return rows.map(fromRow).toList();
  }

  /// Cycle number for a new recording session.
  Future<int> nextCycle(int studyId) async {
    final r = await _db.db.rawQuery(
      'SELECT MAX(cycle) AS c FROM measurement WHERE study_id = ?',
      [studyId],
    );
    final max = r.first['c'] as int?;
    return (max ?? 0) + 1;
  }

  static Measurement fromRow(Map<String, Object?> r) => Measurement(
    id: r['id'] as int,
    studyId: r['study_id'] as int,
    cycle: r['cycle'] as int,
    stepId: r['step_id'] as int?,
    kind: MeasurementKind.parse(r['kind'] as String),
    startMicros: r['start_us'] as int,
    endMicros: r['end_us'] as int,
    durationMicros: r['duration_us'] as int,
    note: r['note'] as String,
  );
}
