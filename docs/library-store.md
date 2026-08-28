# Spec: 书库作为本机网盘

## Objective

Rust 服务把书库做成**简单对象存储**（网盘），Flutter 只负责展示和导入。部署 Web + 服务后，浏览器里的书架就是服务器磁盘上的书，而不是 `SharedPreferences` 里的演示数据。

成功标准：

- 导入一本书后出现在 `GET /v1/library/documents`，文件落在磁盘。
- 刷新 Web 仍能看到这本书。
- 阅读进度写回服务，而不是只存在浏览器。
- 服务不可用时（桌面端没起 Rust），仍回退到本机 `SharedPreferences`。

## Assumptions

1. 这是个人部署的 local-first 服务，第一版不加账号、不加配额、不加分享链接。
2. 文件是真相；元数据（标题、进度）是附属目录，以后可以迁到 SQLite + FTS5（`index.md` §16），不在这一步上数据库。
3. 不解析 EPUB/PDF 元数据；标题来自文件名。封面仍用颜色块。
4. 这一步只接通书库 CRUD；TXT/Markdown/HTML 阅读见 `docs/text-reader.md`。

## 存储布局

```text
$UNIVERSAL_READER_STORAGE_DIR/     # 默认 data/library
  files/{id}.{ext}                 # 二进制，服务生成稳定 id
  catalog.json                     # 文档列表 + 进度
```

选择这个模型而不是「按原文件名堆目录」或「立刻上 SQLite」的原因：

- 原名可能含空格、中文、重名；URL 和路径用不透明 id 更稳。
- JSON 目录人能打开看，和个人网盘心智一致；SQLite 留给搜索/标注。
- 以后 `documents` 表可以一对一迁自 `catalog.json`，文件路径不用动。

## API

| 方法 | 路径 | 作用 |
| --- | --- | --- |
| `GET` | `/v1/library/documents` | 列出书库（会丢掉磁盘上已不存在的条目） |
| `GET` | `/v1/library/documents/{id}` | 单本元数据 |
| `GET` | `/v1/library/documents/{id}/file` | 下载原文件 |
| `POST` | `/v1/library/files` | multipart 字段 `file`，写入 `files/` 并登记 |
| `PATCH` | `/v1/library/documents/{id}` | `{ "progress": 0.37 }`，同时更新最近打开时间 |
| `DELETE` | `/v1/library/documents/{id}` | 删文件和目录项 |

列表/上传响应字段：`id`、`file_name`、`stored_name`、`title`、`author`、`format`、`document_type`、`size`、`cover_color`、`progress`、`last_opened_ms`。

## Flutter

启动时请求 `{origin}/health`（Web 与服务同域时即当前页 origin，否则 `http://127.0.0.1:8787`）。命中 `universal-reader-server` 则走 HTTP 书库，不再灌演示书。

导入使用 `PlatformFile.readAsBytes()` 后 `POST /v1/library/files`。进度走 `PATCH`。

## Commands

```powershell
cd rust
cargo test --workspace
cd ..\app
flutter test
```

## Boundaries

- Always: 文件写在 `files/` 下；id 拒绝 `..` 和路径分隔符；上传仍限 64 MiB、仅支持已有阅读格式。
- Ask first: 引入 SQLite、账号、公网鉴权。
- Never: 把浏览器里的演示书当服务端书库真相。

## 下一步（不做）

文件夹扫描、WebDAV、哈希去重、封面提取、全文索引。
