import 'package:sqflite/sqflite.dart';

/// A single schema migration from version `n - 1` to `n`.
typedef Migration = Future<void> Function(DatabaseExecutor db);

/// Ordered list of migrations. Index 0 creates schema version 1.
///
/// Never edit an existing migration – append a new one instead.
final List<Migration> migrations = [
  // v1: studies and step definitions.
  (db) async {
    await db.execute('''
      CREATE TABLE study (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        mode TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        last_active_at INTEGER NOT NULL
      )''');
    await db.execute('''
      CREATE TABLE step_definition (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        study_id INTEGER NOT NULL REFERENCES study(id) ON DELETE CASCADE,
        position INTEGER NOT NULL,
        name TEXT NOT NULL
      )''');
    await db.execute(
      'CREATE INDEX idx_step_study ON step_definition(study_id, position)',
    );
  },
  // v2: measurements.
  (db) async {
    await db.execute('''
      CREATE TABLE measurement (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        study_id INTEGER NOT NULL REFERENCES study(id) ON DELETE CASCADE,
        cycle INTEGER NOT NULL,
        step_id INTEGER,
        kind TEXT NOT NULL,
        start_us INTEGER NOT NULL,
        end_us INTEGER NOT NULL,
        duration_us INTEGER NOT NULL,
        note TEXT NOT NULL DEFAULT ''
      )''');
    await db.execute(
      'CREATE INDEX idx_measurement_study ON measurement(study_id, cycle)',
    );
  },
  // v3: crash-safe engine state of running recordings.
  (db) async {
    await db.execute('''
      CREATE TABLE run_state (
        study_id INTEGER PRIMARY KEY REFERENCES study(id) ON DELETE CASCADE,
        snapshot TEXT NOT NULL,
        saved_clock_us INTEGER NOT NULL,
        saved_at INTEGER NOT NULL
      )''');
  },
  // v4: cycle time method per study.
  (db) async {
    await db.execute('ALTER TABLE study ADD COLUMN cycle_time_method TEXT');
  },
  // v5: key/value settings.
  (db) async {
    await db.execute(
      'CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
    );
  },
  // v6: imported video of a video study.
  (db) async {
    await db.execute('ALTER TABLE study ADD COLUMN video_path TEXT');
  },
  // v7: video studies define their steps while marking the first cycle.
  (db) async {
    await db.execute(
      'ALTER TABLE study ADD COLUMN steps_open INTEGER NOT NULL DEFAULT 0',
    );
  },
];

/// Thin wrapper around the sqflite [Database] that owns schema migrations.
class AppDatabase {
  AppDatabase._(this.db);

  final Database db;

  static int get latestVersion => migrations.length;

  /// Opens (and migrates) the database at [path].
  ///
  /// [version] can be lowered in tests to create an older schema.
  static Future<AppDatabase> open({
    required DatabaseFactory factory,
    required String path,
    int? version,
    bool singleInstance = true,
  }) async {
    final target = version ?? latestVersion;
    final db = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: target,
        // Tests open several independent in-memory databases.
        singleInstance: singleInstance,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, v) => _migrate(db, 0, v),
        onUpgrade: (db, from, to) => _migrate(db, from, to),
      ),
    );
    return AppDatabase._(db);
  }

  /// Upgrades an already opened database to the latest schema (tests only).
  static Future<AppDatabase> reopen(
    AppDatabase old, {
    required DatabaseFactory factory,
    required String path,
  }) async {
    await old.close();
    return open(factory: factory, path: path);
  }

  static Future<void> _migrate(Database db, int from, int to) async {
    for (var v = from; v < to; v++) {
      await migrations[v](db);
    }
  }

  Future<void> close() => db.close();
}
