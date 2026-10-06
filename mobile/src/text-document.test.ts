import assert from "node:assert/strict";
import test from "node:test";

import {
  TEXT_READER_BYTE_LIMIT,
  TEXT_SECTION_CHAR_LIMIT,
  decodePlainTextBytes,
  openTextDocument,
  parseTextDocument,
  textFormatFromName,
  titleFromName,
  type DocumentMetadata,
} from "./text-document";

const txt = (title = "notes"): DocumentMetadata => ({
  id: "notes",
  title,
  author: "",
  format: "txt",
});

const markdown = (title = "md"): DocumentMetadata => ({
  id: "md",
  title,
  author: "",
  format: "markdown",
});

test("decodes utf-8 text and splits blank-line sections", () => {
  const parsed = parseTextDocument(
    new TextEncoder().encode("第一章\n\nhello\n\n第二章\n\nworld"),
    "txt",
  );

  assert.equal(parsed.truncated, false);
  assert.equal(parsed.sections.length, 2);
  assert.equal(parsed.sections[0]?.title, "第一章");
  assert.match(parsed.sections[0]?.body ?? "", /hello/);
  assert.equal(parsed.sections.at(-1)?.title, "第二章");
});

test("splits markdown on ATX headings", () => {
  const parsed = parseTextDocument(
    new TextEncoder().encode("# Intro\nwelcome\n\n## Details\nmore"),
    "markdown",
  );

  assert.deepEqual(
    parsed.sections.map((section) => section.title),
    ["Intro", "Details"],
  );
  assert.match(parsed.sections.at(-1)?.body ?? "", /more/);
});

test("strips html tags before reading", () => {
  const parsed = parseTextDocument(
    new TextEncoder().encode("<h1>Hi</h1><p>body &amp; text</p>"),
    "html",
  );

  assert.match(parsed.fullText, /Hi/);
  assert.match(parsed.fullText, /body & text/);
  assert.doesNotMatch(parsed.fullText, /<p>/);
});

test("chunks oversized sections even when other chapters exist", () => {
  const huge = "x".repeat(TEXT_SECTION_CHAR_LIMIT + 50);
  const parsed = parseTextDocument(
    new TextEncoder().encode(`# A\n\n${huge}\n\n# B\n\nshort`),
    "markdown",
  );

  assert.ok(parsed.sections.length > 2);
  assert.ok(
    parsed.sections.every((section) => section.body.length <= TEXT_SECTION_CHAR_LIMIT),
  );
});

test("gbk txt decodes as chinese instead of replacement characters", () => {
  const parsed = parseTextDocument(
    Uint8Array.from([181, 218, 210, 187, 213, 194, 10, 10, 213, 253, 206, 196]),
    "txt",
  );

  assert.match(parsed.fullText, /第一章/);
  assert.match(parsed.fullText, /正文/);
  assert.equal(parsed.fullText.includes("\uFFFD"), false);
});

test("valid utf-8 chinese is not reinterpreted as gbk", () => {
  const parsed = parseTextDocument(new TextEncoder().encode("第一章"), "txt");
  assert.equal(parsed.fullText, "第一章");
});

test("decodePlainTextBytes strips the UTF-8 BOM if present", () => {
  const bytes = Uint8Array.from([
    0xef, 0xbb, 0xbf, ...new TextEncoder().encode("hello"),
  ]);
  assert.equal(decodePlainTextBytes(bytes), "hello");
});

test("gbk fallback decodes bytes that fail strict UTF-8", () => {
  assert.match(decodePlainTextBytes(Uint8Array.from([196, 227, 186, 195])), /你好/);
});

test("UTF-16 LE BOM is decoded", () => {
  assert.equal(
    decodePlainTextBytes(Uint8Array.from([0xff, 0xfe, 0x68, 0x00, 0x69, 0x00])),
    "hi",
  );
});

test("truncation flag is set when bytes exceed the limit", () => {
  const parsed = parseTextDocument(
    new TextEncoder().encode("a".repeat(TEXT_READER_BYTE_LIMIT + 1)),
    "txt",
  );
  assert.equal(parsed.truncated, true);
  assert.ok(parsed.fullText.length <= TEXT_READER_BYTE_LIMIT);
});

test("crlf line endings are normalized before splitting", () => {
  const parsed = parseTextDocument(
    new TextEncoder().encode("alpha\r\n\r\nbeta"),
    "txt",
  );
  assert.equal(parsed.fullText.includes("\r"), false);
  assert.equal(parsed.sections.length, 1);
  assert.match(parsed.sections[0]?.body ?? "", /beta/);
});

test("markdown preface before first heading is captured", () => {
  const parsed = parseTextDocument(
    new TextEncoder().encode("preface prose\n\n# Title\n\nbody"),
    "markdown",
  );
  assert.equal(parsed.sections[0]?.title, "");
  assert.match(parsed.sections[0]?.body ?? "", /preface prose/);
});

test("plain text single block produces one section with empty title", () => {
  const parsed = parseTextDocument(new TextEncoder().encode("just one block"), "txt");
  assert.equal(parsed.sections.length, 1);
  assert.equal(parsed.sections[0]?.title, "");
  assert.equal(parsed.sections[0]?.body, "just one block");
});

