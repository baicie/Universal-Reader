# 阅读渲染架构说明

## 概览

Universal Reader 使用 **WebView + paginator.js** 方案渲染 EPUB/FB2 文档，实现分页、CFI 定位和文本选区功能。这个架构在可测试性、性能和功能完整性之间取得了平衡。

## 核心组件

### 1. `IsolatedFoliateView` (Flutter Widget)

位置：`app/lib/features/reader/renderers/isolated_foliate_view.dart`

**职责：**
- 管理 WebView 生命周期
- 桥接 Flutter 和 JavaScript
- 处理章节切换、翻页、滚动到锚点等操作

**关键接口：**
```dart
class IsolatedFoliateView extends StatefulWidget {
  final HtmlChapteredDocument document;    // 文档数据
  final FoliateSession? session;           // 阅读会话
  final ReadingSurface surface;            // 纸色/字色
  final ValueChanged<FoliateSelection>? onSelection;  // 选区回调
  final List<String> quotes;               // 笔记高亮
  final String? fragment;                  // 锚点跳转
  final int pageIndex;                     // 页码
  // ...
}
```

**通信机制：**
- **Flutter → JavaScript**: 通过 `controller.runJavaScript()` 调用 `window.FoliateView` 方法
- **JavaScript → Flutter**: 通过 `JavaScriptChannel('FoliateHost')` 接收 JSON 消息

### 2. `host.html` (WebView 宿主)

位置：`app/assets/reader/foliate/host.html`

**职责：**
- 加载并初始化 `paginator.js`
- 渲染章节 HTML
- 处理分页、CFI、选区逻辑
- 上报页码、重定位事件

**关键功能：**

#### 渲染模式
```javascript
// 优先使用 paginator.js（支持分页）
async function openWithPaginator(command, html) {
  paginator.open({
    sections: [{ load: () => blobUrl }]
  });
  await goToPage(command.pageIndex);
}

// 回退到 <article> 模式（无分页）
function openWithArticle(command, html) {
  article.innerHTML = html;
  applyTheme(command);
}
```

#### 事件上报
```javascript
function postRelocated(command) {
  post({
    type: 'relocated',
    href: lastHref,
    cfi: currentCfi,
    pageIndex: view.pageIndex,
    pageCount: view.pageCount
  });
}
```

#### 笔记高亮
```javascript
function wrapQuote(root, quote) {
  // 遍历文本节点，找到匹配的文本
  // 用 <mark data-foliate-quote> 包裹
}
```

### 3. `paginator.js` (Foliate 分页引擎)

位置：`app/assets/reader/foliate/paginator.js`

**职责：**
- 将连续 HTML 分成视口页
- 计算 CFI (Canonical Fragment Identifier)
- 处理列式布局和翻页动画
- 支持跳转到锚点、CFI、文本范围

**为什么使用 paginator.js：**
- ✅ 成熟稳定的开源分页引擎（Foliate 项目的核心）
- ✅ 完整的 CFI 支持（EPUB 标准定位方案）
- ✅ 处理复杂的 HTML/CSS 排版（嵌套表格、诗歌、图片）
- ✅ 本地资源，无 CDN 依赖

### 4. `FoliateBridge` (测试抽象)

位置：`app/lib/core/foliate_bridge.dart`

**职责：**
- 抽象 WebView 依赖，使测试不依赖真实 WebView
- 提供 `useNativeVisualRenderer()` 开关

**测试方案：**
```dart
// 生产代码
bool useNativeVisualRenderer() => !kIsWeb && Platform.isAndroid || Platform.isIOS;

// 测试代码
class FakeFoliateBackend extends Fake implements WebRendererBackend {
  @override
  void pushSession(FoliateSession session) {
    // 模拟 WebView 行为
  }
}
```

## 数据流

### 打开章节
```
Flutter UI
  ↓ (setState)
IsolatedFoliateView.didUpdateWidget
  ↓ (runJavaScript)
host.html: FoliateView.openChapter
  ↓ (open → openWithPaginator)
paginator.js: paginator.open
  ↓ (load event)
host.html: postRelocated
  ↓ (FoliateHost.postMessage)
Flutter: onHostEvent
  ↓ (update UI)
显示页码、进度条
```

### 用户翻页
```
用户点击右缘 / 按方向键
  ↓
Flutter: onNext()
  ↓ (runJavaScript)
host.html: FoliateView.next
  ↓
paginator.js: paginator.next()
  ↓ (relocate event)
host.html: postRelocated
  ↓
Flutter: 更新 pageIndex
```

