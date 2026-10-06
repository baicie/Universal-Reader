import assert from "node:assert/strict";
import { DatabaseSync } from "node:sqlite";
import test from "node:test";

import { importShelfBook, loadShelf, type ShelfDatabase } from "./shelf-store";
import { saveReadingPrefs } from "./reading-prefs";
import {
  addCollection,
  addToCollection,
  collectionSection,
  documentMatchesSection,
  emptyShelfSections,
  loadShelfSections,
  maxCollectionName,
  maxCollections,
  parseShelfSections,
  pruneShelves,
  removeCollection,
  removeFromCollection,
  saveShelfSections,
  toggleFavorite,
  toggleInCollection,
} from "./shelf-sections";

function memoryDatabase(): ShelfDatabase {
  const sqlite = new DatabaseSync(":memory:");
  return {
    async exec(sql) {
      sqlite.exec(sql);
    },
    async all(sql, params = []) {
      return sqlite.prepare(sql).all(...params) as Record<string, unknown>[];
    },
    async run(sql, params = []) {
      sqlite.prepare(sql).run(...params);
    },
  };
}

test("favorites and collections stay inside this shelf", () => {
  assert.deepEqual(emptyShelfSections.favoriteIds, []);
  assert.equal(
    documentMatchesSection({ section: "favorites", documentId: "design", progress: 0.37, shelves: emptyShelfSections }),
    false,
  );

  const favorite = toggleFavorite(emptyShelfSections, "notes");
  assert.deepEqual(favorite.favoriteIds, ["notes"]);
  assert.equal(documentMatchesSection({ section: "favorites", documentId: "notes", progress: 0, shelves: favorite }), true);
  assert.equal(documentMatchesSection({ section: "favorites", documentId: "design", progress: 0.37, shelves: favorite }), false);
  assert.deepEqual(toggleFavorite(favorite, "notes").favoriteIds, []);
  assert.deepEqual(toggleFavorite(emptyShelfSections, "").favoriteIds, []);

  assert.equal(documentMatchesSection({ section: "reading", documentId: "x", progress: 0, shelves: favorite }), false);
  assert.equal(documentMatchesSection({ section: "reading", documentId: "x", progress: 0.5, shelves: favorite }), true);
  assert.equal(documentMatchesSection({ section: "reading", documentId: "x", progress: 1, shelves: favorite }), false);
  assert.equal(documentMatchesSection({ section: "", documentId: "design", progress: 0, shelves: emptyShelfSections }), true);
  assert.equal(
    documentMatchesSection({
      section: collectionSection("missing"),
      documentId: "design",
      progress: 0.37,
      shelves: emptyShelfSections,
    }),
    false,
  );

  assert.equal(addCollection(emptyShelfSections, "  ", 1).collections.length, 0);
  const named = addCollection(emptyShelfSections, `x`.repeat(maxCollectionName + 10), 1_000);
  assert.equal(named.collections[0]?.name.length, maxCollectionName);
  assert.equal(named.collections[0]?.id, "c-1000-0");
  let full = emptyShelfSections;
  for (let index = 0; index < maxCollections; index += 1) full = addCollection(full, `col ${index}`, index + 1);
  const overflow = addCollection(full, "one more", 99);
  assert.equal(overflow.collections.length, maxCollections);
  assert.equal(overflow.collections.at(-1)?.name, `col ${maxCollections - 1}`);

  const withBook = addToCollection(named, named.collections[0]?.id ?? "", "notes");
  assert.deepEqual(addToCollection(withBook, named.collections[0]?.id ?? "", "notes").collections[0]?.documentIds, ["notes"]);
  assert.equal(addToCollection(named, "", "notes"), named);
  assert.deepEqual(removeFromCollection(withBook, named.collections[0]?.id ?? "", "notes").collections[0]?.documentIds, []);
  const flipped = toggleInCollection(withBook, named.collections[0]?.id ?? "", "notes");
  assert.deepEqual(flipped.collections[0]?.documentIds, []);
  assert.deepEqual(toggleInCollection(flipped, named.collections[0]?.id ?? "", "notes").collections[0]?.documentIds, ["notes"]);
  assert.equal(removeCollection(withBook, named.collections[0]?.id ?? "").collections.length, 0);
  assert.equal(
    documentMatchesSection({
      section: collectionSection(named.collections[0]?.id ?? ""),
      documentId: "notes",
      progress: 0,
      shelves: withBook,
    }),
    true,
  );
  assert.equal(
    documentMatchesSection({
      section: collectionSection(named.collections[0]?.id ?? ""),
      documentId: "design",
      progress: 0,
      shelves: withBook,
    }),
    false,
  );

  const pruned = pruneShelves(
    {
      favoriteIds: ["notes", "ghost"],
      collections: [
        { id: "c-1", name: "今晚读", color: 1, documentIds: ["notes", "missing"] },
        { id: "", name: "blank", color: 1, documentIds: ["notes"] },
        { id: "c-2", name: "  ", color: 1, documentIds: ["notes"] },
      ],
    },
    ["notes"],
  );
  assert.deepEqual(pruned.favoriteIds, ["notes"]);
  assert.equal(pruned.collections.length, 1);
  assert.deepEqual(pruned.collections[0]?.documentIds, ["notes"]);
});

