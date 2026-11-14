import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

/// Hands a file to the system share sheet (save, mail, messenger, …).
abstract class FileSharer {
  Future<void> share(String path, {required String mimeType});
}

/// Share parameters for the file at [path]. The subject is the file name
/// with its extension: Google Drive names the saved file after the subject,
/// so a subject without extension yields files Windows and Excel cannot open.
ShareParams shareParamsFor(String path, {required String mimeType}) {
  final name = p.basename(path);
  return ShareParams(
    files: [XFile(path, mimeType: mimeType)],
    fileNameOverrides: [name],
    subject: name,
  );
}

class SystemFileSharer implements FileSharer {
  @override
  Future<void> share(String path, {required String mimeType}) async {
    await SharePlus.instance.share(shareParamsFor(path, mimeType: mimeType));
  }
}
