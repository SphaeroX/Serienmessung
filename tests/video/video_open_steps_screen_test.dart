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

  bool cycleEnabled(WidgetTester tester) => tester
      .widget<ButtonStyleButton>(find.byKey(const Key('closeCycleButton')))
      .enabled;

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
    // The cycle button is always shown, but only usable while running.
    expect(cycleEnabled(tester), isFalse);
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
    // Later cycles can be ended with the same button.
    expect(cycleEnabled(tester), isTrue);
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

  testWidgets('the name dialog closes cleanly (save and cancel)', (
    tester,
  ) async {
    await pump(tester);
    await markTwoStepsAndClose(tester);
    await tester.enterText(find.byKey(const Key('stepNameField-0')), 'Pick');
    // Keyboard open while editing ...
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();
    await tester.tap(find.byKey(const Key('saveStepNames')));
    await tester.pump();
    // ... and closing while the dialog animates out (rebuilds the dialog).
    tester.view.viewInsets = FakeViewPadding.zero;
    await pumpFrames(tester);
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('stepNameField-0')), findsNothing);
    expect(step(tester), 'Pick');
  });

  testWidgets('saving the suggested names unchanged does not crash', (
    tester,
  ) async {
    await pump(tester);
    await markAt(tester, 1 * s);
    await markAt(tester, 2 * s);
    await markAt(tester, 3 * s);
    video.moveTo(4 * s);
    await tapVisible(tester, find.byKey(const Key('closeCycleButton')));
    await settle(tester);
    await pumpFrames(tester);
    expect(find.byKey(const Key('stepNameField-2')), findsOneWidget);
    // The first field has focus, so the keyboard is open.
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();

    await tester.tap(find.byKey(const Key('saveStepNames')));
    await tester.pump();
    // The keyboard closes while the dialog animates out.
    tester.view.viewInsets = FakeViewPadding.zero;
    await pumpFrames(tester);
    await settle(tester);

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('stepNameField-0')), findsNothing);
    expect(await stepNames(tester, studyId), ['Step 1', 'Step 2', 'Step 3']);
  });
}
