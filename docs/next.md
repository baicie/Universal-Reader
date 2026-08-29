# Spec: 重排书键盘与进度

## Objective

在 Windows 等桌面环境读完一本 EPUB：方向键翻页，进度条落到当前页，而不是只跳到某一章的开头。书末再翻不换书。损坏文件仍是损坏。

成功标准：

- 打开长章后按右方向键，出现下一页标记，仍看不到下一章。
- 把进度拖到后半本，出现下一章正文，不是另一本书。
- 点按翻页仍然可用。TXT 不抢方向键。

## Assumptions

1. 不引入完整 foliate-js npm，也不引入 `flutter_rust_bridge`。
2. 进度按「章内页」映射：`chapterIndex + pageIndex/pageCount`。
3. 右/PageDown 下一页，左/PageUp 上一页。
4. 不发版，除非另说。

请直接纠正以上假设，否则按它们实现。

## Commands

```powershell
cd app
flutter test test/reflow_nav_test.dart test/widget_test.dart
flutter analyze
```

## Project Structure

```text
docs/next.md
docs/epub-reader.md
app/lib/core/reflow_nav.dart
app/lib/features/reader/reader_page.dart
```

## Code Style

```dart
int reflowChapterIndexForProgress(double progress, int chapterCount);
int reflowPageIndexForProgress({...});
```

UI 放 `features/reader/`。

## Testing Strategy

- 先失败：方向键不翻页；进度条只打开章节第一页。
- 单元：0.25 落在第 1 章后半页；0.9 落在第 2 章。
- Widget：右方向键看到下一页；拖进度看到下一章。

## Boundaries

- Always: 损坏如实披露；键盘和进度只作用于当前这本书。
- Ask first: 完整 foliate-js npm。
- Never: 用样章或另一本书填补缺失。
