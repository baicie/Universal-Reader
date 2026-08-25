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

Release 包按“通用包 + 架构包”提供下载：Android 提供通用 APK 和 arm64-v8a、armeabi-v7a、x86_64 架构 APK；Windows 提供通用 ZIP、x86_64 ZIP 和 x86_64 `.exe` 安装包；Linux 提供通用包和 x86_64 包；macOS 提供 Universal、arm64、x86_64 三种 `.dmg` 安装包，并保留对应 `.tar.gz` 包。

## 当前实现

- Flutter Material 3 响应式界面
- Library 搜索、格式筛选、排序、网格/列表视图和阅读进度
- Reader Runtime、文档适配器与定位器契约
- EPUB、PDF、MOBI、AZW3、FB2、TXT、Markdown、HTML、CBZ、CBR 格式检测
- 本地文件导入
- 阅读器目录、进度、主题和移动端交互

## Rust 后端服务

`rust/crates/reader-server` 是随应用发布的本地 Rust HTTP 服务基座。它默认只监听 `127.0.0.1:8787`，不暴露公网接口，当前提供健康检查与文档格式检测；SQLite、索引和文件扫描将在该服务边界内逐步加入。

```powershell
cd rust
cargo run --release --package universal-reader-server
```

可访问 `http://127.0.0.1:8787/health`，或请求 `http://127.0.0.1:8787/v1/formats/book.epub`。使用环境变量 `UNIVERSAL_READER_SERVER_PORT` 可修改监听端口。

## 后续工程化

Flutter UI 保持在 `app/`，Rust 后端服务保持在 `rust/`。后续可通过 `flutter_rust_bridge` 或本地 HTTP 客户端将服务能力接入现有 repository 接口，同时将格式检测、SQLite、索引和文件扫描下沉到 Rust。
