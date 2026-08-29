import 'dart:convert';

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