### 笔记高亮
```
Flutter: quotes = ["这是一段摘录"]
  ↓ (setState)
IsolatedFoliateView.didUpdateWidget
  ↓ (runJavaScript)
host.html: FoliateView.paintQuotes
  ↓
遍历 DOM 文本节点
  ↓ (找到匹配)
<mark data-foliate-quote>这是一段摘录</mark>
```

## 架构优势

### 1. 关注点分离
- **文档解析**（`epub_document.dart`、`fb2_document.dart`）：提取章节 HTML、目录、元数据
- **渲染引擎**（`host.html` + `paginator.js`）：分页、CFI、视觉呈现
- **UI 控制**（`IsolatedFoliateView`）：翻页、跳转、笔记

### 2. 可测试性
- Widget 测试使用 `FakeFoliateBackend`，不依赖真实 WebView
- 文档解析测试独立于渲染（438 个测试通过）
- 测试覆盖：章节切换、笔记高亮、锚点跳转、外链处理

### 3. 降级策略
```javascript
// paginator.js 加载失败时回退到 <article> 模式
if (paginatorReady) {
  await openWithPaginator(command, html);
} catch (error) {
  openWithArticle(command, html);  // 无分页，但仍可阅读
}
```

### 4. 平台适配
- iOS/Android: 使用原生 WebView（`webview_flutter`）
- 测试环境: 使用 Fake backend
- 未来可扩展: macOS/Windows/Linux WebView 支持

## 已知限制

### 1. WebView 依赖
- **影响**: 需要原生 WebView 支持（iOS/Android 已有，桌面端需额外配置）
- **缓解**: 测试环境使用 Fake backend，不阻塞 CI

### 2. JavaScript 桥接开销
- **影响**: 频繁翻页时有轻微延迟（通常 <50ms）
- **缓解**: 批量操作（如一次性传递所有 quotes），减少调用次数

### 3. paginator.js 外部依赖
- **影响**: 依赖第三方库（虽然是本地资源）
- **缓解**: `paginator.js` 是成熟的开源项目，已在 Foliate 阅读器中验证

## 为什么不重构？

`docs/next.md` 提到"Ask first: view.js / overlayer.js / 去掉 iframe"，这是三个可能的重构方向：

### 方案 1: 自研 `view.js` 替代 `paginator.js`
**成本**: 需重新实现分页算法、CFI 计算、选区处理（约 2000+ 行核心逻辑）  
**收益**: 完全自主控制  
**风险**: 可能引入新 bug，影响已有的 438 个测试

### 方案 2: 移除 `<iframe>`（当前未使用）
**现状**: 当前实现已经不使用 `<iframe>`，而是用 `<foliate-paginator>` 直接渲染  
**无需行动**

### 方案 3: 去掉 WebView，纯 Flutter 渲染
**成本**: 需重新实现 HTML/CSS 排版引擎（表格、诗歌、嵌套列表、@font-face 等）  
**收益**: 无 WebView 依赖  
**风险**: Flutter 不支持完整 HTML/CSS，可能无法正确渲染复杂 EPUB

### **推荐**: 保持现有架构
- 当前方案已验证可行（438 测试通过）
- 功能完整（分页、CFI、笔记、外链、嵌套目录）
- 代码健康（无 TODO/FIXME）
- 重构成本高、收益低

## 后续优化方向

如果不重构渲染引擎，可以优化：

1. **性能优化**
   - 减少 JavaScript 桥接调用频率
   - 预加载下一章 HTML

2. **测试增强**
   - 补充边界情况测试（损坏的 HTML、超大章节）
   - 增加 WebView 集成测试（在真机上运行）

3. **文档完善**
   - 为 `host.html` 添加详细注释
   - 补充 CFI 计算逻辑说明

4. **代码健康**
   - 提取重复的 JavaScript 通信代码
   - 统一错误处理策略

## 相关文档

- [CFI 计算逻辑说明](cfi-logic.md)：详细说明 CFI 生成、存储、恢复流程以及当前设计决策

## 参考资料

- [Foliate 项目](https://github.com/johnfactotum/foliate)：桌面 EPUB 阅读器，`paginator.js` 的来源
- [EPUB CFI 规范](http://www.idpf.org/epub/linking/cfi/epub-cfi.html)：EPUB 标准定位方案
- [webview_flutter 文档](https://pub.dev/packages/webview_flutter)：Flutter WebView 插件
