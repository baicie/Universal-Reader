export type Language = "zh" | "en";

export type Copy = {
  appTitle: string;
  openFile: string;
  scope: string;
  emptyShelf: string;
  back: string;
  previous: string;
  next: string;
  previousPage: string;
  nextPage: string;
  contents: string;
  close: string;
  find: string;
  searchPlaceholder: string;
  noHits: string;
  truncated: string;
  corrupt: string;
  unavailable: string;
  unsupported: string;
  readFailed: string;
  shelfUnreadable: string;
  shelfFailed: string;
  importFromWebdav: string;
  webdavUrl: string;
  webdavUser: string;
  webdavPassword: string;
  webdavFailed: string;
  webdavEmpty: string;
  pushToWebdav: string;
  webdavNothing: string;
  webdavPushFailed: string;
  s3Storage: string;
  importFromS3: string;
  s3Endpoint: string;
  s3Region: string;
  s3Bucket: string;
  s3Prefix: string;
  s3AccessKey: string;
  s3SecretKey: string;
  s3Failed: string;
  s3Empty: string;
  pushToS3: string;
  s3Nothing: string;
  s3PushFailed: string;
  syncWebDavReading: string;
  syncS3Reading: string;
  readingSyncFailed: string;
  askThisPage: string;
  askThisBook: string;
  askBookHint: string;
  endpointLabel: string;
  modelLabel: string;
  apiKeyLabel: string;
  askQuestionHint: string;
  sendExcerptHint: string;
  sendExcerpt: string;
  sending: string;
  askFailed: string;
  noExcerpt: string;
  conversationHistory: string;
  conversationUnavailable: string;
  saveAsNote: string;
  noteSaved: string;
  saveSelection: string;
  notesUnavailable: string;
  readingSettings: string;
  notesTitle: string;
  noNotes: string;
  deleteNote: string;
  pageZoom: string;
  comicLayout: string;
  comicLayoutSingle: string;
  comicLayoutDouble: string;
  comicLayoutVertical: string;
  comicReadRtl: string;
  bodyFontSize: string;
  bodyLineHeight: string;
  bodyFontFamily: string;
  fontSerif: string;
  fontSans: string;
  fontMono: string;
  readingPaper: string;
  readingPaperFollow: string;
  themeLight: string;
  themeDark: string;
  smaller: string;
  larger: string;
  tighter: string;
  looser: string;
  bookmarks: string;
  addBookmark: string;
  noBookmarks: string;
  deleteBookmark: string;
  bookmarkAt: (chapter: number, page: number) => string;
  deleteFromLibrary: string;
  editBookIdentity: string;
  bookTitleLabel: string;
  bookAuthorLabel: string;
  saveAction: string;
  shelfSearch: string;
  noShelfHits: string;
  shelfAll: string;
  formatAll: string;
  formatReflow: string;
  formatFixed: string;
  formatComic: string;
  shelfReading: string;
  shelfFavorites: string;
  addToFavorites: string;
  removeFromFavorites: string;
  collections: string;
  newCollection: string;
  collectionNameHint: string;
  createCollection: string;
  noCollections: string;
  deleteCollection: string;
  noSectionBooks: string;
  shelfOrder: string;
  sortRecent: string;
  sortTitle: string;
  sortProgress: string;
  continueReading: string;
  addToNamedCollection: (name: string) => string;
  removeFromNamedCollection: (name: string) => string;
  readingProgress: string;
  comicPage: string;
  previousSide: string;
  nextSide: string;
  readingPercent: (percent: number) => string;
  deleteBookConfirm: (title: string) => string;
  cancelAction: string;
  confirmDelete: string;
  jumpToLocation: (locator: string) => string;
  chapter: (current: number, total: number) => string;
  page: (current: number, total: number) => string;
};

