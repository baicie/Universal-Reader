import type { ConversationTurn } from "./conversation-store";
import { ensureShelfSchema, type ShelfDatabase } from "./shelf-store";

export const MAX_BOOK_NOTES = 100;

const sources = new Set(["user", "assistant", "bookmark"]);

export type NoteSource = "user" | "assistant" | "bookmark";

export type BookNote = {
  id: string;
  note: string;
  quote: string;
  locatorLabel: string;
  source: NoteSource;
  createdAtMs: number;
};

export class NoteError extends Error {
  constructor() {
    super("note");
    this.name = "NoteError";
  }
}

export async function loadBookNotes(db: ShelfDatabase, documentId: string): Promise<BookNote[]> {
  if (documentId.length === 0) return [];
  await ensureShelfSchema(db);
  const rows = await db.all(
    "SELECT id, note, quote, locator_label, source, created_at_ms FROM notes WHERE document_id = ? ORDER BY created_at_ms ASC, id ASC",
    [documentId],
  );
  return rows.map(noteFromRow);
}

export async function appendBookNote(
  db: ShelfDatabase,
  documentId: string,
  turn: ConversationTurn,
  createdAtMs: number,
): Promise<BookNote[]> {
  const existing = await loadBookNotes(db, documentId);
  const note = noteFromTurn(turn, createdAtMs);
  if (note == null || documentId.length === 0) return existing;
  if (existing.some((item) => item.id === note.id)) return existing;
  const next = trimNotes([...existing, note]);
  await replaceNotes(db, documentId, next);
  return next;
}

export async function removeBookNote(db: ShelfDatabase, documentId: string, noteId: string): Promise<BookNote[]> {
  const existing = await loadBookNotes(db, documentId);
  await db.run("DELETE FROM notes WHERE document_id = ? AND id = ?", [documentId, noteId]);
  return existing.filter((item) => item.id !== noteId);
}

export function bookmarkPlace(label: string): { chapterIndex: number; pageIndex: number } | null {
  const match = /^place:(\d+):(\d+)$/.exec(label);
  if (match == null) return null;
  const chapterIndex = Number(match[1]);
  const pageIndex = Number(match[2]);
  if (!isPlace(chapterIndex) || !isPlace(pageIndex)) return null;
  return { chapterIndex, pageIndex };
}

export function bookmarksOf(notes: BookNote[]): BookNote[] {
  return notes.filter((note) => note.source === "bookmark");
}

export function notesOf(notes: BookNote[]): BookNote[] {
  return notes.filter((note) => note.source !== "bookmark");
}

export function noteListLabel(note: BookNote): string {
  const quote = note.quote.trim();
  if (quote.length > 0) return quote;
  const body = note.note.trim();
  if (body.length > 0) return body;
  return note.locatorLabel;
}

export async function appendBookBookmark(
  db: ShelfDatabase,
  documentId: string,
  chapterIndex: number,
  pageIndex: number,
  createdAtMs: number,
): Promise<BookNote[]> {
  if (documentId.length === 0) return [];
  const existing = await loadBookNotes(db, documentId);
  if (!isPlace(chapterIndex) || !isPlace(pageIndex)) return existing;
  const id = `bm-${chapterIndex}-${pageIndex}`;
  if (existing.some((item) => item.id === id)) return existing;
  const next = trimNotes([
    ...existing,
    {
      id,
      note: "",
      quote: "",
      locatorLabel: `place:${chapterIndex}:${pageIndex}`,
      source: "bookmark" as const,
      createdAtMs: stamp(createdAtMs),
    },
  ]);
  await replaceNotes(db, documentId, next);
  return next;
}

export function selectionQuote(quote: string, chapterText: string): string | null {
  const trimmed = quote.trim();
  if (trimmed.length === 0 || !chapterText.includes(trimmed)) return null;
  return trimmed;
}

