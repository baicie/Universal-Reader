# Spec: notes/comments body 无 section 的块进对应目录组

> 上一刀已落地（无 section 的 FB2 正文 body 编成一章），未提交。Ask first：`view.js` / NCX 嵌套 / 应用内打开外链 / `overlayer.js` / 去掉 `<iframe>`。

## Objective

正文 body 没有 `<section>` 时已经能成章。`body name="notes"` / `comments` 若只有 `<p>` / `<poem>` / `<cite>`、没有 section，这些块仍被丢掉；只有 notes 的书仍是损坏。这一刀：有正文时，notes/comments 的无 section 块编成该组下的章；仍然只有 notes、没有任何正文时保持损坏。不发明注释。不 vendor `view.js`。不改 EPUB。

成功标准：

- 正文节 + `body name="notes"` 下直接 `<p>`（无 section）时，notes 组出现在目录末尾，点进去是该段，href 为下一个 `section-N`。
- `comments` 同样单独成组，不和 notes 合并。
- 只有 notes body、没有正文节，仍是 `corrupt fb2`。

## Assumptions

1. 只改 FB2 对无 section 的 notes/comments body 的扫描，不改已有 section 的分组。
2. 测试用 fixture，不加载真实 WebView。
3. 不引入 `view.js` / `overlayer.js` / `flutter_rust_bridge`。不发版，除非另说。

请直接纠正以上假设，否则按它们实现。

## Commands

```powershell
cd app
flutter test test/fb2_document_test.dart --name "notes body without a section"
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
if (name == 'notes' || name == 'comments') {
  emitChapter(body);
}
```

## Testing Strategy

- 先失败：正文 + notes body 只有 p 时没有 notes 组。
- 单元：notes 组成章；comments 单独；仅 notes 仍损坏。
- 回归：无 section 的正文 body、带 section 的 notes 组。

## Boundaries

- Always: 缺正文就是损坏；不把另一本书的注释补进来。
- Ask first: `view.js` / NCX 嵌套 / 应用内打开外链。
- Never: jsDelivr / unpkg；Agent 自己写笔记。