const zh: Copy = {
  appTitle: "通用阅读器",
  openFile: "打开文件",
  scope: "这一版读 TXT、Markdown、HTML、RTF、DOCX、ODT、EPUB、PDF、FB2、MOBI、AZW3、CHM、DJVU，以及 CBZ、CBT、CBR、CB7 漫画。",
  emptyShelf: "还没有打开过文件。",
  back: "返回",
  previous: "上一章",
  next: "下一章",
  previousPage: "上一页",
  nextPage: "下一页",
  contents: "目录",
  close: "关闭",
  find: "查找",
  searchPlaceholder: "在这本书里查找",
  noHits: "没有找到。",
  truncated: "文件太长，只显示前面这一部分。",
  corrupt: "这个文件损坏了，打不开。",
  unavailable: "这个文件是空的。",
  unsupported: "这个格式还不能打开。",
  readFailed: "读不到这个文件。",
  shelfUnreadable: "这台设备上的书架是更新的版本，这一版读不了。",
  shelfFailed: "书架打不开。",
  importFromWebdav: "从 WebDAV 导入",
  webdavUrl: "WebDAV 地址",
  webdavUser: "WebDAV 用户名",
  webdavPassword: "WebDAV 密码",
  webdavFailed: "从 WebDAV 读不到书。",
  webdavEmpty: "这个目录里没有能打开的书。",
  pushToWebdav: "推到 WebDAV",
  webdavNothing: "没有需要推到远端的书。",
  webdavPushFailed: "有的书没有推到 WebDAV。",
  s3Storage: "S3 兼容存储",
  importFromS3: "从 S3 导入",
  s3Endpoint: "S3 地址",
  s3Region: "区域",
  s3Bucket: "存储桶",
  s3Prefix: "前缀",
  s3AccessKey: "Access Key",
  s3SecretKey: "Secret Key",
  s3Failed: "从 S3 读不到书。",
  s3Empty: "这个前缀里没有能打开的书。",
  pushToS3: "推到 S3",
  s3Nothing: "没有需要推到 S3 的书。",
  s3PushFailed: "有的书没有推到 S3。",
  syncWebDavReading: "同步 WebDAV 阅读状态",
  syncS3Reading: "同步 S3 阅读状态",
  readingSyncFailed: "阅读进度没有同步。",
  askThisPage: "问这一页",
  askThisBook: "问这本书",
  askBookHint: "将发送这本书里的命中段落，不上整本书。",
  endpointLabel: "接口地址",
  modelLabel: "模型",
  apiKeyLabel: "API Key",
  askQuestionHint: "输入关于这一页的问题",
  sendExcerptHint: "将发送当前章节摘录，不上整本书。",
  sendExcerpt: "发送摘录",
  sending: "发送中…",
  askFailed: "这一页没有问成。",
  noExcerpt: "当前页没有可发送的摘录。",
  conversationHistory: "问答记录",
  conversationUnavailable: "无法读取问答记录。",
  saveAsNote: "保存为笔记",
  noteSaved: "已保存为笔记。",
  saveSelection: "保存选区",
  notesUnavailable: "无法读取笔记。",
  readingSettings: "阅读设置",
  notesTitle: "笔记",
  noNotes: "这本书还没有笔记。",
  deleteNote: "删除笔记",
  pageZoom: "页面缩放",
  comicLayout: "漫画阅读",
  comicLayoutSingle: "单页",
  comicLayoutDouble: "双页",
  comicLayoutVertical: "竖滑",
  comicReadRtl: "从右到左",
  bodyFontSize: "正文字号",
  bodyLineHeight: "行距",
  bodyFontFamily: "正文字体",
  fontSerif: "衬线",
  fontSans: "无衬线",
  fontMono: "等宽",
  readingPaper: "纸张",
  readingPaperFollow: "跟随应用",
  themeLight: "浅色",
  themeDark: "深色",
  smaller: "更小",
  larger: "更大",
  tighter: "更紧",
  looser: "更松",
  bookmarks: "书签",
  addBookmark: "添加书签",
  noBookmarks: "这本书还没有书签。",
  deleteBookmark: "删除书签",
  bookmarkAt: (chapter, page) => `第 ${chapter} 章 · 第 ${page} 页`,
  deleteFromLibrary: "从书库删除",
  editBookIdentity: "编辑书名",
  bookTitleLabel: "书名",
  bookAuthorLabel: "作者",
  saveAction: "保存",
  shelfSearch: "搜索书名、作者或格式",
  noShelfHits: "没有找到这本书。",
  shelfAll: "全部",
  formatAll: "全部格式",
  formatReflow: "可重排",
  formatFixed: "固定版式",
  formatComic: "漫画",
  shelfReading: "正在阅读",
  shelfFavorites: "收藏",
  addToFavorites: "加入收藏",
  removeFromFavorites: "取消收藏",
  collections: "收藏夹",
  newCollection: "新建收藏夹",
  collectionNameHint: "收藏夹名称",
  createCollection: "创建",
  noCollections: "还没有收藏夹",
  deleteCollection: "删除收藏夹",
  noSectionBooks: "这里还没有书。",
  shelfOrder: "书架顺序",
  sortRecent: "最近阅读",
  sortTitle: "标题",
  sortProgress: "阅读进度",
  continueReading: "继续阅读",
  addToNamedCollection: (name) => `添加到「${name}」`,
  removeFromNamedCollection: (name) => `从「${name}」移除`,
  readingProgress: "阅读进度",
  comicPage: "漫画页面",
  previousSide: "左侧翻页",
  nextSide: "右侧翻页",
  readingPercent: (percent) => `${percent}%`,
  deleteBookConfirm: (title) => `删除「${title}」？原文件和该书的笔记会一起去掉，其它书不受影响。`,
  cancelAction: "取消",
  confirmDelete: "删除",
  jumpToLocation: (locator) => `跳转到 ${locator}`,
  chapter: (current, total) => `${current} / ${total}`,
  page: (current, total) => `第 ${current} / ${total} 页`,
};

