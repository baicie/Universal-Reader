import assert from "node:assert/strict";
import test from "node:test";

import { reflowTapAction, reflowTapTurn } from "./reflow-tap";

test("a reflow tap uses the left and right thirds and stays inside this book", () => {
  assert.equal(reflowTapAction(10, 300), "previous");
  assert.equal(reflowTapAction(290, 300), "next");
  assert.equal(reflowTapAction(150, 300), "chrome");
  assert.equal(reflowTapAction(100, 300), "chrome");
  assert.equal(reflowTapAction(200, 300), "chrome");
  assert.equal(reflowTapAction(10, 0), "chrome");

  assert.deepEqual(
    reflowTapTurn({ x: 90, width: 100, chapterIndex: 0, pageIndex: 0, pageCount: 2, chapterCount: 2, pendingQuote: false }),
    { place: { chapterIndex: 0, pageIndex: 1 }, toggleChrome: false },
  );
  assert.deepEqual(
    reflowTapTurn({ x: 10, width: 100, chapterIndex: 0, pageIndex: 1, pageCount: 2, chapterCount: 2, pendingQuote: false }),
    { place: { chapterIndex: 0, pageIndex: 0 }, toggleChrome: false },
  );
  assert.deepEqual(
    reflowTapTurn({ x: 90, width: 100, chapterIndex: 0, pageIndex: 1, pageCount: 2, chapterCount: 2, pendingQuote: false }),
    { place: { chapterIndex: 1, pageIndex: 0 }, toggleChrome: false },
  );
  assert.deepEqual(
    reflowTapTurn({ x: 10, width: 100, chapterIndex: 1, pageIndex: 0, pageCount: 2, chapterCount: 2, pendingQuote: false }),
    { place: { chapterIndex: 0, pageIndex: -1 }, toggleChrome: false },
  );
  assert.deepEqual(
    reflowTapTurn({ x: 90, width: 100, chapterIndex: 1, pageIndex: 0, pageCount: 1, chapterCount: 2, pendingQuote: false }),
    { place: { chapterIndex: 1, pageIndex: 0 }, toggleChrome: false },
  );
  assert.deepEqual(
    reflowTapTurn({ x: 10, width: 100, chapterIndex: 0, pageIndex: 0, pageCount: 1, chapterCount: 2, pendingQuote: false }),
    { place: { chapterIndex: 0, pageIndex: 0 }, toggleChrome: false },
  );
  assert.deepEqual(
    reflowTapTurn({ x: 90, width: 100, chapterIndex: 0, pageIndex: 0, pageCount: 0, chapterCount: 3, pendingQuote: false }),
    { place: { chapterIndex: 0, pageIndex: 0 }, toggleChrome: false },
  );
  assert.deepEqual(
    reflowTapTurn({ x: 10, width: 100, chapterIndex: 1, pageIndex: 0, pageCount: 0, chapterCount: 3, pendingQuote: false }),
    { place: { chapterIndex: 1, pageIndex: 0 }, toggleChrome: false },
  );
  assert.deepEqual(
    reflowTapTurn({ x: 50, width: 100, chapterIndex: 1, pageIndex: 0, pageCount: 2, chapterCount: 2, pendingQuote: false }),
    { place: { chapterIndex: 1, pageIndex: 0 }, toggleChrome: true },
  );
  assert.deepEqual(
    reflowTapTurn({ x: 50, width: 100, chapterIndex: 1, pageIndex: 0, pageCount: 2, chapterCount: 2, pendingQuote: true }),
    { place: { chapterIndex: 1, pageIndex: 0 }, toggleChrome: false },
  );
  assert.deepEqual(
    reflowTapTurn({ x: 90, width: 100, chapterIndex: 0, pageIndex: 0, pageCount: 2, chapterCount: 2, pendingQuote: true }),
    { place: { chapterIndex: 0, pageIndex: 1 }, toggleChrome: false },
  );
  assert.deepEqual(
    reflowTapTurn({ x: 10, width: 0, chapterIndex: 1, pageIndex: 0, pageCount: 2, chapterCount: 2, pendingQuote: true }),
    { place: { chapterIndex: 1, pageIndex: 0 }, toggleChrome: false },
  );
});
