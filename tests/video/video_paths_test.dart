import 'dart:io';

import 'package:cyclescope/video/platform/video_paths.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory documents;
  late VideoPaths paths;

  setUp(() async {
    documents = await Directory.systemTemp.createTemp('cyclescope_documents');
    paths = VideoPaths(documentsDirectory: () async => documents);
  });

  tearDown(() => documents.delete(recursive: true));

  File createVideo(String fileName) =>
      File(p.join(documents.path, 'videos', fileName))
        ..createSync(recursive: true);

  test('a video is stored relative to the documents folder', () {
    expect(paths.stored('study_1_2.mp4'), 'videos/study_1_2.mp4');
  });

  test('a stored path resolves into the current documents folder', () async {
    expect(
      await paths.resolve('videos/x.mp4'),
      p.join(documents.path, 'videos', 'x.mp4'),
    );
  });

  test('an existing absolute path stays unchanged', () async {
    final video = createVideo('x.mp4');
    expect(await paths.resolve(video.path), video.path);
  });

  test(
    'a missing legacy absolute path is found in the videos folder',
    () async {
      final video = createVideo('study_1_2.mp4');
      expect(
        await paths.resolve('/old/container/Documents/videos/study_1_2.mp4'),
        video.path,
      );
    },
  );

  test('a missing legacy absolute path without a copy in the videos folder '
      'stays unchanged', () async {
    const legacy = '/old/container/Documents/videos/gone.mp4';
    expect(await paths.resolve(legacy), legacy);
  });

  group('without asking for the documents folder', () {
    final pathsWithoutDocuments = VideoPaths(
      documentsDirectory: () => throw StateError('documents folder queried'),
    );

    test('a non-file path stays unchanged', () async {
      expect(
        await pathsWithoutDocuments.resolve('fake:video.mp4'),
        'fake:video.mp4',
      );
    });

    test(
      'a missing absolute path outside a videos folder stays unchanged',
      () async {
        expect(
          await pathsWithoutDocuments.resolve('/elsewhere/clip.mp4'),
          '/elsewhere/clip.mp4',
        );
      },
    );
  });
}
