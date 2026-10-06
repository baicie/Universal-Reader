import { useCallback, useEffect, useRef, useState } from "react";

import { appendBookConversation, loadBookConversation, type ConversationTurn } from "./conversation-store";
import { appendBookBookmark, appendBookNote, appendBookSelection, loadBookNotes, removeBookNote } from "./note-store";
import { defaultReadingPrefs, loadReadingPrefs, saveReadingPrefs, type ReadingPrefs } from "./reading-prefs";
import {
  addCollection,
  emptyShelfSections,
  loadShelfSections,
  pruneShelves,
  removeCollection,
  saveShelfSections,
  toggleFavorite,
  toggleInCollection,
  type ShelfCollection,
  type ShelfSections,
} from "./shelf-sections";
import { openExpoShelfDatabase } from "./shelf-database";
import {
  deleteShelfBook,
  importShelfBook,
  loadShelf,
  ShelfSchemaError,
  writeShelfIdentity,
  writeShelfPlace,
  type ShelfBook,
  type ShelfDatabase,
} from "./shelf-store";

export type ShelfBlock = "shelf-unreadable" | "shelf-failed";

export function useShelf() {
  const [shelf, setShelf] = useState<ShelfBook[]>([]);
  const [readingPrefs, setReadingPrefsState] = useState<ReadingPrefs>(defaultReadingPrefs);
  const [sections, setSections] = useState<ShelfSections>(emptyShelfSections);
  const [ready, setReady] = useState(false);
  const [block, setBlock] = useState<ShelfBlock | null>(null);
  const dbRef = useRef<ShelfDatabase | null>(null);
  const writableRef = useRef(false);

  useEffect(() => {
    let cancelled = false;
    void (async () => {
      try {
        const db = await openExpoShelfDatabase();
        const books = await loadShelf(db);
        let prefs = defaultReadingPrefs;
        try {
          prefs = await loadReadingPrefs(db);
        } catch {
          prefs = defaultReadingPrefs;
        }
        let nextSections = emptyShelfSections;
        if (!cancelled) {
          try {
            const stored = await loadShelfSections(db);
            if (stored) {
              const pruned = pruneShelves(stored, books.map((book) => book.id));
              if (JSON.stringify(pruned) !== JSON.stringify(stored)) await saveShelfSections(db, pruned);
              nextSections = pruned;
            }
          } catch {
            nextSections = emptyShelfSections;
          }
        }
        if (cancelled) return;
        dbRef.current = db;
        writableRef.current = true;
        setShelf(books);
        setSections(nextSections);
        setReadingPrefsState(prefs);
      } catch (error) {
        if (cancelled) return;
        writableRef.current = false;
        setBlock(error instanceof ShelfSchemaError ? "shelf-unreadable" : "shelf-failed");
      } finally {
        if (!cancelled) setReady(true);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, []);

  async function importBook(input: {
    title: string;
    author?: string;
    format: ShelfBook["format"];
    bytes: Uint8Array;
    cover?: Uint8Array | null;
  }): Promise<{ book: ShelfBook; books: ShelfBook[] } | null> {
    const db = dbRef.current;
    if (!db || !writableRef.current) return null;
    const book = await importShelfBook(db, input);
    return { book, books: await loadShelf(db) };
  }

  async function rememberPlace(id: string, chapterIndex: number, pageIndex: number, progress = 0): Promise<void> {
    const lastOpenedMs = Date.now();
    const db = dbRef.current;
    if (db && writableRef.current) {
      try {
        await writeShelfPlace(db, id, chapterIndex, pageIndex, { progress, lastOpenedMs });
      } catch {
        // This session still keeps the place. The next leave writes it again.
      }
    }
    setShelf((current) =>
      current.map((entry) =>
        entry.id === id ? { ...entry, chapterIndex, pageIndex, progress, lastOpenedMs } : entry,
      ),
    );
  }

  async function saveReading(books: ShelfBook[]): Promise<void> {
    const db = dbRef.current;
    if (db && writableRef.current) {
      for (const book of books) {
        await writeShelfPlace(db, book.id, book.chapterIndex, book.pageIndex, {
          progress: book.progress,
          lastOpenedMs: book.lastOpenedMs,
        });
      }
    }
    setShelf(books);
  }

  async function removeBook(id: string): Promise<void> {
    const db = dbRef.current;
    if (db && writableRef.current) {
      try {
        await deleteShelfBook(db, id);
      } catch {
        // The book leaves this session. A reload shows it again if the delete did not land.
      }
    }
    setShelf((current) => current.filter((entry) => entry.id !== id));
    setSections((current) => {
      const pruned = pruneShelves(
        current,
        shelf.filter((entry) => entry.id !== id).map((entry) => entry.id),
      );
      const db = dbRef.current;
      if (db && writableRef.current) {
        void saveShelfSections(db, pruned).catch(() => {
          // The book is already gone from this session. The next change writes the shelves again.
        });
      }
      return pruned;
    });
  }

  async function toggleShelfFavorite(id: string): Promise<void> {
    if (!shelf.some((entry) => entry.id === id)) return;
    const next = toggleFavorite(sections, id);
    setSections(next);
    const db = dbRef.current;
    if (!db || !writableRef.current) return;
    try {
      await saveShelfSections(db, next);
    } catch {
      // This session still shows the favorite. The next change writes it again.
    }
  }

  async function createCollection(name: string): Promise<ShelfCollection | null> {
    const next = addCollection(sections, name, Date.now() * 1000);
    const created = next.collections.at(-1);
    if (created == null || next.collections.length === sections.collections.length) return null;
    const previous = sections;
    setSections(next);
    const db = dbRef.current;
    if (!db || !writableRef.current) {
      setSections(previous);
      return null;
    }
    try {
      await saveShelfSections(db, next);
      return created;
    } catch {
      setSections(previous);
      return null;
    }
  }

  async function toggleShelfCollection(collectionId: string, id: string): Promise<void> {
    if (!shelf.some((entry) => entry.id === id)) return;
    const next = toggleInCollection(sections, collectionId, id);
    setSections(next);
    const db = dbRef.current;
    if (!db || !writableRef.current) return;
    try {
      await saveShelfSections(db, next);
    } catch {
      // This session still shows the membership. The next change writes it again.
    }
  }

  async function deleteCollection(id: string): Promise<void> {
    const next = removeCollection(sections, id);
    setSections(next);
    const db = dbRef.current;
    if (!db || !writableRef.current) return;
    try {
      await saveShelfSections(db, next);
    } catch {
      // This session already dropped the collection. The next change writes it again.
    }
  }

  async function renameBook(id: string, title: string, author: string): Promise<void> {
    const db = dbRef.current;
    if (!db || !writableRef.current || id.length === 0) return;
    try {
      await writeShelfIdentity(db, id, title, author);
      setShelf(await loadShelf(db));
    } catch {
      // The shelf keeps the previous title. A failed write does not invent another name.
    }
  }

  const loadConversation = useCallback(async (id: string) => {
    const db = dbRef.current;
    if (!db || !writableRef.current) return [];
    return loadBookConversation(db, id);
  }, []);

  const rememberConversation = useCallback(async (id: string, turn: ConversationTurn) => {
    const db = dbRef.current;
    if (!db || !writableRef.current) return [];
    return appendBookConversation(db, id, turn);
  }, []);

  const loadNotes = useCallback(async (id: string) => {
    const db = dbRef.current;
    if (!db || !writableRef.current) return [];
    return loadBookNotes(db, id);
  }, []);

  const rememberNote = useCallback(async (id: string, turn: ConversationTurn) => {
    const db = dbRef.current;
    if (!db || !writableRef.current) return [];
    return appendBookNote(db, id, turn, Date.now());
  }, []);

  const rememberBookmark = useCallback(async (id: string, chapterIndex: number, pageIndex: number) => {
    const db = dbRef.current;
    if (!db || !writableRef.current) return [];
    return appendBookBookmark(db, id, chapterIndex, pageIndex, Date.now());
  }, []);

  const rememberSelection = useCallback(
    async (id: string, quote: string, chapterText: string, chapterIndex: number, pageIndex: number) => {
      const db = dbRef.current;
      if (!db || !writableRef.current) return [];
      return appendBookSelection(db, id, quote, chapterText, chapterIndex, pageIndex, Date.now());
    },
    [],
  );

  const forgetNote = useCallback(async (id: string, noteId: string) => {
    const db = dbRef.current;
    if (!db || !writableRef.current) return [];
    return removeBookNote(db, id, noteId);
  }, []);

  const updateReadingPrefs = useCallback(async (prefs: ReadingPrefs) => {
    const next = { ...prefs };
    setReadingPrefsState(next);
    const db = dbRef.current;
    if (!db || !writableRef.current) return;
    try {
      await saveReadingPrefs(db, next);
    } catch {
      // This session still uses the choice. The next change writes it again.
    }
  }, []);

  return {
    shelf,
    setShelf,
    ready,
    block,
    importBook,
    rememberPlace,
    saveReading,
    removeBook,
    renameBook,
    loadConversation,
    rememberConversation,
    loadNotes,
    rememberNote,
    rememberBookmark,
    rememberSelection,
    forgetNote,
    readingPrefs,
    updateReadingPrefs,
    sections,
    toggleShelfFavorite,
    createCollection,
    toggleShelfCollection,
    deleteCollection,
  };
}
