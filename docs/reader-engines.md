# Spec: 阅读引擎与正文笔记

## Objective

把上一轮的章节/页文本阅读升成隔离后的 Renderer：

- EPUB / MOBI / AZW3 / FB2 走可测的 Foliate 会话（分页、CFI、选区），WebView host 用本地 `paginator.js` 排当前章 HTML 并上报视口页；字号、行距、字体和纸色由打开命令带入。点右缘或方向键翻页，进度条落到当前页，章末进下一章，书末停住。底栏显示章内页码；点按翻页把独立页码推到 host。章内图片（含 `srcset`、SVG `<image>`、`<object data>`、`<embed src>` 与 `<video poster>`）和嵌入字体内联为 data URI；FB2 节内 `<image l:href="#id">` 按对应 `binary` 内联，缺 binary 不补；FB2 段落里的 `<emphasis>` / `<strong>` / `<strikethrough>` / `<sub>` / `<sup>` / `<code>` 写成 `<em>` / `<strong>` / `<s>` / `<sub>` / `<sup>` / `<code>`；有 name 的 `<style>` 写成带 class 的 `<span>`，空或无名 style 只留字，FictionBook stylesheet 不进章 HTML；`<p style>` 的 name 抄到 `class`，空 style 不抄；诗行 `<v style>` 写成带 class 的 span，空诗行不编；FB2 `<a l:href="#id">` 写成 `<a href="#id">`，节 / 段落 / 空锚点 `id` 抄到章 HTML，对得上的跨节注释写成 `section-N#id`（节 / 段落 / 空锚点 id），外链只留字；FB2 `<empty-line/>` 写成空白段，`<subtitle>` 写成 `<h2>` 并可检索，节内 `<subtitle style>` 抄到 class，空副题不编；节 `<title style>` 抄到章首 `<h1>` class，空节标题不编；FB2 `<poem>` 的诗行带换行进章 HTML 并可检索，纯诗节不丢；诗级 `<title>` 写成 `<h3>`，`<title style>` 抄到 class，空诗题不编；诗内直接子级的 `<epigraph>` / `<cite>` 同样进诗，诗级 `<subtitle>` 写成 `<h4>`，`<subtitle style>` 抄到 class，空副题不编，诗级 `<text-author>`（style 抄到 class）与 `<date>`（style 抄到 class）进该诗（空 date 用 `value`）；stanza 有字的 `<title>` / `<subtitle>` 写成 `<h4>` / `<h5>`，`<title style>` / `<subtitle style>` 抄到 class，空标题与空副题不编；FB2 节内 `<table>` 写成 HTML 表并可检索，有字的 `<title>` 写成 `<caption>`，正整数 `colspan` / `rowspan` 抄到格子上，允许的 `align` / `valign` 同样抄上，格子 `style` 抄到 class，空表不编格，纯表节不丢；FB2 `<epigraph>` / `<cite>` 写成 `<blockquote>`（段落、副题 style 抄到 class、空行、text-author（style 抄到 class）、诗、表与题词内嵌套 cite）并可检索；FB2 节内 `<annotation>` 的段落、副题 style 抄到 class、空行、`<cite>`、`<poem>` 与 `<table>` 写成 `<aside>` 并可检索，空 annotation 不编，纯 annotation 节不丢。书级 `title-info` annotation 编成目录第一章（href 为 `annotation`，不占用 `section-0`），空提要不增章。FB2 有标题的父节在目录下挂子节；无标题包装节不进目录。`body name="notes"` / `comments` 的节仍用原来的 `section-N` href，作为独立目录组挂在正文后面；空 notes body 不增组。无 `<section>` 的 notes/comments body 在已有正文时同样进该组；只有 notes、没有正文节仍为损坏。无 `<section>` 的正文 body 把直接子级块编成一章（href 仍为 `section-N`）；已有 section 的 body 不把 body 级段落再编一章；空 body 或只有 notes 且无节仍为损坏。正文 body 里第一个 section 之前的 `<epigraph>` / `<cite>` / `<image>` / `<empty-line/>` / `<subtitle>` / `<poem>` / `<table>` / `<annotation>` / `<title>` / `<p>` 接到该 body 第一章开头；body 级 `<subtitle style>` 抄到 class；body 级 `<title style>` 抄到 class；空题词、空副题、空诗、空表、空 annotation、空 title、空段落不编；缺 binary 的图保持缺失；notes/comments 的 body 级题词、图、诗、表、title 和段落不并进正文第一章；第一节章标题仍来自该 section。有 section 的 body 不把这些段落另编成一章。目录当前项跟当前章 href（及 EPUB fragment）对齐；顶层 TOC 项数少于章数时底栏用章序号。章 CSS 的无 media `@import` 会展开；章 HTML 去掉 `<script>` 和 `on*` 事件属性；缺资源不补。章内链接相对当前章跳转，外链不打开；`#id` 滚到锚点，缺锚点停在当前页。EPUB3 nav 嵌套小节出现在所属章下并滚到 fragment；spine 外的顶层项不进目录。书内搜索命中滚到查询词，点笔记滚到该条 quote，缺句停在章首。没有 WebView 时仍按字符页。笔记 quote 标在 host 章文档里，测试 fallback 仍画在文本上。
- PDF 走视觉页（pdfrx，测得过的环境；测试里用隔离 backend）。阅读设置可把当前页放到 100%–300%。页面铺满阅读面，不进重排栏。
- CBZ（以及可当 ZIP 打开的 CBR）走漫画页：单页、双页、竖滑，可选从右到左。末页单独成页，不拿另一本书的图补空。
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
- Ask first: DRM、Linux 完整 WebView、其余 foliate-js 模块。
- Never: 业务代码直接依赖 foliate / pdfrx API。
