# Spec: EPUB 阅读

## Objective

导入 `.epub` 后打开，看到书里的章节正文和目录，而不是「尚未接入」。进度仍写回书库。

成功标准：

- 最小 EPUB（container + OPF + 两章 XHTML + nav）打开后正文来自文件。
- 目录可跳到对应 `EpubLocator.href`。EPUB3 `nav` 嵌套小节带 `fragment`；顶层仍是 spine 章，幽灵章不进目录。点小节滚到 `#id`，缺锚点停在当前页。当前项跟当前章 href 和 fragment 对齐；同一章无 fragment 时只亮父项。
- 损坏 ZIP/缺 OPF 提示文件损坏，不回退样章。
- 种子书（无字节）仍可用样章。
- 长章按页阅读：点右缘或按右方向键下一页，章末进下一章；书末再点不换书。进度条落到当前页。测试环境显示当前页文本。底栏显示章内页码；点按翻页把页码推到 host，不靠就地修改的 session 对象侦测变化。
- 章内图片内联为 `data:`，`srcset`（含 `<picture><source>`）、SVG `<image href>` / `xlink:href`、`<object data>`、`<embed src>` 和 `<video poster>` 同样内联；缺图或 `https` srcset/href/data 保持原样。章 CSS 内联进 HTML。嵌入字体的 `@font-face` `url()` 也变成 `data:`。无 media 的 `@import` 换成该文件内容后再内联 `url()`；缺文件、外链、带 media 的 `@import` 保持原样。章 HTML 去掉 `<script>` 和 `onclick` / `onerror` 等事件属性，不执行、不内联书里的 JS。WebView host 用本地 `paginator.js` 排版；测试不加载 WebView。缺失图片或字体保持缺失。
- 真机翻页和进度跟 host 上报的视口页；没有 WebView 时仍按字符页。
- 当前书的笔记 quote 随打开命令交给 host 标在章 HTML 里。找不到的 quote 不画。书签不画成高亮。
- 章内 `<a href>` 由 host 截获后走当前书的 `goTo`。相对路径相对当前章解析；`https` / `mailto` 等外链不跳转；缺章停在当前章。`#id` 滚到该元素所在页；找不到锚点就停在当前页。
- 书内搜索点命中后滚到查询词所在页。找不到该句停在章首。
- 点笔记滚到该条 quote。空 quote 只跳 locator；缺 locator 不跳。

## Assumptions

1. 文本 Adapter 仍解 spine；视觉层走隔离的 Foliate 桥（测试环境回退到章节文本）。打开命令带当前章 HTML、字号、行距、字体和纸色。
2. 单书抽取上限 2 MiB 文本；超长章按现有文本阅读块大小切开。
3. MOBI / AZW3 / FB2 见 `docs/reader-engines.md`。
4. host 只 vendor `paginator.js`。没有 WebView 时 Dart 字符分页仍负责测试里的翻页；真机以 host 的 `relocated` 页数为准。

## Commands

```powershell
cd app
flutter test test/epub_document_test.dart test/reflow_nav_test.dart test/foliate_bridge_test.dart test/widget_test.dart
```

## Boundaries

- Always: 通过 `ReaderDocument` 取 TOC / 文本 / 搜索。损坏如实披露。
- Ask first: 其余 foliate-js 模块（`view.js` / `epub.js` / overlayer.js）。
- Never: 把损坏 EPUB 显示成另一本种子书；从 CDN 加载阅读引擎。
