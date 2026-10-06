import { useEffect, useMemo, useRef, useState } from "react";
import { Appearance, Platform, Pressable, ScrollView, StyleSheet, Text, TextInput, View } from "react-native";

import type { ConversationTurn } from "../conversation-store";
import type { Copy } from "../copy";
import { annotatePlainText } from "../annotated-text";
import { selectionQuote, type BookNote } from "../note-store";
import { readingIndexForProgress, readingProgress } from "../reading-progress";
import { reflowTapTurn } from "../reflow-tap";
import { placeProgress } from "../reading-sync";
import { readingSurface, type ReadingPrefs } from "../reading-prefs";
import { openFb2Document } from "../fb2-document";
import { openChmDocument, type ChmReaderDocument } from "../chm-document";
import { openDocxDocument } from "../docx-document";
import { openMobiDocument } from "../mobi-document";
import { openOdtDocument } from "../odt-document";
import { openRtfDocument } from "../rtf-document";
import { openTextDocument } from "../text-document";
import { AskPanel } from "./AskPanel";
import { BookmarksPanel } from "./BookmarksPanel";
import { NotesPanel } from "./NotesPanel";
import { ReadingProgress } from "./ReadingProgress";
import { ReadingSettings } from "./ReadingSettings";
import { ReflowTapZones } from "./ReflowTapZones";
import type { ShelfEntry } from "./LibraryScreen";

type Props = {
  copy: Copy;
  entry: ShelfEntry;
  onBack: (chapterIndex: number, progress: number) => void;
  onLoadConversation: (id: string) => Promise<ConversationTurn[]>;
  onRememberConversation: (id: string, turn: ConversationTurn) => Promise<ConversationTurn[]>;
  onLoadNotes: (id: string) => Promise<BookNote[]>;
  onRememberNote: (id: string, turn: ConversationTurn) => Promise<BookNote[]>;
  onRememberBookmark: (id: string, chapterIndex: number, pageIndex: number) => Promise<BookNote[]>;
  onRememberSelection: (
    id: string,
    quote: string,
    chapterText: string,
    chapterIndex: number,
    pageIndex: number,
  ) => Promise<BookNote[]>;
  onForgetNote: (id: string, noteId: string) => Promise<BookNote[]>;
  readingPrefs: ReadingPrefs;
  onReadingPrefs: (prefs: ReadingPrefs) => void;
};

