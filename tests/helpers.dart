import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Opens a fresh in-memory database with all migrations applied.
Future<AppDatabase> openTestDatabase({int? version}) async {
  sqfliteFfiInit();
  return AppDatabase.open(
    factory: databaseFactoryFfi,
    path: inMemoryDatabasePath,
    version: version,
  );
}

/// Wraps [child] in a localized MaterialApp (English).
Widget localizedApp(Widget child, {Locale locale = const Locale('en')}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );
}

/// Runs real async work (e.g. sqflite ffi) inside widget tests and pumps.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
}

/// Scrolls [finder] into view and taps it.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  // A focused text field scrolls itself back into view; release focus first.
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump();
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
}

/// Uses a phone-sized test surface (392×872 logical pixels).
void usePhoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(1078, 2398);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
}

/// Pumps [count] frames of 100 ms so animations (tabs, snack bars,
/// expansion tiles) can finish. Use instead of `pumpAndSettle` on screens
/// with an endless ticker.
Future<void> pumpFrames(WidgetTester tester, {int count = 10}) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
