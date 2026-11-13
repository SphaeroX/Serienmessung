import '../../core/database.dart';
import '../domain/measurement.dart';

/// Persistence of measurements.
class MeasurementRepository {
  MeasurementRepository(this._db, {this.now});

  final AppDatabase _db;

  /// Wall clock for `recorded_at`; without it no timestamp is written.
  final DateTime Function()? now;

  Future<int> insert(int studyId, MeasurementDraft m) async =>
      (await store(studyId, m)).id;

  /// Stores [m] and returns it as it is in the database (with its id and
  /// `recorded_at`).
  Future<Measurement> store(int studyId, MeasurementDraft m) async {
    final recordedAt = now?.call();
    final id = await _db.db.insert('measurement', {
      'study_id': studyId,
      'cycle': m.cycle,
      'step_id': m.stepId,
      'kind': m.kind.name,
      'start_us': m.startMicros,
      'end_us': m.endMicros,
      'duration_us': m.durationMicros,
      'note': m.note,
      'recorded_at': recordedAt?.millisecondsSinceEpoch,
    });
    return Measurement(
      id: id,
      studyId: studyId,
      cycle: m.cycle,
      stepId: m.stepId,
      kind: m.kind,
      startMicros: m.startMicros,
      endMicros: m.endMicros,
      durationMicros: m.durationMicros,
      note: m.note,
      recordedAt: recordedAt,
    );
  }

  Future<void> updateNote(int id, String note) => _db.db.update(
    'measurement',
    {'note': note},
    where: 'id = ?',
    whereArgs: [id],
  );

  /// Deletes all times of [cycle]; returns them for undo.
  Future<List<Measurement>> deleteCycle(int studyId, int cycle) async {
    final rows = await _db.db.query(
      'measurement',
      where: 'study_id = ? AND cycle = ?',
      whereArgs: [studyId, cycle],
    );
    await _db.db.delete(
      'measurement',
      where: 'study_id = ? AND cycle = ?',
      whereArgs: [studyId, cycle],
    );
    return rows.map(fromRow).toList();
  }

  /// Deletes one time; returns it for undo (empty if not found).
  Future<List<Measurement>> deleteById(int id) async {
    final rows = await _db.db.query(
      'measurement',
      where: 'id = ?',
      whereArgs: [id],
    );
    await _db.db.delete('measurement', where: 'id = ?', whereArgs: [id]);
    return rows.map(fromRow).toList();
  }

  /// Updates start, end and duration (moved video marker).
  Future<void> updateTimes(Measurement m) => _db.db.update(
    'measurement',
    {
      'start_us': m.startMicros,
      'end_us': m.endMicros,
      'duration_us': m.durationMicros,
    },
    where: 'id = ?',
    whereArgs: [m.id],
  );

  /// Re-inserts deleted measurements with their original ids (undo).
  Future<void> restore(List<Measurement> items) async {
    await _db.db.transaction((txn) async {
      for (final m in items) {
        await txn.insert('measurement', {
          'id': m.id,
          'study_id': m.studyId,
          'cycle': m.cycle,
          'step_id': m.stepId,
          'kind': m.kind.name,
          'start_us': m.startMicros,
          'end_us': m.endMicros,
          'duration_us': m.durationMicros,
          'note': m.note,
          'recorded_at': m.recordedAt?.millisecondsSinceEpoch,
        });
      }
    });
  }

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
    recordedAt: r['recorded_at'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(r['recorded_at'] as int),
  );
}
