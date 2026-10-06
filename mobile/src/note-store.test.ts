import assert from "node:assert/strict";
import { DatabaseSync } from "node:sqlite";
import test from "node:test";

import { appendBookConversation, loadBookConversation, type ConversationTurn } from "./conversation-store";
import { NoteError, appendBookBookmark, appendBookNote, appendBookSelection, bookmarkPlace, bookmarksOf, loadBookNotes, noteListLabel, notesOf, removeBookNote } from "./note-store";
import { deleteShelfBook, importShelfBook, type ShelfDatabase } from "./shelf-store";

function openShelfDatabase(): { db: ShelfDatabase; close(): void } {
  const sqlite = new DatabaseSync(":memory:");
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
      sqlite.close();
    },
  };
}

function turn(reply: string, createdAtMs: number): ConversationTurn {
  return { kind: "ask", question: "what is this", reply, locatorLabel: "2 / 2", createdAtMs };
}

test("a book with no notes loads none", async () => {
  const shelf = openShelfDatabase();
  const book = await importShelfBook(shelf.db, {
    title: "search-chapters",
    format: "txt",
    bytes: new TextEncoder().encode("zinc chapter marker"),
  });

  assert.deepEqual(await loadBookNotes(shelf.db, book.id), []);
  shelf.close();
});

test("a saved reply becomes this book's note and the other book stays empty", async () => {
  const shelf = openShelfDatabase();
  const current = await importShelfBook(shelf.db, {
    title: "search-chapters",
    format: "txt",
    bytes: new TextEncoder().encode("zinc chapter marker"),
  });
  const other = await importShelfBook(shelf.db, {
    title: "plain",
    format: "txt",
    bytes: new TextEncoder().encode("hello shelf"),
  });

  const saved = await appendBookNote(shelf.db, current.id, turn("zinc fixture reply", 40), 80);
  const reloaded = await loadBookNotes(shelf.db, current.id);

  assert.equal(saved.length, 1);
  assert.equal(reloaded[0]?.id, "40");
  assert.equal(reloaded[0]?.note, "zinc fixture reply");
  assert.equal(reloaded[0]?.quote, "what is this");
  assert.equal(reloaded[0]?.locatorLabel, "2 / 2");
  assert.equal(reloaded[0]?.source, "assistant");
  assert.equal(reloaded[0]?.createdAtMs, 80);
  assert.deepEqual(await loadBookNotes(shelf.db, other.id), []);
  shelf.close();
});

test("saving the same reply again does not add a second note", async () => {
  const shelf = openShelfDatabase();
  const book = await importShelfBook(shelf.db, {
    title: "search-chapters",
    format: "txt",
    bytes: new TextEncoder().encode("zinc chapter marker"),
  });
  await appendBookNote(shelf.db, book.id, turn("zinc fixture reply", 40), 80);

  const saved = await appendBookNote(shelf.db, book.id, turn("zinc fixture reply", 40), 90);

  assert.equal(saved.length, 1);
  assert.equal(saved[0]?.createdAtMs, 80);
  shelf.close();
});

test("an empty reply is not stored as a note", async () => {
  const shelf = openShelfDatabase();
  const book = await importShelfBook(shelf.db, {
    title: "search-chapters",
    format: "txt",
    bytes: new TextEncoder().encode("zinc chapter marker"),
  });

  const saved = await appendBookNote(shelf.db, book.id, turn("   ", 40), 80);

  assert.deepEqual(saved, []);
  assert.deepEqual(await loadBookNotes(shelf.db, book.id), []);
  shelf.close();
});

test("the oldest note drops after one hundred notes", async () => {
  const shelf = openShelfDatabase();
  const book = await importShelfBook(shelf.db, {
    title: "search-chapters",
    format: "txt",
    bytes: new TextEncoder().encode("zinc chapter marker"),
  });
  for (let index = 0; index < 100; index += 1) {
    await appendBookNote(shelf.db, book.id, turn(`reply ${index}`, index), index);
  }

  const saved = await appendBookNote(shelf.db, book.id, turn("newest note", 100), 100);

  assert.equal(saved.length, 100);
  assert.equal(saved[0]?.note, "reply 1");
  assert.equal(saved[99]?.note, "newest note");
  shelf.close();
});

