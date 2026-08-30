# Spec: 已完成

> NCX 嵌套已支持。外部链接保留已完成。**应用内打开外链已完成**。**CSS @import media query 保留已完成**。下一刀：Ask first：`view.js` / `overlayer.js` / 去掉 `<iframe>`。

## CSS @import media query 保留（最新完成）

章节 CSS 中的 `@import` 语句现在正确处理 media query：无 media query 的会展开内联，带 media query 的会保留。

成功标准：

- ✅ `@import url("theme.css");` 会被展开内联。
- ✅ `@import url("print.css") print;` 会被保留（不展开）。
- ✅ `@import url('screen.css') screen;` 会被保留（不展开）。
- ✅ 外部或 data URI 的 `@import` 保持不变。

实现结果：

- 修改 `epub_document.dart` 中的 CSS 处理逻辑，添加 `_cssImportNoMedia` 正则表达式。
- `_inlineCssImports` 函数现在只展开无 media query 的 `@import`。
- 添加测试用例验证带 media query 的 `@import` 被正确保留。
- 所有 438 个测试通过，静态分析无问题。

## 应用内打开外链（之前完成）

EPUB 和 FB2 文档中的外部链接（`http://`、`https://`、`mailto:` 等）现在可以在系统浏览器中打开。

成功标准：

- ✅ 点击外部链接时使用 `url_launcher` 在系统默认浏览器中打开。
- ✅ 使用 `LaunchMode.externalApplication` 确保在外部应用打开，不在应用内嵌 WebView。
- ✅ 无效 URL 或启动失败时静默忽略，不影响阅读体验。
- ✅ 内部链接（`#id` 和相对路径）保持原有行为。
- 所有 33 个 widget 测试通过，静态分析无问题。

## FB2 外部链接保留（之前完成）

FB2 文档中的外部链接（`http://`、`https://`、`mailto:` 等）现在保留为可点击的 `<a>` 标签，标记 `class="external-link"`，为后续实现"应用内打开"功能打下基础。

成功标准：

- ✅ `<a l:href="https://example.com">text</a>` 生成 `<a href="https://example.com" class="external-link">text</a>`。
- ✅ `<a l:href="mailto:test@example.com">email</a>` 生成 `<a href="mailto:test@example.com" class="external-link">email</a>`。
- ✅ `<a l:href="http://site.org/page">link</a>` 生成 `<a href="http://site.org/page" class="external-link">link</a>`。
- ✅ 内部 `#id` 链接保持原有行为，不添加 `external-link` class。
- ✅ 空链接和空内容正确处理。

实现结果：

- 修改 `fb2_document.dart` 中 `_fb2Inline` 的 `case 'a'` 处理逻辑，识别外部链接并保留。
- 新增 `_isFb2ExternalHref` 辅助函数，识别 `http://`、`https://`、`mailto:` 和 `//` 开头的链接。
- 更新旧测试"chapter html drops an external link href"为"chapter html keeps external links as clickable a tags"。
- 添加新测试用例 `fb2WithExternalLinksBytes()` 和完整测试，验证各种外部链接场景。
- 更新 CHANGELOG.md、README.md 和 epub-reader.md 文档。
- 所有 437 个测试通过，静态分析无问题。

## NCX 嵌套（之前完成）

EPUB2 的 NCX 目录现在支持嵌套 navPoint，与 EPUB3 nav 行为一致。

成功标准：

- ✅ NCX navMap 里嵌套的 navPoint 解析为 TocItem children。
- ✅ 子 navPoint 的 fragment 正确提取（如 `ch1.xhtml#section1` 提取为 `section1`）。
- ✅ 嵌套层级递归解析，支持任意深度。
- ✅ NCX 损坏时退回 spine 平铺，不让整本书打不开。

实现结果：

- 在 `_navTocItems` 函数中添加 NCX 解析逻辑，优先使用 EPUB3 nav，回退到 NCX。
- 新增 `_ncxNavPoints` 递归函数，解析嵌套的 navPoint 并生成 TocItem 树。
- 添加完整测试用例 `nestedNcxEpubBytes()` 和测试，验证两层嵌套结构。
- 所有 436 个测试通过，静态分析无问题。

## 引文副题 id（之前完成）

节 / 诗级 / 诗节副题的 `id` 已经抄到 `<h2>` / `<h4>` / `<h5>`。引文块（`<epigraph>` / `<cite>`）里 `<subtitle id="…">` 已完成实现，编成的 `<h2>` 带有 id。

成功标准：

- ✅ `<epigraph><subtitle id="spot">softly</subtitle>…` 的章 HTML 含 `<h2 id="spot">`。
- ✅ `<cite><subtitle id="ref">note</subtitle>…` 的章 HTML 含 `<h2 id="ref">`。
- ✅ 空 id 不抄。空引文副题仍不编。
- ✅ stylesheet 里的 CSS 仍不进章 HTML。

实现结果：

已在 `_fb2QuoteHtml` 函数的 `subtitle` 处理中添加 `idAttr`，与 style 一起输出到 `<h2>` 标签。所有测试通过（203 个 FB2 测试），静态分析无问题。
