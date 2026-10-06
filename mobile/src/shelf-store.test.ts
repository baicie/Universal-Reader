import assert from "node:assert/strict";
import { mkdtempSync, rmSync } from "node:fs";
import { DatabaseSync } from "node:sqlite";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";

import {
  contentHash,
  deleteShelfBook,
  importShelfBook,
  loadShelf,
  ShelfSchemaError,
  writeShelfIdentity,
  writeShelfPlace,
  type ShelfDatabase,
} from "./shelf-store";

function openShelfDatabase(path: string): { db: ShelfDatabase; close(): void } {
  const sqlite = new DatabaseSync(path);
  let closed = false;
  return {
    db: {
      async exec(sql) {
        sqlite.exec(sql);
      },
      async all(sql, params = []) {
        return sqlite.prepare(sql).all(...params) as Record<string, unknown>[];
      },
      async run(sql, params = []) {
        sqlite.prepare(sql).run(...params);
      },
    },
    close() {
      if (closed) return;
      closed = true;
      sqlite.close();
    },
  };
}

test("an empty shelf stays empty", async () => {
  const shelf = openShelfDatabase(":memory:");
  assert.deepEqual(await loadShelf(shelf.db), []);
  shelf.close();
});

test("imported bytes survive a new connection to the same file", async () => {
  const dir = mkdtempSync(join(tmpdir(), "ur-shelf-"));
  const path = join(dir, "shelf.sqlite");
  try {
    const first = openShelfDatabase(path);
    const imported = await importShelfBook(first.db, {
      title: "notes",
      format: "txt",
      bytes: new TextEncoder().encode("hello sqlite"),
    });
    first.close();

    const second = openShelfDatabase(path);
    const loaded = await loadShelf(second.db);
    assert.equal(loaded.length, 1);
    assert.equal(loaded[0]?.id, imported.id);
    assert.equal(loaded[0]?.title, "notes");
    assert.deepEqual(loaded[0]?.bytes, new TextEncoder().encode("hello sqlite"));
    second.close();
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("the same bytes stay one book and keep the reading place", async () => {
  const shelf = openShelfDatabase(":memory:");
  const bytes = new TextEncoder().encode("same-bytes");
  const first = await importShelfBook(shelf.db, { title: "One", format: "txt", bytes });
  await writeShelfPlace(shelf.db, first.id, 1, 2);
  const second = await importShelfBook(shelf.db, { title: "Two", format: "txt", bytes });
  const loaded = await loadShelf(shelf.db);

  assert.equal(second.id, first.id);
  assert.equal(second.title, "One");
  assert.equal(second.chapterIndex, 1);
  assert.equal(second.pageIndex, 2);
  assert.equal(loaded.length, 1);
  shelf.close();
});

test("writing a title and author changes only this book", async () => {
  const shelf = openShelfDatabase(":memory:");
  const notesBytes = new TextEncoder().encode("hello shelf");
  const notes = await importShelfBook(shelf.db, {
    title: "notes",
    format: "txt",
    bytes: notesBytes,
  });
  const other = await importShelfBook(shelf.db, {
    title: "other",
    format: "txt",
    bytes: new TextEncoder().encode("other book"),
  });
  await writeShelfPlace(shelf.db, notes.id, 1, 2, { progress: 0.4, lastOpenedMs: 90 });

  await writeShelfIdentity(shelf.db, notes.id, "  设计笔记  ", "  某作者  ");
  const renamed = await loadShelf(shelf.db);
  const renamedNotes = renamed.find((book) => book.id === notes.id);
  const renamedOther = renamed.find((book) => book.id === other.id);
  assert.equal(renamedNotes?.title, "设计笔记");
  assert.equal(renamedNotes?.author, "某作者");
  assert.equal(renamedNotes?.chapterIndex, 1);
  assert.equal(renamedNotes?.pageIndex, 2);
  assert.equal(renamedNotes?.progress, 0.4);
  assert.equal(renamedNotes?.lastOpenedMs, 90);
  assert.deepEqual(renamedNotes?.bytes, notesBytes);
  assert.equal(renamedOther?.title, "other");
  assert.equal(renamedOther?.author, "");

  await writeShelfIdentity(shelf.db, notes.id, "   ", "   ");
  const kept = (await loadShelf(shelf.db)).find((book) => book.id === notes.id);
  assert.equal(kept?.title, "设计笔记");
  assert.equal(kept?.author, "");

  await writeShelfIdentity(shelf.db, notes.id, "a".repeat(201), "b".repeat(201));
  const clipped = (await loadShelf(shelf.db)).find((book) => book.id === notes.id);
  assert.equal(clipped?.title, "a".repeat(200));
  assert.equal(clipped?.author, "b".repeat(200));

  await writeShelfIdentity(shelf.db, "missing", "seed", "nobody");
  const afterMissing = await loadShelf(shelf.db);
  assert.equal(afterMissing.find((book) => book.id === notes.id)?.title, "a".repeat(200));
  assert.equal(afterMissing.find((book) => book.id === other.id)?.title, "other");

  const again = await importShelfBook(shelf.db, {
    title: "Two",
    author: "Nope",
    format: "txt",
    bytes: notesBytes,
  });
  assert.equal(again.title, "a".repeat(200));
  assert.equal(again.author, "b".repeat(200));
  assert.equal(again.chapterIndex, 1);
  assert.equal(again.pageIndex, 2);

  const version = await shelf.db.all("PRAGMA user_version");
  assert.equal(version[0]?.user_version, 5);
  shelf.close();
});

test("a newer shelf schema is refused and the saved book stays", async () => {
  const shelf = openShelfDatabase(":memory:");
  await importShelfBook(shelf.db, {
    title: "notes",
    format: "txt",
    bytes: new TextEncoder().encode("hello sqlite"),
  });
  await shelf.db.exec("PRAGMA user_version = 99");

  await assert.rejects(() => loadShelf(shelf.db), ShelfSchemaError);

  await shelf.db.exec("PRAGMA user_version = 1");
  const loaded = await loadShelf(shelf.db);
  assert.equal(loaded.length, 1);
  assert.deepEqual(loaded[0]?.bytes, new TextEncoder().encode("hello sqlite"));
  shelf.close();
});

test("rows that are not a readable book are dropped", async () => {
  const shelf = openShelfDatabase(":memory:");
  const kept = await importShelfBook(shelf.db, {
    title: "notes",
    format: "txt",
    bytes: new TextEncoder().encode("keep"),
  });
  await shelf.db.run(
    "INSERT INTO books (id, title, format, bytes, chapter_index, page_index, sort_index) VALUES (?, ?, ?, ?, ?, ?, ?)",
    ["bad-format", "Other", "lit", new TextEncoder().encode("nope"), 0, 0, 1],
  );
  await shelf.db.run(
    "INSERT INTO books (id, title, format, bytes, chapter_index, page_index, sort_index) VALUES (?, ?, ?, ?, ?, ?, ?)",
    ["bad-page", "Broken", "txt", new TextEncoder().encode("x"), 0, -1, 2],
  );
  await shelf.db.run(
    "INSERT INTO books (id, title, format, bytes, chapter_index, page_index, sort_index) VALUES (?, ?, ?, ?, ?, ?, ?)",
    ["bad-bytes", "Broken", "txt", "not-bytes", 0, 0, 3],
  );

  const loaded = await loadShelf(shelf.db);
  assert.equal(loaded.length, 1);
  assert.equal(loaded[0]?.id, kept.id);
  assert.deepEqual(loaded[0]?.bytes, new TextEncoder().encode("keep"));
  shelf.close();
});

test("deleting one book keeps the other book's bytes", async () => {
  const shelf = openShelfDatabase(":memory:");
  const notes = await importShelfBook(shelf.db, {
    title: "notes",
    format: "txt",
    bytes: new TextEncoder().encode("hello notes"),
  });
  const other = await importShelfBook(shelf.db, {
    title: "other",
    format: "txt",
    bytes: new TextEncoder().encode("hello other"),
  });

  await deleteShelfBook(shelf.db, notes.id);
  const loaded = await loadShelf(shelf.db);

  assert.equal(loaded.length, 1);
  assert.equal(loaded[0]?.id, other.id);
  assert.deepEqual(loaded[0]?.bytes, new TextEncoder().encode("hello other"));
  shelf.close();
});

test("a missing book and a negative place do not invent a shelf entry", async () => {
  const shelf = openShelfDatabase(":memory:");
  await writeShelfPlace(shelf.db, "missing", 1, 1);
  assert.deepEqual(await loadShelf(shelf.db), []);

  const book = await importShelfBook(shelf.db, {
    title: "notes",
    format: "txt",
    bytes: new TextEncoder().encode("place"),
  });
  await writeShelfPlace(shelf.db, book.id, -1, 3);
  const loaded = await loadShelf(shelf.db);
  assert.equal(loaded[0]?.chapterIndex, 0);
  assert.equal(loaded[0]?.pageIndex, 0);
  shelf.close();
});

test("a stored cover survives a new connection and a later import keeps it", async () => {
  const dir = mkdtempSync(join(tmpdir(), "ur-shelf-cover-"));
  const path = join(dir, "shelf.sqlite");
  const cover = Uint8Array.from([0x89, 0x50, 0x4e, 0x47]);
  const replacement = Uint8Array.from([0xff, 0xd8, 0xff]);
  const first = openShelfDatabase(path);
  let second: ReturnType<typeof openShelfDatabase> | null = null;
  try {
    const imported = await importShelfBook(first.db, {
      title: "notes",
      format: "cbz",
      bytes: new TextEncoder().encode("same-bytes"),
      cover,
    });
    await writeShelfPlace(first.db, imported.id, 1, 2);
    const again = await importShelfBook(first.db, {
      title: "other",
      format: "cbz",
      bytes: new TextEncoder().encode("same-bytes"),
      cover: replacement,
    });
    assert.equal(again.chapterIndex, 1);
    assert.equal(again.pageIndex, 2);
    assert.deepEqual(again.cover, cover);
    first.close();
    second = openShelfDatabase(path);
    const loaded = await loadShelf(second.db);
    assert.deepEqual(loaded[0]?.cover, cover);
  } finally {
    first.close();
    second?.close();
    rmSync(dir, { recursive: true, force: true });
  }
});

test("a missing cover can be filled without moving the reading place", async () => {
  const shelf = openShelfDatabase(":memory:");
  const bytes = new TextEncoder().encode("pages");
  const book = await importShelfBook(shelf.db, {
    title: "notes",
    format: "cbz",
    bytes,
    cover: null,
  });
  await writeShelfPlace(shelf.db, book.id, 2, 5);
  const cover = Uint8Array.from([0x89, 0x50, 0x4e, 0x47]);
  const filled = await importShelfBook(shelf.db, {
    title: "other",
    format: "cbz",
    bytes,
    cover,
  });
  const loaded = await loadShelf(shelf.db);

  assert.equal(filled.chapterIndex, 2);
  assert.equal(filled.pageIndex, 5);
  assert.deepEqual(filled.cover, cover);
  assert.equal(loaded.length, 1);
  shelf.close();
});

test("an older shelf gains a cover column without losing the book", async () => {
  const shelf = openShelfDatabase(":memory:");
  await shelf.db.exec(`
    CREATE TABLE books (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      format TEXT NOT NULL,
      bytes BLOB NOT NULL,
      chapter_index INTEGER NOT NULL,
      page_index INTEGER NOT NULL,
      sort_index INTEGER NOT NULL
    )
  `);
  await shelf.db.exec("PRAGMA user_version = 1");
  const bytes = new TextEncoder().encode("kept");
  await shelf.db.run(
    "INSERT INTO books (id, title, format, bytes, chapter_index, page_index, sort_index) VALUES (?, ?, ?, ?, ?, ?, ?)",
    ["book-1", "notes", "txt", bytes, 3, 4, 0],
  );

  const loaded = await loadShelf(shelf.db);
  assert.equal(loaded.length, 1);
  assert.equal(loaded[0]?.title, "notes");
  assert.equal(loaded[0]?.chapterIndex, 3);
  assert.equal(loaded[0]?.pageIndex, 4);
  assert.deepEqual(loaded[0]?.bytes, bytes);
  assert.equal(loaded[0]?.cover, null);
  shelf.close();
});

test("a current shelf version without a cover column still opens the book", async () => {
  const shelf = openShelfDatabase(":memory:");
  await shelf.db.exec(`
    CREATE TABLE books (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      format TEXT NOT NULL,
      bytes BLOB NOT NULL,
      chapter_index INTEGER NOT NULL,
      page_index INTEGER NOT NULL,
      sort_index INTEGER NOT NULL
    )
  `);
  await shelf.db.exec("PRAGMA user_version = 2");
  const bytes = new TextEncoder().encode("kept");
  await shelf.db.run(
    "INSERT INTO books (id, title, format, bytes, chapter_index, page_index, sort_index) VALUES (?, ?, ?, ?, ?, ?, ?)",
    ["book-1", "notes", "txt", bytes, 1, 0, 0],
  );

  const loaded = await loadShelf(shelf.db);
  assert.equal(loaded.length, 1);
  assert.deepEqual(loaded[0]?.bytes, bytes);
  assert.equal(loaded[0]?.cover, null);
  shelf.close();
});

test("a cover stored as a database view stays intact after that buffer changes", async () => {
  const png = Uint8Array.from([0x89, 0x50, 0x4e, 0x47, 1, 2, 3, 4]);
  const backing = new Uint8Array(png);
  const db: ShelfDatabase = {
    async exec() {},
    async all(sql) {
      if (sql.includes("user_version")) return [{ user_version: 2 }];
      if (sql.includes("table_info")) return [{ name: "cover" }];
      return [
        {
          id: "a",
          title: "notes",
          format: "txt",
          bytes: png,
          chapter_index: 0,
          page_index: 0,
          cover: new DataView(backing.buffer),
        },
      ];
    },
    async run() {},
  };

  const loaded = await loadShelf(db);
  backing.fill(0);
  assert.deepEqual(loaded[0]?.cover, png);
});

test("an older shelf keeps its chapter and stores when it was opened", async () => {
  const shelf = openShelfDatabase(":memory:");
  await shelf.db.exec(`
    CREATE TABLE books (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      format TEXT NOT NULL,
      bytes BLOB NOT NULL,
      chapter_index INTEGER NOT NULL,
      page_index INTEGER NOT NULL,
      sort_index INTEGER NOT NULL,
      cover BLOB
    )
  `);
  await shelf.db.exec("PRAGMA user_version = 2");
  const bytes = new TextEncoder().encode("kept");
  await shelf.db.run(
    "INSERT INTO books (id, title, format, bytes, chapter_index, page_index, sort_index) VALUES (?, ?, ?, ?, ?, ?, ?)",
    ["abc123", "notes", "txt", bytes, 3, 4, 0],
  );

  const loaded = await loadShelf(shelf.db);
  assert.equal(loaded[0]?.chapterIndex, 3);
  assert.equal(loaded[0]?.progress, 0);
  assert.equal(loaded[0]?.lastOpenedMs, 0);
  await writeShelfPlace(shelf.db, "abc123", 3, 4, { progress: 0.5, lastOpenedMs: 80 });
  const again = await loadShelf(shelf.db);
  assert.equal(again[0]?.chapterIndex, 3);
  assert.equal(again[0]?.pageIndex, 4);
  assert.equal(again[0]?.progress, 0.5);
  assert.equal(again[0]?.lastOpenedMs, 80);
  assert.deepEqual(again[0]?.bytes, bytes);
  shelf.close();
});

test("content hash is sha-256 of the file bytes", async () => {
  assert.equal(
    await contentHash(new TextEncoder().encode("abc")),
    "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
  );
});

test("each book's bytes stay intact when one blob buffer is reused across rows", async () => {
  const notes = new TextEncoder().encode("hello shelf");
  const other = new TextEncoder().encode("second book");
  const shared = new Uint8Array(other);
  const db: ShelfDatabase = {
    async exec() {},
    async all(sql, params = []) {
      if (sql.includes("user_version")) return [{ user_version: 2 }];
      if (sql.includes("table_info")) return [{ name: "cover" }];
      if (sql.includes("SELECT id, cover")) return [];
      if (sql.includes("SELECT bytes FROM books WHERE id")) {
        const id = params[0];
        if (id === "notes") return [{ bytes: notes }];
        if (id === "other") return [{ bytes: other }];
        return [];
      }
      return [
        {
          id: "notes",
          title: "notes",
          format: "txt",
          bytes: shared.subarray(0, notes.length),
          chapter_index: 0,
          page_index: 0,
        },
        {
          id: "other",
          title: "other",
          format: "txt",
          bytes: shared.subarray(0, other.length),
          chapter_index: 0,
          page_index: 0,
        },
      ];
    },
    async run() {},
  };

  const loaded = await loadShelf(db);
  assert.equal(new TextDecoder().decode(loaded.find((book) => book.id === "notes")?.bytes), "hello shelf");
  assert.equal(new TextDecoder().decode(loaded.find((book) => book.id === "other")?.bytes), "second book");
});
