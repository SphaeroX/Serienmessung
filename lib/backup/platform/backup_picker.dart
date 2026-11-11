import 'dart:convert';

import 'package:file_picker/file_picker.dart';

/// Lets the user choose a backup file and returns its text.
abstract class BackupPicker {
  /// Null if the user cancelled.
  Future<String?> pickBackup();
}

class FileBackupPicker implements BackupPicker {
  @override
  Future<String?> pickBackup() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (files.isEmpty) return null;
    return utf8.decode(await files.first.readAsBytes(), allowMalformed: true);
  }
}
