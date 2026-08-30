# Universal Reader 技术文档

本目录包含 Universal Reader 的技术设计文档和开发指南。

## 架构与设计

### 渲染架构
- **[renderer-architecture.md](renderer-architecture.md)** - 阅读渲染架构说明  
  WebView + paginator.js 方案详解，包括核心组件、数据流和架构决策

- **[cfi-logic.md](cfi-logic.md)** - CFI 计算逻辑说明  
  EPUB CFI（Canonical Fragment Identifier）生成、存储、恢复流程以及设计决策

- **[reader-engines.md](reader-engines.md)** - 阅读引擎对比  
  不同渲染引擎的技术方案和选型考量

### 阅读器实现
- **[epub-reader.md](epub-reader.md)** - EPUB 阅读器实现  
  EPUB 文档解析、章节渲染、目录导航和交互设计

- **[pdf-reader.md](pdf-reader.md)** - PDF 阅读器实现  
  PDF 文档渲染和交互方式

- **[text-reader.md](text-reader.md)** - 文本阅读器实现  
  TXT、Markdown、HTML 等纯文本格式的阅读支持

## 功能模块

### 书库管理
- **[library-store.md](library-store.md)** - 书库存储设计  
  本地书库数据模型、文件组织和持久化方案

- **[local-sqlite.md](local-sqlite.md)** - 本地 SQLite 方案  
  客户端 SQLite 数据库设计和迁移策略

- **[library-sources.md](library-sources.md)** - 书库数据源  
  多数据源支持（本地、HTTP 服务）和切换逻辑

- **[library-sync.md](library-sync.md)** - 书库同步  
  多设备书库同步方案和冲突处理

### 辅助功能
- **[annotations.md](annotations.md)** - 笔记与标注  
  书签、高亮、笔记的数据模型和存储方案

- **[ai-agent.md](ai-agent.md)** - AI 阅读助手  
  DeepSeek/Ollama 集成、问答历史和笔记生成

## 平台与工程

- **[reading-platform.md](reading-platform.md)** - 阅读平台概述  
  整体平台架构、技术栈和跨平台策略

## 开发指南

### 快速开始
阅读顺序建议：
1. [reading-platform.md](reading-platform.md) - 了解整体架构
2. [renderer-architecture.md](renderer-architecture.md) - 理解渲染层设计
3. [library-store.md](library-store.md) - 了解数据存储
4. [epub-reader.md](epub-reader.md) - 深入阅读器实现

### 常见任务
- **添加新的文档格式支持** → 参考 [epub-reader.md](epub-reader.md) 和 [reader-engines.md](reader-engines.md)
- **优化渲染性能** → 参考 [renderer-architecture.md](renderer-architecture.md) 和 [cfi-logic.md](cfi-logic.md)
- **扩展书库功能** → 参考 [library-store.md](library-store.md) 和 [library-sources.md](library-sources.md)
- **集成新的 AI 模型** → 参考 [ai-agent.md](ai-agent.md)

## 开发状态

- **[next.md](next.md)** - 下一步工作计划  
  已完成的功能、待优化项和未来方向

## 贡献指南

编写或更新文档时，请遵循以下原则：
1. **准确性** - 确保文档与代码实现一致
2. **完整性** - 说明设计决策、权衡和替代方案
3. **可读性** - 使用清晰的标题、代码示例和流程图
4. **可维护性** - 代码变更时同步更新文档

文档使用 Markdown 格式，代码示例使用对应语言的语法高亮。

## 项目链接

- [GitHub 仓库](https://github.com/your-org/universal-reader)
- [问题反馈](https://github.com/your-org/universal-reader/issues)
- [主 README](../README.md)
