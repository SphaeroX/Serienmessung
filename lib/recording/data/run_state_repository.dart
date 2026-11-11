import 'dart:convert';

import '../../core/database.dart';
import '../domain/recording_engine.dart';

/// Persisted engine state of a study whose recording is in progress.
class RunState {
  const RunState({
    required this.studyId,
    required this.snapshot,
    required this.savedClockMicros,
    required this.savedAt,
  });

  final int studyId;
  final EngineSnapshot snapshot;

  /// Monotonic clock value when saved. A smaller current value means the
  /// device was rebooted in between.
  final int savedClockMicros;
  final DateTime savedAt;
}

/// A study with a recording in progress (for the resume dialog).
class ActiveRun {
  const ActiveRun({required this.studyId, required this.studyName});

  final int studyId;
  final String studyName;
}

/// Crash-safe storage of the running engine state (one row per study).
class RunStateRepository {
  RunStateRepository(this._db);

  final AppDatabase _db;

  Future<void> save(
    int studyId,
    EngineSnapshot snapshot, {
    required int clockMicros,
    required DateTime now,
  }) => _db.db.rawInsert(
    'INSERT OR REPLACE INTO run_state '
    '(study_id, snapshot, saved_clock_us, saved_at) VALUES (?, ?, ?, ?)',
    [
      studyId,
      jsonEncode(snapshot.toJson()),
      clockMicros,
      now.millisecondsSinceEpoch,
    ],
  );

  Future<RunState?> load(int studyId) async {
    final rows = await _db.db.query(
      'run_state',
      where: 'study_id = ?',
      whereArgs: [studyId],
    );
    if (rows.isEmpty) return null;
    final r = rows.first;
    return RunState(
      studyId: studyId,
      snapshot: EngineSnapshot.fromJson(
        jsonDecode(r['snapshot'] as String) as Map<String, Object?>,
      ),
      savedClockMicros: r['saved_clock_us'] as int,
      savedAt: DateTime.fromMillisecondsSinceEpoch(r['saved_at'] as int),
    );
  }

  Future<void> delete(int studyId) =>
      _db.db.delete('run_state', where: 'study_id = ?', whereArgs: [studyId]);

  Future<List<ActiveRun>> activeRuns() async {
    final rows = await _db.db.rawQuery(
      'SELECT r.study_id AS id, s.name AS name FROM run_state r '
      'JOIN study s ON s.id = r.study_id ORDER BY r.saved_at DESC',
    );
    return [
      for (final r in rows)
        ActiveRun(studyId: r['id'] as int, studyName: r['name'] as String),
    ];
  }
}
