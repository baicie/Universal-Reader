import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('zh'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In zh, this message translates to:
  /// **'Universal Reader'**
  String get appTitle;

  /// No description provided for @openMenu.
  ///
  /// In zh, this message translates to:
  /// **'打开菜单'**
  String get openMenu;

  /// No description provided for @settings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settings;

  /// No description provided for @importBooks.
  ///
  /// In zh, this message translates to:
  /// **'导入书籍'**
  String get importBooks;

  /// No description provided for @allBooks.
  ///
  /// In zh, this message translates to:
  /// **'全部书籍'**
  String get allBooks;

  /// No description provided for @currentlyReading.
  ///
  /// In zh, this message translates to:
  /// **'正在阅读'**
  String get currentlyReading;

  /// No description provided for @favorites.
  ///
  /// In zh, this message translates to:
  /// **'收藏'**
  String get favorites;

  /// No description provided for @library.
  ///
  /// In zh, this message translates to:
  /// **'资料库'**
  String get library;

  /// No description provided for @libraryWithServer.
  ///
  /// In zh, this message translates to:
  /// **'资料库 · 本机服务'**
  String get libraryWithServer;

  /// No description provided for @bookCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 本书籍'**
  String bookCount(int count);

  /// No description provided for @toggleView.
  ///
  /// In zh, this message translates to:
  /// **'切换视图'**
  String get toggleView;

  /// No description provided for @all.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get all;

  /// No description provided for @reflow.
  ///
  /// In zh, this message translates to:
  /// **'可重排'**
  String get reflow;

  /// No description provided for @fixedLayout.
  ///
  /// In zh, this message translates to:
  /// **'固定版式'**
  String get fixedLayout;

  /// No description provided for @comic.
  ///
  /// In zh, this message translates to:
  /// **'漫画'**
  String get comic;

  /// No description provided for @sortRecent.
  ///
  /// In zh, this message translates to:
  /// **'最近阅读'**
  String get sortRecent;

  /// No description provided for @sortTitle.
  ///
  /// In zh, this message translates to:
  /// **'标题'**
  String get sortTitle;

  /// No description provided for @sortProgress.
  ///
  /// In zh, this message translates to:
  /// **'阅读进度'**
  String get sortProgress;

  /// No description provided for @continueReading.
  ///
  /// In zh, this message translates to:
  /// **'继续阅读'**
  String get continueReading;

  /// No description provided for @browse.
  ///
  /// In zh, this message translates to:
  /// **'浏览'**
  String get browse;

  /// No description provided for @collections.
  ///
  /// In zh, this message translates to:
  /// **'收藏夹'**
  String get collections;

  /// No description provided for @collectionDesign.
  ///
  /// In zh, this message translates to:
  /// **'设计与灵感'**
  String get collectionDesign;

  /// No description provided for @collectionTech.
  ///
  /// In zh, this message translates to:
  /// **'技术阅读'**
  String get collectionTech;

  /// No description provided for @addToFavorites.
  ///
  /// In zh, this message translates to:
  /// **'加入收藏'**
  String get addToFavorites;

  /// No description provided for @removeFromFavorites.
  ///
  /// In zh, this message translates to:
  /// **'取消收藏'**
  String get removeFromFavorites;

  /// No description provided for @newCollection.
  ///
  /// In zh, this message translates to:
  /// **'新建收藏夹'**
  String get newCollection;

  /// No description provided for @collectionNameHint.
  ///
  /// In zh, this message translates to:
  /// **'收藏夹名称'**
  String get collectionNameHint;

  /// No description provided for @createCollection.
  ///
  /// In zh, this message translates to:
  /// **'创建'**
  String get createCollection;

  /// No description provided for @cancelAction.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancelAction;

  /// No description provided for @deleteCollection.
  ///
  /// In zh, this message translates to:
  /// **'删除收藏夹'**
  String get deleteCollection;

  /// No description provided for @deleteFromLibrary.
  ///
  /// In zh, this message translates to:
  /// **'从书库删除'**
  String get deleteFromLibrary;

  /// No description provided for @deleteBookConfirm.
  ///
  /// In zh, this message translates to:
  /// **'删除「{title}」？原文件和该书的笔记会一起去掉，其它书不受影响。'**
  String deleteBookConfirm(String title);

  /// No description provided for @confirmDelete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get confirmDelete;

  /// No description provided for @bookActions.
  ///
  /// In zh, this message translates to:
  /// **'书籍操作'**
  String get bookActions;

  /// No description provided for @noCollections.
  ///
  /// In zh, this message translates to:
  /// **'还没有收藏夹'**
  String get noCollections;

  /// No description provided for @addToNamedCollection.
  ///
  /// In zh, this message translates to:
  /// **'添加到「{name}」'**
  String addToNamedCollection(String name);

  /// No description provided for @removeFromNamedCollection.
  ///
  /// In zh, this message translates to:
  /// **'从「{name}」移除'**
  String removeFromNamedCollection(String name);

  /// No description provided for @importFolder.
  ///
  /// In zh, this message translates to:
  /// **'导入文件夹'**
  String get importFolder;

  /// No description provided for @localFirstOffline.
  ///
  /// In zh, this message translates to:
  /// **'Local-first · 离线可用'**
  String get localFirstOffline;

  /// No description provided for @searchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索书名、作者或格式'**
  String get searchHint;

  /// No description provided for @emptyLibraryTitle.
  ///
  /// In zh, this message translates to:
  /// **'书库还是空的'**
  String get emptyLibraryTitle;

  /// No description provided for @emptyLibraryFilteredTitle.
  ///
  /// In zh, this message translates to:
  /// **'没有找到匹配的书籍'**
  String get emptyLibraryFilteredTitle;

  /// No description provided for @emptyLibraryFilteredSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'尝试更换搜索词或筛选条件。'**
  String get emptyLibraryFilteredSubtitle;

  /// No description provided for @emptyLibraryRemoteSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'点击 + 把书上传到本机服务，刷新后也会还在。'**
  String get emptyLibraryRemoteSubtitle;

  /// No description provided for @emptyLibraryLocalSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'点击 + 导入本地书籍。'**
  String get emptyLibraryLocalSubtitle;

  /// No description provided for @importedBooks.
  ///
  /// In zh, this message translates to:
  /// **'已导入 {count} 本书籍'**
  String importedBooks(int count);

  /// No description provided for @importFailed.
  ///
  /// In zh, this message translates to:
  /// **'导入失败，请确认本机服务可用'**
  String get importFailed;

  /// No description provided for @noSupportedFormat.
  ///
  /// In zh, this message translates to:
  /// **'没有识别到支持的格式'**
  String get noSupportedFormat;

  /// No description provided for @localLibraryAuthor.
  ///
  /// In zh, this message translates to:
  /// **'本地书库'**
  String get localLibraryAuthor;

  /// No description provided for @backToLibrary.
  ///
  /// In zh, this message translates to:
  /// **'返回书库'**
  String get backToLibrary;

  /// No description provided for @askThisPage.
  ///
  /// In zh, this message translates to:
  /// **'问这一页'**
  String get askThisPage;

  /// No description provided for @askThisBook.
  ///
  /// In zh, this message translates to:
  /// **'问这本书'**
  String get askThisBook;

  /// No description provided for @jumpToLocation.
  ///
  /// In zh, this message translates to:
  /// **'跳转到 {locator}'**
  String jumpToLocation(String locator);

  /// No description provided for @saveAsNote.
  ///
  /// In zh, this message translates to:
  /// **'保存为笔记'**
  String get saveAsNote;

  /// No description provided for @noteSaved.
  ///
  /// In zh, this message translates to:
  /// **'已保存为笔记。'**
  String get noteSaved;

  /// No description provided for @notesTitle.
  ///
  /// In zh, this message translates to:
  /// **'笔记'**
  String get notesTitle;

  /// No description provided for @notesUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'无法读取笔记。'**
  String get notesUnavailable;

  /// No description provided for @bookmarks.
  ///
  /// In zh, this message translates to:
  /// **'书签'**
  String get bookmarks;

  /// No description provided for @addBookmark.
  ///
  /// In zh, this message translates to:
  /// **'添加书签'**
  String get addBookmark;

  /// No description provided for @bookmarkAdded.
  ///
  /// In zh, this message translates to:
  /// **'已添加书签。'**
  String get bookmarkAdded;

  /// No description provided for @saveSelection.
  ///
  /// In zh, this message translates to:
  /// **'保存选区'**
  String get saveSelection;

  /// No description provided for @noBookmarks.
  ///
  /// In zh, this message translates to:
  /// **'这本书还没有书签。'**
  String get noBookmarks;

  /// No description provided for @noNotes.
  ///
  /// In zh, this message translates to:
  /// **'这本书还没有笔记。'**
  String get noNotes;

  /// No description provided for @deleteNote.
  ///
  /// In zh, this message translates to:
  /// **'删除笔记'**
  String get deleteNote;

  /// No description provided for @deleteBookmark.
  ///
  /// In zh, this message translates to:
  /// **'删除书签'**
  String get deleteBookmark;

  /// No description provided for @searchInBook.
  ///
  /// In zh, this message translates to:
  /// **'在这本书里搜索'**
  String get searchInBook;

  /// No description provided for @searchInBookHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索这本书'**
  String get searchInBookHint;

  /// No description provided for @noSearchResults.
  ///
  /// In zh, this message translates to:
  /// **'没有找到匹配的内容。'**
  String get noSearchResults;

  /// No description provided for @scanFolder.
  ///
  /// In zh, this message translates to:
  /// **'扫描文件夹'**
  String get scanFolder;

  /// No description provided for @scanFolderHint.
  ///
  /// In zh, this message translates to:
  /// **'本机服务上的文件夹路径'**
  String get scanFolderHint;

  /// No description provided for @webdavUrl.
  ///
  /// In zh, this message translates to:
  /// **'WebDAV 地址'**
  String get webdavUrl;

  /// No description provided for @webdavUser.
  ///
  /// In zh, this message translates to:
  /// **'WebDAV 用户名'**
  String get webdavUser;

  /// No description provided for @webdavPassword.
  ///
  /// In zh, this message translates to:
  /// **'WebDAV 密码'**
  String get webdavPassword;

  /// No description provided for @importFromWebdav.
  ///
  /// In zh, this message translates to:
  /// **'从 WebDAV 导入'**
  String get importFromWebdav;

  /// No description provided for @syncWebdav.
  ///
  /// In zh, this message translates to:
  /// **'双向同步 WebDAV'**
  String get syncWebdav;

  /// No description provided for @watchFolder.
  ///
  /// In zh, this message translates to:
  /// **'监视文件夹'**
  String get watchFolder;

  /// No description provided for @librarySources.
  ///
  /// In zh, this message translates to:
  /// **'书库来源'**
  String get librarySources;

  /// No description provided for @providerDeepSeek.
  ///
  /// In zh, this message translates to:
  /// **'DeepSeek'**
  String get providerDeepSeek;

  /// No description provided for @providerOllama.
  ///
  /// In zh, this message translates to:
  /// **'Ollama'**
  String get providerOllama;

  /// No description provided for @tableOfContents.
  ///
  /// In zh, this message translates to:
  /// **'目录'**
  String get tableOfContents;

  /// No description provided for @readingSettings.
  ///
  /// In zh, this message translates to:
  /// **'阅读设置'**
  String get readingSettings;

  /// No description provided for @bodyFontSize.
  ///
  /// In zh, this message translates to:
  /// **'正文字号'**
  String get bodyFontSize;

  /// No description provided for @bodyLineHeight.
  ///
  /// In zh, this message translates to:
  /// **'行距'**
  String get bodyLineHeight;

  /// No description provided for @bodyFontFamily.
  ///
  /// In zh, this message translates to:
  /// **'正文字体'**
  String get bodyFontFamily;

  /// No description provided for @fontSerif.
  ///
  /// In zh, this message translates to:
  /// **'衬线'**
  String get fontSerif;

  /// No description provided for @fontSans.
  ///
  /// In zh, this message translates to:
  /// **'无衬线'**
  String get fontSans;

  /// No description provided for @fontMono.
  ///
  /// In zh, this message translates to:
  /// **'等宽'**
  String get fontMono;

  /// No description provided for @readingPaper.
  ///
  /// In zh, this message translates to:
  /// **'纸张'**
  String get readingPaper;

  /// No description provided for @readingPaperFollow.
  ///
  /// In zh, this message translates to:
  /// **'跟随应用'**
  String get readingPaperFollow;

  /// No description provided for @preferences.
  ///
  /// In zh, this message translates to:
  /// **'偏好'**
  String get preferences;

  /// No description provided for @appearance.
  ///
  /// In zh, this message translates to:
  /// **'外观'**
  String get appearance;

  /// No description provided for @theme.
  ///
  /// In zh, this message translates to:
  /// **'主题'**
  String get theme;

  /// No description provided for @themeLight.
  ///
  /// In zh, this message translates to:
  /// **'浅色'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In zh, this message translates to:
  /// **'深色'**
  String get themeDark;

  /// No description provided for @themeSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get themeSystem;

  /// No description provided for @language.
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get language;

  /// No description provided for @languageChinese.
  ///
  /// In zh, this message translates to:
  /// **'中文'**
  String get languageChinese;

  /// No description provided for @languageEnglish.
  ///
  /// In zh, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get languageSystem;

  /// No description provided for @readingAssistant.
  ///
  /// In zh, this message translates to:
  /// **'阅读助手'**
  String get readingAssistant;

  /// No description provided for @enableAssistant.
  ///
  /// In zh, this message translates to:
  /// **'启用阅读助手'**
  String get enableAssistant;

  /// No description provided for @enableAssistantSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'默认关闭。关闭时阅读页不会请求任何模型。'**
  String get enableAssistantSubtitle;

  /// No description provided for @endpointLabel.
  ///
  /// In zh, this message translates to:
  /// **'接口地址'**
  String get endpointLabel;

  /// No description provided for @modelLabel.
  ///
  /// In zh, this message translates to:
  /// **'模型'**
  String get modelLabel;

  /// No description provided for @modelHint.
  ///
  /// In zh, this message translates to:
  /// **'deepseek-chat'**
  String get modelHint;

  /// No description provided for @apiKeyLabel.
  ///
  /// In zh, this message translates to:
  /// **'API Key'**
  String get apiKeyLabel;

  /// No description provided for @apiKeyHint.
  ///
  /// In zh, this message translates to:
  /// **'仅保存在本机，也可通过项目编译参数提供'**
  String get apiKeyHint;

  /// No description provided for @assistantProvider.
  ///
  /// In zh, this message translates to:
  /// **'模型服务'**
  String get assistantProvider;

  /// No description provided for @assistantPrivacyNote.
  ///
  /// In zh, this message translates to:
  /// **'启用后会把当前摘录发给 DeepSeek。不上整本书，也不上传书库。问答记录按书保存在本机。接口地址和模型可在本页或项目编译参数中配置。'**
  String get assistantPrivacyNote;

  /// No description provided for @assistantGatewayNote.
  ///
  /// In zh, this message translates to:
  /// **'当前由本机服务转发 DeepSeek 请求，避免浏览器跨域。不会使用客户端填写的接口地址。密钥可填在这里，或由服务端环境变量提供。'**
  String get assistantGatewayNote;

  /// No description provided for @apiKeyOptionalHint.
  ///
  /// In zh, this message translates to:
  /// **'本机服务已配置密钥，可留空'**
  String get apiKeyOptionalHint;

  /// No description provided for @conversationHistory.
  ///
  /// In zh, this message translates to:
  /// **'问答记录'**
  String get conversationHistory;

  /// No description provided for @conversationUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'无法读取问答记录。'**
  String get conversationUnavailable;

  /// No description provided for @defaultImportLocation.
  ///
  /// In zh, this message translates to:
  /// **'默认导入位置'**
  String get defaultImportLocation;

  /// No description provided for @defaultImportLocationSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'由系统文件选择器管理'**
  String get defaultImportLocationSubtitle;

  /// No description provided for @localFirstStorage.
  ///
  /// In zh, this message translates to:
  /// **'本地优先存储'**
  String get localFirstStorage;

  /// No description provided for @localFirstStorageSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'阅读进度和标注保存在本设备'**
  String get localFirstStorageSubtitle;

  /// No description provided for @sendExcerptHint.
  ///
  /// In zh, this message translates to:
  /// **'将发送当前章节摘录，不上整本书。'**
  String get sendExcerptHint;

  /// No description provided for @sendExcerptHintLocated.
  ///
  /// In zh, this message translates to:
  /// **'定位：{locator}。将发送当前摘录，不上整本书。'**
  String sendExcerptHintLocated(String locator);

  /// No description provided for @summarize.
  ///
  /// In zh, this message translates to:
  /// **'总结'**
  String get summarize;

  /// No description provided for @explain.
  ///
  /// In zh, this message translates to:
  /// **'解释'**
  String get explain;

  /// No description provided for @translate.
  ///
  /// In zh, this message translates to:
  /// **'翻译'**
  String get translate;

  /// No description provided for @ask.
  ///
  /// In zh, this message translates to:
  /// **'提问'**
  String get ask;

  /// No description provided for @askQuestionHint.
  ///
  /// In zh, this message translates to:
  /// **'输入关于这一页的问题'**
  String get askQuestionHint;

  /// No description provided for @readingExcerpt.
  ///
  /// In zh, this message translates to:
  /// **'正在读取当前摘录…'**
  String get readingExcerpt;

  /// No description provided for @sending.
  ///
  /// In zh, this message translates to:
  /// **'发送中…'**
  String get sending;

  /// No description provided for @sendExcerpt.
  ///
  /// In zh, this message translates to:
  /// **'发送摘录'**
  String get sendExcerpt;

  /// No description provided for @enableAssistantInSettings.
  ///
  /// In zh, this message translates to:
  /// **'到设置中启用阅读助手'**
  String get enableAssistantInSettings;

  /// No description provided for @requestFailed.
  ///
  /// In zh, this message translates to:
  /// **'请求失败：{error}'**
  String requestFailed(String error);

  /// No description provided for @assistantDisabled.
  ///
  /// In zh, this message translates to:
  /// **'阅读助手未启用。可在设置中打开。'**
  String get assistantDisabled;

  /// No description provided for @assistantNotConfigured.
  ///
  /// In zh, this message translates to:
  /// **'请先填写 DeepSeek API Key。'**
  String get assistantNotConfigured;

  /// No description provided for @noExcerpt.
  ///
  /// In zh, this message translates to:
  /// **'当前页没有可发送的摘录。'**
  String get noExcerpt;

  /// No description provided for @pageNumber.
  ///
  /// In zh, this message translates to:
  /// **'第 {page} 页'**
  String pageNumber(int page);

  /// No description provided for @textOffset.
  ///
  /// In zh, this message translates to:
  /// **'偏移 {offset}'**
  String textOffset(int offset);

  /// No description provided for @readerLoading.
  ///
  /// In zh, this message translates to:
  /// **'正在打开…'**
  String get readerLoading;

  /// No description provided for @untitledSection.
  ///
  /// In zh, this message translates to:
  /// **'正文'**
  String get untitledSection;

  /// No description provided for @readerSection.
  ///
  /// In zh, this message translates to:
  /// **'{current} / {total}'**
  String readerSection(int current, int total);

  /// No description provided for @readerUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'{format} 阅读器尚未接入。当前可以阅读 TXT、Markdown、HTML、EPUB、PDF、漫画、MOBI/AZW3 和 FB2。'**
  String readerUnavailable(String format);

  /// No description provided for @readerMissingFile.
  ///
  /// In zh, this message translates to:
  /// **'找不到这本书的原文件。'**
  String get readerMissingFile;

  /// No description provided for @readerCorruptFile.
  ///
  /// In zh, this message translates to:
  /// **'这本书的文件已损坏，无法打开。'**
  String get readerCorruptFile;

  /// No description provided for @readerTruncated.
  ///
  /// In zh, this message translates to:
  /// **'文件较大，仅显示开头部分。'**
  String get readerTruncated;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
