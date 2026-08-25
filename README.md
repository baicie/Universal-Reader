# Universal Reader

Universal Reader 的首版可运行 Web MVP，依据 `index.md` 的 Phase 0 设计实现了 Local-first Library 体验。

## 运行

这是一个零依赖静态应用，直接打开 `index.html` 即可运行。也可以在项目目录启动任意静态文件服务器，例如：

```powershell
python -m http.server 8080
```

然后访问 `http://localhost:8080`。

## 当前实现

- Library 首页：全部、最近阅读、正在阅读、收藏
- 可重排、固定版式、漫画格式筛选
- 书名、作者、格式搜索
- 最近添加、标题、进度排序
- 网格/列表视图切换
- 本地文件选择与导入反馈
- 响应式桌面/移动布局
- 预留后续 Flutter `Reader Runtime`、`DocumentAdapter`、`Locator` 的产品边界

## Rust 后端服务

`rust/crates/reader-server` 是随应用发布的本地 Rust HTTP 服务基座。它默认只监听 `127.0.0.1:8787`，不暴露公网接口，当前提供健康检查与文档格式检测；SQLite、索引和文件扫描将在该服务边界内逐步加入。

```powershell
cd rust
cargo run --release --package universal-reader-server
```

可访问 `http://127.0.0.1:8787/health`，或请求 `http://127.0.0.1:8787/v1/formats/book.epub`。使用环境变量 `UNIVERSAL_READER_SERVER_PORT` 可修改监听端口。

## 后续工程化

Flutter UI 保持在 `app/`，Rust 后端服务保持在 `rust/`。后续可通过 `flutter_rust_bridge` 或本地 HTTP 客户端将服务能力接入现有 repository 接口，同时将格式检测、SQLite、索引和文件扫描下沉到 Rust。
