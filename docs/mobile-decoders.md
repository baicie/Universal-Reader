# Spec: Mobile CHM and DjVu decoder audit

## Objective

确认 iOS / Android 在没有本机 Rust HTTP 服务时，是否可以把 CHM、DjVu 转换进进程内，并给出不破坏现有 Reader Runtime 契约的实现路径。

当前行为：移动端保留文件并明确显示不可读，不伪造样章；桌面服务可用时转换为 EPUB / CBZ。

## Existing reusable core

服务端已有两条转换路径：

- CHM：`libchm` 解包并组装 EPUB。
- DjVu：`djvu-rs` 渲染页面并组装 CBZ。

两者输出都进入现有 `EpubReaderDocument` / `ComicReaderDocument`，不需要改 Reader UI 或 Locator API。

## Options

| 方案 | 优点 | 风险 |
| --- | --- | --- |
| Dart 纯重写 | 无原生打包 | CHM/DjVu 复杂度高，重复实现风险大 |
| 平台插件分别写 Kotlin/Swift | 贴近系统能力 | 两套解码器、两套测试，长期维护成本高 |
| 共享 Rust 静态库 + C ABI | 复用已验证转换代码，iOS/Android 同一套逻辑 | 需要移动构建链、代码签名和产物管理 |
| `flutter_rust_bridge` | 生成桥接代码 | 与当前项目“不引入该依赖”的约束冲突 |

## Implemented architecture

采用 **共享 Rust 转换核心 + 最小 C ABI**：

- `reader-format-native` 是 CHM/DjVu 的唯一实现，服务端和移动端共用。
- `reader-mobile` 暴露 CHM -> EPUB、DjVu -> CBZ 两个稳定函数；不支持流式/增量回调。
- C ABI 使用 `UrBytes { data, len, capacity }`，成功结果必须用 `ur_bytes_free` 释放。
- 输入上限 64 MiB；错误码区分参数错误、损坏输入和内部错误。
- 输入、输出都设置内存上限；转换失败返回明确错误码，不创建空书。
- iOS 构建静态 XCFramework，Android 按 ABI 构建 `.so`。
- 每次平台构建同时运行最小 CHM/DjVu fixture，防止只有服务端路径通过。

不引入 `flutter_rust_bridge`。C ABI 只承载转换函数，不暴露 Reader/Database 对象图。

## C ABI

头文件：`rust/crates/reader-mobile/include/universal_reader_native.h`

```c
uint32_t ur_native_api_version(void);

int32_t ur_chm_to_epub(
    const uint8_t* file_name_ptr,
    size_t file_name_len,
    const uint8_t* input_ptr,
    size_t input_len,
    UrBytes* output);

int32_t ur_djvu_to_cbz(
    const uint8_t* input_ptr,
    size_t input_len,
    UrBytes* output);

void ur_bytes_free(UrBytes bytes);
```

错误码：

- `0`：成功
- `1`：参数错误
- `2`：损坏或不支持的输入
- `3`：内部错误

## Build

Android（需要 Android NDK 和 `cargo-ndk`）：

```powershell
cd rust
.\tool\build-mobile-android.ps1
```

输出：`rust/target/android/jniLibs/{arm64-v8a,armeabi-v7a,x86_64}/libuniversal_reader_native.so`。

iOS（需要 macOS 和 Xcode）：

```bash
cd rust
bash tool/build-mobile-ios.sh
```

输出：`rust/target/ios/UniversalReaderNative.xcframework`。

## License review

| Crate | License | Repository |
| --- | --- | --- |
| `libchm` | MIT | `https://github.com/trypsynth/libchm` |
| `djvu-rs` | MIT | `https://github.com/matyushkin/djvu-rs` |
| `tempfile` | MIT OR Apache-2.0 | `https://github.com/Stebalien/tempfile` |
| `zip` | MIT | `https://github.com/zip-rs/zip2.git` |

发布产物仍须带上这些许可证文本；许可证元数据由 `cargo metadata` 审查。

## Release gate

进入正式移动发布前必须满足：

- Android arm64-v8a、armeabi-v7a、x86_64 与 iOS device：能解析最小 CHM、DjVu。
- 损坏输入返回 `corrupt`，不是崩溃或空书。
- 单个输入输出有明确内存上限。
- 第三方解码器许可证完成审查并在 About / NOTICE 中列出。
- App 体积增量逐 ABI 可见，不能靠隐藏全量二进制。

## Decision

Hardening D 已完成共享核心、C ABI、Android ABI 产物、iOS XCFramework、fixture/损坏输入测试、产物大小报告和许可证审查。

Android `.so` 会通过 Gradle `jniLibs` 进入 APK；iOS 由 XCFramework 的 device / simulator 静态库 `-force_load` 进 Runner，并导出 C ABI 符号供 `DynamicLibrary.process()` 查找。Dart 侧使用条件 FFI：移动端加载原生库，Web 和库缺失时安全回退为 `UnavailableReaderDocument`。CI 会检查三套 Android APK 内的 `.so` 和 iOS Runner 内的核心符号。

App 打开 CHM/DjVu 时会先尝试原生转换，再复用现有 `EpubReaderDocument` / `ComicReaderDocument`；同步 `openReaderDocument` 路径仍不会转换。

Dart 在查找转换符号前会调用 `ur_native_api_version()`。当前支持版本为 `1`，Dart 常量、Rust 常量和 C 头宏由单元测试保持一致；版本不匹配时 App 会安全回退而不会调用不兼容 ABI。

## 设备侧 smoke 验证

`app/integration_test/native_format_converter_smoke_test.dart` 会在真实 Android / iOS 运行环境中加载原生库，使用固定 SHA-256 的 `test-books` 样本完成 CHM -> EPUB 和 DjVu -> CBZ 转换，并断言结果可被现有阅读器打开。

独立的 `Native smoke` workflow 每天运行一次，也可手动触发：`Android native smoke` 使用 x86_64 Android 模拟器，`iOS native smoke` 使用 macOS Runner 上的 iOS Simulator。两者覆盖动态库加载、C ABI 调用和 Dart 阅读器接线。主 CI 继续验证原生构建、APK/XCFramework 打包和符号链接，不承担模拟器启动波动。

真机运行和签名包安装属于可选扩展验证，不属于当前 v1.0 发布门禁；需要时可使用 `app/tool/physical_smoke.dart` 及手动 `Physical device smoke` workflow，步骤见 `docs/physical-device-smoke.md`。
