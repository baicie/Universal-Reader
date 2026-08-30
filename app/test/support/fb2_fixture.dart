import 'dart:convert';

import 'image_fixture.dart';

String minimalFb2Source({
  String title = 'FB2 Book',
  String authorFirst = 'Ann',
  String authorLast = 'Author',
  String chapterTitle = 'Chapter One',
  String body = 'hello from fb2',
}) {
  return '''<?xml version="1.0" encoding="utf-8"?>
<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0">
  <description>
    <title-info>
      <book-title>$title</book-title>
      <author><first-name>$authorFirst</first-name><last-name>$authorLast</last-name></author>
    </title-info>
  </description>
  <body>
    <section>
      <title><p>$chapterTitle</p></title>
      <p>$body</p>
    </section>
  </body>
</FictionBook>
''';
}

List<int> minimalFb2Bytes({
  String title = 'FB2 Book',
  String authorFirst = 'Ann',
  String authorLast = 'Author',
  String chapterTitle = 'Chapter One',
  String body = 'hello from fb2',
}) {
  return utf8.encode(
    minimalFb2Source(
      title: title,
      authorFirst: authorFirst,
      authorLast: authorLast,
      chapterTitle: chapterTitle,
      body: body,
    ),
  );
}

List<int> illustratedFb2Bytes({
  bool includeBinary = true,
  bool includeParagraph = true,
}) {
  final binary = includeBinary
      ? '<binary id="spot.png" content-type="image/png">${base64Encode(tinyPngBytes())}</binary>'
      : '';
  final paragraph = includeParagraph ? '<p>hello from fb2</p>' : '';
  return utf8.encode('''<?xml version="1.0" encoding="utf-8"?>
<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0" xmlns:l="http://www.w3.org/1999/xlink">
  <description>
    <title-info>
      <book-title>FB2 Book</book-title>
      <author><first-name>Ann</first-name><last-name>Author</last-name></author>
    </title-info>
  </description>
  <body>
    <section>
      <title><p>Chapter One</p></title>
      $paragraph
      <image l:href="#spot.png"/>
    </section>
  </body>
  $binary
</FictionBook>
''');
}

List<int> markedFb2Bytes(String paragraphInner, {String stylesheet = ''}) {
  final sheet = stylesheet.isEmpty
      ? ''
      : '<stylesheet type="text/css">$stylesheet</stylesheet>';
  return utf8.encode('''<?xml version="1.0" encoding="utf-8"?>
<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0" xmlns:l="http://www.w3.org/1999/xlink">
  $sheet
  <description>
    <title-info>
      <book-title>FB2 Book</book-title>
      <author><first-name>Ann</first-name><last-name>Author</last-name></author>
    </title-info>
  </description>
  <body>
    <section>
      <title><p>Chapter One</p></title>
      <p>$paragraphInner</p>
    </section>
  </body>
</FictionBook>
''');
}

List<int> fb2SectionMarkupBytes(
  String markup, {
  String chapterTitle = 'Chapter One',
  String titleStyle = '',
  String id = '',
  String stylesheet = '',
}) {
  final styleAttr = titleStyle.isEmpty ? '' : ' style="$titleStyle"';
  final title = chapterTitle.isEmpty
      ? ''
      : '<title$styleAttr><p>$chapterTitle</p></title>';
  final idAttr = id.isEmpty ? '' : ' id="$id"';
  final sheet = stylesheet.isEmpty
      ? ''
      : '<stylesheet type="text/css">$stylesheet</stylesheet>';
  return utf8.encode('''<?xml version="1.0" encoding="utf-8"?>
<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0" xmlns:l="http://www.w3.org/1999/xlink">
  $sheet
  <description>
    <title-info>
      <book-title>FB2 Book</book-title>
      <author><first-name>Ann</first-name><last-name>Author</last-name></author>
    </title-info>
  </description>
  <body>
    <section$idAttr>
      $title
      $markup
    </section>
  </body>
</FictionBook>
''');
}

List<int> fb2NoteLinkBytes({bool includeTarget = true}) {
  final notes = includeTarget
      ? '''
    <section id="n1">
      <title><p>Notes</p></title>
      <p>footnote</p>
    </section>'''
      : '';
  return utf8.encode('''<?xml version="1.0" encoding="utf-8"?>
<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0" xmlns:l="http://www.w3.org/1999/xlink">
  <description>
    <title-info>
      <book-title>FB2 Book</book-title>
      <author><first-name>Ann</first-name><last-name>Author</last-name></author>
    </title-info>
  </description>
  <body>
    <section>
      <title><p>Chapter One</p></title>
      <p>see <a l:href="#n1">world</a></p>
    </section>
    $notes
  </body>
</FictionBook>
''');
}

