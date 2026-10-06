export type ShelfSearchNote = {
  quote: string;
  note: string;
  locatorLabel: string;
};

export function shelfSearch<T extends { id: string; title: string; author: string; format: string }>(
  books: readonly T[],
  query: string,
  notesFor: (id: string) => readonly ShelfSearchNote[],
  formatLabel: (format: T["format"]) => string,
): T[] {
  const needle = query.trim().toLowerCase();
  if (needle.length === 0) return books.slice();
  return books.filter((book) => matchesBook(book, needle, notesFor, formatLabel));
}

function matchesBook<T extends { id: string; title: string; author: string; format: string }>(
  book: T,
  needle: string,
  notesFor: (id: string) => readonly ShelfSearchNote[],
  formatLabel: (format: T["format"]) => string,
): boolean {
  if (contains(book.title, needle) || contains(book.author, needle) || contains(formatLabel(book.format), needle)) {
    return true;
  }
  let notes: readonly ShelfSearchNote[] = [];
  try {
    notes = notesFor(book.id);
  } catch {
    return false;
  }
  return notes.some(
    (item) => contains(item.quote, needle) || contains(item.note, needle) || contains(item.locatorLabel, needle),
  );
}

function contains(haystack: string, needle: string): boolean {
  return haystack.toLowerCase().includes(needle);
}
