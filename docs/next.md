# Spec: foliate-js 第一刀（章 HTML + 本地 paginator）

## Objective

现在 EPUB 能翻页、能拖进度，但 WebView 只把抽出的纯文本页塞进 `#chapter`。图没了，章内 CSS 没了，分页也不跟窗口走。

这一刀让 host **用本地 vendor 的 `paginator.js` 排当前章 HTML**，而不是再灌整个 foliate-js npm / `view.js` / `epub.js`。Dart 仍然解析 EPUB、仍然按字符页翻页和写进度；测试环境仍然不加载真 WebView。

成功标准：

- 带 `<img>` 和 class 的最小 EPUB，打开命令里的 HTML 仍是标签，并把图变成 `data:`，不是 `&lt;img`，也不是另一本书的图。
- 缺失的图片保持缺失，不拿封面或样章补。
- `host.html` 从本地 `./paginator.js` 建 `foliate-paginator`；源码不含 jsDelivr / unpkg。
- 现有点按 / 方向键 / 进度 / 字号测试继续绿。损坏 EPUB 仍是损坏。

## Assumptions

1. 只 vendor `paginator.js`（MIT）和它的 LICENSE。不引入 `view.js`、`epub.js`、`zip.js`、`reader.html`，也不引入 CDN。
2. 业务代码仍只发 `FoliateBridge` 打开命令。UI 不点名 `FoliateView` / `foliate-paginator`。
3. 打开命令的 `html` 是**当前章标记**（含图和 class），不是 1800 字切片的 `<p>转义文本</p>`。测试 fallback 仍显示当前页纯文本。
4. 真机 host 用 blob URL 把这一章交给 paginator；Dart 的 `pageIndex` / `pageCount` 仍作锚点，直到下一刀用视口页数替换字符分页。
5. 不引入 `flutter_rust_bridge`。不发版，除非另说。

请直接纠正以上假设，否则按它们实现。

## Commands

```powershell
cd app
flutter test test/epub_document_test.dart test/foliate_bridge_test.dart test/foliate_session_test.dart test/widget_test.dart
flutter analyze
```

## Project Structure

```text
docs/next.md
docs/epub-reader.md
docs/reader-engines.md
app/assets/reader/foliate/host.html
app/assets/reader/foliate/paginator.js
app/lib/core/epub_document.dart
app/lib/core/foliate_bridge.dart
app/lib/core/foliate_session.dart
app/test/support/epub_fixture.dart
```

## Code Style

```dart
FoliateBridge.openSession(session); // html 含 <img> / class，不含 FoliateView
```

```html
<script type="module">
  import './paginator.js';
</script>
```

UI 仍在 `features/reader/`。资源改写在 `core/`。

## Testing Strategy

- 先失败：章 HTML 丢掉 img；host 仍是 `innerHTML` 纯文本、没有本地 paginator。
- 单元：带图 EPUB → `currentChapterHtml` 含 `data:image/png` 和原 class；缺图文件则 src 仍指向缺失路径。
- 桥：host 源码 import `./paginator.js`、出现 `foliate-paginator`、无 CDN。
- 回归：点按、方向键、进度条、损坏 EPUB。

## Boundaries

- Always: 损坏如实披露；测试不加载真 WebView；缺资源就是缺。
- Ask first: 其余 foliate-js 模块（`view.js` / `epub.js` / overlayer / 搜索）、用 host 视口页数替换 Dart 字符分页、字体文件。
- Never: jsDelivr / unpkg；一次灌进整个 npm；`flutter_rust_bridge`；用样章或另一本书填补缺失。
