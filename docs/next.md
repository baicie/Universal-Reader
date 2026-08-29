# Spec: 下一步（读完之后能标、能定位）

## Objective

引擎、单机 SQLite、笔记高亮和书库同步已经能用。下一步把阅读协议补全到「能划、能标、能回到原处」，而不是再铺新格式。

目标用户：正在读一本书，想自己划一段、写一句、下次还能跳回去的人。不是要账号、商城或自动摘要整库的人。

成功标准：

- 在当前章/页里选一段文字，确认后写成该书笔记，quote 就是选区。
- 该书已有书签列表，点击跳到对应 locator，需走现有 `goTo`。
- Foliate 宿主换成可测的 foliate-js 会话（至少：打开章、CFI 进度、选区回传）；测试环境仍不加载真 WebView。
- 书目列表仍可用；这一步不把 `catalog.json` 废掉，除非下面假设被纠正。

## Assumptions

1. 这一步 **不** 引入 `flutter_rust_bridge`，继续 HTTP。
2. 这一步 **不** 做账号、云同步、DRM、OCR、PDF 墨迹编辑。
3. 用户划线是新笔记来源；助手「保存为笔记」保持原样。
4. Linux WebView 仍是 Tier 2：做得出就做，测不过就维持文本层。
5. 复杂压缩 PDF、RAR CBR、完整 PalmDOC MOBI 仍后置。
6. 书目真相暂时仍是 `catalog.json`；SQLite 继续做 FTS / 笔记。

请直接纠正以上假设，否则按它们实现。

## Commands

```powershell
cd app
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

```powershell
cd rust
cargo test --workspace
cargo clippy --workspace --all-targets -- -D warnings
cargo fmt --all -- --check
```

## Project Structure

```text
docs/next.md                         本规格
docs/annotations.md                  选区写入笔记
docs/reader-engines.md               foliate-js 会话
app/lib/core/annotated_text.dart     已有 quote 高亮
app/lib/features/reader/             选区、书签 chrome
app/lib/features/library/annotation_store.dart
```

## Boundaries

- Always: 缺选区就不写笔记；跳转仍要用户点；损坏不回退样章；UI 文案走 l10n。
- Ask first: catalog 迁 SQLite、`flutter_rust_bridge`、公网鉴权。
- Never: Agent 自己划线或写书签；破解 DRM。

## Open Questions

1. 下一步优先「选区+书签」，还是先把 foliate-js 换成真正分页？
2. 书签是否单独一张表，还是复用 annotations 且 `source=bookmark`？
