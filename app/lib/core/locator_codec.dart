import 'dart:convert';

import 'models.dart';

const locatorSchemaVersion = 1;

String encodeLocator(Locator locator) {
  return switch (locator) {
    EpubLocator(:final href, :final cfi, :final progression, :final fragment) =>
      [
        'epub',
        href,
        if (cfi != null && cfi.isNotEmpty) 'cfi=$cfi',
        if (progression != null) 'p=$progression',
        if (fragment != null && fragment.isNotEmpty) 'f=$fragment',
      ].join('|'),
    PdfLocator(:final page) => 'pdf|$page',
    ComicLocator(:final page) => 'comic|$page',
    TextLocator(:final offset) => 'text|$offset',
  };
}

Locator? decodeLocator(String label) {
  final parts = label.split('|');
  if (parts.isEmpty || parts.first.isEmpty) return null;
  switch (parts.first) {
    case 'epub':
      if (parts.length < 2) return null;
      String? cfi;
      double? progression;
      String? fragment;
      for (final part in parts.skip(2)) {
        if (part.startsWith('cfi=')) cfi = part.substring(4);
        if (part.startsWith('p=')) {
          progression = double.tryParse(part.substring(2));
        }
        if (part.startsWith('f=')) fragment = part.substring(2);
      }
      return EpubLocator(
        href: parts[1],
        cfi: cfi,
        progression: progression,
        fragment: fragment,
      );
    case 'pdf':
      if (parts.length < 2) return null;
      final page = int.tryParse(parts[1]);
      return page == null ? null : PdfLocator(page: page);
    case 'comic':
      if (parts.length < 2) return null;
      final page = int.tryParse(parts[1]);
      return page == null ? null : ComicLocator(page: page);
    case 'text':
      if (parts.length < 2) return null;
      final offset = int.tryParse(parts[1]);
      return offset == null ? null : TextLocator(offset: offset);
    default:
      return null;
  }
}

Map<String, Object?> locatorToJson(Locator locator) {
  return {
    'version': locatorSchemaVersion,
    ...switch (locator) {
      EpubLocator(
        :final href,
        :final cfi,
        :final progression,
        :final fragment,
      ) =>
        {
          'kind': 'epub',
          'href': href,
          if (cfi != null && cfi.isNotEmpty) 'cfi': cfi,
          if (progression != null && progression.isFinite)
            'progression': progression,
          if (fragment != null && fragment.isNotEmpty) 'fragment': fragment,
        },
      PdfLocator(:final page, :final x, :final y) => {
        'kind': 'pdf',
        'page': page,
        if (x != null && x.isFinite) 'x': x,
        if (y != null && y.isFinite) 'y': y,
      },
      ComicLocator(:final page) => {'kind': 'comic', 'page': page},
      TextLocator(:final offset) => {'kind': 'text', 'offset': offset},
    },
  };
}

String encodeLocatorJson(Locator locator) => jsonEncode(locatorToJson(locator));

Locator? decodeLocatorJson(String value) {
  try {
    return locatorFromJson(jsonDecode(value));
  } on FormatException {
    return null;
  }
}

Locator? locatorFromJson(Object? value) {
  if (value is! Map) return null;
  final version = (value['version'] as num?)?.toInt();
  if (version != locatorSchemaVersion) return null;
  return switch (value['kind']) {
    'epub' => _epubLocatorFromJson(value),
    'pdf' => _pageLocatorFromJson(value, pdf: true),
    'comic' => _pageLocatorFromJson(value, pdf: false),
    'text' => _textLocatorFromJson(value),
    _ => null,
  };
}

EpubLocator? _epubLocatorFromJson(Map value) {
  final href = value['href'];
  if (href is! String || href.isEmpty) return null;
  final cfi = value['cfi'];
  final fragment = value['fragment'];
  final progression = value['progression'];
  if (cfi != null && cfi is! String) return null;
  if (fragment != null && fragment is! String) return null;
  if (progression != null &&
      (progression is! num || !progression.toDouble().isFinite)) {
    return null;
  }
  return EpubLocator(
    href: href,
    cfi: cfi as String?,
    progression: (progression as num?)?.toDouble(),
    fragment: fragment as String?,
  );
}

Locator? _pageLocatorFromJson(Map value, {required bool pdf}) {
  final page = value['page'];
  if (page is! int) return null;
  if (!pdf) return ComicLocator(page: page);
  final x = value['x'];
  final y = value['y'];
  if (x != null && (x is! num || !x.toDouble().isFinite)) return null;
  if (y != null && (y is! num || !y.toDouble().isFinite)) return null;
  return PdfLocator(
    page: page,
    x: (x as num?)?.toDouble(),
    y: (y as num?)?.toDouble(),
  );
}

TextLocator? _textLocatorFromJson(Map value) {
  final offset = value['offset'];
  return offset is int ? TextLocator(offset: offset) : null;
}
