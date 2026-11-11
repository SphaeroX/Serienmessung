import 'package:share_plus/share_plus.dart';

/// Hands a file to the system share sheet (save, mail, messenger, …).
abstract class FileSharer {
  Future<void> share(String path, {required String mimeType, String? subject});
}

class SystemFileSharer implements FileSharer {
  @override
  Future<void> share(
    String path, {
    required String mimeType,
    String? subject,
  }) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(path, mimeType: mimeType)],
        subject: subject,
      ),
    );
  }
}
