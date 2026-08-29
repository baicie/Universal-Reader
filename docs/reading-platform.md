# Spec: 阅读平台下一程

## Objective

在 v0.0.1-dev.9 之后，把「能读完一本主格式书」和「按书提问」补齐。用户已经明确要一次做完下面这些：

- EPUB / PDF 真实可读（目录、进度、正文，不是占位提示）
- SQLite + FTS5（服务端书库真相，按章/页索引）
- 问整书（回答带 locator）
- 有限 loop（模型或本地检索可以提议跳转，必须用户确认）
- 文件夹扫描、WebDAV 导入
- Ollama 作为第二 Provider
- 把一条问答存成笔记（Annotation）

目标用户：已经把书放进本机书库、要读完并偶尔提问的人。不是要云端书库或自动摘要整库的人。

## Assumptions

1. Renderer 隔离：Foliate 桥 / pdfrx / 漫画页，UI 不直接点名第三方。
2. 不引入 `flutter_rust_bridge`。Flutter ↔ Rust 继续走本机 HTTP。
3. 无 Rust 时 Flutter 用 SQLite 保存书和文件字节；有 Rust 时仍走 HTTP。
4. WebDAV 双向同步、文件夹监视、哈希去重、封面提取按 `docs/library-sync.md`。
5. WebDAV / Ollama / DeepSeek 的 URL 只来自设置或服务端环境变量。
6. 笔记的 quote 画进当前正文；不让 Agent 自己写标注。
7. 损坏文件如实披露，不回退样章。

请直接纠正以上假设，否则按它们实现。

## Tech Stack

沿用现有栈。新增：

| 层 | 选择 |
| --- | --- |
| EPUB Adapter | Dart `archive` + `xml`（测得过的最小 OPF/spine/nav） |
| PDF Adapter | 页面文本抽取（测得过的简单内容流）；视觉 pdfrx 后置 |
| DB | Rust `rusqlite` bundled + FTS5 |
| 导入 | 现有 multipart + 新的 scan / WebDAV |
| 模型 | DeepSeek 与 Ollama，都走 OpenAI 兼容 chat |

## Commands

```powershell
cd app
flutter pub get
flutter gen-l10n
flutter analyze
flutter test
```

```powershell
cd rust
cargo test --workspace
cargo clippy --workspace --all-targets -- -D warnings
```

## Project Structure

```text
docs/reading-platform.md      本规格
docs/epub-reader.md
docs/pdf-reader.md
docs/library-sources.md
docs/annotations.md
app/lib/core/epub_document.dart
app/lib/core/pdf_document.dart
app/lib/features/library/      文件夹、WebDAV、笔记 UI 与仓库
app/lib/features/tools/ai/     问整书、Ollama、提议跳转
rust/crates/reader-server/src/extract.rs
rust/crates/reader-server/src/sqlite.rs
rust/crates/reader-server/src/sources.rs
```

新行为放 `app/lib/features/` 或 `app/lib/core/`，不把逻辑堆进 `main.dart`。

## Code Style

阅读协议不变。UI 只认 `ReaderDocument` / `ChapteredDocument`，不直接解 ZIP 或解析 PDF。

```dart
abstract interface class ChapteredDocument implements ReaderDocument {
  int get chapterIndex;
  int get chapterCount;
  String get currentChapterText;
  bool get truncated;
  Locator locatorForProgress(double progress);
}
```

## Testing Strategy

- 先写失败测试：最小 EPUB ZIP、损坏 EPUB、简单 PDF、损坏 PDF、FTS 命中带 locator、扫描不删除已有书、WebDAV 只取已配置 URL、Ollama 不需要 Key、存笔记不改对话。
- 不在 CI 打真实 DeepSeek / Ollama / 公网 WebDAV。
- 回归：现有 library / text / AI widget 测试必须继续通过。

## Boundaries

- Always
  - 缺文件、损坏文件、未索引：如实披露。
  - 问答和检索只针对当前 `documentId`。
  - 跳转必须用户点确认。
  - UI 文案走 l10n；书名和正文不翻译。
- Ask first
  - 换成完整 foliate-js 分页 / CFI。
  - 用户划线选区写入笔记。
  - 书目真相从 `catalog.json` 迁到 SQLite。
  - `flutter_rust_bridge`。
- Never
  - 用样章或另一本书填补缺失。
  - 客户端指定任意上游 URL。
  - Agent 自己翻页、改进度、写标注。

## Success Criteria

- 导入一本最小 EPUB / 简单 PDF 后，阅读页显示原文件章节或页面，目录可跳，进度可写回。
- 损坏 EPUB/PDF 提示损坏，不是「尚未接入」，也不是样章。
- 本机服务把目录放进 SQLite；按书 FTS 能返回带 locator 的命中。
- 「问这本书」把检索命中送给模型，回答带 locator；命中可提议跳转，需确认。
- 设置里可选 Ollama；无 Key 也可在已配置时就绪。
- 一条问答能存成该书笔记；删书时笔记一起删。

## Open Questions

1. 本轮用章节/页文本读完 EPUB/PDF，而不是先上 foliate-js / pdfrx，是否可以？
2. 无 Rust 时，Flutter 单机是否也要 SQLite，还是继续 SharedPreferences？
