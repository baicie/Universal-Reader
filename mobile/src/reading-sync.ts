import { readS3Object, writeS3Object, type S3Account } from "./s3";
import { readWebDavObject, writeWebDavObject, type WebDavAccount } from "./webdav";

export const READING_SYNC_FILE = "universal-reader-sync.json";
export const READING_SYNC_BYTE_LIMIT = 16 * 1024 * 1024;

const MAX_NOTES = 100;
const MAX_TOMBSTONES = 200;

export class ReadingSyncError extends Error {
  constructor() {
    super("reading-sync");
    this.name = "ReadingSyncError";
  }
}

export type ReadingFormat = "txt" | "markdown" | "html" | "rtf" | "docx" | "odt" | "mobi" | "azw3" | "chm" | "djvu" | "epub" | "pdf" | "fb2" | "cbz" | "cbt" | "cbr" | "cb7";

export type ReadingBook = {
  id: string;
  title: string;
  author: string;
  format: ReadingFormat;
  bytes: Uint8Array;
  chapterIndex: number;
  pageIndex: number;
  cover: Uint8Array | null;
  progress: number;
  lastOpenedMs: number;
};

export type ReadingNote = {
  id: string;
  note: string;
  quote: string;
  locatorLabel: string;
  source: string;
  createdAtMs: number;
};

export type ReadingTombstone = {
  id: string;
  deletedAtMs: number;
};

export type ReadingDocument = {
  contentHash: string;
  documentId: string;
  fileName: string;
  progress: number;
  lastOpenedMs: number;
  chapterIndex: number | null;
  pageIndex: number | null;
  annotations: ReadingNote[];
  deletedAnnotations: ReadingTombstone[];
};

export type ReadingSnapshot = {
  version: 1;
  documents: ReadingDocument[];
};

export function placeProgress(index: number, count: number): number {
  if (!Number.isInteger(index) || index < 0 || !Number.isInteger(count) || count <= 1) return 0;
  return clampProgress(index / (count - 1));
}

export function localReadingSnapshot(books: readonly ReadingBook[]): ReadingSnapshot {
  const documents: ReadingDocument[] = [];
  for (const book of books) {
    if (!validSyncKey(book.id)) continue;
    documents.push({
      contentHash: book.id,
      documentId: book.id,
      fileName: fileNameFor(book),
      progress: clampProgress(book.progress),
      lastOpenedMs: openedAt(book.lastOpenedMs),
      chapterIndex: placeIndex(book.chapterIndex),
      pageIndex: placeIndex(book.pageIndex),
      annotations: [],
      deletedAnnotations: [],
    });
  }
  return normalize({ version: 1, documents });
}

export function parseReadingSnapshot(bytes: Uint8Array): ReadingSnapshot {
  if (bytes.byteLength > READING_SYNC_BYTE_LIMIT) throw new ReadingSyncError();
  let parsed: unknown;
  try {
    parsed = JSON.parse(new TextDecoder().decode(bytes));
  } catch {
    throw new ReadingSyncError();
  }
  if (!isRecord(parsed)) throw new ReadingSyncError();
  const version = parsed.version === undefined ? 1 : parsed.version;
  if (version !== 1) throw new ReadingSyncError();
  if (!Array.isArray(parsed.documents)) throw new ReadingSyncError();
  const documents: ReadingDocument[] = [];
  for (const item of parsed.documents) documents.push(documentFromJson(item));
  return normalize({ version: 1, documents });
}

export function serializeReadingSnapshot(snapshot: ReadingSnapshot): Uint8Array {
  const documents = normalize(snapshot).documents.map((document) => ({
    content_hash: document.contentHash,
    document_id: document.documentId,
    file_name: document.fileName,
    progress: document.progress,
    last_opened_ms: document.lastOpenedMs,
    ...(document.chapterIndex == null ? {} : { chapter_index: document.chapterIndex }),
    ...(document.pageIndex == null ? {} : { page_index: document.pageIndex }),
    annotations: document.annotations.map((note) => ({
      id: note.id,
      note: note.note,
      quote: note.quote,
      locator_label: note.locatorLabel,
      source: note.source,
      created_at_ms: note.createdAtMs,
    })),
    deleted_annotations: document.deletedAnnotations.map((tombstone) => ({
      id: tombstone.id,
      deleted_at_ms: tombstone.deletedAtMs,
    })),
  }));
  return new TextEncoder().encode(JSON.stringify({ version: 1, documents }));
}

