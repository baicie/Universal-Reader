import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/foliate_bridge.dart';
import '../../../core/reader_runtime.dart';
import 'renderer_binding.dart';

class IsolatedFoliateView extends StatefulWidget {
  const IsolatedFoliateView({
    required this.document,
    required this.fallback,
    super.key,
  });

  final HtmlChapteredDocument document;
  final Widget fallback;

  @override
  State<IsolatedFoliateView> createState() => _IsolatedFoliateViewState();
}

class _IsolatedFoliateViewState extends State<IsolatedFoliateView> {
  WebViewController? _controller;

  @override
  void initState() {
    super.initState();
    if (!useNativeVisualRenderer()) return;
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadFlutterAsset(FoliateBridge.hostAsset);
    _controller = controller;
    WidgetsBinding.instance.addPostFrameCallback((_) => _pushChapter());
  }

  @override
  void didUpdateWidget(IsolatedFoliateView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.document.currentChapterHref !=
            widget.document.currentChapterHref ||
        oldWidget.document.currentChapterHtml !=
            widget.document.currentChapterHtml) {
      _pushChapter();
    }
  }

  Future<void> _pushChapter() async {
    final controller = _controller;
    if (controller == null) return;
    final command = jsonEncode(FoliateBridge.openCurrent(widget.document));
    await controller.runJavaScript(
      'window.FoliateView && window.FoliateView.openChapter($command)',
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) return widget.fallback;
    return WebViewWidget(controller: controller);
  }
}
