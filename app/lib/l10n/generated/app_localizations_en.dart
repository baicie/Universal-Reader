// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Universal Reader';

  @override
  String get openMenu => 'Open menu';

  @override
  String get settings => 'Settings';

  @override
  String get importBooks => 'Import books';

  @override
  String get allBooks => 'All books';

  @override
  String get currentlyReading => 'Reading';

  @override
  String get favorites => 'Favorites';

  @override
  String get library => 'Library';

  @override
  String get libraryWithServer => 'Library · local server';

  @override
  String bookCount(int count) {
    return '$count books';
  }

  @override
  String get toggleView => 'Toggle view';

  @override
  String get all => 'All';

  @override
  String get reflow => 'Reflow';

  @override
  String get fixedLayout => 'Fixed layout';

  @override
  String get comic => 'Comics';

  @override
  String get sortRecent => 'Recently read';

  @override
  String get sortTitle => 'Title';

  @override
  String get sortProgress => 'Progress';

  @override
  String get continueReading => 'Continue reading';

  @override
  String get browse => 'Browse';

  @override
  String get collections => 'Collections';

  @override
  String get collectionDesign => 'Design & inspiration';

  @override
  String get collectionTech => 'Technical reading';

  @override
  String get importFolder => 'Import folder';

  @override
  String get localFirstOffline => 'Local-first · works offline';

  @override
  String get searchHint => 'Search title, author, or format';

  @override
  String get emptyLibraryTitle => 'Your library is empty';

  @override
  String get emptyLibraryFilteredTitle => 'No matching books';

  @override
  String get emptyLibraryFilteredSubtitle =>
      'Try a different search or filter.';

  @override
  String get emptyLibraryRemoteSubtitle =>
      'Tap + to upload books to the local server. They stay after refresh.';

  @override
  String get emptyLibraryLocalSubtitle =>
      'Tap + to import books from this device.';

  @override
  String importedBooks(int count) {
    return 'Imported $count books';
  }

  @override
  String get importFailed =>
      'Import failed. Check that the local server is running.';

  @override
  String get noSupportedFormat => 'No supported formats found';

  @override
  String get localLibraryAuthor => 'Local library';

  @override
  String get backToLibrary => 'Back to library';

  @override
  String get askThisPage => 'Ask this page';

  @override
  String get askThisBook => 'Ask this book';

  @override
  String jumpToLocation(String locator) {
    return 'Go to $locator';
  }

  @override
  String get saveAsNote => 'Save as a note';

  @override
  String get noteSaved => 'Saved as a note.';

  @override
  String get notesTitle => 'Notes';

  @override
  String get notesUnavailable => 'Could not load notes.';

  @override
  String get bookmarks => 'Bookmarks';

  @override
  String get addBookmark => 'Add bookmark';

  @override
  String get bookmarkAdded => 'Bookmark added.';

  @override
  String get saveSelection => 'Save selection';

  @override
  String get noBookmarks => 'This book has no bookmarks yet.';

  @override
  String get scanFolder => 'Scan folder';

  @override
  String get scanFolderHint => 'Folder path on the local server';

  @override
  String get webdavUrl => 'WebDAV URL';

  @override
  String get webdavUser => 'WebDAV username';

  @override
  String get webdavPassword => 'WebDAV password';

  @override
  String get importFromWebdav => 'Import from WebDAV';

  @override
  String get syncWebdav => 'Sync WebDAV both ways';

  @override
  String get watchFolder => 'Watch folder';

  @override
  String get librarySources => 'Library sources';

  @override
  String get providerDeepSeek => 'DeepSeek';

  @override
  String get providerOllama => 'Ollama';

  @override
  String get tableOfContents => 'Contents';

  @override
  String get readingSettings => 'Reading settings';

  @override
  String get bodyFontSize => 'Body text size';

  @override
  String get preferences => 'Preferences';

  @override
  String get appearance => 'Appearance';

  @override
  String get theme => 'Theme';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeSystem => 'System';

  @override
  String get language => 'Language';

  @override
  String get languageChinese => '中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageSystem => 'System';

  @override
  String get readingAssistant => 'Reading assistant';

  @override
  String get enableAssistant => 'Enable reading assistant';

  @override
  String get enableAssistantSubtitle =>
      'Off by default. The reader will not call any model while this is off.';

  @override
  String get endpointLabel => 'Endpoint';

  @override
  String get modelLabel => 'Model';

  @override
  String get modelHint => 'deepseek-chat';

  @override
  String get apiKeyLabel => 'API key';

  @override
  String get apiKeyHint =>
      'Stored on this device, or supplied by a project build define';

  @override
  String get assistantProvider => 'Provider';

  @override
  String get assistantPrivacyNote =>
      'When enabled, the current excerpt is sent to DeepSeek. The full book and library are not uploaded. Questions and answers are remembered per book on this device. Endpoint and model can be set here or with project build defines.';

  @override
  String get assistantGatewayNote =>
      'The local server forwards DeepSeek requests, which avoids browser CORS. The client endpoint is not used. You can paste a key here or set it on the server.';

  @override
  String get apiKeyOptionalHint =>
      'The local server already has a key; this can be blank';

  @override
  String get conversationHistory => 'Conversation';

  @override
  String get conversationUnavailable => 'Could not load the conversation.';

  @override
  String get defaultImportLocation => 'Default import location';

  @override
  String get defaultImportLocationSubtitle =>
      'Managed by the system file picker';

  @override
  String get localFirstStorage => 'Local-first storage';

  @override
  String get localFirstStorageSubtitle =>
      'Reading progress and notes stay on this device';

  @override
  String get sendExcerptHint =>
      'The current chapter excerpt will be sent, not the whole book.';

  @override
  String sendExcerptHintLocated(String locator) {
    return 'Location: $locator. The current excerpt will be sent, not the whole book.';
  }

  @override
  String get summarize => 'Summarize';

  @override
  String get explain => 'Explain';

  @override
  String get translate => 'Translate';

  @override
  String get ask => 'Ask';

  @override
  String get askQuestionHint => 'Ask a question about this page';

  @override
  String get readingExcerpt => 'Reading the current excerpt…';

  @override
  String get sending => 'Sending…';

  @override
  String get sendExcerpt => 'Send excerpt';

  @override
  String get enableAssistantInSettings => 'Enable the assistant in Settings';

  @override
  String requestFailed(String error) {
    return 'Request failed: $error';
  }

  @override
  String get assistantDisabled =>
      'Reading assistant is off. Turn it on in Settings.';

  @override
  String get assistantNotConfigured =>
      'Add a DeepSeek API key in Settings first.';

  @override
  String get noExcerpt => 'This page has no excerpt to send.';

  @override
  String pageNumber(int page) {
    return 'Page $page';
  }

  @override
  String textOffset(int offset) {
    return 'Offset $offset';
  }

  @override
  String get readerLoading => 'Opening…';

  @override
  String get untitledSection => 'Text';

  @override
  String readerSection(int current, int total) {
    return '$current / $total';
  }

  @override
  String readerUnavailable(String format) {
    return '$format is not readable yet. TXT, Markdown, HTML, EPUB, PDF, comics, MOBI/AZW3, and FB2 work now.';
  }

  @override
  String get readerMissingFile =>
      'The original file for this book could not be found.';

  @override
  String get readerCorruptFile =>
      'This book file is damaged and cannot be opened.';

  @override
  String get readerTruncated =>
      'This file is large, so only the beginning is shown.';
}
