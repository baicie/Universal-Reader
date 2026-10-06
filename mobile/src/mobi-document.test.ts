import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

import { openEpubDocument } from "./epub-document";
import { openMobiDocument } from "./mobi-document";

const encoder = new TextEncoder();

function padded(bytes: Uint8Array, prefix: number): Uint8Array {
  const out = new Uint8Array(prefix + bytes.length);
  out.set(bytes, prefix);
  return out;
}

test("empty mobi bytes stay unavailable and a short file stays corrupt", () => {
  assert.equal(openMobiDocument(null).kind, "unavailable");
  assert.equal(openMobiDocument(new Uint8Array()).kind, "unavailable");
  assert.equal(openMobiDocument(Uint8Array.from([0, 1, 2])).kind, "corrupt");
  assert.equal(openMobiDocument(encoder.encode("hello")).kind, "corrupt");
  assert.equal(openMobiDocument(encoder.encode("1".repeat(40))).kind, "corrupt");
  const opened = openMobiDocument(
    encoder.encode(`${"\0".repeat(80)}This is valid English text that should be extracted`),
  );
  assert.equal(opened.kind, "mobi");
  if (opened.kind !== "mobi") return;
  assert.equal(opened.document.currentChapterText, "This is valid English text that should be extracted");
  assert.equal(opened.document.currentChapterTitle, "");
  assert.equal(opened.document.chapterCount, 1);
  assert.equal(opened.document.truncated, false);
});

test("the shared mobi and azw3 samples open their own sentences", () => {
  const mobi = openMobiDocument(readFileSync(new URL("../../test-books/mobi/minimal.mobi", import.meta.url)));
  const azw3 = openMobiDocument(readFileSync(new URL("../../test-books/azw3/minimal.azw3", import.meta.url)));
  assert.equal(mobi.kind, "mobi");
  assert.equal(azw3.kind, "mobi");
  if (mobi.kind !== "mobi" || azw3.kind !== "mobi") return;
  const mobiText = mobi.document.currentChapterText;
  const azw3Text = azw3.document.currentChapterText;
  assert.equal(mobiText, "Universal Reader sample text for MOBI decoding.");
  assert.equal(azw3Text, "Universal Reader sample text for AZW3 decoding.");
  assert.equal(mobiText.includes("AZW3"), false);
  assert.equal(azw3Text.includes("MOBI"), false);
  assert.equal(mobi.document.chapterCount, 1);
  mobi.document.next();
  assert.equal(mobi.document.currentChapterText, "Universal Reader sample text for MOBI decoding.");
});

test("an epub tucked after a header opens that epub and not another sentence", () => {
  const epubBytes = new Uint8Array(readFileSync(new URL("../../test-books/epub/minimal.epub", import.meta.url)));
  const epub = openEpubDocument(epubBytes);
  assert.equal(epub.kind, "epub");
  if (epub.kind !== "epub") return;
  const opened = openMobiDocument(padded(epubBytes, 16));
  assert.equal(opened.kind, "mobi");
  if (opened.kind !== "mobi") return;
  const first = opened.document.currentChapterText;
  assert.equal(first, epub.document.currentChapterText);
  assert.equal(first.includes("MOBI decoding"), false);
  assert.equal(opened.document.title, epub.document.title);
  opened.document.next();
  epub.document.next();
  assert.equal(opened.document.currentChapterText, epub.document.currentChapterText);
  const direct = openMobiDocument(epubBytes);
  assert.equal(direct.kind, "mobi");
  if (direct.kind !== "mobi") return;
  assert.equal(direct.document.currentChapterText, first);
});

test("separate readable runs stay in this one chapter", () => {
  const opened = openMobiDocument(
    encoder.encode(`${"中".repeat(24)}\0${"0".repeat(8)}\0Second readable run of letters here`),
  );
  assert.equal(opened.kind, "mobi");
  if (opened.kind !== "mobi") return;
  assert.equal(opened.document.chapterCount, 1);
  assert.equal(opened.document.currentChapterText, `${"中".repeat(24)}\n\nSecond readable run of letters here`);
});

test("search stays inside this mobi", () => {
  const opened = openMobiDocument(readFileSync(new URL("../../test-books/mobi/minimal.mobi", import.meta.url)));
  assert.equal(opened.kind, "mobi");
  if (opened.kind !== "mobi") return;
  assert.deepEqual(opened.document.search("  "), []);
  const hits = opened.document.search("MOBI decoding");
  assert.equal(hits.length, 1);
  assert.equal(hits[0]?.chapterIndex, 0);
  assert.equal(hits[0]?.excerpt.includes("AZW3"), false);
  opened.document.moveTo(hits[0]?.chapterIndex ?? 0);
  assert.equal(opened.document.currentChapterText.includes("MOBI decoding"), true);
  assert.equal(opened.document.search("AZW3 decoding").length, 0);
});
