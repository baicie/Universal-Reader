# Spec: 阅读排版进 Foliate host

## Objective

阅读设置里的行距、正文字体、纸张（跟随应用 / 浅色 / 夜间）到达 Foliate host 和文本回退层。字号已经进 host；这一刀把正文排版补齐。不引入完整 foliate-js npm。

成功标准：

- 打开命令带 `fontSize`、`lineHeight`、`fontFamily`、`background`、`color`。host 用它们排正文，不请求 CDN。
- 阅读设置可改行距、衬线/无衬线/等宽、纸张；本机记住。
- 纸张选「浅色」时，应用是深色也不把书页改成夜间；选「跟随应用」时跟 `Theme.brightness`。
- 文本回退层（无 WebView 的测试和损坏回退）用同一套字号、行距、字体和墨色。PDF / 漫画页不套这套排版。
- 未知的已存字体或纸张回到默认（衬线、跟随应用），不编一本别的书。

## Assumptions

1. 三种字体只映射到 CSS / Flutter 族名，不打包网页字体、不上完整 foliate-js 主题。
2. 纸张颜色沿用现有阅读页：浅色 `#F5F0E8` / `#2A2620`，夜间 `#1C1B18` / `#E8E2D6`。
3. 行距 1.4–2.2，默认 1.7；字号范围不变。
4. 不引入 `flutter_rust_bridge`。不发新版本，除非另说。

请直接纠正以上假设，否则按它们实现。

## Commands

```powershell
cd app
flutter gen-l10n
flutter test test/reader_prefs_test.dart test/reading_surface_test.dart test/foliate_bridge_test.dart test/foliate_session_test.dart test/widget_test.dart
flutter analyze
```

## Project Structure

```text
docs/next.md
app/lib/core/reader_prefs.dart
app/lib/core/reading_surface.dart
app/lib/core/foliate_bridge.dart
app/assets/reader/foliate/host.html
app/lib/features/reader/reading_settings_sheet.dart
app/lib/features/reader/reader_page.dart
app/lib/features/reader/renderers/isolated_foliate_view.dart
app/lib/l10n/app_zh.arb
app/lib/l10n/app_en.arb
```

## Code Style

打开命令由 Dart 算出 CSS 值，host 只应用，不猜主题：

```dart
FoliateBridge.openSession(
  session,
  typography: surface.toFoliateCommand(),
);
```

新 UI 放 `features/reader/`，不把设置面板继续堆进 `reader_page.dart`。文案走 l10n。

## Testing Strategy

- 先失败：打开命令缺行距/字体/纸色；host 不含 `command.lineHeight`；prefs 不恢复行距。
- `ReadingSurface.resolve`：跟随应用 + 深色 → 夜间纸色；强制浅色 + 深色应用 → 仍浅色。
- Widget：阅读设置里能看到行距、字体、纸张。
- 不在 CI 开真实 WebView。

## Boundaries

- Always: 缺排版字段用默认值；PDF/漫画不套重排样式。
- Ask first: 完整 foliate-js npm 分页主题、自定义网页字体。
- Never: 用另一本书的样式顶上；host 拉 CDN。
