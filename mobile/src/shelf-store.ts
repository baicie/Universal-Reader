export type ShelfFormat = "txt" | "markdown" | "html" | "rtf" | "docx" | "odt" | "mobi" | "azw3" | "chm" | "djvu" | "epub" | "pdf" | "fb2" | "cbz" | "cbt" | "cbr" | "cb7";

export type ShelfBook = {
  id: string;
  title: string;
  author: string;
  format: ShelfFormat;
  bytes: Uint8Array;
  chapterIndex: number;
  pageIndex: number;
  cover: Uint8Array | null;
  progress: number;
  lastOpenedMs: number;
};

export type SqlValue = string | number | Uint8Array | null;

export interface ShelfDatabase {
  exec(sql: string): Promise<void>;
  all(sql: string, params?: SqlValue[]): Promise<Record<string, unknown>[]>;
  run(sql: string, params?: SqlValue[]): Promise<void>;
}

const shelfSchemaVersion = 5;

const shelfFormats = new Set<ShelfFormat>(["txt", "markdown", "html", "rtf", "docx", "odt", "mobi", "azw3", "chm", "djvu", "epub", "pdf", "fb2", "cbz", "cbt", "cbr", "cb7"]);

export class ShelfSchemaError extends Error {
  constructor() {
    super("unsupported shelf schema");
    this.name = "ShelfSchemaError";
  }
}

export async function contentHash(bytes: Uint8Array): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new Uint8Array(bytes));
  return [...new Uint8Array(digest)].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

export async function loadShelf(db: ShelfDatabase): Promise<ShelfBook[]> {
  await ensureShelfSchema(db);
  const rows = await db.all(
    "SELECT id, title, author, format, chapter_index, page_index, progress, last_opened_ms FROM books ORDER BY sort_index ASC",
  );
  // Read the cover by itself. On the web driver, two blobs in one row share memory and the second one is shifted.
  const coverRows = await db.all("SELECT id, cover FROM books WHERE cover IS NOT NULL");
  const covers = new Map<string, Uint8Array>();
  for (const row of coverRows) {
    if (typeof row.id !== "string") continue;
    const cover = asBytes(row.cover);
    if (cover) covers.set(row.id, cover);
  }
  const books: ShelfBook[] = [];
  for (const row of rows) {
    if (typeof row.id !== "string" || row.id.length === 0) continue;
    // Read this book's bytes alone. The web driver reuses one buffer for every blob in a result, so a later row overwrites the earlier ones.
    const byteRows = await db.all("SELECT bytes FROM books WHERE id = ?", [row.id]);
    const book = bookFromRow({ ...row, bytes: byteRows[0]?.bytes }, covers.get(row.id) ?? null);
    if (book) books.push(book);
  }
  return books;
}

export async function importShelfBook(
  db: ShelfDatabase,
  input: { title: string; author?: string; format: ShelfFormat; bytes: Uint8Array; cover?: Uint8Array | null },
): Promise<ShelfBook> {
  const id = await contentHash(input.bytes);
  const cover = input.cover ?? null;
  const author = bookAuthorForWrite(input.author ?? "");
  const existing = (await loadShelf(db)).find((book) => book.id === id);
  if (existing) {
    if (existing.cover == null && cover != null) {
      await db.run("UPDATE books SET cover = ? WHERE id = ?", [cover, existing.id]);
      return { ...existing, cover };
    }
    return existing;
  }

  await db.exec("BEGIN");
  try {
    await db.run("UPDATE books SET sort_index = sort_index + 1");
    await db.run(
      "INSERT INTO books (id, title, author, format, bytes, chapter_index, page_index, sort_index, cover) VALUES (?, ?, ?, ?, ?, 0, 0, 0, ?)",
      [id, input.title, author, input.format, input.bytes, cover],
    );
    await db.exec("COMMIT");
  } catch (error) {
    try {
      await db.exec("ROLLBACK");
    } catch {
      // The failed statement may already have closed the transaction.
    }
    throw error;
  }
  return {
    id,
    title: input.title,
    author,
    format: input.format,
    bytes: input.bytes,
    chapterIndex: 0,
    pageIndex: 0,
    cover,
    progress: 0,
    lastOpenedMs: 0,
  };
}

export async function writeShelfPlace(
  db: ShelfDatabase,
  id: string,
  chapterIndex: number,
  pageIndex: number,
  reading?: { progress: number; lastOpenedMs: number },
): Promise<void> {
  if (id.length === 0) return;
  if (!isPlace(chapterIndex) || !isPlace(pageIndex)) return;
  const progress = reading ? clampProgress(reading.progress) : 0;
  const lastOpenedMs = reading ? openedAt(reading.lastOpenedMs) : Date.now();
  await ensureShelfSchema(db);
  await db.run(
    "UPDATE books SET chapter_index = ?, page_index = ?, progress = ?, last_opened_ms = ? WHERE id = ?",
    [chapterIndex, pageIndex, progress, lastOpenedMs, id],
  );
}

export async function deleteShelfBook(db: ShelfDatabase, id: string): Promise<void> {
  await ensureShelfSchema(db);
  await db.run("DELETE FROM conversations WHERE document_id = ?", [id]);
  await db.run("DELETE FROM notes WHERE document_id = ?", [id]);
  await db.run("DELETE FROM books WHERE id = ?", [id]);
}

const maxBookIdentityLength = 200;

export function bookTitleForWrite(requested: string, current: string): string {
  const trimmed = requested.trim();
  if (trimmed.length === 0) return current;
  return clipBookIdentity(trimmed);
}

export function bookAuthorForWrite(requested: string): string {
  return clipBookIdentity(requested.trim());
}

