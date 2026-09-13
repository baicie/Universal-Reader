# Spec: 10k library performance baseline

## Objective

v1.0 要求 Library 在 10,000 本书量级仍能加载、搜索、筛选、排序和更新进度。

## Covered path

`app/test/library_scale_test.dart` 生成 10,000 条完整 `LibraryDocument`，覆盖：

- 初始加载
- 标题搜索
- 漫画类型筛选
- 按标题和进度排序
- 进度更新
- 继续阅读选择

测试使用 8 秒作为宽松回归上限，避免共享 CI 机器抖动；它是功能回归门禁，不是产品 SLA。

## View cache

`PersistedLibraryController` 缓存当前 query / section / type / sort 对应的可见文档列表。以下变化会立即失效缓存：

- 搜索、筛选、排序
- 收藏夹和收藏集
- 导入、删除、改名
- 阅读进度和最近打开时间
- 异步笔记搜索命中

同一状态重复读取返回同一列表，避免一次 Widget build 中反复过滤、排序 10k 文档。

## Commands

```powershell
cd app
flutter test test/library_scale_test.dart
cd ..\rust
cargo test -p universal-reader-server loads_ten_thousand_documents_within_baseline cover_lookup_stays_fast_with_ten_thousand_documents
```

## Rust service baseline

SQLite 查询测试插入 10,000 条文档，要求全量读取在 5 秒内、单 ID 查询在 500 ms 内。

封面测试在 10,000 条目录记录中读取单本封面，要求 500 ms 内完成。实现不再为了单本封面重新协调并重写整库目录；文档按 ID 直读，目录仅在 `list()` 时协调，且只在磁盘与 SQLite 不一致时回写。

## Remaining measurement

当前基线覆盖 Flutter 内存书库 query/view、Rust SQLite 列表和单本查询、封面查询。后续还要补：

- 真机列表滚动帧率和图片解码占用
- 10k 文件扫描会话的端到端吞吐

## Cover cache and lazy loading

- `LibraryCover` 仍由懒布局按可见项构建。
- `PersistedLibraryController` 使用有界 LRU：默认最多 128 张、总 16 MiB、单张 4 MiB，超限淘汰最久未使用项。
- 同一本书重复构建只读取一次仓储。

## Progressive folder scan

服务端扫描拆为会话：

1. `POST /v1/library/scan/start` 返回 `session_id` 和 `total`。
2. `POST /v1/library/scan/next` 每次处理 1–500 个路径并返回累计状态。
3. 会话完成后自动移除；服务端最多保留 8 个未完成扫描会话。

Flutter Sources 卡片使用分批接口显示扫描进度，不再等整个目录一次性处理完后才反馈。
