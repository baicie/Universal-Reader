# Spec: 书架改书名和作者

## Objective

用户可以改书架上显示的书名和作者。改的是书目，不改原文件。空书名不写；没有这本书就不造另一本。

成功标准：

- 把 `notes.txt` 的书名改成「设计笔记」后，书架显示「设计笔记」，再 load 仍是这个名字。
- 作者可改成真实名字，也可改成空（界面仍用「本地书库」标签）。
- 书名为空或只含空白时保留原书名，不换成种子书。
- 未知 id 不新增条目。
- 本机 SQLite / 内存库 / HTTP `PATCH` 都能改；走服务时 `{ "title", "author" }` 不必带 `progress`。

## Assumptions

1. 只改目录项，不重写 EPUB OPF / TXT 文件。
2. 同一文件再导入仍命中原 id，用户改过的书名保留。
3. 不引入 `flutter_rust_bridge`。不发版，除非另说。

请直接纠正以上假设，否则按它们实现。

## Commands

```powershell
cd app
flutter gen-l10n
flutter test test/library_repository_test.dart test/sqlite_library_repository_test.dart test/library_controller_test.dart test/library_api_test.dart test/widget_test.dart
flutter analyze
cd ..\rust
cargo test --workspace
cargo clippy --workspace --all-targets -- -D warnings
```

## Project Structure

```text
docs/next.md
app/lib/core/library_repository.dart
app/lib/core/library_controller.dart
app/lib/features/library/shelf_ui.dart
app/lib/l10n/app_zh.arb
app/lib/l10n/app_en.arb
rust/crates/reader-server/src/lib.rs
rust/crates/reader-server/src/library.rs
```

## Code Style

```dart
Future<void> writeIdentity({
  required String id,
  required String title,
  required String author,
});
```

UI 放 `features/library/`，文案走 l10n。书名来自用户输入，不翻译。

## Testing Strategy

- 先失败：改书名后 load 仍是文件名。
- 空书名、未知 id、HTTP PATCH 无 progress。
- Widget：书籍操作 → 编辑书名 → 保存后书架是新书名。

## Boundaries

- Always: 缺书就是缺；空书名保持原名。
- Ask first: 改封面、批量重命名、写回 OPF。
- Never: 用种子书名顶上；未知 id 新建一本。
