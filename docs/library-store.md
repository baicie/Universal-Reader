# Spec: 书库作为本机网盘

## Objective

Rust 服务把书库做成**简单对象存储**（网盘），Flutter 只负责展示和导入。部署 Web + 服务后，浏览器里的书架就是服务器磁盘上的书，而不是 `SharedPreferences` 里的演示数据。

成功标准：

- 导入一本书后出现在 `GET /v1/library/documents`，文件落在磁盘。
- 刷新 Web 仍能看到这本书。
- 阅读进度写回服务，而不是只存在浏览器。
- 服务不可用时（桌面端没起 Rust），Flutter 走本机 SQLite（Web 走同源持久化），刷新后仍能打开刚导入的书。

## Assumptions

1. 这是个人部署的 local-first 服务，第一版不加账号、不加配额、不加分享链接。
2. 文件在 `files/`；书目和进度在 SQLite `documents`。无 Rust 时 Flutter 自己持有 SQLite。
3. EPUB / FB2 标题和作者来自文件元数据；没有元数据时用文件名、作者留空。有封面时显示封面，没有就用颜色块。
4. 哈希去重、封面、监视、双向 WebDAV 见 `docs/library-sync.md`。

## 存储布局

```text
$UNIVERSAL_READER_STORAGE_DIR/     # 默认 data/library
  files/{id}.{ext}                 # 二进制，服务生成稳定 id
  covers/{id}                      # 可选封面
  catalog.json                     # 旧书目；仅在 SQLite 尚未迁移时导入一次
  library.sqlite                   # documents 书目 + FTS + annotations + settings
  conversations/{id}.json          # 旧问答；仅在 SQLite 尚无该书记录时导入一次
```

选择这个模型而不是「按原文件名堆目录」的原因：

- 原名可能含空格、中文、重名；URL 和路径用不透明 id 更稳。
- 书目、进度、笔记和收藏夹同在 SQLite；文件路径仍是 `files/{id}.{ext}`。
- 已有 `catalog.json` 会迁进 `documents` 表一次，之后不再读写 JSON。

## API

| 方法 | 路径 | 作用 |
| --- | --- | --- |
| `GET` | `/v1/library/documents` | 列出书库（会丢掉磁盘上已不存在的条目） |
| `GET` | `/v1/library/documents/{id}` | 单本元数据 |
| `GET` | `/v1/library/documents/{id}/file` | 下载原文件 |
| `POST` | `/v1/library/files` | multipart 字段 `file`，写入 `files/` 并登记 |
| `PATCH` | `/v1/library/documents/{id}` | `{ "progress": 0.37 }`，同时更新最近打开时间 |
| `DELETE` | `/v1/library/documents/{id}` | 删文件、目录项和问答记录 |
| `GET` | `/v1/library/documents/{id}/conversations` | 该书问答记录 |
| `PUT` | `/v1/library/documents/{id}/conversations` | 覆盖该书问答记录 |
| `GET` | `/v1/library/documents/{id}/search` | 该书 FTS 命中（`q`，带 locator） |
| `GET` | `/v1/library/documents/{id}/annotations` | 该书笔记 |
| `PUT` | `/v1/library/documents/{id}/annotations` | 覆盖该书笔记 |
| `GET` | `/v1/library/shelves` | 收藏与收藏夹；未知 document id 会被剪掉 |
| `PUT` | `/v1/library/shelves` | 覆盖收藏与收藏夹，保存前按书库 prune |
| `POST` | `/v1/library/scan` | 扫描本机文件夹并导入 |
| `POST` | `/v1/library/webdav/import` | 从已配置 WebDAV 导入 |
| `POST` | `/v1/library/webdav/sync` | 双向同步：拉缺失的书，推本地有、远端没有的书 |
| `POST` | `/v1/library/watch` | 监视本机文件夹，新文件只追加 |
| `GET` | `/v1/library/documents/{id}/cover` | 封面字节 |
| `GET` | `/v1/ai/status` | `{ "configured": bool, "providers": { "deepseek", "ollama" } }` |
| `POST` | `/v1/ai/chat` | 转发 DeepSeek 或 Ollama；不接受客户端 endpoint |

列表/上传响应字段：`id`、`file_name`、`stored_name`、`title`、`author`、`format`、`document_type`、`size`、`cover_color`、`progress`、`last_opened_ms`、`content_hash`、`has_cover`。

## Flutter

启动时请求 `{origin}/health`（Web 与服务同域时即当前页 origin，否则 `http://127.0.0.1:8787`）。命中 `universal-reader-server` 则走 HTTP 书库。空的本机书库保持为空，不灌演示书。删除走 `DELETE /v1/library/documents/{id}`。

导入使用 `PlatformFile.readAsBytes()` 后 `POST /v1/library/files`。进度走 `PATCH`。

## Commands

```powershell
cd rust
cargo test --workspace
cd ..\app
flutter test
```

## Boundaries

- Always: 文件写在 `files/` 下；id 拒绝 `..` 和路径分隔符；上传仍限 64 MiB、仅支持已有阅读格式。SQLite 损坏不能当成空库。扫描/监视/同步只追加，不删已有书。相同内容哈希不当新书。
- Ask first: 账号、公网鉴权。
- Never: 把浏览器里的演示书当服务端书库真相。
