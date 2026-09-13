# Spec: Reader Runtime API stability

## Objective

为 v1.0 建立可验证的公开契约，避免插件、同步和持久化代码依赖未版本化的私有细节。

当前基线：

- `readerRuntimeApiVersion = 1.0.0`
- `locatorSchemaVersion = 1`

## Frozen surface

公开契约位于：

- `app/lib/core/reader_runtime.dart`
- `app/lib/core/models.dart`
- `app/lib/core/locator_codec.dart`

覆盖：

- `ReaderDocument`
- `ChapteredDocument`
- `HtmlChapteredDocument`
- `DocumentRenderer`
- `DocumentAdapter`
- `DocumentRange`
- `TocItem`
- `SearchResult`
- `Locator` 及其四个公开子类

## Locator JSON v1

版本化 JSON 与旧的紧凑 `encodeLocator` 并存。旧格式继续用于已有笔记；新代码、插件和跨进程边界使用 JSON v1。

```json
{
  "version": 1,
  "kind": "epub",
  "href": "OEBPS/chapter.xhtml",
  "cfi": "/6/4",
  "progression": 0.42,
  "fragment": "note"
}
```

支持的 `kind`：

- `epub`
- `pdf`
- `comic`
- `text`

读取时未知版本、未知 kind、缺字段或非有限数值都返回 `null`，不能当成默认位置。

## Change policy

- v1 内允许新增可选字段、可选成员和新的适配器。
- 不删除、不改名、不改变已有字段含义或类型。
- 不把可空字段突然改成必填。
- 枚举新增值后，消费者必须保留兜底分支。
- 破坏契约需要提升 major version，并提供迁移期。

## Commands

```powershell
cd app
flutter test test/reader_api_contract_test.dart test/locator_codec_test.dart
```

## Boundaries

- Always: 持久化定位先写 schema version。
- Never: 把另一个格式的 locator 静默解释成当前格式。
