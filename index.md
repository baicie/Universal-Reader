# Universal Reader 最终设计方案 v1.0

## 1. 项目定位

做一个：

> **开源、Local-first、跨平台、尽可能兼容各种阅读型文件的 Universal Reader。**

目标不是再做一个 EPUB Reader，也不是复制 Calibre，而是做一个拥有现代 UI、统一阅读体验、可持续扩展格式的阅读平台。

首要平台：

**Android / iOS / Windows / macOS**

次要平台：

**Linux / Web**

Linux 不作为首版硬指标，因为 Flutter 当前 WebView 生态在 Linux 上仍明显弱于 Android/iOS/macOS/Windows；架构上支持，但延后完善。

---

# 2. 最终技术栈

| 层              | 技术                            |
| -------------- | ----------------------------- |
| App Framework  | **Flutter**                   |
| Language       | Dart                          |
| UI State       | **Riverpod**                  |
| Navigation     | go_router                     |
| Native Core    | **Rust**                      |
| Flutter ↔ Rust | **flutter_rust_bridge**       |
| Local DB       | **SQLite + FTS5**             |
| Reflow Reader  | **WebView + foliate-js**      |
| PDF            | **pdfrx / PDFium**            |
| Comic          | Flutter Native                |
| TXT/MD         | Rust Parser → Reflow Renderer |
| Archive        | Rust                          |
| Search / Index | Rust + SQLite FTS5            |
| Settings       | SQLite                        |
| Cover Cache    | Filesystem                    |
| Sync           | 后期独立 Sync Provider            |
| License        | **Apache-2.0**                |

截至 2026 年 8 月，`flutter_rust_bridge 2.13.0` 已覆盖 Android/iOS/Linux/macOS/Web/Windows，很适合把 Flutter 保持为表现层、Rust 保持为基础设施层。

PDF 采用 `pdfrx`。当前 `pdfrx 2.4.7` 基于 PDFium，并覆盖 Android、iOS、Windows、macOS、Linux 和 Web，许可证为 MIT。

---

# 3. 核心设计原则

整个项目遵守五条原则。

### 3.1 不自己重写成熟格式解析器

我们自己做：

* Reader Runtime
* 格式抽象
* Locator
* 标注
* 搜索
* Library
* UI
* 插件系统

而不是自己从 EPUB ZIP specification 开始造所有 parser。

---

### 3.2 不把所有文件统一转换成 HTML

错误架构：

```text
PDF ─┐
EPUB ├──→ HTML → WebView
CBZ ─┤
DOCX ┘
```

正确架构：

```text
                   ┌── Reflow Renderer
                   │
Document Adapter ──┼── Fixed Page Renderer
                   │
                   └── Image / Comic Renderer
```

因为 PDF、EPUB、漫画本质完全不同。

---

### 3.3 统一“阅读协议”，不统一“文件结构”

统一的是：

```text
Metadata
TOC
Locator
Progress
Search
Selection
Annotation
Bookmark
Navigation
```

而不是强迫 PDF 和 EPUB拥有相同内部结构。

---

### 3.4 Flutter 负责体验，Rust 负责能力

```text
Flutter
  ↓
Application / Reader Runtime
  ↓
flutter_rust_bridge
  ↓
Rust Core
```

Flutter 不应该承担大量文件解析、数据库扫描、全文索引。

Rust 也不应该负责按钮、动画、主题和页面状态。

---

### 3.5 所有第三方 Renderer 必须隔离

业务代码绝不能：

```dart
FoliateView(...)
PdfViewer(...)
```

到处直接调用第三方库。

必须：

```text
UI
 ↓
Reader Runtime
 ↓
Renderer Interface
 ↓
具体第三方实现
```

这能避免项目未来被某个库锁死。

---

# 4. 整体架构

