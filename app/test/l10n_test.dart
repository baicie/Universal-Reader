import 'package:app/l10n/l10n.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

AppLocalizations _stubL10n(Locale locale) => lookupAppLocalizations(locale);

void main() {
  group('LibraryStrings.authorLabel', () {
    final l10n = _stubL10n(const Locale('en'));

    test('returns the given author when it is non-empty and non-local', () {
      expect(l10n.authorLabel('Author'), 'Author');
    });

    test('returns empty for missing author (missing data stays missing)', () {
      expect(l10n.authorLabel(''), '');
    });

    test('falls back to empty for legacy seed "本地文件"', () {
      expect(l10n.authorLabel('本地文件'), '');
    });

    test('falls back to empty for injected "本地书库"', () {
      expect(l10n.authorLabel('本地书库'), '');
    });

    test(
      'preserves authors that share a substring with the local sentinel',
      () {
        // The fallback is an exact-match check; "本地文件 2" must not be
        // treated as the local library placeholder.
        expect(l10n.authorLabel('本地文件 2'), '本地文件 2');
      },
    );

    test('matches localLibraryAuthor exactly, not by prefix', () {
      // Substring-prefix should be preserved.
      expect(l10n.authorLabel('本地书库笔记'), '本地书库笔记');
    });

    test('keeps the stub reference stable across calls', () {
      // Two calls must return the same empty string for legacy seed values.
      final first = l10n.authorLabel('本地文件');
      final second = l10n.authorLabel('本地书库');
      expect(first, second);
      expect(first, '');
    });
  });

  group('LibraryStrings.sectionTitle', () {
    final l10n = _stubL10n(const Locale('en'));

    test('"reading" maps to currentlyReading', () {
      expect(l10n.sectionTitle('reading'), l10n.currentlyReading);
    });

    test('"favorites" maps to favorites', () {
      expect(l10n.sectionTitle('favorites'), l10n.favorites);
    });

    test('"collection:abc" with collectionName returns the collectionName', () {
      expect(
        l10n.sectionTitle('collection:abc', collectionName: 'My Shelf'),
        'My Shelf',
      );
    });

    test(
      '"collection:abc" without collectionName falls back to collections',
      () {
        expect(l10n.sectionTitle('collection:abc'), l10n.collections);
      },
    );

    test('unknown section maps to allBooks', () {
      expect(l10n.sectionTitle('whatever'), l10n.allBooks);
      expect(l10n.sectionTitle(''), l10n.allBooks);
    });

    test('"collection:" without an id is treated as an unknown section', () {
      // No `:` separator after `collection` → doesn't match the startsWith
      // branch and falls through to allBooks.
      expect(l10n.sectionTitle('collection'), l10n.allBooks);
    });

    test('"collection:" with empty collection name falls back gracefully', () {
      // collectionName is null → uses the collections label.
      expect(
        l10n.sectionTitle('collection:', collectionName: null),
        l10n.collections,
      );
    });

    test('"collection:xyz" ignores collectionName when section is not a '
        'collection', () {
      // collectionName must only matter for collection sections.
      expect(
        l10n.sectionTitle('reading', collectionName: 'should-be-ignored'),
        l10n.currentlyReading,
      );
    });
  });

  group('LibraryStrings with zh locale', () {
    final l10n = _stubL10n(const Locale('zh'));

    test('authorLabel returns empty for missing/legacy values in zh', () {
      expect(l10n.authorLabel(''), '');
      expect(l10n.authorLabel('本地文件'), '');
      expect(l10n.authorLabel('本地书库'), '');
    });

    test('sectionTitle maps to zh strings', () {
      expect(l10n.sectionTitle('reading'), l10n.currentlyReading);
      expect(l10n.sectionTitle('favorites'), l10n.favorites);
      expect(l10n.sectionTitle('collection:1', collectionName: '我的书架'), '我的书架');
    });
  });
}
