import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

import { openChmDocument } from "./chm-document";

test("empty chm bytes stay unavailable and a file that is not ITSF stays corrupt", async () => {
  assert.equal((await openChmDocument(null)).kind, "unavailable");
  assert.equal((await openChmDocument(new Uint8Array())).kind, "unavailable");
  assert.equal((await openChmDocument(Uint8Array.from([1, 2, 3, 4]))).kind, "corrupt");
  assert.equal((await openChmDocument(Uint8Array.from([0x49, 0x54, 0x53, 0x46, 0, 0, 0, 0]))).kind, "corrupt");
});

test("the shared chm sample opens its own pages", async () => {
  const opened = await openChmDocument(readFileSync(new URL("../../test-books/chm/minimal.chm", import.meta.url)));
  assert.equal(opened.kind, "chm");
  if (opened.kind !== "chm") return;
  assert.equal(opened.document.title, "rustchm basic test");
  assert.equal(opened.document.chapterCount, 2);
  assert.equal(opened.document.currentChapterTitle, "Alpha Page");
  const first = opened.document.currentChapterText;
  assert.equal(
    first,
    "Alpha\n\nThe quick brown fox jumps over the lazy dog. Repetition repetition repetition\nhelps compression. See Beta.",
  );
  assert.equal(first.includes("Second page of the rustchm basic test."), false);
  opened.document.next();
  assert.equal(opened.document.currentChapterTitle, "Beta Page");
  const second = opened.document.currentChapterText;
  assert.equal(second, "Beta\n\nSecond page of the rustchm basic test. Back to Alpha.");
  assert.equal(second.includes("lazy dog"), false);
  opened.document.next();
  assert.equal(opened.document.currentChapterText, second);
  assert.equal(opened.document.truncated, false);
});

test("search stays inside this chm", async () => {
  const opened = await openChmDocument(readFileSync(new URL("../../test-books/chm/minimal.chm", import.meta.url)));
  assert.equal(opened.kind, "chm");
  if (opened.kind !== "chm") return;
  assert.deepEqual(opened.document.search("  "), []);
  const hits = opened.document.search("lazy dog");
  assert.equal(hits.length, 1);
  assert.equal(hits[0]?.chapterIndex, 0);
  assert.equal(hits[0]?.excerpt.includes("Second page"), false);
  opened.document.moveTo(hits[0]?.chapterIndex ?? 0);
  assert.equal(opened.document.currentChapterText.includes("lazy dog"), true);
  const later = opened.document.search("Second page");
  assert.equal(later.length, 1);
  assert.equal(later[0]?.chapterIndex, 1);
  assert.equal(opened.document.search("not in this help").length, 0);
});
