# Spec: 去重、封面、监视与双向同步

## Objective

服务端书库支持：

- 按内容 SHA-256 去重
- 从 EPUB/FB2 抽封面，写入 `covers/`。FB2 只跟 `title-info` coverpage 的图片 href，不靠 binary id 是否含 `cover`。
- 监视已配置文件夹，新文件只追加
- 本地文件夹双向同步：拉缺失的书，推本地有、文件夹没有的书
- S3 兼容存储双向同步：ListObjectsV2 分页、对象下载、对象上传、前缀隔离
- WebDAV 双向：拉缺失的书，推本地有、远端没有的书
- Reader Metadata Sync：阅读进度、书签和笔记单独走 `universal-reader-sync.json`，与书籍文件同步分开

## Assumptions

1. 去重按文件哈希，不按文件名。
2. 监视不删除书架上的书。
3. WebDAV 仍只用已配置的 http(s) URL。
4. 封面缺失就继续用颜色块。
5. 本地文件夹同步不覆盖不同内容的同名文件。
6. S3 使用 AWS Signature V4；默认 path-style，兼容 AWS、MinIO 和常见 S3 实现。
7. S3 的 access key / secret key 只从设置或服务端环境变量读取，不写入日志。
8. Metadata 以 `content_hash` 对齐文档；进度取 `last_opened_ms` 最新的一份，时间相同才取更大的进度。
9. 批注按稳定 ID 合并；删除批注写入墓碑，旧批注不会在下一台设备同步时复活。
10. 远端有、本机还没有对应书的 metadata 会原样保留，导入那本书后下次同步自动接上。
11. `universal-reader-sync.json` 是保留文件名，文件夹、WebDAV 和 S3 的书籍文件同步会忽略它，不能把它当 TXT 导入。

## Metadata Sync API

| 方法 | 路径 | 作用 |
| --- | --- | --- |
| `POST` | `/v1/library/metadata/folder/sync` | 合并文件夹中的 Reader Metadata |
| `POST` | `/v1/library/metadata/webdav/sync` | 合并 WebDAV 中的 Reader Metadata |
| `POST` | `/v1/library/metadata/s3/sync` | 合并 S3 兼容存储中的 Reader Metadata |

响应包含 `remote_found`、`documents`、`progress_updated`、`annotations_updated` 和 `unmatched_remote`。Metadata 文件限制 16 MiB；损坏或未知版本不会被当成空文件覆盖。

## Commands

```powershell
cd rust
cargo test --workspace
```
