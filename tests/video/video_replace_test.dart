import 'package:cyclescope/core/clock.dart';
import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/core/providers.dart';
import 'package:cyclescope/recording/data/measurement_repository.dart';
import 'package:cyclescope/recording/domain/measurement.dart';
import 'package:cyclescope/study/data/study_repository.dart';
import 'package:cyclescope/study/domain/study.dart';
import 'package:cyclescope/video/presentation/video_study_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_clock.dart';
import '../fakes/fake_platform.dart';
import '../fakes/fake_video.dart';
import '../fakes/fake_video_files.dart';
import '../helpers.dart';

const _s = 1000000;

/// A player that cannot open some files (broken or unsupported video).
class _PickyPlayback extends FakeVideoPlayback {
  final unplayable = <String>{};
  final opened = <String>[];

  @override
  Future<void> open(String path) async {
    if (unplayable.contains(path)) throw StateError('not playable');
    opened.add(path);
    await super.open(path);
  }
}

void main() {
  late AppDatabase db;
  late StudyRepository studies;
  late FakeVideoFiles files;
  late _PickyPlayback video;
  late int studyId;

  setUp(() async {
    db = await openTestDatabase();
    studies = StudyRepository(db);
    files = FakeVideoFiles();
    video = _PickyPlayback();
    studyId = await studies.createStudy(
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
          clockProvider.overrideWithValue(FakeClock(100 * _s) as Clock),
          videoPlaybackFactoryProvider.overrideWithValue(() => video),
          frameSourceFactoryProvider.overrideWithValue(FakeFrameSource.new),
          videoPickerProvider.overrideWithValue(
            FakeVideoPicker('fake:new.mp4'),
          ),
          ...fakePlatformOverrides(videoFiles: files),
        ],
        child: localizedApp(VideoStudyScreen(studyId: studyId)),
      ),
    );
    await settle(tester);
  }

  Future<void> addCycle() async {
    final steps = await studies.getSteps(studyId);
    await MeasurementRepository(db).insert(
      studyId,
      MeasurementDraft(
        cycle: 1,
        stepId: steps.first.id,
        kind: MeasurementKind.normal,
        startMicros: 0,
        endMicros: _s,
        durationMicros: _s,
      ),
    );
  }

  Future<String?> storedPath(WidgetTester tester) async =>
      (await tester.runAsync(() => studies.getStudy(studyId)))!.videoPath;

  Future<int> timeCount(WidgetTester tester) async => (await tester.runAsync(
    () => MeasurementRepository(db).listForStudy(studyId),
  ))!.length;

  Future<void> replace(WidgetTester tester, {String? answer}) async {
    await tester.tap(find.byKey(const Key('chooseVideoAction')));
    await settle(tester);
    if (answer != null) {
      await tester.tap(find.byKey(Key(answer)));
      await settle(tester);
    }
    await pumpFrames(tester, count: 3);
  }

  testWidgets('an unplayable new video keeps the old one', (tester) async {
    await tester.runAsync(() => studies.setVideoPath(studyId, 'fake:old.mp4'));
    video.unplayable.add('fake:new.mp4');
    await pump(tester);
    expect(video.openedPath, 'fake:old.mp4');

    await replace(tester);
    expect(await storedPath(tester), 'fake:old.mp4');
    expect(files.deleted, ['fake:new.mp4']);
    expect(video.openedPath, 'fake:old.mp4');
    expect(find.byKey(const Key('fakeVideo')), findsOneWidget);
    expect(find.textContaining('could not be opened'), findsOneWidget);
  });

  testWidgets('"delete cycles" keeps them when the new video fails', (
    tester,
  ) async {
    await tester.runAsync(() => studies.setVideoPath(studyId, 'fake:old.mp4'));
    await tester.runAsync(addCycle);
    video.unplayable.add('fake:new.mp4');
    await pump(tester);

    await replace(tester, answer: 'deleteOldCycles');
    expect(await timeCount(tester), 1);
    expect(await storedPath(tester), 'fake:old.mp4');
    expect(files.deleted, ['fake:new.mp4']);
  });

  testWidgets('an unplayable first video leaves "no video yet"', (
    tester,
  ) async {
    video.unplayable.add('fake:new.mp4');
    await pump(tester);
    await replace(tester);
    expect(await storedPath(tester), isNull);
    expect(files.deleted, ['fake:new.mp4']);
    expect(find.byKey(const Key('chooseVideoButton')), findsOneWidget);
    expect(find.textContaining('could not be opened'), findsOneWidget);
  });

  testWidgets('a playable new video replaces the old one as before', (
    tester,
  ) async {
    await tester.runAsync(() => studies.setVideoPath(studyId, 'fake:old.mp4'));
    await tester.runAsync(addCycle);
    await pump(tester);
    await replace(tester, answer: 'deleteOldCycles');
    expect(await storedPath(tester), 'fake:new.mp4');
    expect(await timeCount(tester), 0);
    expect(files.deleted, ['fake:old.mp4']);
    expect(video.openedPath, 'fake:new.mp4');
  });

  testWidgets('a cancelled press on the special button ends the special time', (
    tester,
  ) async {
    await tester.runAsync(() => studies.setVideoPath(studyId, 'fake:old.mp4'));
    await pump(tester);
    video.moveTo(_s);
    await tester.tap(find.byKey(const Key('markButton')));
    await settle(tester);

    video.moveTo(2 * _s);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('specialButton'))),
    );
    await settle(tester);
    video.moveTo(3 * _s);
    await gesture.cancel();
    await settle(tester);

    final stored = (await tester.runAsync(
      () => MeasurementRepository(db).listForStudy(studyId),
    ))!;
    expect(stored.single.kind, MeasurementKind.special);
    expect(stored.single.durationMicros, _s);
  });

  testWidgets('a marker at the position of the last one names the reason', (
    tester,
  ) async {
    await tester.runAsync(() => studies.setVideoPath(studyId, 'fake:old.mp4'));
    await pump(tester);
    for (final _ in [1, 2]) {
      video.moveTo(4 * _s);
      await tester.tap(find.byKey(const Key('markButton')));
      await settle(tester);
    }
    await pumpFrames(tester, count: 3);
    expect(find.textContaining('already a marker here'), findsOneWidget);
    expect(await timeCount(tester), 0);
  });
}