```text
┌─────────────────────────────────────────────┐
│                 Flutter App                 │
│                                             │
│ Library / Search / Reader / Settings / UI  │
└───────────────────┬─────────────────────────┘
                    │
          ┌─────────▼─────────┐
          │   Reader Runtime  │
          │                   │
          │ DocumentSession   │
          │ Locator           │
          │ Navigation        │
          │ Annotation        │
          │ Progress          │
          │ Bookmark          │
          └─────────┬─────────┘
                    │
     ┌──────────────┼──────────────────┐
     │              │                  │
     ▼              ▼                  ▼
 Reflow         Fixed Page           Comic
 Renderer        Renderer            Renderer
     │              │                  │
 WebView          pdfrx             Flutter
     │              │                  │
 foliate-js      PDFium             Images
     │
 EPUB/MOBI/
 AZW3/FB2
                    │
          ┌─────────▼─────────┐
          │     Rust Core     │
          │                   │
          │ File Source       │
          │ Format Detect     │
          │ Archive           │
          │ Metadata          │
          │ SQLite            │
          │ FTS Index         │
          │ Cache             │
          └───────────────────┘
```

---

# 5. Reader Runtime：整个项目最核心的部分

真正值得长期维护的不是 EPUB Parser，而是：

> **Reader Runtime**

核心接口：

```dart
abstract interface class ReaderDocument {
  DocumentMetadata get metadata;

  Future<List<TocItem>> getToc();

  Future<Locator> currentLocator();

  Future<void> goTo(Locator locator);

  Future<List<SearchResult>> search(String query);

  Future<String?> extractText(DocumentRange range);

  Stream<double> get progress;
}
```

Renderer：

```dart
abstract interface class DocumentRenderer {
  Widget build(BuildContext context);

  Future<void> open(ReaderDocument document);

  Future<void> goTo(Locator locator);

  Future<void> next();

  Future<void> previous();

  Future<void> dispose();
}
```

Adapter：

```dart
abstract interface class DocumentAdapter {
  String get id;

  Future<double> sniff(DocumentSource source);

  Future<ReaderDocument> open(
    DocumentSource source,
  );
}
```

这样以后增加：

```text
DjVu
CHM
DOCX
ODT
RTF
KFX
PDB
```

都不改 Reader UI。

只增加 Adapter。

---

# 6. Locator 是第二核心抽象

不要用：

```text
page = 137
```

作为全局阅读定位方式。

定义：

```dart
sealed class Locator {
  const Locator();
}
```

下面分别实现：

```text
EpubLocator
PdfLocator
TextLocator
ComicLocator
HtmlLocator
```

例如：

```dart
class PdfLocator extends Locator {
  final int page;
  final double? x;
  final double? y;
}

class EpubLocator extends Locator {
  final String href;
  final String? cfi;
  final double? progression;
}

class TextLocator extends Locator {
  final int offset;
}

class ComicLocator extends Locator {
  final int page;
}
```

于是：

```text
阅读进度
书签
历史
标注
同步
恢复阅读
```

全部可以依赖 Locator，而不依赖文件类型。

---

# 7. 三大 Renderer

## 7.1 ReflowRenderer

负责所有“文本可以重新排版”的内容。

```text
EPUB
MOBI
AZW3
FB2
KEPUB
TXT
Markdown
HTML
XHTML
DOCX*
ODT*
RTF*
CHM*
```

核心：

```text
Flutter
 ↓
WebRendererBackend
 ↓
WebView
 ↓
foliate-js / generated HTML
```

`foliate-js` 当前支持 EPUB、MOBI、KF8/AZW3、FB2、CBZ，并自带分页、搜索、进度和 annotation 等模块。它特别适合当 Reader Engine。

但它自己明确表示 API **尚未稳定，可能发生 breaking changes**。

因此必须：

```text
ReflowRenderer
     ↓
FoliateEngineAdapter
     ↓
foliate-js
```

绝不让 Flutter Application 层直接依赖 foliate API。

---

# 8. WebView 也需要做一层 Backend

定义：

```dart
abstract interface class WebRendererBackend {
  Future<void> loadReader();

  Future<dynamic> evaluate(String script);

  Stream<ReaderBridgeEvent> get events;

  Future<void> dispose();
}
```

第一阶段：

