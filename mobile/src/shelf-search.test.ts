import assert from "node:assert/strict";
import test from "node:test";

import { shelfSearch, type ShelfSearchNote } from "./shelf-search";

type Book = { id: string; title: string; author: string; format: string };

function books(): Book[] {
  return [
    { id: "hash-notes", title: "Notes", author: "", format: "txt" },
    { id: "hash-design", title: "Design Patterns", author: "Haruki", format: "pdf" },
    { id: "hash-md", title: "Other", author: "Someone Else", format: "markdown" },
  ];
}

function label(format: string): string {
  if (format === "markdown") return "MD";
  if (format === "pdf") return "PDF";
  return "TXT";
}

test("a blank shelf query keeps every book in shelf order", () => {
  const shelf = books();
  let scanned = 0;
  const hits = shelfSearch(shelf, "   ", () => {
    scanned += 1;
    return [];
  }, label);
  assert.deepEqual(hits.map((book) => book.id), ["hash-notes", "hash-design", "hash-md"]);
  assert.equal(scanned, 0);
});

test("an unknown shelf query stays empty and does not match the book id", () => {
  const shelf = books();
  assert.deepEqual(shelfSearch(shelf, "zzz", () => [], label), []);
  assert.deepEqual(shelfSearch(shelf, "hash-design", () => [], label), []);
});

test("a shelf query matches this book's title, author, or format label", () => {
  const shelf = books();
  const titled = shelfSearch(shelf, "design", () => [], label);
  assert.deepEqual(titled.map((book) => book.id), ["hash-design"]);
  const authored = shelfSearch(shelf, "haruki", () => [], label);
  assert.deepEqual(authored.map((book) => book.id), ["hash-design"]);
  const formatted = shelfSearch(shelf, "pdf", () => [], label);
  assert.deepEqual(formatted.map((book) => book.id), ["hash-design"]);
  assert.deepEqual(shelfSearch(shelf, "markdown", () => [], label), []);
});

test("a shelf query keeps a note hit in shelf order and leaves the other book out", () => {
  const shelf = books();
  const notes = new Map<string, ShelfSearchNote[]>([
    ["hash-notes", [{ quote: "hello shelf", note: "", locatorLabel: "place:0:0" }]],
    ["hash-md", [{ quote: "second match", note: "plain reply", locatorLabel: "chapter-7" }]],
  ]);
  const quoted = shelfSearch(shelf, "Hello Shelf", (id) => notes.get(id) ?? [], label);
  assert.deepEqual(quoted.map((book) => book.id), ["hash-notes"]);
  const body = shelfSearch(shelf, "plain reply", (id) => notes.get(id) ?? [], label);
  assert.deepEqual(body.map((book) => book.id), ["hash-md"]);
  const locator = shelfSearch(shelf, "chapter-7", (id) => notes.get(id) ?? [], label);
  assert.deepEqual(locator.map((book) => book.id), ["hash-md"]);

  const both = shelfSearch(
    shelf,
    "match",
    (id) => (id === "hash-notes" ? [{ quote: "first match", note: "second match", locatorLabel: "" }] : []),
    label,
  );
  const titled = shelfSearch(
    [
      { id: "hash-notes", title: "Notes", author: "", format: "txt" },
      { id: "hash-design", title: "match", author: "", format: "pdf" },
    ],
    "match",
    (id) => (id === "hash-notes" ? [{ quote: "match too", note: "", locatorLabel: "" }] : []),
    label,
  );
  assert.deepEqual(both.map((book) => book.id), ["hash-notes"]);
  assert.deepEqual(titled.map((book) => book.id), ["hash-notes", "hash-design"]);
});

test("a shelf query still returns the title match when notes cannot be read", () => {
  const hits = shelfSearch(books(), "design", () => {
    throw new Error("disk full");
  }, label);
  assert.deepEqual(hits.map((book) => book.id), ["hash-design"]);
});
