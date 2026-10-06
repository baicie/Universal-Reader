import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { Pressable, ScrollView, StyleSheet, Text, TextInput, View } from "react-native";

import { quoteHighlights } from "../annotated-text";
import type { ConversationTurn } from "../conversation-store";
import type { Copy } from "../copy";
import type { BookNote } from "../note-store";
import { selectionQuote } from "../note-store";
import { searchPdf, textForReportedPage, turnPdfPage } from "../pdf-document";
import { readingIndexForProgress, readingProgress } from "../reading-progress";
import { placeProgress } from "../reading-sync";
import type { ReadingPrefs } from "../reading-prefs";
import { buildPdfViewer } from "../pdf-viewer";
import { pdfWorkerSource, pdfjsSource } from "../pdfjs-source";
import { AskPanel } from "./AskPanel";
import { BookmarksPanel } from "./BookmarksPanel";
import { NotesPanel } from "./NotesPanel";
import { ReadingProgress } from "./ReadingProgress";
import type { ShelfEntry } from "./LibraryScreen";
import { PdfView } from "./PdfView";
import { ReadingSettings } from "./ReadingSettings";
import type { PdfViewHandle } from "./pdf-view-handle";

type Props = {
  copy: Copy;
  entry: ShelfEntry;
  onBack: (pageIndex: number, progress: number) => void;
  onFailed: () => void;
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

export function PdfReaderScreen({
  copy,
  entry,
  onBack,
  onFailed,
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
  const [pageIndex, setPageIndex] = useState(entry.pageIndex);
  const [pageCount, setPageCount] = useState(0);
  const [pageText, setPageText] = useState<{ pageIndex: number; text: string } | null>(null);
  const [askOpen, setAskOpen] = useState(false);
  const [bookmarksOpen, setBookmarksOpen] = useState(false);
  const [notesOpen, setNotesOpen] = useState(false);
  const [settingsOpen, setSettingsOpen] = useState(false);
  const [findOpen, setFindOpen] = useState(false);
  const [query, setQuery] = useState("");
  const [notes, setNotes] = useState<BookNote[]>([]);
  const [pendingQuote, setPendingQuote] = useState<string | null>(null);
  const hits = useMemo(() => searchPdf(entry.bytes, query), [entry.bytes, query]);
  const quotes = useMemo(() => quoteHighlights(notes), [notes]);
  useEffect(() => {
    let cancelled = false;
    void onLoadNotes(entry.id)
      .then((loaded) => {
        if (!cancelled) setNotes(loaded);
      })
      .catch(() => {
        // A failed note load leaves this page unmarked. Do not invent a highlight.
        if (!cancelled) setNotes([]);
      });
    return () => {
      cancelled = true;
    };
  }, [entry.id, onLoadNotes]);
  useEffect(() => {
    pdfView.current?.paintQuotes(quotes);
  }, [quotes, pageIndex]);
  const pdfView = useRef<PdfViewHandle>(null);
  const onRelocated = useCallback((report: { pageIndex: number; pageCount: number }) => {
    setPageIndex((current) => {
      if (current !== report.pageIndex) setPendingQuote(null);
      return report.pageIndex;
    });
    setPageCount(report.pageCount);
    pdfView.current?.paintQuotes(quotes);
  }, [quotes]);
  const onPageSelection = useCallback(
    (quote: string) => {
      const accepted = selectionQuote(quote, textForReportedPage(pageText, pageIndex));
      if (accepted == null) return;
      setPendingQuote(accepted);
    },
    [pageIndex, pageText],
  );
  const openedZoom = useRef(readingPrefs.pdfZoom);
  const html = useMemo(
    () =>
      buildPdfViewer({
        pdfjsSource,
        pdfWorkerSource,
        bytes: entry.bytes,
        pageIndex: entry.pageIndex,
        zoom: openedZoom.current,
      }),
    [entry.bytes, entry.pageIndex],
  );
  useEffect(() => {
    pdfView.current?.setZoom(readingPrefs.pdfZoom);
  }, [readingPrefs.pdfZoom]);
  const pending = pageCount < 1;
  const atStart = pending || turnPdfPage(pageIndex, pageCount, "prev") === pageIndex;
  const atEnd = pending || turnPdfPage(pageIndex, pageCount, "next") === pageIndex;

  function turn(direction: "next" | "prev") {
    const next = turnPdfPage(pageIndex, pageCount, direction);
    if (next === pageIndex) return;
    pdfView.current?.goTo(next);
  }

  function seek(fraction: number) {
    if (pageCount < 1) return;
    const next = readingIndexForProgress(fraction, pageCount);
    if (next === pageIndex) return;
    pdfView.current?.goTo(next);
  }

  return (
    <View style={styles.screen}>
      <View style={styles.header}>
        <Pressable
          accessibilityRole="button"
          onPress={() => onBack(pageIndex < 0 ? 0 : pageIndex, placeProgress(pageIndex < 0 ? 0 : pageIndex, pageCount))}
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
            setBookmarksOpen(false);
            setNotesOpen(false);
            setSettingsOpen(false);
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
            setBookmarksOpen(false);
            setNotesOpen(false);
            setSettingsOpen(false);
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
            setNotesOpen(false);
            setSettingsOpen(false);
            setBookmarksOpen((open) => !open);
          }}
          style={styles.headerButton}
        >
          <Text style={styles.headerButtonLabel}>{copy.bookmarks}</Text>
        </Pressable>
        <Pressable
          accessibilityRole="button"
          onPress={() => {
            setFindOpen(false);
            setAskOpen(false);
            setBookmarksOpen(false);
            setSettingsOpen(false);
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
            setBookmarksOpen(false);
            setNotesOpen(false);
            setSettingsOpen((open) => !open);
          }}
          style={styles.headerButton}
        >
          <Text style={styles.headerButtonLabel}>{copy.readingSettings}</Text>
        </Pressable>
        <Text style={styles.progress}>
          {pageCount > 0 && pageIndex >= 0 ? copy.page(pageIndex + 1, pageCount) : ""}
        </Text>
      </View>
      {bookmarksOpen ? (
        <BookmarksPanel
          copy={copy}
          notes={notes}
          onAdd={() => {
            void onRememberBookmark(entry.id, 0, pageIndex < 0 ? 0 : pageIndex)
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
          onOpen={(_chapterIndex, nextPage) => {
            setBookmarksOpen(false);
            pdfView.current?.goTo(nextPage);
          }}
        />
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
          onOpen={(_chapterIndex, nextPage) => {
            setNotesOpen(false);
            pdfView.current?.goTo(nextPage);
          }}
        />
      ) : null}
      {settingsOpen ? (
        <ReadingSettings copy={copy} onChange={onReadingPrefs} prefs={readingPrefs} showPdfZoom />
      ) : null}
      <PdfView
        html={html}
        onFailed={onFailed}
        onPageText={setPageText}
        onRelocated={onRelocated}
        onSelection={onPageSelection}
        ref={pdfView}
      />
      {pendingQuote ? (
        <View style={styles.selection}>
          <Text numberOfLines={2} style={styles.selectionQuote}>
            {pendingQuote}
          </Text>
          <Pressable
            accessibilityRole="button"
            onPress={() => {
              const quote = pendingQuote;
              void onRememberSelection(entry.id, quote, textForReportedPage(pageText, pageIndex), 0, pageIndex < 0 ? 0 : pageIndex)
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
      {pageCount > 0 ? (
        <ReadingProgress
          copy={copy}
          onSeek={seek}
          progress={readingProgress(pageIndex < 0 ? 0 : pageIndex, pageCount)}
        />
      ) : null}
      <View style={styles.footer}>
        <Pressable
          accessibilityRole="button"
          accessibilityState={{ disabled: atStart }}
          disabled={atStart}
          onPress={() => turn("prev")}
          style={styles.footerButton}
        >
          <Text style={[styles.footerLabel, atStart && styles.footerLabelDisabled]}>{copy.previousPage}</Text>
        </Pressable>
        <Pressable
          accessibilityRole="button"
          accessibilityState={{ disabled: atEnd }}
          disabled={atEnd}
          onPress={() => turn("next")}
          style={styles.footerButton}
        >
          <Text style={[styles.footerLabel, atEnd && styles.footerLabelDisabled]}>{copy.nextPage}</Text>
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
                  key={`${hit.pageIndex}:${hit.excerpt}`}
                  onPress={() => {
                    pdfView.current?.goTo(hit.pageIndex);
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
        excerpt={textForReportedPage(pageText, pageIndex)}
        onClose={() => setAskOpen(false)}
        onLoadConversation={onLoadConversation}
        onLoadNotes={onLoadNotes}
        onNotesChanged={setNotes}
        onRememberConversation={onRememberConversation}
        onRememberNote={onRememberNote}
        open={askOpen}
        onConfirmJump={(index) => pdfView.current?.goTo(index)}
        onSearchBook={(question) =>
          searchPdf(entry.bytes, question).map((hit) => ({ placeIndex: hit.pageIndex, excerpt: hit.excerpt }))
        }
        placeCount={pageCount > 0 ? pageCount : 1}
        placeIndex={pageIndex < 0 ? 0 : pageIndex}
        title={entry.title}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  screen: {
    backgroundColor: "#F5F0E8",
    flex: 1,
    minHeight: 0,
  },
  header: {
    alignItems: "center",
    flexDirection: "row",
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
  footer: {
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