```text
Android
iOS
macOS
Windows
        ↓
flutter_inappwebview
```

目前 `flutter_inappwebview 6.1.5` 官方覆盖 Android、iOS、macOS、Windows 和 Web，并提供 JS bridge/headless WebView 等能力。

Linux 单独：

```text
LinuxBackend
     ↓
WebKitGTK
```

Linux Flutter WebView 目前仍然比较碎片化，但已有基于 WebKitGTK 4.1 的实现，因此只需要把它隔离到 Backend，而不是污染 Reader Runtime。

这就是为什么 Linux 应该是 Tier 2。

---

# 9. PDF Renderer

PDF 完全独立：

```text
PDF
 ↓
PdfAdapter
 ↓
PdfRenderer
 ↓
pdfrx
 ↓
PDFium
```

不通过 WebView。

当前 pdfrx 已经支持：

```text
文本选择
PDF 显示
页面操作
组合
图片导入
跨平台 PDFium
```

并覆盖六大目标平台。

未来如果 PDF Reader 要变复杂：

```text
Annotation
Ink
Signature
OCR
Form
Page Editing
```

依然可以继续扩展 PdfRenderer。

---

# 10. Comic Renderer

漫画应该是纯 Flutter Renderer。

支持：

```text
CBZ
CBR
CBT
CB7
```

流程：

```text
Archive
 ↓
Rust 解压/索引
 ↓
ImageManifest
 ↓
ComicRenderer
```

阅读模式：

```text
Vertical Scroll

Single Page

Double Page

LTR

RTL

Fit Width

Fit Height
```

以及：

```text
前 2 页预加载
后 3~5 页预加载
LRU Image Cache
```

Comic 不进入 WebView。

---

# 11. Text / Markdown

TXT：

```text
File
 ↓
Encoding Detect
 ↓
Text Parser
 ↓
Section Split
 ↓
ReflowPackage
```

Markdown：

```text
Markdown
 ↓
Rust Markdown Parser
 ↓
Sanitized HTML
 ↓
ReflowRenderer
```

不要让单个 100 MB TXT 一次性变成一个 HTML DOM。

应该切：

```text
Chapter
Section
Chunk
```

然后按需载入。

---

# 12. Office 格式

这里必须克制。

Reader 不是 Office。

目标：

> **可读，而不是 100% Word 像素级还原。**

统一转换：

```text
DOCX
ODT
RTF
 ↓
OfficeAdapter
 ↓
ReflowPackage
 ↓
ReflowRenderer
```

`ReflowPackage`：

```text
manifest
sections[]
styles
assets
metadata
toc
```

以后无论是 Rust parser、WASM parser 还是 JS converter，都可以替换。

---

# 13. 格式检测

绝不能只：

```dart
if (path.endsWith(".epub"))
```

Rust Core：

```text
Extension
+
MIME
+
Magic bytes
+
Container inspection
```

例如：

```text
ZIP
 │
 ├ META-INF/container.xml
 │       ↓
 │      EPUB
 │
 ├ word/document.xml
 │       ↓
 │      DOCX
 │
 └ mostly images
         ↓
        CBZ
```

定义：

```rust
enum DocumentFormat {
    Epub,
    Pdf,
    Mobi,
    Azw3,
    Fb2,
    Txt,
    Markdown,
    Html,
    Cbz,
    Cbr,
    Docx,
    Djvu,
    Unknown,
}
```

---

# 14. 格式兼容最终目标

### Tier 1

必须做到优秀：

```text
EPUB
PDF
TXT
Markdown
HTML
MOBI
AZW3
FB2
CBZ
CBR
```

已经覆盖绝大多数实际阅读场景。

### Tier 2

做到可用：

```text
KEPUB
DOCX
ODT
RTF
CBT
CB7
DjVu
CHM
```

### Tier 3

兼容历史资料：

```text
PRC
PDB
LIT
HTMLZ
TXTZ
FBZ
```

### Experimental

```text
KFX
AZW4
PPTX
XLSX
```

### 不支持

