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
  late List<int> ids;

  setUp(() async {
    db = await openTestDatabase();
    studyId = await StudyRepository(db).createStudy(
      name: 'Line',
      mode: StudyMode.stepTimer,
      steps: ['Pick', 'Place'],
      now: DateTime(2026),
    );
    ids = (await StudyRepository(db).getSteps(studyId))
        .map((s) => s.id)
        .toList();
    await MeasurementRepository(db).insert(
      studyId,
      MeasurementDraft(
        cycle: 1,
        stepId: ids.first,
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

  Future<List<StepDefinition>> steps(WidgetTester tester) async =>
      (await tester.runAsync(() => StudyRepository(db).getSteps(studyId)))!;

  Future<void> toText(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('stepsTextMode')));
    await settle(tester);
  }

  Future<void> toList(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('stepsListMode')));
    await settle(tester);
  }

  String fieldText(WidgetTester tester) => tester
      .widget<TextField>(find.byKey(const Key('stepsField')))
      .controller!
      .text;

  testWidgets('the list is the default editing method', (tester) async {
    await pump(tester);
    expect(find.byKey(const Key('newStepField')), findsOneWidget);
    expect(find.byKey(const Key('stepsField')), findsNothing);
  });

  testWidgets('text mode shows one step per line', (tester) async {
    await pump(tester);
    await toText(tester);
    expect(fieldText(tester), 'Pick\nPlace');
    expect(find.byKey(const Key('newStepField')), findsNothing);
  });

  testWidgets('switching back to the list applies the text', (tester) async {
    await pump(tester);
    await toText(tester);
    await tester.enterText(
      find.byKey(const Key('stepsField')),
      'Press\nPick part\nPlace',
    );
    await toList(tester);
    final result = await steps(tester);
    expect(result.map((s) => s.name), ['Press', 'Pick part', 'Place']);
    // The edited line keeps the step (and its recorded time).
    expect(result[1].id, ids.first);
    expect(find.text('Press'), findsOneWidget);
  });

  testWidgets('save applies the text and the study fields', (tester) async {
    await pump(tester);
    await toText(tester);
    await tester.enterText(find.byKey(const Key('stepsField')), 'Pick\nCheck');
    await tester.tap(find.byKey(const Key('saveStudyButton')));
    await settle(tester);
    expect((await steps(tester)).map((s) => s.name), ['Pick', 'Check']);
  });

  testWidgets('removing a line with times asks first', (tester) async {
    await pump(tester);
    await toText(tester);
    await tester.enterText(find.byKey(const Key('stepsField')), 'Place');
    await toList(tester);
    expect(find.textContaining('1 recorded time'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await settle(tester);
    expect((await steps(tester)).map((s) => s.name), ['Pick', 'Place']);
    expect(find.byKey(const Key('stepsField')), findsOneWidget);

    await toList(tester);
    await tester.tap(find.text('Delete').last);
    await settle(tester);
    expect((await steps(tester)).map((s) => s.name), ['Place']);
    expect(find.byKey(const Key('stepsField')), findsNothing);
  });

  testWidgets('empty text is rejected', (tester) async {
    await pump(tester);
    await toText(tester);
    await tester.enterText(find.byKey(const Key('stepsField')), '  \n');
    await toList(tester);
    expect(find.text('Please enter at least one step'), findsOneWidget);
    expect((await steps(tester)).length, 2);
    expect(find.byKey(const Key('stepsField')), findsOneWidget);
  });
}
