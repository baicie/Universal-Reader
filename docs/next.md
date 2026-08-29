# Spec: 选区、书签与 foliate-js 会话

## Objective

读完之后能标、能定位：

- 在当前章/页选一段文字，确认后写成该书笔记，quote 就是选区；空选区不写。
- 该书有书签列表，点击走现有 `goTo`。书签 API 独立，存储复用 annotations 且 `source=bookmark`。
- Foliate 换成可测会话：分页、CFI 进度、选区回传。测试环境不加载真 WebView。

## Assumptions

1. 不引入 `flutter_rust_bridge`。
2. 不做账号、云同步、DRM、OCR、PDF 墨迹。
3. 用户划线 `source=user`；助手保存笔记保持原样；书签 `source=bookmark`。
4. Linux WebView 仍是 Tier 2。
5. `catalog.json` 仍是服务端书目真相。

## Commands

```powershell
cd app
flutter test test/reader_selection_test.dart test/bookmark_store_test.dart test/foliate_session_test.dart test/widget_test.dart
flutter analyze
```

## Boundaries

- Always: 缺选区不写笔记；跳转仍走 `goTo`；UI 文案走 l10n。
- Ask first: catalog 迁 SQLite、完整上游 foliate-js npm 包。
- Never: Agent 自己划线或写书签。
