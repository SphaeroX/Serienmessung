import 'package:cyclescope/core/clock.dart';
import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/core/providers.dart';
import 'package:cyclescope/recording/data/measurement_repository.dart';
import 'package:cyclescope/recording/domain/key_interpreter.dart';
import 'package:cyclescope/study/data/study_repository.dart';
import 'package:cyclescope/study/domain/study.dart';
import 'package:cyclescope/video/domain/frame_cache.dart';
import 'package:cyclescope/analysis/presentation/analysis_view.dart';
import 'package:cyclescope/recording/presentation/cycles_view.dart';
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
  late FakeFrameSource frames;

  setUp(() async {
    db = await openTestDatabase();
    video = FakeVideoPlayback();
    keys = FakeHardwareKeys();
    mono = FakeClock(100 * s);
    frames = FakeFrameSource();
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
          frameSourceFactoryProvider.overrideWithValue(() => frames),
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

  Future<void> markAt(WidgetTester tester, int micros) async {
    video.moveTo(micros);
    await tester.tap(find.byKey(const Key('markButton')));
    await settle(tester);
  }

  Future<void> openTab(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(Key(key)));
    await settle(tester);
  }

  testWidgets('after deleting the cycles new markers can be set anywhere', (
    tester,
  ) async {
    await tester.runAsync(
      () => StudyRepository(db).setVideoPath(studyId, 'fake:v.mp4'),
    );
    await pump(tester);
    // Cycle 1 (Pick, Place) and the start of cycle 2.
    await markAt(tester, 1 * s);
    await markAt(tester, 2 * s);
    await markAt(tester, 3 * s);
    await markAt(tester, 4 * s);
    expect(await durations(tester), [1 * s, 1 * s, 1 * s]);

    await openTab(tester, 'cyclesTab');
    await tester.tap(find.byKey(const Key('deleteCycle-2')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('deleteCycle-1')));
    await settle(tester);
    expect(await durations(tester), isEmpty);

    // Back at the beginning of the video the markers work again.
    await openTab(tester, 'markTab');
    await markAt(tester, 500000);
    expect(find.textContaining('before the last marker'), findsNothing);
    expect(step(tester), 'Pick');
    await markAt(tester, 1500000);
    expect(step(tester), 'Place');
    expect(await durations(tester), [1 * s]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('deleting an older cycle keeps the running cycle', (
    tester,
  ) async {
    await tester.runAsync(
      () => StudyRepository(db).setVideoPath(studyId, 'fake:v.mp4'),
    );
    await pump(tester);
    await markAt(tester, 1 * s);
    await markAt(tester, 2 * s);
    await markAt(tester, 3 * s);
    await markAt(tester, 4 * s);

    await openTab(tester, 'cyclesTab');
    await tester.tap(find.byKey(const Key('deleteCycle-1')));
    await settle(tester);
    await openTab(tester, 'markTab');
    expect(step(tester), 'Place');
    await markAt(tester, 5 * s);
    expect(await durations(tester), [1 * s, 1 * s]);
  });

  testWidgets('replacing the video can delete the old cycles', (tester) async {
    await tester.runAsync(
      () => StudyRepository(db).setVideoPath(studyId, 'fake:v.mp4'),
    );
    await pump(tester);
    await markAt(tester, 1 * s);
    await markAt(tester, 2 * s);
    await markAt(tester, 3 * s);

    await tester.tap(find.byKey(const Key('chooseVideoAction')));
    await settle(tester);
    expect(find.byKey(const Key('deleteOldCycles')), findsOneWidget);
    await tester.tap(find.byKey(const Key('deleteOldCycles')));
    await settle(tester);
    expect(video.openedPath, 'fake:video.mp4');
    expect(await durations(tester), isEmpty);

    await markAt(tester, 500000);
    expect(step(tester), 'Pick');
    await markAt(tester, 1 * s);
    expect(await durations(tester), [500000]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('replacing the video can keep the old cycles', (tester) async {
    await tester.runAsync(
      () => StudyRepository(db).setVideoPath(studyId, 'fake:v.mp4'),
    );
    await pump(tester);
    await markAt(tester, 1 * s);
    await markAt(tester, 2 * s);
    await markAt(tester, 3 * s);

    await tester.tap(find.byKey(const Key('chooseVideoAction')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('keepOldCycles')));
    await settle(tester);
    expect(await durations(tester), [1 * s, 1 * s]);

    // The open marker run of the old video is dropped: a new cycle starts.
    await markAt(tester, 500000);
    expect(step(tester), 'Pick');
    await markAt(tester, 1 * s);
    expect(await durations(tester), [1 * s, 1 * s, 500000]);
  });

  testWidgets('a new video without cycles is opened without asking', (
    tester,
  ) async {
    await tester.runAsync(
      () => StudyRepository(db).setVideoPath(studyId, 'fake:v.mp4'),
    );
    await pump(tester);
    await tester.tap(find.byKey(const Key('chooseVideoAction')));
    await settle(tester);
    expect(find.byKey(const Key('deleteOldCycles')), findsNothing);
    expect(video.openedPath, 'fake:video.mp4');
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

  testWidgets('step and cycle buttons sit side by side; cycle ends early', (
    tester,
  ) async {
    await tester.runAsync(
      () => StudyRepository(db).setVideoPath(studyId, 'fake:v.mp4'),
    );
    await pump(tester);
    final stepButton = find.byKey(const Key('markButton'));
    final cycleButton = find.byKey(const Key('closeCycleButton'));
    expect(stepButton, findsOneWidget);
    expect(cycleButton, findsOneWidget);
    expect(tester.widget<ButtonStyleButton>(cycleButton).enabled, isFalse);
    expect(
      tester.getCenter(stepButton).dy,
      moreOrLessEquals(tester.getCenter(cycleButton).dy),
    );

    video.moveTo(1 * s);
    await tester.tap(stepButton);
    await settle(tester);
    expect(find.text('STEP'), findsOneWidget);
    expect(find.text('CYCLE'), findsOneWidget);
    expect(tester.widget<ButtonStyleButton>(cycleButton).enabled, isTrue);

    // End cycle 1 while still on "Pick": "Place" is skipped.
    video.moveTo(3 * s);
    await tester.tap(cycleButton);
    await settle(tester);
    expect(step(tester), 'Pick');
    expect(await durations(tester), [2 * s]);
    expect(find.byKey(const Key('stepNameField-0')), findsNothing);
    expect(tester.takeException(), isNull);
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

  testWidgets('marking, cycles and analysis are separate tabs', (tester) async {
    await tester.runAsync(
      () => StudyRepository(db).setVideoPath(studyId, 'fake:v.mp4'),
    );
    await pump(tester);
    final videoParts = [
      find.byKey(const Key('fakeVideo')),
      find.byKey(const Key('playPause')),
      find.byKey(const Key('markButton')),
      find.byKey(const Key('closeCycleButton')),
      find.byKey(const Key('currentStepName')),
    ];

    // The marking tab is open first and holds video, transport and markers.
    for (final part in videoParts) {
      expect(part, findsOneWidget);
    }
    expect(find.byType(CyclesView), findsNothing);
    expect(find.byType(AnalysisView), findsNothing);
    final videoHeight = tester
        .getSize(find.byKey(const Key('videoZoom')))
        .height;

    // Playing video pauses when another tab opens; the video gives way.
    await tester.tap(find.byKey(const Key('playPause')));
    await settle(tester);
    expect(video.playing, isTrue);
    await tester.tap(find.byKey(const Key('cyclesTab')));
    await settle(tester);
    expect(video.playing, isFalse);
    expect(find.byType(CyclesView), findsOneWidget);
    for (final part in videoParts) {
      expect(part, findsNothing);
    }

    await tester.tap(find.byKey(const Key('analysisTab')));
    await settle(tester);
    expect(find.byType(AnalysisView), findsOneWidget);
    for (final part in videoParts) {
      expect(part, findsNothing);
    }

    // Swiping must not switch tabs: on the marking tab it pans the video.
    await tester.tap(find.byKey(const Key('markTab')));
    await settle(tester);
    expect(find.byKey(const Key('fakeVideo')), findsOneWidget);
    await tester.fling(
      find.byKey(const Key('videoZoom')),
      const Offset(-400, 0),
      1000,
    );
    await settle(tester);
    expect(find.byKey(const Key('fakeVideo')), findsOneWidget);

    // Without the lists below, the video gets more room than before.
    final screenHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(videoHeight, greaterThan(screenHeight * 0.4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the video can be zoomed, panned and reset', (tester) async {
    await tester.runAsync(
      () => StudyRepository(db).setVideoPath(studyId, 'fake:v.mp4'),
    );
    await pump(tester);
    double scale() => tester
        .widget<InteractiveViewer>(find.byKey(const Key('videoZoom')))
        .transformationController!
        .value
        .getMaxScaleOnAxis();
    expect(scale(), 1);
    expect(find.byKey(const Key('resetZoom')), findsNothing);

    // Pinch with two fingers.
    final center = tester.getCenter(find.byKey(const Key('videoZoom')));
    final a = await tester.startGesture(center - const Offset(20, 0));
    final b = await tester.startGesture(center + const Offset(20, 0));
    await tester.pump();
    for (var i = 0; i < 5; i++) {
      await a.moveBy(const Offset(-15, 0));
      await b.moveBy(const Offset(15, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await a.up();
    await b.up();
    await settle(tester);
    expect(scale(), greaterThan(2));

    await tester.tap(find.byKey(const Key('resetZoom')));
    await settle(tester);
    expect(scale(), 1);
    expect(find.byKey(const Key('resetZoom')), findsNothing);
  });

  testWidgets('frame steps show preloaded frames at the real frame rate', (
    tester,
  ) async {
    frames = FakeFrameSource(
      timing: const FrameTiming(fps: 25, frameCount: 1500),
    );
    await tester.runAsync(
      () => StudyRepository(db).setVideoPath(studyId, 'fake:v.mp4'),
    );
    await pump(tester);
    // Frames around the start are decoded in advance.
    expect(frames.requests, isNotEmpty);
    expect(find.byKey(const Key('cachedFrame')), findsNothing);

    video.moveTo(1 * s); // frame 25
    await tester.tap(find.byKey(const Key('frameForward')));
    await settle(tester);
    expect(video.position, 1040000); // frame 26 at 25 fps
    expect(find.byKey(const Key('cachedFrame')), findsOneWidget);
    expect(frames.requests.any((r) => r.$1 <= 26 && 26 < r.$1 + r.$2), isTrue);

    await tester.tap(find.byKey(const Key('frameBack')));
    await tester.tap(find.byKey(const Key('frameBack')));
    await settle(tester);
    expect(video.position, 960000); // frame 24

    // Playing shows the player again.
    await tester.tap(find.byKey(const Key('playPause')));
    await settle(tester);
    expect(find.byKey(const Key('cachedFrame')), findsNothing);
  });

  testWidgets('leaving the screen releases the frame decoder', (tester) async {
    await tester.runAsync(
      () => StudyRepository(db).setVideoPath(studyId, 'fake:v.mp4'),
    );
    await pump(tester);
    await tester.pumpWidget(const SizedBox());
    expect(frames.closed, isTrue);
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

  testWidgets('dragging the timeline scrubs the video', (tester) async {
    await tester.runAsync(
      () => StudyRepository(db).setVideoPath(studyId, 'fake:v.mp4'),
    );
    await pump(tester);
    await tester.tap(find.byKey(const Key('playPause')));
    await settle(tester);
    video.moveTo(10 * s);
    await settle(tester);
    // Drag to the left = forward in time (60 px = 1 s at default zoom).
    await tester.drag(find.byKey(const Key('timeline')), const Offset(-120, 0));
    await settle(tester);
    expect(video.isPlaying, isFalse);
    expect(video.position, greaterThan(10 * s));
  });

  testWidgets('long-press drag moves a marker between two steps', (
    tester,
  ) async {
    await tester.runAsync(
      () => StudyRepository(db).setVideoPath(studyId, 'fake:v.mp4'),
    );
    await pump(tester);
    for (final t in [1, 3, 6]) {
      video.moveTo(t * s);
      await settle(tester);
      await tester.tap(find.byKey(const Key('markButton')));
      await settle(tester);
    }
    expect(await durations(tester), [2 * s, 3 * s]);

    // Put the marker at 3 s under the fixed playhead (middle).
    video.moveTo(3 * s);
    await settle(tester);
    final center = tester.getCenter(find.byKey(const Key('timeline')));
    final g = await tester.startGesture(center);
    await tester.pump(const Duration(milliseconds: 700));
    await g.moveBy(const Offset(30, 0));
    await tester.pump(const Duration(milliseconds: 50));
    await g.moveBy(const Offset(30, 0)); // +60 px = +1 s
    await tester.pump(const Duration(milliseconds: 50));
    await g.up();
    await settle(tester);
    expect(await durations(tester), [3 * s, 2 * s]);
  });
}
