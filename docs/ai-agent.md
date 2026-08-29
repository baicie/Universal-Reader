# Spec: AI Agent as Reader Tool

## Objective

为 Universal Reader 设计一个**可选、文档锚定、用户主动唤起**的阅读助手，而不是把大模型做成核心阅读器，也不是做一个会自己操作应用的通用 Agent。

这份文档只覆盖设计。落地必须排在真实可读（EPUB/PDF 能读完一本）之后。没有配置任何模型时，阅读、书库、进度必须 100% 可用。

目标用户：已经在读一本书、需要对选区或当前章节提问的人。不是想用聊天窗口替代阅读的人。

成功标准见文末。第一批落地：Tool slot、设置开关、问这一页面板；默认关闭，不调用模型。

## Assumptions

请直接纠正下面这些前提，否则后续实现会按它们执行：

1. 「引入 AI agent」指产品能力（阅读助手），不是再加一层 Cursor 开发 Agent。
2. 遵守 `index.md` §25 与 §34：AI 是 enhancement；第一年不做自主大模型 Agent。
3. Local-first：默认不联网、不建账号；用户必须显式启用 Provider。
4. 当前支持用户配置的 DeepSeek 接口；默认关闭。
5. Agent 只使用当前打开文档的 `extractText` / `search` / `TOC` / `Locator`，不把整库上传。
6. 界面挂在 Reader Chrome / 选区菜单，不新增资料库一级入口。
7. 模型推理走用户配置的 DeepSeek（或兼容网关），Rust Core 不内置模型权重。

## Tech Stack

沿用现有栈，不为此功能先加新框架。

| 层 | 选择 |
| --- | --- |
| App | Flutter / Dart，Riverpod，go_router |
| 阅读协议 | 现有 `ReaderDocument`、`Locator`、`DocumentRange` |
| 插件槽位 | `index.md` §23 的 `ToolProvider` |
| 本地能力 | Rust 服务负责文件、书库，以及可选的 DeepSeek 转发与按书问答落盘；**不**复制 prompt / grounding |
| 模型 | 用户配置的 DeepSeek；走本机服务时由服务转发，默认关闭 |
| 持久化 | 工具设置进 Settings；问答记录按书保存（本机 SharedPreferences，或服务端 `conversations/{id}.json`），不进 annotations |

## Commands

验证设计落地时使用现有命令，不引入新脚本：

```powershell
cd app
flutter pub get
flutter analyze
flutter test
flutter run -d chrome
```

```powershell
cd rust
cargo test --workspace
```

## Project Structure

设计落地时新增位置，现有 `main.dart` 单体壳层之后再拆：

```text
app/lib/
  features/
    reader/                 现有阅读页
    settings/               Provider 开关与端点配置
    tools/                  本期设计的边界
      reader_tool.dart      Tool 协议
      reader_tool_host.dart 阅读页宿主（默认可空）
      ai/
        ai_tool_provider.dart
        model_provider.dart
        conversation_store.dart 按书保存问答
        model_client.dart       DeepSeek 直连或同域网关
        grounding.dart          从 ReaderDocument 取上下文
        prompts.dart            把文档当作不可信输入
docs/ai-agent.md            本规格（活文档）
```

Rust 侧**不要**再做一份阅读助手：不写 prompt、不抽摘录、不内置模型。只提供：

- `POST /v1/ai/chat`：把 `{ model, messages, api_key? }` 转到服务端配置的 DeepSeek；客户端不能指定 endpoint（防 SSRF）。
- `GET /v1/ai/status`：服务端是否已配置密钥。
- `GET/PUT /v1/library/documents/{id}/conversations`：按书保存问答，最多 50 条。

## Code Style

工具必须通过阅读协议拿上下文，禁止直接操作 WebView 或第三方 renderer。

```dart
abstract interface class ReaderTool {
  String get id;
  String get label;
  bool get enabled;

  Future<ReaderToolResult> run({
    required ReaderDocument document,
    required ReaderToolRequest request,
  });
}

class ReaderToolRequest {
  const ReaderToolRequest({
    required this.kind, // summarize | explain | translate | ask
    this.question,
    this.range,
    this.locator,
  });

  final String kind;
  final String? question;
  final DocumentRange? range;
  final Locator? locator;
}
```

命名：`*Provider` 只表示可替换后端，不表示一定联网。文档正文一律当不可信内容，不能当指令执行。

## Testing Strategy

实现阶段（当前不做）最低要求：

