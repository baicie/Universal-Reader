# Spec: 无 Rust 时的 Flutter SQLite

## Objective

本机服务不可达时，Flutter 用 SQLite 保存书目、文件字节、笔记和问答。刷新后仍能打开刚导入的书。

成功标准：

- 导入 TXT/EPUB 后 `readFile` 能读回原字节。
- 相同内容哈希的第二次导入返回已有书，不建副本。
- 从旧版 SharedPreferences 书目迁到 SQLite；迁不了的行丢掉，不拿种子书顶上。
- Web 没有 FFI SQLite 时，用同一仓库接口的持久化实现，不静默换成另一本书。

## Assumptions

1. IO/桌面/测试走 `sqflite_common_ffi`。
2. Web 走条件导入的持久化后端（不是 rusqlite）。
3. 有 Rust 时仍走 HTTP 书库，不双写。

## Commands

```powershell
cd app
flutter test test/sqlite_library_repository_test.dart
```