```text
带 DRM 的 Kindle 内容
Adobe DRM EPUB
其他受保护内容
```

DRM 不进入项目范围。

---

# 15. Rust Core

Rust Workspace：

```text
rust/
├── reader-core
├── reader-format
├── reader-source
├── reader-archive
├── reader-library
├── reader-database
├── reader-index
├── reader-cache
└── reader-sync
```

负责：

```text
Filesystem
Format detection
Archive IO
Hash
Metadata
Database
FTS
Index
Cache
Library Scan
Import
Future sync
```

Rust 不负责：

```text
UI
Widget
Navigation
Animation
Reader Toolbar
Theme
```

---

# 16. 数据库

使用：

> **SQLite + FTS5**

核心表：

```text
documents
sources
collections
tags
document_tags
reading_states
bookmarks
annotations
search_index
settings
```

`documents` 和实际文件路径分离：

```text
Document
    ↓
Source A → /Books/a.epub
Source B → WebDAV/a.epub
Source C → SDCard/a.epub
```

Document ID 推荐：

```text
metadata fingerprint
+
content hash
```

这样移动文件之后不会变成一本新书。

---

# 17. Annotation

不要只保存选中的文字：

```json
{
  "text": "hello world"
}
```

而应该：

```text
Annotation
├ locator
├ range
├ quote
├ prefix
├ suffix
├ color
├ note
└ created_at
```

这样书籍重新分页、字体变化之后仍有机会恢复位置。

---

# 18. 全文搜索

统一：

```text
DocumentAdapter
       ↓
extractText()
       ↓
Rust Indexer
       ↓
SQLite FTS5
```

最终可以：

```text
Search: "ownership"

Rust Book
Chapter 4
...

Programming Rust.pdf
Page 153
...

note.md
Section 8
...
```

这会成为项目非常强的差异化能力。

---

# 19. Library

首页只做：

```text
All
Recent
Reading
Favorites
Collections
```

支持：

```text
Import File
Import Folder
Drag & Drop
Folder Scan
```

桌面：

```text
Monitor Folder
```

移动：

```text
System File Picker
Share → Reader
```

不要首版加入商城。

---

# 20. UI

产品设计方向：

> **极简、内容优先。**

桌面：

```text
┌──────────────────────────────────────────────┐
│ Library    Search                     ⚙      │
├──────────────┬───────────────────────────────┤
│ All          │                               │
│ Recent       │                               │
│ Reading      │          Book Grid            │
│ Favorite     │                               │
│ Collections  │                               │
└──────────────┴───────────────────────────────┘
```

Reader：

```text
┌──────────────────────────────────────────────┐
│ ←       Chapter                     Aa  ⋯    │
├───────┬──────────────────────────────────────┤
│ TOC   │                                      │
│       │                                      │
│       │               Content                │
│       │                                      │
│       │                                      │
├───────┴──────────────────────────────────────┤
│              Chapter 8       37%             │
└──────────────────────────────────────────────┘
```

移动端阅读时默认：

> 全屏隐藏所有工具栏。

点击中心区域再显示 Reader Chrome。

---

# 21. Theme 系统

统一：

```dart
class ReaderTheme {
  Color background;
  Color foreground;

  String fontFamily;

  double fontSize;
  double lineHeight;

  double paragraphSpacing;

  double horizontalMargin;

  ReaderColorMode mode;
}
```

内置：

```text
Light
Dark
Sepia
OLED
```

EPUB/TXT/Markdown 共用。

PDF 和 Comic 只共享外围 UI。

---

# 22. 安全

这一点很重要，因为 EPUB/HTML 本质上可能带 HTML。

默认：

```text
禁止访问公网

禁止任意 window.open

禁止 file:// 任意访问

禁止外部 JS

CSP

sanitize generated HTML

自定义 resource protocol
```

例如：

```text
reader-resource://book/{id}/image/1.jpg
```

Web Renderer 只能访问当前 Document 沙箱。

不能让 EPUB 变成：

> 本地 HTML 任意执行环境。

---

# 23. 插件体系

**第一版设计接口，但不要第一版开放插件市场。**

