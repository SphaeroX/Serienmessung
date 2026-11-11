import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers.dart';
import 'l10n/app_localizations.dart';
import 'recording/presentation/recording_screen.dart';
import 'study/presentation/study_list_screen.dart';

const _seed = Color(0xFF0B6B8A);

ThemeData buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(seedColor: _seed, brightness: brightness);
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    cardTheme: CardThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}

/// Root widget.
class CycleScopeApp extends ConsumerWidget {
  const CycleScopeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      onGenerateTitle: (ctx) => AppLocalizations.of(ctx).appTitle,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: StudyListScreen(onOpenStudy: openStudy),
    );
  }
}

/// Opens the screen matching the study's mode.
Future<void> openStudy(BuildContext context, int studyId) async {
  await Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => RecordingScreen(studyId: studyId)),
  );
  if (context.mounted) {
    // Counts and "active" timestamps changed while the study was open.
    ProviderScope.containerOf(
      context,
      listen: false,
    ).invalidate(studyListProvider);
  }
}
