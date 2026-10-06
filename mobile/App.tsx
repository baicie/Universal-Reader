import { getDocumentAsync } from "expo-document-picker";
import { getLocales } from "expo-localization";
import { StatusBar } from "expo-status-bar";
import { useState } from "react";
import { SafeAreaView, StyleSheet } from "react-native";

import { bytesFromAsset } from "./src/bytes-from-asset";
import { extractCover } from "./src/cover";
import { copyFor, languageFromCode } from "./src/copy";
import { comicFormatFromName, openComicDocument } from "./src/comic-document";
import { isEpubName, openEpubDocument } from "./src/epub-document";
import { isFb2Name, openFb2Document } from "./src/fb2-document";
import { isDocxName, openDocxDocument } from "./src/docx-document";
import { isAzw3Name, isMobiName, openMobiDocument } from "./src/mobi-document";
import { isChmName, openChmDocument } from "./src/chm-document";
import { isDjvuName, openDjvuDocument } from "./src/djvu-document";
import { isOdtName, openOdtDocument } from "./src/odt-document";
import { isRtfName, openRtfDocument } from "./src/rtf-document";
import { isPdfName, openPdfDocument } from "./src/pdf-document";
import { prepareShelfBook } from "./src/prepare-shelf-book";
import { ComicReaderScreen } from "./src/screens/ComicReaderScreen";
import { EpubReaderScreen } from "./src/screens/EpubReaderScreen";
import { LibraryScreen, type ShelfEntry } from "./src/screens/LibraryScreen";
import { PdfReaderScreen } from "./src/screens/PdfReaderScreen";
import { ReaderScreen } from "./src/screens/ReaderScreen";
import { openTextDocument, textFormatFromName, titleFromName } from "./src/text-document";
import { useShelf } from "./src/use-shelf";
import { syncS3Reading, syncWebDavReading } from "./src/reading-sync";
import { listS3Files, pushS3Books } from "./src/s3";
import { listWebDavFiles, pushWebDavBooks } from "./src/webdav";

type Notice =
  | "corrupt"
  | "unavailable"
  | "unsupported"
  | "read-failed"
  | "webdav-failed"
  | "webdav-empty"
  | "webdav-nothing"
  | "webdav-push-failed"
  | "s3-failed"
  | "s3-empty"
  | "s3-nothing"
  | "s3-push-failed"
  | "reading-sync-failed";

