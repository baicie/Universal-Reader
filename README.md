# Universal Reader

Universal Reader 是一个 Local-first、跨平台的阅读应用，设计方案见 `index.md`。

## Flutter 应用

应用代码位于 `app/`，支持 Library、Reader 和 Settings 等基础流程。

```powershell
cd app
flutter pub get
flutter run -d chrome
```

验证构建：

```powershell
cd app
flutter analyze
flutter test
flutter build web --release
flutter build windows --release
```

Release 包按“通用包 + 架构包”提供下载：Android 提供通用 APK 和 arm64-v8a、armeabi-v7a、x86_64 架构 APK；Windows 提供通用 ZIP、x86_64 ZIP 和 x86_64 `.exe` 安装包；Linux 提供通用包和 x86_64 包；macOS 提供 Universal、arm64、x86_64 三种 `.dmg` 安装包，并保留对应 `.tar.gz` 包。服务器部署还可下载 `web-server` 合包（Linux `.tar.gz` / Windows `.zip`），内含 Rust 服务与 Flutter Web 静态资源。

## 当前实现

- Flutter Material 3 响应式界面
- Library 搜索、格式筛选、排序、网格/列表视图和阅读进度
- Reader Runtime、文档适配器与定位器契约
- EPUB、PDF、MOBI、AZW3、FB2、TXT、Markdown、HTML、CBZ、CBR 格式检测
- 本地文件导入
- 阅读器目录、进度、主题和移动端交互
- 界面默认中文，可在设置中切换 English 或跟随系统
- TXT / Markdown / HTML 可阅读原文件（EPUB/PDF 等仍提示尚未接入）

## Rust 后端服务

`rust/crates/reader-server` 是随应用发布的本地 Rust HTTP 服务基座。它默认只监听 `127.0.0.1:8787`，不暴露公网接口，当前提供健康检查、文档格式检测、本机书库网盘，以及可选的 Flutter Web 静态资源托管。Flutter 在服务可达时通过 HTTP 读写该书库；SQLite、索引和文件扫描将在该服务边界内逐步加入。

```powershell
cd rust
cargo run --release --package universal-reader-server
```

可访问 `http://127.0.0.1:8787/health`，或请求 `http://127.0.0.1:8787/v1/formats/book.epub`。使用环境变量 `UNIVERSAL_READER_SERVER_PORT` 可修改监听端口。

### 与 Web 一起部署

Release 中的 `universal-reader-<tag>-web-server-linux-x86_64.tar.gz`（以及对应的 Windows zip）解压后包含：

- `universal-reader-server`（Windows 为 `universal-reader-server.exe`）
- `web/`（Flutter `build web --release` 产物，`index.html` 位于该目录根下）

服务会按以下顺序查找 Web 资源：环境变量 `UNIVERSAL_READER_WEB_DIR`、可执行文件旁的 `web/`、当前工作目录下的 `web/`。找到 `index.html` 后，浏览器访问根路径即可打开界面；`/health` 与 `/v1/*` 仍走 API。书库按本机网盘存放在 `data/library/files`（可用 `UNIVERSAL_READER_STORAGE_DIR` 改路径），设计见 `docs/library-store.md`。

在服务器上对外提供访问时：

```bash
export UNIVERSAL_READER_SERVER_BIND=0.0.0.0
export UNIVERSAL_READER_SERVER_PORT=8787
# 可选：UNIVERSAL_READER_STORAGE_DIR=/var/lib/universal-reader
./universal-reader-server
```

然后打开 `http://服务器地址:8787/`。默认绑定仍是 `127.0.0.1`；只有在你信任的网络上才应改为 `0.0.0.0`。

本地联调也可以先构建 Web，再让服务托管：

```powershell
cd app
flutter build web --release
cd ..\rust
$env:UNIVERSAL_READER_WEB_DIR = "..\app\build\web"
cargo run --release --package universal-reader-server
```

## 后续工程化

Flutter UI 保持在 `app/`，Rust 后端服务保持在 `rust/`。服务可达时，书架已通过本地 HTTP 接入现有 repository 接口。后续可将 EPUB/PDF 引擎、SQLite/FTS5 和文件扫描继续下沉到 Rust。
