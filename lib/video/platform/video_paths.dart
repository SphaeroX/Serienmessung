import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Locates the imported videos. A study stores its video relative to the
/// documents folder (`videos/<file name>`) because the absolute path of the
/// app container changes with every app update on iOS.
class VideoPaths {
  const VideoPaths({
    this.documentsDirectory = getApplicationDocumentsDirectory,
  });

  final Future<Directory> Function() documentsDirectory;

  static const _folder = 'videos';

  Future<Directory> videosDirectory() async =>
      Directory(p.join((await documentsDirectory()).path, _folder));

  String stored(String fileName) => '$_folder/$fileName';

  /// The file behind [storedPath]. Absolute paths saved before videos were
  /// stored relative (or restored from such a backup) point into the videos
  /// folder of an old app container; a missing one falls back to the same
  /// file name in the current videos folder.
  Future<String> resolve(String storedPath) async {
    if (storedPath.startsWith('$_folder/')) {
      return p.join((await documentsDirectory()).path, storedPath);
    }
    if (!p.isAbsolute(storedPath) ||
        p.basename(p.dirname(storedPath)) != _folder ||
        await File(storedPath).exists()) {
      return storedPath;
    }
    final moved = File(
      p.join((await videosDirectory()).path, p.basename(storedPath)),
    );
    return await moved.exists() ? moved.path : storedPath;
  }
}
