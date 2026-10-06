import assert from "node:assert/strict";
import test from "node:test";

import { readChapterSelection, readRelocated, turnBackward, turnForward } from "./reading-place";

test("the next page stays in the chapter until the last page", () => {
  assert.deepEqual(turnForward({ chapterIndex: 0, pageIndex: 0 }, 4, 2), {
    chapterIndex: 0,
    pageIndex: 1,
  });
  assert.deepEqual(turnForward({ chapterIndex: 0, pageIndex: 2 }, 4, 2), {
    chapterIndex: 0,
    pageIndex: 3,
  });
});

test("the last page of a chapter opens the next chapter at its first page", () => {
  assert.deepEqual(turnForward({ chapterIndex: 0, pageIndex: 3 }, 4, 2), {
    chapterIndex: 1,
    pageIndex: 0,
  });
});

test("the last page of the book does not move", () => {
  const end = { chapterIndex: 1, pageIndex: 0 };
  assert.deepEqual(turnForward(end, 1, 2), end);
});

test("an unknown page count does not skip the chapter", () => {
  const start = { chapterIndex: 0, pageIndex: 0 };
  assert.deepEqual(turnForward(start, 0, 3), start);
  assert.deepEqual(turnForward(start, Number.NaN, 3), start);
});

test("the previous page stays in the chapter when one exists", () => {
  assert.deepEqual(turnBackward({ chapterIndex: 1, pageIndex: 2 }), {
    chapterIndex: 1,
    pageIndex: 1,
  });
});

test("the first page of a chapter opens the previous chapter at its last page", () => {
  assert.deepEqual(turnBackward({ chapterIndex: 1, pageIndex: 0 }), {
    chapterIndex: 0,
    pageIndex: -1,
  });
});

test("the first page of the book does not move", () => {
  const start = { chapterIndex: 0, pageIndex: 0 };
  assert.deepEqual(turnBackward(start), start);
});

test("waiting for the previous chapter's last page does not skip another chapter", () => {
  const waiting = { chapterIndex: 1, pageIndex: -1 };
  assert.deepEqual(turnBackward(waiting), waiting);
});

test("relocated reports become a page position", () => {
  assert.deepEqual(readRelocated({ type: "relocated", pageIndex: 1, pageCount: 5 }), {
    pageIndex: 1,
    pageCount: 5,
  });
  assert.deepEqual(readRelocated('{"type":"relocated","pageIndex":2,"pageCount":3}'), {
    pageIndex: 2,
    pageCount: 3,
  });
});

test("other host messages and unfinished layouts are ignored", () => {
  assert.equal(readRelocated({ type: "link", href: "ch2.xhtml" }), null);
  assert.equal(readRelocated({ type: "relocated", pageIndex: 0, pageCount: 0 }), null);
  assert.equal(readRelocated("not json"), null);
  assert.equal(readRelocated(null), null);
});

test("a chapter selection is the quoted text and other messages stay ignored", () => {
  assert.equal(readChapterSelection({ type: "selection", text: "  hello from epub  " }), "hello from epub");
  assert.equal(readChapterSelection('{"type":"selection","text":"Second chapter"}'), "Second chapter");
  assert.equal(readChapterSelection({ type: "selection", text: "   " }), null);
  assert.equal(readChapterSelection({ type: "relocated", pageIndex: 0, pageCount: 1 }), null);
  assert.equal(readChapterSelection("not json"), null);
  assert.equal(readChapterSelection(null), null);
});
