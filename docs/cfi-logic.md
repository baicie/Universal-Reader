# CFI (Canonical Fragment Identifier) 计算逻辑说明

## 概览

CFI（Canonical Fragment Identifier，标准片段标识符）是 EPUB 标准定义的定位方案，用于精确定位文档中的任意位置。Universal Reader 通过 `paginator.js` 计算和解析 CFI，实现跨章节的精确定位和阅读进度保存。

## CFI 是什么

CFI 是一种类似 XPath 的路径表达式，用于标识 EPUB 文档中的特定位置。

### CFI 示例

```
epubcfi(/6/4[chap01]!/4/2/1:15)
```

**解析：**
- `/6/4[chap01]` - 包装文档路径（spine 中的第 3 个项目，ID 为 chap01）
- `!` - 分隔符，表示后面是章节内部路径
- `/4/2/1:15` - 章节内部的 DOM 路径（第 2 个子节点的第 1 个文本节点的第 15 个字符）

## Universal Reader 中的 CFI 流程

### 1. CFI 生成（JavaScript 层）

`paginator.js` 在以下场景自动计算 CFI：

#### 场景 A：翻页完成
```javascript
// host.html 中的 relocated 事件
function postRelocated(command) {
  var view = viewportFromPaginator();
  currentCfi = (command && command.cfi) || currentCfi || '';
  post({
    type: 'relocated',
    href: lastHref,
    cfi: currentCfi,              // 当前可见页面的 CFI
    pageIndex: view.pageIndex,
    pageCount: view.pageCount
  });
}
```

**触发时机：**
- 用户翻页（`paginator.next()` / `paginator.prev()`）
- 跳转完成（`goToPage()` / `goToFragment()` / `goToQuote()`）
- 章节加载完成

#### 场景 B：文本选区
```javascript
// host.html 中的 selectionchange 监听
document.addEventListener('selectionchange', function () {
  var text = (window.getSelection && window.getSelection().toString()) || '';
  post({ 
    type: 'selection', 
    text: text, 
    cfi: currentCfi    // 当前选区所在页面的 CFI
  });
});
```

### 2. CFI 存储（Flutter 层）

#### 读取进度持久化
```dart
// app/lib/core/foliate_session.dart
class FoliateSession {
  final String currentCfi;      // 当前章节的 CFI
  final double progression;     // 章节内进度（0.0-1.0）
  
  // relocated 事件触发时更新
  FoliateSession relocate({
    required String cfi,
    required int pageIndex,
    required int pageCount,
  }) {
    return FoliateSession(
      // ...
      currentCfi: cfi,
      progression: pageCount > 0 ? pageIndex / pageCount : 0,
    );
  }
}
```

#### 保存到数据库
```dart
// app/lib/features/library/library_controller.dart
Future<void> updateProgress(String id, double progress) async {
  // progress 来自 FoliateSession.progression
  // 持久化到 LibraryDocument.progress 字段
  await _repository.updateDocument(id, (doc) => doc.copyWith(progress: progress));
}
```

### 3. CFI 恢复（打开已读书籍时）

#### Flutter → JavaScript 流程
```dart
// app/lib/core/foliate_bridge.dart
static Map<String, Object?> openSession(
  FoliateSession session, {
  // ...
}) {
  return {
    'type': 'open',
    'href': session.href,
    'html': session.visualHtml,
    'cfi': session.currentCfi,         // 传递保存的 CFI
    'pageIndex': session.pageIndex,    // 传递页码（降级方案）
    // ...
  };
}
```

#### JavaScript 侧恢复
```javascript
// host.html 中的 openWithPaginator
async function openWithPaginator(command, html) {
  // ...
  paginator.open({
    sections: [{ load: function () { return blobUrl; } }]
  });
  
  // 优先使用 pageIndex（简单可靠）
  var pageIndex = command.pageIndex || 0;
  await goToPage(pageIndex);
  
  // CFI 暂未直接使用，保留用于未来增强
  // 如果需要 CFI 跳转：await paginator.goTo({ index: 0, cfi: command.cfi });
  
  // 其他导航优先级更高（fragment / scrollQuote）
  if (command.fragment) await goToFragment(command.fragment);
  if (command.scrollQuote) await goToQuote(command.scrollQuote);
}
```

## CFI 与其他定位方式的关系

Universal Reader 支持多种定位方式，优先级如下：

### 优先级顺序（从高到低）

1. **Fragment（锚点）** - 章节内 HTML 元素 ID
   - 用途：目录跳转、内部链接
   - 示例：`#section-2`
   - 实现：`goToFragment(id)`

2. **Quote（引用文本）** - 精确文本匹配
   - 用途：笔记跳转、选区高亮
   - 示例：`"这是一段被选中的文字"`
   - 实现：`goToQuote(quote)`

3. **PageIndex（页码）** - 相对页码（0-based）
   - 用途：进度恢复、滑动条跳转
   - 示例：`pageIndex: 5, pageCount: 20`
   - 实现：`goToPage(index)`

