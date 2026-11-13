import 'package:cyclescope/analysis/domain/statistics.dart';
import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/core/providers.dart';
import 'package:cyclescope/core/time_format.dart';
import 'package:cyclescope/recording/data/measurement_repository.dart';
import 'package:cyclescope/recording/domain/measurement.dart';
import 'package:cyclescope/revision/data/revision_repository.dart';
import 'package:cyclescope/revision/presentation/revisions_screen.dart';
import 'package:cyclescope/study/data/study_repository.dart';
import 'package:cyclescope/study/domain/study.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_platform.dart';
import '../../helpers.dart';

void main() {
  late AppDatabase db;
  late int studyId;
  late List<int> stepIds;
  var now = DateTime(2025, 3, 4, 10);

  setUp(() async {
    db = await openTestDatabase();
    final studies = StudyRepository(db);
    studyId = await studies.createStudy(
      name: 'Saw',
      mode: StudyMode.timeStudy,
      steps: ['Load', 'Cut'],
      now: DateTime(2025),
    );
    stepIds = [for (final s in await studies.getSteps(studyId)) s.id];
  });

  tearDown(() => db.close());

  Future<void> cycle(int cycle, int load, int cut) async {
    final repo = MeasurementRepository(db, now: () => now);
    for (final (i, s) in [(0, load), (1, cut)]) {
      await repo.insert(
        studyId,
        MeasurementDraft(
          cycle: cycle,
          stepId: stepIds[i],
          kind: MeasurementKind.normal,
          startMicros: 0,
          endMicros: s * 1000000,
          durationMicros: s * 1000000,
        ),
      );
    }
  }

  Widget app({bool canStartNew = true}) => ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      wallClockProvider.overrideWithValue(() => DateTime(2026, 3, 5)),
      ...fakePlatformOverrides(),
    ],
    child: localizedApp(
      RevisionsScreen(
        studyId: studyId,
        unit: TimeUnit.seconds,
        method: CycleTimeMethod.mean,
        canStartNew: canStartNew,
      ),
    ),
  );

  testWidgets('shows the current revision and deviations to older ones', (
    tester,
  ) async {
    await tester.runAsync(() async {
      now = DateTime(2025, 3, 4, 10);
      await cycle(1, 10, 30);
      await RevisionRepository(db)
          .startNewRevision(studyId, now: DateTime(2026, 3, 1));
      now = DateTime(2026, 3, 2, 9);
      await cycle(1, 15, 27);
    });
    await tester.pumpWidget(app());
    await settle(tester);

    expect(find.text('Revision 2 (current)'), findsOneWidget);
    expect(find.textContaining('3/2/2026'), findsOneWidget);
    expect(find.text('Revision 1'), findsOneWidget);
    // Cycle time 40 s → 42 s.
    expect(find.text('+2.00 s (+5.0 %)'), findsOneWidget);

    await tester.tap(find.byKey(const Key('revision_1')));
    await tester.pumpAndSettle();
    expect(find.text('Load'), findsOneWidget);
    expect(find.text('+5.00 s'), findsOneWidget);
    expect(find.text('Cut'), findsOneWidget);
    expect(find.text('-3.00 s'), findsOneWidget);
  });

  testWidgets('starting a new measurement archives after confirming', (
    tester,
  ) async {
    await tester.runAsync(() => cycle(1, 10, 30));
    await tester.pumpWidget(app());
    await settle(tester);

    await tester.tap(find.byKey(const Key('newRevisionButton')));
    await tester.pumpAndSettle();
    expect(find.textContaining('kept as revision 1'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirmNewRevision')));
    await settle(tester);
    await tester.pumpAndSettle();

    final list = (await tester.runAsync(
      () => RevisionRepository(db).listRevisions(studyId),
    ))!;
    expect(list.single.number, 1);
    expect(list.single.closedAt, DateTime(2026, 3, 5));
  });

  testWidgets('no new measurement while recording or without times', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await settle(tester);
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('newRevisionButton')),
    );
    expect(button.onPressed, isNull);

    await tester.runAsync(() => cycle(1, 10, 30));
    await tester.pumpWidget(Container());
    await tester.pumpWidget(app(canStartNew: false));
    await settle(tester);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('newRevisionButton')))
          .onPressed,
      isNull,
    );
    expect(find.text('Stop the recording first.'), findsOneWidget);
  });

  testWidgets('an archived revision can be deleted', (tester) async {
    await tester.runAsync(() async {
      await cycle(1, 10, 30);
      await RevisionRepository(db)
          .startNewRevision(studyId, now: DateTime(2026));
    });
    await tester.pumpWidget(app());
    await settle(tester);
    await tester.tap(find.byKey(const Key('revision_1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('deleteRevision_1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmDeleteRevision')));
    await settle(tester);
    await tester.pumpAndSettle();
    expect(find.text('Revision 1'), findsNothing);
    expect(
      await tester.runAsync(
        () => RevisionRepository(db).listRevisions(studyId),
      ),
      isEmpty,
    );
  });

  testWidgets('small deviations show one decimal more than the live unit', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await cycle(1, 10, 30);
      await RevisionRepository(db)
          .startNewRevision(studyId, now: DateTime(2026));
      // Load: 10 s → 10.24 s = +0.4 HM.
      final repo = MeasurementRepository(db, now: () => now);
      for (final (i, us) in [(0, 10240000), (1, 30000000)]) {
        await repo.insert(
          studyId,
          MeasurementDraft(
            cycle: 1,
            stepId: stepIds[i],
            kind: MeasurementKind.normal,
            startMicros: 0,
            endMicros: us,
            durationMicros: us,
          ),
        );
      }
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          ...fakePlatformOverrides(),
        ],
        child: localizedApp(
          RevisionsScreen(
            studyId: studyId,
            unit: TimeUnit.hm,
            method: CycleTimeMethod.mean,
          ),
        ),
      ),
    );
    await settle(tester);
    await tester.tap(find.byKey(const Key('revision_1')));
    await tester.pumpAndSettle();
    expect(find.text('+0.4 HM'), findsWidgets);
    expect(find.text('16.7 HM'), findsOneWidget);
  });
}