export async function appendBookSelection(
  db: ShelfDatabase,
  documentId: string,
  quote: string,
  chapterText: string,
  chapterIndex: number,
  pageIndex: number,
  createdAtMs: number,
): Promise<BookNote[]> {
  if (documentId.length === 0) return [];
  const existing = await loadBookNotes(db, documentId);
  const accepted = selectionQuote(quote, chapterText);
  if (accepted == null || !isPlace(chapterIndex) || !isPlace(pageIndex)) return existing;
  const locatorLabel = `place:${chapterIndex}:${pageIndex}`;
  if (existing.some((item) => item.source === "user" && item.quote === accepted && item.locatorLabel === locatorLabel)) {
    return existing;
  }
  const note: BookNote = {
    id: selectionId(chapterIndex, pageIndex, accepted),
    note: "",
    quote: accepted,
    locatorLabel,
    source: "user",
    createdAtMs: stamp(createdAtMs),
  };
  if (existing.some((item) => item.id === note.id)) return existing;
  const next = trimNotes([...existing, note]);
  await replaceNotes(db, documentId, next);
  return next;
}

function selectionId(chapterIndex: number, pageIndex: number, quote: string): string {
  let hash = 2166136261;
  for (let index = 0; index < quote.length; index += 1) {
    hash ^= quote.charCodeAt(index);
    hash = Math.imul(hash, 16777619);
  }
  return `sel-${chapterIndex}-${pageIndex}-${quote.length}-${(hash >>> 0).toString(16)}`;
}

function isPlace(value: number): boolean {
  return Number.isInteger(value) && value >= 0;
}

async function replaceNotes(db: ShelfDatabase, documentId: string, notes: BookNote[]): Promise<void> {
  await db.exec("BEGIN");
  try {
    await db.run("DELETE FROM notes WHERE document_id = ?", [documentId]);
    for (const note of notes) {
      await db.run(
        "INSERT INTO notes (document_id, id, note, quote, locator_label, source, created_at_ms) VALUES (?, ?, ?, ?, ?, ?, ?)",
        [documentId, note.id, note.note, note.quote, note.locatorLabel, note.source, note.createdAtMs],
      );
    }
    await db.exec("COMMIT");
  } catch (error) {
    try {
      await db.exec("ROLLBACK");
    } catch {
      // The failed statement may already have closed the transaction.
    }
    throw error;
  }
}

function trimNotes(notes: BookNote[]): BookNote[] {
  if (notes.length <= MAX_BOOK_NOTES) return notes;
  return notes.slice(notes.length - MAX_BOOK_NOTES);
}

function noteFromTurn(turn: ConversationTurn, createdAtMs: number): BookNote | null {
  const note = turn.reply.trim();
  if (note.length === 0) return null;
  if (!Number.isFinite(turn.createdAtMs) || turn.createdAtMs < 0) return null;
  return {
    id: String(Math.floor(turn.createdAtMs)),
    note,
    quote: turn.question,
    locatorLabel: turn.locatorLabel,
    source: "assistant",
    createdAtMs: stamp(createdAtMs),
  };
}

function noteFromRow(row: Record<string, unknown>): BookNote {
  if (typeof row.id !== "string" || row.id.length === 0) throw new NoteError();
  if (typeof row.note !== "string") throw new NoteError();
  if (typeof row.quote !== "string" || typeof row.locator_label !== "string") throw new NoteError();
  if (typeof row.source !== "string" || !sources.has(row.source)) throw new NoteError();
  if (typeof row.created_at_ms !== "number" || !Number.isFinite(row.created_at_ms) || row.created_at_ms < 0) {
    throw new NoteError();
  }
  return {
    id: row.id,
    note: row.note,
    quote: row.quote,
    locatorLabel: row.locator_label,
    source: row.source as NoteSource,
    createdAtMs: Math.floor(row.created_at_ms),
  };
}

function stamp(value: number): number {
  if (!Number.isFinite(value) || value < 0) return 0;
  return Math.floor(value);
}