test("a note row with an empty id is refused and left in place", async () => {
  const shelf = openShelfDatabase();
  const book = await importShelfBook(shelf.db, {
    title: "search-chapters",
    format: "txt",
    bytes: new TextEncoder().encode("zinc chapter marker"),
  });
  await shelf.db.run(
    "INSERT INTO notes (document_id, id, note, quote, locator_label, source, created_at_ms) VALUES (?, ?, ?, ?, ?, ?, ?)",
    [book.id, "", "broken", "", "", "assistant", 1],
  );

  await assert.rejects(() => loadBookNotes(shelf.db, book.id), (error: unknown) => {
    assert.ok(error instanceof NoteError);
    assert.equal(error.message, "note");
    return true;
  });
  await assert.rejects(
    () => appendBookNote(shelf.db, book.id, turn("replacement", 2), 3),
    NoteError,
  );
  const rows = await shelf.db.all("SELECT note FROM notes WHERE document_id = ?", [book.id]);
  assert.deepEqual(
    rows.map((row) => row.note),
    ["broken"],
  );
  shelf.close();
});

test("removing a note leaves the conversation", async () => {
  const shelf = openShelfDatabase();
  const book = await importShelfBook(shelf.db, {
    title: "search-chapters",
    format: "txt",
    bytes: new TextEncoder().encode("zinc chapter marker"),
  });
  await appendBookConversation(shelf.db, book.id, turn("zinc fixture reply", 40));
  await appendBookNote(shelf.db, book.id, turn("zinc fixture reply", 40), 80);

  const notes = await removeBookNote(shelf.db, book.id, "40");

  assert.deepEqual(notes, []);
  assert.equal((await loadBookConversation(shelf.db, book.id))[0]?.reply, "zinc fixture reply");
  shelf.close();
});

test("deleting a book removes its notes and keeps the other book's note", async () => {
  const shelf = openShelfDatabase();
  const current = await importShelfBook(shelf.db, {
    title: "search-chapters",
    format: "txt",
    bytes: new TextEncoder().encode("zinc chapter marker"),
  });
  const other = await importShelfBook(shelf.db, {
    title: "plain",
    format: "txt",
    bytes: new TextEncoder().encode("hello shelf"),
  });
  await appendBookNote(shelf.db, current.id, turn("zinc fixture reply", 40), 80);
  await appendBookNote(shelf.db, other.id, turn("plain reply", 41), 81);

  await deleteShelfBook(shelf.db, current.id);

  assert.deepEqual(await loadBookNotes(shelf.db, current.id), []);
  assert.equal((await loadBookNotes(shelf.db, other.id))[0]?.note, "plain reply");
  shelf.close();
});

test("a bookmark stays on this place and leaves the other book and its note alone", async () => {
  const shelf = openShelfDatabase();
  const current = await importShelfBook(shelf.db, {
    title: "search-chapters",
    format: "txt",
    bytes: new TextEncoder().encode("zinc chapter marker"),
  });
  const other = await importShelfBook(shelf.db, {
    title: "plain",
    format: "txt",
    bytes: new TextEncoder().encode("hello shelf"),
  });
  await appendBookNote(shelf.db, current.id, turn("zinc fixture reply", 40), 80);

  const saved = await appendBookBookmark(shelf.db, current.id, 1, 2, 90);
  assert.equal(saved.length, 2);
  assert.equal(bookmarksOf(saved).length, 1);
  const mark = bookmarksOf(saved)[0];
  assert.equal(mark?.source, "bookmark");
  assert.equal(mark?.note, "");
  assert.equal(mark?.quote, "");
  assert.equal(mark?.locatorLabel, "place:1:2");
  assert.deepEqual(bookmarkPlace(mark?.locatorLabel ?? ""), { chapterIndex: 1, pageIndex: 2 });
  assert.equal(bookmarkPlace("2 / 2"), null);
  const again = await appendBookBookmark(shelf.db, current.id, 1, 2, 120);
  assert.equal(bookmarksOf(again).length, 1);
  assert.equal(again[0]?.note, "zinc fixture reply");
  const both = await appendBookBookmark(shelf.db, current.id, 0, 0, 130);
  assert.equal(bookmarksOf(both).length, 2);
  assert.equal((await appendBookBookmark(shelf.db, current.id, -1, 0, 140)).length, 3);
  assert.equal((await appendBookBookmark(shelf.db, "", 0, 0, 150)).length, 0);
  assert.deepEqual(await loadBookNotes(shelf.db, other.id), []);
  const kept = await removeBookNote(shelf.db, current.id, "bm-0-0");
  assert.equal(bookmarksOf(kept).length, 1);
  assert.equal(kept.some((note) => note.note === "zinc fixture reply"), true);
  shelf.close();
});

