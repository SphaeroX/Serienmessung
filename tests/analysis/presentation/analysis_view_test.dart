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
      name: 'Line',
      mode: StudyMode.timeStudy,
      steps: ['A', 'B'],
      now: DateTime(2026),
    );
    final ids = (await studies.getSteps(studyId)).map((x) => x.id).toList();
    final repo = MeasurementRepository(db);
    var t = 0;
    // Cycle totals 10, 11, 12, 13, 40 s.
    const split = [(4, 6), (5, 6), (5, 7), (6, 7), (30, 10)];
    for (var c = 0; c < split.length; c++) {
      for (final (i, sec) in [(0, split[c].$1), (1, split[c].$2)]) {
        t += sec * s;
        await repo.insert(
          studyId,
          MeasurementDraft(
            cycle: c + 1,
            stepId: ids[i],
            kind: MeasurementKind.normal,
            startMicros: t - sec * s,
            endMicros: t,
            durationMicros: sec * s,
          ),
        );
      }
    }
  });

  tearDown(() => db.close());

  Future<void> openAnalysis(WidgetTester tester) async {
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
  }

  String real(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const Key('realCycleTime'))).data!;

  testWidgets('shows the median cycle time by default', (tester) async {
    await openAnalysis(tester);
    expect(real(tester), '20.0 HM'); // 12 s
  });

  testWidgets('switching to IQR removes the disturbed cycle and is saved', (
    tester,
  ) async {
    await openAnalysis(tester);
    await tester.tap(find.byKey(const Key('method-iqr')));
    await settle(tester);
    expect(real(tester), '19.2 HM'); // 11.5 s
    expect(find.textContaining('1 outlier'), findsOneWidget);
    final study = await tester.runAsync(
      () => StudyRepository(db).getStudy(studyId),
    );
    expect(study!.cycleTimeMethod, 'iqr');
  });

  testWidgets('unit can be switched', (tester) async {
    await openAnalysis(tester);
    await tester.tap(find.byKey(const Key('unit-seconds')));
    await settle(tester);
    expect(real(tester), '12.00 s');
    await tester.tap(find.byKey(const Key('method-mean')));
    await settle(tester);
    expect(real(tester), '17.20 s');
  });
}
