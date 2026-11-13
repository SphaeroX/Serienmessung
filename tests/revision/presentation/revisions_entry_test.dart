import 'package:cyclescope/core/clock.dart';
import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/core/providers.dart';
import 'package:cyclescope/recording/data/measurement_repository.dart';
import 'package:cyclescope/recording/presentation/recording_screen.dart';
import 'package:cyclescope/revision/data/revision_repository.dart';
import 'package:cyclescope/revision/presentation/revisions_screen.dart';
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
      steps: ['Pick', 'Place'],
      now: DateTime(2026),
    );
  });

  tearDown(() => db.close());

  testWidgets('recording screen opens the revisions and reloads after a '
      'new measurement was started', (tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(clock as Clock),
          wallClockProvider.overrideWithValue(() => DateTime(2026, 5, 1)),
          ...fakePlatformOverrides(),
        ],
        child: localizedApp(RecordingScreen(studyId: studyId)),
      ),
    );
    await settle(tester);

    // Record one cycle and stop.
    await tester.tap(find.byKey(const Key('startStopButton')));
    await settle(tester);
    for (var i = 0; i < 2; i++) {
      clock.advanceSeconds(3);
      await tester.tap(find.byKey(const Key('nextButton')));
      await settle(tester);
    }
    await tester.tap(find.byKey(const Key('resetButton')));
    await pumpFrames(tester);
    await tester.tap(find.text('Reset').last);
    await settle(tester);

    await tester.tap(find.byKey(const Key('revisionsButton')));
    await pumpFrames(tester);
    await settle(tester);
    expect(find.byType(RevisionsScreen), findsOneWidget);

    await tester.tap(find.byKey(const Key('newRevisionButton')));
    await pumpFrames(tester);
    await tester.tap(find.byKey(const Key('confirmNewRevision')));
    await settle(tester);
    await pumpFrames(tester);
    await settle(tester);

    expect(find.byType(RevisionsScreen), findsNothing);
    expect(find.textContaining('Revision 2'), findsOneWidget);
    expect(
      await tester.runAsync(
        () => MeasurementRepository(db).listForStudy(studyId),
      ),
      isEmpty,
    );
    expect(
      (await tester.runAsync(
        () => RevisionRepository(db).listRevisions(studyId),
      ))!.single.measurements,
      hasLength(2),
    );
    // Times are stamped with the wall clock.
    expect(
      (await tester.runAsync(
        () => RevisionRepository(db).listRevisions(studyId),
      ))!.single.lastRecordedAt,
      DateTime(2026, 5, 1),
    );
  });
}
