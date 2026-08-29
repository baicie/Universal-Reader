# Spec: 书是书，问答进库，字号进阅读页

## Objective

导入后书架显示文件里的书名和作者；问答进 SQLite；阅读设置的字号到达 Foliate host。然后发 **v0.0.1-dev.11**。

成功标准：

- 导入带 `dc:title` / `dc:creator` 的 EPUB，书架上是 OPF 里的书名和作者，不是 `story` / 「本地文件」。
- 没有元数据（TXT，或坏 EPUB）继续用文件名，作者留空，不编种子书。
- 本机服务把问答存在 `library.sqlite`；已有 `conversations/{id}.json` 只导入一次。改 JSON 不能改已保存的问答。
- 无 Rust 时 Flutter SQLite 同样保存问答；删书时该书问答一起去掉。
- Foliate 打开命令带上阅读字号，host 用它排正文。不引入完整 foliate-js npm。

## Assumptions

1. 不引入 `flutter_rust_bridge`。不换完整上游 foliate-js。
2. PDF / 纯文本没有可靠元数据时用文件名。
3. 空作者仍由 l10n 显示为「本地书库」，那是标签不是假作者。
4. 发版：`app/pubspec.yaml` `0.0.1-dev.11+12`，`rust` workspace `0.0.1-dev.11`，tag `v0.0.1-dev.11`。

## Commands

```powershell
cd app
flutter test test/library_repository_test.dart test/conversation_store_test.dart test/foliate_bridge_test.dart test/widget_test.dart
flutter analyze
cd ..\rust
cargo test --workspace
cargo clippy --workspace --all-targets -- -D warnings
```

## Boundaries

- Always: 缺元数据就缺；按 `documentId` 隔离问答。
- Ask first: 完整 foliate-js npm 主题、账号。
- Never: 用种子书名顶上；把坏问答当成空历史。