export function mergeReadingSnapshots(local: ReadingSnapshot, remote: ReadingSnapshot | null): ReadingSnapshot {
  const left = normalize(local);
  if (remote == null) return left;
  const right = normalize(remote);
  const merged = new Map<string, ReadingDocument>();
  for (const document of right.documents) merged.set(document.contentHash, document);
  for (const document of left.documents) {
    const other = merged.get(document.contentHash);
    merged.set(document.contentHash, other == null ? document : mergeDocuments(document, other));
  }
  return normalize({ version: 1, documents: [...merged.values()] });
}

export function applyReadingSnapshot<T extends ReadingBook>(
  books: readonly T[],
  snapshot: ReadingSnapshot,
): { books: T[]; progressUpdated: number; unmatchedRemote: number } {
  const byHash = new Map(snapshot.documents.map((document) => [document.contentHash, document]));
  let progressUpdated = 0;
  const next = books.map((book) => {
    const document = byHash.get(book.id);
    if (document == null) return book;
    const chapterIndex = document.chapterIndex ?? book.chapterIndex;
    const pageIndex = document.pageIndex ?? book.pageIndex;
    const changed =
      book.progress !== document.progress ||
      book.lastOpenedMs !== document.lastOpenedMs ||
      book.chapterIndex !== chapterIndex ||
      book.pageIndex !== pageIndex;
    if (!changed) return book;
    progressUpdated += 1;
    return { ...book, chapterIndex, pageIndex, progress: document.progress, lastOpenedMs: document.lastOpenedMs };
  });
  const ids = new Set(books.map((book) => book.id));
  const unmatchedRemote = snapshot.documents.filter((document) => !ids.has(document.contentHash)).length;
  return { books: next, progressUpdated, unmatchedRemote };
}

export async function syncS3Reading(
  account: S3Account,
  books: readonly ReadingBook[],
  fetchImpl: typeof fetch = fetch,
): Promise<{ books: ReadingBook[]; progressUpdated: number; unmatchedRemote: number }> {
  const remote = await readS3Object(account, READING_SYNC_FILE, fetchImpl);
  const result = mergedReading(books, remote);
  await writeS3Object(account, READING_SYNC_FILE, serializeReadingSnapshot(result.snapshot), fetchImpl);
  return { books: result.books, progressUpdated: result.progressUpdated, unmatchedRemote: result.unmatchedRemote };
}

export async function syncWebDavReading(
  account: WebDavAccount,
  books: readonly ReadingBook[],
  fetchImpl: typeof fetch = fetch,
): Promise<{ books: ReadingBook[]; progressUpdated: number; unmatchedRemote: number }> {
  const remote = await readWebDavObject(account, READING_SYNC_FILE, fetchImpl);
  const result = mergedReading(books, remote);
  await writeWebDavObject(account, READING_SYNC_FILE, serializeReadingSnapshot(result.snapshot), fetchImpl);
  return { books: result.books, progressUpdated: result.progressUpdated, unmatchedRemote: result.unmatchedRemote };
}

function mergedReading(books: readonly ReadingBook[], remote: Uint8Array | null) {
  if (remote != null && remote.byteLength > READING_SYNC_BYTE_LIMIT) throw new ReadingSyncError();
  const snapshot = mergeReadingSnapshots(localReadingSnapshot(books), remote == null ? null : parseReadingSnapshot(remote));
  const applied = applyReadingSnapshot(books, snapshot);
  return { snapshot, ...applied };
}

