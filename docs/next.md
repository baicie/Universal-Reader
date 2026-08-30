# Spec: 已完成

> NCX 嵌套已支持。下一刀：Ask first：`view.js` / 应用内打开外链 / `overlayer.js` / 去掉 `<iframe>`。

## NCX 嵌套（最新完成）

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
