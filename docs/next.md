# Spec: 笔记管理与书内搜索

## Objective

读完之后管得了、找得到：

- 该书有笔记列表（用户划线 + 助手保存），点击走现有 `goTo`，可删。删笔记不影响问答记录。
- 书签可删；删书签不影响笔记。
- 当前书内搜索，命中走现有 `search` / `goTo`，不换书。
- 空搜索、空选区、解不出的 locator 都如实缺，不回退样章。

## Assumptions

1. 不引入 `flutter_rust_bridge`。
2. 不做账号、云同步、DRM、OCR、PDF 墨迹、导出笔记。
3. 删除走现有 annotations `save`（整表覆盖），不新开 HTTP 动词。
4. `catalog.json` 仍是服务端书目真相。
5. 找不到的 locator 不跳转，正文仍是这本书。

## Commands

```powershell
cd app
flutter test test/annotation_store_test.dart test/bookmark_store_test.dart test/reader_search_test.dart test/widget_test.dart
flutter analyze
```

## Boundaries

- Always: 按 `documentId` 隔离；UI 文案走 l10n。
- Ask first: catalog 迁 SQLite、完整上游 foliate-js npm、笔记导出。
- Never: Agent 自己删笔记或写书签。
