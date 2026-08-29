# Spec: PDF 阅读

## Objective

导入可抽取文本的 PDF 后打开，按页阅读，目录为页列表，进度写回书库。打开后可以放大当前页。

成功标准：

- 测试用单页/多页 PDF 打开后正文是页内文本。
- `PdfLocator.page` 从 1 起算；目录跳转换页。
- 阅读设置把缩放调到 150% 后，当前页按 1.5 倍显示。测试环境没有 pdfrx 视觉层时，缩放仍作用在页文本上。
- 页面铺满阅读面，不挤在重排正文的 680 栏里。
- 不是 PDF 或无法抽出任何文本：损坏提示，不回退样章。
- 无法抽出任何文本且视觉 backend 也打不开：损坏提示，不回退样章。

## Assumptions

1. 视觉页走隔离的 pdfrx backend；测试环境回退到页文本。
2. 只保证未压缩内容流里的括号字符串能被测到；复杂压缩 PDF 可以失败并显示损坏。
3. 搜索在已抽出的页文本上做，不跑外部引擎。
4. 缩放是本机阅读偏好，不是书目字段。真机 pdfrx 与页文本 fallback 用同一缩放值。

## Commands

```powershell
cd app
flutter test test/pdf_document_test.dart test/reader_prefs_test.dart test/widget_test.dart
```

## Boundaries

- Always: PDF 走独立 Adapter，不进 WebView。损坏如实披露。
- Ask first: 批注墨迹、复杂压缩 PDF。
- Never: 把 PDF 先转成整本 HTML；用样章或另一本书填补缺失。