List<int> fb2ParagraphNoteLinkBytes() {
  return utf8.encode('''<?xml version="1.0" encoding="utf-8"?>
<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0" xmlns:l="http://www.w3.org/1999/xlink">
  <description>
    <title-info>
      <book-title>FB2 Book</book-title>
      <author><first-name>Ann</first-name><last-name>Author</last-name></author>
    </title-info>
  </description>
  <body>
    <section>
      <title><p>Chapter One</p></title>
      <p>see <a l:href="#n1">world</a></p>
    </section>
    <section>
      <title><p>Notes</p></title>
      <p id="n1">footnote</p>
    </section>
  </body>
</FictionBook>
''');
}

List<int> fb2CoverpageBytes({
  String? coverHref = '#spot.png',
  String binaryId = 'spot.png',
  bool includeBinary = true,
}) {
  final coverpage = coverHref == null
      ? ''
      : '<coverpage><image l:href="$coverHref"/></coverpage>';
  final binary = includeBinary
      ? '<binary id="$binaryId" content-type="image/png">${base64Encode(tinyPngBytes())}</binary>'
      : '';
  return utf8.encode('''<?xml version="1.0" encoding="utf-8"?>
<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0" xmlns:l="http://www.w3.org/1999/xlink">
  <description>
    <title-info>
      <book-title>FB2 Book</book-title>
      <author><first-name>Ann</first-name><last-name>Author</last-name></author>
      $coverpage
    </title-info>
  </description>
  <body>
    <section>
      <title><p>Chapter One</p></title>
      <p>hello from fb2</p>
    </section>
  </body>
  $binary
</FictionBook>
''');
}

List<int> fb2TitleInfoAnnotationBytes({
  String? titleInfoAnnotation = '<annotation><p>blurb</p></annotation>',
  String? srcTitleInfoAnnotation,
}) {
  final src = srcTitleInfoAnnotation == null
      ? ''
      : '<src-title-info>$srcTitleInfoAnnotation</src-title-info>';
  return utf8.encode('''<?xml version="1.0" encoding="utf-8"?>
<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0">
  <description>
    <title-info>
      <book-title>FB2 Book</book-title>
      <author><first-name>Ann</first-name><last-name>Author</last-name></author>
      ${titleInfoAnnotation ?? ''}
    </title-info>
    $src
  </description>
  <body>
    <section>
      <title><p>Chapter One</p></title>
      <p>hello from fb2</p>
    </section>
  </body>
</FictionBook>
''');
}

List<int> fb2NestedSectionBytes({bool parentTitle = true}) {
  final title = parentTitle ? '<title><p>Part I</p></title>' : '';
  return utf8.encode('''<?xml version="1.0" encoding="utf-8"?>
<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0">
  <description>
    <title-info>
      <book-title>FB2 Book</book-title>
      <author><first-name>Ann</first-name><last-name>Author</last-name></author>
    </title-info>
  </description>
  <body>
    <section>
      $title
      <section>
        <title><p>Chapter One</p></title>
        <p>hello from fb2</p>
      </section>
    </section>
  </body>
</FictionBook>
''');
}

List<int> fb2NotesBodyBytes({
  bool notesBody = true,
  bool notesSection = true,
  bool notesLoose = false,
  String? notesTitle = 'Notes',
  bool commentsBody = false,
  bool commentsLoose = false,
  String? commentsTitle = 'Comments',
  bool unnamedSecondBody = false,
}) {
  final notesTitleXml = notesTitle == null
      ? ''
      : '<title><p>$notesTitle</p></title>';
  final notes = !notesBody
      ? ''
      : notesLoose
      ? '''
  <body name="notes">
    $notesTitleXml
    <p id="n1">footnote</p>
  </body>'''
      : notesSection
      ? '''
  <body name="notes">
    $notesTitleXml
    <section id="n1">
      <title><p>1</p></title>
      <p>footnote</p>
    </section>
  </body>'''
      : '''
  <body name="notes"></body>''';
  final commentsTitleXml = commentsTitle == null
      ? ''
      : '<title><p>$commentsTitle</p></title>';
  final comments = commentsLoose
      ? '''
  <body name="comments">
    $commentsTitleXml
    <p>a comment</p>
  </body>'''
      : !commentsBody
      ? ''
      : '''
  <body name="comments">
    $commentsTitleXml
    <section>
      <title><p>Remark</p></title>
      <p>a comment</p>
    </section>
  </body>''';
  final second = !unnamedSecondBody
      ? ''
      : '''
  <body>
    <section>
      <title><p>Chapter Two</p></title>
      <p>more fb2</p>
    </section>
  </body>''';
  return utf8.encode('''<?xml version="1.0" encoding="utf-8"?>
<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0" xmlns:l="http://www.w3.org/1999/xlink">
  <description>
    <title-info>
      <book-title>FB2 Book</book-title>
      <author><first-name>Ann</first-name><last-name>Author</last-name></author>
    </title-info>
  </description>
  <body>
    <section>
      <title><p>Chapter One</p></title>
      <p>see <a l:href="#n1">world</a></p>
    </section>
  </body>
  $notes
  $comments
  $second
</FictionBook>
''');
}

