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

## Recommendation

采用 **共享 Rust 静态库 + 最小 C ABI**：

- 抽出现有 CHM/DjVu 转换模块，保持纯字节输入、纯字节输出。
- 暴露两个稳定函数：CHM -> EPUB、DjVu -> CBZ；不支持流式/增量回调。
- Dart 使用 `dart:ffi`，只在移动端解析失败且本机服务不可用时调用。
- 输入、输出都设置内存上限；转换失败返回明确错误码，不创建空书。
- iOS 使用静态 XCFramework，Android 按 ABI 打包 `.so`。
- 每次平台构建同时运行最小 CHM/DjVu fixture，防止只有服务端路径通过。

不引入 `flutter_rust_bridge`。C ABI 只承载转换函数，不暴露 Reader/Database 对象图。

## Release gate

进入正式移动发布前必须满足：

- Android arm64-v8a、armeabi-v7a、x86_64 与 iOS device：能解析最小 CHM、DjVu。
- 损坏输入返回 `corrupt`，不是崩溃或空书。
- 单个输入输出有明确内存上限。
- 第三方解码器许可证完成审查并在 About / NOTICE 中列出。
- App 体积增量逐 ABI 可见，不能靠隐藏全量二进制。

## Decision

审计结论：技术上可行，推荐 Rust 静态库路线。Hardening C 只完成方案与验收基线；实际移动二进制打包排在 `Hardening D`。
