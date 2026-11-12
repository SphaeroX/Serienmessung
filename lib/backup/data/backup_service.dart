import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../core/database.dart';

/// Identifies backup files of this app.
const backupFormat = 'cyclescope-backup';

/// Current backup format version. Files with a higher version are rejected.
const backupVersion = 1;

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

/// Exports all studies with steps and measurements to JSON and restores them.
///
/// Not included: running recordings (`run_state`), settings and video files
/// (only their path is kept).
class BackupService {
  BackupService(this._db);

  final AppDatabase _db;

  Future<String> exportJson({required DateTime now}) async {
    final db = _db.db;
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
            },
        ],
      });
    }
    return const JsonEncoder.withIndent(' ').convert({
      'format': backupFormat,
      'version': backupVersion,
      'exportedAt': now.toIso8601String(),
      'studies': out,
    });
  }

  /// Restores [json]. With [replace] all existing studies are deleted first;
  /// otherwise studies already present are skipped. Nothing is changed if
  /// the file is invalid.
  Future<ImportResult> importJson(String json, {required bool replace}) async {
    final studies = _parse(json);
    return _db.db.transaction((txn) async {
      if (replace) {
        await txn.delete('run_state');
        await txn.delete('measurement');
        await txn.delete('step_definition');
        await txn.delete('study');
      }
      var imported = 0;
      var skipped = 0;
      var videos = 0;
      for (final s in studies) {
        if (!replace && await _exists(txn, s)) {
          skipped++;
          continue;
        }
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
          });
        }
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

  Future<bool> _exists(Transaction txn, Map s) async {
    final rows = await txn.query(
      'study',
      columns: ['id'],
      where: 'name = ? AND mode = ? AND created_at = ?',
      whereArgs: [s['name'], s['mode'], s['createdAt']],
    );
    return rows.isNotEmpty;
  }

  /// Validates the structure before anything is written.
  List<Map> _parse(String json) {
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
    const modes = {'simple', 'timeStudy', 'stepTimer', 'video'};
    const kinds = {'normal', 'special'};
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
          (s['measurements'] as List).every(
            (m) =>
                m is Map &&
                m['cycle'] is int &&
                kinds.contains(m['kind']) &&
                m['start'] is int &&
                m['end'] is int &&
                m['duration'] is int,
          );
      if (!ok) {
        throw const BackupException(BackupError.invalid, 'malformed study');
      }
    }
    return studies.cast<Map>();
  }
}
