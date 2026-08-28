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
  String get tableOfContents => 'Contents';

  @override
  String get readingSettings => 'Reading settings';

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
  String get modelHint => 'llama3.1 or gpt-4o-mini';

  @override
  String get apiKeyLabel => 'API key (optional)';

  @override
  String get apiKeyHint => 'Stored on this device only';

  @override
  String get assistantPrivacyNote =>
      'Only the current excerpt is sent to your OpenAI-compatible endpoint, such as local Ollama. The full book and library are not uploaded.';

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
      'Add an endpoint and model name in Settings first.';

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
}
