import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

import { openFb2Document } from "./fb2-document";

const encoder = new TextEncoder();

function fb2(body: string, description = "<title-info><book-title>Book</book-title></title-info>"): Uint8Array {
  return encoder.encode(
    `<?xml version="1.0" encoding="UTF-8"?><FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0"><description>${description}</description>${body}</FictionBook>`,
  );
}

test("empty fb2 bytes stay unavailable and a broken file stays corrupt", () => {
  assert.equal(openFb2Document(null).kind, "unavailable");
  assert.equal(openFb2Document(new Uint8Array()).kind, "unavailable");
  assert.equal(openFb2Document(encoder.encode("not xml")).kind, "corrupt");
  assert.equal(openFb2Document(encoder.encode("<?xml version=\"1.0\"?><html><body>other book</body></html>")).kind, "corrupt");
  assert.equal(openFb2Document(fb2("<body><section></section></body>")).kind, "corrupt");
  const upper = encoder.encode(
    '<?xml version="1.0"?><FICTIONBOOK><description><title-info><book-title>Title</book-title></title-info></description><body><section><title>Ch</title><p>Text</p></section></body></FICTIONBOOK>',
  );
  const opened = openFb2Document(upper);
  assert.equal(opened.kind, "fb2");
  if (opened.kind !== "fb2") return;
  assert.equal(opened.document.currentChapterText, "Text");
});

test("the shared fb2 samples open their own chapters", () => {
  const minimal = openFb2Document(readFileSync(new URL("../../test-books/fb2/minimal.fb2", import.meta.url)));
  const nested = openFb2Document(readFileSync(new URL("../../test-books/fb2/edge-nested.fb2", import.meta.url)));
  assert.equal(minimal.kind, "fb2");
  assert.equal(nested.kind, "fb2");
  if (minimal.kind !== "fb2" || nested.kind !== "fb2") return;
  assert.equal(minimal.document.title, "FB2 Book");
  assert.equal(minimal.document.author, "Ann Author");
  assert.equal(minimal.document.chapterCount, 2);
  assert.equal(minimal.document.currentChapterTitle, "第一章");
  assert.equal(minimal.document.currentChapterText, "first chapter text here");
  minimal.document.next();
  assert.equal(minimal.document.currentChapterTitle, "第二章");
  assert.equal(minimal.document.currentChapterText, "second chapter text here");
  assert.equal(minimal.document.search("Part one content").length, 0);
  assert.equal(nested.document.title, "嵌套章节样本");
  assert.equal(nested.document.chapterCount, 2);
  assert.equal(nested.document.currentChapterText, "Part one content");
  nested.document.next();
  assert.equal(nested.document.currentChapterText, "Part two content");
  assert.equal(nested.document.search("first chapter text here").length, 0);
});

test("a section that only groups other sections is not its own chapter", () => {
  const opened = openFb2Document(
    fb2(
      "<body><section><section><title>A</title><p>alpha</p></section><section><title>B</title><p>beta</p></section></section></body>",
    ),
  );
  assert.equal(opened.kind, "fb2");
  if (opened.kind !== "fb2") return;
  assert.equal(opened.document.chapterCount, 2);
  assert.equal(opened.document.currentChapterTitle, "A");
  assert.equal(opened.document.currentChapterText, "alpha");
  opened.document.next();
  assert.equal(opened.document.currentChapterText, "beta");
});

test("an epigraph before the first section stays with that chapter", () => {
  const opened = openFb2Document(
    fb2("<body><epigraph><p>Quote from a friend.</p></epigraph><section><title>正文</title><p>main paragraph</p></section></body>"),
  );
  assert.equal(opened.kind, "fb2");
  if (opened.kind !== "fb2") return;
  assert.equal(opened.document.chapterCount, 1);
  assert.equal(opened.document.currentChapterText.includes("Quote from a friend."), true);
  assert.equal(opened.document.currentChapterText.includes("main paragraph"), true);
});

test("a poem's lines stay in that chapter", () => {
  const opened = openFb2Document(
    fb2("<body><section><title>Poem Chapter</title><poem><stanza><v>line one</v><v>line two</v></stanza></poem></section></body>"),
  );
  assert.equal(opened.kind, "fb2");
  if (opened.kind !== "fb2") return;
  assert.equal(opened.document.currentChapterText.includes("line one"), true);
  assert.equal(opened.document.currentChapterText.includes("line two"), true);
});

test("a title-info annotation is the first chapter and notes follow the book", () => {
  const opened = openFb2Document(
    fb2(
      "<body><section><title>Main</title><p>main paragraph</p></section></body><body name=\"notes\"><p>note paragraph</p></body>",
      "<title-info><book-title>Annotated</book-title><annotation><p>A brief description of the book.</p></annotation></title-info>",
    ),
  );
  assert.equal(opened.kind, "fb2");
  if (opened.kind !== "fb2") return;
  assert.equal(opened.document.currentChapterText.includes("brief description"), true);
  opened.document.moveTo(1);
  assert.equal(opened.document.currentChapterText, "main paragraph");
  opened.document.moveTo(2);
  assert.equal(opened.document.currentChapterText, "note paragraph");
});

test("notes without a main chapter stay corrupt", () => {
  const opened = openFb2Document(fb2("<body name=\"notes\"><p>only a note</p></body>"));
  assert.equal(opened.kind, "corrupt");
});

test("search stays inside this fb2", () => {
  const opened = openFb2Document(
    fb2(
      "<body><section><title>One</title><p>alpha marker</p></section><section><title>Two</title><p>beta marker</p></section></body>",
    ),
  );
  assert.equal(opened.kind, "fb2");
  if (opened.kind !== "fb2") return;
  assert.deepEqual(opened.document.search("  "), []);
  const hits = opened.document.search("beta marker");
  assert.equal(hits.length, 1);
  assert.equal(hits[0]?.chapterIndex, 1);
  assert.equal(hits[0]?.excerpt.includes("beta marker"), true);
  assert.equal(hits[0]?.excerpt.includes("alpha marker"), false);
  opened.document.moveTo(hits[0]?.chapterIndex ?? 0);
  assert.equal(opened.document.currentChapterText, "beta marker");
});
