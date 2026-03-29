import 'package:flutter/material.dart';

class PdfViewerWidget extends StatelessWidget {
  const PdfViewerWidget({
    super.key,
    required this.url,
    required this.viewId,
    this.fallback,
  });

  final String url;
  final String viewId;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    return fallback ??
        const Center(
          child: Text('PDF preview is not supported on this platform.'),
        );
  }
}
