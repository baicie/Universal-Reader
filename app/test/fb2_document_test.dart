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

  test('a body paragraph does not become another chapter', () {
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
    expect(document.currentChapterText, contains('stray intro'));
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

  test(
    'a notes body without a section is a toc group after the main text',
    () async {
      final document = Fb2ReaderDocument.parse(
        metadata: const DocumentMetadata(
          id: 'fb2-notes-loose-body',
          title: 'Local',
          author: 'Local',
          format: DocumentFormat.fb2,
          type: DocumentType.reflow,
        ),
        bytes: fb2NotesBodyBytes(notesLoose: true),
      );
      expect(document.chapterCount, 2);
      expect(document.parsed.chapters.first.href, 'section-0');
      expect(document.parsed.chapters.last.href, 'section-1');
      expect(document.parsed.chapters.last.text, contains('footnote'));
      expect(
        document.parsed.chapters.first.html,
        contains('<a href="section-1#n1">world</a>'),
      );
      final toc = await document.getToc();
      expect(toc, hasLength(2));
      expect(toc.first.title, 'Chapter One');
      expect(toc.last.title, 'Notes');
      expect(toc.last.children, hasLength(1));
      expect(toc.last.children.single.title, 'footnote');
      expect(
        (toc.last.children.single.locator as EpubLocator).href,
        'section-1',
      );
      await document.goTo(toc.last.children.single.locator);
      expect(document.currentChapterHref, 'section-1');
      expect(document.currentChapterText, contains('footnote'));
    },
  );

  test('a comments body without a section is a separate toc group', () async {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-comments-loose-body',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2NotesBodyBytes(notesLoose: true, commentsLoose: true),
    );
    expect(document.chapterCount, 3);
    final toc = await document.getToc();
    expect(toc, hasLength(3));
    expect(toc[1].title, 'Notes');
    expect(toc[1].children.single.title, 'footnote');
    expect(toc[2].title, 'Comments');
    expect(toc[2].children.single.title, 'a comment');
    expect((toc[2].children.single.locator as EpubLocator).href, 'section-2');
    await document.goTo(toc[2].children.single.locator);
    expect(document.currentChapterText, contains('a comment'));
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

  test('a body epigraph stays at the start of the first chapter', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-body-epigraph',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2BodyEpigraphBytes(secondSection: true),
    );
    expect(document.chapterCount, 2);
    expect(document.currentChapterHref, 'section-0');
    expect(document.currentChapterTitle, 'Chapter One');
    final html = document.currentChapterHtml;
    expect(html, contains('<blockquote>'));
    expect(html, contains('quoted line'));
    expect(html, contains('Ann'));
    expect(html.indexOf('quoted line'), lessThan(html.indexOf('Chapter One')));
    expect(document.currentChapterText, contains('quoted line'));
    expect(document.parsed.chapters.last.html, isNot(contains('quoted line')));
    expect(document.parsed.chapters.last.text, contains('later'));
  });

  test('a body cite stays at the start of the first chapter', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-body-cite',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2BodyEpigraphBytes(
        lead: '<cite><p>cited line</p><text-author>Ann</text-author></cite>',
      ),
    );
    expect(document.currentChapterHref, 'section-0');
    expect(document.currentChapterHtml, contains('cited line'));
    expect(
      document.currentChapterHtml.indexOf('cited line'),
      lessThan(document.currentChapterHtml.indexOf('Chapter One')),
    );
    expect(document.currentChapterText, contains('cited line'));
  });

  test('an empty body epigraph does not invent a quote', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-empty-body-epigraph',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2BodyEpigraphBytes(lead: '<epigraph></epigraph>'),
    );
    expect(document.currentChapterHref, 'section-0');
    expect(document.currentChapterHtml, isNot(contains('<blockquote>')));
    expect(document.currentChapterText, contains('hello from fb2'));
  });

  test('a notes body epigraph does not join the first chapter', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-notes-body-epigraph',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2BodyEpigraphBytes(notesLead: true),
    );
    expect(document.currentChapterHref, 'section-0');
    expect(document.currentChapterHtml, isNot(contains('note motto')));
    expect(document.currentChapterText, isNot(contains('note motto')));
    expect(document.parsed.chapters.first.html, contains('hello from fb2'));
  });

  test('a body image stays at the start of the first chapter', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-body-image',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2BodyEpigraphBytes(
        lead: '<image l:href="#spot.png"/>',
        includeBinary: true,
        secondSection: true,
      ),
    );
    expect(document.currentChapterHref, 'section-0');
    final html = document.currentChapterHtml;
    expect(html, contains('<img'));
    expect(html, contains('data:image/png'));
    expect(html.indexOf('<img'), lessThan(html.indexOf('Chapter One')));
    expect(document.parsed.chapters.last.html, isNot(contains('<img')));
  });

  test('a missing body image stays missing', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-missing-body-image',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2BodyEpigraphBytes(lead: '<image l:href="#spot.png"/>'),
    );
    expect(document.currentChapterHtml, isNot(contains('data:image')));
    expect(document.currentChapterHtml, isNot(contains('<img')));
    expect(document.currentChapterText, contains('hello from fb2'));
  });

  test('a body empty-line stays at the start of the first chapter', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-body-empty-line',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2BodyEpigraphBytes(lead: '<empty-line/>'),
    );
    final html = document.currentChapterHtml;
    expect(html, contains('<p><br/></p>'));
    expect(html.indexOf('<p><br/></p>'), lessThan(html.indexOf('Chapter One')));
    expect(document.currentChapterText, contains('hello from fb2'));
  });

  test('a notes body image does not join the first chapter', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-notes-body-image',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2BodyEpigraphBytes(notesImage: true),
    );
    expect(document.currentChapterHref, 'section-0');
    expect(document.currentChapterHtml, isNot(contains('<img')));
    expect(document.currentChapterHtml, contains('hello from fb2'));
  });

  test('a body subtitle stays at the start of the first chapter', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-body-subtitle',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2BodyEpigraphBytes(lead: '<subtitle><p>Before</p></subtitle>'),
    );
    final html = document.currentChapterHtml;
    expect(html, contains('<h2>Before</h2>'));
    expect(html.indexOf('Before'), lessThan(html.indexOf('Chapter One')));
    expect(document.currentChapterText, contains('Before'));
  });

  test('an empty body subtitle does not invent a heading', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-empty-body-subtitle',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2BodyEpigraphBytes(lead: '<subtitle></subtitle>'),
    );
    expect(document.currentChapterHtml, isNot(contains('<h2>')));
    expect(document.currentChapterText, contains('hello from fb2'));
  });

  test('chapter html copies a body subtitle style', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-body-subtitle-style',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2BodyEpigraphBytes(
        lead: '<subtitle style="foreign"><p>Before</p></subtitle>',
        stylesheet: '.foreign { color: red; }',
      ),
    );
    expect(
      document.currentChapterHtml,
      contains('<h2 class="foreign">Before</h2>'),
    );
    expect(document.currentChapterHtml, isNot(contains('color: red')));
    expect(document.currentChapterText, contains('Before'));
  });

  test('an empty body subtitle style does not invent a class', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-empty-body-subtitle-style',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2BodyEpigraphBytes(
        lead: '<subtitle style=""><p>Before</p></subtitle>',
      ),
    );
    expect(document.currentChapterHtml, contains('<h2>Before</h2>'));
    expect(document.currentChapterHtml, isNot(contains('class=')));
  });

  test(
    'a body subtitle style on an empty subtitle does not invent a heading',
    () {
      final document = Fb2ReaderDocument.parse(
        metadata: const DocumentMetadata(
          id: 'fb2-empty-body-subtitle-with-style',
          title: 'Local',
          author: 'Local',
          format: DocumentFormat.fb2,
          type: DocumentType.reflow,
        ),
        bytes: fb2BodyEpigraphBytes(
          lead: '<subtitle style="foreign"></subtitle>',
        ),
      );
      expect(document.currentChapterHtml, isNot(contains('<h2>')));
      expect(document.currentChapterText, contains('hello from fb2'));
    },
  );

  test('a body poem stays at the start of the first chapter', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-body-poem',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2BodyEpigraphBytes(
        lead: '<poem><stanza><v>line one</v></stanza></poem>',
        secondSection: true,
      ),
    );
    final html = document.currentChapterHtml;
    expect(html, contains('<blockquote>'));
    expect(html, contains('line one'));
    expect(html.indexOf('line one'), lessThan(html.indexOf('Chapter One')));
    expect(document.currentChapterText, contains('line one'));
    expect(document.parsed.chapters.last.html, isNot(contains('line one')));
  });

  test('an empty body poem does not invent a quote', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-empty-body-poem',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2BodyEpigraphBytes(lead: '<poem></poem>'),
    );
    expect(document.currentChapterHtml, isNot(contains('<blockquote>')));
    expect(document.currentChapterText, contains('hello from fb2'));
  });

  test('a notes body poem does not join the first chapter', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-notes-body-poem',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2BodyEpigraphBytes(notesPoem: true),
    );
    expect(document.currentChapterHref, 'section-0');
    expect(document.currentChapterHtml, isNot(contains('note verse')));
    expect(document.currentChapterText, isNot(contains('note verse')));
    expect(document.currentChapterHtml, contains('hello from fb2'));
  });

  test('a body table stays at the start of the first chapter', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-body-table',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2BodyEpigraphBytes(
        lead: '<table><tr><td><p>alpha</p></td></tr></table>',
        secondSection: true,
      ),
    );
    final html = document.currentChapterHtml;
    expect(html, contains('<table>'));
    expect(html, contains('<td>alpha</td>'));
    expect(html.indexOf('alpha'), lessThan(html.indexOf('Chapter One')));
    expect(document.currentChapterText, contains('alpha'));
    expect(document.parsed.chapters.last.html, isNot(contains('alpha')));
  });

  test('an empty body table does not invent a grid', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-empty-body-table',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2BodyEpigraphBytes(lead: '<table></table>'),
    );
    expect(document.currentChapterHtml, isNot(contains('<table>')));
    expect(document.currentChapterText, contains('hello from fb2'));
  });

  test('a body annotation stays at the start of the first chapter', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-body-annotation',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2BodyEpigraphBytes(
        lead: '<annotation><p>blurb</p></annotation>',
      ),
    );
    final html = document.currentChapterHtml;
    expect(html, contains('<aside>'));
    expect(html, contains('blurb'));
    expect(html.indexOf('blurb'), lessThan(html.indexOf('Chapter One')));
    expect(document.currentChapterHref, 'section-0');
    expect(document.currentChapterText, contains('blurb'));
  });

  test('an empty body annotation does not invent a blurb', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-empty-body-annotation',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2BodyEpigraphBytes(lead: '<annotation></annotation>'),
    );
    expect(document.currentChapterHtml, isNot(contains('<aside>')));
    expect(document.currentChapterText, contains('hello from fb2'));
  });

  test('a notes body table does not join the first chapter', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-notes-body-table',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2BodyEpigraphBytes(notesTable: true),
    );
    expect(document.currentChapterHref, 'section-0');
    expect(document.currentChapterHtml, isNot(contains('note cell')));
    expect(document.currentChapterText, isNot(contains('note cell')));
    expect(document.currentChapterHtml, contains('hello from fb2'));
  });

  test('a body title stays at the start of the first chapter', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-body-title',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2BodyEpigraphBytes(
        lead: '<title><p>Part I</p></title>',
        secondSection: true,
      ),
    );
    final html = document.currentChapterHtml;
    expect(html, contains('<h1>Part I</h1>'));
    expect(html.indexOf('Part I'), lessThan(html.indexOf('Chapter One')));
    expect(document.currentChapterTitle, 'Chapter One');
    expect(document.currentChapterText, contains('Part I'));
    expect(document.parsed.chapters.last.html, isNot(contains('Part I')));
  });

  test('an empty body title does not invent a heading', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-empty-body-title',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2BodyEpigraphBytes(lead: '<title></title>'),
    );
    expect(document.currentChapterHtml, isNot(contains('<h1></h1>')));
    expect(document.currentChapterTitle, 'Chapter One');
    expect(document.currentChapterText, contains('hello from fb2'));
  });

  test('a notes body title does not join the first chapter', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-notes-body-title',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2BodyEpigraphBytes(notesTitle: true),
    );
    expect(document.currentChapterHref, 'section-0');
    expect(document.currentChapterTitle, 'Chapter One');
    expect(document.currentChapterHtml, isNot(contains('Notes Volume')));
    expect(document.currentChapterText, isNot(contains('Notes Volume')));
    expect(document.currentChapterHtml, contains('hello from fb2'));
  });

  test('chapter html copies a body title style', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-body-title-style',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2BodyEpigraphBytes(
        lead: '<title style="foreign"><p>Part I</p></title>',
        stylesheet: '.foreign { color: red; }',
      ),
    );
    final html = document.currentChapterHtml;
    expect(html, contains('<h1 class="foreign">Part I</h1>'));
    expect(html.indexOf('Part I'), lessThan(html.indexOf('Chapter One')));
    expect(document.currentChapterTitle, 'Chapter One');
    expect(html, isNot(contains('color: red')));
    expect(document.currentChapterText, contains('Part I'));
  });

  test('an empty body title style does not invent a class', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-empty-body-title-style',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2BodyEpigraphBytes(
        lead: '<title style=""><p>Part I</p></title>',
      ),
    );
    expect(document.currentChapterHtml, contains('<h1>Part I</h1>'));
    expect(document.currentChapterTitle, 'Chapter One');
    expect(document.currentChapterHtml, isNot(contains('class=')));
  });

  test('a body title style on an empty title does not invent a heading', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-empty-body-title-with-style',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2BodyEpigraphBytes(lead: '<title style="foreign"></title>'),
    );
    expect(document.currentChapterHtml, isNot(contains('<h1 class=')));
    expect(document.currentChapterTitle, 'Chapter One');
    expect(document.currentChapterText, contains('hello from fb2'));
  });

  test('chapter html copies a section title style', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-section-title-style',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2SectionMarkupBytes(
        '<p>hello from fb2</p>',
        titleStyle: 'foreign',
        stylesheet: '.foreign { color: red; }',
      ),
    );
    expect(
      document.currentChapterHtml,
      contains('<h1 class="foreign">Chapter One</h1>'),
    );
    expect(document.currentChapterHtml, isNot(contains('color: red')));
    expect(document.currentChapterTitle, 'Chapter One');
  });

  test('an empty section title style does not invent a class', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-empty-section-title-style',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2SectionMarkupBytes(
        '<title style=""><p>Chapter One</p></title><p>hello from fb2</p>',
        chapterTitle: '',
      ),
    );
    expect(document.currentChapterHtml, contains('<h1>Chapter One</h1>'));
    expect(document.currentChapterHtml, isNot(contains('class=')));
  });

  test('a section title style on an empty title does not invent a heading', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-empty-section-title-with-style',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2SectionMarkupBytes(
        '<title style="foreign"></title><p>hello from fb2</p>',
        chapterTitle: '',
      ),
    );
    expect(document.currentChapterHtml, contains('hello from fb2'));
    expect(document.currentChapterHtml, isNot(contains('<h1>')));
  });

  test('a body paragraph stays at the start of the first chapter', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-body-paragraph',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2BodyEpigraphBytes(
        lead: '<p>stray intro</p>',
        secondSection: true,
      ),
    );
    final html = document.currentChapterHtml;
    expect(html, contains('<p>stray intro</p>'));
    expect(html.indexOf('stray intro'), lessThan(html.indexOf('Chapter One')));
    expect(document.currentChapterText, contains('stray intro'));
    expect(document.parsed.chapters.last.html, isNot(contains('stray intro')));
  });

  test('an empty body paragraph does not invent a sentence', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-empty-body-paragraph',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2BodyEpigraphBytes(lead: '<p></p>'),
    );
    expect(document.currentChapterHtml, isNot(contains('<p></p>')));
    expect(document.currentChapterText, contains('hello from fb2'));
  });

  test('a notes body paragraph does not join the first chapter', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-notes-body-paragraph',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2BodyEpigraphBytes(notesParagraph: true),
    );
    expect(document.currentChapterHref, 'section-0');
    expect(document.currentChapterHtml, isNot(contains('note intro')));
    expect(document.currentChapterText, isNot(contains('note intro')));
    expect(document.currentChapterHtml, contains('hello from fb2'));
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

  test('chapter html keeps a named style', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-style',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: markedFb2Bytes(
        'see <style name="foreign">bonjour</style>',
        stylesheet: '.foreign { color: red; }',
      ),
    );
    expect(
      document.currentChapterHtml,
      contains('<span class="foreign">bonjour</span>'),
    );
    expect(document.currentChapterHtml, isNot(contains('color: red')));
    expect(document.currentChapterHtml, isNot(contains('<style')));
    expect(document.currentChapterText, contains('bonjour'));
  });

  test('chapter html drops empty style', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-empty-style',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: markedFb2Bytes('hello<style name="foreign"></style>world'),
    );
    expect(document.currentChapterHtml, contains('<p>helloworld</p>'));
    expect(document.currentChapterHtml, isNot(contains('<span')));
  });

  test('chapter html keeps unnamed style text', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-unnamed-style',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: markedFb2Bytes('see <style>bonjour</style>'),
    );
    expect(document.currentChapterHtml, contains('<p>see bonjour</p>'));
    expect(document.currentChapterHtml, isNot(contains('<span')));
    expect(document.currentChapterText, contains('bonjour'));
  });

  test('chapter html copies a paragraph style', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-p-style',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2SectionMarkupBytes(
        '<p style="foreign">hello</p>',
        stylesheet: '.foreign { color: red; }',
      ),
    );
    expect(
      document.currentChapterHtml,
      contains('<p class="foreign">hello</p>'),
    );
    expect(document.currentChapterHtml, isNot(contains('color: red')));
    expect(document.currentChapterText, contains('hello'));
  });

  test('an empty paragraph style does not invent a class', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-empty-p-style',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2SectionMarkupBytes('<p style="">hello</p>'),
    );
    expect(document.currentChapterHtml, contains('<p>hello</p>'));
    expect(document.currentChapterHtml, isNot(contains('class=')));
  });

  test('a paragraph style keeps the paragraph id', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-p-id-style',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2SectionMarkupBytes(
        '<p id="n1" style="foreign">hello from fb2</p>',
      ),
    );
    expect(
      document.currentChapterHtml,
      contains('<p id="n1" class="foreign">'),
    );
    expect(document.currentChapterHtml, contains('hello from fb2'));
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

  test('chapter html copies a subtitle style', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-subtitle-style',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2SectionMarkupBytes(
        '<subtitle style="foreign"><p>Before</p></subtitle><p>hello from fb2</p>',
        stylesheet: '.foreign { color: red; }',
      ),
    );
    expect(
      document.currentChapterHtml,
      contains('<h2 class="foreign">Before</h2>'),
    );
    expect(document.currentChapterHtml, isNot(contains('color: red')));
    expect(document.currentChapterText, contains('Before'));
  });

  test('an empty subtitle style does not invent a class', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-empty-subtitle-style',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2SectionMarkupBytes(
        '<subtitle style="">Part Two</subtitle><p>hello from fb2</p>',
      ),
    );
    expect(document.currentChapterHtml, contains('<h2>Part Two</h2>'));
    expect(document.currentChapterHtml, isNot(contains('class=')));
  });

  test('a subtitle style on an empty subtitle does not invent a heading', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-empty-subtitle-with-style',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2SectionMarkupBytes(
        '<subtitle style="foreign"></subtitle><p>hello from fb2</p>',
      ),
    );
    expect(document.currentChapterHtml, isNot(contains('<h2>')));
    expect(document.currentChapterHtml, contains('hello from fb2'));
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

  test('chapter html copies a poem title style', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-poem-title-style',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2SectionMarkupBytes(
        '<poem><title style="foreign"><p>Night</p></title><stanza><v>line one</v></stanza></poem>',
        stylesheet: '.foreign { color: red; }',
      ),
    );
    expect(
      document.currentChapterHtml,
      contains('<h3 class="foreign">Night</h3>'),
    );
    expect(document.currentChapterHtml, isNot(contains('color: red')));
    expect(document.currentChapterText, contains('Night'));
  });

  test('an empty poem title style does not invent a class', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-empty-poem-title-style',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2SectionMarkupBytes(
        '<poem><title style=""><p>Night</p></title><stanza><v>line one</v></stanza></poem>',
      ),
    );
    expect(document.currentChapterHtml, contains('<h3>Night</h3>'));
    expect(document.currentChapterHtml, isNot(contains('class=')));
  });

  test('a poem title style on an empty title does not invent a heading', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-empty-poem-title-with-style',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2SectionMarkupBytes(
        '<poem><title style="foreign"></title><stanza><v>line one</v></stanza></poem>',
      ),
    );
    expect(document.currentChapterHtml, contains('line one'));
    expect(document.currentChapterHtml, isNot(contains('<h3>')));
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

  test('chapter html copies a poem subtitle style', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-poem-subtitle-style',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2SectionMarkupBytes(
        '<poem><subtitle style="foreign"><p>a lyric</p></subtitle><stanza><v>line one</v></stanza></poem>',
        stylesheet: '.foreign { color: red; }',
      ),
    );
    expect(
      document.currentChapterHtml,
      contains('<h4 class="foreign">a lyric</h4>'),
    );
    expect(document.currentChapterHtml, isNot(contains('color: red')));
    expect(document.currentChapterText, contains('a lyric'));
  });

  test('an empty poem subtitle style does not invent a class', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-empty-poem-subtitle-style',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2SectionMarkupBytes(
        '<poem><subtitle style=""><p>a lyric</p></subtitle><stanza><v>line one</v></stanza></poem>',
      ),
    );
    expect(document.currentChapterHtml, contains('<h4>a lyric</h4>'));
    expect(document.currentChapterHtml, isNot(contains('class=')));
  });

  test(
    'a poem subtitle style on an empty subtitle does not invent a heading',
    () {
      final document = Fb2ReaderDocument.parse(
        metadata: const DocumentMetadata(
          id: 'fb2-empty-poem-subtitle-with-style',
          title: 'Local',
          author: 'Local',
          format: DocumentFormat.fb2,
          type: DocumentType.reflow,
        ),
        bytes: fb2SectionMarkupBytes(
          '<poem><subtitle style="foreign"></subtitle><stanza><v>line one</v></stanza></poem>',
        ),
      );
      expect(document.currentChapterHtml, contains('line one'));
      expect(document.currentChapterHtml, isNot(contains('<h4>')));
    },
  );

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

  test('chapter html copies a poem text-author style', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-poem-author-style',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2SectionMarkupBytes(
        '<poem><stanza><v>line one</v></stanza><text-author style="foreign">Pushkin</text-author></poem>',
        stylesheet: '.foreign { color: red; }',
      ),
    );
    expect(
      document.currentChapterHtml,
      contains('<p class="foreign">Pushkin</p>'),
    );
    expect(document.currentChapterHtml, isNot(contains('color: red')));
    expect(document.currentChapterText, contains('Pushkin'));
  });

  test('an empty poem text-author style does not invent a class', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-empty-poem-author-style',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2SectionMarkupBytes(
        '<poem><stanza><v>line one</v></stanza><text-author style="">Pushkin</text-author></poem>',
      ),
    );
    expect(document.currentChapterHtml, contains('<p>Pushkin</p>'));
    expect(document.currentChapterHtml, isNot(contains('class=')));
  });

  test(
    'a poem text-author style on an empty author does not invent a byline',
    () {
      final document = Fb2ReaderDocument.parse(
        metadata: const DocumentMetadata(
          id: 'fb2-empty-poem-author-with-style',
          title: 'Local',
          author: 'Local',
          format: DocumentFormat.fb2,
          type: DocumentType.reflow,
        ),
        bytes: fb2SectionMarkupBytes(
          '<poem><stanza><v>line one</v></stanza><text-author style="foreign"></text-author></poem>',
        ),
      );
      expect(document.currentChapterHtml, contains('line one'));
      expect(document.currentChapterHtml, isNot(contains('<p></p>')));
      expect(document.currentChapterHtml, isNot(contains('class=')));
    },
  );

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

  test('chapter html copies a poem date style', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-poem-date-style',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2SectionMarkupBytes(
        '<poem><stanza><v>line one</v></stanza><date style="foreign">1825</date></poem>',
        stylesheet: '.foreign { color: red; }',
      ),
    );
    expect(
      document.currentChapterHtml,
      contains('<p class="foreign">1825</p>'),
    );
    expect(document.currentChapterHtml, isNot(contains('color: red')));
    expect(document.currentChapterText, contains('1825'));
  });

  test('an empty poem date style does not invent a class', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-empty-poem-date-style',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2SectionMarkupBytes(
        '<poem><stanza><v>line one</v></stanza><date style="">1825</date></poem>',
      ),
    );
    expect(document.currentChapterHtml, contains('<p>1825</p>'));
    expect(document.currentChapterHtml, isNot(contains('class=')));
  });

  test('a poem date style on an empty date does not invent a year', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-empty-poem-date-with-style',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2SectionMarkupBytes(
        '<poem><stanza><v>line one</v></stanza><date style="foreign"></date></poem>',
      ),
    );
    expect(document.currentChapterHtml, contains('line one'));
    expect(document.currentChapterHtml, isNot(contains('<p></p>')));
    expect(document.currentChapterHtml, isNot(contains('class=')));
  });

  test('chapter html copies a poem date style onto a value attribute', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-poem-date-value-style',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2SectionMarkupBytes(
        '<poem><stanza><v>line one</v></stanza><date style="foreign" value="1825"/></poem>',
        stylesheet: '.foreign { color: red; }',
      ),
    );
    expect(
      document.currentChapterHtml,
      contains('<p class="foreign">1825</p>'),
    );
    expect(document.currentChapterHtml, isNot(contains('color: red')));
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

  test('chapter html copies a stanza title style', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-stanza-title-style',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2SectionMarkupBytes(
        '<poem><stanza><title style="foreign"><p>I</p></title><v>line one</v></stanza></poem>',
        stylesheet: '.foreign { color: red; }',
      ),
    );
    expect(document.currentChapterHtml, contains('<h4 class="foreign">I</h4>'));
    expect(document.currentChapterHtml, isNot(contains('color: red')));
    expect(document.currentChapterText, contains('I'));
  });

  test('an empty stanza title style does not invent a class', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-empty-stanza-title-style',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2SectionMarkupBytes(
        '<poem><stanza><title style=""><p>I</p></title><v>line one</v></stanza></poem>',
      ),
    );
    expect(document.currentChapterHtml, contains('<h4>I</h4>'));
    expect(document.currentChapterHtml, isNot(contains('class=')));
  });

  test('a stanza title style on an empty title does not invent a heading', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-empty-stanza-title-with-style',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2SectionMarkupBytes(
        '<poem><stanza><title style="foreign"></title><v>line one</v></stanza></poem>',
      ),
    );
    expect(document.currentChapterHtml, contains('line one'));
    expect(document.currentChapterHtml, isNot(contains('<h4>')));
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

  test('chapter html copies a stanza subtitle style', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-stanza-subtitle-style',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2SectionMarkupBytes(
        '<poem><stanza><subtitle style="foreign"><p>softly</p></subtitle><v>line one</v></stanza></poem>',
        stylesheet: '.foreign { color: red; }',
      ),
    );
    expect(
      document.currentChapterHtml,
      contains('<h5 class="foreign">softly</h5>'),
    );
    expect(document.currentChapterHtml, isNot(contains('color: red')));
    expect(document.currentChapterText, contains('softly'));
  });

  test('an empty stanza subtitle style does not invent a class', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-empty-stanza-subtitle-style',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2SectionMarkupBytes(
        '<poem><stanza><subtitle style=""><p>softly</p></subtitle><v>line one</v></stanza></poem>',
      ),
    );
    expect(document.currentChapterHtml, contains('<h5>softly</h5>'));
    expect(document.currentChapterHtml, isNot(contains('class=')));
  });

  test(
    'a stanza subtitle style on an empty subtitle does not invent a heading',
    () {
      final document = Fb2ReaderDocument.parse(
        metadata: const DocumentMetadata(
          id: 'fb2-empty-stanza-subtitle-with-style',
          title: 'Local',
          author: 'Local',
          format: DocumentFormat.fb2,
          type: DocumentType.reflow,
        ),
        bytes: fb2SectionMarkupBytes(
          '<poem><stanza><subtitle style="foreign"></subtitle><v>line one</v></stanza></poem>',
        ),
      );
      expect(document.currentChapterHtml, contains('line one'));
      expect(document.currentChapterHtml, isNot(contains('<h5>')));
    },
  );

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

  test('chapter html copies a verse style', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-verse-style',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2SectionMarkupBytes(
        '<poem><stanza><v style="foreign">line one</v></stanza></poem>',
        stylesheet: '.foreign { color: red; }',
      ),
    );
    expect(
      document.currentChapterHtml,
      contains('<span class="foreign">line one</span>'),
    );
    expect(document.currentChapterHtml, isNot(contains('color: red')));
    expect(document.currentChapterText, contains('line one'));
  });

  test('an empty verse style does not invent a class', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-empty-verse-style',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2SectionMarkupBytes(
        '<poem><stanza><v style="">line one</v></stanza></poem>',
      ),
    );
    expect(document.currentChapterHtml, contains('line one'));
    expect(document.currentChapterHtml, isNot(contains('class=')));
  });

  test('a verse style on an empty line does not invent a line', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-empty-verse',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2SectionMarkupBytes(
        '<poem><stanza><v style="foreign"></v><v>line one</v></stanza></poem>',
      ),
    );
    expect(document.currentChapterHtml, contains('line one'));
    expect(document.currentChapterHtml, isNot(contains('<span')));
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

  test('chapter html copies a quote text-author style', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-epigraph-author-style',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2SectionMarkupBytes(
        '<epigraph><p>quoted line</p><text-author style="foreign">Ann</text-author></epigraph>',
        stylesheet: '.foreign { color: red; }',
      ),
    );
    expect(document.currentChapterHtml, contains('<p class="foreign">Ann</p>'));
    expect(document.currentChapterHtml, isNot(contains('color: red')));
    expect(document.currentChapterText, contains('Ann'));
  });

  test('chapter html copies a quote text-author style from a cite', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-cite-author-style',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2SectionMarkupBytes(
        '<cite><p>cited line</p><text-author style="foreign">Ann</text-author></cite>',
        stylesheet: '.foreign { color: red; }',
      ),
    );
    expect(document.currentChapterHtml, contains('<p class="foreign">Ann</p>'));
    expect(document.currentChapterHtml, isNot(contains('color: red')));
    expect(document.currentChapterText, contains('Ann'));
  });

  test('an empty quote text-author style does not invent a class', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-empty-quote-author-style',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2SectionMarkupBytes(
        '<epigraph><p>quoted line</p><text-author style="">Ann</text-author></epigraph>',
      ),
    );
    expect(document.currentChapterHtml, contains('<p>Ann</p>'));
    expect(document.currentChapterHtml, isNot(contains('class=')));
  });

  test(
    'a quote text-author style on an empty author does not invent a byline',
    () {
      final document = Fb2ReaderDocument.parse(
        metadata: const DocumentMetadata(
          id: 'fb2-empty-quote-author-with-style',
          title: 'Local',
          author: 'Local',
          format: DocumentFormat.fb2,
          type: DocumentType.reflow,
        ),
        bytes: fb2SectionMarkupBytes(
          '<epigraph><p>quoted line</p><text-author style="foreign"></text-author></epigraph>',
        ),
      );
      expect(document.currentChapterHtml, contains('<p>quoted line</p>'));
      expect(document.currentChapterHtml, isNot(contains('<p></p>')));
      expect(document.currentChapterHtml, isNot(contains('class=')));
    },
  );

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

  test('chapter html copies a cite subtitle style', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-cite-subtitle-style',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2SectionMarkupBytes(
        '<cite><subtitle style="foreign"><p>Note</p></subtitle><p>quoted</p></cite>',
        stylesheet: '.foreign { color: red; }',
      ),
    );
    expect(
      document.currentChapterHtml,
      contains('<h2 class="foreign">Note</h2>'),
    );
    expect(document.currentChapterHtml, isNot(contains('color: red')));
    expect(document.currentChapterText, contains('Note'));
  });

  test('an empty cite subtitle style does not invent a class', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-empty-cite-subtitle-style',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2SectionMarkupBytes(
        '<cite><subtitle style=""><p>Note</p></subtitle><p>quoted</p></cite>',
      ),
    );
    expect(document.currentChapterHtml, contains('<h2>Note</h2>'));
    expect(document.currentChapterHtml, isNot(contains('class=')));
  });

  test(
    'a cite subtitle style on an empty subtitle does not invent a heading',
    () {
      final document = Fb2ReaderDocument.parse(
        metadata: const DocumentMetadata(
          id: 'fb2-empty-cite-subtitle-with-style',
          title: 'Local',
          author: 'Local',
          format: DocumentFormat.fb2,
          type: DocumentType.reflow,
        ),
        bytes: fb2SectionMarkupBytes(
          '<cite><subtitle style="foreign"></subtitle><p>quoted</p></cite>',
        ),
      );
      expect(document.currentChapterHtml, contains('<p>quoted</p>'));
      expect(document.currentChapterHtml, isNot(contains('<h2>')));
    },
  );

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

  test('chapter html copies an annotation subtitle style', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-annotation-subtitle-style',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2SectionMarkupBytes(
        '<annotation><subtitle style="foreign"><p>Note</p></subtitle><p>blurb</p></annotation>',
        stylesheet: '.foreign { color: red; }',
      ),
    );
    expect(
      document.currentChapterHtml,
      contains('<h2 class="foreign">Note</h2>'),
    );
    expect(document.currentChapterHtml, isNot(contains('color: red')));
    expect(document.currentChapterText, contains('Note'));
  });

  test('an empty annotation subtitle style does not invent a class', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-empty-annotation-subtitle-style',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2SectionMarkupBytes(
        '<annotation><subtitle style=""><p>Note</p></subtitle><p>blurb</p></annotation>',
      ),
    );
    expect(document.currentChapterHtml, contains('<h2>Note</h2>'));
    expect(document.currentChapterHtml, isNot(contains('class=')));
  });

  test('an annotation subtitle style on an empty subtitle does not invent a heading', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-empty-annotation-subtitle-with-style',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2SectionMarkupBytes(
        '<annotation><subtitle style="foreign"></subtitle><p>blurb</p></annotation>',
      ),
    );
    expect(document.currentChapterHtml, contains('<p>blurb</p>'));
    expect(document.currentChapterHtml, isNot(contains('<h2>')));
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

  test('chapter html copies a table cell style', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-table-cell-style',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2SectionMarkupBytes(
        '<table><tr><td style="foreign"><p>alpha</p></td></tr></table>',
        stylesheet: '.foreign { color: red; }',
      ),
    );
    expect(
      document.currentChapterHtml,
      contains('<td class="foreign">alpha</td>'),
    );
    expect(document.currentChapterHtml, isNot(contains('color: red')));
    expect(document.currentChapterText, contains('alpha'));
  });

  test('chapter html copies a table cell style onto a header', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-table-th-style',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2SectionMarkupBytes(
        '<table><tr><th style="foreign"><p>alpha</p></th></tr></table>',
        stylesheet: '.foreign { color: red; }',
      ),
    );
    expect(
      document.currentChapterHtml,
      contains('<th class="foreign">alpha</th>'),
    );
    expect(document.currentChapterHtml, isNot(contains('color: red')));
    expect(document.currentChapterText, contains('alpha'));
  });

  test('an empty table cell style does not invent a class', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-empty-table-cell-style',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: fb2SectionMarkupBytes(
        '<table><tr><td style=""><p>alpha</p></td></tr></table>',
      ),
    );
    expect(document.currentChapterHtml, contains('<td>alpha</td>'));
    expect(document.currentChapterHtml, isNot(contains('class=')));
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
