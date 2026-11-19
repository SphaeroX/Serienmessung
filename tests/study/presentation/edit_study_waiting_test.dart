import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/core/providers.dart';
import 'package:cyclescope/study/data/study_repository.dart';
import 'package:cyclescope/study/domain/study.dart';
import 'package:cyclescope/study/presentation/edit_study_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_platform.dart';
import '../../helpers.dart';

void main() {
  late AppDatabase db;
  late int studyId;

  setUp(() async {
    db = await openTestDatabase();
    studyId = await StudyRepository(db).createStudy(
      name: 'Gantry',
      mode: StudyMode.timeStudy,
      steps: ['Change', 'Wait for machine'],
      now: DateTime(2026),
    );
  });

  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          ...fakePlatformOverrides(),
        ],
        child: localizedApp(EditStudyScreen(studyId: studyId)),
      ),
    );
    await settle(tester);
  }

  Future<List<bool>> marks(WidgetTester tester) async =>
      (await tester.runAsync(() => StudyRepository(db).getSteps(studyId)))!
          .map((s) => s.waiting)
          .toList();

  testWidgets('a step is marked as waiting time and unmarked again', (
    tester,
  ) async {
    await pump(tester);
    expect(find.textContaining('Waiting time'), findsNothing);

    await tester.tap(find.byKey(const Key('waitingStep-1')));
    await settle(tester);
    expect(await marks(tester), [false, true]);
    expect(find.text('Step 2 of 2 · Waiting time'), findsOneWidget);
    expect(find.text('Step 1 of 2'), findsOneWidget);

    await tester.tap(find.byKey(const Key('waitingStep-1')));
    await settle(tester);
    expect(await marks(tester), [false, false]);
    expect(find.textContaining('Waiting time'), findsNothing);
  });

  testWidgets('the mark explains itself', (tester) async {
    await pump(tester);
    expect(
      find.byTooltip(
        'Waiting for a machine or for material: left out in a loader cell',
      ),
      findsNWidgets(2),
    );
  });

  testWidgets('the mark survives editing the steps as text', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('waitingStep-1')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('stepsTextMode')));
    await settle(tester);
    await tester.enterText(
      find.byKey(const Key('stepsField')),
      'Change\nWait for the machine',
    );
    await tester.tap(find.byKey(const Key('stepsListMode')));
    await settle(tester);
    expect(await marks(tester), [false, true]);
    expect(find.text('Step 2 of 2 · Waiting time'), findsOneWidget);
  });
}
