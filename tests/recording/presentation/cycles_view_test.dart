import 'package:cyclescope/core/clock.dart';
import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/core/providers.dart';
import 'package:cyclescope/recording/data/measurement_repository.dart';
import 'package:cyclescope/recording/domain/measurement.dart';
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
  late int studyId;
  late List<int> steps;

  setUp(() async {
    db = await openTestDatabase();
    final studies = StudyRepository(db);
    studyId = await studies.createStudy(
      name: 'Line',
      mode: StudyMode.timeStudy,
      steps: ['Pick', 'Place'],
      now: DateTime(2026),
    );
    steps = (await studies.getSteps(studyId)).map((s) => s.id).toList();
    final repo = MeasurementRepository(db);
    var t = 0;
    Future<void> add(int cycle, int step, {bool special = false}) async {
      t += 1000000;
      await repo.insert(
        studyId,
        MeasurementDraft(
          cycle: cycle,
          stepId: step,
          kind: special ? MeasurementKind.special : MeasurementKind.normal,
          startMicros: t - 1000000,
          endMicros: t,
          durationMicros: 1000000,
        ),
      );
    }

    await add(1, steps[0]);
    await add(1, steps[1]);
    await add(2, steps[0]);
    await add(2, steps[0], special: true);
    await add(2, steps[1]);
  });

  tearDown(() => db.close());

  Future<void> openCycles(WidgetTester tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(FakeClock(1) as Clock),
          ...fakePlatformOverrides(),
        ],
        child: localizedApp(RecordingScreen(studyId: studyId)),
      ),
    );
    await settle(tester);
    await tester.tap(find.byKey(const Key('cyclesTab')));
    // Let the tab switch animation finish.
    await pumpFrames(tester);
    await settle(tester);
  }

  Future<List<Measurement>> stored(WidgetTester tester) async => (await tester
      .runAsync(() => MeasurementRepository(db).listForStudy(studyId)))!;

  testWidgets('shows cycles with their steps', (tester) async {
    await openCycles(tester);
    expect(find.byKey(const Key('cycleTile-1')), findsOneWidget);
    expect(find.byKey(const Key('cycleTile-2')), findsOneWidget);
    await tapVisible(tester, find.byKey(const Key('cycleTile-2')));
    await pumpFrames(tester);
    expect(find.text('Special time'), findsWidgets);
  });

  testWidgets('deleting a cycle removes it and undo restores it', (
    tester,
  ) async {
    await openCycles(tester);
    await tapVisible(tester, find.byKey(const Key('deleteCycle-2')));
    await settle(tester);
    await pumpFrames(tester);
    expect(find.byKey(const Key('cycleTile-2')), findsNothing);
    expect((await stored(tester)).length, 2);

    await tester.tap(find.text('Undo'));
    await settle(tester);
    await pumpFrames(tester);
    expect(find.byKey(const Key('cycleTile-2')), findsOneWidget);
    expect((await stored(tester)).length, 5);
  });

  testWidgets('deleting a single step time marks the cycle incomplete', (
    tester,
  ) async {
    await openCycles(tester);
    await tapVisible(tester, find.byKey(const Key('cycleTile-1')));
    await pumpFrames(tester);
    expect(find.text('incomplete'), findsNothing);
    await tapVisible(tester, find.byKey(const Key('deleteMeasurement')).first);
    await settle(tester);
    await pumpFrames(tester);
    expect((await stored(tester)).length, 4);
    expect(find.text('incomplete'), findsOneWidget);
  });
}
