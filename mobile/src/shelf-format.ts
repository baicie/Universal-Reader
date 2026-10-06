export type ShelfFormatKind = "reflow" | "fixedPage" | "comic";
export type ShelfFormatFilter = "all" | ShelfFormatKind;

export function parseShelfFormatFilter(raw: unknown): ShelfFormatFilter {
  return raw === "reflow" || raw === "fixedPage" || raw === "comic" ? raw : "all";
}

export function shelfFormatKind(format: string): ShelfFormatKind {
  if (format === "pdf" || format === "djvu") return "fixedPage";
  if (format === "cbz" || format === "cbr" || format === "cbt" || format === "cb7") return "comic";
  return "reflow";
}

export function shelfByFormat<T extends { format: string }>(books: readonly T[], filter: string): T[] {
  if (filter === "all") return books.slice();
  if (filter !== "reflow" && filter !== "fixedPage" && filter !== "comic") return [];
  return books.filter((book) => shelfFormatKind(book.format) === filter);
}
