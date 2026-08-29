// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Universal Reader';

  @override
  String get openMenu => '打开菜单';

  @override
  String get settings => '设置';

  @override
  String get importBooks => '导入书籍';

  @override
  String get allBooks => '全部书籍';

  @override
  String get currentlyReading => '正在阅读';

  @override
  String get favorites => '收藏';

  @override
  String get library => '资料库';

  @override
  String get libraryWithServer => '资料库 · 本机服务';

  @override
  String bookCount(int count) {
    return '$count 本书籍';
  }

  @override
  String get toggleView => '切换视图';

  @override
  String get all => '全部';

  @override
  String get reflow => '可重排';

  @override
  String get fixedLayout => '固定版式';

  @override
  String get comic => '漫画';

  @override
  String get sortRecent => '最近阅读';

  @override
  String get sortTitle => '标题';

  @override
  String get sortProgress => '阅读进度';

  @override
  String get continueReading => '继续阅读';

  @override
  String get browse => '浏览';

  @override
  String get collections => '收藏夹';

  @override
  String get collectionDesign => '设计与灵感';

  @override
  String get collectionTech => '技术阅读';

  @override
  String get addToFavorites => '加入收藏';

  @override
  String get removeFromFavorites => '取消收藏';

  @override
  String get newCollection => '新建收藏夹';

  @override
  String get collectionNameHint => '收藏夹名称';

  @override
  String get createCollection => '创建';

  @override
  String get cancelAction => '取消';

  @override
  String get deleteCollection => '删除收藏夹';

  @override
  String get deleteFromLibrary => '从书库删除';

  @override
  String deleteBookConfirm(String title) {
    return '删除「$title」？原文件和该书的笔记会一起去掉，其它书不受影响。';
  }

  @override
  String get confirmDelete => '删除';

  @override
  String get bookActions => '书籍操作';

  @override
  String get editBookIdentity => '编辑书名';

  @override
  String get bookTitleLabel => '书名';

  @override
  String get bookAuthorLabel => '作者';

  @override
  String get saveAction => '保存';

  @override
  String get noCollections => '还没有收藏夹';

  @override
  String addToNamedCollection(String name) {
    return '添加到「$name」';
  }

  @override
  String removeFromNamedCollection(String name) {
    return '从「$name」移除';
  }

  @override
  String get importFolder => '导入文件夹';

  @override
  String get localFirstOffline => 'Local-first · 离线可用';

  @override
  String get searchHint => '搜索书名、作者或格式';

  @override
  String get emptyLibraryTitle => '书库还是空的';

  @override
  String get emptyLibraryFilteredTitle => '没有找到匹配的书籍';

  @override
  String get emptyLibraryFilteredSubtitle => '尝试更换搜索词或筛选条件。';

  @override
  String get emptyLibraryRemoteSubtitle => '点击 + 把书上传到本机服务，刷新后也会还在。';

  @override
  String get emptyLibraryLocalSubtitle => '点击 + 导入本地书籍。';

  @override
  String importedBooks(int count) {
    return '已导入 $count 本书籍';
  }

  @override
  String get importFailed => '导入失败，请确认本机服务可用';

  @override
  String get noSupportedFormat => '没有识别到支持的格式';

  @override
  String get localLibraryAuthor => '本地书库';

  @override
  String get backToLibrary => '返回书库';

  @override
  String get askThisPage => '问这一页';

  @override
  String get askThisBook => '问这本书';

  @override
  String jumpToLocation(String locator) {
    return '跳转到 $locator';
  }

  @override
  String get saveAsNote => '保存为笔记';

  @override
  String get noteSaved => '已保存为笔记。';

  @override
  String get notesTitle => '笔记';

  @override
  String get notesUnavailable => '无法读取笔记。';

  @override
  String get bookmarks => '书签';

  @override
  String get addBookmark => '添加书签';

  @override
  String get bookmarkAdded => '已添加书签。';

  @override
  String get saveSelection => '保存选区';

  @override
  String get noBookmarks => '这本书还没有书签。';

  @override
  String get noNotes => '这本书还没有笔记。';

  @override
  String get deleteNote => '删除笔记';

  @override
  String get deleteBookmark => '删除书签';

  @override
  String get searchInBook => '在这本书里搜索';

  @override
  String get searchInBookHint => '搜索这本书';

  @override
  String get noSearchResults => '没有找到匹配的内容。';

  @override
  String get scanFolder => '扫描文件夹';

  @override
  String get scanFolderHint => '本机服务上的文件夹路径';

  @override
  String get webdavUrl => 'WebDAV 地址';

  @override
  String get webdavUser => 'WebDAV 用户名';

  @override
  String get webdavPassword => 'WebDAV 密码';

  @override
  String get importFromWebdav => '从 WebDAV 导入';

  @override
  String get syncWebdav => '双向同步 WebDAV';

  @override
  String get watchFolder => '监视文件夹';

  @override
  String get librarySources => '书库来源';

  @override
  String get providerDeepSeek => 'DeepSeek';

  @override
  String get providerOllama => 'Ollama';

  @override
  String get tableOfContents => '目录';

  @override
  String get readingSettings => '阅读设置';

  @override
  String get bodyFontSize => '正文字号';

  @override
  String get bodyLineHeight => '行距';

  @override
  String get bodyFontFamily => '正文字体';

  @override
  String get fontSerif => '衬线';

  @override
  String get fontSans => '无衬线';

  @override
  String get fontMono => '等宽';

  @override
  String get readingPaper => '纸张';

  @override
  String get readingPaperFollow => '跟随应用';

  @override
  String get comicLayout => '漫画阅读';

  @override
  String get comicLayoutSingle => '单页';

  @override
  String get comicLayoutDouble => '双页';

  @override
  String get comicLayoutVertical => '竖滑';

  @override
  String get comicReadRtl => '从右到左';

  @override
  String get pdfZoom => '页面缩放';

  @override
  String get preferences => '偏好';

  @override
  String get appearance => '外观';

  @override
  String get theme => '主题';

  @override
  String get themeLight => '浅色';

  @override
  String get themeDark => '深色';

  @override
  String get themeSystem => '跟随系统';

  @override
  String get language => '语言';

  @override
  String get languageChinese => '中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageSystem => '跟随系统';

  @override
  String get readingAssistant => '阅读助手';

  @override
  String get enableAssistant => '启用阅读助手';

  @override
  String get enableAssistantSubtitle => '默认关闭。关闭时阅读页不会请求任何模型。';

  @override
  String get endpointLabel => '接口地址';

  @override
  String get modelLabel => '模型';

  @override
  String get modelHint => 'deepseek-chat';

  @override
  String get apiKeyLabel => 'API Key';

  @override
  String get apiKeyHint => '仅保存在本机，也可通过项目编译参数提供';

  @override
  String get assistantProvider => '模型服务';

  @override
  String get assistantPrivacyNote =>
      '启用后会把当前摘录发给 DeepSeek。不上整本书，也不上传书库。问答记录按书保存在本机。接口地址和模型可在本页或项目编译参数中配置。';

  @override
  String get assistantGatewayNote =>
      '当前由本机服务转发 DeepSeek 请求，避免浏览器跨域。不会使用客户端填写的接口地址。密钥可填在这里，或由服务端环境变量提供。';

  @override
  String get apiKeyOptionalHint => '本机服务已配置密钥，可留空';

  @override
  String get conversationHistory => '问答记录';

  @override
  String get conversationUnavailable => '无法读取问答记录。';

  @override
  String get defaultImportLocation => '默认导入位置';

  @override
  String get defaultImportLocationSubtitle => '由系统文件选择器管理';

  @override
  String get localFirstStorage => '本地优先存储';

  @override
  String get localFirstStorageSubtitle => '阅读进度和标注保存在本设备';

  @override
  String get sendExcerptHint => '将发送当前章节摘录，不上整本书。';

  @override
  String sendExcerptHintLocated(String locator) {
    return '定位：$locator。将发送当前摘录，不上整本书。';
  }

  @override
  String get summarize => '总结';

  @override
  String get explain => '解释';

  @override
  String get translate => '翻译';

  @override
  String get ask => '提问';

  @override
  String get askQuestionHint => '输入关于这一页的问题';

  @override
  String get readingExcerpt => '正在读取当前摘录…';

  @override
  String get sending => '发送中…';

  @override
  String get sendExcerpt => '发送摘录';

  @override
  String get enableAssistantInSettings => '到设置中启用阅读助手';

  @override
  String requestFailed(String error) {
    return '请求失败：$error';
  }

  @override
  String get assistantDisabled => '阅读助手未启用。可在设置中打开。';

  @override
  String get assistantNotConfigured => '请先填写 DeepSeek API Key。';

  @override
  String get noExcerpt => '当前页没有可发送的摘录。';

  @override
  String pageNumber(int page) {
    return '第 $page 页';
  }

  @override
  String textOffset(int offset) {
    return '偏移 $offset';
  }

  @override
  String get readerLoading => '正在打开…';

  @override
  String get untitledSection => '正文';

  @override
  String readerSection(int current, int total) {
    return '$current / $total';
  }

  @override
  String readerUnavailable(String format) {
    return '$format 阅读器尚未接入。当前可以阅读 TXT、Markdown、HTML、EPUB、PDF、漫画、MOBI/AZW3 和 FB2。';
  }

  @override
  String get readerMissingFile => '找不到这本书的原文件。';

  @override
  String get readerCorruptFile => '这本书的文件已损坏，无法打开。';

  @override
  String get readerTruncated => '文件较大，仅显示开头部分。';
}
