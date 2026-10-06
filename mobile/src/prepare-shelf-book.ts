import { isChmName, openChmDocument } from "./chm-document";
import { isDjvuName, openDjvuDocument } from "./djvu-document";
import { comicFormatFromName, openComicDocument } from "./comic-document";
import { extractCover } from "./cover";
import { isEpubName, openEpubDocument } from "./epub-document";
import { isFb2Name, openFb2Document } from "./fb2-document";
import { isDocxName, openDocxDocument } from "./docx-document";
import { isAzw3Name, isMobiName, openMobiDocument } from "./mobi-document";
import { isOdtName, openOdtDocument } from "./odt-document";
import { isRtfName, openRtfDocument } from "./rtf-document";
import { isPdfName, openPdfDocument } from "./pdf-document";
import type { ShelfFormat } from "./shelf-store";
import { openTextDocument, textFormatFromName, titleFromName } from "./text-document";

export type PreparedShelfBook = {
  title: string;
  author: string;
  format: ShelfFormat;
  cover: Uint8Array | null;
};

export async function prepareShelfBook(name: string, bytes: Uint8Array): Promise<PreparedShelfBook | null> {
  const comicFormat = comicFormatFromName(name);
  const format = comicFormat
    ? comicFormat
    : isPdfName(name)
      ? "pdf"
      : isEpubName(name)
        ? "epub"
        : isFb2Name(name)
          ? "fb2"
          : isRtfName(name)
            ? "rtf"
            : isDocxName(name)
              ? "docx"
              : isOdtName(name)
                ? "odt"
                : isMobiName(name)
                  ? "mobi"
                  : isAzw3Name(name)
                    ? "azw3"
                    : isChmName(name)
                      ? "chm"
                      : isDjvuName(name)
                        ? "djvu"
                        : textFormatFromName(name);
  if (format == null) return null;
  let title = titleFromName(name);
  if (format === "cbz" || format === "cbt" || format === "cbr" || format === "cb7") {
    const opened = await openComicDocument(name, bytes);
    if (opened.kind !== "comic") return null;
    const page = opened.pages[0];
    return { title, author: "", format: opened.format, cover: page ? new Uint8Array(page.bytes) : null };
  }
  if (format === "epub") {
    const opened = openEpubDocument(bytes);
    if (opened.kind !== "epub") return null;
    if (opened.document.title.length > 0) title = opened.document.title;
    return { title, author: opened.document.author, format: "epub", cover: extractCover("epub", bytes) };
  }
  if (format === "fb2") {
    const opened = openFb2Document(bytes);
    if (opened.kind !== "fb2") return null;
    if (opened.document.title.length > 0) title = opened.document.title;
    return { title, author: opened.document.author, format: "fb2", cover: extractCover("fb2", bytes) };
  }
  if (format === "rtf") {
    const opened = openRtfDocument(bytes);
    if (opened.kind !== "rtf") return null;
    if (opened.document.title.length > 0) title = opened.document.title;
    return { title, author: opened.document.author, format: "rtf", cover: null };
  }
  if (format === "docx") {
    const opened = openDocxDocument(bytes);
    if (opened.kind !== "docx") return null;
    if (opened.document.title.length > 0) title = opened.document.title;
    return { title, author: opened.document.author, format: "docx", cover: null };
  }
  if (format === "odt") {
    const opened = openOdtDocument(bytes);
    if (opened.kind !== "odt") return null;
    if (opened.document.title.length > 0) title = opened.document.title;
    return { title, author: opened.document.author, format: "odt", cover: null };
  }
  if (format === "mobi" || format === "azw3") {
    const opened = openMobiDocument(bytes);
    if (opened.kind !== "mobi") return null;
    if (opened.document.title.length > 0) title = opened.document.title;
    return { title, author: opened.document.author, format, cover: null };
  }
  if (format === "chm") {
    const opened = await openChmDocument(bytes);
    if (opened.kind !== "chm") return null;
    if (opened.document.title.length > 0) title = opened.document.title;
    return { title, author: opened.document.author, format: "chm", cover: null };
  }
  if (format === "djvu") {
    const opened = await openDjvuDocument(bytes);
    if (opened.kind !== "djvu") return null;
    const page = opened.pages[0];
    return { title, author: "", format: "djvu", cover: page ? new Uint8Array(page.bytes) : null };
  }
  if (format === "pdf") {
    const opened = openPdfDocument(bytes);
    if (opened.kind !== "pdf") return null;
    return { title, author: "", format: "pdf", cover: null };
  }
  if (format === "txt" || format === "markdown" || format === "html") {
    const opened = openTextDocument({ id: name, title, author: "", format }, bytes);
    if (opened.kind !== "text") return null;
    return { title, author: "", format, cover: null };
  }
  return null;
}
