import 'package:cyclescope/export/platform/file_sharer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shareParamsFor', () {
    // Google Drive ("Save to Drive") names the uploaded file after the
    // share subject. A subject without the file extension (e.g. the study
    // name "Demo: Gehäuselinie") produced files without ".xlsx"/".csv" that
    // Windows and Excel could not open.
    test('uses the file name with extension as subject', () {
      final params = shareParamsFor(
        '/data/exports/Demo_Gehäuselinie_2026-11-14.xlsx',
        mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );

      expect(params.subject, 'Demo_Gehäuselinie_2026-11-14.xlsx');
    });

    test('shares the file with its mime type and name', () {
      final params = shareParamsFor(
        '/data/exports/Line_200_2026-11-14.csv',
        mimeType: 'text/csv',
      );

      final file = params.files!.single;
      expect(file.path, '/data/exports/Line_200_2026-11-14.csv');
      expect(file.mimeType, 'text/csv');
      expect(params.fileNameOverrides, ['Line_200_2026-11-14.csv']);
    });
  });
}
