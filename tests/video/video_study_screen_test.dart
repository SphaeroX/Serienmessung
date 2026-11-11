import 'package:cyclescope/core/clock.dart';
import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/core/providers.dart';
import 'package:cyclescope/recording/data/measurement_repository.dart';
import 'package:cyclescope/recording/domain/key_interpreter.dart';
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

void main() {
  late AppDatabase db;
  late int studyId;
  late FakeVideoPlayback video;
  late FakeHardwareKeys keys;
  late FakeClock mono;

  setUp(() async {
    db = await openTestDatabase();
    video = FakeVideoPlayback();
    keys = FakeHardwareKeys();
    mono = FakeClock(100 * s);
    studyId = await StudyRepository(db).createStudy(
      name: 'Video',
      mode: StudyMode.video,
      steps: ['Pick', 'Place'],
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
          clockProvider.overrideWithValue(mono as Clock),
          videoPlaybackFactoryProvider.overrideWithValue(() => video),
          videoPickerProvider.overrideWithValue(FakeVideoPicker()),
          ...fakePlatformOverrides(keys: keys),
        ],
        child: localizedApp(VideoStudyScreen(studyId: studyId)),
      ),
    );
    await settle(tester);
  }

  Future<List<int>> durations(WidgetTester tester) async =>
      (await tester.runAsync(
        () => MeasurementRepository(db).listForStudy(studyId),
      ))!.map((m) => m.durationMicros).toList();

  String step(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const Key('currentStepName'))).data!;

  testWidgets('choosing a video opens it and remembers it', (tester) async {
    await pump(tester);
    expect(find.byKey(const Key('chooseVideoButton')), findsOneWidget);
    await tester.tap(find.byKey(const Key('chooseVideoButton')));
    await settle(tester);
    expect(video.openedPath, 'fake:video.mp4');
    expect(find.byKey(const Key('fakeVideo')), findsOneWidget);
    final study = await tester.runAsync(
      () => StudyRepository(db).getStudy(studyId),
    );
    expect(study!.videoPath, 'fake:video.mp4');
  });

  testWidgets('markers create step times from the video position', (
    tester,
  ) async {
    await tester.runAsync(
      () => StudyRepository(db).setVideoPath(studyId, 'fake:v.mp4'),
    );
    await pump(tester);
    video.moveTo(2 * s);
    await tester.tap(find.byKey(const Key('markButton')));
    await settle(tester);
    expect(step(tester), 'Pick');
    video.moveTo(5500000);
    await tester.tap(find.byKey(const Key('markButton')));
    await settle(tester);
    expect(step(tester), 'Place');
    expect(await durations(tester), [3500000]);
  });

  testWidgets('volume up marks at the video position of the key press', (
    tester,
  ) async {
    await tester.runAsync(
      () => StudyRepository(db).setVideoPath(studyId, 'fake:v.mp4'),
    );
    await pump(tester);
    video.moveTo(1 * s);
    keys.press(VolumeKey.up, at: mono.micros);
    await settle(tester);
    video.moveTo(4 * s);
    keys.press(VolumeKey.up, at: mono.micros);
    await settle(tester);
    expect(await durations(tester), [3 * s]);

    keys.press(VolumeKey.down, at: mono.micros); // play/pause
    await settle(tester);
    expect(video.isPlaying, isTrue);
  });

  testWidgets('frame step and speed menu control the player', (tester) async {
    await tester.runAsync(
      () => StudyRepository(db).setVideoPath(studyId, 'fake:v.mp4'),
    );
    await pump(tester);
    video.moveTo(1 * s);
    await tester.tap(find.byKey(const Key('frameForward')));
    await settle(tester);
    expect(video.position, 1 * s + frameMicros);
    await tester.tap(find.byKey(const Key('frameBack')));
    await settle(tester);
    expect(video.position, 1 * s);

    await tester.tap(find.byKey(const Key('speedMenu')));
    await pumpFrames(tester, count: 4);
    await tester.tap(find.byKey(const Key('speed-0.5')));
    await pumpFrames(tester, count: 4);
    expect(video.currentSpeed, 0.5);
  });

  testWidgets('a marker before the last one is rejected with a hint', (
    tester,
  ) async {
    await tester.runAsync(
      () => StudyRepository(db).setVideoPath(studyId, 'fake:v.mp4'),
    );
    await pump(tester);
    video.moveTo(5 * s);
    await tester.tap(find.byKey(const Key('markButton')));
    await settle(tester);
    video.moveTo(2 * s);
    await tester.tap(find.byKey(const Key('markButton')));
    await settle(tester);
    await pumpFrames(tester, count: 3);
    expect(find.textContaining('before the last marker'), findsOneWidget);
    expect(await durations(tester), isEmpty);
  });
}
