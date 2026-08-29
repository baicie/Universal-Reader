import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/foliate_bridge.dart';
import '../../../core/foliate_session.dart';
import '../../../core/reader_runtime.dart';
import 'renderer_binding.dart';

class IsolatedFoliateView extends StatefulWidget {
  const IsolatedFoliateView({
    required this.document,
    required this.fallback,
    this.session,
    this.fontSize = 18,
    this.onSelection,
    this.onHostEvent,
    super.key,
  });

  final HtmlChapteredDocument document;
  final Widget fallback;
  final FoliateSession? session;
  final double fontSize;
  final ValueChanged<FoliateSelection>? onSelection;
  final ValueChanged<Map<String, Object?>>? onHostEvent;

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
      ..addJavaScriptChannel('FoliateHost', onMessageReceived: _onHostMessage)
      ..loadFlutterAsset(FoliateBridge.hostAsset);
    _controller = controller;
    WidgetsBinding.instance.addPostFrameCallback((_) => _pushSession());
  }

  @override
  void didUpdateWidget(IsolatedFoliateView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final chapterChanged =
        oldWidget.document.currentChapterHref !=
            widget.document.currentChapterHref ||
        oldWidget.document.currentChapterHtml !=
            widget.document.currentChapterHtml;
    final pageChanged =
        oldWidget.session?.pageIndex != widget.session?.pageIndex ||
        oldWidget.session?.currentCfi != widget.session?.currentCfi;
    final fontChanged = oldWidget.fontSize != widget.fontSize;
    if (chapterChanged || pageChanged || fontChanged) {
      _pushSession();
    }
  }

  void _onHostMessage(JavaScriptMessage message) {
    final decoded = jsonDecode(message.message);
    if (decoded is! Map) return;
    final payload = <String, Object?>{
      for (final entry in decoded.entries) '${entry.key}': entry.value,
    };
    final session = widget.session;
    final selection = session?.selectionFromEvent(payload);
    if (selection != null) {
      widget.onSelection?.call(selection);
    }
    widget.onHostEvent?.call(payload);
  }

  Future<void> _pushSession() async {
    final controller = _controller;
    if (controller == null) return;
    final command = jsonEncode(
      widget.session != null
          ? FoliateBridge.openSession(
              widget.session!,
              fontSize: widget.fontSize,
            )
          : FoliateBridge.openCurrent(
              widget.document,
              fontSize: widget.fontSize,
            ),
    );
    await controller.runJavaScript(
      'window.FoliateView && window.FoliateView.open($command)',
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) return widget.fallback;
    return WebViewWidget(controller: controller);
  }
}