test("a selection in this chapter becomes one note and leaves the other book alone", async () => {
  const shelf = openShelfDatabase();
  const current = await importShelfBook(shelf.db, {
    title: "plain",
    format: "txt",
    bytes: new TextEncoder().encode("hello shelf\n\nzinc chapter marker"),
  });
  const other = await importShelfBook(shelf.db, {
    title: "other",
    format: "txt",
    bytes: new TextEncoder().encode("other book"),
  });
  await appendBookNote(shelf.db, current.id, turn("zinc fixture reply", 40), 80);
  const chapter = "hello shelf\n\nzinc chapter marker";

  const saved = await appendBookSelection(shelf.db, current.id, "  zinc chapter marker  ", chapter, 1, 0, 90);
  assert.equal(saved.length, 2);
  const mark = saved.find((note) => note.source === "user");
  assert.equal(mark?.quote, "zinc chapter marker");
  assert.equal(mark?.note, "");
  assert.equal(mark?.locatorLabel, "place:1:0");
  const again = await appendBookSelection(shelf.db, current.id, "zinc chapter marker", chapter, 1, 0, 120);
  assert.equal(again.filter((note) => note.source === "user").length, 1);
  assert.equal(again.find((note) => note.source === "user")?.id, mark?.id);
  assert.equal((await appendBookSelection(shelf.db, current.id, "   ", chapter, 1, 0, 130)).length, 2);
  assert.equal((await appendBookSelection(shelf.db, current.id, "missing sentence", chapter, 1, 0, 140)).length, 2);
  assert.equal((await appendBookSelection(shelf.db, current.id, "zinc chapter marker", chapter, -1, 0, 150)).length, 2);
  assert.equal((await appendBookSelection(shelf.db, "", "zinc chapter marker", chapter, 1, 0, 160)).length, 0);
  assert.equal(saved.some((note) => note.note === "zinc fixture reply"), true);
  assert.deepEqual(await loadBookNotes(shelf.db, other.id), []);
  shelf.close();
});

test("a note list keeps this book's sentences and leaves bookmarks out", () => {
  const notes = [
    {
      id: "n1",
      note: "fallback body",
      quote: "  hello shelf  ",
      locatorLabel: "place:0:0",
      source: "user" as const,
      createdAtMs: 1,
    },
    {
      id: "bm",
      note: "",
      quote: "",
      locatorLabel: "place:0:0",
      source: "bookmark" as const,
      createdAtMs: 2,
    },
    {
      id: "a1",
      note: "  plain reply  ",
      quote: "   ",
      locatorLabel: "2 / 2",
      source: "assistant" as const,
      createdAtMs: 3,
    },
    {
      id: "empty",
      note: "  ",
      quote: "",
      locatorLabel: "place:1:0",
      source: "user" as const,
      createdAtMs: 4,
    },
  ];
  assert.deepEqual(
    notesOf(notes).map((note) => note.id),
    ["n1", "a1", "empty"],
  );
  assert.equal(noteListLabel(notes[0]!), "hello shelf");
  assert.equal(noteListLabel(notes[2]!), "plain reply");
  assert.equal(noteListLabel(notes[3]!), "place:1:0");
  assert.deepEqual(notesOf([notes[1]!]), []);
  assert.equal(bookmarkPlace("2 / 2"), null);
});