- `app/test/` widget：未启用 Provider 时阅读页不出现强制引导、不发起网络。
- 单元测试：`grounding.dart` 只拼接当前文档摘录、locator、用户问题；不读取其他书籍。
- 回归：现有 `format_detector_test`、`library_repository_test`、`widget_test` 必须继续通过。
- 不做「调用真实模型」的 CI。Provider 用假实现。

## Boundaries

- Always
  - 默认关闭；无 Provider 时阅读体验不变。
  - 只通过 `ReaderDocument` 取文本和定位。
  - 把书籍内容当不可信输入，防提示注入。
  - 用户主动点「发送」后才调用模型。
  - 移动端仍是点中心区域显隐 Reader Chrome。
  - 问答记录按书保存；Rust 只做轻量转发和落盘。
  - 服务端 DeepSeek endpoint 只来自环境变量，不接受客户端传入的 URL。
- Ask first
  - 增加 Ollama 或其他 Provider。
  - 默认把选区送出设备。
  - 把对话存进 annotations / 笔记。
  - 给资料库首页加 AI 入口或推荐。
  - 在 Rust 里复制一套 prompt / grounding Agent。
- Never
  - 无 AI 就无法打开书。
  - 导入时自动摘要整库。
  - Agent 自己翻页、改进度、写标注、执行 JS、访问任意文件。
  - 账号体系、插件市场、DRM、把 EPUB WebView 变成开放浏览器。
  - 第一年做「自主规划、多步操作应用」的通用 Agent。

## Product Design

### 它是什么

用户对着**当前书**执行的有限工具，以及后续一个仍由用户发起的问答循环。循环里模型只能调用白名单工具：

```text
extractText(range)
search(query)
getToc()
currentLocator()
goTo(locator)          只建议跳转，必须用户确认
```

### 它不是什么

- 不是第二个产品首页。
- 不是能自己点按钮的桌面 Agent。
- 不是云端书库分析服务。

### 界面

桌面阅读页：右侧可选面板，宽约 320px，不挤压正文字宽到无法阅读；正文仍居中、最大宽度约 720px。

移动阅读页：底部 sheet，高度不超过半屏；打开工具时不要永久占据 Chrome。点页面中心仍只切换工具栏。

入口：

1. 选区菜单：解释、翻译、总结。
2. Reader 顶栏溢出菜单：「问这一页 / 问这本书」。
3. Settings：Provider、端点、是否允许离机、模型名。

不入口：资料库网格、继续阅读卡片、侧栏 Collections。

视觉继续遵守 `index.md` §20：极简、内容优先。工具面板用应用表面色，不另做一套霓虹聊天皮肤。

### 安全

- WebView 沙箱规则不变（`index.md` §22）。
- Tool 层不能 `evaluate` WebView。
- 远程 Provider 必须在 Settings 里明文展示「将发送当前摘录」。
- 默认策略：仅选区或当前章节，不上整本书，不上封面以外的二进制。

## Phased Plan

实现顺序（全部需本规格通过后才开工）：

1. **Tool slot**：`ReaderTool` + 阅读页空宿主 + Settings 占位。零模型依赖。
2. **Single-shot tools**：总结 / 解释 / 翻译选区。用户配置 endpoint。
3. **Ask document**：FTS + `extractText` 做有限上下文问答，回答必须带 locator。
4. **Limited loop**：模型可提议 `search` / `goTo`，跳转需确认。仍不是自主 Agent。

当前已完成第 1、2 步，以及按书问答记录和 Rust 轻量网关。第 3、4 步仍未开始。

## Success Criteria

设计阶段完成，当且仅当：

- [x] 规格覆盖目标、命令、结构、风格、测试、边界。
- [ ] 你确认或纠正文首 7 条假设。
- [ ] 确认「现在不实现」。
- [ ] 确认第一批若落地，是 Tool slot，而不是聊天首页。

实现阶段完成（以后），当且仅当：

- 关闭 Provider 时，现有 widget 测试与阅读路径无变化。
- 打开 Provider 后，问答只引用当前文档摘录，并显示 locator。
- 无账号、无强制联网、无自动整库分析。

## Open Questions

1. 第一批 Provider 要哪种：仅本机（如 Ollama）、仅用户自备 API，还是两者都做但默认全关？
2. 工具语言是否固定中文界面、模型提示按书的语言走？
3. 对话要不要允许「保存为笔记」？这会碰到 Annotation 模型。
4. 是否同意：EPUB 真实可读之前，不开始第 1 阶段代码？
