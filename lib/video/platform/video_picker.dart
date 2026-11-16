import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

import 'video_paths.dart';

/// Lets the user pick a video and copies it into app storage.
abstract class VideoPicker {
  /// Returns the stored path of the copied video (see VideoPaths), or null if
  /// cancelled.
  Future<String?> pickAndCopy({required int studyId});
}

/// Copies the picked file into `<documents>/videos/` so the study keeps
/// working even if the original is moved or deleted.
class FileVideoPicker implements VideoPicker {
  const FileVideoPicker(this.paths);

  final VideoPaths paths;

  @override
  Future<String?> pickAndCopy({required int studyId}) async {
    final files = await FilePicker.pickFiles(type: FileType.video);
    if (files.isEmpty) return null;
    final file = files.first;
    final dir = await paths.videosDirectory();
    await dir.create(recursive: true);
    final ext = file.extension == null ? '' : '.${file.extension}';
    final fileName =
        'study_${studyId}_${DateTime.now().millisecondsSinceEpoch}$ext';
    final sink = File(p.join(dir.path, fileName)).openWrite();
    await sink.addStream(file.readAsByteStream());
    await sink.close();
    return paths.stored(fileName);
  }
}
