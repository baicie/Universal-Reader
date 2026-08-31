# Spec: 已完成

> NCX 嵌套已支持。外部链接保留已完成。**应用内打开外链已完成**。**CSS @import media query 保留已完成**。**渲染架构文档已完成**。**代码健康优化已完成（空 catch 文档化、重复代码提取）**。**测试增强已完成（边界测试覆盖）**。**性能优化已完成（避免昂贵的 HTML 比较）**。**文档完善已完成（host.html 详细注释、CFI 计算逻辑说明、文档索引）**。**MOBI 文档测试覆盖率提升至 100%**。下一刀：继续优化或功能开发。

## MOBI 测试覆盖提升（最新完成）

将 MOBI 文档测试覆盖率从 50% 提升至 100%（1 个提交）。

**改进内容：**
- ✅ 扩展 `mobi_document_test.dart`，从 3 个测试增加到 20 个测试
- ✅ 新增完整 API 测试组（章节导航、定位器、文本提取、搜索、目录）
- ✅ 新增边界测试（未知 href、空查询、单章进度、索引范围限制）
- ✅ 新增格式边界测试（ZIP 偏移查找、HTML 实体转义、可读文本过滤）
- ✅ 测试覆盖率：`mobi_document.dart` 从 42/84 行提升至 84/84 行

**覆盖的 API：**
- 章节导航（`chapterIndex`、`chapterCount`、`currentChapter*`）
- 定位器（`locatorForProgress`、`currentLocator`、`goTo`）
- 文本操作（`extractText`、`search`）
- 目录（`getToc`）
- 进度流（`progress`）
- 格式特性（`truncated`、索引限制）

**格式边界覆盖：**
- ZIP 签名偏移检测（嵌入式 EPUB）
- HTML 实体转义（`<`、`>`、`&`）
- 可读文本提取（过滤二进制垃圾）

**测试结果：**
- 所有 460 个测试通过（从 443 增加到 460）
- `mobi_document.dart` 覆盖率：**100%（84/84 行）**

**提交记录：**
```
待提交
```

## 文档索引（之前完成）

创建文档索引提升文档可发现性（1 个提交）。

**改进内容：**
- ✅ 创建 `docs/README.md` 作为技术文档入口（89 行）
- ✅ 按类别组织所有技术文档（架构与设计、功能模块、平台与工程）
- ✅ 添加开发者阅读指南（推荐阅读顺序）
- ✅ 提供常见任务索引（添加格式支持、优化性能、扩展书库等）
- ✅ 在 `renderer-architecture.md` 中链接 CFI 文档

**改进效果：**
- 新开发者可以快速找到相关文档
- 明确的文档层次和阅读路径
- 文档间交叉引用更清晰
- 提升项目文档的专业度和可维护性

**测试结果：**
- 所有 443 个测试通过

**提交记录：**
```
dc9f67d Add docs/README.md as documentation index and link CFI doc
```

## CFI 文档（之前完成）

完成 CFI 计算逻辑说明文档（1 个提交）。

**文档内容：**
- ✅ 创建 `docs/cfi-logic.md`（294 行）
- ✅ 说明 CFI 是什么以及在 EPUB 定位中的作用
- ✅ 记录 CFI 生成流程（paginator.js 中的计算）
- ✅ 说明 CFI 存储方式（FoliateSession 和数据库）
- ✅ 解释 CFI 恢复流程（打开已读书籍时）
- ✅ 对比 CFI 与其他定位方式（fragment、quote、pageIndex）
- ✅ 阐述为什么优先使用 pageIndex 而不是 CFI
- ✅ 提出未来扩展方向（精确位置同步、跨设备同步）
- ✅ 总结测试覆盖和建议

**设计决策澄清：**
- CFI 在当前实现中**生成并记录**，但**不用于跳转**
- 使用更简单的 `pageIndex` 实现进度恢复（精度足够且可靠）
- CFI 字段保留用于未来扩展（字符级精度、跨版本定位）

**改进效果：**
- 明确说明当前 CFI 的使用方式和设计理由
- 为未来扩展提供清晰的技术路径
- 完成 `docs/renderer-architecture.md` 中提出的"补充 CFI 计算逻辑说明"任务

