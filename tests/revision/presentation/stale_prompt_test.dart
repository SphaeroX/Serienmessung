import 'package:cyclescope/app.dart';
import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/core/providers.dart';
import 'package:cyclescope/recording/data/measurement_repository.dart';
import 'package:cyclescope/recording/data/run_state_repository.dart';
import 'package:cyclescope/recording/domain/measurement.dart';
import 'package:cyclescope/recording/domain/recording_engine.dart';
import 'package:cyclescope/recording/presentation/recording_screen.dart';
import 'package:cyclescope/revision/data/revision_repository.dart';
import 'package:cyclescope/settings/domain/app_settings.dart';
import 'package:cyclescope/settings/presentation/settings_controller.dart';
import 'package:cyclescope/study/data/study_repository.dart';
import 'package:cyclescope/study/domain/study.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_platform.dart';
import '../../helpers.dart';

void main() {
  late AppDatabase db;

  setUp(() async => db = await openTestDatabase());
  tearDown(() => db.close());

  /// Study with one time recorded at [measuredAt].
  Future<int> study(
    WidgetTester tester, {
    StudyMode mode = StudyMode.timeStudy,
    DateTime? measuredAt,
  }) async => (await tester.runAsync(() async {
    final studies = StudyRepository(db);
    final id = await studies.createStudy(
      name: 'Saw',
      mode: mode,
      steps: ['Cut'],
      now: DateTime(2026),
    );
    if (measuredAt != null) {
      await MeasurementRepository(db, now: () => measuredAt).insert(
        id,
        MeasurementDraft(
          cycle: 1,
          stepId: (await studies.getSteps(id)).single.id,
          kind: MeasurementKind.normal,
          startMicros: 0,
          endMicros: 5,
          durationMicros: 5,
        ),
      );
    }
    return id;
  }))!;

  Future<void> pumpOpener(
    WidgetTester tester,
    int studyId, {
    AppSettings settings = const AppSettings(),
  }) async {
    usePhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          initialSettingsProvider.overrideWithValue(settings),
          wallClockProvider.overrideWithValue(() => DateTime(2026, 3, 20)),
          ...fakePlatformOverrides(),
        ],
        child: localizedApp(
          Builder(
            builder: (context) => TextButton(
              key: const Key('open'),
              onPressed: () => openStudy(context, studyId),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open')));
    await settle(tester);
    await pumpFrames(tester);
  }

  Future<int> revisionCount(WidgetTester tester, int id) async =>
      (await tester.runAsync(() => RevisionRepository(db).listRevisions(id)))!
          .length;

  testWidgets('an old measurement offers a new one; accepting archives it', (
    tester,
  ) async {
    final id = await study(tester, measuredAt: DateTime(2026, 3, 1));
    await pumpOpener(tester, id);
    expect(find.text('Measurement is 19 days old'), findsOneWidget);

    await tester.tap(find.byKey(const Key('staleNewRevision')));
    await settle(tester);
    await pumpFrames(tester);
    await settle(tester);

    expect(await revisionCount(tester, id), 1);
    expect(find.byType(RecordingScreen), findsOneWidget);
  });

  testWidgets('continuing keeps the times', (tester) async {
    final id = await study(tester, measuredAt: DateTime(2026, 3, 1));
    await pumpOpener(tester, id);
    await tester.tap(find.byKey(const Key('staleContinue')));
    await settle(tester);
    await pumpFrames(tester);
    expect(await revisionCount(tester, id), 0);
    expect(find.byType(RecordingScreen), findsOneWidget);
  });

  testWidgets('no question for recent, empty or video studies', (tester) async {
    for (final id in [
      await study(tester, measuredAt: DateTime(2026, 3, 15)),
      await study(tester),
      await study(
        tester,
        mode: StudyMode.video,
        measuredAt: DateTime(2025, 1, 1),
      ),
    ]) {
      await pumpOpener(tester, id);
      expect(find.byKey(const Key('staleNewRevision')), findsNothing);
      await tester.pumpWidget(Container());
    }
  });

  testWidgets('no question when switched off', (tester) async {
    final id = await study(tester, measuredAt: DateTime(2025, 1, 1));
    await pumpOpener(
      tester,
      id,
      settings: const AppSettings().copyWith(staleDays: 0),
    );
    expect(find.byKey(const Key('staleNewRevision')), findsNothing);
  });

  testWidgets('no question while a recording is running', (tester) async {
    final id = await study(tester, measuredAt: DateTime(2025, 1, 1));
    await tester.runAsync(
      () => RunStateRepository(db).save(
        id,
        const EngineSnapshot(
          status: EngineStatus.paused,
          cycle: 2,
          stepIndex: 0,
          currentStepId: null,
          stepStartMicros: 0,
          segmentStartMicros: 0,
          accumulatedMicros: 0,
          specialStartMicros: 0,
        ),
        clockMicros: 0,
        now: DateTime(2025),
      ),
    );
    await pumpOpener(tester, id);
    expect(find.byKey(const Key('staleNewRevision')), findsNothing);
  });
}
