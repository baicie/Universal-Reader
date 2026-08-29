# Spec: 服务端书目真相在 SQLite

## Objective

本机服务的书目以 `library.sqlite` 的 `documents` 表为准，不再把 `catalog.json` 当真相：

- 导入、列表、进度、删除都读写 SQLite。HTTP JSON 形状不变。
- 已有 `catalog.json`：仅在尚未迁移时导入一次。迁完之后改 JSON 不能改书名、进度或复活已删的书。
- 文件仍在 `files/`；缺文件的条目仍从列表去掉。不发明种子书。

## Assumptions

1. 不引入 `flutter_rust_bridge`。Flutter 继续走现有 HTTP。
2. 不做账号、回收站、双写 JSON。
3. SQLite 损坏按错误处理，不当空库。坏掉的 `catalog.json` 不当书目真相。
4. 迁成功后不删除用户的 `catalog.json`，只是不再读、不再写。

## Commands

```powershell
cd rust
cargo test -p universal-reader-server --lib
cargo test --workspace
cargo clippy --workspace --all-targets -- -D warnings
cargo fmt --all -- --check
```

## Boundaries

- Always: 文件写在 `files/`；按 `documentId` 隔离；API 字段保持现有列表。
- Ask first: 账号、把问答也迁进 SQLite。
- Never: 用种子书或另一本顶上；把坏 SQLite 当成空库再灌 JSON。
