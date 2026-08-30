import 'package:app/core/fb2_document.dart';
import 'package:app/core/models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fb2_fixture.dart';

void main() {
  test('opens fictionbook chapters from the xml body', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-1',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: minimalFb2Bytes(),
    );
    expect(document.currentChapterText, contains('hello from fb2'));
    expect(document.parsed.title, 'FB2 Book');
    expect(document.parsed.author, 'Ann Author');
    expect(document.currentChapterHtml, contains('hello from fb2'));
  });

  test('title-info annotation becomes the first chapter', () async {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-title-info-annotation',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2TitleInfoAnnotationBytes(),
    );
    expect(document.chapterCount, 2);
    expect(document.currentChapterHref, 'annotation');
    expect(document.currentChapterTitle, 'blurb');
    expect(document.currentChapterHtml, contains('<aside>'));
    expect(document.currentChapterHtml, contains('<p>blurb</p>'));
    expect(document.currentChapterText, contains('blurb'));
    expect(document.parsed.chapters.last.href, 'section-0');
    expect(document.parsed.chapters.last.text, contains('hello from fb2'));
    final toc = await document.getToc();
    expect(toc.first.title, 'blurb');
    expect((toc.first.locator as EpubLocator).href, 'annotation');
    final hits = await document.search('blurb');
    expect(hits, hasLength(1));
    expect((hits.single.locator as EpubLocator).href, 'annotation');
    await document.goTo(const EpubLocator(href: 'section-0'));
    expect(document.currentChapterText, contains('hello from fb2'));
  });

  test('an empty title-info annotation does not invent a blurb chapter', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-empty-title-info-annotation',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2TitleInfoAnnotationBytes(
        titleInfoAnnotation: '<annotation></annotation>',
      ),
    );
    expect(document.chapterCount, 1);
    expect(document.currentChapterHref, 'section-0');
    expect(document.currentChapterHtml, isNot(contains('<aside>')));
  });

  test('a src-title-info annotation is not a blurb chapter', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-src-title-info-annotation',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2TitleInfoAnnotationBytes(
        titleInfoAnnotation: null,
        srcTitleInfoAnnotation: '<annotation><p>other blurb</p></annotation>',
      ),
    );
    expect(document.chapterCount, 1);
    expect(document.currentChapterHref, 'section-0');
    expect(document.currentChapterHtml, isNot(contains('<aside>')));
    expect(document.currentChapterText, isNot(contains('other blurb')));
  });

  test('nested section titles appear under the parent in the toc', () async {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-nested-toc',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2NestedSectionBytes(),
    );
    expect(document.chapterCount, 2);
    final toc = await document.getToc();
    expect(toc, hasLength(1));
    expect(toc.single.title, 'Part I');
    expect((toc.single.locator as EpubLocator).href, 'section-0');
    expect(toc.single.children, hasLength(1));
    expect(toc.single.children.single.title, 'Chapter One');
    expect(
      (toc.single.children.single.locator as EpubLocator).href,
      'section-1',
    );
    await document.goTo(toc.single.children.single.locator);
    expect(document.currentChapterText, contains('hello from fb2'));
    expect(document.currentChapterHref, 'section-1');
  });

  test('an untitled wrapper section does not appear in the toc', () async {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-untitled-wrapper',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2NestedSectionBytes(parentTitle: false),
    );
    expect(document.chapterCount, 1);
    final toc = await document.getToc();
    expect(toc, hasLength(1));
    expect(toc.single.title, 'Chapter One');
    expect(toc.single.children, isEmpty);
    expect((toc.single.locator as EpubLocator).href, 'section-0');
  });

  test('a notes body is a toc group at the end', () async {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-notes-body',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2NotesBodyBytes(),
    );
    expect(document.chapterCount, 2);
    expect(document.parsed.chapters.first.href, 'section-0');
    expect(document.parsed.chapters.last.href, 'section-1');
    final toc = await document.getToc();
    expect(toc, hasLength(2));
    expect(toc.first.title, 'Chapter One');
    expect(toc.first.children, isEmpty);
    expect((toc.first.locator as EpubLocator).href, 'section-0');
    expect(toc.last.title, 'Notes');
    expect(toc.last.children, hasLength(1));
    expect(toc.last.children.single.title, '1');
    expect((toc.last.children.single.locator as EpubLocator).href, 'section-1');
    await document.goTo(toc.last.children.single.locator);
    expect(document.currentChapterHref, 'section-1');
    expect(document.currentChapterText, contains('footnote'));
  });

  test('a comments body is a separate toc group from notes', () async {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-comments-body',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2NotesBodyBytes(commentsBody: true),
    );
    expect(document.chapterCount, 3);
    final toc = await document.getToc();
    expect(toc, hasLength(3));
    expect(toc[0].title, 'Chapter One');
    expect(toc[1].title, 'Notes');
    expect(toc[1].children.single.title, '1');
    expect(toc[2].title, 'Comments');
    expect(toc[2].children.single.title, 'Remark');
    expect((toc[2].children.single.locator as EpubLocator).href, 'section-2');
    await document.goTo(toc[2].children.single.locator);
    expect(document.currentChapterText, contains('a comment'));
  });

  test('an empty notes body does not add a toc group', () async {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-empty-notes-body',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2NotesBodyBytes(notesSection: false),
    );
    expect(document.chapterCount, 1);
    final toc = await document.getToc();
    expect(toc, hasLength(1));
    expect(toc.single.title, 'Chapter One');
    expect(toc.single.children, isEmpty);
  });

  test('opens a body without a section as a chapter', () async {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-body-without-section',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2BodyWithoutSectionBytes(),
    );
    expect(document.chapterCount, 1);
    expect(document.currentChapterHref, 'section-0');
    expect(document.currentChapterText, contains('hello from fb2'));
    expect(document.currentChapterHtml, contains('<p>hello from fb2</p>'));
    final toc = await document.getToc();
    expect(toc, hasLength(1));
    expect((toc.single.locator as EpubLocator).href, 'section-0');
  });

  test('a body with a section does not also emit body-level paragraphs', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-body-with-section-and-paragraph',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2BodyWithoutSectionBytes(
        inner: '''
      <p>stray intro</p>
      <section>
        <title><p>Chapter One</p></title>
        <p>hello from fb2</p>
      </section>''',
      ),
    );
    expect(document.chapterCount, 1);
    expect(document.currentChapterHref, 'section-0');
    expect(document.currentChapterText, contains('hello from fb2'));
    expect(document.currentChapterText, isNot(contains('stray intro')));
    expect(document.parsed.chapters, hasLength(1));
  });

  test('a second body without a section is still a chapter', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-second-body-without-section',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2BodyWithoutSectionBytes(
        inner: '''
      <section>
        <title><p>Chapter One</p></title>
        <p>hello from fb2</p>
      </section>''',
        secondInner: '<p>more fb2</p>',
      ),
    );
    expect(document.chapterCount, 2);
    expect(document.parsed.chapters.first.href, 'section-0');
    expect(document.parsed.chapters.last.href, 'section-1');
    expect(document.parsed.chapters.last.text, contains('more fb2'));
    expect(document.parsed.chapters.first.text, isNot(contains('more fb2')));
  });

  test('a body without a section keeps order before a later section', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-loose-body-before-section',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2BodyWithoutSectionBytes(
        inner: '<p>hello from fb2</p>',
        secondInner: '''
      <section>
        <title><p>Chapter Two</p></title>
        <p>later</p>
      </section>''',
      ),
    );
    expect(document.chapterCount, 2);
    expect(document.parsed.chapters.first.href, 'section-0');
    expect(document.parsed.chapters.first.text, contains('hello from fb2'));
    expect(document.parsed.chapters.last.href, 'section-1');
    expect(document.parsed.chapters.last.text, contains('later'));
  });

  test('an empty body without a section stays corrupt', () {
    expect(
      () => Fb2ReaderDocument.parse(
        metadata: const DocumentMetadata(
          id: 'fb2-empty-body-without-section',
          title: 'Local',
          author: 'Local',
          format: DocumentFormat.fb2,
          type: DocumentType.reflow,
        ),
        bytes: fb2BodyWithoutSectionBytes(inner: ''),
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('a notes body without a section stays corrupt', () {
    expect(
      () => Fb2ReaderDocument.parse(
        metadata: const DocumentMetadata(
          id: 'fb2-notes-without-section',
          title: 'Local',
          author: 'Local',
          format: DocumentFormat.fb2,
          type: DocumentType.reflow,
        ),
        bytes: fb2BodyWithoutSectionBytes(
          inner: '<p>footnote</p>',
          notesOnly: true,
        ),
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('an unnamed second body stays in the main toc', () async {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-unnamed-second-body',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2NotesBodyBytes(notesBody: false, unnamedSecondBody: true),
    );
    expect(document.chapterCount, 2);
    final toc = await document.getToc();
    expect(toc, hasLength(2));
    expect(toc[0].title, 'Chapter One');
    expect(toc[0].children, isEmpty);
    expect(toc[1].title, 'Chapter Two');
    expect(toc[1].children, isEmpty);
    expect((toc[1].locator as EpubLocator).href, 'section-1');
  });

  test('a hash link to a notes body section points at that chapter', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-notes-body-link',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2NotesBodyBytes(),
    );
    expect(
      document.parsed.chapters.first.html,
      contains('<a href="section-1#n1">world</a>'),
    );
    expect(document.parsed.chapters.last.html, contains('<section id="n1">'));
  });

  test('chapter html inlines a binary image', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-img',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: illustratedFb2Bytes(),
    );
    expect(document.currentChapterHtml, contains('data:image/png'));
    expect(document.currentChapterHtml, contains('<img'));
    expect(document.currentChapterHtml, contains('hello from fb2'));
    expect(document.currentChapterText, contains('hello from fb2'));
  });

  test('a missing fb2 image stays missing', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-missing-img',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: illustratedFb2Bytes(includeBinary: false),
    );
    expect(document.currentChapterHtml, isNot(contains('data:image')));
    expect(document.currentChapterHtml, isNot(contains('<img')));
    expect(document.currentChapterText, contains('hello from fb2'));
  });

  test('a titled fb2 image section still opens without a paragraph', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-plate',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: illustratedFb2Bytes(includeParagraph: false),
    );
    expect(document.currentChapterHtml, contains('data:image/png'));
    expect(document.currentChapterHtml, contains('Chapter One'));
    expect(document.currentChapterText, contains('Chapter One'));
  });

  test('chapter html keeps emphasis', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-em',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: markedFb2Bytes('hello <emphasis>world</emphasis>'),
    );
    expect(document.currentChapterHtml, contains('<em>world</em>'));
    expect(document.currentChapterHtml, contains('hello'));
    expect(document.currentChapterText, contains('hello'));
    expect(document.currentChapterText, contains('world'));
  });

  test('chapter html keeps strong', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-strong',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: markedFb2Bytes('hello <strong>world</strong>'),
    );
    expect(document.currentChapterHtml, contains('<strong>world</strong>'));
    expect(document.currentChapterHtml, contains('hello'));
    expect(document.currentChapterText, contains('world'));
  });

  test('chapter html keeps strikethrough', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-strike',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: markedFb2Bytes('hello <strikethrough>world</strikethrough>'),
    );
    expect(document.currentChapterHtml, contains('<s>world</s>'));
    expect(document.currentChapterHtml, contains('hello'));
    expect(document.currentChapterText, contains('hello'));
    expect(document.currentChapterText, contains('world'));
  });

  test('chapter html drops empty strikethrough', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-empty-strike',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: markedFb2Bytes('hello<strikethrough></strikethrough>world'),
    );
    expect(document.currentChapterHtml, contains('<p>helloworld</p>'));
    expect(document.currentChapterHtml, isNot(contains('<s>')));
  });

  test('chapter html keeps sub', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-sub',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: markedFb2Bytes('H<sub>2</sub>O'),
    );
    expect(document.currentChapterHtml, contains('<sub>2</sub>'));
    expect(document.currentChapterHtml, contains('H'));
    expect(document.currentChapterHtml, contains('O'));
    expect(document.currentChapterText, contains('H'));
    expect(document.currentChapterText, contains('2'));
    expect(document.currentChapterText, contains('O'));
  });

  test('chapter html keeps sup', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-sup',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: markedFb2Bytes('x<sup>2</sup>'),
    );
    expect(document.currentChapterHtml, contains('<sup>2</sup>'));
    expect(document.currentChapterHtml, contains('x'));
    expect(document.currentChapterText, contains('x'));
    expect(document.currentChapterText, contains('2'));
  });

  test('chapter html drops empty sub', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-empty-sub',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: markedFb2Bytes('H<sub></sub>O'),
    );
    expect(document.currentChapterHtml, contains('<p>HO</p>'));
    expect(document.currentChapterHtml, isNot(contains('<sub>')));
  });

  test('chapter html keeps code', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-code',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: markedFb2Bytes('use <code>print</code> it'),
    );
    expect(document.currentChapterHtml, contains('<code>print</code>'));
    expect(document.currentChapterHtml, contains('use'));
    expect(document.currentChapterHtml, contains('it'));
    expect(document.currentChapterText, contains('print'));
  });

  test('chapter html drops empty code', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-empty-code',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: markedFb2Bytes('hello<code></code>world'),
    );
    expect(document.currentChapterHtml, contains('<p>helloworld</p>'));
    expect(document.currentChapterHtml, isNot(contains('<code>')));
  });

  test('chapter html keeps an internal hash link', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-hash-link',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: markedFb2Bytes('hello <a l:href="#n1">world</a>'),
    );
    expect(document.currentChapterHtml, contains('<a href="#n1">world</a>'));
    expect(document.currentChapterHtml, contains('hello'));
    expect(document.currentChapterText, contains('hello'));
    expect(document.currentChapterText, contains('world'));
  });

  test('chapter html drops an external link href', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-ext-link',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: markedFb2Bytes(
        'hello <a l:href="https://example.invalid/x">world</a>',
      ),
    );
    expect(document.currentChapterHtml, contains('world'));
    expect(document.currentChapterHtml, isNot(contains('href="https')));
    expect(document.currentChapterHtml, isNot(contains('example.invalid')));
    expect(document.currentChapterText, contains('world'));
  });

  test('chapter html drops empty hash links', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-empty-link',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: markedFb2Bytes('hello<a l:href="#n1"></a>world'),
    );
    expect(document.currentChapterHtml, contains('<p>helloworld</p>'));
    expect(document.currentChapterHtml, isNot(contains('<a ')));
  });

  test('chapter html copies a section id', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-section-id',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2SectionMarkupBytes('<p>hello from fb2</p>', id: 'n1'),
    );
    expect(document.currentChapterHtml, contains('<section id="n1">'));
    expect(document.currentChapterHtml, contains('hello from fb2'));
  });

  test('chapter html copies a paragraph id', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-p-id',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2SectionMarkupBytes('<p id="n1">hello from fb2</p>'),
    );
    expect(document.currentChapterHtml, contains('<p id="n1">'));
    expect(document.currentChapterHtml, contains('hello from fb2'));
  });

  test('chapter html keeps an empty named anchor', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-a-id',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2SectionMarkupBytes('<p><a id="n1"/>hello from fb2</p>'),
    );
    expect(document.currentChapterHtml, contains('<span id="n1"></span>'));
    expect(document.currentChapterHtml, contains('hello from fb2'));
    expect(document.currentChapterHtml, isNot(contains('<a ')));
  });

  test('a hash link to another section points at that chapter', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-note-link',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2NoteLinkBytes(),
    );
    expect(document.chapterCount, 2);
    expect(
      document.parsed.chapters.first.html,
      contains('<a href="section-1#n1">world</a>'),
    );
    expect(document.parsed.chapters.last.html, contains('<section id="n1">'));
    expect(document.parsed.chapters.first.text, contains('world'));
    expect(document.parsed.chapters.last.text, contains('footnote'));
  });

  test('a hash link without a section id stays a fragment', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-missing-note',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2NoteLinkBytes(includeTarget: false),
    );
    expect(document.chapterCount, 1);
    expect(document.currentChapterHtml, contains('<a href="#n1">world</a>'));
    expect(document.currentChapterHtml, isNot(contains('section-1')));
  });

  test('a hash link to a paragraph id points at that chapter', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-p-note-link',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2ParagraphNoteLinkBytes(),
    );
    expect(document.chapterCount, 2);
    expect(
      document.parsed.chapters.first.html,
      contains('<a href="section-1#n1">world</a>'),
    );
    expect(document.parsed.chapters.last.html, contains('<p id="n1">'));
    expect(document.parsed.chapters.last.html, isNot(contains('<section id=')));
    expect(document.parsed.chapters.last.text, contains('footnote'));
  });

  test('chapter html keeps an empty line between paragraphs', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-empty-line',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2SectionMarkupBytes('<p>hello</p><empty-line/><p>world</p>'),
    );
    expect(document.currentChapterHtml, contains('<p>hello</p>'));
    expect(document.currentChapterHtml, contains('<p>world</p>'));
    expect(document.currentChapterHtml, contains('<p><br/></p>'));
    expect(document.currentChapterText, contains('hello'));
    expect(document.currentChapterText, contains('world'));
  });

  test('chapter html keeps a subtitle that can be searched', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-subtitle',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2SectionMarkupBytes(
        '<subtitle>Part Two</subtitle><p>hello from fb2</p>',
      ),
    );
    expect(document.currentChapterHtml, contains('<h2>Part Two</h2>'));
    expect(document.currentChapterHtml, contains('hello from fb2'));
    expect(document.currentChapterText, contains('Part Two'));
    expect(document.currentChapterText, contains('hello from fb2'));
  });

  test('chapter html keeps poem lines', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-poem',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2SectionMarkupBytes(
        '<poem><title><p>Night</p></title><stanza><v>line one</v><v>line two</v></stanza></poem><p>hello from fb2</p>',
      ),
    );
    expect(document.currentChapterHtml, contains('<blockquote>'));
    expect(document.currentChapterHtml, contains('<h3>Night</h3>'));
    expect(document.currentChapterHtml, contains('line one'));
    expect(document.currentChapterHtml, contains('line two'));
    expect(document.currentChapterHtml, contains('<br/>'));
    expect(document.currentChapterHtml, contains('hello from fb2'));
    expect(document.currentChapterText, contains('line one'));
    expect(document.currentChapterText, contains('line two'));
    expect(document.currentChapterText, contains('hello from fb2'));
  });

  test('a poem-only section still opens', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-poem-only',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2SectionMarkupBytes(
        '<poem><stanza><v>line one</v><v>line two</v></stanza></poem>',
        chapterTitle: '',
      ),
    );
    expect(document.currentChapterHtml, contains('line one'));
    expect(document.currentChapterHtml, contains('line two'));
    expect(document.currentChapterText, contains('line one'));
  });

  test('chapter html keeps a poem subtitle', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-poem-subtitle',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2SectionMarkupBytes(
        '<poem><title><p>Night</p></title><subtitle><p>a lyric</p></subtitle><stanza><v>line one</v></stanza></poem>',
      ),
    );
    expect(document.currentChapterHtml, contains('<h3>Night</h3>'));
    expect(document.currentChapterHtml, contains('<h4>a lyric</h4>'));
    expect(document.currentChapterHtml, contains('line one'));
    expect(document.currentChapterText, contains('a lyric'));
  });

  test('an empty poem subtitle does not invent a heading', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-empty-poem-subtitle',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2SectionMarkupBytes(
        '<poem><subtitle></subtitle><stanza><v>line one</v></stanza></poem>',
      ),
    );
    expect(document.currentChapterHtml, contains('line one'));
    expect(document.currentChapterHtml, isNot(contains('<h4>')));
  });

  test('chapter html keeps an epigraph inside a poem', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-poem-epigraph',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2SectionMarkupBytes(
        '<poem><epigraph><p>quoted line</p><text-author>Ann</text-author></epigraph><stanza><v>line one</v></stanza></poem>',
      ),
    );
    expect(document.currentChapterHtml, contains('<blockquote>'));
    expect(document.currentChapterHtml, contains('quoted line'));
    expect(document.currentChapterHtml, contains('Ann'));
    expect(document.currentChapterHtml, contains('line one'));
    expect(document.currentChapterText, contains('quoted line'));
    expect(document.currentChapterText, contains('Ann'));
    expect(document.currentChapterText, contains('line one'));
  });

  test('chapter html keeps a poem text-author', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-poem-author',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2SectionMarkupBytes(
        '<poem><stanza><v>line one</v></stanza><text-author>Pushkin</text-author></poem>',
      ),
    );
    expect(document.currentChapterHtml, contains('line one'));
    expect(document.currentChapterHtml, contains('<p>Pushkin</p>'));
    expect(document.currentChapterText, contains('Pushkin'));
    expect(document.currentChapterText, contains('line one'));
  });

  test('an empty poem text-author does not invent a byline', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-empty-poem-author',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2SectionMarkupBytes(
        '<poem><stanza><v>line one</v></stanza><text-author></text-author></poem>',
      ),
    );
    expect(document.currentChapterHtml, contains('line one'));
    expect(document.currentChapterHtml, isNot(contains('<p></p>')));
  });

  test('chapter html keeps a poem date', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-poem-date',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2SectionMarkupBytes(
        '<poem><stanza><v>line one</v></stanza><date>1825</date></poem>',
      ),
    );
    expect(document.currentChapterHtml, contains('line one'));
    expect(document.currentChapterHtml, contains('<p>1825</p>'));
    expect(document.currentChapterText, contains('1825'));
    expect(document.currentChapterText, contains('line one'));
  });

  test('an empty poem date does not invent a year', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-empty-poem-date',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2SectionMarkupBytes(
        '<poem><stanza><v>line one</v></stanza><date></date></poem>',
      ),
    );
    expect(document.currentChapterHtml, contains('line one'));
    expect(document.currentChapterHtml, isNot(contains('<p></p>')));
  });

  test('chapter html keeps a poem date value when the body is empty', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-poem-date-value',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2SectionMarkupBytes(
        '<poem><stanza><v>line one</v></stanza><date value="1825"/></poem>',
      ),
    );
    expect(document.currentChapterHtml, contains('line one'));
    expect(document.currentChapterHtml, contains('<p>1825</p>'));
  });

  test('a poem date body wins over the value attribute', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-poem-date-body',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2SectionMarkupBytes(
        '<poem><stanza><v>line one</v></stanza><date value="1824">1825</date></poem>',
      ),
    );
    expect(document.currentChapterHtml, contains('<p>1825</p>'));
    expect(document.currentChapterHtml, isNot(contains('1824')));
  });

  test('chapter html keeps a stanza title', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-stanza-title',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2SectionMarkupBytes(
        '<poem><stanza><title><p>I</p></title><v>line one</v></stanza></poem>',
      ),
    );
    expect(document.currentChapterHtml, contains('<h4>I</h4>'));
    expect(document.currentChapterHtml, contains('line one'));
    expect(document.currentChapterText, contains('I'));
    expect(document.currentChapterText, contains('line one'));
  });

  test('chapter html keeps a stanza subtitle', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-stanza-subtitle',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2SectionMarkupBytes(
        '<poem><stanza><subtitle><p>softly</p></subtitle><v>line one</v></stanza></poem>',
      ),
    );
    expect(document.currentChapterHtml, contains('<h5>softly</h5>'));
    expect(document.currentChapterHtml, contains('line one'));
    expect(document.currentChapterText, contains('softly'));
  });

  test('an empty stanza title does not invent a heading', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-empty-stanza-title',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2SectionMarkupBytes(
        '<poem><stanza><title></title><v>line one</v></stanza></poem>',
      ),
    );
    expect(document.currentChapterHtml, contains('line one'));
    expect(document.currentChapterHtml, isNot(contains('<h4>')));
  });

  test('chapter html keeps an epigraph', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-epigraph',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2SectionMarkupBytes(
        '<epigraph><p>quoted line</p><text-author>Ann</text-author></epigraph><p>hello from fb2</p>',
      ),
    );
    expect(document.currentChapterHtml, contains('<blockquote>'));
    expect(document.currentChapterHtml, contains('quoted line'));
    expect(document.currentChapterHtml, contains('Ann'));
    expect(document.currentChapterHtml, contains('hello from fb2'));
    expect(document.currentChapterText, contains('quoted line'));
    expect(document.currentChapterText, contains('Ann'));
  });

  test('chapter html keeps a cite', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-cite',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2SectionMarkupBytes(
        '<cite><p>cited line</p><text-author>Ann</text-author></cite><p>hello from fb2</p>',
      ),
    );
    expect(document.currentChapterHtml, contains('<blockquote>'));
    expect(document.currentChapterHtml, contains('cited line'));
    expect(document.currentChapterHtml, contains('Ann'));
    expect(document.currentChapterText, contains('cited line'));
    expect(document.currentChapterText, contains('hello from fb2'));
  });

  test('chapter html keeps empty-line and subtitle in a cite', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-cite-inner',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2SectionMarkupBytes(
        '<cite><subtitle><p>Note</p></subtitle><p>quoted</p><empty-line/></cite><p>hello from fb2</p>',
      ),
    );
    expect(document.currentChapterHtml, contains('<blockquote>'));
    expect(document.currentChapterHtml, contains('<h2>Note</h2>'));
    expect(document.currentChapterHtml, contains('<p>quoted</p>'));
    expect(document.currentChapterHtml, contains('<p><br/></p>'));
    expect(document.currentChapterText, contains('Note'));
    expect(document.currentChapterText, contains('quoted'));
  });

  test('chapter html keeps empty-line and subtitle in an epigraph', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-epigraph-inner',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2SectionMarkupBytes(
        '<epigraph><subtitle><p>Note</p></subtitle><p>quoted line</p><empty-line/></epigraph><p>hello from fb2</p>',
      ),
    );
    expect(document.currentChapterHtml, contains('<blockquote>'));
    expect(document.currentChapterHtml, contains('<h2>Note</h2>'));
    expect(document.currentChapterHtml, contains('<p>quoted line</p>'));
    expect(document.currentChapterHtml, contains('<p><br/></p>'));
    expect(document.currentChapterText, contains('Note'));
    expect(document.currentChapterText, contains('quoted line'));
  });

  test('an empty cite subtitle does not invent a heading', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-empty-cite-subtitle',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2SectionMarkupBytes(
        '<cite><subtitle></subtitle><p>quoted</p></cite><p>hello from fb2</p>',
      ),
    );
    expect(document.currentChapterHtml, contains('<blockquote>'));
    expect(document.currentChapterHtml, contains('<p>quoted</p>'));
    expect(document.currentChapterHtml, isNot(contains('<h2>')));
  });

  test('chapter html keeps a poem in a cite', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-cite-poem',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2SectionMarkupBytes(
        '<cite><p>quoted</p><poem><stanza><v>line one</v></stanza></poem></cite><p>hello from fb2</p>',
      ),
    );
    expect(document.currentChapterHtml, contains('<blockquote>'));
    expect(document.currentChapterHtml, contains('<p>quoted</p>'));
    expect(document.currentChapterHtml, contains('line one'));
    expect(document.currentChapterText, contains('line one'));
  });

  test('chapter html keeps a table in a cite', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-cite-table',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2SectionMarkupBytes(
        '<cite><p>quoted</p><table><tr><td><p>alpha</p></td></tr></table></cite><p>hello from fb2</p>',
      ),
    );
    expect(document.currentChapterHtml, contains('<blockquote>'));
    expect(document.currentChapterHtml, contains('<table>'));
    expect(document.currentChapterHtml, contains('<td>alpha</td>'));
    expect(document.currentChapterText, contains('alpha'));
  });

  test('chapter html keeps a poem in an epigraph', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-epigraph-poem',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2SectionMarkupBytes(
        '<epigraph><p>quoted line</p><poem><stanza><v>line one</v></stanza></poem></epigraph><p>hello from fb2</p>',
      ),
    );
    expect(document.currentChapterHtml, contains('<blockquote>'));
    expect(document.currentChapterHtml, contains('<p>quoted line</p>'));
    expect(document.currentChapterHtml, contains('line one'));
    expect(document.currentChapterText, contains('line one'));
  });

  test('an empty table in a cite does not invent a grid', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-cite-empty-table',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2SectionMarkupBytes(
        '<cite><p>quoted</p><table></table></cite><p>hello from fb2</p>',
      ),
    );
    expect(document.currentChapterHtml, contains('<blockquote>'));
    expect(document.currentChapterHtml, contains('<p>quoted</p>'));
    expect(document.currentChapterHtml, isNot(contains('<table>')));
  });

  test('chapter html keeps a cite inside an epigraph', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-epigraph-cite',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2SectionMarkupBytes(
        '<epigraph><p>quoted line</p><cite><p>inner</p></cite></epigraph><p>hello from fb2</p>',
      ),
    );
    expect(
      document.currentChapterHtml,
      contains(
        '<blockquote><p>quoted line</p><blockquote><p>inner</p></blockquote></blockquote>',
      ),
    );
    expect(document.currentChapterText, contains('quoted line'));
    expect(document.currentChapterText, contains('inner'));
  });

  test('an empty cite inside an epigraph does not invent a quote', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-epigraph-empty-cite',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2SectionMarkupBytes(
        '<epigraph><p>quoted line</p><cite></cite></epigraph><p>hello from fb2</p>',
      ),
    );
    expect(
      document.currentChapterHtml,
      contains('<blockquote><p>quoted line</p></blockquote>'),
    );
    expect(document.currentChapterHtml, isNot(contains('<p>inner</p>')));
  });

  test('chapter html keeps a section annotation', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-annotation',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2SectionMarkupBytes(
        '<annotation><p>blurb</p></annotation><p>hello from fb2</p>',
      ),
    );
    expect(document.currentChapterHtml, contains('<aside>'));
    expect(document.currentChapterHtml, contains('<p>blurb</p>'));
    expect(document.currentChapterHtml, contains('hello from fb2'));
    expect(document.currentChapterText, contains('blurb'));
    expect(document.currentChapterText, contains('hello from fb2'));
  });

  test('an annotation-only section still opens', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-annotation-only',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2SectionMarkupBytes(
        '<annotation><p>blurb</p></annotation>',
        chapterTitle: '',
      ),
    );
    expect(document.currentChapterHtml, contains('<aside>'));
    expect(document.currentChapterHtml, contains('<p>blurb</p>'));
    expect(document.currentChapterText, contains('blurb'));
  });

  test('an empty annotation does not invent a blurb', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-empty-annotation',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2SectionMarkupBytes(
        '<annotation></annotation><p>hello from fb2</p>',
      ),
    );
    expect(document.currentChapterHtml, contains('hello from fb2'));
    expect(document.currentChapterHtml, isNot(contains('<aside>')));
  });

  test('chapter html keeps cite empty-line and subtitle in an annotation', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-annotation-inner',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2SectionMarkupBytes(
        '<annotation><subtitle><p>Note</p></subtitle><p>blurb</p><empty-line/><cite><p>quoted</p></cite></annotation><p>hello from fb2</p>',
      ),
    );
    expect(document.currentChapterHtml, contains('<aside>'));
    expect(document.currentChapterHtml, contains('<h2>Note</h2>'));
    expect(document.currentChapterHtml, contains('<p>blurb</p>'));
    expect(document.currentChapterHtml, contains('<p><br/></p>'));
    expect(document.currentChapterHtml, contains('<blockquote>'));
    expect(document.currentChapterHtml, contains('quoted'));
    expect(document.currentChapterHtml, contains('hello from fb2'));
    expect(document.currentChapterText, contains('Note'));
    expect(document.currentChapterText, contains('quoted'));
  });

  test('chapter html keeps a poem in an annotation', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-annotation-poem',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2SectionMarkupBytes(
        '<annotation><p>blurb</p><poem><stanza><v>line one</v></stanza></poem></annotation><p>hello from fb2</p>',
      ),
    );
    expect(document.currentChapterHtml, contains('<aside>'));
    expect(document.currentChapterHtml, contains('<p>blurb</p>'));
    expect(document.currentChapterHtml, contains('<blockquote>'));
    expect(document.currentChapterHtml, contains('line one'));
    expect(document.currentChapterText, contains('line one'));
  });

  test('chapter html keeps a table in an annotation', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-annotation-table',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2SectionMarkupBytes(
        '<annotation><p>blurb</p><table><tr><td><p>alpha</p></td></tr></table></annotation><p>hello from fb2</p>',
      ),
    );
    expect(document.currentChapterHtml, contains('<aside>'));
    expect(document.currentChapterHtml, contains('<table>'));
    expect(document.currentChapterHtml, contains('<td>alpha</td>'));
    expect(document.currentChapterText, contains('alpha'));
  });

  test('an empty table in an annotation does not invent a grid', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-annotation-empty-table',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2SectionMarkupBytes(
        '<annotation><p>blurb</p><table></table></annotation><p>hello from fb2</p>',
      ),
    );
    expect(document.currentChapterHtml, contains('<aside>'));
    expect(document.currentChapterHtml, contains('<p>blurb</p>'));
    expect(document.currentChapterHtml, isNot(contains('<table>')));
  });

  test('chapter html keeps a table', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-table',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2SectionMarkupBytes(
        '<table><tr><td><p>alpha</p></td><td><p>beta</p></td></tr></table><p>hello from fb2</p>',
      ),
    );
    expect(document.currentChapterHtml, contains('<table>'));
    expect(document.currentChapterHtml, contains('<td>alpha</td>'));
    expect(document.currentChapterHtml, contains('<td>beta</td>'));
    expect(document.currentChapterHtml, contains('hello from fb2'));
    expect(document.currentChapterText, contains('alpha'));
    expect(document.currentChapterText, contains('beta'));
    expect(document.currentChapterText, contains('hello from fb2'));
  });

  test('a table-only section still opens', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-table-only',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2SectionMarkupBytes(
        '<table><tr><td><p>alpha</p></td></tr></table>',
        chapterTitle: '',
      ),
    );
    expect(document.currentChapterHtml, contains('<td>alpha</td>'));
    expect(document.currentChapterText, contains('alpha'));
  });

  test('an empty table does not invent cells', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-empty-table',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2SectionMarkupBytes('<table></table><p>hello from fb2</p>'),
    );
    expect(document.currentChapterHtml, contains('hello from fb2'));
    expect(document.currentChapterHtml, isNot(contains('<table>')));
    expect(document.currentChapterHtml, isNot(contains('<td>')));
  });

  test('chapter html keeps a table caption', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-table-caption',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2SectionMarkupBytes(
        '<table><title><p>Rates</p></title><tr><td><p>alpha</p></td></tr></table><p>hello from fb2</p>',
      ),
    );
    expect(document.currentChapterHtml, contains('<caption>Rates</caption>'));
    expect(document.currentChapterHtml, contains('<td>alpha</td>'));
    expect(document.currentChapterText, contains('Rates'));
    expect(document.currentChapterText, contains('alpha'));
  });

  test('an empty table title does not invent a caption', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-empty-caption',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2SectionMarkupBytes(
        '<table><title></title><tr><td><p>alpha</p></td></tr></table><p>hello from fb2</p>',
      ),
    );
    expect(document.currentChapterHtml, contains('<td>alpha</td>'));
    expect(document.currentChapterHtml, isNot(contains('<caption>')));
  });

  test('chapter html keeps table colspan', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-colspan',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2SectionMarkupBytes(
        '<table><tr><td colspan="2"><p>alpha</p></td></tr></table><p>hello from fb2</p>',
      ),
    );
    expect(document.currentChapterHtml, contains('<td colspan="2">alpha</td>'));
    expect(document.currentChapterText, contains('alpha'));
  });

  test('chapter html keeps table rowspan', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-rowspan',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2SectionMarkupBytes(
        '<table><tr><td rowspan="2"><p>alpha</p></td><td><p>beta</p></td></tr></table>',
      ),
    );
    expect(document.currentChapterHtml, contains('rowspan="2"'));
    expect(document.currentChapterHtml, contains('alpha'));
    expect(document.currentChapterHtml, contains('beta'));
  });

  test('an invalid table colspan is not copied', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-bad-colspan',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2SectionMarkupBytes(
        '<table><tr><td colspan="x"><p>alpha</p></td></tr></table><p>hello from fb2</p>',
      ),
    );
    expect(document.currentChapterHtml, contains('<td>alpha</td>'));
    expect(document.currentChapterHtml, isNot(contains('colspan=')));
  });

  test('chapter html keeps table align', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-align',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2SectionMarkupBytes(
        '<table><tr><td align="center"><p>alpha</p></td></tr></table><p>hello from fb2</p>',
      ),
    );
    expect(
      document.currentChapterHtml,
      contains('<td align="center">alpha</td>'),
    );
    expect(document.currentChapterText, contains('alpha'));
  });

  test('chapter html keeps table valign', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-valign',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2SectionMarkupBytes(
        '<table><tr><td valign="top"><p>alpha</p></td></tr></table>',
      ),
    );
    expect(document.currentChapterHtml, contains('valign="top"'));
    expect(document.currentChapterHtml, contains('alpha'));
  });

  test('an invalid table align is not copied', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-bad-align',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2SectionMarkupBytes(
        '<table><tr><td align="justify"><p>alpha</p></td></tr></table><p>hello from fb2</p>',
      ),
    );
    expect(document.currentChapterHtml, contains('<td>alpha</td>'));
    expect(document.currentChapterHtml, isNot(contains('align=')));
  });

  test('rejects xml that is not a fictionbook', () {
    expect(
      () => Fb2ReaderDocument.parse(
        metadata: const DocumentMetadata(
          id: 'fb2-bad',
          title: 'x',
          author: 'x',
          format: DocumentFormat.fb2,
          type: DocumentType.reflow,
        ),
        bytes: '<not-fb2/>'.codeUnits,
      ),
      throwsA(isA<FormatException>()),
    );
  });
}
