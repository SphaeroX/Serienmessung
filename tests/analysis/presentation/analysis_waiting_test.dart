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

const s = 1000000;

void main() {
  late AppDatabase db;
  late int studyId;

  setUp(() async {
    db = await openTestDatabase();
    final studies = StudyRepository(db);
    studyId = await studies.createStudy(
      name: 'Gantry',
      mode: StudyMode.timeStudy,
      steps: ['Change', 'Wait for machine'],
      now: DateTime(2026),
    );
    final steps = await studies.getSteps(studyId);
    await studies.setStepWaiting(steps[1].id, true);
    final repo = MeasurementRepository(db);
    var t = 0;
    for (final (i, sec) in [(0, 9), (1, 3)]) {
      t += sec * s;
      await repo.insert(
        studyId,
        MeasurementDraft(
          cycle: 1,
          stepId: steps[i].id,
          kind: MeasurementKind.normal,
          startMicros: t - sec * s,
          endMicros: t,
          durationMicros: sec * s,
        ),
      );
    }
  });

  tearDown(() => db.close());

  testWidgets('the analysis names waiting steps and still counts them', (
    tester,
  ) async {
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
    await tester.tap(find.byKey(const Key('analysisTab')));
    await pumpFrames(tester);
    await settle(tester);

    // 12 s: the study itself keeps the waiting step in its cycle time.
    expect(
      tester.widget<Text>(find.byKey(const Key('realCycleTime'))).data,
      '20.0 HM',
    );
    await tester.scrollUntilVisible(
      find.textContaining('2. Wait for machine'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('1. Change'), findsOneWidget);
    expect(find.text('2. Wait for machine · Waiting time'), findsOneWidget);
  });
}
