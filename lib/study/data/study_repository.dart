import 'package:sqflite/sqflite.dart';

import '../../core/database.dart';
import '../domain/study.dart';

/// Persistence of studies and step definitions.
class StudyRepository {
  StudyRepository(this._db);

  final AppDatabase _db;

  Future<int> createStudy({
    required String name,
    String description = '',
    required StudyMode mode,
    required List<String> steps,
    required DateTime now,
    String? cycleTimeMethod,
  }) {
    return _db.db.transaction((txn) async {
      final id = await txn.insert('study', {
        'name': name,
        'description': description,
        'mode': mode.name,
        'created_at': now.millisecondsSinceEpoch,
        'last_active_at': now.millisecondsSinceEpoch,
        'cycle_time_method': ?cycleTimeMethod,
        // Only written when set; the column defaults to 0.
        'steps_open': ?(mode == StudyMode.video && steps.isEmpty ? 1 : null),
      });
      for (var i = 0; i < steps.length; i++) {
        await txn.insert('step_definition', {
          'study_id': id,
          'position': i,
          'name': steps[i],
        });
      }
      return id;
    });
  }

  Future<Study?> getStudy(int id) async {
    final rows = await _db.db.query('study', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : studyFromRow(rows.first);
  }

  Future<List<StepDefinition>> getSteps(int studyId) async {
    final rows = await _db.db.query(
      'step_definition',
      where: 'study_id = ?',
      whereArgs: [studyId],
      orderBy: 'position',
    );
    return rows.map(stepFromRow).toList();
  }

  /// All studies, newest activity first; with [groupId] only the studies of
  /// that group in group order.
  Future<List<StudySummary>> listStudies({int? groupId}) async {
    final rows = await _db.db.rawQuery(
      'SELECT s.*, g.name AS group_name FROM study s '
      'LEFT JOIN study_group g ON g.id = s.group_id '
      '${groupId == null ? '' : 'WHERE s.group_id = ? '}'
      'ORDER BY ${groupId == null ? 's.last_active_at DESC, s.id DESC' : 's.group_position, s.id'}',
      [?groupId],
    );
    final running = {
      for (final r in await _db.db.query('run_state', columns: ['study_id']))
        r['study_id'] as int,
    };
    final result = <StudySummary>[];
    for (final row in rows) {
      final study = studyFromRow(row);
      result.add(
        StudySummary(
          study: study,
          cycleCount: await countCycles(study),
          isRecording: running.contains(study.id),
          groupName: row['group_name'] as String?,
        ),
      );
    }
    return result;
  }

  /// Number shown on the list card: laps/times for simple and step-timer
  /// studies, distinct cycles otherwise. Special times are not counted.
  Future<int> countCycles(Study study) async {
    final countsTimes =
        study.mode == StudyMode.simple || study.mode == StudyMode.stepTimer;
    final expr = countsTimes ? 'COUNT(*)' : 'COUNT(DISTINCT cycle)';
    final r = await _db.db.rawQuery(
      "SELECT $expr AS n FROM measurement WHERE study_id = ? AND kind = 'normal'",
      [study.id],
    );
    return r.first['n'] as int;
  }

  Future<void> deleteStudy(int id) async {
    await _db.db.delete('study', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateStudy(
    int id, {
    required String name,
    required String description,
  }) => _db.db.update(
    'study',
    {'name': name, 'description': description},
    where: 'id = ?',
    whereArgs: [id],
  );

  Future<void> renameStep(int stepId, String name) => _db.db.update(
    'step_definition',
    {'name': name},
    where: 'id = ?',
    whereArgs: [stepId],
  );

  /// Sets the positions to the order of [stepIdsInOrder].
  Future<void> reorderSteps(int studyId, List<int> stepIdsInOrder) =>
      _db.db.transaction((txn) async {
        for (var i = 0; i < stepIdsInOrder.length; i++) {
          await txn.update(
            'step_definition',
            {'position': i},
            where: 'id = ? AND study_id = ?',
            whereArgs: [stepIdsInOrder[i], studyId],
          );
        }
      });

  /// Appends a step at the end and returns its id.
  Future<int> addStep(int studyId, String name) async {
    final r = await _db.db.rawQuery(
      'SELECT COALESCE(MAX(position), -1) + 1 AS p FROM step_definition '
      'WHERE study_id = ?',
      [studyId],
    );
    return _db.db.insert('step_definition', {
      'study_id': studyId,
      'position': r.first['p'] as int,
      'name': name,
    });
  }

  /// Number of recorded times (incl. special times) attached to a step.
  Future<int> countStepTimes(int stepId) async {
    final r = await _db.db.rawQuery(
      'SELECT COUNT(*) AS n FROM measurement WHERE step_id = ?',
      [stepId],
    );
    return r.first['n'] as int;
  }

  /// Deletes a step together with its times and closes the position gap.
  Future<void> deleteStep(int stepId) => _db.db.transaction((txn) async {
    final rows = await txn.query(
      'step_definition',
      where: 'id = ?',
      whereArgs: [stepId],
    );
    if (rows.isEmpty) return;
    final studyId = rows.first['study_id'] as int;
    await txn.delete('measurement', where: 'step_id = ?', whereArgs: [stepId]);
    await txn.delete('step_definition', where: 'id = ?', whereArgs: [stepId]);
    final rest = await txn.query(
      'step_definition',
      where: 'study_id = ?',
      whereArgs: [studyId],
      orderBy: 'position',
    );
    for (var i = 0; i < rest.length; i++) {
      await txn.update(
        'step_definition',
        {'position': i},
        where: 'id = ?',
        whereArgs: [rest[i]['id']],
      );
    }
  });

  /// Ends the step definition of a video study (first cycle closed).
  Future<void> closeSteps(int id) => _db.db.update(
    'study',
    {'steps_open': 0},
    where: 'id = ?',
    whereArgs: [id],
  );

  /// Creates a live time study with the steps of study [id] (e.g. steps
  /// defined in a video study) and returns its id.
  Future<int> copyAsTimeStudy(
    int id, {
    required String name,
    required DateTime now,
  }) async {
    final source = await getStudy(id);
    final steps = await getSteps(id);
    return createStudy(
      name: name,
      description: source?.description ?? '',
      mode: StudyMode.timeStudy,
      steps: [for (final s in steps) s.name],
      now: now,
      cycleTimeMethod: source?.cycleTimeMethod,
    );
  }

  /// Duplicates study [id] with its steps and times as a new study named
  /// [name] and returns its id. With [groupId] the copy is appended to that
  /// group.
  Future<int> copyStudy(
    int id, {
    required String name,
    int? groupId,
    required DateTime now,
  }) => _db.db.transaction((txn) async {
    final rows = await txn.query('study', where: 'id = ?', whereArgs: [id]);
    final source = Map<String, Object?>.of(rows.single)
      ..remove('id')
      ..['name'] = name
      ..['created_at'] = now.millisecondsSinceEpoch
      ..['last_active_at'] = now.millisecondsSinceEpoch
      ..['group_id'] = groupId
      ..['group_position'] = groupId == null
          ? 0
          : await nextGroupPosition(txn, groupId);
    final copy = await txn.insert('study', source);
    final stepIds = <int, int>{};
    for (final st in await txn.query(
      'step_definition',
      where: 'study_id = ?',
      whereArgs: [id],
      orderBy: 'position',
    )) {
      stepIds[st['id'] as int] = await txn.insert('step_definition', {
        'study_id': copy,
        'position': st['position'],
        'name': st['name'],
      });
    }
    for (final m in await txn.query(
      'measurement',
      where: 'study_id = ?',
      whereArgs: [id],
      orderBy: 'id',
    )) {
      final row = Map<String, Object?>.of(m)
        ..remove('id')
        ..['study_id'] = copy
        ..['step_id'] = stepIds[m['step_id']];
      await txn.insert('measurement', row);
    }
    return copy;
  });

  /// Position behind the last study of group [groupId].
  static Future<int> nextGroupPosition(DatabaseExecutor db, int groupId) async {
    final r = await db.rawQuery(
      'SELECT COALESCE(MAX(group_position), -1) + 1 AS p FROM study '
      'WHERE group_id = ?',
      [groupId],
    );
    return r.first['p'] as int;
  }

  Future<void> setVideoPath(int id, String path) => _db.db.update(
    'study',
    {'video_path': path},
    where: 'id = ?',
    whereArgs: [id],
  );

  Future<void> setNotes(int id, String notes) => _db.db.update(
    'study',
    {'notes': notes},
    where: 'id = ?',
    whereArgs: [id],
  );

  Future<void> setCycleTimeMethod(int id, String method) => _db.db.update(
    'study',
    {'cycle_time_method': method},
    where: 'id = ?',
    whereArgs: [id],
  );

  Future<void> touch(int id, DateTime now) async {
    await _db.db.update(
      'study',
      {'last_active_at': now.millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Study studyFromRow(Map<String, Object?> r) => Study(
    id: r['id'] as int,
    name: r['name'] as String,
    description: r['description'] as String,
    mode: StudyMode.parse(r['mode'] as String),
    createdAt: DateTime.fromMillisecondsSinceEpoch(r['created_at'] as int),
    lastActiveAt: DateTime.fromMillisecondsSinceEpoch(
      r['last_active_at'] as int,
    ),
    cycleTimeMethod: r['cycle_time_method'] as String?,
    videoPath: r['video_path'] as String?,
    stepsOpen: (r['steps_open'] as int? ?? 0) == 1,
    notes: r['notes'] as String? ?? '',
    groupId: r['group_id'] as int?,
    groupPosition: r['group_position'] as int? ?? 0,
  );

  static StepDefinition stepFromRow(Map<String, Object?> r) => StepDefinition(
    id: r['id'] as int,
    studyId: r['study_id'] as int,
    position: r['position'] as int,
    name: r['name'] as String,
  );
}
