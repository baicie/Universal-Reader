import type { ShelfDatabase } from "./shelf-store";

export const favoritesSection = "favorites";
export const readingSection = "reading";
export const collectionSectionPrefix = "collection:";
export const maxCollections = 50;
export const maxCollectionName = 40;
export const collectionColors = [0xffc69355, 0xff6c9eb4, 0xffa25848, 0xff314d49] as const;

export type ShelfCollection = {
  id: string;
  name: string;
  color: number;
  documentIds: string[];
};

export type ShelfSections = {
  favoriteIds: string[];
  collections: ShelfCollection[];
};

export const emptyShelfSections: ShelfSections = { favoriteIds: [], collections: [] };

const shelvesRow = "shelves";

export function collectionSection(id: string): string {
  return `${collectionSectionPrefix}${id}`;
}

export function documentMatchesSection(input: {
  section: string;
  documentId: string;
  progress: number;
  shelves: ShelfSections;
}): boolean {
  if (input.section === readingSection) return input.progress > 0 && input.progress < 1;
  if (input.section === favoritesSection) return input.shelves.favoriteIds.includes(input.documentId);
  if (input.section.startsWith(collectionSectionPrefix)) {
    const id = input.section.slice(collectionSectionPrefix.length);
    return input.shelves.collections.find((collection) => collection.id === id)?.documentIds.includes(input.documentId) ?? false;
  }
  return true;
}

export function toggleFavorite(shelves: ShelfSections, documentId: string): ShelfSections {
  if (documentId.length === 0) return shelves;
  const favoriteIds = shelves.favoriteIds.includes(documentId)
    ? shelves.favoriteIds.filter((id) => id !== documentId)
    : [...shelves.favoriteIds, documentId];
  return { favoriteIds, collections: shelves.collections };
}

export function addCollection(shelves: ShelfSections, name: string, now: number): ShelfSections {
  const trimmed = name.trim();
  if (trimmed.length === 0 || shelves.collections.length >= maxCollections) return shelves;
  const clipped = trimmed.length <= maxCollectionName ? trimmed : trimmed.slice(0, maxCollectionName);
  const color = collectionColors[shelves.collections.length % collectionColors.length] ?? collectionColors[0];
  return {
    favoriteIds: shelves.favoriteIds,
    collections: [
      ...shelves.collections,
      { id: `c-${now}-${shelves.collections.length}`, name: clipped, color, documentIds: [] },
    ],
  };
}

export function addToCollection(shelves: ShelfSections, collectionId: string, documentId: string): ShelfSections {
  if (collectionId.length === 0 || documentId.length === 0) return shelves;
  return {
    favoriteIds: shelves.favoriteIds,
    collections: shelves.collections.map((collection) => {
      if (collection.id !== collectionId || collection.documentIds.includes(documentId)) return collection;
      return { ...collection, documentIds: [...collection.documentIds, documentId] };
    }),
  };
}

export function removeFromCollection(shelves: ShelfSections, collectionId: string, documentId: string): ShelfSections {
  return {
    favoriteIds: shelves.favoriteIds,
    collections: shelves.collections.map((collection) =>
      collection.id === collectionId
        ? { ...collection, documentIds: collection.documentIds.filter((id) => id !== documentId) }
        : collection,
    ),
  };
}

export function toggleInCollection(shelves: ShelfSections, collectionId: string, documentId: string): ShelfSections {
  const member = shelves.collections.some(
    (collection) => collection.id === collectionId && collection.documentIds.includes(documentId),
  );
  return member
    ? removeFromCollection(shelves, collectionId, documentId)
    : addToCollection(shelves, collectionId, documentId);
}

export function removeCollection(shelves: ShelfSections, collectionId: string): ShelfSections {
  return {
    favoriteIds: shelves.favoriteIds,
    collections: shelves.collections.filter((collection) => collection.id !== collectionId),
  };
}

