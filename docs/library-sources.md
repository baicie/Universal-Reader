# Spec: 文件夹扫描与 WebDAV

## Objective

除了点选单个文件，用户还能：

- 扫描本机文件夹，把支持的阅读格式导入书库。
- 从已配置的 WebDAV 目录拉取支持的文件。

成功标准：

- 扫描只 **复制** 进 `files/` 并登记；文件夹里消失的文件不会删掉书架上的书。
- 已存在相同内容哈希或相同 `file_name` 的条目跳过，不当成新书。
- WebDAV 只使用设置/环境里的 base URL，请求体不能改成任意主机。
- 超过 64 MiB 或未知扩展名的文件跳过。

## Assumptions

1. 监视和双向同步见 `docs/library-sync.md`。扫描本身仍只追加。
2. WebDAV 用 Basic 认证；PROPFIND Depth 1。
3. Flutter 侧「导入文件夹」在测得过的路径上走 `importNamedBytes`；服务端提供 scan / watch / sync。
4. 无 Rust 时，文件夹导入只影响当前可写的本机 SQLite 仓库。

## Commands

```powershell
cd rust
cargo test --workspace
cd ..\app
flutter test test/library_controller_test.dart
```

## Boundaries

- Always: id 仍拒绝 `..` 和分隔符；上传限制不变。
- Ask first: 远端删除镜像到书架。
- Never: 扫描结果覆盖整本目录、删除用户已导入的书。
