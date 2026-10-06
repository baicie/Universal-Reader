import assert from "node:assert/strict";
import test from "node:test";

import { continueReading, parseShelfSort, shelfSort } from "./shelf-sort";

const books = [
  { id: "notes", title: "b", progress: 0.2, lastOpenedMs: 10 },
  { id: "design", title: "A", progress: 0.9, lastOpenedMs: 30 },
  { id: "plain", title: "a", progress: 1, lastOpenedMs: 20 },
  { id: "same", title: "A", progress: 0.9, lastOpenedMs: 30 },
];

test("shelf sort keeps this shelf and reorders only the view", () => {
  const shelfOrder = shelfSort(books, "shelf");
  assert.deepEqual(
    shelfOrder.map((book) => book.id),
    ["notes", "design", "plain", "same"],
  );
  assert.equal(books[0]?.id, "notes");
  assert.notEqual(shelfOrder, books);

  assert.deepEqual(
    shelfSort(books, "title").map((book) => book.id),
    ["design", "same", "plain", "notes"],
  );
  assert.deepEqual(
    shelfSort(books, "progress").map((book) => book.id),
    ["plain", "design", "same", "notes"],
  );
  assert.deepEqual(
    shelfSort(books, "recent").map((book) => book.id),
    ["design", "same", "plain", "notes"],
  );
  assert.deepEqual(
    shelfSort(
      [
        { id: "older", title: "Older", progress: Number.NaN, lastOpenedMs: Number.NaN },
        { id: "newer", title: "Newer", progress: 0.4, lastOpenedMs: 5 },
      ],
      "progress",
    ).map((book) => book.id),
    ["newer", "older"],
  );
  assert.equal(parseShelfSort("nope"), "shelf");
  assert.equal(parseShelfSort("title"), "title");
});

test("continue reading is the newest unfinished book", () => {
  assert.equal(continueReading(books)?.id, "design");
  assert.equal(continueReading([{ id: "done", title: "Done", progress: 1, lastOpenedMs: 90 }]), null);
  assert.equal(continueReading([{ id: "new", title: "New", progress: 0, lastOpenedMs: 90 }]), null);
  assert.equal(
    continueReading([
      { id: "first", title: "First", progress: 0.4, lastOpenedMs: 8 },
      { id: "second", title: "Second", progress: 0.4, lastOpenedMs: 8 },
    ])?.id,
    "first",
  );
});
