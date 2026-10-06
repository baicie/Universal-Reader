import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import { zipSync } from "fflate";

import { docxTextCharLimit, openDocxDocument } from "./docx-document";

const encoder = new TextEncoder();

function docx(files: Record<string, string>): Uint8Array {
  const entries: Record<string, Uint8Array> = {};
  for (const [name, text] of Object.entries(files)) entries[name] = encoder.encode(text);
  return zipSync(entries);
}

function document(body: string, title = "", author = ""): Uint8Array {
  const files: Record<string, string> = {
    "word/document.xml": `<?xml version="1.0" encoding="UTF-8"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <w:body>${body}</w:body>
</w:document>`,
  };
  if (title.length > 0 || author.length > 0) {
    files["docProps/core.xml"] = `<?xml version="1.0" encoding="UTF-8"?>
<cp:coreProperties xmlns:dc="http://purl.org/dc/elements/1.1/">
  <dc:title>${title}</dc:title>
  <dc:creator>${author}</dc:creator>
</cp:coreProperties>`;
  }
  return docx(files);
}

test("empty docx bytes stay unavailable and a broken file stays corrupt", () => {
  assert.equal(openDocxDocument(null).kind, "unavailable");
  assert.equal(openDocxDocument(new Uint8Array()).kind, "unavailable");
  assert.equal(openDocxDocument(Uint8Array.from([1, 2, 3])).kind, "corrupt");
  assert.equal(openDocxDocument(docx({ "word/notes.xml": "<p>other book</p>" })).kind, "corrupt");
  assert.equal(openDocxDocument(document("<w:p></w:p>")).kind, "corrupt");
  assert.equal(openDocxDocument(document("")).kind, "corrupt");
  assert.equal(
    openDocxDocument(docx({ "word/document.xml": "not xml" })).kind,
    "corrupt",
  );
  const opened = openDocxDocument(document('<w:p><w:r><w:t>Hello</w:t></w:r></w:p>'));
  assert.equal(opened.kind, "docx");
  if (opened.kind !== "docx") return;
  assert.equal(opened.document.title, "");
  assert.equal(opened.document.currentChapterText, "Hello");
});

test("the shared docx samples open their own chapters", () => {
  const minimal = openDocxDocument(readFileSync(new URL("../../test-books/docx/minimal.docx", import.meta.url)));
  const cjk = openDocxDocument(readFileSync(new URL("../../test-books/docx/edge-cjk.docx", import.meta.url)));
  assert.equal(minimal.kind, "docx");
  assert.equal(cjk.kind, "docx");
  if (minimal.kind !== "docx" || cjk.kind !== "docx") return;
  assert.equal(minimal.document.title, "DOCX Compatibility Book");
  assert.equal(minimal.document.author, "Ada Reader");
  assert.equal(cjk.document.title, "文档兼容样本");
  assert.equal(cjk.document.author, "测试作者");
  assert.equal(minimal.document.chapterCount, 3);
  assert.equal(minimal.document.truncated, false);
  assert.equal(minimal.document.currentChapterTitle, "DOCX Compatibility Book");
  assert.equal(minimal.document.currentChapterText, "");
  minimal.document.next();
  const chapter = minimal.document.currentChapterText;
  assert.equal(minimal.document.currentChapterTitle, "Chapter One");
  assert.equal(
    chapter,
    ["Hello bold and italic text.", "- First item", "Key\tValue\nFormat\tDOCX", "External link"].join("\n\n"),
  );
  assert.equal(chapter.includes("https://example.com"), false);
  assert.equal(chapter.includes("文档兼容样本"), false);
  minimal.document.next();
  assert.equal(minimal.document.currentChapterTitle, "Chapter Two");
  assert.equal(minimal.document.currentChapterText, "Second chapter body.");
  minimal.document.next();
  assert.equal(minimal.document.currentChapterText, "Second chapter body.");
  assert.equal(cjk.document.currentChapterTitle, "文档兼容样本");
  cjk.document.moveTo(1);
  assert.equal(cjk.document.currentChapterTitle, "第一章");
  assert.equal(cjk.document.currentChapterText.includes("DOCX Compatibility Book"), false);
  cjk.document.next();
  assert.equal(cjk.document.currentChapterTitle, "第二章");
});

