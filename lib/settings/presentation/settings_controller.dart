import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../data/settings_repository.dart';
import '../domain/app_settings.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(databaseProvider)),
);

/// Settings loaded at startup (overridden in `main()`); defaults in tests.
final initialSettingsProvider = Provider<AppSettings>(
  (ref) => const AppSettings(),
);

/// Current settings. Changes are saved immediately.
final settingsProvider = NotifierProvider<SettingsController, AppSettings>(
  SettingsController.new,
);

class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.read(initialSettingsProvider);

  Future<void> update(AppSettings Function(AppSettings) change) async {
    state = change(state);
    await ref.read(settingsRepositoryProvider).save(state);
  }
}
