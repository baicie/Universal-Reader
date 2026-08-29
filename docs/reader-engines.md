# Spec: 阅读引擎与正文笔记

## Objective

把上一轮的章节/页文本阅读升成隔离后的 Renderer：

- EPUB / MOBI / AZW3 / FB2 走 Foliate 桥（WebView host）
- PDF 走视觉页（pdfrx，测得过的环境；测试里用隔离 backend）
- CBZ（以及可当 ZIP 打开的 CBR）走漫画页
- 笔记的 quote 画进当前章节正文

## Assumptions

1. UI **不**直接调用 `FoliateView` / `PdfViewer`。只认 `DocumentRenderer` / `WebRendererBackend`。
2. Widget 测试不依赖真实 WebView / PDFium；用 Fake backend。正文文本层仍保留，方便检索和笔记。
3. MOBI/AZW3：能当 ZIP/KF8 的按 EPUB 打开；否则抽取可读文本。不是完整 Kindle DRM 引擎。
4. CBR 若不是 ZIP，视为损坏，不回退样章。
5. 仍不引入 `flutter_rust_bridge`。

## Commands

```powershell
cd app
flutter test test/comic_document_test.dart test/fb2_document_test.dart test/mobi_document_test.dart test/foliate_bridge_test.dart test/annotated_text_test.dart test/widget_test.dart
```

## Boundaries

- Always: 损坏如实披露；Renderer 失败时回到已解析的章节/页文本，不换另一本书。
- Ask first: DRM、Linux 完整 WebView。
- Never: 业务代码直接依赖 foliate / pdfrx API。
