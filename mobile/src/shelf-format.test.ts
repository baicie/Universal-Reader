import assert from "node:assert/strict";
import test from "node:test";

import { parseShelfFormatFilter, shelfByFormat, shelfFormatKind } from "./shelf-format";

const books = [
  { id: "notes", format: "txt" },
  { id: "chapter", format: "epub" },
  { id: "pages", format: "pdf" },
  { id: "scan", format: "djvu" },
  { id: "covered", format: "cbz" },
  { id: "tape", format: "cbr" },
  { id: "pack", format: "cb7" },
  { id: "tar", format: "cbt" },
  { id: "help", format: "chm" },
];

test("format filter keeps this shelf and drops the other kinds", () => {
  const all = shelfByFormat(books, "all");
  assert.deepEqual(
    all.map((book) => book.id),
    books.map((book) => book.id),
  );
  assert.notEqual(all, books);
  assert.equal(books[0]?.id, "notes");

  assert.deepEqual(
    shelfByFormat(books, "reflow").map((book) => book.id),
    ["notes", "chapter", "help"],
  );
  assert.deepEqual(
    shelfByFormat(books, "fixedPage").map((book) => book.id),
    ["pages", "scan"],
  );
  assert.deepEqual(
    shelfByFormat(books, "comic").map((book) => book.id),
    ["covered", "tape", "pack", "tar"],
  );
  assert.deepEqual(shelfByFormat(books, "nope"), []);
  assert.equal(shelfFormatKind("html"), "reflow");
  assert.equal(shelfFormatKind("mobi"), "reflow");
  assert.equal(shelfFormatKind("unknown"), "reflow");
  assert.equal(parseShelfFormatFilter("comic"), "comic");
  assert.equal(parseShelfFormatFilter("nope"), "all");
});
