import '../../study/data/study_repository.dart';
import '../platform/video_files.dart';

/// Deletes the video file at [path] unless a study still uses it (copies
/// of a study share the file). Call after the study was deleted or got
/// another video.
Future<void> deleteUnusedVideo(
  StudyRepository studies,
  VideoFiles files,
  String? path,
) async {
  if (path == null || await studies.isVideoUsed(path)) return;
  await files.delete(path);
}
