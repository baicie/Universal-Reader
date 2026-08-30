# Spec: FB2 表题的 style 属性抄到 class

> 上一刀已落地（节 `<title style>` 抄到章首 h1 class），未提交。Ask first：`view.js` / NCX 嵌套 / 应用内打开外链 / `overlayer.js` / 去掉 `<iframe>`。

## Objective

节标题的 `style` 已经抄到 `<h1>`。表格 `<title style="…">` 仍丢掉 name，caption 没有 class。这一刀：有 name 的表题 `style` 抄到该 `<caption>` 的 class。不发明 class。不加载 stylesheet。不 vendor `view.js`。不改 EPUB。

成功标准：

- `<table><title style="foreign"><p>Rates</p></title>…` 的章 HTML 含 `<caption class="foreign">Rates</caption>`。
- 空 style 不抄；空表题仍不编 caption。
- stylesheet 里的 CSS 仍不进章 HTML。

## Assumptions

1. 只处理 `_fb2TableHtml` 里表 `<title>` 上的 `style` 属性，值抄到 `<caption>`。格子 style 上一刀已做。
2. 测试用 fixture，不加载真实 WebView。
3. 不引入 `view.js` / `overlayer.js` / `flutter_rust_bridge`。不发版，除非另说。

请直接纠正以上假设，否则按它们实现。

## Commands

```powershell
cd app
flutter test test/fb2_document_test.dart --name "table caption style"
flutter analyze
```

## Project Structure

```text
docs/next.md
app/lib/core/fb2_document.dart
app/test/fb2_document_test.dart
app/test/support/fb2_fixture.dart
```

## Code Style

```dart
final style = (child.getAttribute('style') ?? '').trim();
final classAttr = style.isEmpty ? '' : ' class="${_escapeAttr(style)}"';
if (inner.isNotEmpty) caption = '<caption$classAttr>$inner</caption>';
```

## Testing Strategy

- 先失败：caption HTML 没有 `class="foreign"`。
- 单元：有 style 抄到 class；空的不抄；空表题不编 caption。
- 回归：section title style、空 caption、格子 style。

## Boundaries

- Always: 缺 style 就是缺；不把另一本书的 class 补进来。
- Ask first: `view.js` / NCX 嵌套 / 应用内打开外链。
- Never: jsDelivr / unpkg；Agent 自己写笔记。
