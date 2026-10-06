export type ReadingPlace = {
  chapterIndex: number;
  pageIndex: number;
};

export function turnForward(
  place: ReadingPlace,
  pageCount: number,
  chapterCount: number,
): ReadingPlace {
  if (!Number.isFinite(pageCount) || pageCount < 1) return place;
  if (place.pageIndex + 1 < pageCount) {
    return { chapterIndex: place.chapterIndex, pageIndex: place.pageIndex + 1 };
  }
  if (place.chapterIndex + 1 < chapterCount) {
    return { chapterIndex: place.chapterIndex + 1, pageIndex: 0 };
  }
  return place;
}

export function turnBackward(place: ReadingPlace): ReadingPlace {
  if (place.pageIndex < 0) return place;
  if (place.pageIndex > 0) {
    return { chapterIndex: place.chapterIndex, pageIndex: place.pageIndex - 1 };
  }
  if (place.chapterIndex > 0) {
    return { chapterIndex: place.chapterIndex - 1, pageIndex: -1 };
  }
  return place;
}

export function readRelocated(data: unknown): { pageIndex: number; pageCount: number } | null {
  let value = data;
  if (typeof value === "string") {
    try {
      value = JSON.parse(value) as unknown;
    } catch {
      return null;
    }
  }
  if (typeof value !== "object" || value == null) return null;
  const record = value as Record<string, unknown>;
  if (record.type !== "relocated") return null;
  const { pageIndex, pageCount } = record;
  if (typeof pageIndex !== "number" || typeof pageCount !== "number") return null;
  if (!Number.isInteger(pageIndex) || !Number.isInteger(pageCount)) return null;
  if (pageIndex < 0 || pageCount < 1) return null;
  return { pageIndex, pageCount };
}

export function readChapterSelection(data: unknown): string | null {
  let value = data;
  if (typeof value === "string") {
    try {
      value = JSON.parse(value) as unknown;
    } catch {
      return null;
    }
  }
  if (typeof value !== "object" || value == null) return null;
  const record = value as Record<string, unknown>;
  if (record.type !== "selection" || typeof record.text !== "string") return null;
  const quote = record.text.trim();
  if (quote.length === 0) return null;
  return quote;
}