function clipBookIdentity(value: string): string {
  if (value.length <= maxBookIdentityLength) return value;
  return value.slice(0, maxBookIdentityLength);
}

export async function writeShelfIdentity(db: ShelfDatabase, id: string, title: string, author: string): Promise<void> {
  if (id.length === 0) return;
  await ensureShelfSchema(db);
  const current = (await loadShelf(db)).find((book) => book.id === id);
  if (!current) return;
  await db.run("UPDATE books SET title = ?, author = ? WHERE id = ?", [
    bookTitleForWrite(title, current.title),
    bookAuthorForWrite(author),
    id,
  ]);
}

export async function ensureShelfSchema(db: ShelfDatabase): Promise<void> {
  const version = await userVersion(db);
  if (version > shelfSchemaVersion) throw new ShelfSchemaError();
  await db.exec(`
    CREATE TABLE IF NOT EXISTS books (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      format TEXT NOT NULL,
      bytes BLOB NOT NULL,
      chapter_index INTEGER NOT NULL,
      page_index INTEGER NOT NULL,
      sort_index INTEGER NOT NULL
    )
  `);
  const columns = await db.all("PRAGMA table_info(books)");
  const names = new Set(columns.map((row) => row.name));
  if (!names.has("cover")) await db.exec("ALTER TABLE books ADD COLUMN cover BLOB");
  if (!names.has("author")) await db.exec("ALTER TABLE books ADD COLUMN author TEXT NOT NULL DEFAULT ''");
  if (!names.has("progress")) await db.exec("ALTER TABLE books ADD COLUMN progress REAL NOT NULL DEFAULT 0");
  if (!names.has("last_opened_ms")) {
    await db.exec("ALTER TABLE books ADD COLUMN last_opened_ms INTEGER NOT NULL DEFAULT 0");
  }
  await db.exec(`
    CREATE TABLE IF NOT EXISTS conversations (
      document_id TEXT PRIMARY KEY,
      turns_json TEXT NOT NULL
    )
  `);
  await db.exec(`
    CREATE TABLE IF NOT EXISTS notes (
      document_id TEXT NOT NULL,
      id TEXT NOT NULL,
      note TEXT NOT NULL,
      quote TEXT NOT NULL,
      locator_label TEXT NOT NULL,
      source TEXT NOT NULL,
      created_at_ms INTEGER NOT NULL,
      PRIMARY KEY (document_id, id)
    )
  `);
  if (version !== shelfSchemaVersion) await db.exec(`PRAGMA user_version = ${shelfSchemaVersion}`);
}

async function userVersion(db: ShelfDatabase): Promise<number> {
  const rows = await db.all("PRAGMA user_version");
  const version = rows[0]?.user_version;
  if (typeof version !== "number" || !Number.isInteger(version) || version < 0) return 0;
  return version;
}

function bookFromRow(row: Record<string, unknown>, cover: Uint8Array | null): ShelfBook | null {
  if (typeof row.id !== "string" || row.id.length === 0) return null;
  if (typeof row.title !== "string") return null;
  if (!isFormat(row.format)) return null;
  const bytes = asBytes(row.bytes);
  const chapterIndex = asPlace(row.chapter_index);
  const pageIndex = asPlace(row.page_index);
  if (bytes == null || chapterIndex == null || pageIndex == null) return null;
  return {
    id: row.id,
    title: row.title,
    author: asAuthor(row.author),
    format: row.format,
    bytes,
    chapterIndex,
    pageIndex,
    cover,
    progress: asProgress(row.progress),
    lastOpenedMs: asOpened(row.last_opened_ms),
  };
}

function isFormat(value: unknown): value is ShelfFormat {
  return typeof value === "string" && shelfFormats.has(value as ShelfFormat);
}

function isPlace(value: number): boolean {
  return Number.isInteger(value) && value >= 0;
}

function clampProgress(value: number): number {
  if (!Number.isFinite(value)) return 0;
  return Math.min(1, Math.max(0, value));
}

function openedAt(value: number): number {
  if (!Number.isFinite(value) || value < 0) return 0;
  return Math.floor(value);
}

function asAuthor(value: unknown): string {
  return typeof value === "string" ? value : "";
}

function asProgress(value: unknown): number {
  return typeof value === "number" ? clampProgress(value) : 0;
}

function asOpened(value: unknown): number {
  if (typeof value === "number") return openedAt(value);
  if (typeof value === "bigint" && value >= 0n && value <= BigInt(Number.MAX_SAFE_INTEGER)) return Number(value);
  return 0;
}

function asPlace(value: unknown): number | null {
  if (typeof value === "number" && isPlace(value)) return value;
  if (typeof value === "bigint" && value >= 0n && value <= BigInt(Number.MAX_SAFE_INTEGER)) {
    const asNumber = Number(value);
    return isPlace(asNumber) ? asNumber : null;
  }
  return null;
}

function asBytes(value: unknown): Uint8Array | null {
  if (value instanceof Uint8Array) return new Uint8Array(value);
  if (value instanceof ArrayBuffer) return new Uint8Array(value);
  if (ArrayBuffer.isView(value)) {
    // Copy immediately. A database driver can hand back a view of memory it reuses.
    return new Uint8Array(value.buffer.slice(value.byteOffset, value.byteOffset + value.byteLength));
  }
  if (!Array.isArray(value)) return null;
  const bytes = new Uint8Array(value.length);
  for (let index = 0; index < value.length; index += 1) {
    const byte = value[index];
    if (typeof byte !== "number" || !Number.isInteger(byte) || byte < 0 || byte > 255) return null;
    bytes[index] = byte;
  }
  return bytes;
}
