import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Lets the user pick a video and copies it into app storage.
abstract class VideoPicker {
  /// Returns the local path of the copied video, or null if cancelled.
  Future<String?> pickAndCopy({required int studyId});
}

/// Copies the picked file into `<documents>/videos/` so the study keeps
/// working even if the original is moved or deleted.
class FileVideoPicker implements VideoPicker {
  @override
  Future<String?> pickAndCopy({required int studyId}) async {
    final files = await FilePicker.pickFiles(type: FileType.video);
    if (files.isEmpty) return null;
    final file = files.first;
    final dir = Directory(
      p.join((await getApplicationDocumentsDirectory()).path, 'videos'),
    );
    await dir.create(recursive: true);
    final ext = file.extension == null ? '' : '.${file.extension}';
    final target = File(
      p.join(
        dir.path,
        'study_${studyId}_${DateTime.now().millisecondsSinceEpoch}$ext',
      ),
    );
    final sink = target.openWrite();
    await sink.addStream(file.readAsByteStream());
    await sink.close();
    return target.path;
  }
}
