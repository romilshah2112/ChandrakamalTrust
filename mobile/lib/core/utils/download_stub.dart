import 'dart:typed_data';

/// On non-web platforms share_plus handles file sharing/saving directly,
/// so this is intentionally a no-op (never called from DocumentViewerPage).
Future<void> triggerDownload(Uint8List bytes, String fileName) async {}
