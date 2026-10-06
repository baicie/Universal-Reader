import { createElement, useEffect, useState } from "react";
import { Image, Platform, Pressable, ScrollView, StyleSheet, Text, View } from "react-native";

import { comicNextPageIndex, comicPreviousPageIndex, comicSpread, comicTapTurn } from "../comic-layout";
import { comicPageImage, openComicDocument, type ComicPage } from "../comic-document";
import { openDjvuDocument } from "../djvu-document";
import type { Copy } from "../copy";
import type { BookNote } from "../note-store";
import type { ReadingPrefs } from "../reading-prefs";
import { readingIndexForProgress, readingProgress } from "../reading-progress";
import { placeProgress } from "../reading-sync";
import type { ShelfEntry } from "./LibraryScreen";
import { BookmarksPanel } from "./BookmarksPanel";
import { ReadingProgress } from "./ReadingProgress";
import { ReadingSettings } from "./ReadingSettings";

type Props = {
  copy: Copy;
  entry: ShelfEntry;
  onBack: (pageIndex: number, progress: number) => void;
  onLoadNotes: (id: string) => Promise<BookNote[]>;
  onRememberBookmark: (id: string, chapterIndex: number, pageIndex: number) => Promise<BookNote[]>;
  onForgetNote: (id: string, noteId: string) => Promise<BookNote[]>;
  readingPrefs: ReadingPrefs;
  onReadingPrefs: (prefs: ReadingPrefs) => void;
};

function ComicPicture({ page, fill = true }: { page: ComicPage; fill?: boolean }) {
  const image = comicPageImage(page);
  if (Platform.OS === "web") {
    return (
      <View style={fill ? styles.page : styles.verticalPage}>
        {createElement("img", {
          alt: image.alt,
          src: image.src,
          style: fill
            ? { height: "100%", objectFit: "contain", width: "100%" }
            : { display: "block", objectFit: "contain", width: "100%" },
        })}
      </View>
    );
  }
  return (
    <Image
      accessibilityLabel={image.alt}
      resizeMode="contain"
      source={{ uri: image.src }}
      style={fill ? styles.page : styles.verticalPage}
    />
  );
}

