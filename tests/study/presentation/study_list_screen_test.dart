import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/core/providers.dart';
import 'package:cyclescope/recording/data/run_state_repository.dart';
import 'package:cyclescope/recording/domain/recording_engine.dart';
import 'package:cyclescope/study/data/study_repository.dart';
import 'package:cyclescope/study/domain/study.dart';
import 'package:cyclescope/study/presentation/study_list_screen.dart';
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
      name: 'Line 7',
      mode: StudyMode.timeStudy,
      steps: ['A'],
      now: DateTime(2026),
    );
  });

  tearDown(() => db.close());

  Future<void> saveRun() => RunStateRepository(db).save(
    studyId,
    const EngineSnapshot(
      status: EngineStatus.running,
      cycle: 1,
      stepIndex: 0,
      currentStepId: null,
      stepStartMicros: 0,
      segmentStartMicros: 0,
      accumulatedMicros: 0,
      specialStartMicros: 0,
    ),
    clockMicros: 0,
    now: DateTime(2026),
  );

  Widget app({OpenStudy? onOpen}) => ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      ...fakePlatformOverrides(),
    ],
    child: localizedApp(StudyListScreen(onOpenStudy: onOpen)),
  );

  testWidgets('no dialog without a running recording', (tester) async {
    await tester.pumpWidget(app());
    await settle(tester);
    expect(find.text('Recording in progress'), findsNothing);
    expect(find.byKey(const Key('recBadge')), findsNothing);
  });

  testWidgets('offers to continue a running recording', (tester) async {
    await tester.runAsync(saveRun);
    int? opened;
    await tester.pumpWidget(app(onOpen: (_, id) async => opened = id));
    await settle(tester);
    expect(find.text('Recording in progress'), findsOneWidget);
    expect(find.byKey(const Key('recBadge')), findsOneWidget);
    await tester.tap(find.byKey(const Key('openRunButton')));
    await settle(tester);
    expect(opened, studyId);
  });

  testWidgets('discarding removes the saved run', (tester) async {
    await tester.runAsync(saveRun);
    await tester.pumpWidget(app());
    await settle(tester);
    await tester.tap(find.byKey(const Key('discardRunButton')));
    await settle(tester);
    final rs = await tester.runAsync(
      () => RunStateRepository(db).load(studyId),
    );
    expect(rs, isNull);
    expect(find.byKey(const Key('recBadge')), findsNothing);
  });
}