function mergeDocuments(local: ReadingDocument, remote: ReadingDocument): ReadingDocument {
  const remoteIsNewer =
    remote.lastOpenedMs > local.lastOpenedMs || (remote.lastOpenedMs === local.lastOpenedMs && remote.progress > local.progress);
  const merged: ReadingDocument = remoteIsNewer ? { ...remote } : { ...local };
  if (merged.documentId.length === 0) merged.documentId = remote.documentId || local.documentId;
  if (merged.fileName.length === 0) merged.fileName = remote.fileName || local.fileName;
  const notes = new Map<string, ReadingNote>();
  for (const note of [...local.annotations, ...remote.annotations]) {
    if (!validSyncKey(note.id)) continue;
    const existing = notes.get(note.id);
    if (existing != null && noteRank(existing) >= noteRank(note)) continue;
    notes.set(note.id, note);
  }
  const tombstones = new Map<string, ReadingTombstone>();
  for (const tombstone of [...local.deletedAnnotations, ...remote.deletedAnnotations]) {
    if (!validSyncKey(tombstone.id)) continue;
    const existing = tombstones.get(tombstone.id);
    if (existing != null && existing.deletedAtMs >= tombstone.deletedAtMs) continue;
    tombstones.set(tombstone.id, tombstone);
  }
  for (const [id, note] of notes) {
    const tombstone = tombstones.get(id);
    if (tombstone != null && note.createdAtMs > tombstone.deletedAtMs) tombstones.delete(id);
  }
  for (const [id, note] of notes) {
    const tombstone = tombstones.get(id);
    if (tombstone != null && note.createdAtMs <= tombstone.deletedAtMs) notes.delete(id);
  }
  merged.annotations = [...notes.values()];
  merged.deletedAnnotations = [...tombstones.values()];
  return trimAnnotations(merged);
}

function normalize(snapshot: ReadingSnapshot): ReadingSnapshot {
  const byHash = new Map<string, ReadingDocument>();
  for (const document of snapshot.documents) {
    if (!validSyncKey(document.contentHash)) continue;
    const next = trimAnnotations({
      ...document,
      progress: clampProgress(document.progress),
      lastOpenedMs: openedAt(document.lastOpenedMs),
    });
    const existing = byHash.get(next.contentHash);
    byHash.set(next.contentHash, existing == null ? next : mergeDocuments(existing, next));
  }
  return {
    version: 1,
    documents: [...byHash.values()].sort((left, right) => (left.contentHash < right.contentHash ? -1 : left.contentHash > right.contentHash ? 1 : 0)),
  };
}

function documentFromJson(value: unknown): ReadingDocument {
  if (!isRecord(value)) throw new ReadingSyncError();
  const hash = stringField(value, "content_hash", "contentHash").trim();
  if (hash.length === 0) {
    return {
      contentHash: "",
      documentId: "",
      fileName: "",
      progress: 0,
      lastOpenedMs: 0,
      chapterIndex: null,
      pageIndex: null,
      annotations: [],
      deletedAnnotations: [],
    };
  }
  if (!validSyncKey(hash)) throw new ReadingSyncError();
  return {
    contentHash: hash,
    documentId: stringField(value, "document_id", "documentId"),
    fileName: stringField(value, "file_name", "fileName"),
    progress: numberField(value, "progress"),
    lastOpenedMs: openedAt(numberField(value, "last_opened_ms", "lastOpenedMs")),
    chapterIndex: optionalPlace(value, "chapter_index", "chapterIndex"),
    pageIndex: optionalPlace(value, "page_index", "pageIndex"),
    annotations: notesFrom(value.annotations),
    deletedAnnotations: tombstonesFrom(value.deleted_annotations ?? value.deletedAnnotations),
  };
}