**测试结果：**
- 所有 443 个测试通过

**提交记录：**
```
1d1409b Document CFI calculation logic and current usage
```

## 文档完善（之前完成）

完成渲染层核心文件文档化（1 个提交）。

**文档化内容：**
- ✅ 为 `host.html` 添加全面的内联注释（192 行新增注释）
- ✅ 说明状态管理和生命周期
- ✅ 记录 Flutter ↔ JS 桥接通信协议
- ✅ 解释 Paginator 初始化和降级策略
- ✅ 文档化主题应用和样式注入
- ✅ 详细说明引用高亮算法
- ✅ 记录片段和引用导航机制
- ✅ 解释页面导航和视口计算
- ✅ 文档化链接点击拦截处理
- ✅ 说明事件监听器和选区跟踪
- ✅ 记录预初始化命令队列机制

**改进效果：**
- 渲染逻辑可维护性大幅提升
- 新开发者可以快速理解 WebView 渲染层
- 完成 `docs/renderer-architecture.md` 中提出的"为 host.html 添加详细注释"任务

**测试结果：**
- 所有 443 个测试通过
- 注释添加不影响任何功能

**提交记录：**
```
9aaf544 Document host.html: add comprehensive inline comments
```

## 性能优化（之前完成）

完成渲染性能优化（1 个提交）。

**优化内容：**
- ✅ 优化 `IsolatedFoliateView.didUpdateWidget` 章节变更检测
- ✅ 只比较 `href` 而不是完整 HTML 字符串（避免 O(n) 字符串比较）
- ✅ `href` 唯一标识章节，足以检测章节变化
- ✅ 消除每次 widget 重建时的昂贵 HTML 比较（每章可能数千字符）

**性能影响：**
- Widget 更新时避免大字符串比较，特别是对长章节明显
- 保持功能完全一致，只优化检测逻辑

**测试结果：**
- 所有 443 个测试通过
- 静态分析无问题

**提交记录：**
```
dc79593 Optimize didUpdateWidget: compare href only, not full HTML
```

## 代码健康优化 + 测试增强（之前完成）

完成代码健康优化和测试覆盖补充（3 个提交）。

**已完成内容：**
- ✅ 文档化所有空 `catch` 块（`library_controller.dart` 中 3 处）
- ✅ 提取 `_callFoliateMethod` 辅助方法消除重复（5 处 → 1 处）
- ✅ 新增 5 个边界测试覆盖 `opened` 和 `updateProgress` 方法
- ✅ 测试持久化失败场景的正确处理
- ✅ 测试进度值范围限制（0.0-1.0）
- ✅ 测试缺失 ID 不创建文档的边界情况

**测试结果：**
- 所有 434 个测试通过（从 429 增加到 434）
- 静态分析无问题
- 代码覆盖率提升，特别是错误处理路径

**提交记录：**
```
fd1f31c Document the last empty catch block in opened()
ec54aa3 Add boundary tests for reading state persistence failures
8f6291c Improve code health: document errors and reduce duplication
```

## 渲染架构文档（之前完成）

完成 `docs/renderer-architecture.md`（261 行），详细说明当前 WebView + paginator.js 渲染方案。

**内容概览：**
- ✅ 核心组件说明（`IsolatedFoliateView`、`host.html`、`paginator.js`、`FoliateBridge`）
- ✅ 数据流图解（打开章节、翻页、笔记高亮）
- ✅ 架构优势（关注点分离、可测试性、降级策略）
- ✅ 已知限制与缓解方案
- ✅ 重构方案对比分析（为什么保持现有架构）
- ✅ 后续优化方向（性能、测试、文档、代码健康）

**决策：**
暂不重构渲染引擎（`view.js` / 移除 iframe / 纯 Flutter 渲染），当前架构已验证可行，重构成本高、收益低。

**推荐下一步：**
1. **代码健康优化**：提取重复代码、统一错误处理
2. **测试增强**：补充边界情况测试、WebView 集成测试
3. **性能优化**：减少 JavaScript 桥接调用、预加载下一章

## CSS @import media query 保留（之前完成）

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