test("shelf sections reload without moving another book", async () => {
  const db = memoryDatabase();
  await db.exec("PRAGMA user_version = 5");
  const book = await importShelfBook(db, {
    title: "notes",
    format: "txt",
    bytes: new TextEncoder().encode("hello shelf"),
  });
  await saveReadingPrefs(db, {
    fontSize: 19,
    lineHeight: 1.7,
    fontFamily: "serif",
    paper: "dark",
    pdfZoom: 1,
    comicLayout: "single",
    comicDirection: "ltr",
  });
  assert.deepEqual(await loadShelfSections(db), emptyShelfSections);
  await saveShelfSections(db, toggleFavorite(emptyShelfSections, book.id));
  const loaded = await loadShelfSections(db);
  assert.deepEqual(loaded?.favoriteIds, [book.id]);
  assert.equal(loaded?.favoriteIds.includes("design"), false);
  const shelf = await loadShelf(db);
  assert.equal(shelf[0]?.title, "notes");
  assert.equal(shelf[0]?.chapterIndex, 0);
  const version = await db.all("PRAGMA user_version");
  assert.equal(version[0]?.user_version, 5);
  const prefs = await db.all("SELECT payload FROM reader_prefs WHERE id = ?", ["reading"]);
  assert.equal(JSON.parse(String(prefs[0]?.payload)).fontSize, 19);

  await db.run("UPDATE reader_prefs SET payload = ? WHERE id = ?", ["{", "shelves"]);
  assert.equal(await loadShelfSections(db), null);
  const kept = await db.all("SELECT payload FROM reader_prefs WHERE id = ?", ["shelves"]);
  assert.equal(kept[0]?.payload, "{");

  await db.run(
    "UPDATE reader_prefs SET payload = ? WHERE id = ?",
    [JSON.stringify({ schema_version: 2, payload: { favorites: ["notes"] } }), "shelves"],
  );
  assert.equal(await loadShelfSections(db), null);
  const newer = await db.all("SELECT payload FROM reader_prefs WHERE id = ?", ["shelves"]);
  assert.match(String(newer[0]?.payload), /"schema_version":2/);
});

test("corrupt shelf sections stay an error", () => {
  assert.throws(() => parseShelfSections("{not-json"), SyntaxError);
  assert.throws(() => parseShelfSections(JSON.stringify(["not", "a", "map"])), /corrupt shelves/);
  const parsed = parseShelfSections(
    JSON.stringify({
      favorites: ["notes", 42, null, ""],
      collections: [
        { id: "c-1", name: "A", color: 1, document_ids: ["notes", "", "design"] },
        { name: "no-id-collection" },
        { id: "c-2", name: 42, color: 1, document_ids: [] },
        "not a map",
      ],
    }),
  );
  assert.deepEqual(parsed.favoriteIds, ["notes"]);
  assert.equal(parsed.collections.length, 1);
  assert.deepEqual(parsed.collections[0]?.documentIds, ["notes", "design"]);
});
