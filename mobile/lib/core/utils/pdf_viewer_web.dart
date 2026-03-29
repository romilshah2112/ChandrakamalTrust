// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

class PdfViewerWidget extends StatefulWidget {
  const PdfViewerWidget({
    super.key,
    required this.url,
    required this.viewId,
    this.fallback,
  });

  final String url;
  final String viewId;
  // ignored on web — the iframe is always shown
  // ignore: unused_field
  final Widget? fallback;

  @override
  State<PdfViewerWidget> createState() => _PdfViewerWidgetState();
}

class _PdfViewerWidgetState extends State<PdfViewerWidget> {
  @override
  void initState() {
    super.initState();
    // Register the factory once per unique viewId. Silently ignore the
    // "already registered" error that can occur on hot reload.
    try {
      ui_web.platformViewRegistry.registerViewFactory(widget.viewId, (int id) {
        return html.IFrameElement()
          ..src = widget.url
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.border = 'none';
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: widget.viewId);
  }
}
