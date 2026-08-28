export 'generated/app_localizations.dart';

import 'generated/app_localizations.dart';

extension LibraryStrings on AppLocalizations {
  String authorLabel(String author) {
    if (author.isEmpty || author == '本地文件' || author == '本地书库') {
      return localLibraryAuthor;
    }
    return author;
  }

  String sectionTitle(String section) => switch (section) {
    'reading' => currentlyReading,
    'favorites' => favorites,
    _ => allBooks,
  };
}