```text
ReaderPlugin
├ FormatAdapter
├ MetadataProvider
├ SyncProvider
└ ToolProvider
```

最重要的是：

```text
FormatAdapter
```

以后可以实现：

```text
reader-djvu
reader-chm
reader-kfx
reader-office
```

Plugin ABI 第一阶段不用做动态 Rust ABI。

内部 package 即可。

等架构稳定以后才考虑：

```text
WASM Component
```

作为真正第三方插件沙箱。

---

# 24. 同步

第一版：

> **完全 Local-first。**

不做账号。

第二阶段：

```text
SyncProvider
├ WebDAV
├ S3
├ Local Folder
└ Future Cloud
```

同步：

```text
ReadingState
Bookmarks
Annotations
Collections
Settings
```

默认不自动同步整本书。

书籍文件同步与 Reader Metadata Sync 分离。

---

# 25. AI

AI 不进入核心 Reader。

以后作为：

```text
Reader Tool
```

可以有：

```text
Summarize selection
Explain
Translate
Ask document
Vocabulary
Semantic search
```

但 Reader 在没有任何 AI Provider 时必须 100% 可用。

也就是说：

> **AI 是 enhancement，不是 dependency。**

后续若引入阅读助手，只作为 `ToolProvider`，且必须先完成规格再实现。当前规格见 `docs/ai-agent.md`。第一年仍不做自主大模型 Agent。

---

# 26. 推荐 Monorepo

```text
universal-reader/
│
├── app/
│   ├── lib/
│   │   ├── app/
│   │   ├── features/
│   │   │   ├── library/
│   │   │   ├── reader/
│   │   │   ├── search/
│   │   │   ├── collections/
│   │   │   └── settings/
│   │   │
│   │   ├── reader/
│   │   │   ├── runtime/
│   │   │   ├── document/
│   │   │   ├── locator/
│   │   │   ├── adapters/
│   │   │   ├── renderers/
│   │   │   └── annotations/
│   │   │
│   │   └── rust/
│   │
│   └── assets/
│       └── reader-web/
│
├── reader-web/
│   ├── foliate/
│   ├── bridge/
│   ├── theme/
│   └── index.html
│
├── rust/
│   ├── Cargo.toml
│   └── crates/
│       ├── core/
│       ├── format/
│       ├── source/
│       ├── archive/
│       ├── library/
│       ├── database/
│       ├── index/
│       └── cache/
│
├── test-books/
│
└── docs/
    ├── architecture/
    ├── formats/
    └── adr/
```

---

# 27. 必须建立 Compatibility Corpus

这是这个项目非常重要、甚至比 Unit Test 更重要的一部分。

建立：

```text
test-books/
├── epub/
├── mobi/
├── azw3/
├── fb2/
├── pdf/
├── comic/
├── txt/
└── malformed/
```

每种格式至少收集：

```text
普通文件
超大文件
RTL
CJK
Emoji
特殊字体
图片密集
复杂目录
损坏文件
异常编码
```

最终 CI 输出：

```text
EPUB   96/100
MOBI   44/50
AZW3   38/40
PDF    80/80
FB2    24/25
CBZ    30/30
```

Universal Reader 的真正护城河不是：

> 支持 30 个扩展名。

而是：

> **这 30 个格式真的能打开。**

---

# 28. 性能目标

大文件也必须从架构上考虑。

目标：

```text
App cold start          < 1.5 s
普通书首次打开           < 500 ms
恢复阅读                < 300 ms
翻页响应                 < 16~32 ms
Library 10k documents   可正常使用
全文索引                 后台渐进构建
```

原则：

```text
Lazy Loading

Section Loading

Page Cache

Image LRU

Background Index

Streaming Archive

Never load entire book unless unavoidable
```

`foliate-js` 本身的一个优势就是不要求把整本电子书一次性加载进内存。

---

# 29. MVP 路线

## Phase 0 — Foundation

做到：

```text
Flutter Shell
Rust bridge
DocumentSource
FormatDetector
SQLite
Library
```

