import assert from "node:assert/strict";
import test from "node:test";

import { readingIndexForProgress, readingPageIndexForProgress, readingPercent, readingProgress } from "./reading-progress";

test("reading progress stays inside this book", () => {
  assert.equal(readingProgress(0, 2), 0);
  assert.equal(readingProgress(1, 2), 0.5);
  assert.equal(readingProgress(0, 2, 1, 2), 0.25);
  assert.equal(readingProgress(1, 2, 1, 2), 0.75);
  assert.equal(readingProgress(0, 1), 0);
  assert.equal(readingProgress(9, 2), 0.5);
  assert.equal(readingProgress(-1, 2), 0);
  assert.equal(readingProgress(0, 0), 0);
  assert.equal(readingPercent(0.5), 50);
  assert.equal(readingPercent(1), 100);
  assert.equal(readingPercent(Number.NaN), 0);
});

test("seeking progress lands inside this book", () => {
  assert.equal(readingIndexForProgress(0, 2), 0);
  assert.equal(readingIndexForProgress(0.49, 2), 0);
  assert.equal(readingIndexForProgress(0.5, 2), 1);
  assert.equal(readingIndexForProgress(1, 2), 1);
  assert.equal(readingIndexForProgress(2, 2), 1);
  assert.equal(readingIndexForProgress(Number.NaN, 2), 0);
  assert.equal(readingIndexForProgress(0.5, 0), 0);
  assert.equal(readingPageIndexForProgress({ progress: 0, chapterCount: 2, chapterIndex: 0, pageCount: 2 }), 0);
  assert.equal(readingPageIndexForProgress({ progress: 0.25, chapterCount: 2, chapterIndex: 0, pageCount: 2 }), 1);
  assert.equal(readingPageIndexForProgress({ progress: 1, chapterCount: 2, chapterIndex: 1, pageCount: 2 }), 1);
  assert.equal(readingPageIndexForProgress({ progress: 0.5, chapterCount: 0, chapterIndex: 0, pageCount: 2 }), 0);
});
