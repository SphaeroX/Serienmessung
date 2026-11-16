import 'dart:io';

import 'video_paths.dart';

/// The copied video files of the video studies in app storage.
abstract class VideoFiles {
  /// Deletes the file at [path]; a missing file is not an error.
  Future<void> delete(String path);
}

/// Files in the app's documents folder (see `FileVideoPicker`).
class LocalVideoFiles implements VideoFiles {
  const LocalVideoFiles({this.paths = const VideoPaths()});

  final VideoPaths paths;

  @override
  Future<void> delete(String path) async {
    final String resolved;
    try {
      resolved = await paths.resolve(path);
    } on Exception {
      // Without a resolvable location there is no file to delete.
      return;
    }
    try {
      final file = File(resolved);
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // Still in use or already gone: the file just stays.
    }
  }
}
