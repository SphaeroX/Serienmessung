import 'package:cyclescope/video/platform/video_files.dart';

/// Records the video files the app deleted.
class FakeVideoFiles implements VideoFiles {
  final deleted = <String>[];

  @override
  Future<void> delete(String path) async => deleted.add(path);
}
