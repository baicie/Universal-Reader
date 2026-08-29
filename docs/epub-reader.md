# Spec: EPUB 阅读

## Objective

导入 `.epub` 后打开，看到书里的章节正文和目录，而不是「尚未接入」。进度仍写回书库。

成功标准：

- 最小 EPUB（container + OPF + 两章 XHTML + nav）打开后正文来自文件。
- 目录可跳到对应 `EpubLocator.href`。
- 损坏 ZIP/缺 OPF 提示文件损坏，不回退样章。
- 种子书（无字节）仍可用样章。
- 长章按页阅读：点右缘或按右方向键下一页，章末进下一章；书末再点不换书。进度条落到当前页。测试环境显示当前页文本。
- 章内图片内联为 `data:`，章 CSS 内联进 HTML。WebView host 用本地 `paginator.js` 排版；测试不加载 WebView。缺失图片保持缺失。

## Assumptions

1. 文本 Adapter 仍解 spine；视觉层走隔离的 Foliate 桥（测试环境回退到章节文本）。打开命令带当前章 HTML、字号、行距、字体和纸色。
2. 单书抽取上限 2 MiB 文本；超长章按现有文本阅读块大小切开。
3. MOBI / AZW3 / FB2 见 `docs/reader-engines.md`。
4. host 只 vendor `paginator.js`。Dart 字符分页仍负责测试里的翻页和进度。

## Commands

```powershell
cd app
flutter test test/epub_document_test.dart test/text_document_test.dart test/widget_test.dart
```

## Boundaries

- Always: 通过 `ReaderDocument` 取 TOC / 文本 / 搜索。损坏如实披露。
- Ask first: 其余 foliate-js 模块（`view.js` / `epub.js` / overlayer）、用视口页数替换 Dart 字符分页。
- Never: 把损坏 EPUB 显示成另一本种子书；从 CDN 加载阅读引擎。
