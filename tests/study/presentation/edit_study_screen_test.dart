import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/core/providers.dart';
import 'package:cyclescope/recording/data/measurement_repository.dart';
import 'package:cyclescope/recording/domain/measurement.dart';
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
      name: 'Line',
      mode: StudyMode.timeStudy,
      steps: ['Pick', 'Place'],
      now: DateTime(2026),
    );
    final first = (await StudyRepository(db).getSteps(studyId)).first;
    await MeasurementRepository(db).insert(
      studyId,
      MeasurementDraft(
        cycle: 1,
        stepId: first.id,
        kind: MeasurementKind.normal,
        startMicros: 0,
        endMicros: 1,
        durationMicros: 1,
      ),
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

  Future<List<String>> names(WidgetTester tester) async =>
      (await tester.runAsync(() => StudyRepository(db).getSteps(studyId)))!
          .map((s) => s.name)
          .toList();

  testWidgets('renames a step', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Place'));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('stepNameField')), 'Insert');
    await tester.tap(find.text('Save').last);
    await settle(tester);
    expect(await names(tester), ['Pick', 'Insert']);
    expect(find.text('Insert'), findsOneWidget);
  });

  testWidgets('adds a step', (tester) async {
    await pump(tester);
    await tester.enterText(find.byKey(const Key('newStepField')), 'Press');
    await tester.tap(find.byKey(const Key('addStepButton')));
    await settle(tester);
    expect(await names(tester), ['Pick', 'Place', 'Press']);
  });

  testWidgets('deleting a step with times asks first', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('deleteStep-0')));
    await settle(tester);
    expect(find.textContaining('1 recorded time'), findsOneWidget);
    await tester.tap(find.text('Delete').last);
    await settle(tester);
    expect(await names(tester), ['Place']);
  });

  testWidgets('saves name and description', (tester) async {
    await pump(tester);
    await tester.enterText(find.byKey(const Key('studyNameField')), 'Line 2');
    await tester.tap(find.byKey(const Key('saveStudyButton')));
    await settle(tester);
    final s = await tester.runAsync(
      () => StudyRepository(db).getStudy(studyId),
    );
    expect(s!.name, 'Line 2');
  });
}
