import 'dart:typed_data';

import 'export_downloader_stub.dart'
    if (dart.library.html) 'export_downloader_web.dart';

/// Cross-platform download helper. On web a Blob + anchor click triggers a
/// browser download. On native a share sheet is presented via share_plus.
class ExportDownloader {
  ExportDownloader._() : _impl = createExportDownloaderImpl();
  static final ExportDownloader _instance = ExportDownloader._();
  factory ExportDownloader() => _instance;

  final ExportDownloaderImpl _impl;

  Future<bool> downloadBytes({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
  }) =>
      _impl.downloadBytes(
        bytes: bytes,
        filename: filename,
        mimeType: mimeType,
      );
}
