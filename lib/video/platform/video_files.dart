import 'dart:io';

/// The copied video files of the video studies in app storage.
abstract class VideoFiles {
  /// Deletes the file at [path]; a missing file is not an error.
  Future<void> delete(String path);
}

/// Files in the app's documents folder (see `FileVideoPicker`).
class LocalVideoFiles implements VideoFiles {
  const LocalVideoFiles();

  @override
  Future<void> delete(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // Still in use or already gone: the file just stays.
    }
  }
}
