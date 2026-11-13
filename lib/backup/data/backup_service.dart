import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../core/database.dart';
import '../../study/data/study_repository.dart';

/// Identifies backup files of this app.
const backupFormat = 'cyclescope-backup';

/// Current backup format version. Files with a higher version are rejected.
///
/// v2 adds groups (`groups`, `groupRef`, `groupPosition`), the revision
/// number, `recordedAt` per time and the archived `revisions`. v1 files are
/// still imported (those fields are optional).
const backupVersion = 2;

/// Why a backup could not be restored.
enum BackupError { invalid, tooNew }

class BackupException implements Exception {
  const BackupException(this.error, [this.detail = '']);

  final BackupError error;
  final String detail;

  @override
  String toString() =>
      'BackupException($error${detail.isEmpty ? '' : ': $detail'})';
}

/// Result of a restore.
class ImportResult {
  const ImportResult({
    required this.imported,
    required this.skipped,
    required this.videoStudies,
  });

  final int imported;

  /// Studies already present (same name, mode and creation time).
  final int skipped;

  /// Imported video studies; their video files are not part of the backup.
  final int videoStudies;
}

/// Exports all studies with steps, measurements, groups and archived
/// revisions to JSON and restores them.
///
/// Not included: running recordings (`run_state`), settings and video files
/// (only their path is kept).
class BackupService {
  BackupService(this._db);

  final AppDatabase _db;

  Future<String> exportJson({required DateTime now}) async {
    final db = _db.db;
    final groups = await db.query('study_group', orderBy: 'id');
    final studies = await db.query('study', orderBy: 'id');
    final out = <Map<String, Object?>>[];
    for (final s in studies) {
      final id = s['id'] as int;
      final steps = await db.query(
        'step_definition',
        where: 'study_id = ?',
        whereArgs: [id],
        orderBy: 'position',
      );
      final measurements = await db.query(
        'measurement',
        where: 'study_id = ?',
        whereArgs: [id],
        orderBy: 'id',
      );
      out.add({
        'name': s['name'],
        'description': s['description'],
        'mode': s['mode'],
        'createdAt': s['created_at'],
        'lastActiveAt': s['last_active_at'],
        'cycleTimeMethod': s['cycle_time_method'],
        'videoPath': s['video_path'],
        'stepsOpen': s['steps_open'] == 1,
        'notes': s['notes'],
        'groupRef': s['group_id'],
        'groupPosition': s['group_position'],
        'parallel': s['parallel'] == 1,
        'bufferCapacity': s['buffer_capacity'],
        'bufferStore': s['buffer_store_us'],
        'bufferRetrieve': s['buffer_retrieve_us'],
        'conveyorCapacity': s['conveyor_capacity'],
        'conveyorTransport': s['conveyor_transport_us'],
        'revision': s['revision'],
        'steps': [
          for (final st in steps)
            {'ref': st['id'], 'position': st['position'], 'name': st['name']},
        ],
        'measurements': [
          for (final m in measurements)
            {
              'cycle': m['cycle'],
              'stepRef': m['step_id'],
              'kind': m['kind'],
              'start': m['start_us'],
              'end': m['end_us'],
              'duration': m['duration_us'],
              'note': m['note'],
              'recordedAt': m['recorded_at'],
            },
        ],
        'revisions': await _exportRevisions(db, id),
      });
    }
    return const JsonEncoder.withIndent(' ').convert({
      'format': backupFormat,
      'version': backupVersion,
      'exportedAt': now.toIso8601String(),
      'groups': [
        for (final g in groups)
          {
            'ref': g['id'],
            'name': g['name'],
            'description': g['description'],
            'createdAt': g['created_at'],
          },
      ],
      'studies': out,
    });
  }

