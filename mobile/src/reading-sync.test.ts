import assert from "node:assert/strict";
import test from "node:test";

import { S3Error } from "./s3";
import { WebDavError } from "./webdav";
import {
  READING_SYNC_BYTE_LIMIT,
  READING_SYNC_FILE,
  ReadingSyncError,
  applyReadingSnapshot,
  localReadingSnapshot,
  mergeReadingSnapshots,
  parseReadingSnapshot,
  placeProgress,
  serializeReadingSnapshot,
  syncS3Reading,
  syncWebDavReading,
  type ReadingBook,
} from "./reading-sync";

const account = {
  endpoint: "https://s3.example.test",
  region: "us-east-1",
  bucket: "books",
  prefix: "library",
  accessKey: "access",
  secretKey: "secret-pass",
  now: new Date("2013-05-24T00:00:00.000Z"),
};

test("the reading sync file is the reserved metadata name and stays within 16 MiB", () => {
  assert.equal(READING_SYNC_FILE, "universal-reader-sync.json");
  assert.equal(READING_SYNC_BYTE_LIMIT, 16 * 1024 * 1024);
});

test("place progress stays between the first and last position", () => {
  assert.equal(placeProgress(0, 2), 0);
  assert.equal(placeProgress(1, 2), 1);
  assert.equal(placeProgress(0, 1), 0);
});

test("a newer remote place moves this book and leaves the other book alone", () => {
  const localBook = shelf("abc123", "notes", 0, 0, 0.2, 10);
  const other = shelf("def456", "other", 2, 1, 0.4, 50);
  const remote = parseReadingSnapshot(
    json({
      version: 1,
      documents: [
        {
          content_hash: "abc123",
          progress: 0.8,
          last_opened_ms: 20,
          chapter_index: 1,
          page_index: 4,
          annotations: [{ id: "keep-me", note: "remote note", created_at_ms: 5 }],
        },
        {
          content_hash: "unread99",
          file_name: "later.txt",
          progress: 0.3,
          last_opened_ms: 8,
          chapter_index: 3,
          page_index: 0,
        },
      ],
    }),
  );
  const merged = mergeReadingSnapshots(localReadingSnapshot([localBook, other]), remote);
  const applied = applyReadingSnapshot([localBook, other], merged);
  const moved = applied.books.find((book) => book.id === "abc123");
  const kept = applied.books.find((book) => book.id === "def456");

  assert.equal(moved?.chapterIndex, 1);
  assert.equal(moved?.pageIndex, 4);
  assert.equal(moved?.progress, 0.8);
  assert.equal(moved?.lastOpenedMs, 20);
  assert.equal(new TextDecoder().decode(moved?.bytes), "notes-body");
  assert.equal(kept?.chapterIndex, 2);
  assert.equal(kept?.pageIndex, 1);
  assert.equal(applied.unmatchedRemote, 1);
  const written = JSON.parse(new TextDecoder().decode(serializeReadingSnapshot(merged))) as {
    documents: { content_hash: string; annotations?: { note?: string }[]; file_name?: string }[];
  };
  const remoteNotes = written.documents.find((document) => document.content_hash === "abc123");
  const waiting = written.documents.find((document) => document.content_hash === "unread99");
  assert.equal(remoteNotes?.annotations?.[0]?.note, "remote note");
  assert.equal(waiting?.file_name, "later.txt");
});

test("the same open time keeps the larger progress", () => {
  const local = localReadingSnapshot([shelf("abc123", "notes", 0, 0, 0.2, 10)]);
  const remote = parseReadingSnapshot(
    json({
      version: 1,
      documents: [{ content_hash: "abc123", progress: 0.9, last_opened_ms: 10, chapter_index: 2, page_index: 0 }],
    }),
  );
  const merged = mergeReadingSnapshots(local, remote);
  assert.equal(merged.documents[0]?.progress, 0.9);
  assert.equal(merged.documents[0]?.chapterIndex, 2);
});

test("a tombstone drops an older note and a newer note removes the tombstone", () => {
  const local = parseReadingSnapshot(
    json({
      version: 1,
      documents: [
        {
          content_hash: "abc123",
          deleted_annotations: [{ id: "gone", deleted_at_ms: 20 }],
        },
      ],
    }),
  );
  const remote = parseReadingSnapshot(
    json({
      version: 1,
      documents: [
        {
          content_hash: "abc123",
          annotations: [
            { id: "gone", note: "old", created_at_ms: 10 },
            { id: "same", note: "new", created_at_ms: 20 },
          ],
          deleted_annotations: [{ id: "same", deleted_at_ms: 10 }],
        },
      ],
    }),
  );
  const merged = mergeReadingSnapshots(local, remote);
  assert.deepEqual(
    merged.documents[0]?.annotations.map((note) => note.id),
    ["same"],
  );
  assert.deepEqual(
    merged.documents[0]?.deletedAnnotations.map((tombstone) => tombstone.id),
    ["gone"],
  );
});