function notesFrom(value: unknown): ReadingNote[] {
  if (value == null) return [];
  if (!Array.isArray(value)) throw new ReadingSyncError();
  const notes: ReadingNote[] = [];
  for (const item of value) {
    if (!isRecord(item)) throw new ReadingSyncError();
    const id = stringField(item, "id");
    if (!validSyncKey(id)) continue;
    notes.push({
      id,
      note: stringField(item, "note"),
      quote: stringField(item, "quote"),
      locatorLabel: stringField(item, "locator_label", "locatorLabel"),
      source: stringField(item, "source"),
      createdAtMs: openedAt(numberField(item, "created_at_ms", "createdAtMs")),
    });
  }
  return notes;
}

function tombstonesFrom(value: unknown): ReadingTombstone[] {
  if (value == null) return [];
  if (!Array.isArray(value)) throw new ReadingSyncError();
  const tombstones: ReadingTombstone[] = [];
  for (const item of value) {
    if (!isRecord(item)) throw new ReadingSyncError();
    const id = stringField(item, "id");
    if (!validSyncKey(id)) continue;
    tombstones.push({ id, deletedAtMs: openedAt(numberField(item, "deleted_at_ms", "deletedAtMs")) });
  }
  return tombstones;
}

function trimAnnotations(document: ReadingDocument): ReadingDocument {
  const annotations = document.annotations
    .filter((note) => validSyncKey(note.id))
    .sort((left, right) => left.createdAtMs - right.createdAtMs || compareText(left.id, right.id));
  const deletedAnnotations = document.deletedAnnotations
    .filter((tombstone) => validSyncKey(tombstone.id))
    .sort((left, right) => left.deletedAtMs - right.deletedAtMs || compareText(left.id, right.id));
  if (annotations.length > MAX_NOTES) annotations.splice(0, annotations.length - MAX_NOTES);
  if (deletedAnnotations.length > MAX_TOMBSTONES) deletedAnnotations.splice(0, deletedAnnotations.length - MAX_TOMBSTONES);
  return { ...document, annotations, deletedAnnotations };
}

function noteRank(note: ReadingNote): string {
  return `${note.createdAtMs.toString().padStart(16, "0")}\n${note.note}\n${note.quote}\n${note.locatorLabel}\n${note.source}`;
}

function fileNameFor(book: ReadingBook): string {
  const trimmed = book.title.trim();
  if (trimmed.length === 0 || trimmed.includes("/") || trimmed.includes("\\") || trimmed.includes("..") || trimmed.includes("\0")) {
    return "";
  }
  const extension = book.format === "markdown" ? "md" : book.format;
  const dot = trimmed.lastIndexOf(".");
  const current = dot > 0 ? trimmed.slice(dot + 1).toLowerCase() : "";
  const name = current === extension ? trimmed : `${dot > 0 ? trimmed.slice(0, dot) : trimmed}.${extension}`;
  if (name.includes("/") || name.includes("\\") || name.includes("..") || name === READING_SYNC_FILE) return "";
  return name;
}

function validSyncKey(value: string): boolean {
  return value.length > 0 && value.length <= 128 && /^[A-Za-z0-9_-]+$/.test(value);
}

function clampProgress(value: number): number {
  if (!Number.isFinite(value)) return 0;
  return Math.min(1, Math.max(0, value));
}

function openedAt(value: number): number {
  if (!Number.isFinite(value) || value < 0) return 0;
  return Math.floor(value);
}

function placeIndex(value: number): number | null {
  return Number.isInteger(value) && value >= 0 ? value : null;
}

function optionalPlace(record: Record<string, unknown>, snake: string, camel: string): number | null {
  const value = record[snake] ?? record[camel];
  if (value == null) return null;
  if (typeof value !== "number" || !Number.isInteger(value) || value < 0) return null;
  return value;
}

function numberField(record: Record<string, unknown>, snake: string, camel = snake): number {
  const value = record[snake] ?? record[camel];
  return typeof value === "number" ? value : 0;
}

function stringField(record: Record<string, unknown>, snake: string, camel = snake): string {
  const value = record[snake] ?? record[camel];
  return typeof value === "string" ? value : "";
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return value != null && typeof value === "object" && !Array.isArray(value);
}

function compareText(left: string, right: string): number {
  if (left < right) return -1;
  if (left > right) return 1;
  return 0;
}
