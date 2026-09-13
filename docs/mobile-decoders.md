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

尚未接入 Flutter 运行时绑定：当前 App 仍优先使用本机服务；把 XCFramework / `.so` 链接进 iOS Runner、Android APK 并通过 Dart FFI 调用排在 `Hardening E`。