const en: Copy = {
  appTitle: "Universal Reader",
  openFile: "Open a file",
  scope: "This version reads TXT, Markdown, HTML, RTF, DOCX, ODT, EPUB, PDF, FB2, MOBI, AZW3, CHM, DJVU, and CBZ, CBT, CBR, or CB7 comics.",
  emptyShelf: "No file opened yet.",
  back: "Back",
  previous: "Previous",
  next: "Next",
  previousPage: "Previous page",
  nextPage: "Next page",
  contents: "Contents",
  close: "Close",
  find: "Find",
  searchPlaceholder: "Search this book",
  noHits: "No matches.",
  truncated: "This file is too long. Only the beginning is shown.",
  corrupt: "This file is damaged and cannot be opened.",
  unavailable: "This file is empty.",
  unsupported: "This format cannot be opened yet.",
  readFailed: "Could not read this file.",
  shelfUnreadable: "This shelf was saved by a newer version and cannot be opened.",
  shelfFailed: "The shelf could not be opened.",
  importFromWebdav: "Import from WebDAV",
  webdavUrl: "WebDAV URL",
  webdavUser: "WebDAV username",
  webdavPassword: "WebDAV password",
  webdavFailed: "Could not read books from WebDAV.",
  webdavEmpty: "This folder has no book this version can open.",
  pushToWebdav: "Push to WebDAV",
  webdavNothing: "No book on this shelf needs to be pushed.",
  webdavPushFailed: "Some books could not be pushed to WebDAV.",
  s3Storage: "S3-compatible storage",
  importFromS3: "Import from S3",
  s3Endpoint: "S3 endpoint",
  s3Region: "Region",
  s3Bucket: "Bucket",
  s3Prefix: "Prefix",
  s3AccessKey: "Access key",
  s3SecretKey: "Secret key",
  s3Failed: "Could not read books from S3.",
  s3Empty: "This prefix has no book this version can open.",
  pushToS3: "Push to S3",
  s3Nothing: "No book on this shelf needs to be pushed to S3.",
  s3PushFailed: "Some books could not be pushed to S3.",
  syncWebDavReading: "Sync reading data with WebDAV",
  syncS3Reading: "Sync reading data with S3",
  readingSyncFailed: "Reading progress could not be synced.",
  askThisPage: "Ask this page",
  askThisBook: "Ask this book",
  askBookHint: "Matching passages from this book will be sent, not the whole book.",
  endpointLabel: "Endpoint",
  modelLabel: "Model",
  apiKeyLabel: "API key",
  askQuestionHint: "Ask a question about this page",
  sendExcerptHint: "The current chapter excerpt will be sent, not the whole book.",
  sendExcerpt: "Send excerpt",
  sending: "Sending…",
  askFailed: "This page could not be asked.",
  noExcerpt: "This page has no excerpt to send.",
  conversationHistory: "Conversation",
  conversationUnavailable: "Could not load the conversation.",
  saveAsNote: "Save as a note",
  noteSaved: "Saved as a note.",
  saveSelection: "Save selection",
  notesUnavailable: "Could not load notes.",
  readingSettings: "Reading settings",
  notesTitle: "Notes",
  noNotes: "This book has no notes yet.",
  deleteNote: "Delete note",
  pageZoom: "Page zoom",
  comicLayout: "Comics",
  comicLayoutSingle: "Single",
  comicLayoutDouble: "Double",
  comicLayoutVertical: "Vertical",
  comicReadRtl: "Right to left",
  bodyFontSize: "Body text size",
  bodyLineHeight: "Line height",
  bodyFontFamily: "Body font",
  fontSerif: "Serif",
  fontSans: "Sans",
  fontMono: "Mono",
  readingPaper: "Paper",
  readingPaperFollow: "Match app",
  themeLight: "Light",
  themeDark: "Dark",
  smaller: "Smaller",
  larger: "Larger",
  tighter: "Tighter",
  looser: "Looser",
  bookmarks: "Bookmarks",
  addBookmark: "Add bookmark",
  noBookmarks: "This book has no bookmarks yet.",
  deleteBookmark: "Delete bookmark",
  bookmarkAt: (chapter, page) => `Chapter ${chapter}, page ${page}`,
  deleteFromLibrary: "Remove from library",
  editBookIdentity: "Edit title",
  bookTitleLabel: "Title",
  bookAuthorLabel: "Author",
  saveAction: "Save",
  shelfSearch: "Search title, author, or format",
  noShelfHits: "No book matches.",
  shelfAll: "All",
  formatAll: "All formats",
  formatReflow: "Reflow",
  formatFixed: "Fixed layout",
  formatComic: "Comics",
  shelfReading: "Reading",
  shelfFavorites: "Favorites",
  addToFavorites: "Add to favorites",
  removeFromFavorites: "Remove from favorites",
  collections: "Collections",
  newCollection: "New collection",
  collectionNameHint: "Collection name",
  createCollection: "Create",
  noCollections: "No collections yet",
  deleteCollection: "Delete collection",
  noSectionBooks: "Nothing in this shelf.",
  shelfOrder: "Shelf order",
  sortRecent: "Recently read",
  sortTitle: "Title",
  sortProgress: "Progress",
  continueReading: "Continue reading",
  addToNamedCollection: (name) => `Add to "${name}"`,
  removeFromNamedCollection: (name) => `Remove from "${name}"`,
  readingProgress: "Reading progress",
  comicPage: "Comic page",
  previousSide: "Previous side",
  nextSide: "Next side",
  readingPercent: (percent) => `${percent}%`,
  deleteBookConfirm: (title) => `Remove "${title}"? The file and notes for this book are deleted. Other books are not touched.`,
  cancelAction: "Cancel",
  confirmDelete: "Delete",
  jumpToLocation: (locator) => `Go to ${locator}`,
  chapter: (current, total) => `${current} / ${total}`,
  page: (current, total) => `Page ${current} / ${total}`,
};

export function languageFromCode(code: string | null | undefined): Language {
  return code?.toLowerCase().startsWith("zh") ? "zh" : "en";
}

export function copyFor(language: Language): Copy {
  return language === "zh" ? zh : en;
}
