import 'package:cyclescope/core/clock.dart';
import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/core/providers.dart';
import 'package:cyclescope/recording/data/measurement_repository.dart';
import 'package:cyclescope/recording/domain/recording_engine.dart';
import 'package:cyclescope/recording/presentation/recording_screen.dart';
import 'package:cyclescope/study/data/study_repository.dart';
import 'package:cyclescope/study/domain/study.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_clock.dart';
import '../../fakes/fake_platform.dart';
import '../../helpers.dart';

const s = 1000000;

void main() {
  test('engine can start with any step in free order', () {
    final e = RecordingEngine(
      clock: FakeClock(),
      sequence: const [1, 2, 3],
      freeOrder: true,
    );
    e.start(cycle: 0, stepId: 3);
    expect(e.currentStepId, 3);
  });

  late AppDatabase db;
  late FakeClock clock;
  late int studyId;
  late List<int> ids;

  setUp(() async {
    db = await openTestDatabase();
    clock = FakeClock(5 * s);
    final studies = StudyRepository(db);
    studyId = await studies.createStudy(
      name: 'Free',
      mode: StudyMode.stepTimer,
      steps: ['Pick', 'Place', 'Press'],
      now: DateTime(2026),
    );
    ids = (await studies.getSteps(studyId)).map((x) => x.id).toList();
  });

  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester) async {
    usePhoneSize(tester);
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

  Future<void> tapStep(WidgetTester tester, int index) async {
    await tester.tap(find.byKey(Key('stepTile-$index')));
    await settle(tester);
  }

  Future<List<(int?, int)>> stored(WidgetTester tester) async =>
      (await tester.runAsync(
        () => MeasurementRepository(db).listForStudy(studyId),
      ))!.map((m) => (m.stepId, m.durationMicros)).toList();

  String current(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const Key('currentStepName'))).data!;

  testWidgets('tapping a tile starts timing that step', (tester) async {
    await pump(tester);
    expect(find.byKey(const Key('stepTile-2')), findsOneWidget);
    await tapStep(tester, 1); // Place, while idle
    expect(current(tester), 'Place');
    expect(find.text('STOP'), findsOneWidget);
  });

  testWidgets('S2 → S1 → S2 gives three times with correct steps', (
    tester,
  ) async {
    await pump(tester);
    await tapStep(tester, 1);
    clock.advanceSeconds(2);
    await tapStep(tester, 0);
    clock.advanceSeconds(1);
    await tapStep(tester, 1);
    clock.advanceSeconds(4);
    await tapStep(tester, 1); // tapping the active step again
    expect(await stored(tester), [
      (ids[1], 2 * s),
      (ids[0], 1 * s),
      (ids[1], 4 * s),
    ]);
    expect(current(tester), 'Place');
  });

  testWidgets('times tab lists times flat and allows deleting', (tester) async {
    await pump(tester);
    await tapStep(tester, 0);
    clock.advanceSeconds(1);
    await tapStep(tester, 2);
    await tester.tap(find.byKey(const Key('cyclesTab')));
    await pumpFrames(tester);
    expect(find.text('Cycle 0'), findsNothing);
    await tester.tap(find.byKey(const Key('deleteMeasurement')).first);
    await settle(tester);
    expect(await stored(tester), isEmpty);
  });
}