export function ComicReaderScreen({
  copy,
  entry,
  onBack,
  onLoadNotes,
  onRememberBookmark,
  onForgetNote,
  readingPrefs,
  onReadingPrefs,
}: Props) {
  const [pages, setPages] = useState<ComicPage[] | null>(null);
  const [pageIndex, setPageIndex] = useState(entry.pageIndex);
  const [notes, setNotes] = useState<BookNote[]>([]);
  const [bookmarksOpen, setBookmarksOpen] = useState(false);
  const [settingsOpen, setSettingsOpen] = useState(false);
  const [chromeOpen, setChromeOpen] = useState(true);
  const [pageWidth, setPageWidth] = useState(0);
  const comic = entry.format !== "djvu";
  const layout = comic ? readingPrefs.comicLayout : "single";
  const direction = comic ? readingPrefs.comicDirection : "ltr";
  useEffect(() => {
    let cancelled = false;
    setPages(null);
    void (entry.format === "djvu"
      ? openDjvuDocument(entry.bytes)
      : openComicDocument(entry.title + "." + entry.format, entry.bytes)
    )
      .then((opened) => {
        if (cancelled) return;
        const next = opened.kind === "comic" || opened.kind === "djvu" ? opened.pages : [];
        setPages(next);
        setPageIndex((current) => Math.min(current < 0 ? 0 : current, Math.max(next.length - 1, 0)));
      })
      .catch(() => {
        if (!cancelled) setPages([]);
      });
    return () => {
      cancelled = true;
    };
  }, [entry.bytes, entry.format, entry.title]);
  useEffect(() => {
    let cancelled = false;
    void onLoadNotes(entry.id)
      .then((loaded) => {
        if (!cancelled) setNotes(loaded);
      })
      .catch(() => {
        if (!cancelled) setNotes([]);
      });
    return () => {
      cancelled = true;
    };
  }, [entry.id, onLoadNotes]);
  const page = pages?.[pageIndex];
  const spread = pages && pages.length > 0 ? comicSpread({ pages, pageIndex, layout, direction }) : null;
  const atStart =
    pages == null || pages.length === 0 || comicPreviousPageIndex({ pageIndex, pageCount: pages.length, layout }) === pageIndex;
  const atEnd =
    pages == null || pages.length === 0 || comicNextPageIndex({ pageIndex, pageCount: pages.length, layout }) === pageIndex;

  function turn(directionName: "next" | "prev") {
    if (pages == null) return;
    const next =
      directionName === "next"
        ? comicNextPageIndex({ pageIndex, pageCount: pages.length, layout })
        : comicPreviousPageIndex({ pageIndex, pageCount: pages.length, layout });
    if (next !== pageIndex) setPageIndex(next);
  }

  function tapPage(x: number | undefined) {
    if (x == null || pages == null) return;
    const result = comicTapTurn({
      x,
      width: pageWidth,
      direction,
      layout,
      pageIndex,
      pageCount: pages.length,
    });
    if (result.toggleChrome) {
      setChromeOpen((open) => !open);
      setBookmarksOpen(false);
      setSettingsOpen(false);
      return;
    }
    if (result.pageIndex !== pageIndex) setPageIndex(result.pageIndex);
  }

  function seek(fraction: number) {
    if (pages == null || pages.length === 0) return;
    const next = readingIndexForProgress(fraction, pages.length);
    if (next !== pageIndex) setPageIndex(next);
  }

  const pageBody =
    pages != null && pages.length > 0 && layout === "vertical" ? (
      <ScrollView contentContainerStyle={styles.vertical} style={styles.page}>
        {pages.map((item, index) => (
          <ComicPicture fill={false} key={`${item.name}-${index}`} page={item} />
        ))}
      </ScrollView>
    ) : spread && layout === "double" && spread.left && spread.right ? (
      <View style={styles.spread}>
        <ComicPicture page={spread.left} />
        <ComicPicture page={spread.right} />
      </View>
    ) : spread && layout === "double" && spread.left ? (
      <ComicPicture page={spread.left} />
    ) : spread && layout === "double" && spread.right ? (
      <ComicPicture page={spread.right} />
    ) : page ? (
      <ComicPicture page={page} />
    ) : null;

  return (
    <View style={styles.screen}>
      {chromeOpen ? (
      <View style={styles.header}>
        <Pressable
          accessibilityRole="button"
          onPress={() =>
            onBack(
              pageIndex < 0 ? 0 : pageIndex,
              placeProgress(pageIndex < 0 ? 0 : pageIndex, pages?.length ?? 0),
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
          onPress={() => setBookmarksOpen((open) => !open)}
          style={styles.headerButton}
        >
          <Text style={styles.headerButtonLabel}>{copy.bookmarks}</Text>
        </Pressable>
        {comic ? (
          <Pressable
            accessibilityRole="button"
            onPress={() => {
              setBookmarksOpen(false);
              setSettingsOpen((open) => !open);
            }}
            style={styles.headerButton}
          >
            <Text style={styles.headerButtonLabel}>{copy.readingSettings}</Text>
          </Pressable>
        ) : null}
        <Text style={styles.progress}>
          {pages != null && pages.length > 0 ? copy.page(pageIndex + 1, pages.length) : ""}
        </Text>
      </View>
      ) : null}
      {chromeOpen && bookmarksOpen ? (
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
            setPageIndex(Math.min(nextPage < 0 ? 0 : nextPage, Math.max((pages?.length ?? 1) - 1, 0)));
          }}
        />
      ) : null}
      {chromeOpen && settingsOpen && comic ? (
        <ReadingSettings copy={copy} onChange={onReadingPrefs} prefs={readingPrefs} showComicLayout />
      ) : null}
      {pageBody ? (
        <Pressable
          accessibilityLabel={copy.comicPage}
          accessibilityRole="button"
          onLayout={(event) => setPageWidth(event.nativeEvent.layout.width)}
          onPress={(event) => {
            const point = event.nativeEvent as { locationX?: number; offsetX?: number };
            tapPage(point.locationX ?? point.offsetX);
          }}
          style={styles.page}
        >
          {pageBody}
        </Pressable>
      ) : pages != null ? (
        <Text style={styles.notice}>{copy.corrupt}</Text>
      ) : null}
      {chromeOpen && pages != null && pages.length > 0 ? (
        <ReadingProgress
          copy={copy}
          onSeek={seek}
          progress={readingProgress(pageIndex < 0 ? 0 : pageIndex, pages.length)}
        />
      ) : null}
      {chromeOpen ? (
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
      ) : null}
    </View>
  );
}

const styles = StyleSheet.create({
  screen: {
    backgroundColor: "#1C2423",
    flex: 1,
    minHeight: 0,
  },
  header: {
    alignItems: "center",
    backgroundColor: "#F5F0E8",
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
  page: {
    flex: 1,
    minHeight: 0,
  },
  spread: {
    flex: 1,
    flexDirection: "row",
    minHeight: 0,
  },
  vertical: {
    gap: 12,
    paddingVertical: 12,
  },
  verticalPage: {
    width: "100%",
  },
  notice: {
    color: "#F5F0E8",
    fontSize: 16,
    padding: 24,
  },
  footer: {
    backgroundColor: "#F5F0E8",
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
});