List<int> fb2BodyWithoutSectionBytes({
  String inner = '<p>hello from fb2</p>',
  String? secondInner,
  bool notesOnly = false,
}) {
  final main = notesOnly
      ? ''
      : '''
  <body>
    $inner
  </body>''';
  final notes = !notesOnly
      ? ''
      : '''
  <body name="notes">
    $inner
  </body>''';
  final second = secondInner == null
      ? ''
      : '''
  <body>
    $secondInner
  </body>''';
  return utf8.encode('''<?xml version="1.0" encoding="utf-8"?>
<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0" xmlns:l="http://www.w3.org/1999/xlink">
  <description>
    <title-info>
      <book-title>FB2 Book</book-title>
      <author><first-name>Ann</first-name><last-name>Author</last-name></author>
    </title-info>
  </description>
  $main
  $notes
  $second
</FictionBook>
''');
}

List<int> fb2BodyEpigraphBytes({
  String lead =
      '<epigraph><p>quoted line</p><text-author>Ann</text-author></epigraph>',
  bool notesLead = false,
  bool notesImage = false,
  bool notesPoem = false,
  bool notesTable = false,
  bool notesTitle = false,
  bool notesParagraph = false,
  bool secondSection = false,
  bool includeBinary = false,
  String stylesheet = '',
}) {
  final extra = secondSection
      ? '''
    <section>
      <title><p>Chapter Two</p></title>
      <p>later</p>
    </section>'''
      : '';
  final notes = notesImage
      ? '''
  <body name="notes">
    <image l:href="#spot.png"/>
    <section>
      <title><p>1</p></title>
      <p>footnote</p>
    </section>
  </body>'''
      : notesPoem
      ? '''
  <body name="notes">
    <poem><stanza><v>note verse</v></stanza></poem>
    <section>
      <title><p>1</p></title>
      <p>footnote</p>
    </section>
  </body>'''
      : notesTable
      ? '''
  <body name="notes">
    <table><tr><td><p>note cell</p></td></tr></table>
    <section>
      <title><p>1</p></title>
      <p>footnote</p>
    </section>
  </body>'''
      : notesTitle
      ? '''
  <body name="notes">
    <title><p>Notes Volume</p></title>
    <section>
      <title><p>1</p></title>
      <p>footnote</p>
    </section>
  </body>'''
      : notesParagraph
      ? '''
  <body name="notes">
    <p>note intro</p>
    <section>
      <title><p>1</p></title>
      <p>footnote</p>
    </section>
  </body>'''
      : !notesLead
      ? ''
      : '''
  <body name="notes">
    <epigraph><p>note motto</p></epigraph>
    <section>
      <title><p>1</p></title>
      <p>footnote</p>
    </section>
  </body>''';
  final mainLead =
      (notesLead ||
          notesImage ||
          notesPoem ||
          notesTable ||
          notesTitle ||
          notesParagraph)
      ? ''
      : lead;
  final binary = includeBinary || notesImage
      ? '<binary id="spot.png" content-type="image/png">${base64Encode(tinyPngBytes())}</binary>'
      : '';
  final sheet = stylesheet.isEmpty
      ? ''
      : '<stylesheet type="text/css">$stylesheet</stylesheet>';
  return utf8.encode('''<?xml version="1.0" encoding="utf-8"?>
<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0" xmlns:l="http://www.w3.org/1999/xlink">
  $sheet
  <description>
    <title-info>
      <book-title>FB2 Book</book-title>
      <author><first-name>Ann</first-name><last-name>Author</last-name></author>
    </title-info>
  </description>
  <body>
    $mainLead
    <section>
      <title><p>Chapter One</p></title>
      <p>hello from fb2</p>
    </section>
    $extra
  </body>
  $notes
  $binary
</FictionBook>
''');
}