验收：

> 可以导入文件并正确识别格式。

---

## Phase 1 — EPUB

```text
foliate-js
WebView Bridge
EPUB
TOC
Next / Previous
Progress
Theme
```

验收：

> 它已经是一款可以真正读完一本 EPUB 的 Reader。

---

## Phase 2 — PDF

```text
pdfrx
PDF Reader
TOC
Search
Progress
Zoom
```

---

## Phase 3 — Kindle / FB2

通过 foliate Adapter：

```text
MOBI
AZW3
FB2
```

---

## Phase 4 — Text

```text
TXT
Markdown
HTML
```

---

## Phase 5 — Comic

```text
CBZ
CBR
Single
Double
Vertical
RTL
```

到这里发布：

# v0.1.0

支持：

```text
EPUB
PDF
MOBI
AZW3
FB2
TXT
Markdown
HTML
CBZ
CBR
```

这就是一个完整产品。

---

# 30. v0.2

增加：

```text
Bookmark
Highlight
Annotation
FTS Search
Collections
Folder Watch
Import improvements
```

---

# 31. v0.3

增加：

```text
DOCX
ODT
RTF
DjVu
CHM
CB7
CBT
```

---

# 32. v0.4

增加：

```text
WebDAV
S3
Local Folder Sync
Annotation Sync
Reading Progress Sync
```

---

# 33. v1.0

v1.0 的标准不是功能数量。

而是：

```text
Reader Runtime API 稳定

Locator API 稳定

Adapter API 稳定

十余种格式可靠

Library 10k+ 文档可靠

Annotations 稳定

跨平台可靠

Compatibility Corpus 成熟
```

届时再开放真正的 Plugin API。

---

# 34. 明确不做什么

第一年不要做：

```text
电子书商城
社交
社区
账号体系
复杂云后端
编辑器
Office 编辑
PDF 编辑器
OCR 平台
DRM 破解
插件市场
大模型 Agent
```

否则很容易从：

> Universal Reader

变成：

> 什么都有一点、但书不好读。

---

# 35. 最终技术决策

最终架构固定为：

```text
                 Flutter
                    │
                    ▼
             Reader Runtime
                    │
      ┌─────────────┼─────────────┐
      │             │             │
      ▼             ▼             ▼
   Reflow          PDF          Comic
      │             │             │
   WebView         pdfrx        Flutter
      │             │
 foliate-js       PDFium
      │
 EPUB/MOBI/
 AZW3/FB2
                    │
                    ▼
                 Rust Core
                    │
    ┌───────────────┼───────────────┐
    ▼               ▼               ▼
   File          SQLite           Index
 Archive          FTS5           Cache
```

其中最重要的资产不是某个 parser。

而是：

```text
Reader Runtime
+
DocumentAdapter
+
Locator
+
Compatibility Corpus
```

这四个东西一旦稳定，未来无论：

```text
foliate-js → 新引擎

pdfrx → 新 PDF 引擎

Dart parser → Rust parser

Flutter WebView → 新 renderer
```

上层产品都不用推翻重写。

---

# 36. 最终结论

如果现在从零开始，我认为这套方案是最合适的：

> **Flutter + Rust Core + foliate-js + PDFium + SQLite FTS5**

Flutter 提供真正优秀的跨平台 App 体验。

Rust 提供本地文件、索引、数据库、压缩包和未来高性能格式处理能力。

foliate-js 解决电子书领域最麻烦的 EPUB/MOBI/AZW3/FB2 排版问题。

PDFium 专门处理 PDF。

Flutter Native 专门处理漫画和应用 UI。

然后用：

> **Reader Runtime + DocumentAdapter + Locator**

把这些看起来完全不同的东西统一成一个产品。

这比“找一个支持很多格式的库，然后围着它做 App”更重要。

最终它应该不是：

**Flutter EPUB Reader**

而是：

# Universal Reader

**One reader for every document.**

而且架构上是真正有机会长期做到“一个 App 打开绝大部分阅读型文件”，而不是 README 里堆几十个扩展名。