test("a word path with different case still opens and a preface stays its own chapter", () => {
  const opened = openDocxDocument(
    docx({
      "WORD\\Document.XML": `<?xml version="1.0"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    <w:p><w:r><w:t>Preface</w:t></w:r></w:p>
    <w:p><w:pPr><w:pStyle w:val="Heading1"/></w:pPr><w:r><w:t>Later</w:t></w:r></w:p>
    <w:p><w:r><w:t>after</w:t></w:r></w:p>
  </w:body>
</w:document>`,
    }),
  );
  assert.equal(opened.kind, "docx");
  if (opened.kind !== "docx") return;
  assert.equal(opened.document.chapterCount, 2);
  assert.equal(opened.document.currentChapterText, "Preface");
  opened.document.next();
  assert.equal(opened.document.currentChapterTitle, "Later");
  assert.equal(opened.document.currentChapterText, "after");
});

test("a chinese heading and a deeper outline stay in this book", () => {
  const opened = openDocxDocument(
    document(`
      <w:p><w:pPr><w:pStyle w:val="标题1"/></w:pPr><w:r><w:t>正文</w:t></w:r></w:p>
      <w:p><w:r><w:t>one</w:t><w:br/><w:t>two</w:t></w:r></w:p>
      <w:p><w:pPr><w:outlineLvl w:val="2"/></w:pPr><w:r><w:t>Sub</w:t></w:r></w:p>
    `),
  );
  assert.equal(opened.kind, "docx");
  if (opened.kind !== "docx") return;
  assert.equal(opened.document.chapterCount, 1);
  assert.equal(opened.document.currentChapterTitle, "正文");
  assert.equal(opened.document.currentChapterText, "one\ntwo\n\nSub");
});

test("search stays inside this docx", () => {
  const opened = openDocxDocument(
    document(`
      <w:p><w:pPr><w:pStyle w:val="Heading1"/></w:pPr><w:r><w:t>One</w:t></w:r></w:p>
      <w:p><w:r><w:t>alpha marker</w:t></w:r></w:p>
      <w:p><w:pPr><w:pStyle w:val="Heading2"/></w:pPr><w:r><w:t>Two</w:t></w:r></w:p>
      <w:p><w:r><w:t>beta marker</w:t></w:r></w:p>
    `),
  );
  assert.equal(opened.kind, "docx");
  if (opened.kind !== "docx") return;
  assert.deepEqual(opened.document.search("  "), []);
  const hits = opened.document.search("beta marker");
  assert.equal(hits.length, 1);
  assert.equal(hits[0]?.chapterIndex, 1);
  assert.equal(hits[0]?.excerpt.includes("alpha marker"), false);
  opened.document.moveTo(hits[0]?.chapterIndex ?? 0);
  assert.equal(opened.document.currentChapterText, "beta marker");
  const many = openDocxDocument(
    document(
      Array.from(
        { length: 11 },
        (_, index) =>
          `<w:p><w:pPr><w:pStyle w:val="Heading1"/></w:pPr><w:r><w:t>Chapter ${index}</w:t></w:r></w:p><w:p><w:r><w:t>hit ${index}</w:t></w:r></w:p>`,
      ).join(""),
    ),
  );
  assert.equal(many.kind, "docx");
  if (many.kind !== "docx") return;
  assert.equal(many.document.search("hit").length, 10);
});

test("a chapter past the character limit is cut and the rest is not shown", () => {
  const opened = openDocxDocument(
    document(`<w:p><w:r><w:t>${"a".repeat(docxTextCharLimit + 8)}</w:t></w:r></w:p>`),
  );
  assert.equal(opened.kind, "docx");
  if (opened.kind !== "docx") return;
  assert.equal(opened.document.truncated, true);
  assert.equal(opened.document.currentChapterText.length, docxTextCharLimit);
  assert.equal(opened.document.chapterCount, 1);
});
