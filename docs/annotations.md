# Spec: 笔记（由问答保存）

## Objective

用户可以把一条问答存成该书的笔记。笔记带 locator 标签，删书时一起删。

成功标准：

- 保存后再次打开该书能读到这条笔记。
- 笔记不是对话的别名：删笔记不影响问答记录，反之亦然。
- 损坏的笔记文件/行是错误，不是空列表。
- 无账号、不同步。

## Assumptions

1. 笔记的 quote 画进当前章节正文（高亮），不是墨迹层。
2. 服务端进 SQLite `annotations` 表；本机无服务时优先进 Flutter SQLite，否则 SharedPreferences，前缀 `universal_reader.annotations.v1.`。
3. `source` 为 `user` 或 `assistant`。

## Commands

```powershell
cd app
flutter test test/annotation_store_test.dart
cd ..\rust
cargo test --workspace
```

## Boundaries

- Always: 按 `documentId` 隔离。
- Ask first: 导出、跨设备同步笔记。
- Never: Agent 自己写笔记。
