import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { Appearance, Pressable, ScrollView, StyleSheet, Text, TextInput, View } from "react-native";

import { quoteHighlights } from "../annotated-text";
import type { ConversationTurn } from "../conversation-store";
import type { Copy } from "../copy";
import type { BookNote } from "../note-store";
import { selectionQuote } from "../note-store";
import { openEpubDocument, type EpubTocItem } from "../epub-document";
import { buildFoliateDocument } from "../foliate-document";
import { hostSource, paginatorSource } from "../foliate-source";
import { turnBackward, turnForward } from "../reading-place";
import { reflowTapTurn } from "../reflow-tap";
import { readingIndexForProgress, readingPageIndexForProgress, readingProgress } from "../reading-progress";
import { placeProgress } from "../reading-sync";
import { readingSurface, type ReadingPrefs } from "../reading-prefs";
import { ChapterView } from "./ChapterView";
import type { ChapterViewHandle } from "./chapter-view-handle";
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
  onBack: (chapterIndex: number, pageIndex: number, progress: number) => void;
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

export function EpubReaderScreen({
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
  const document = useMemo(() => {
    const opened = openEpubDocument(entry.bytes);
    if (opened.kind !== "epub") return null;
    opened.document.moveTo(entry.chapterIndex);
    return opened.document;
  }, [entry.bytes, entry.chapterIndex]);
  const [chapterIndex, setChapterIndex] = useState(document?.chapterIndex ?? 0);
  const [fragment, setFragment] = useState<string | null>(null);
  const [openPageIndex, setOpenPageIndex] = useState(entry.pageIndex);
  const [pageIndex, setPageIndex] = useState(entry.pageIndex);
  const [pageCount, setPageCount] = useState(0);
  const [tocOpen, setTocOpen] = useState(false);
  const [askOpen, setAskOpen] = useState(false);
  const [settingsOpen, setSettingsOpen] = useState(false);
  const [bookmarksOpen, setBookmarksOpen] = useState(false);
  const [notesOpen, setNotesOpen] = useState(false);
  const [notes, setNotes] = useState<BookNote[]>([]);
  const [pendingQuote, setPendingQuote] = useState<string | null>(null);
  const [query, setQuery] = useState("");
  const surface = readingSurface(readingPrefs, Appearance.getColorScheme() === "dark" ? "dark" : "light");
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
  const chapterView = useRef<ChapterViewHandle>(null);
  const onRelocated = useCallback((report: { pageIndex: number; pageCount: number }) => {
    setPageIndex(report.pageIndex);
    setPageCount(report.pageCount);
  }, []);
  const onChapterSelection = useCallback(
    (quote: string) => {
      const accepted = selectionQuote(quote, document?.currentChapterText ?? "");
      if (accepted == null) return;
      setPendingQuote(accepted);
    },
    [document],
  );
  const chapterHtml = useMemo(() => {
    if (document == null) return "";
    return buildFoliateDocument({
      hostSource,
      paginatorSource,
      chapterHtml: document.currentChapterHtml,
      quotes: quoteHighlights(notes),
      href: document.currentChapterHref,
      pageIndex: openPageIndex,
      fragment,
      fontSize: surface.fontSize,
      lineHeight: surface.lineHeight,
      fontFamily: surface.cssFontFamily,
      background: surface.background,
      color: surface.color,
    });
  }, [
    document,
    chapterIndex,
    fragment,
    notes,
    openPageIndex,
    surface.fontSize,
    surface.lineHeight,
    surface.cssFontFamily,
    surface.background,
    surface.color,
  ]);

  if (document == null) {
    return (
      <View style={styles.screen}>
        <Pressable accessibilityRole="button" onPress={() => onBack(0, 0, 0)} style={styles.headerButton}>
          <Text style={styles.headerButtonLabel}>{copy.back}</Text>
        </Pressable>
        <Text style={styles.notice}>{copy.corrupt}</Text>
      </View>
    );
  }

  const place = { chapterIndex, pageIndex };
  const forward = turnForward(place, pageCount, document.chapterCount);
  const backward = turnBackward(place);
  const pending = pageCount < 1;
  const atStart = pending || (backward.chapterIndex === chapterIndex && backward.pageIndex === pageIndex);
  const atEnd = pending || (forward.chapterIndex === chapterIndex && forward.pageIndex === pageIndex);
  const hits = query.trim().length === 0 ? [] : document.search(query.trim());

  function openPlace(nextChapter: number, nextPage: number, nextFragment: string | null) {
    if (document == null) return;
    document.moveTo(nextChapter);
    setChapterIndex(document.chapterIndex);
    setFragment(nextFragment);
    setOpenPageIndex(nextPage);
    setPageIndex(nextPage);
    setPageCount(0);
    setPendingQuote(null);
    setTocOpen(false);
    setQuery("");
  }

  function applyTap(x: number, width: number) {
    if (document == null) return;
    const currentPage = pageIndex < 0 ? 0 : pageIndex;
    const result = reflowTapTurn({
      x,
      width,
      chapterIndex,
      pageIndex: currentPage,
      pageCount,
      chapterCount: document.chapterCount,
      pendingQuote: pendingQuote != null,
    });
    if (result.toggleChrome) return;
    if (result.place.chapterIndex === chapterIndex && result.place.pageIndex === currentPage) return;
    if (result.place.chapterIndex !== chapterIndex) {
      openPlace(result.place.chapterIndex, result.place.pageIndex, null);
      return;
    }
    chapterView.current?.turn(result.place.pageIndex > currentPage ? "next" : "prev");
  }

  function seek(fraction: number) {
    if (document == null) return;
    const chapter = readingIndexForProgress(fraction, document.chapterCount);
    const page =
      chapter === chapterIndex && pageCount > 1
        ? readingPageIndexForProgress({
            progress: fraction,
            chapterCount: document.chapterCount,
            chapterIndex: chapter,
            pageCount,
          })
        : 0;
    if (chapter === chapterIndex && page === pageIndex) return;
    openPlace(chapter, page, null);
  }

  function openTocItem(item: EpubTocItem) {
    if (document == null) return;
    document.goTo(item.href);
    openPlace(document.chapterIndex, 0, item.fragment);
  }

  return (
    <View style={styles.screen}>
      <View style={styles.header}>
        <Pressable
          accessibilityRole="button"
          onPress={() =>
            onBack(
              document.chapterIndex,
              pageIndex < 0 ? 0 : pageIndex,
              placeProgress(document.chapterIndex, document.chapterCount),
            )
          }
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
            setTocOpen(true);
          }}
          style={styles.headerButton}
        >
          <Text style={styles.headerButtonLabel}>{copy.contents}</Text>
        </Pressable>
        <Pressable
          accessibilityRole="button"
          onPress={() => {
            setTocOpen(false);
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
            setTocOpen(false);
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
            setTocOpen(false);
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
            setTocOpen(false);
            setAskOpen(false);
            setSettingsOpen(false);
            setNotesOpen(false);
            setBookmarksOpen((open) => !open);
          }}
          style={styles.headerButton}
        >
          <Text style={styles.headerButtonLabel}>{copy.bookmarks}</Text>
        </Pressable>
        <Text style={styles.progress}>{copy.chapter(chapterIndex + 1, document.chapterCount)}</Text>
      </View>
      {settingsOpen ? (
        <ReadingSettings copy={copy} onChange={onReadingPrefs} prefs={readingPrefs} />
      ) : null}
      {bookmarksOpen ? (
        <BookmarksPanel
          copy={copy}
          notes={notes}
          onAdd={() => {
            void onRememberBookmark(entry.id, chapterIndex, pageIndex < 0 ? 0 : pageIndex)
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
          onOpen={(nextChapter, nextPage) => {
            setBookmarksOpen(false);
            openPlace(nextChapter, nextPage, null);
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
          onOpen={(nextChapter, nextPage) => {
            setNotesOpen(false);
            openPlace(nextChapter, nextPage, null);
          }}
        />
      ) : null}
      {document.truncated ? <Text style={styles.notice}>{copy.truncated}</Text> : null}
      {document.currentChapterTitle.length > 0 ? (
        <Text style={styles.chapterTitle}>{document.currentChapterTitle}</Text>
      ) : null}
      <View style={styles.reading}>
        <ChapterView
          key={`${document.currentChapterHref}:${fragment ?? ""}:${chapterIndex}:${openPageIndex}`}
          html={chapterHtml}
          onRelocated={onRelocated}
          onSelection={onChapterSelection}
          ref={chapterView}
        />
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
              void onRememberSelection(
                entry.id,
                quote,
                document.currentChapterText,
                document.chapterIndex,
                pageIndex < 0 ? 0 : pageIndex,
              )
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
        progress={readingProgress(chapterIndex, document.chapterCount, pageIndex < 0 ? 0 : pageIndex, pageCount)}
      />
      <View style={styles.footer}>
        <Pressable
          accessibilityRole="button"
          accessibilityState={{ disabled: atStart }}
          disabled={atStart}
          onPress={() => {
            if (backward.chapterIndex !== chapterIndex) {
              openPlace(backward.chapterIndex, backward.pageIndex, null);
              return;
            }
            chapterView.current?.turn("prev");
          }}
          style={styles.footerButton}
        >
          <Text style={[styles.footerLabel, atStart && styles.footerLabelDisabled]}>{copy.previousPage}</Text>
        </Pressable>
        <Text style={styles.pageProgress}>
          {pageCount > 0 && pageIndex >= 0 ? copy.page(pageIndex + 1, pageCount) : ""}
        </Text>
        <Pressable
          accessibilityRole="button"
          accessibilityState={{ disabled: atEnd }}
          disabled={atEnd}
          onPress={() => {
            if (forward.chapterIndex !== chapterIndex) {
              openPlace(forward.chapterIndex, forward.pageIndex, null);
              return;
            }
            chapterView.current?.turn("next");
          }}
          style={styles.footerButton}
        >
          <Text style={[styles.footerLabel, atEnd && styles.footerLabelDisabled]}>{copy.nextPage}</Text>
        </Pressable>
      </View>
      {tocOpen ? (
        <View style={styles.toc}>
          <View style={styles.tocBar}>
            <Text style={styles.tocTitle}>{copy.contents}</Text>
            <Pressable accessibilityRole="button" onPress={() => setTocOpen(false)}>
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
          <ScrollView contentContainerStyle={styles.tocList}>
            {query.trim().length > 0 ? (
              hits.length === 0 ? (
                <Text style={styles.empty}>{copy.noHits}</Text>
              ) : (
                hits.map((hit) => (
                  <Pressable
                    accessibilityRole="button"
                    key={`${hit.href}:${hit.excerpt}`}
                    onPress={() => openTocItem({ title: hit.title, href: hit.href, fragment: null, children: [] })}
                    style={styles.tocRow}
                  >
                    <Text style={styles.tocItem}>{hit.title}</Text>
                    <Text style={styles.excerpt}>{hit.excerpt}</Text>
                  </Pressable>
                ))
              )
            ) : (
              <TocRows depth={0} items={document.toc()} onOpen={openTocItem} />
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
        onConfirmJump={(index) => openPlace(index, 0, null)}
        onSearchBook={(query) =>
          document.search(query).flatMap((hit) => {
            const placeIndex = document.indexOfHref(hit.href);
            return placeIndex < 0 ? [] : [{ placeIndex, excerpt: hit.excerpt }];
          })
        }
        placeCount={document.chapterCount}
        placeIndex={document.chapterIndex}
        title={entry.title}
      />
    </View>
  );
}

function TocRows({
  items,
  depth,
  onOpen,
}: {
  items: EpubTocItem[];
  depth: number;
  onOpen: (item: EpubTocItem) => void;
}) {
  return (
    <>
      {items.map((item) => (
        <View key={`${item.href}:${item.fragment ?? ""}:${item.title}`}>
          <Pressable
            accessibilityRole="button"
            onPress={() => onOpen(item)}
            style={[styles.tocRow, { paddingLeft: 16 + depth * 16 }]}
          >
            <Text style={styles.tocItem}>{item.title}</Text>
          </Pressable>
          {item.children.length > 0 ? (
            <TocRows depth={depth + 1} items={item.children} onOpen={onOpen} />
          ) : null}
        </View>
      ))}
    </>
  );
}

const styles = StyleSheet.create({
  screen: {
    backgroundColor: "#F5F0E8",
    flex: 1,
    minHeight: 0,
  },
  reading: {
    flex: 1,
    minHeight: 0,
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
  chapterTitle: {
    color: "#1C2423",
    fontSize: 22,
    fontWeight: "600",
    paddingBottom: 4,
    paddingHorizontal: 20,
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
  pageProgress: {
    color: "#8A7358",
    fontSize: 14,
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
  toc: {
    backgroundColor: "#F7F4EE",
    bottom: 0,
    left: 0,
    position: "absolute",
    right: 0,
    top: 0,
  },
  tocBar: {
    alignItems: "center",
    flexDirection: "row",
    justifyContent: "space-between",
    paddingHorizontal: 16,
    paddingVertical: 12,
  },
  tocTitle: {
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
  tocList: {
    paddingBottom: 24,
    paddingTop: 8,
  },
  tocRow: {
    paddingHorizontal: 16,
    paddingVertical: 12,
  },
  tocItem: {
    color: "#1C2423",
    fontSize: 16,
  },
  excerpt: {
    color: "#5C6563",
    fontSize: 14,
    marginTop: 4,
  },
  empty: {
    color: "#5C6563",
    fontSize: 16,
    paddingHorizontal: 16,
    paddingVertical: 12,
  },
});
