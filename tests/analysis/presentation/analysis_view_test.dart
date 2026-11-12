import 'package:cyclescope/core/clock.dart';
import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/core/providers.dart';
import 'package:cyclescope/core/time_format.dart';
import 'package:cyclescope/recording/data/measurement_repository.dart';
import 'package:cyclescope/recording/domain/measurement.dart';
import 'package:cyclescope/recording/presentation/recording_screen.dart';
import 'package:cyclescope/settings/data/settings_repository.dart';
import 'package:cyclescope/settings/presentation/settings_controller.dart';
import 'package:cyclescope/study/data/study_repository.dart';
import 'package:cyclescope/study/domain/study.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
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

  Future<void> openAnalysis(WidgetTester tester, {Override? settings}) async {
    usePhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          ?settings,
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

  testWidgets('the last chosen unit is remembered for the next analysis', (
    tester,
  ) async {
    await openAnalysis(tester);
    await tester.tap(find.byKey(const Key('unit-seconds')));
    await settle(tester);
    final saved = (await tester.runAsync(() => SettingsRepository(db).load()))!;
    expect(saved.defaultUnit, TimeUnit.seconds);

    // A new screen (e.g. after an app restart) starts with seconds.
    await tester.pumpWidget(const SizedBox());
    await openAnalysis(
      tester,
      settings: initialSettingsProvider.overrideWithValue(saved),
    );
    expect(real(tester), '12.00 s');
  });

  testWidgets('the notes field grows while writing and shrinks after', (
    tester,
  ) async {
    await openAnalysis(tester);
    final notes = find.byKey(const Key('studyNotes'));
    final small = tester.getSize(notes).height;

    await tester.tap(notes);
    await settle(tester);
    final large = tester.getSize(notes).height;
    expect(large, greaterThan(small * 3));

    // Leaving the field (tap outside) makes it small again.
    await tester.tapAt(
      tester.getCenter(find.byKey(const Key('realCycleTime'))),
    );
    await settle(tester);
    expect(tester.getSize(notes).height, small);
  });

  testWidgets('notes above the times are saved with the study', (tester) async {
    await openAnalysis(tester);
    final notes = find.byKey(const Key('studyNotes'));
    expect(notes, findsOneWidget);
    expect(
      tester.getTopLeft(notes).dy,
      lessThan(tester.getTopLeft(find.byKey(const Key('realCycleTime'))).dy),
    );
    await tester.enterText(notes, 'New fixture since Monday');
    await settle(tester);
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
    final study = await tester.runAsync(
      () => StudyRepository(db).getStudy(studyId),
    );
    expect(study!.notes, 'New fixture since Monday');

    await openAnalysis(tester);
    expect(find.text('New fixture since Monday'), findsOneWidget);
  });
}
