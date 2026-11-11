import '../../core/database.dart';
import '../domain/app_settings.dart';

/// Stores settings as key/value rows in the app database.
class SettingsRepository {
  SettingsRepository(this._db);

  final AppDatabase _db;

  Future<AppSettings> load() async {
    final rows = await _db.db.query('settings');
    return AppSettings.fromMap({
      for (final r in rows) r['key'] as String: r['value'] as String,
    });
  }

  Future<void> save(AppSettings settings) => _db.db.transaction((txn) async {
    for (final e in settings.toMap().entries) {
      await txn.rawInsert(
        'INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)',
        [e.key, e.value],
      );
    }
  });
}