4. **CFI（标准片段标识符）** - 精确 DOM 路径
   - 用途：阅读位置快照（当前仅记录，未用于跳转）
   - 示例：`epubcfi(/6/4[chap01]!/4/2/1:15)`
   - 实现：`paginator.goTo({ index: 0, cfi: '...' })`（保留接口）

### 为什么优先使用 PageIndex 而不是 CFI？

**当前设计决策：**
- ✅ **PageIndex 简单可靠**：整数索引，无解析开销，降级友好
- ✅ **CFI 复杂度高**：需要完整 DOM 树、处理动态内容、字符偏移计算
- ✅ **精度足够**：以页为单位的定位对绝大多数场景够用
- ⚠️ **CFI 未来可用**：保留 CFI 字段用于未来高级功能（如跨设备同步精确位置）

**trade-off：**
- 丢失精度：PageIndex 只能定位到页，CFI 可以定位到字符
- 获得简单：代码更少、测试更简单、bug 更少

## CFI 在代码中的位置

### 生成 CFI
- **文件**：`app/assets/reader/foliate/paginator.js`（Foliate 库内部实现）
- **触发**：`paginator.addEventListener('relocate', ...)`
- **传递**：通过 `postRelocated()` 上报给 Flutter

### 存储 CFI
- **会话层**：`app/lib/core/foliate_session.dart`（内存中的 `currentCfi` 字段）
- **持久层**：未直接持久化 CFI，仅持久化 `progress`（从 `pageIndex / pageCount` 计算）

### 使用 CFI
- **当前**：仅记录，不用于跳转
- **未来**：可扩展为精确位置恢复、多设备同步、精细化进度追踪

## 扩展方向

如果未来需要使用 CFI 实现高级功能，可以：

### 1. 精确位置恢复
```dart
// 持久化 CFI 到数据库
class LibraryDocument {
  final double progress;       // 粗粒度进度（页面级别）
  final String? lastCfi;       // 精确 CFI（字符级别）
}
```

```javascript
// 优先使用 CFI 恢复
async function openWithPaginator(command, html) {
  // ...
  if (command.cfi) {
    await paginator.goTo({ index: 0, cfi: command.cfi });
  } else {
    await goToPage(command.pageIndex || 0);
  }
}
```

### 2. 跨设备同步
```dart
// 上传阅读位置到云端
class ReadingPosition {
  final String bookId;
  final String chapterHref;
  final String cfi;           // 精确位置
  final DateTime timestamp;
}
```

### 3. 精细化进度追踪
```dart
// 分析用户阅读行为
class ReadingAnalytics {
  // CFI 可以精确记录用户在哪一段停留时间长
  void trackReadingTime(String cfi, Duration duration);
}
```

## 测试覆盖

### 当前测试状态

**已覆盖：**
- ✅ CFI 字段在 `FoliateSession` 中正确传递
- ✅ `relocated` 事件包含 CFI
- ✅ `selection` 事件包含 CFI

**未覆盖（因为未使用）：**
- ⚠️ CFI 解析和跳转（`paginator.goTo({ cfi: ... })`）
- ⚠️ CFI 持久化和恢复
- ⚠️ 跨章节 CFI 处理

### 未来测试建议

如果启用 CFI 跳转功能，需增加测试：

```dart
test('restores exact CFI position across sessions', () async {
  // 1. 打开书籍，定位到特定位置
  final doc = EpubReaderDocument.parse(...);
  await doc.goTo(EpubLocator(href: 'ch1.xhtml'));
  
  // 2. 获取当前 CFI
  final cfi = doc.currentCfi;
  
  // 3. 关闭并重新打开
  final doc2 = EpubReaderDocument.parse(...);
  await doc2.goToCfi(cfi);
  
  // 4. 验证恢复到同一位置
  expect(doc2.currentCfi, equals(cfi));
});
```

## 参考资料

- [EPUB CFI 规范](http://www.idpf.org/epub/linking/cfi/epub-cfi.html) - IDPF 官方规范
- [Foliate paginator.js](https://github.com/johnfactotum/foliate) - CFI 计算的实现源码
- [Readium CFI.js](https://github.com/readium/readium-cfi-js) - 另一个 CFI 实现参考

## 总结

**当前状态：**
- CFI 在 Universal Reader 中**生成并记录**，但**不用于跳转**
- 使用更简单的 `pageIndex` 实现进度恢复，精度足够且可靠
- CFI 字段保留用于未来扩展

**设计理念：**
- **实用主义**：优先简单可靠的方案，避免过度设计
- **可扩展性**：保留 CFI 接口，为高级功能预留空间
- **渐进增强**：当前 pageIndex 够用时不引入复杂度

**何时使用 CFI：**
- 需要字符级精度（如精确位置同步、段落级进度）
- 需要跨版本定位（EPUB 更新后仍能找到相同内容）
- 需要与其他 EPUB 阅读器互操作
