import assert from "node:assert/strict";
import { DatabaseSync } from "node:sqlite";
import test from "node:test";

import {
  ConversationError,
  appendBookConversation,
  loadBookConversation,
  type ConversationTurn,
} from "./conversation-store";
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

function turn(reply: string, createdAtMs: number, question = "what is this"): ConversationTurn {
  return { kind: "ask", question, reply, locatorLabel: "2 / 2", createdAtMs };
}

test("a book with no conversation loads none", async () => {
  const shelf = openShelfDatabase();
  const book = await importShelfBook(shelf.db, {
    title: "search-chapters",
    format: "txt",
    bytes: new TextEncoder().encode("zinc chapter marker"),
  });

  assert.deepEqual(await loadBookConversation(shelf.db, book.id), []);
  shelf.close();
});

test("a saved reply reloads for this book and the other book stays empty", async () => {
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

  const saved = await appendBookConversation(shelf.db, current.id, turn("zinc fixture reply", 40));
  const reloaded = await loadBookConversation(shelf.db, current.id);

  assert.equal(saved.length, 1);
  assert.equal(reloaded[0]?.reply, "zinc fixture reply");
  assert.equal(reloaded[0]?.question, "what is this");
  assert.equal(reloaded[0]?.locatorLabel, "2 / 2");
  assert.equal(reloaded[0]?.createdAtMs, 40);
  assert.deepEqual(await loadBookConversation(shelf.db, other.id), []);
  shelf.close();
});

test("the oldest turn drops after fifty replies", async () => {
  const shelf = openShelfDatabase();
  const book = await importShelfBook(shelf.db, {
    title: "search-chapters",
    format: "txt",
    bytes: new TextEncoder().encode("zinc chapter marker"),
  });
  for (let index = 0; index < 50; index += 1) {
    await appendBookConversation(shelf.db, book.id, turn(`reply ${index}`, index));
  }

  const saved = await appendBookConversation(shelf.db, book.id, turn("newest reply", 50));

  assert.equal(saved.length, 50);
  assert.equal(saved[0]?.reply, "reply 1");
  assert.equal(saved[49]?.reply, "newest reply");
  shelf.close();
});

test("corrupt conversation json is refused and left in place", async () => {
  const shelf = openShelfDatabase();
  const book = await importShelfBook(shelf.db, {
    title: "search-chapters",
    format: "txt",
    bytes: new TextEncoder().encode("zinc chapter marker"),
  });
  await shelf.db.run("INSERT INTO conversations (document_id, turns_json) VALUES (?, ?)", [
    book.id,
    "{not json",
  ]);

  await assert.rejects(() => loadBookConversation(shelf.db, book.id), (error: unknown) => {
    assert.ok(error instanceof ConversationError);
    assert.equal(error.message, "conversation");
    return true;
  });
  await assert.rejects(
    () => appendBookConversation(shelf.db, book.id, turn("replacement", 1)),
    ConversationError,
  );
  const rows = await shelf.db.all("SELECT turns_json FROM conversations WHERE document_id = ?", [book.id]);
  assert.equal(rows[0]?.turns_json, "{not json");
  shelf.close();
});

test("deleting a book removes its conversation and keeps the other", async () => {
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
  await appendBookConversation(shelf.db, current.id, turn("zinc fixture reply", 1));
  await appendBookConversation(shelf.db, other.id, turn("plain reply", 2, "about plain"));

  await deleteShelfBook(shelf.db, current.id);

  assert.deepEqual(await loadBookConversation(shelf.db, current.id), []);
  assert.equal((await loadBookConversation(shelf.db, other.id))[0]?.reply, "plain reply");
  shelf.close();
});

test("an empty reply is not stored", async () => {
  const shelf = openShelfDatabase();
  const book = await importShelfBook(shelf.db, {
    title: "search-chapters",
    format: "txt",
    bytes: new TextEncoder().encode("zinc chapter marker"),
  });

  const saved = await appendBookConversation(shelf.db, book.id, turn("   ", 1));

  assert.deepEqual(saved, []);
  assert.deepEqual(await loadBookConversation(shelf.db, book.id), []);
  shelf.close();
});
