import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'app.dart';
import 'core/clock.dart';
import 'core/database.dart';
import 'core/providers.dart';
import 'recording/platform/recording_notifier.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = await AppDatabase.open(
    factory: databaseFactory,
    path: p.join(await getDatabasesPath(), 'cyclescope.db'),
  );
  // Elapsed realtime keeps running while the app is killed, so a saved
  // recording can be continued with correct times after a restart.
  final offset =
      await readElapsedRealtimeMicros() ??
      DateTime.now().microsecondsSinceEpoch;
  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(MonotonicClock(offsetMicros: offset)),
      ],
      child: const CycleScopeApp(),
    ),
  );
}