test("an unknown snapshot version or corrupt bytes are refused", () => {
  assert.throws(() => parseReadingSnapshot(json({ version: 2, documents: [] })), ReadingSyncError);
  assert.throws(() => parseReadingSnapshot(new TextEncoder().encode("{")), ReadingSyncError);
  assert.throws(
    () => parseReadingSnapshot(json({ version: 1, documents: [{ content_hash: "bad hash" }] })),
    ReadingSyncError,
  );
  const huge = new Uint8Array(READING_SYNC_BYTE_LIMIT + 1);
  assert.throws(() => parseReadingSnapshot(huge), ReadingSyncError);
});

test("s3 reading sync writes the merged snapshot and moves only the matching book", async () => {
  const books = [shelf("abc123", "notes", 0, 0, 0, 0), shelf("def456", "other", 1, 0, 0, 0)];
  const puts: string[] = [];
  const fetchImpl: typeof fetch = async (input, init) => {
    const url = String(input);
    if (init?.method === "PUT") {
      const raw = init.body instanceof Uint8Array ? init.body : new Uint8Array();
      puts.push(new TextDecoder().decode(raw));
      assert.equal(url, "https://s3.example.test/books/library/universal-reader-sync.json");
      assert.equal(new Headers(init.headers).get("authorization")?.includes("secret-pass"), false);
      return new Response(null, { status: 200 });
    }
    if (url.endsWith("/universal-reader-sync.json")) {
      return new Response(
        JSON.stringify({
          version: 1,
          documents: [{ content_hash: "abc123", progress: 1, last_opened_ms: 30, chapter_index: 1, page_index: 2 }],
        }),
        { status: 200 },
      );
    }
    return new Response("no", { status: 404 });
  };
  const result = await syncS3Reading(account, books, fetchImpl);
  assert.equal(result.books.find((book) => book.id === "abc123")?.chapterIndex, 1);
  assert.equal(result.books.find((book) => book.id === "abc123")?.pageIndex, 2);
  assert.equal(result.books.find((book) => book.id === "def456")?.chapterIndex, 1);
  assert.equal(puts[0]?.includes("abc123"), true);
  assert.equal(puts[0]?.includes("def456"), true);
});

test("a failed or newer-version s3 snapshot uploads nothing and leaves the shelf", async () => {
  let puts = 0;
  const books = [shelf("abc123", "notes", 4, 5, 0.2, 9)];
  const denied: typeof fetch = async (_input, init) => {
    if (init?.method === "PUT") puts += 1;
    return new Response("no", { status: 403 });
  };
  await assert.rejects(() => syncS3Reading(account, books, denied), S3Error);
  const future: typeof fetch = async (_input, init) => {
    if (init?.method === "PUT") puts += 1;
    return new Response(JSON.stringify({ version: 9, documents: [] }), { status: 200 });
  };
  await assert.rejects(() => syncS3Reading(account, books, future), ReadingSyncError);
  assert.equal(puts, 0);
});

test("webdav reading sync uploads the merged file and a missing file starts from this shelf", async () => {
  const books = [shelf("abc123", "notes", 1, 2, 0.5, 40)];
  let put = "";
  const fetchImpl: typeof fetch = async (input, init) => {
    const url = String(input);
    if (init?.method === "PUT") {
      const raw = init.body instanceof Uint8Array ? init.body : new Uint8Array();
      put = new TextDecoder().decode(raw);
      assert.equal(url, "http://127.0.0.1:8765/dav/universal-reader-sync.json");
      return new Response(null, { status: 201 });
    }
    return new Response("missing", { status: 404 });
  };
  const result = await syncWebDavReading(
    { baseUrl: "http://127.0.0.1:8765/dav/", username: "reader", password: "secret-pass" },
    books,
    fetchImpl,
  );
  assert.equal(result.books[0]?.chapterIndex, 1);
  assert.equal(put.includes("abc123"), true);
  assert.equal(put.includes("secret-pass"), false);
});

test("a failed webdav listing uploads nothing", async () => {
  let puts = 0;
  const fetchImpl: typeof fetch = async (_input, init) => {
    if (init?.method === "PUT") puts += 1;
    return new Response("no", { status: 401 });
  };
  await assert.rejects(
    () =>
      syncWebDavReading(
        { baseUrl: "http://127.0.0.1:8765/dav/", username: "reader", password: "secret-pass" },
        [shelf("abc123", "notes", 0, 0, 0, 0)],
        fetchImpl,
      ),
    (error: unknown) => error instanceof WebDavError && !(error instanceof Error && error.message.includes("secret-pass")),
  );
  assert.equal(puts, 0);
});

function shelf(
  id: string,
  title: string,
  chapterIndex: number,
  pageIndex: number,
  progress: number,
  lastOpenedMs: number,
): ReadingBook {
  return {
    id,
    title,
    author: "",
    format: "txt",
    bytes: new TextEncoder().encode(`${title}-body`),
    chapterIndex,
    pageIndex,
    cover: null,
    progress,
    lastOpenedMs,
  };
}

function json(value: unknown): Uint8Array {
  return new TextEncoder().encode(JSON.stringify(value));
}
