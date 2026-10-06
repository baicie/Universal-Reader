import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

import { openRtfDocument, rtfTextCharLimit } from "./rtf-document";

const encoder = new TextEncoder();

function rtf(source: string): Uint8Array {
  return encoder.encode(source);
}

test("empty rtf bytes stay unavailable and a broken file stays corrupt", () => {
  assert.equal(openRtfDocument(null).kind, "unavailable");
  assert.equal(openRtfDocument(new Uint8Array()).kind, "unavailable");
  assert.equal(openRtfDocument(rtf("not rtf")).kind, "corrupt");
  assert.equal(openRtfDocument(rtf("{\\rtf1}")).kind, "corrupt");
  assert.equal(openRtfDocument(rtf("{\\rtf1 hello")).kind, "corrupt");
  assert.equal(openRtfDocument(rtf("{\\rtf1 \\'zz}")).kind, "corrupt");
  const opened = openRtfDocument(rtf("\uFEFF \n{\\rtf1 visible\\par}"));
  assert.equal(opened.kind, "rtf");
  if (opened.kind !== "rtf") return;
  assert.equal(opened.document.currentChapterText, "visible");
});

test("the shared rtf samples open their own chapters", () => {
  const minimal = openRtfDocument(readFileSync(new URL("../../test-books/rtf/minimal.rtf", import.meta.url)));
  const unicode = openRtfDocument(readFileSync(new URL("../../test-books/rtf/edge-unicode.rtf", import.meta.url)));
  assert.equal(minimal.kind, "rtf");
  assert.equal(unicode.kind, "rtf");
  if (minimal.kind !== "rtf" || unicode.kind !== "rtf") return;
  assert.equal(minimal.document.title, "RTF Compatibility Book");
  assert.equal(minimal.document.author, "Rich Text");
  assert.equal(unicode.document.title, "RTF Unicode");
  assert.equal(minimal.document.chapterCount, 2);
  assert.equal(minimal.document.truncated, false);
  assert.equal(minimal.document.currentChapterTitle, "Chapter One");
  const first = minimal.document.currentChapterText;
  assert.equal(
    first,
    ["Hello boldand italictext.", "Unicode: 中文", "Bullet: •\tFirst item", "Key\tValue"].join("\n\n"),
  );
  assert.equal(first.includes("Arial"), false);
  assert.equal(first.includes("RTF Unicode"), false);
  minimal.document.next();
  const second = minimal.document.currentChapterText;
  assert.equal(minimal.document.currentChapterTitle, "Chapter Two");
  assert.equal(second, "Second chapter body.");
  assert.equal(second.includes("Hello bold"), false);
  minimal.document.next();
  assert.equal(minimal.document.currentChapterText, "Second chapter body.");
  assert.equal(unicode.document.currentChapterText.includes("RTF Compatibility Book"), false);
});

test("a header, a font table, and a starred group stay out of the chapter", () => {
  const opened = openRtfDocument(
    rtf("{\\rtf1{\\fonttbl{\\f0 Arial;}}{\\header secret header}{\\*\\hidden secret}visible\\par}"),
  );
  assert.equal(opened.kind, "rtf");
  if (opened.kind !== "rtf") return;
  assert.equal(opened.document.currentChapterText, "visible");
});

test("a gbk code page decodes its own bytes and a later heading stays in this book", () => {
  const opened = openRtfDocument(
    rtf("{\\rtf1\\ansicpg936\\'d6\\'d0\\par\\pard\\s1 Later\\par\\pard after\\par}"),
  );
  assert.equal(opened.kind, "rtf");
  if (opened.kind !== "rtf") return;
  assert.equal(opened.document.chapterCount, 2);
  assert.equal(opened.document.currentChapterText, "中");
  opened.document.next();
  assert.equal(opened.document.currentChapterTitle, "Later");
  assert.equal(opened.document.currentChapterText, "after");
});

test("an operator names the book when the title control is absent", () => {
  const opened = openRtfDocument(rtf("{\\rtf1{\\info{\\operator Op Name}}Hello\\par}"));
  assert.equal(opened.kind, "rtf");
  if (opened.kind !== "rtf") return;
  assert.equal(opened.document.title, "");
  assert.equal(opened.document.author, "Op Name");
  assert.equal(opened.document.currentChapterTitle, "");
  assert.equal(opened.document.currentChapterText, "Hello");
});

test("a heading deeper than two stays inside the current chapter", () => {
  const opened = openRtfDocument(rtf("{\\rtf1\\s1 Main\\par\\s3 Sub\\par more\\par}"));
  assert.equal(opened.kind, "rtf");
  if (opened.kind !== "rtf") return;
  assert.equal(opened.document.chapterCount, 1);
  assert.equal(opened.document.currentChapterTitle, "Main");
  assert.equal(opened.document.currentChapterText, "Sub\n\nmore");
  const stuck = openRtfDocument(rtf("{\\rtf1\\s1 Title\\par still a heading\\par}"));
  assert.equal(stuck.kind, "rtf");
  if (stuck.kind !== "rtf") return;
  assert.equal(stuck.document.chapterCount, 2);
  stuck.document.next();
  assert.equal(stuck.document.currentChapterTitle, "still a heading");
});

test("binary data and a line break stay in this paragraph", () => {
  const opened = openRtfDocument(rtf("{\\rtf1 before\\bin4 SKIP\\line after\\par}"));
  assert.equal(opened.kind, "rtf");
  if (opened.kind !== "rtf") return;
  assert.equal(opened.document.currentChapterText, "before\nafter");
});

test("search stays inside this rtf", () => {
  const opened = openRtfDocument(
    rtf("{\\rtf1\\s1 One\\par\\pard alpha marker\\par\\s2 Two\\par\\pard beta marker\\par}"),
  );
  assert.equal(opened.kind, "rtf");
  if (opened.kind !== "rtf") return;
  assert.deepEqual(opened.document.search("  "), []);
  const hits = opened.document.search("beta marker");
  assert.equal(hits.length, 1);
  assert.equal(hits[0]?.chapterIndex, 1);
  assert.equal(hits[0]?.excerpt.includes("alpha marker"), false);
  opened.document.moveTo(hits[0]?.chapterIndex ?? 0);
  assert.equal(opened.document.currentChapterText, "beta marker");
  assert.equal(opened.document.search("alpha marker").length, 1);
  const many = openRtfDocument(
    rtf(`{\\rtf1 ${Array.from({ length: 11 }, (_, index) => `\\s1 Chapter ${index}\\par\\pard hit ${index}\\par`).join("")}}`),
  );
  assert.equal(many.kind, "rtf");
  if (many.kind !== "rtf") return;
  assert.equal(many.document.search("hit").length, 10);
});

test("a chapter past the character limit is cut and the rest is not shown", () => {
  const opened = openRtfDocument(rtf(`{\\rtf1 ${"a".repeat(rtfTextCharLimit + 8)}\\par}`));
  assert.equal(opened.kind, "rtf");
  if (opened.kind !== "rtf") return;
  assert.equal(opened.document.truncated, true);
  assert.equal(opened.document.currentChapterText.length, rtfTextCharLimit);
  assert.equal(opened.document.chapterCount, 1);
});
