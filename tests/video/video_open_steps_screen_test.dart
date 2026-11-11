import 'package:cyclescope/core/clock.dart';
import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/core/providers.dart';
import 'package:cyclescope/recording/presentation/recording_screen.dart';
import 'package:cyclescope/study/data/study_repository.dart';
import 'package:cyclescope/study/domain/study.dart';
import 'package:cyclescope/video/presentation/video_study_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_clock.dart';
import '../fakes/fake_platform.dart';
import '../fakes/fake_video.dart';
import '../helpers.dart';

const s = 1000000;

/// Video study created without steps: the steps are defined by the markers
/// of the first cycle.
void main() {
  late AppDatabase db;
  late int studyId;
  late FakeVideoPlayback video;

  setUp(() async {
    db = await openTestDatabase();
    video = FakeVideoPlayback();
    final repo = StudyRepository(db);
    studyId = await repo.createStudy(
      name: 'Video',
      mode: StudyMode.video,
      steps: const [],
      now: DateTime(2026),
    );
    await repo.setVideoPath(studyId, 'fake:v.mp4');
  });

  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(FakeClock(100 * s) as Clock),
          videoPlaybackFactoryProvider.overrideWithValue(() => video),
          videoPickerProvider.overrideWithValue(FakeVideoPicker()),
          ...fakePlatformOverrides(),
        ],
        child: localizedApp(VideoStudyScreen(studyId: studyId)),
      ),
    );
    await settle(tester);
  }

  String step(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const Key('currentStepName'))).data!;

  Future<void> markAt(WidgetTester tester, int at) async {
    video.moveTo(at);
    await tester.tap(find.byKey(const Key('markButton')));
    await settle(tester);
  }

  Future<List<String>> stepNames(WidgetTester tester, int id) async =>
      (await tester.runAsync(() => StudyRepository(db).getSteps(id)))!
          .map((st) => st.name)
          .toList();

  Future<void> markTwoStepsAndClose(WidgetTester tester) async {
    await markAt(tester, 1 * s);
    await markAt(tester, 3 * s);
    video.moveTo(5 * s);
    await tapVisible(tester, find.byKey(const Key('closeCycleButton')));
    await settle(tester);
  }

  testWidgets('markers create the steps of the first cycle', (tester) async {
    await pump(tester);
    expect(find.byKey(const Key('closeCycleButton')), findsNothing);
    await markAt(tester, 1 * s);
    expect(step(tester), 'Step 1');
    await markAt(tester, 3 * s);
    expect(step(tester), 'Step 2');
    expect(find.byKey(const Key('nextStepName')), findsNothing);
    expect(find.byKey(const Key('closeCycleButton')), findsOneWidget);
    expect(await stepNames(tester, studyId), ['Step 1', 'Step 2']);
  });

  testWidgets('closing the cycle asks for the step names', (tester) async {
    await pump(tester);
    await markTwoStepsAndClose(tester);

    expect(find.byKey(const Key('stepNameField-0')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('stepNameField-0')), 'Pick');
    await tester.enterText(find.byKey(const Key('stepNameField-1')), 'Place');
    await tester.tap(find.byKey(const Key('saveStepNames')));
    await settle(tester);

    expect(await stepNames(tester, studyId), ['Pick', 'Place']);
    expect(find.byKey(const Key('closeCycleButton')), findsNothing);
    // Cycle 2 starts with the first step.
    expect(step(tester), 'Pick');
  });

  testWidgets('the steps can be used for a live time study', (tester) async {
    await pump(tester);
    await markTwoStepsAndClose(tester);
    await tester.tap(find.byKey(const Key('saveStepNames')));
    await settle(tester);

    await tester.tap(find.byKey(const Key('studyMenu')));
    await pumpFrames(tester);
    await tester.tap(find.byKey(const Key('useAsTimeStudy')));
    await settle(tester);
    await pumpFrames(tester);
    await settle(tester);

    final studies = (await tester.runAsync(
      () => StudyRepository(db).listStudies(),
    ))!.map((x) => x.study).toList();
    final live = studies.singleWhere((x) => x.mode == StudyMode.timeStudy);
    expect(live.name, 'Video (live)');
    expect(await stepNames(tester, live.id), ['Step 1', 'Step 2']);
    expect(find.byType(RecordingScreen), findsOneWidget);
  });
}
