# Spec: 去重、封面、监视与双向同步

## Objective

服务端书库支持：

- 按内容 SHA-256 去重
- 从 EPUB/FB2 抽封面，写入 `covers/`。FB2 只跟 `title-info` coverpage 的图片 href，不靠 binary id 是否含 `cover`。
- 监视已配置文件夹，新文件只追加
- 本地文件夹双向同步：拉缺失的书，推本地有、文件夹没有的书
- WebDAV 双向：拉缺失的书，推本地有、远端没有的书

## Assumptions

1. 去重按文件哈希，不按文件名。
2. 监视不删除书架上的书。
3. WebDAV 仍只用已配置的 http(s) URL。
4. 封面缺失就继续用颜色块。
5. 本地文件夹同步不覆盖不同内容的同名文件。

## Commands

```powershell
cd rust
cargo test --workspace
```
