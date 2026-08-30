# Spec: 已完成

> 引文副题的 id 已抄到 h2。下一刀：Ask first：`view.js` / NCX 嵌套 / 应用内打开外链 / `overlayer.js` / 去掉 `<iframe>`。

## Objective

节 / 诗级 / 诗节副题的 `id` 已经抄到 `<h2>` / `<h4>` / `<h5>`。引文块（`<epigraph>` / `<cite>`）里 `<subtitle id="…">` 已完成实现，编成的 `<h2>` 带有 id。

成功标准：

- ✅ `<epigraph><subtitle id="spot">softly</subtitle>…` 的章 HTML 含 `<h2 id="spot">`。
- ✅ `<cite><subtitle id="ref">note</subtitle>…` 的章 HTML 含 `<h2 id="ref">`。
- ✅ 空 id 不抄。空引文副题仍不编。
- ✅ stylesheet 里的 CSS 仍不进章 HTML。

## 实现结果

已在 `_fb2QuoteHtml` 函数的 `subtitle` 处理中添加 `idAttr`，与 style 一起输出到 `<h2>` 标签。所有测试通过（203 个 FB2 测试），静态分析无问题。
