import 'package:sqflite/sqflite.dart';

import '../../core/database.dart';
import '../../recording/domain/measurement.dart';
import '../../study/domain/study.dart';
import '../domain/revision.dart';

/// Archived revisions of studies and the "last measured" time.
class RevisionRepository {
  RevisionRepository(this._db);

  final AppDatabase _db;

  /// Archives the current times of study [studyId] (with its steps) as a
  /// revision, deletes them and the run state, and returns the new current
  /// revision number. Returns null (and changes nothing) without times.
  Future<int?> startNewRevision(int studyId, {required DateTime now}) =>
      _db.db.transaction((txn) async {
        final studyRows = await txn.query(
          'study',
          where: 'id = ?',
          whereArgs: [studyId],
        );
        if (studyRows.isEmpty) return null;
        final study = studyRows.single;
        final times = await txn.query(
          'measurement',
          where: 'study_id = ?',
          whereArgs: [studyId],
          orderBy: 'cycle, end_us, id',
        );
        if (times.isEmpty) return null;
        final number = study['revision'] as int;
        final stamps = [
          for (final m in times)
            if (m['recorded_at'] != null) m['recorded_at'] as int,
        ]..sort();
        final revisionId = await txn.insert('revision', {
          'study_id': studyId,
          'number': number,
          'closed_at': now.millisecondsSinceEpoch,
          'first_recorded_at': stamps.isEmpty ? null : stamps.first,
          'last_recorded_at': stamps.isEmpty
              ? study['last_active_at']
              : stamps.last,
          'cycle_time_method': study['cycle_time_method'],
          'notes': study['notes'] ?? '',
        });
        for (final st in await txn.query(
          'step_definition',
          where: 'study_id = ?',
          whereArgs: [studyId],
          orderBy: 'position',
        )) {
          await txn.insert('revision_step', {
            'revision_id': revisionId,
            'step_id': st['id'],
            'position': st['position'],
            'name': st['name'],
          });
        }
        for (final m in times) {
          await txn.insert('revision_measurement', {
            'revision_id': revisionId,
            'cycle': m['cycle'],
            'step_id': m['step_id'],
            'kind': m['kind'],
            'start_us': m['start_us'],
            'end_us': m['end_us'],
            'duration_us': m['duration_us'],
            'note': m['note'],
            'recorded_at': m['recorded_at'],
          });
        }
        await txn.delete(
          'measurement',
          where: 'study_id = ?',
          whereArgs: [studyId],
        );
        await txn.delete(
          'run_state',
          where: 'study_id = ?',
          whereArgs: [studyId],
        );
        await txn.update(
          'study',
          {'revision': number + 1},
          where: 'id = ?',
          whereArgs: [studyId],
        );
        return number + 1;
      });

  /// Archived revisions of a study, newest first.
  Future<List<Revision>> listRevisions(int studyId) async {
    final rows = await _db.db.query(
      'revision',
      where: 'study_id = ?',
      whereArgs: [studyId],
      orderBy: 'number DESC',
    );
    return [for (final r in rows) await _load(_db.db, r)];
  }

  /// The most recently archived revision, null if there is none.
  Future<Revision?> latestRevision(int studyId) async {
    final rows = await _db.db.query(
      'revision',
      where: 'study_id = ?',
      whereArgs: [studyId],
      orderBy: 'number DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : _load(_db.db, rows.single);
  }

  Future<void> deleteRevision(int id) =>
      _db.db.delete('revision', where: 'id = ?', whereArgs: [id]);

  /// Wall-clock time of the newest time of the current revision. Times from
  /// before timestamps existed fall back to the study's last activity; null
  /// if the study has no times.
  Future<DateTime?> lastRecordedAt(int studyId) async {
    final r = await _db.db.rawQuery(
      'SELECT COUNT(m.id) AS n, MAX(m.recorded_at) AS t, s.last_active_at AS a '
      'FROM study s LEFT JOIN measurement m ON m.study_id = s.id '
      'WHERE s.id = ?',
      [studyId],
    );
    final row = r.first;
    if ((row['n'] as int) == 0 || row['a'] == null) return null;
    return DateTime.fromMillisecondsSinceEpoch((row['t'] ?? row['a']) as int);
  }

  static DateTime? _date(Object? ms) =>
      ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms as int);

  static Future<Revision> _load(
    DatabaseExecutor db,
    Map<String, Object?> r,
  ) async {
    final id = r['id'] as int;
    final studyId = r['study_id'] as int;
    final steps = await db.query(
      'revision_step',
      where: 'revision_id = ?',
      whereArgs: [id],
      orderBy: 'position',
    );
    final times = await db.query(
      'revision_measurement',
      where: 'revision_id = ?',
      whereArgs: [id],
      orderBy: 'cycle, end_us, id',
    );
    return Revision(
      id: id,
      studyId: studyId,
      number: r['number'] as int,
      closedAt: _date(r['closed_at'])!,
      firstRecordedAt: _date(r['first_recorded_at']),
      lastRecordedAt: _date(r['last_recorded_at']),
      cycleTimeMethod: r['cycle_time_method'] as String?,
      notes: r['notes'] as String? ?? '',
      steps: [
        for (final st in steps)
          StepDefinition(
            id: st['step_id'] as int,
            studyId: studyId,
            position: st['position'] as int,
            name: st['name'] as String,
          ),
      ],
      measurements: [
        for (final m in times)
          Measurement(
            id: m['id'] as int,
            studyId: studyId,
            cycle: m['cycle'] as int,
            stepId: m['step_id'] as int?,
            kind: MeasurementKind.parse(m['kind'] as String),
            startMicros: m['start_us'] as int,
            endMicros: m['end_us'] as int,
            durationMicros: m['duration_us'] as int,
            note: m['note'] as String,
            recordedAt: _date(m['recorded_at']),
          ),
      ],
    );
  }
}
