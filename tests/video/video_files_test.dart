import 'dart:io';

import 'package:cyclescope/core/clock.dart';
import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/core/providers.dart';
import 'package:cyclescope/recording/data/measurement_repository.dart';
import 'package:cyclescope/recording/domain/measurement.dart';
import 'package:cyclescope/study/data/study_repository.dart';
import 'package:cyclescope/study/domain/study.dart';
import 'package:cyclescope/study/presentation/study_list_screen.dart';
import 'package:cyclescope/video/data/video_cleanup.dart';
import 'package:cyclescope/video/platform/video_files.dart';
import 'package:cyclescope/video/presentation/video_study_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_clock.dart';
import '../fakes/fake_platform.dart';
import '../fakes/fake_video.dart';
import '../fakes/fake_video_files.dart';
import '../helpers.dart';

const s = 1000000;

void main() {
  late AppDatabase db;
  late StudyRepository studies;
  late FakeVideoFiles files;
  late int studyId;

  setUp(() async {
    db = await openTestDatabase();
    studies = StudyRepository(db);
    files = FakeVideoFiles();
    studyId = await studies.createStudy(
      name: 'Video',
      mode: StudyMode.video,
      steps: ['Pick', 'Place'],
      now: DateTime(2026),
    );
    await studies.setVideoPath(studyId, 'fake:old.mp4');
  });

  tearDown(() => db.close());

  group('deleteUnusedVideo', () {
    test('deletes a file no study uses', () async {
      await deleteUnusedVideo(studies, files, 'fake:gone.mp4');
      expect(files.deleted, ['fake:gone.mp4']);
    });

    test('keeps a file a study still uses', () async {
      await deleteUnusedVideo(studies, files, 'fake:old.mp4');
      expect(files.deleted, isEmpty);
    });

    test('does nothing without a path', () async {
      await deleteUnusedVideo(studies, files, null);
      expect(files.deleted, isEmpty);
    });
  });

  test('the local store deletes the file and ignores a missing one', () async {
    final dir = await Directory.systemTemp.createTemp('cyclescope_video');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/v.mp4')..writeAsStringSync('x');
    const store = LocalVideoFiles();
    await store.delete(file.path);
    expect(file.existsSync(), isFalse);
    await store.delete(file.path);
  });

  group('study list', () {
    Widget app() => ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        ...fakePlatformOverrides(videoFiles: files),
      ],
      child: localizedApp(const StudyListScreen(checkActiveRuns: false)),
    );

    Future<void> delete(WidgetTester tester, String name) async {
      await tester.longPress(find.text(name));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await settle(tester);
    }

    testWidgets('deleting a video study deletes its video file', (
      tester,
    ) async {
      await tester.pumpWidget(app());
      await settle(tester);
      await delete(tester, 'Video');
      expect(await tester.runAsync(() => studies.getStudy(studyId)), isNull);
      expect(files.deleted, ['fake:old.mp4']);
    });

    testWidgets('the file stays while a copy of the study uses it', (
      tester,
    ) async {
      await tester.runAsync(
        () => studies.copyStudy(studyId, name: 'Copy', now: DateTime(2026, 2)),
      );
      await tester.pumpWidget(app());
      await settle(tester);
      await delete(tester, 'Video');
      expect(files.deleted, isEmpty);
      await delete(tester, 'Copy');
      expect(files.deleted, ['fake:old.mp4']);
    });
  });

  group('video screen', () {
    late FakeVideoPlayback video;

    Future<void> pump(WidgetTester tester) async {
      usePhoneSize(tester);
      video = FakeVideoPlayback();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            clockProvider.overrideWithValue(FakeClock(100 * s) as Clock),
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
          endMicros: s,
          durationMicros: s,
        ),
      );
    }

    Future<String?> path(WidgetTester tester) async =>
        (await tester.runAsync(() => studies.getStudy(studyId)))!.videoPath;

    testWidgets('replacing the video deletes the old file', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const Key('chooseVideoAction')));
      await settle(tester);
      expect(await path(tester), 'fake:new.mp4');
      expect(video.openedPath, 'fake:new.mp4');
      expect(files.deleted, ['fake:old.mp4']);
    });

    testWidgets('keeping the cycles also deletes the old file', (tester) async {
      await tester.runAsync(addCycle);
      await pump(tester);
      await tester.tap(find.byKey(const Key('chooseVideoAction')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('keepOldCycles')));
      await settle(tester);
      expect(await path(tester), 'fake:new.mp4');
      expect(files.deleted, ['fake:old.mp4']);
    });

    testWidgets('cancelling the question deletes the copied new file', (
      tester,
    ) async {
      await tester.runAsync(addCycle);
      await pump(tester);
      await tester.tap(find.byKey(const Key('chooseVideoAction')));
      await settle(tester);
      expect(find.byKey(const Key('keepOldCycles')), findsOneWidget);
      // Tap beside the dialog.
      await tester.tapAt(const Offset(5, 5));
      await settle(tester);
      expect(find.byKey(const Key('keepOldCycles')), findsNothing);
      expect(await path(tester), 'fake:old.mp4');
      expect(files.deleted, ['fake:new.mp4']);
    });

    testWidgets('the old file stays while a copy of the study uses it', (
      tester,
    ) async {
      await tester.runAsync(
        () => studies.copyStudy(studyId, name: 'Copy', now: DateTime(2026, 2)),
      );
      await pump(tester);
      await tester.tap(find.byKey(const Key('chooseVideoAction')));
      await settle(tester);
      expect(await path(tester), 'fake:new.mp4');
      expect(files.deleted, isEmpty);
    });
  });
}