export function pruneShelves(shelves: ShelfSections, knownDocumentIds: readonly string[]): ShelfSections {
  const known = new Set(knownDocumentIds);
  return {
    favoriteIds: shelves.favoriteIds.filter((id) => known.has(id)),
    collections: shelves.collections
      .filter((collection) => collection.id.length > 0 && collection.name.trim().length > 0)
      .map((collection) => ({
        ...collection,
        documentIds: collection.documentIds.filter((id) => known.has(id)),
      })),
  };
}

export function parseShelfSections(raw: string): ShelfSections {
  const decoded: unknown = JSON.parse(raw);
  const payload = shelfPayload(decoded);
  const favorites = payload.favorites;
  const collections = payload.collections;
  return {
    favoriteIds: Array.isArray(favorites)
      ? favorites.filter((id): id is string => typeof id === "string" && id.length > 0)
      : [],
    collections: Array.isArray(collections)
      ? collections.flatMap((item) => {
          const collection = readCollection(item);
          return collection == null ? [] : [collection];
        })
      : [],
  };
}

export function encodeShelfSections(shelves: ShelfSections): string {
  return JSON.stringify({
    schema_version: 1,
    payload: {
      favorites: shelves.favoriteIds,
      collections: shelves.collections.map((collection) => ({
        id: collection.id,
        name: collection.name,
        color: collection.color,
        document_ids: collection.documentIds,
      })),
    },
  });
}

export async function loadShelfSections(db: ShelfDatabase): Promise<ShelfSections | null> {
  await ensureShelfPrefs(db);
  const rows = await db.all("SELECT payload FROM reader_prefs WHERE id = ?", [shelvesRow]);
  const payload = rows[0]?.payload;
  if (typeof payload !== "string") return emptyShelfSections;
  try {
    return parseShelfSections(payload);
  } catch {
    return null;
  }
}

export async function saveShelfSections(db: ShelfDatabase, shelves: ShelfSections): Promise<void> {
  await ensureShelfPrefs(db);
  await db.run(
    "INSERT INTO reader_prefs (id, payload) VALUES (?, ?) ON CONFLICT(id) DO UPDATE SET payload = excluded.payload",
    [shelvesRow, encodeShelfSections(shelves)],
  );
}

function shelfPayload(decoded: unknown): Record<string, unknown> {
  if (decoded == null || typeof decoded !== "object" || Array.isArray(decoded)) {
    throw new Error("corrupt shelves");
  }
  const record = decoded as Record<string, unknown>;
  if (!Object.prototype.hasOwnProperty.call(record, "schema_version")) return record;
  const version = record.schema_version;
  if (typeof version !== "number" || !Number.isInteger(version) || version < 1 || version > 1) {
    throw new Error("corrupt shelves");
  }
  if (record.payload == null || typeof record.payload !== "object" || Array.isArray(record.payload)) {
    throw new Error("corrupt shelves");
  }
  return record.payload as Record<string, unknown>;
}

function readCollection(item: unknown): ShelfCollection | null {
  if (item == null || typeof item !== "object" || Array.isArray(item)) return null;
  const record = item as Record<string, unknown>;
  if (typeof record.id !== "string" || record.id.length === 0) return null;
  if (record.name != null && typeof record.name !== "string") return null;
  const ids = record.document_ids ?? record.documentIds;
  return {
    id: record.id,
    name: typeof record.name === "string" ? record.name : "",
    color: typeof record.color === "number" && Number.isFinite(record.color) ? Math.trunc(record.color) : collectionColors[0],
    documentIds: Array.isArray(ids) ? ids.filter((id): id is string => typeof id === "string" && id.length > 0) : [],
  };
}

async function ensureShelfPrefs(db: ShelfDatabase): Promise<void> {
  await db.exec(`
    CREATE TABLE IF NOT EXISTS reader_prefs (
      id TEXT PRIMARY KEY,
      payload TEXT NOT NULL
    )
  `);
}
