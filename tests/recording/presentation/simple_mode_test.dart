import 'package:cyclescope/analysis/domain/analysis.dart';
import 'package:cyclescope/analysis/domain/statistics.dart';
import 'package:cyclescope/core/clock.dart';
import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/core/providers.dart';
import 'package:cyclescope/recording/data/measurement_repository.dart';
import 'package:cyclescope/recording/domain/key_interpreter.dart';
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
  test('engine in simple mode: 5 laps with correct durations', () {
    final clock = FakeClock();
    final e = RecordingEngine(clock: clock, sequence: const [null]);
    e.start(cycle: 1);
    final laps = [];
    for (var i = 1; i <= 5; i++) {
      clock.advanceSeconds(i);
      laps.addAll(e.next());
    }
    expect(laps.map((m) => m.cycle), [1, 2, 3, 4, 5]);
    expect(laps.map((m) => m.durationMicros), [
      1 * s,
      2 * s,
      3 * s,
      4 * s,
      5 * s,
    ]);
    expect(laps.every((m) => m.stepId == null), isTrue);
  });

  late AppDatabase db;
  late FakeClock clock;
  late int studyId;
  late FakeHardwareKeys keys;

  setUp(() async {
    db = await openTestDatabase();
    clock = FakeClock(5 * s);
    keys = FakeHardwareKeys();
    studyId = await StudyRepository(db).createStudy(
      name: 'Stopwatch',
      mode: StudyMode.simple,
      steps: const [],
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
          clockProvider.overrideWithValue(clock as Clock),
          ...fakePlatformOverrides(keys: keys),
        ],
        child: localizedApp(RecordingScreen(studyId: studyId)),
      ),
    );
    await settle(tester);
  }

  Future<void> tap(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(Key(key)));
    await settle(tester);
  }

  testWidgets('lap list shows lap numbers, total and lap time', (tester) async {
    await pump(tester);
    expect(find.text('Lap 1'), findsOneWidget);
    expect(find.text('LAP'), findsWidgets); // tile label and button
    await tap(tester, 'startStopButton');
    clock.advanceSeconds(2);
    await tap(tester, 'nextButton');
    clock.advanceSeconds(3);
    await tap(tester, 'nextButton');

    expect(
      tester.widget<Text>(find.byKey(const Key('currentStepName'))).data,
      'Lap 3',
    );
    final rows = find.byKey(const Key('liveRow'));
    expect(rows, findsNWidgets(2));
    final newest = rows.first;
    expect(
      find.descendant(of: newest, matching: find.text('Lap 2')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: newest, matching: find.text('00:05.000')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: newest, matching: find.text('00:03.000')),
      findsOneWidget,
    );
  });

  testWidgets('volume keys: up = lap, hold = special time', (tester) async {
    await pump(tester);
    keys.press(VolumeKey.down, at: clock.micros);
    await settle(tester);
    clock.advanceSeconds(2);
    keys.press(VolumeKey.up, at: clock.micros);
    await settle(tester);
    clock.advanceSeconds(1);
    keys.emit(VolumeKey.up, down: true, at: clock.micros);
    await tester.pump(const Duration(milliseconds: 450));
    await settle(tester);
    clock.advanceSeconds(4);
    keys.emit(VolumeKey.up, down: false, at: clock.micros);
    await settle(tester);
    clock.advanceSeconds(1);
    keys.press(VolumeKey.up, at: clock.micros);
    await settle(tester);

    final stored = (await tester.runAsync(
      () => MeasurementRepository(db).listForStudy(studyId),
    ))!;
    final a = StudyAnalysis.compute(
      measurements: stored,
      steps: const [],
      mode: StudyMode.simple,
      method: CycleTimeMethod.mean,
    );
    // Laps: 2 s and 2 s (1 s + 1 s, the 4 s special time excluded).
    expect(a.cycleTotals, [2 * s, 2 * s]);
    expect(a.specialTotal, 4 * s);
  });
}
