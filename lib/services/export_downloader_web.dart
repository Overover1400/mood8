// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

import 'package:flutter/foundation.dart';

class ExportDownloaderImpl {
  Future<bool> downloadBytes({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
  }) async {
    try {
      final blob = html.Blob(<dynamic>[bytes], mimeType);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', filename)
        ..style.display = 'none';
      html.document.body?.append(anchor);
      anchor.click();
      anchor.remove();
      // Defer revoke so the browser has time to start the download.
      Future<void>.delayed(const Duration(seconds: 4), () {
        try {
          html.Url.revokeObjectUrl(url);
        } catch (_) {}
      });
      return true;
    } catch (e) {
      debugPrint('ExportDownloader.web download failed: $e');
      return false;
    }
  }
}

ExportDownloaderImpl createExportDownloaderImpl() => ExportDownloaderImpl();