export function ReaderScreen({
  copy,
  entry,
  onBack,
  onLoadConversation,
  onRememberConversation,
  onLoadNotes,
  onRememberNote,
  onRememberBookmark,
  onRememberSelection,
  onForgetNote,
  readingPrefs,
  onReadingPrefs,
}: Props) {
  const syncDocument = useMemo(() => {
    if (
      entry.format === "chm" ||
      entry.format === "djvu" ||
      entry.format === "epub" ||
      entry.format === "pdf" ||
      entry.format === "cbz" ||
      entry.format === "cbt" ||
      entry.format === "cbr" ||
      entry.format === "cb7"
    ) {
      return null;
    }
    if (entry.format === "fb2") {
      const opened = openFb2Document(entry.bytes);
      if (opened.kind !== "fb2") return null;
      opened.document.moveTo(entry.chapterIndex);
      return opened.document;
    }
    if (entry.format === "rtf") {
      const opened = openRtfDocument(entry.bytes);
      if (opened.kind !== "rtf") return null;
      opened.document.moveTo(entry.chapterIndex);
      return opened.document;
    }
    if (entry.format === "docx") {
      const opened = openDocxDocument(entry.bytes);
      if (opened.kind !== "docx") return null;
      opened.document.moveTo(entry.chapterIndex);
      return opened.document;
    }
    if (entry.format === "odt") {
      const opened = openOdtDocument(entry.bytes);
      if (opened.kind !== "odt") return null;
      opened.document.moveTo(entry.chapterIndex);
      return opened.document;
    }
    if (entry.format === "mobi" || entry.format === "azw3") {
      const opened = openMobiDocument(entry.bytes);
      if (opened.kind !== "mobi") return null;
      opened.document.moveTo(entry.chapterIndex);
      return opened.document;
    }
    const opened = openTextDocument(
      { id: entry.id, title: entry.title, author: entry.author, format: entry.format },
      entry.bytes,
    );
    if (opened.kind !== "text") return null;
    opened.document.moveTo(entry.chapterIndex);
    return opened.document;
  }, [entry.bytes, entry.chapterIndex, entry.format, entry.id, entry.title, entry.author]);
  const [chmDocument, setChmDocument] = useState<ChmReaderDocument | null>(null);
  const [chmOpening, setChmOpening] = useState(entry.format === "chm");
  const document = entry.format === "chm" ? chmDocument : syncDocument;
  const [chapterIndex, setChapterIndex] = useState(document?.chapterIndex ?? 0);
  useEffect(() => {
    if (entry.format !== "chm") return;
    let cancelled = false;
    setChmOpening(true);
    void openChmDocument(entry.bytes)
      .then((opened) => {
        if (cancelled) return;
        if (opened.kind !== "chm") {
          setChmDocument(null);
          setChmOpening(false);
          return;
        }
        opened.document.moveTo(entry.chapterIndex);
        setChmDocument(opened.document);
        setChapterIndex(opened.document.chapterIndex);
        setChmOpening(false);
      })
      .catch(() => {
        if (cancelled) return;
        setChmDocument(null);
        setChmOpening(false);
      });
    return () => {
      cancelled = true;
    };
  }, [entry.bytes, entry.chapterIndex, entry.format]);
  const [findOpen, setFindOpen] = useState(false);
  const [query, setQuery] = useState("");
  const [askOpen, setAskOpen] = useState(false);
  const [settingsOpen, setSettingsOpen] = useState(false);
  const [bookmarksOpen, setBookmarksOpen] = useState(false);
  const [notesOpen, setNotesOpen] = useState(false);
  const surface = readingSurface(readingPrefs, Appearance.getColorScheme() === "dark" ? "dark" : "light");
  const [notes, setNotes] = useState<BookNote[]>([]);
  const [pendingQuote, setPendingQuote] = useState<string | null>(null);
  const scrollRef = useRef<ScrollView>(null);
  const hits =
    document == null || query.trim().length === 0 ? [] : document.search(query.trim());
  useEffect(() => {
    let cancelled = false;
    void onLoadNotes(entry.id)
      .then((loaded) => {
        if (!cancelled) setNotes(loaded);
      })
      .catch(() => {
        // A failed note load leaves this chapter unmarked. Do not invent a highlight.
        if (!cancelled) setNotes([]);
      });
    return () => {
      cancelled = true;
    };
  }, [entry.id, onLoadNotes]);

  useEffect(() => {
    if (Platform.OS !== "web") return;
    function onSelectionChange() {
      const chapterText = document?.currentChapterText ?? "";
      const selection = window.getSelection();
      const quote = selection?.toString() ?? "";
      const root = window.document.querySelector('[data-testid="reading-prose"]');
      const anchor = selection?.anchorNode;
      if (root == null || anchor == null || !root.contains(anchor)) return;
      const accepted = selectionQuote(quote, chapterText);
      if (accepted == null) return;
      setPendingQuote(accepted);
    }
    window.document.addEventListener("selectionchange", onSelectionChange);
    return () => window.document.removeEventListener("selectionchange", onSelectionChange);
  }, [document]);

  function showChapter(move: () => void) {
    move();
    setChapterIndex(document?.chapterIndex ?? 0);
    setPendingQuote(null);
    scrollRef.current?.scrollTo({ y: 0, animated: false });
  }

  if (chmOpening) {
    return (
      <View style={styles.screen}>
        <Pressable
          accessibilityRole="button"
          onPress={() => onBack(entry.chapterIndex, 0)}
          style={styles.headerButton}
        >
          <Text style={styles.headerButtonLabel}>{copy.back}</Text>
        </Pressable>
      </View>
    );
  }

  if (document == null) {
    return (
      <View style={styles.screen}>
        <Pressable accessibilityRole="button" onPress={() => onBack(0, 0)} style={styles.headerButton}>
          <Text style={styles.headerButtonLabel}>{copy.back}</Text>
        </Pressable>
        <Text style={styles.notice}>{copy.corrupt}</Text>
      </View>
    );
  }

  const book = document;
  const atStart = chapterIndex <= 0;
  const atEnd = chapterIndex >= book.chapterCount - 1;
  const chapterTitle = book.currentChapterTitle;

  function applyTap(x: number, width: number) {
    const result = reflowTapTurn({
      x,
      width,
      chapterIndex: book.chapterIndex,
      pageIndex: 0,
      pageCount: 1,
      chapterCount: book.chapterCount,
      pendingQuote: pendingQuote != null,
    });
    if (result.toggleChrome || result.place.chapterIndex === book.chapterIndex) return;
    showChapter(() => book.moveTo(result.place.chapterIndex));
  }

  function seek(fraction: number) {
    const next = readingIndexForProgress(fraction, book.chapterCount);
    if (next === book.chapterIndex) return;
    showChapter(() => book.moveTo(next));
  }

  return (
    <View style={[styles.screen, { backgroundColor: surface.background }]}>
      <View style={styles.header}>
        <Pressable
          accessibilityRole="button"
          onPress={() => onBack(document.chapterIndex, placeProgress(document.chapterIndex, document.chapterCount))}
          style={styles.headerButton}
        >
          <Text style={styles.headerButtonLabel}>{copy.back}</Text>
        </Pressable>
        <Text numberOfLines={1} style={styles.bookTitle}>
          {entry.title}
        </Text>
        <Pressable
          accessibilityRole="button"
          onPress={() => {
            setAskOpen(false);
            setSettingsOpen(false);
            setBookmarksOpen(false);
            setNotesOpen(false);
            setFindOpen(true);
          }}
          style={styles.headerButton}
        >
          <Text style={styles.headerButtonLabel}>{copy.find}</Text>
        </Pressable>
        <Pressable
          accessibilityRole="button"
          onPress={() => {
            setFindOpen(false);
            setSettingsOpen(false);
            setBookmarksOpen(false);
            setNotesOpen(false);
            setAskOpen(true);
          }}
          style={styles.headerButton}
        >
          <Text style={styles.headerButtonLabel}>{copy.askThisPage}</Text>
        </Pressable>
        <Pressable
          accessibilityRole="button"
          onPress={() => {
            setFindOpen(false);
            setAskOpen(false);
            setBookmarksOpen(false);
            setNotesOpen(false);
            setSettingsOpen((open) => !open);
          }}
          style={styles.headerButton}
        >
          <Text style={styles.headerButtonLabel}>{copy.readingSettings}</Text>
        </Pressable>
        <Pressable
          accessibilityRole="button"
          onPress={() => {
            setFindOpen(false);
            setAskOpen(false);
            setSettingsOpen(false);
            setBookmarksOpen(false);
            setNotesOpen((open) => !open);
          }}
          style={styles.headerButton}
        >
          <Text style={styles.headerButtonLabel}>{copy.notesTitle}</Text>
        </Pressable>
        <Pressable
          accessibilityRole="button"
          onPress={() => {
            setFindOpen(false);
            setAskOpen(false);
            setSettingsOpen(false);
            setNotesOpen(false);
            setBookmarksOpen((open) => !open);
          }}
          style={styles.headerButton}
        >
          <Text style={styles.headerButtonLabel}>{copy.bookmarks}</Text>
        </Pressable>
        <Text style={styles.progress}>
          {copy.chapter(chapterIndex + 1, document.chapterCount)}
        </Text>
      </View>
      {settingsOpen ? (
        <ReadingSettings copy={copy} onChange={onReadingPrefs} prefs={readingPrefs} />
      ) : null}
      {notesOpen ? (
        <NotesPanel
          copy={copy}
          notes={notes}
          onDelete={(noteId) => {
            void onForgetNote(entry.id, noteId)
              .then((next) => setNotes(next))
              .catch(() => {
                // A failed delete leaves the note where it was.
              });
          }}
          onOpen={(chapterIndex) => {
            setNotesOpen(false);
            showChapter(() => document.moveTo(chapterIndex));
          }}
        />
      ) : null}
      {bookmarksOpen ? (
        <BookmarksPanel
          copy={copy}
          notes={notes}
          onAdd={() => {
            void onRememberBookmark(entry.id, document.chapterIndex, 0)
              .then((next) => setNotes(next))
              .catch(() => {
                // The place stays unmarked when the shelf cannot store the bookmark.
              });
          }}
          onDelete={(noteId) => {
            void onForgetNote(entry.id, noteId)
              .then((next) => setNotes(next))
              .catch(() => {
                // A failed delete leaves the bookmark where it was.
              });
          }}
          onOpen={(chapterIndex) => {
            setBookmarksOpen(false);
            showChapter(() => document.moveTo(chapterIndex));
          }}
        />
      ) : null}
      {document.truncated ? <Text style={styles.notice}>{copy.truncated}</Text> : null}
      <View style={styles.reading}>
      <ScrollView ref={scrollRef} contentContainerStyle={[styles.body, { backgroundColor: surface.background }]} style={styles.readingScroll}>
        {chapterTitle.length > 0 ? (
          <Text style={[styles.chapterTitle, { color: surface.color }]}>{chapterTitle}</Text>
        ) : null}
        <Text
          selectable
          style={[
            styles.prose,
            {
              color: surface.color,
              fontFamily: Platform.OS === "web" ? surface.cssFontFamily : surface.nativeFontFamily,
              fontSize: surface.fontSize,
              lineHeight: Math.round(surface.fontSize * surface.lineHeight),
            },
          ]}
          testID="reading-prose"
        >
          {annotatePlainText(document.currentChapterText, notes).map((segment, index) =>
            segment.highlighted ? (
              <Text accessibilityLabel="highlighted quote" key={index} style={styles.highlight}>
                {segment.text}
              </Text>
            ) : (
              <Text key={index}>{segment.text}</Text>
            ),
          )}
        </Text>
      </ScrollView>
      <ReflowTapZones copy={copy} onTap={applyTap} />
      </View>
      {pendingQuote ? (
        <View style={styles.selection}>
          <Text numberOfLines={2} style={styles.selectionQuote}>
            {pendingQuote}
          </Text>
          <Pressable
            accessibilityRole="button"
            onPress={() => {
              const quote = pendingQuote;
              void onRememberSelection(entry.id, quote, document.currentChapterText, document.chapterIndex, 0)
                .then((next) => {
                  setNotes(next);
                  setPendingQuote(null);
                })
                .catch(() => {
                  // A failed save leaves the selection where it was.
                });
            }}
            style={styles.headerButton}
          >
            <Text style={styles.headerButtonLabel}>{copy.saveSelection}</Text>
          </Pressable>
          <Pressable accessibilityRole="button" onPress={() => setPendingQuote(null)} style={styles.headerButton}>
            <Text style={styles.headerButtonLabel}>{copy.close}</Text>
          </Pressable>
        </View>
      ) : null}
      <ReadingProgress
        copy={copy}
        onSeek={seek}
        progress={readingProgress(document.chapterIndex, document.chapterCount)}
      />
      <View style={styles.footer}>
        <Pressable
          accessibilityRole="button"
          accessibilityState={{ disabled: atStart }}
          disabled={atStart}
          onPress={() => {
            if (document == null) return;
            showChapter(() => document.previous());
          }}
          style={styles.footerButton}
        >
          <Text style={[styles.footerLabel, atStart && styles.footerLabelDisabled]}>
            {copy.previous}
          </Text>
        </Pressable>
        <Pressable
          accessibilityRole="button"
          accessibilityState={{ disabled: atEnd }}
          disabled={atEnd}
          onPress={() => {
            if (document == null) return;
            showChapter(() => document.next());
          }}
          style={styles.footerButton}
        >
          <Text style={[styles.footerLabel, atEnd && styles.footerLabelDisabled]}>{copy.next}</Text>
        </Pressable>
      </View>
      {findOpen ? (
        <View style={styles.find}>
          <View style={styles.findBar}>
            <Text style={styles.findTitle}>{copy.find}</Text>
            <Pressable accessibilityRole="button" onPress={() => setFindOpen(false)}>
              <Text style={styles.headerButtonLabel}>{copy.close}</Text>
            </Pressable>
          </View>
          <TextInput
            onChangeText={setQuery}
            placeholder={copy.searchPlaceholder}
            placeholderTextColor="#8A7358"
            style={styles.search}
            value={query}
          />
          <ScrollView contentContainerStyle={styles.findList}>
            {query.trim().length === 0 ? null : hits.length === 0 ? (
              <Text style={styles.empty}>{copy.noHits}</Text>
            ) : (
              hits.map((hit) => (
                <Pressable
                  accessibilityRole="button"
                  key={`${hit.chapterIndex}:${hit.excerpt}`}
                  onPress={() => {
                    showChapter(() => document.moveTo(hit.chapterIndex));
                    setFindOpen(false);
                  }}
                  style={styles.hit}
                >
                  <Text style={styles.excerpt}>{hit.excerpt}</Text>
                </Pressable>
              ))
            )}
          </ScrollView>
        </View>
      ) : null}
      <AskPanel
        bookId={entry.id}
        copy={copy}
        excerpt={document.currentChapterText}
        onClose={() => setAskOpen(false)}
        onLoadConversation={onLoadConversation}
        onLoadNotes={onLoadNotes}
        onRememberConversation={onRememberConversation}
        onNotesChanged={setNotes}
        onRememberNote={onRememberNote}
        open={askOpen}
        onConfirmJump={(index) => showChapter(() => document.moveTo(index))}
        onSearchBook={(query) =>
          document.search(query).map((hit) => ({ placeIndex: hit.chapterIndex, excerpt: hit.excerpt }))
        }
        placeCount={document.chapterCount}
        placeIndex={document.chapterIndex}
        title={entry.title}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  screen: {
    backgroundColor: "#F5F0E8",
    flex: 1,
  },
  header: {
    alignItems: "center",
    backgroundColor: "#F5F0E8",
    flexDirection: "row",
    flexWrap: "wrap",
    gap: 12,
    paddingHorizontal: 16,
    paddingVertical: 12,
  },
  headerButton: {
    paddingVertical: 8,
  },
  headerButtonLabel: {
    color: "#2F5B57",
    fontSize: 16,
  },
  bookTitle: {
    color: "#1C2423",
    flex: 1,
    fontSize: 16,
    fontWeight: "600",
  },
  progress: {
    color: "#8A7358",
    fontSize: 14,
  },
  notice: {
    color: "#8A3D32",
    fontSize: 14,
    lineHeight: 20,
    paddingHorizontal: 20,
  },
  reading: {
    flex: 1,
    minHeight: 0,
  },
  readingScroll: {
    flex: 1,
  },
  body: {
    paddingBottom: 32,
    paddingHorizontal: 22,
    paddingTop: 12,
  },
  selection: {
    alignItems: "center",
    backgroundColor: "#F7F4EE",
    flexDirection: "row",
    gap: 12,
    paddingHorizontal: 16,
    paddingVertical: 8,
  },
  selectionQuote: {
    color: "#1C2423",
    flex: 1,
    fontSize: 15,
  },
  chapterTitle: {
    color: "#1C2423",
    fontSize: 22,
    fontWeight: "600",
    marginBottom: 16,
  },
  prose: {
    color: "#2A2620",
    fontSize: 18,
    lineHeight: 30,
  },
  highlight: {
    backgroundColor: "rgba(196, 165, 116, 0.4)",
  },
  footer: {
    backgroundColor: "#F5F0E8",
    borderTopColor: "#DDD6C8",
    borderTopWidth: StyleSheet.hairlineWidth,
    flexDirection: "row",
    justifyContent: "space-between",
    paddingHorizontal: 8,
    paddingVertical: 8,
  },
  footerButton: {
    paddingHorizontal: 12,
    paddingVertical: 10,
  },
  footerLabel: {
    color: "#2F5B57",
    fontSize: 16,
  },
  footerLabelDisabled: {
    color: "#C4B8A8",
  },
  find: {
    backgroundColor: "#F5F0E8",
    bottom: 0,
    left: 0,
    position: "absolute",
    right: 0,
    top: 0,
  },
  findBar: {
    alignItems: "center",
    flexDirection: "row",
    justifyContent: "space-between",
    paddingHorizontal: 16,
    paddingVertical: 12,
  },
  findTitle: {
    color: "#1C2423",
    fontSize: 18,
    fontWeight: "600",
  },
  search: {
    borderColor: "#DDD6C8",
    borderRadius: 8,
    borderWidth: StyleSheet.hairlineWidth,
    color: "#1C2423",
    fontSize: 16,
    marginHorizontal: 16,
    paddingHorizontal: 12,
    paddingVertical: 10,
  },
  findList: {
    paddingBottom: 24,
    paddingTop: 8,
  },
  empty: {
    color: "#5C6563",
    fontSize: 16,
    paddingHorizontal: 20,
    paddingTop: 20,
  },
  hit: {
    borderTopColor: "#DDD6C8",
    borderTopWidth: StyleSheet.hairlineWidth,
    paddingHorizontal: 20,
    paddingVertical: 12,
  },
  excerpt: {
    color: "#2A2620",
    fontSize: 16,
    lineHeight: 24,
  },
});
