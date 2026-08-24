# Universal Reader

Universal Reader 的首版可运行 Web MVP，依据 `index.md` 的 Phase 0 设计实现了 Local-first Library 体验。

## 运行

这是一个零依赖静态应用，直接打开 `index.html` 即可运行。也可以在项目目录启动任意静态文件服务器，例如：

```powershell
python -m http.server 8080
```

然后访问 `http://localhost:8080`。

## 当前实现

- Library 首页：全部、最近阅读、正在阅读、收藏
- 可重排、固定版式、漫画格式筛选
- 书名、作者、格式搜索
- 最近添加、标题、进度排序
- 网格/列表视图切换
- 本地文件选择与导入反馈
- 响应式桌面/移动布局
- 预留后续 Flutter `Reader Runtime`、`DocumentAdapter`、`Locator` 的产品边界

## 后续工程化

正式跨平台版本应按设计方案迁移到 Flutter + Rust Core，并把当前页面拆为 `features/library`，将格式检测、SQLite、索引和文件扫描下沉到 Rust。
