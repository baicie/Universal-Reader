import 'package:app/core/locator_codec.dart';
import 'package:app/core/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('encodeLocator', () {
    test('encodes an EpubLocator with only the href', () {
      expect(
        encodeLocator(const EpubLocator(href: 'OEBPS/chapter1.xhtml')),
        'epub|OEBPS/chapter1.xhtml',
      );
    });

    test('encodes an EpubLocator with cfi, progression, and fragment', () {
      expect(
        encodeLocator(
          const EpubLocator(
            href: 'OEBPS/chapter1.xhtml',
            cfi: '/6/4[chap01ref]',
            progression: 0.42,
            fragment: 'note-1',
          ),
        ),
        'epub|OEBPS/chapter1.xhtml|cfi=/6/4[chap01ref]|p=0.42|f=note-1',
      );
    });

    test('omits the cfi token when cfi is null or empty', () {
      expect(
        encodeLocator(
          const EpubLocator(
            href: 'a.xhtml',
            cfi: '',
            progression: 0.1,
          ),
        ),
        'epub|a.xhtml|p=0.1',
      );
      expect(
        encodeLocator(const EpubLocator(href: 'a.xhtml')),
        'epub|a.xhtml',
      );
    });

    test('omits the fragment token when fragment is null or empty', () {
      expect(
        encodeLocator(
          const EpubLocator(href: 'a.xhtml', cfi: 'cfi', fragment: ''),
        ),
        'epub|a.xhtml|cfi=cfi',
      );
    });

    test('still emits progression=0 because 0 is non-null', () {
      // `progression` is a `double`, so 0 serializes as "0.0".
      expect(
        encodeLocator(
          const EpubLocator(href: 'a.xhtml', progression: 0),
        ),
        'epub|a.xhtml|p=0.0',
      );
    });

    test('encodes a PdfLocator with just the page number', () {
      expect(encodeLocator(const PdfLocator(page: 12)), 'pdf|12');
    });

    test('encodes a ComicLocator with just the page number', () {
      expect(encodeLocator(const ComicLocator(page: 7)), 'comic|7');
    });

    test('encodes a TextLocator with the byte offset', () {
      expect(encodeLocator(const TextLocator(offset: 1024)), 'text|1024');
    });
  });

  group('decodeLocator', () {
    test('decodes an EpubLocator that only has href', () {
      final decoded = decodeLocator('epub|OEBPS/chapter1.xhtml');
      expect(decoded, isA<EpubLocator>());
      final epub = decoded as EpubLocator;
      expect(epub.href, 'OEBPS/chapter1.xhtml');
      expect(epub.cfi, isNull);
      expect(epub.progression, isNull);
      expect(epub.fragment, isNull);
    });

    test('decodes an EpubLocator with cfi, progression, and fragment', () {
      final decoded = decodeLocator(
        'epub|OEBPS/chapter1.xhtml|cfi=/6/4[chap01ref]|p=0.42|f=note-1',
      );
      expect(decoded, isA<EpubLocator>());
      final epub = decoded as EpubLocator;
      expect(epub.href, 'OEBPS/chapter1.xhtml');
      expect(epub.cfi, '/6/4[chap01ref]');
      expect(epub.progression, 0.42);
      expect(epub.fragment, 'note-1');
    });

    test('decodes a PdfLocator with the page number', () {
      final decoded = decodeLocator('pdf|12');
      expect(decoded, isA<PdfLocator>());
      expect((decoded as PdfLocator).page, 12);
    });

    test('decodes a ComicLocator with the page number', () {
      final decoded = decodeLocator('comic|7');
      expect(decoded, isA<ComicLocator>());
      expect((decoded as ComicLocator).page, 7);
    });

    test('decodes a TextLocator with the byte offset', () {
      final decoded = decodeLocator('text|1024');
      expect(decoded, isA<TextLocator>());
      expect((decoded as TextLocator).offset, 1024);
    });

    test('round-trips an EpubLocator that only has href', () {
      const original = EpubLocator(href: 'OEBPS/chapter1.xhtml');
      final decoded = decodeLocator(encodeLocator(original));
      expect(decoded, isA<EpubLocator>());
      final epub = decoded as EpubLocator;
      expect(epub.href, original.href);
      expect(epub.cfi, original.cfi);
      expect(epub.progression, original.progression);
      expect(epub.fragment, original.fragment);
    });

    test('round-trips an EpubLocator with cfi, progression, and fragment', () {
      const original = EpubLocator(
        href: 'OEBPS/chapter1.xhtml',
        cfi: '/6/4[chap01ref]',
        progression: 0.42,
        fragment: 'note-1',
      );
      final decoded = decodeLocator(encodeLocator(original));
      expect(decoded, isA<EpubLocator>());
      final epub = decoded as EpubLocator;
      expect(epub.href, original.href);
      expect(epub.cfi, original.cfi);
      expect(epub.progression, original.progression);
      expect(epub.fragment, original.fragment);
    });

    test('round-trips a PdfLocator', () {
      const original = PdfLocator(page: 12);
      final decoded = decodeLocator(encodeLocator(original));
      expect(decoded, isA<PdfLocator>());
      expect((decoded as PdfLocator).page, original.page);
    });

    test('round-trips a ComicLocator', () {
      const original = ComicLocator(page: 7);
      final decoded = decodeLocator(encodeLocator(original));
      expect(decoded, isA<ComicLocator>());
      expect((decoded as ComicLocator).page, original.page);
    });

    test('round-trips a TextLocator', () {
      const original = TextLocator(offset: 1024);
      final decoded = decodeLocator(encodeLocator(original));
      expect(decoded, isA<TextLocator>());
      expect((decoded as TextLocator).offset, original.offset);
    });

    test('returns null for an empty string', () {
      expect(decodeLocator(''), isNull);
    });

    test('returns null for a label with an unknown kind', () {
      expect(decodeLocator('wat|3'), isNull);
    });

    test('returns null when only the kind token is present', () {
      // All four kinds require at least a second segment.
      expect(decodeLocator('epub'), isNull);
      expect(decodeLocator('pdf'), isNull);
      expect(decodeLocator('comic'), isNull);
      expect(decodeLocator('text'), isNull);
    });

    test('returns null when the PDF page segment is not an integer', () {
      expect(decodeLocator('pdf|abc'), isNull);
    });

    test('returns null when the comic page segment is not an integer', () {
      expect(decodeLocator('comic|abc'), isNull);
    });

    test('returns null when the text offset segment is not an integer', () {
      expect(decodeLocator('text|abc'), isNull);
    });

    test('drops a malformed EpubLocator progression but keeps the locator', () {
      // cfi and fragment are tolerated as-is; a malformed `p=` is simply
      // dropped rather than invalidating the whole locator.
      final decoded = decodeLocator('epub|a.xhtml|cfi=x|p=notanumber|f=y');
      expect(decoded, isA<EpubLocator>());
      final epub = decoded as EpubLocator;
      expect(epub.href, 'a.xhtml');
      expect(epub.cfi, 'x');
      expect(epub.progression, isNull);
      expect(epub.fragment, 'y');
    });

    test('round-trips an EpubLocator with progression=0', () {
      const original = EpubLocator(href: 'a.xhtml', progression: 0);
      final decoded = decodeLocator(encodeLocator(original));
      expect(decoded, isA<EpubLocator>());
      expect((decoded as EpubLocator).progression, 0);
    });

    test('tolerates an empty href segment in an EpubLocator', () {
      // The codec never rejects an empty href — it falls through.
      final decoded = decodeLocator('epub|');
      expect(decoded, isA<EpubLocator>());
      expect((decoded as EpubLocator).href, '');
    });
  });
}
