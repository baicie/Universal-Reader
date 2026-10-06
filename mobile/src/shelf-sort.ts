export type ShelfSort = "shelf" | "recent" | "title" | "progress";

type SortedBook = {
  title: string;
  progress: number;
  lastOpenedMs: number;
};

export function parseShelfSort(raw: unknown): ShelfSort {
  return raw === "recent" || raw === "title" || raw === "progress" ? raw : "shelf";
}

export function shelfSort<T extends SortedBook>(books: readonly T[], sort: ShelfSort): T[] {
  if (parseShelfSort(sort) === "shelf") return books.slice();
  return books
    .map((book, index) => ({ book, index }))
    .sort((left, right) => compareBooks(left.book, right.book, sort) || left.index - right.index)
    .map((item) => item.book);
}

export function continueReading<T extends SortedBook>(books: readonly T[]): T | null {
  let best: T | null = null;
  for (const book of books) {
    if (!(book.progress > 0 && book.progress < 1)) continue;
    if (best == null || book.lastOpenedMs > best.lastOpenedMs) best = book;
  }
  return best;
}

function compareBooks(left: SortedBook, right: SortedBook, sort: ShelfSort): number {
  if (sort === "title") return compareText(left.title, right.title);
  if (sort === "progress") return finite(right.progress) - finite(left.progress);
  return finite(right.lastOpenedMs) - finite(left.lastOpenedMs);
}

function compareText(left: string, right: string): number {
  if (left < right) return -1;
  if (left > right) return 1;
  return 0;
}

function finite(value: number): number {
  return Number.isFinite(value) ? value : Number.NEGATIVE_INFINITY;
}
