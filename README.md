# Universal Reader

Universal Reader 是一个 Local-first 阅读应用。手机端在 `mobile/` 使用 Expo / React Native；桌面端保留 `app/` 中的 Flutter 与 `rust/` 中的 Rust 服务。整体设计见 [index.md](index.md)，手机端规格见 [docs/rn-reader.md](docs/rn-reader.md)。

## 当前路线与下载

| 范围 | 当前实现与发布方式 |
| --- | --- |
| Android / iOS 手机端 | Expo / React Native。当前 `Release` 工作流通过 EAS 的 `preview` profile 构建 Android APK；iOS 尚未纳入自动发布 |
| Windows / macOS / Linux 桌面端 | Flutter + Rust，本地开发和手动构建继续可用 |
| Web | Expo Web 用于手机端开发验证；已有 Flutter Web 可由 Rust 服务托管 |

已发布的包按各自版本下载：

- [v0.1.0-test](https://github.com/baicie/Universal-Reader/releases/tag/v0.1.0-test)：2026-10-06 发布的 Expo Android 测试 APK。
- [v1.0.0-rc.1](https://github.com/baicie/Universal-Reader/releases/tag/v1.0.0-rc.1)：2026-09-16 发布的 Flutter 多平台 RC，保留 Android 架构 APK、桌面安装包及 `web-server` 合包。

旧 RC 的多平台产物与 Flutter 门禁属于该版本；当前 CI 检查 Expo 手机工程与 Rust，当前 Release 不再重建 Flutter 全平台产物。发布要求及已知限制见 [发布清单](docs/release-candidate.md)。

## 手机端开发

需要 Node.js 22 和 npm。从仓库根目录执行：

```powershell
cd mobile
npm ci
npm start
```

开发时可运行 `npm run android`、`npm run ios` 或 `npm run web`。iOS 本地原生构建需要 macOS / Xcode；正式验收应安装对应平台的实际构建包，记录设备与构建版本。

手机端代码提供书架搜索、分组、排序、封面、本地 SQLite 存储、目录与进度、阅读设置、书签笔记，以及 WebDAV / S3 书籍和阅读进度同步。阅读助手使用用户配置的 OpenAI 兼容接口，可对当前章节、PDF 当前页或本书检索结果提问，回答可保存为笔记，跳转须由用户确认。

| 格式 | Expo 当前范围 |
| --- | --- |
| TXT / Markdown / HTML / EPUB / PDF / FB2 / RTF / DOCX / ODT | 有解析与阅读路径；原生文件导入、渲染及位置恢复仍需按设备验收 |
| MOBI / AZW3 | 优先读取内嵌 EPUB，否则提取可读文本片段；完整格式兼容性有限 |
| CBZ / CBT | ZIP / TAR 漫画路径，支持单页、双页、竖滑和从右到左 |
| CHM | Web / Node / 原生入口共用纯 TypeScript 解析路径；原生样本测试通过，设备上的导入与阅读待验收 |
| CBR / CB7 / DjVu | 使用 WASM 解码；运行环境没有 WebAssembly 时明确提示尚不支持，设备上的实际解码与页面显示待验收 |

上述代码覆盖范围不等于真机验收完成。Node 测试、Metro 导出和 Flutter 原生冒烟均不能替代 Expo 真机验证；执行并记录 [Expo 手机端验收清单](docs/expo-device-smoke.md)。

Node 回归包含缺少 Web Crypto 时的书籍内容哈希与 S3 签名检查，用于覆盖 Hermes 的平台限制；实际文件导入、入库及同步仍需在目标构建上验证。

本地检查与 CI 一致：

```powershell
cd mobile
npm run typecheck
npm run lint -- --max-warnings=0
npm test
npx expo export --platform android --platform ios --output-dir dist/native
```

## Flutter 桌面端

Flutter 工程保留原有 Library、Reader、Settings、阅读助手和 Rust 服务集成。阅读器支持可重排文档、PDF 与多种漫画容器；CHM 转 EPUB、DjVu 转 CBZ 可由 Rust 服务完成。`app/` 的 Android / iOS FFI 转换和对应冒烟属于 Flutter 客户端，不代表 Expo 具备相同能力。

```powershell
cd app
flutter pub get
flutter run -d windows
```

在对应宿主上可使用 `flutter run -d macos`、`flutter run -d linux` 或 `flutter run -d chrome`。手动验证和构建：

```powershell
cd app
flutter analyze
flutter test
flutter build windows --release
flutter build web --release
```

macOS / Linux 桌面包分别在相应宿主运行 `flutter build macos --release` / `flutter build linux --release`。这些命令不属于当前 Expo Release 自动产物矩阵。

Flutter 阅读助手默认关闭，可在设置中选择 DeepSeek 或 Ollama，密钥在本机设置中填写；Ollama 默认使用 `http://127.0.0.1:11434`。走 Rust 服务时，客户端经 `POST /v1/ai/chat` 转发，请求与问答保存在本机书库。服务端可从 `UNIVERSAL_READER_DEEPSEEK_API_KEY` 读取密钥。不要将密钥放入 Web 产物的 `--dart-define`。

## Rust 后端服务

`rust/crates/reader-server` 默认监听 `127.0.0.1:8787`，提供健康检查、格式检测、SQLite 书库、全文搜索、文件夹扫描与监视、双向 WebDAV / S3 同步、Reader Metadata Sync、哈希去重和封面，以及可选的 Flutter Web 静态资源托管。Flutter 在服务可达时通过 HTTP 读写书库，桌面离线时使用本机 SQLite。Expo 当前直接处理本地文件及 WebDAV / S3，不依赖这套 HTTP 服务。

```powershell
cd rust
cargo run --release --package universal-reader-server
```

可访问 `http://127.0.0.1:8787/health`，或请求 `http://127.0.0.1:8787/v1/formats/book.epub`。使用环境变量 `UNIVERSAL_READER_SERVER_PORT` 修改端口。设计见 [书库存储](docs/library-store.md)。Rust 本地检查：

```powershell
cd rust
cargo fmt --all -- --check
cargo test --all
```

### 托管已有 Flutter Web

旧 RC 中的 `web-server` 合包包含 Rust 服务可执行文件与 `web/` 静态资源；解压后可启动服务。服务依次查找 `UNIVERSAL_READER_WEB_DIR`、可执行文件旁的 `web/`、当前目录下的 `web/`，找到 `index.html` 后访问根路径即可打开界面，`/health` 与 `/v1/*` 继续提供 API。

本地联调也可以自行构建：

```powershell
cd app
flutter build web --release
cd ..\rust
$env:UNIVERSAL_READER_WEB_DIR = "..\app\build\web"
cargo run --release --package universal-reader-server
```

书库默认存放于 `data/library/files`，可用 `UNIVERSAL_READER_STORAGE_DIR` 修改路径。对可信网络开放服务时可设置 `UNIVERSAL_READER_SERVER_BIND=0.0.0.0`；默认仍只监听本机。

## 验证范围

- [CI](.github/workflows/ci.yml)：手机端类型检查、零警告 lint、Node 测试和 Android / iOS Metro 导出；Rust 格式检查与工作区测试。
- [Release](.github/workflows/release.yml)：从指定标签通过 EAS 构建 Expo Android APK，验证构建身份与 APK 后发布 APK 和 SHA-256，所需配置见 [发布清单](docs/release-candidate.md)。
- [Native smoke](.github/workflows/native-smoke.yml) 与 [Physical device smoke](docs/physical-device-smoke.md)：保留的 Flutter CHM / DjVu 原生转换验证。
- [test-books](test-books/README.md)：各格式的最小与边界样本，以及 SHA-256 清单。最小压缩包样本用于解码行为测试，页面显示验收另需可解码的真实图片。