  static Future<List<Map<String, Object?>>> _exportRevisions(
    DatabaseExecutor db,
    int studyId,
  ) async {
    final out = <Map<String, Object?>>[];
    for (final r in await db.query(
      'revision',
      where: 'study_id = ?',
      whereArgs: [studyId],
      orderBy: 'number',
    )) {
      final id = r['id'];
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
        orderBy: 'id',
      );
      out.add({
        'number': r['number'],
        'closedAt': r['closed_at'],
        'firstRecordedAt': r['first_recorded_at'],
        'lastRecordedAt': r['last_recorded_at'],
        'cycleTimeMethod': r['cycle_time_method'],
        'notes': r['notes'],
        // stepRef values refer to the study's step refs (or to deleted
        // steps, which only the revision knows).
        'steps': [
          for (final st in steps)
            {
              'stepRef': st['step_id'],
              'position': st['position'],
              'name': st['name'],
            },
        ],
        'measurements': [
          for (final m in times)
            {
              'cycle': m['cycle'],
              'stepRef': m['step_id'],
              'kind': m['kind'],
              'start': m['start_us'],
              'end': m['end_us'],
              'duration': m['duration_us'],
              'note': m['note'],
              'recordedAt': m['recorded_at'],
            },
        ],
      });
    }
    return out;
  }

  /// Restores [json]. With [replace] all existing studies are deleted first;
  /// otherwise studies already present are skipped. Nothing is changed if
  /// the file is invalid.
  Future<ImportResult> importJson(String json, {required bool replace}) async {
    final (groups, studies) = _parse(json);
    return _db.db.transaction((txn) async {
      if (replace) {
        await txn.delete('run_state');
        await txn.delete('revision_measurement');
        await txn.delete('revision_step');
        await txn.delete('revision');
        await txn.delete('measurement');
        await txn.delete('step_definition');
        await txn.delete('study');
        await txn.delete('study_group');
      }
      // Groups are reused by name when merging.
      final groupIds = <Object?, int>{};
      final groupOffsets = <int, int>{};
      for (final g in groups) {
        final existing = await txn.query(
          'study_group',
          columns: ['id'],
          where: 'name = ?',
          whereArgs: [g['name']],
          limit: 1,
        );
        groupIds[g['ref']] = existing.isNotEmpty
            ? existing.first['id'] as int
            : await txn.insert('study_group', {
                'name': g['name'],
                'description': g['description'] ?? '',
                'created_at': g['createdAt'],
              });
      }
      // Imported studies keep their order behind the group's existing ones.
      Future<int> position(int groupId, Object? backupPosition) async {
        final offset = groupOffsets[groupId] ??=
            await StudyRepository.nextGroupPosition(txn, groupId);
        return offset + ((backupPosition as int?) ?? 0);
      }

      var imported = 0;
      var skipped = 0;
      var videos = 0;
      for (final s in studies) {
        if (!replace && await _exists(txn, s)) {
          skipped++;
          continue;
        }
        final groupId = groupIds[s['groupRef']];
        final studyId = await txn.insert('study', {
          'name': s['name'],
          'description': s['description'] ?? '',
          'mode': s['mode'],
          'created_at': s['createdAt'],
          'last_active_at': s['lastActiveAt'] ?? s['createdAt'],
          'cycle_time_method': s['cycleTimeMethod'],
          'video_path': s['videoPath'],
          'steps_open': s['stepsOpen'] == true ? 1 : 0,
          'notes': s['notes'] as String? ?? '',
          'group_id': groupId,
          'group_position': groupId == null
              ? 0
              : await position(groupId, s['groupPosition']),
          'revision': s['revision'] as int? ?? 1,
          'parallel': groupId != null && s['parallel'] == true ? 1 : 0,
          if (groupId != null) ...{
            'buffer_capacity': s['bufferCapacity'] as int? ?? 0,
            'buffer_store_us': s['bufferStore'] as int? ?? 0,
            'buffer_retrieve_us': s['bufferRetrieve'] as int? ?? 0,
            'conveyor_capacity': s['conveyorCapacity'] as int? ?? 0,
            'conveyor_transport_us': s['conveyorTransport'] as int? ?? 0,
          },
        });
        final stepIds = <Object?, int>{};
        for (final st in s['steps'] as List) {
          final m = st as Map;
          stepIds[m['ref']] = await txn.insert('step_definition', {
            'study_id': studyId,
            'position': m['position'],
            'name': m['name'],
          });
        }
        for (final x in s['measurements'] as List) {
          final m = x as Map;
          await txn.insert('measurement', {
            'study_id': studyId,
            'cycle': m['cycle'],
            'step_id': m['stepRef'] == null ? null : stepIds[m['stepRef']],
            'kind': m['kind'],
            'start_us': m['start'],
            'end_us': m['end'],
            'duration_us': m['duration'],
            'note': m['note'] ?? '',
            'recorded_at': m['recordedAt'],
          });
        }
        await _importRevisions(
          txn,
          studyId,
          s['revisions'] as List? ?? const [],
          stepIds,
        );
        imported++;
        if (s['mode'] == 'video') videos++;
      }
      return ImportResult(
        imported: imported,
        skipped: skipped,
        videoStudies: videos,
      );
    });
  }

  /// Revision steps that still exist in the study point to the new step
  /// ids; refs of deleted steps get fresh negative ids.
  static Future<void> _importRevisions(
    Transaction txn,
    int studyId,
    List revisions,
    Map<Object?, int> stepIds,
  ) async {
    final mapped = <Object?, int>{...stepIds};
    int? map(Object? ref) => ref == null
        ? null
        : mapped.putIfAbsent(ref, () => -(mapped.length + 1));
    for (final x in revisions) {
      final r = x as Map;
      final id = await txn.insert('revision', {
        'study_id': studyId,
        'number': r['number'],
        'closed_at': r['closedAt'],
        'first_recorded_at': r['firstRecordedAt'],
        'last_recorded_at': r['lastRecordedAt'],
        'cycle_time_method': r['cycleTimeMethod'],
        'notes': r['notes'] ?? '',
      });
      for (final st in r['steps'] as List) {
        final m = st as Map;
        await txn.insert('revision_step', {
          'revision_id': id,
          'step_id': map(m['stepRef']),
          'position': m['position'],
          'name': m['name'],
        });
      }
      for (final t in r['measurements'] as List) {
        final m = t as Map;
        await txn.insert('revision_measurement', {
          'revision_id': id,
          'cycle': m['cycle'],
          'step_id': map(m['stepRef']),
          'kind': m['kind'],
          'start_us': m['start'],
          'end_us': m['end'],
          'duration_us': m['duration'],
          'note': m['note'] ?? '',
          'recorded_at': m['recordedAt'],
        });
      }
    }
  }

  Future<bool> _exists(Transaction txn, Map s) async {
    final rows = await txn.query(
      'study',
      columns: ['id'],
      where: 'name = ? AND mode = ? AND created_at = ?',
      whereArgs: [s['name'], s['mode'], s['createdAt']],
    );
    return rows.isNotEmpty;
  }

  /// Validates the structure before anything is written; returns the groups
  /// (empty for v1) and the studies.
  (List<Map>, List<Map>) _parse(String json) {
    final Object? root;
    try {
      root = jsonDecode(json);
    } on FormatException catch (e) {
      throw BackupException(BackupError.invalid, e.message);
    }
    if (root is! Map || root['format'] != backupFormat) {
      throw const BackupException(BackupError.invalid, 'not a backup file');
    }
    final version = root['version'];
    if (version is! int) {
      throw const BackupException(BackupError.invalid, 'missing version');
    }
    if (version > backupVersion) {
      throw BackupException(BackupError.tooNew, 'version $version');
    }
    final studies = root['studies'];
    if (studies is! List) {
      throw const BackupException(BackupError.invalid, 'missing studies');
    }
    final groups = root['groups'] ?? const [];
    if (groups is! List ||
        !groups.every(
          (g) => g is Map && g['name'] is String && g['createdAt'] is int,
        )) {
      throw const BackupException(BackupError.invalid, 'malformed group');
    }
    const modes = {'simple', 'timeStudy', 'stepTimer', 'video'};
    const kinds = {'normal', 'special'};
    bool time(Object? m) =>
        m is Map &&
        m['cycle'] is int &&
        kinds.contains(m['kind']) &&
        m['start'] is int &&
        m['end'] is int &&
        m['duration'] is int &&
        (m['recordedAt'] == null || m['recordedAt'] is int);
    bool revision(Object? r) =>
        r is Map &&
        r['number'] is int &&
        r['closedAt'] is int &&
        r['steps'] is List &&
        r['measurements'] is List &&
        (r['steps'] as List).every(
          (st) =>
              st is Map &&
              st['name'] is String &&
              st['position'] is int &&
              st['stepRef'] is int,
        ) &&
        (r['measurements'] as List).every(time);
    for (final s in studies) {
      final ok =
          s is Map &&
          s['name'] is String &&
          modes.contains(s['mode']) &&
          s['createdAt'] is int &&
          s['steps'] is List &&
          s['measurements'] is List &&
          (s['steps'] as List).every(
            (st) => st is Map && st['name'] is String && st['position'] is int,
          ) &&
          (s['measurements'] as List).every(time) &&
          (s['revisions'] == null ||
              (s['revisions'] is List &&
                  (s['revisions'] as List).every(revision)));
      if (!ok) {
        throw const BackupException(BackupError.invalid, 'malformed study');
      }
    }
    return (groups.cast<Map>(), studies.cast<Map>());
  }
}
