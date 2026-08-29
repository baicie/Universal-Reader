import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/foliate_bridge.dart';
import '../../../core/foliate_session.dart';
import '../../../core/reader_runtime.dart';
import '../../../core/reading_surface.dart';
import 'renderer_binding.dart';

class IsolatedFoliateView extends StatefulWidget {
  const IsolatedFoliateView({
    required this.document,
    required this.fallback,
    this.session,
    this.surface = ReadingSurface.light,
    this.onSelection,
    this.onHostEvent,
    this.onNext,
    this.onPrevious,
    super.key,
  });

  final HtmlChapteredDocument document;
  final Widget fallback;
  final FoliateSession? session;
  final ReadingSurface surface;
  final ValueChanged<FoliateSelection>? onSelection;
  final ValueChanged<Map<String, Object?>>? onHostEvent;
  final VoidCallback? onNext;
  final VoidCallback? onPrevious;

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
    if (chapterChanged || pageChanged || oldWidget.surface != widget.surface) {
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
    final typography = widget.surface.toFoliateCommand();
    final command = jsonEncode(
      widget.session != null
          ? FoliateBridge.openSession(
              widget.session!,
              fontSize: widget.surface.fontSize,
              typography: typography,
            )
          : FoliateBridge.openCurrent(
              widget.document,
              fontSize: widget.surface.fontSize,
              typography: typography,
            ),
    );
    await controller.runJavaScript(
      'window.FoliateView && window.FoliateView.open($command)',
    );
  }

  Widget _page() {
    final controller = _controller;
    if (controller == null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 32, 28, 48),
        child: widget.fallback,
      );
    }
    return WebViewWidget(controller: controller);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final strip = constraints.maxWidth / 3;
        return SizedBox.expand(
          child: Stack(
            key: const Key('foliate-surface'),
            fit: StackFit.expand,
            children: [
              Positioned.fill(child: _page()),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: strip,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onPrevious,
                ),
              ),
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: strip,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onNext,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
