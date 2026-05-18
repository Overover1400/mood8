import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

class ExportDownloaderImpl {
  Future<bool> downloadBytes({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
  }) async {
    try {
      final result = await Share.shareXFiles(
        [
          XFile.fromData(bytes, name: filename, mimeType: mimeType),
        ],
        subject: 'Mood8 data export',
      );
      return result.status == ShareResultStatus.success ||
          result.status == ShareResultStatus.dismissed;
    } catch (e) {
      debugPrint('ExportDownloader.shareXFiles failed: $e');
      return false;
    }
  }
}

ExportDownloaderImpl createExportDownloaderImpl() => ExportDownloaderImpl();
