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

## Adapter registry

`ReaderAdapterRegistry` 是实际打开路径，不再保留一套未使用的接口：

- 每个适配器声明自己支持的 `DocumentFormat`。
- `openReaderDocument` 与 `openReaderDocumentAsync` 都通过标准注册表。
- `DocumentSource.metadata` 是可选新增字段；传入时优先使用调用方元数据，未传入时由内容检测补全。
- 重复注册同一格式会立即抛错。
- 没有格式适配器时返回 `UnavailableReaderDocument`；适配器抛出 `FormatException` 时返回 `CorruptReaderDocument`。

标准注册表覆盖直接解析格式：TXT、Markdown、HTML、DOCX、ODT、RTF、EPUB、PDF、FB2、MOBI、AZW3、CBZ、CBR、CBT、CB7。CHM/DjVu 仍由服务端转换，不注册客户端解析器。

## Plugin contract v1

插件是 App 内进程内、只读的适配器扩展，不包含动态代码下载、插件市场或权限沙箱。插件清单冻结以下 JSON 字段：

```json
{
  "manifestVersion": 1,
  "id": "io.example.custom-format",
  "name": "Custom Format",
  "version": "1.0.0",
  "apiVersion": 1,
  "formats": ["rtf"]
}
```

`ReaderPluginHost` 在任何适配器进入打开路径前验证清单版本、宿主 API 版本、ID、语义版本、适配器 ID、格式冲突和声明能力。无效插件会被隔离并记录 `ReaderPluginIssue`，标准适配器和其他插件继续工作。

插件不能覆盖内置格式，不能声明未实际提供的格式，也不能复用已有适配器 ID。只有验证通过的适配器会进入新的 `ReaderAdapterRegistry`。

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