export default function App() {
  const copy = copyFor(languageFromCode(getLocales()[0]?.languageCode));
  const shelfState = useShelf();
  const [notice, setNotice] = useState<Notice | null>(null);
  const [readingId, setReadingId] = useState<string | null>(null);
  const reading = shelfState.shelf.find((entry) => entry.id === readingId) ?? null;
  const shownNotice = notice ?? shelfState.block;

  async function openFile() {
    if (!shelfState.ready || shelfState.block) return;
    setNotice(null);
    const picked = await getDocumentAsync({
      base64: false,
      copyToCacheDirectory: true,
      multiple: false,
    });
    if (picked.canceled) return;
    const asset = picked.assets[0];
    if (asset == null) return;
    const comicFormat = comicFormatFromName(asset.name);
    const format = comicFormat
      ? comicFormat
      : isPdfName(asset.name)
        ? "pdf"
        : isEpubName(asset.name)
          ? "epub"
          : isFb2Name(asset.name)
            ? "fb2"
            : isRtfName(asset.name)
              ? "rtf"
              : isDocxName(asset.name)
                ? "docx"
                : isOdtName(asset.name)
                  ? "odt"
                  : isMobiName(asset.name)
                    ? "mobi"
                    : isAzw3Name(asset.name)
                      ? "azw3"
                      : isChmName(asset.name)
                        ? "chm"
                        : isDjvuName(asset.name)
                          ? "djvu"
                          : textFormatFromName(asset.name);
    if (format == null) {
      setNotice("unsupported");
      return;
    }
    let bytes: Uint8Array;
    try {
      bytes = await bytesFromAsset(asset);
    } catch {
      // The picker can return a URI this runtime cannot read. Say so; do not invent text.
      setNotice("read-failed");
      return;
    }
    let title = titleFromName(asset.name);
    let author = "";
    let storedFormat: ShelfEntry["format"];
    let comicCover: Uint8Array | null = null;
    if (comicFormat) {
      const opened = await openComicDocument(asset.name, bytes);
      if (opened.kind !== "comic") {
        setNotice(opened.kind);
        return;
      }
      storedFormat = opened.format;
      const page = opened.pages[0];
      comicCover = page ? new Uint8Array(page.bytes) : null;
    } else if (format === "epub") {
      const opened = openEpubDocument(bytes);
      if (opened.kind !== "epub") {
        setNotice(opened.kind);
        return;
      }
      if (opened.document.title.length > 0) title = opened.document.title;
      author = opened.document.author;
      storedFormat = "epub";
    } else if (format === "pdf") {
      const opened = openPdfDocument(bytes);
      if (opened.kind !== "pdf") {
        setNotice(opened.kind);
        return;
      }
      storedFormat = "pdf";
    } else if (format === "fb2") {
      const opened = openFb2Document(bytes);
      if (opened.kind !== "fb2") {
        setNotice(opened.kind);
        return;
      }
      if (opened.document.title.length > 0) title = opened.document.title;
      author = opened.document.author;
      storedFormat = "fb2";
    } else if (format === "rtf") {
      const opened = openRtfDocument(bytes);
      if (opened.kind !== "rtf") {
        setNotice(opened.kind);
        return;
      }
      if (opened.document.title.length > 0) title = opened.document.title;
      author = opened.document.author;
      storedFormat = "rtf";
    } else if (format === "docx") {
      const opened = openDocxDocument(bytes);
      if (opened.kind !== "docx") {
        setNotice(opened.kind);
        return;
      }
      if (opened.document.title.length > 0) title = opened.document.title;
      author = opened.document.author;
      storedFormat = "docx";
    } else if (format === "odt") {
      const opened = openOdtDocument(bytes);
      if (opened.kind !== "odt") {
        setNotice(opened.kind);
        return;
      }
      if (opened.document.title.length > 0) title = opened.document.title;
      author = opened.document.author;
      storedFormat = "odt";
    } else if (format === "mobi" || format === "azw3") {
      const opened = openMobiDocument(bytes);
      if (opened.kind !== "mobi") {
        setNotice(opened.kind);
        return;
      }
      if (opened.document.title.length > 0) title = opened.document.title;
      author = opened.document.author;
      storedFormat = format;
    } else if (format === "chm") {
      const opened = await openChmDocument(bytes);
      if (opened.kind !== "chm") {
        setNotice(opened.kind);
        return;
      }
      if (opened.document.title.length > 0) title = opened.document.title;
      author = opened.document.author;
      storedFormat = "chm";
    } else if (format === "djvu") {
      const opened = await openDjvuDocument(bytes);
      if (opened.kind !== "djvu") {
        setNotice(opened.kind);
        return;
      }
      storedFormat = "djvu";
      const page = opened.pages[0];
      comicCover = page ? new Uint8Array(page.bytes) : null;
    } else if (format === "txt" || format === "markdown" || format === "html") {
      const opened = openTextDocument({ id: asset.name, title, author: "", format }, bytes);
      if (opened.kind !== "text") {
        setNotice(opened.kind);
        return;
      }
      storedFormat = format;
    } else {
      setNotice("unsupported");
      return;
    }
    try {
      const imported = await shelfState.importBook({
        title,
        author,
        format: storedFormat,
        bytes,
        cover: comicFormat || storedFormat === "djvu" ? comicCover : extractCover(storedFormat, bytes),
      });
      if (!imported) return;
      shelfState.setShelf(imported.books);
      setReadingId(imported.book.id);
    } catch {
      // The file was readable, but the shelf could not keep it. Do not show another book.
      setNotice("read-failed");
    }
  }

  async function importWebDav(account: { baseUrl: string; username: string; password: string }) {
    if (!shelfState.ready || shelfState.block) return;
    setNotice(null);
    let files;
    try {
      files = await listWebDavFiles(account);
    } catch {
      setNotice("webdav-failed");
      return;
    }
    let stored: ShelfEntry[] | null = null;
    let sawBook = false;
    for (const file of files) {
      const prepared = await prepareShelfBook(file.name, file.bytes);
      if (prepared == null) continue;
      sawBook = true;
      try {
        const imported = await shelfState.importBook({
          title: prepared.title,
          author: prepared.author,
          format: prepared.format,
          bytes: file.bytes,
          cover: prepared.cover,
        });
        if (!imported) continue;
        stored = imported.books;
      } catch {
        // This file did not land. Keep the books that already did.
      }
    }
    if (stored) {
      shelfState.setShelf(stored);
      return;
    }
    setNotice(sawBook ? "webdav-failed" : "webdav-empty");
  }

  async function importS3(account: {
    endpoint: string;
    region: string;
    bucket: string;
    prefix: string;
    accessKey: string;
    secretKey: string;
  }) {
    if (!shelfState.ready || shelfState.block) return;
    setNotice(null);
    let files;
    try {
      files = await listS3Files(account);
    } catch {
      setNotice("s3-failed");
      return;
    }
    let stored: ShelfEntry[] | null = null;
    let sawBook = false;
    for (const file of files) {
      const prepared = await prepareShelfBook(file.name, file.bytes);
      if (prepared == null) continue;
      sawBook = true;
      try {
        const imported = await shelfState.importBook({
          title: prepared.title,
          author: prepared.author,
          format: prepared.format,
          bytes: file.bytes,
          cover: prepared.cover,
        });
        if (!imported) continue;
        stored = imported.books;
      } catch {
        // This file did not land. Keep the books that already did.
      }
    }
    if (stored) {
      shelfState.setShelf(stored);
      return;
    }
    setNotice(sawBook ? "s3-failed" : "s3-empty");
  }

  async function pushS3(account: {
    endpoint: string;
    region: string;
    bucket: string;
    prefix: string;
    accessKey: string;
    secretKey: string;
  }) {
    if (!shelfState.ready || shelfState.block) return;
    setNotice(null);
    try {
      const result = await pushS3Books(account, shelfState.shelf);
      if (result.failed.length > 0) {
        setNotice("s3-push-failed");
        return;
      }
      if (result.pushed.length === 0) setNotice("s3-nothing");
    } catch {
      setNotice("s3-failed");
    }
  }

  async function syncWebDavReadingPlace(account: { baseUrl: string; username: string; password: string }) {
    if (!shelfState.ready || shelfState.block) return;
    setNotice(null);
    try {
      const result = await syncWebDavReading(account, shelfState.shelf);
      await shelfState.saveReading(result.books);
    } catch {
      setNotice("reading-sync-failed");
    }
  }

  async function syncS3ReadingPlace(account: {
    endpoint: string;
    region: string;
    bucket: string;
    prefix: string;
    accessKey: string;
    secretKey: string;
  }) {
    if (!shelfState.ready || shelfState.block) return;
    setNotice(null);
    try {
      const result = await syncS3Reading(account, shelfState.shelf);
      await shelfState.saveReading(result.books);
    } catch {
      setNotice("reading-sync-failed");
    }
  }

  async function pushWebDav(account: { baseUrl: string; username: string; password: string }) {
    if (!shelfState.ready || shelfState.block) return;
    setNotice(null);
    try {
      const result = await pushWebDavBooks(account, shelfState.shelf);
      if (result.failed.length > 0) {
        setNotice("webdav-push-failed");
        return;
      }
      if (result.pushed.length === 0) setNotice("webdav-nothing");
    } catch {
      setNotice("webdav-failed");
    }
  }

  return (
    <SafeAreaView style={styles.root}>
      <StatusBar style="dark" />
      {reading?.format === "epub" ? (
        <EpubReaderScreen
          key={reading.id}
          copy={copy}
          entry={reading}
          onBack={(chapterIndex, pageIndex, progress) => {
            void shelfState.rememberPlace(reading.id, chapterIndex, pageIndex, progress).then(() => {
              setReadingId(null);
            });
          }}
          onLoadConversation={shelfState.loadConversation}
          onRememberConversation={shelfState.rememberConversation}
          onLoadNotes={shelfState.loadNotes}
          onRememberNote={shelfState.rememberNote}
          onRememberBookmark={shelfState.rememberBookmark}
          onRememberSelection={shelfState.rememberSelection}
          onForgetNote={shelfState.forgetNote}
          onReadingPrefs={(prefs) => {
            void shelfState.updateReadingPrefs(prefs);
          }}
          readingPrefs={shelfState.readingPrefs}
        />
      ) : reading && (reading.format === "cbz" || reading.format === "cbt" || reading.format === "cbr" || reading.format === "cb7" || reading.format === "djvu") ? (
        <ComicReaderScreen
          key={reading.id}
          copy={copy}
          entry={reading}
          onBack={(pageIndex, progress) => {
            void shelfState.rememberPlace(reading.id, reading.chapterIndex, pageIndex, progress).then(() => {
              setReadingId(null);
            });
          }}
          onForgetNote={shelfState.forgetNote}
          onLoadNotes={shelfState.loadNotes}
          onRememberBookmark={shelfState.rememberBookmark}
          onReadingPrefs={(prefs) => {
            void shelfState.updateReadingPrefs(prefs);
          }}
          readingPrefs={shelfState.readingPrefs}
        />
      ) : reading?.format === "pdf" ? (
        <PdfReaderScreen
          key={reading.id}
          copy={copy}
          entry={reading}
          onBack={(pageIndex, progress) => {
            void shelfState.rememberPlace(reading.id, reading.chapterIndex, pageIndex, progress).then(() => {
              setReadingId(null);
            });
          }}
          onFailed={() => {
            void shelfState.removeBook(reading.id).then(() => {
              setNotice("corrupt");
              setReadingId(null);
            });
          }}
          onLoadConversation={shelfState.loadConversation}
          onRememberConversation={shelfState.rememberConversation}
          onLoadNotes={shelfState.loadNotes}
          onRememberNote={shelfState.rememberNote}
          onRememberBookmark={shelfState.rememberBookmark}
          onRememberSelection={shelfState.rememberSelection}
          onForgetNote={shelfState.forgetNote}
          onReadingPrefs={(prefs) => {
            void shelfState.updateReadingPrefs(prefs);
          }}
          readingPrefs={shelfState.readingPrefs}
        />
      ) : reading ? (
        <ReaderScreen
          key={reading.id}
          copy={copy}
          entry={reading}
          onBack={(chapterIndex, progress) => {
            void shelfState.rememberPlace(reading.id, chapterIndex, reading.pageIndex, progress).then(() => {
              setReadingId(null);
            });
          }}
          onLoadConversation={shelfState.loadConversation}
          onRememberConversation={shelfState.rememberConversation}
          onLoadNotes={shelfState.loadNotes}
          onRememberNote={shelfState.rememberNote}
          onRememberBookmark={shelfState.rememberBookmark}
          onRememberSelection={shelfState.rememberSelection}
          onForgetNote={shelfState.forgetNote}
          onReadingPrefs={(prefs) => {
            void shelfState.updateReadingPrefs(prefs);
          }}
          readingPrefs={shelfState.readingPrefs}
        />
      ) : (
        <LibraryScreen
          copy={copy}
          notice={shownNotice}
          onOpenEntry={setReadingId}
          onRemove={(id) => {
            void shelfState.removeBook(id);
          }}
          onRename={(id, title, author) => {
            void shelfState.renameBook(id, title, author);
          }}
          onLoadNotes={shelfState.loadNotes}
          sections={shelfState.sections}
          onToggleFavorite={(id) => {
            void shelfState.toggleShelfFavorite(id);
          }}
          onCreateCollection={shelfState.createCollection}
          onToggleCollection={(collectionId, id) => {
            void shelfState.toggleShelfCollection(collectionId, id);
          }}
          onDeleteCollection={(id) => {
            void shelfState.deleteCollection(id);
          }}
          onImportS3={importS3}
          onPushS3={pushS3}
          onSyncS3Reading={syncS3ReadingPlace}
          onSyncWebDavReading={syncWebDavReadingPlace}
          onImportWebDav={importWebDav}
          onPushWebDav={pushWebDav}
          onOpenFile={() => {
            void openFile();
          }}
          ready={shelfState.ready}
          shelf={shelfState.shelf}
        />
      )}
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  root: {
    backgroundColor: "#F7F4EE",
    flex: 1,
  },
});