test("html script and style blocks are stripped", () => {
  const parsed = parseTextDocument(
    new TextEncoder().encode(
      "<script>alert(1)</script>visible<script>x</script><style>.x{}</style>keep",
    ),
    "html",
  );
  assert.match(parsed.fullText, /visible/);
  assert.match(parsed.fullText, /keep/);
  assert.doesNotMatch(parsed.fullText, /alert/);
  assert.doesNotMatch(parsed.fullText, /\.x\{\}/);
});

test("text reader exposes the current chapter and moves to a locator", () => {
  const opened = openTextDocument(
    txt(),
    new TextEncoder().encode("Title\n\nreadable body\n\nNext\n\nlater"),
  );
  assert.equal(opened.kind, "text");
  if (opened.kind !== "text") return;
  assert.match(opened.document.currentChapterText, /readable body/);
  opened.document.goTo({ kind: "text", offset: 9999 });
  assert.ok(opened.document.chapterIndex < opened.document.chapterCount);
  assert.match(opened.document.currentChapterText, /later/);
});

test("moveTo lands on the requested chapter", () => {
  const opened = openTextDocument(
    txt(),
    new TextEncoder().encode("Title\n\nreadable body\n\nNext\n\nlater"),
  );
  assert.equal(opened.kind, "text");
  if (opened.kind !== "text") return;
  opened.document.moveTo(1);
  assert.equal(opened.document.chapterIndex, 1);
  assert.match(opened.document.currentChapterText, /later/);
  opened.document.moveTo(99);
  assert.equal(opened.document.chapterIndex, opened.document.chapterCount - 1);
});

test("title comes from the file name without its extension", () => {
  assert.equal(titleFromName("Notes.TXT"), "Notes");
  assert.equal(titleFromName("dir/a.b.md"), "a.b");
  assert.equal(titleFromName("README"), "README");
});

test("text format comes from the file name", () => {
  assert.equal(textFormatFromName("Notes.TXT"), "txt");
  assert.equal(textFormatFromName("chapter.markdown"), "markdown");
  assert.equal(textFormatFromName("page.htm"), "html");
  assert.equal(textFormatFromName("book.epub"), null);
  assert.equal(textFormatFromName("no-extension"), null);
});

test("search stays inside the current text and lands on that chapter", () => {
  const opened = openTextDocument(
    txt(),
    new TextEncoder().encode("alpha line\nstill alpha\n\nhello shelf"),
  );
  const other = openTextDocument(
    { id: "other", title: "other", author: "", format: "txt" },
    new TextEncoder().encode("only in the other book"),
  );
  assert.equal(opened.kind, "text");
  assert.equal(other.kind, "text");
  if (opened.kind !== "text" || other.kind !== "text") return;
  assert.deepEqual(opened.document.search(""), []);
  assert.deepEqual(opened.document.search("   "), []);
  assert.deepEqual(opened.document.search("only in the other book"), []);
  assert.deepEqual(opened.document.search("Hello shelf"), []);
  const hits = opened.document.search("hello shelf");
  assert.equal(hits.length, 1);
  assert.equal(hits[0]?.chapterIndex, 1);
  assert.match(hits[0]?.excerpt ?? "", /hello shelf/);
  opened.document.moveTo(hits[0]?.chapterIndex ?? 0);
  assert.match(opened.document.currentChapterText, /hello shelf/);
  const otherHits = other.document.search("only in the other book");
  assert.equal(otherHits.length, 1);
  assert.equal(otherHits[0]?.chapterIndex, 0);
});

test("markdown search finds the later heading's chapter", () => {
  const opened = openTextDocument(
    markdown(),
    new TextEncoder().encode("# One\nalpha\n# Two\nbeta target\n"),
  );
  assert.equal(opened.kind, "text");
  if (opened.kind !== "text") return;
  const hits = opened.document.search("beta target");
  assert.equal(hits.length, 1);
  assert.equal(hits[0]?.chapterIndex, 1);
  const heading = opened.document.search("Two");
  assert.equal(heading.length, 1);
  assert.equal(heading[0]?.chapterIndex, 1);
});

test("search stops after ten hits in this book", () => {
  const chapters = Array.from({ length: 12 }, (_, index) => `Chapter ${index}\n\nmarker ${index}`).join(
    "\n\n",
  );
  const opened = openTextDocument(txt(), new TextEncoder().encode(chapters));
  assert.equal(opened.kind, "text");
  if (opened.kind !== "text") return;
  const hits = opened.document.search("marker");
  assert.equal(hits.length, 10);
  assert.equal(hits[0]?.chapterIndex, 0);
  assert.equal(hits[9]?.chapterIndex, 9);
});

test("a word that exists only inside an html script is not a hit", () => {
  const opened = openTextDocument(
    { id: "page", title: "page", author: "", format: "html" },
    new TextEncoder().encode("<p>visible words</p><script>hiddenword</script>"),
  );
  assert.equal(opened.kind, "text");
  if (opened.kind !== "text") return;
  assert.deepEqual(opened.document.search("hiddenword"), []);
  assert.equal(opened.document.search("visible words").length, 1);
});

test("empty bytes stay unavailable and a lone 0xFF stays corrupt", () => {
  assert.equal(openTextDocument(txt(), null).kind, "unavailable");
  assert.equal(openTextDocument(txt(), new Uint8Array()).kind, "unavailable");
  assert.equal(openTextDocument(txt(), Uint8Array.from([0xff])).kind, "corrupt");
  assert.equal(openTextDocument(markdown(), null).kind, "unavailable");
});
