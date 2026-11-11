import 'package:cyclescope/core/clock.dart';
import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/core/providers.dart';
import 'package:cyclescope/recording/data/measurement_repository.dart';
import 'package:cyclescope/recording/presentation/recording_screen.dart';
import 'package:cyclescope/study/data/study_repository.dart';
import 'package:cyclescope/study/domain/study.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_clock.dart';
import '../../fakes/fake_platform.dart';
import '../../helpers.dart';

void main() {
  late AppDatabase db;
  late FakeClock clock;
  late int studyId;

  setUp(() async {
    db = await openTestDatabase();
    clock = FakeClock(1000000);
    studyId = await StudyRepository(db).createStudy(
      name: 'Line',
      mode: StudyMode.timeStudy,
      steps: ['Pick', 'Place', 'Press'],
      now: DateTime(2026),
    );
  });

  tearDown(() => db.close());

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(clock as Clock),
          ...fakePlatformOverrides(),
        ],
        child: localizedApp(RecordingScreen(studyId: studyId)),
      ),
    );
    await settle(tester);
  }

  String textOf(WidgetTester tester, String key) =>
      tester.widget<Text>(find.byKey(Key(key))).data!;

  Future<void> tap(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(Key(key)));
    await settle(tester);
  }

  testWidgets('overlay shows step 1 immediately after start', (tester) async {
    await pumpScreen(tester);
    expect(textOf(tester, 'currentStepName'), 'Pick');
    expect(find.text('Ready'), findsOneWidget);

    await tap(tester, 'startStopButton');
    expect(textOf(tester, 'currentStepName'), 'Pick');
    expect(textOf(tester, 'stepPosition'), 'Step 1 of 3');
    expect(textOf(tester, 'nextStepName'), 'Next: Place');
    expect(textOf(tester, 'cycleLabel'), 'Cycle 1');
  });

  testWidgets('next advances the overlay and wraps into cycle 2', (
    tester,
  ) async {
    await pumpScreen(tester);
    await tap(tester, 'startStopButton');

    clock.advanceSeconds(2);
    await tap(tester, 'nextButton');
    expect(textOf(tester, 'currentStepName'), 'Place');

    clock.advanceSeconds(2);
    await tap(tester, 'nextButton');
    expect(textOf(tester, 'currentStepName'), 'Press');

    clock.advanceSeconds(2);
    await tap(tester, 'nextButton');
    expect(textOf(tester, 'currentStepName'), 'Pick');
    expect(textOf(tester, 'cycleLabel'), 'Cycle 2');

    final stored = await tester.runAsync(
      () => MeasurementRepository(db).listForStudy(studyId),
    );
    expect(stored!.length, 3);
  });

  testWidgets('newest measurement appears at the top of the live list', (
    tester,
  ) async {
    await pumpScreen(tester);
    await tap(tester, 'startStopButton');
    clock.advanceSeconds(1);
    await tap(tester, 'nextButton');
    clock.advanceSeconds(3);
    await tap(tester, 'nextButton');

    final rows = find.byKey(const Key('liveRow'));
    expect(rows, findsNWidgets(2));
    final first = find.descendant(of: rows.first, matching: find.text('Place'));
    expect(first, findsOneWidget);
  });

  testWidgets('stop pauses and continue resumes the same step', (tester) async {
    await pumpScreen(tester);
    await tap(tester, 'startStopButton');
    await tap(tester, 'startStopButton');
    expect(find.text('CONTINUE'), findsOneWidget);
    await tap(tester, 'startStopButton');
    expect(textOf(tester, 'currentStepName'), 'Pick');
    expect(find.text('STOP'), findsOneWidget);
  });
}
