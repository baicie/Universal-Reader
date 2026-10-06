import { turnBackward, turnForward } from "./reading-place";

export type OpenedPdf =
  | { kind: "pdf" }
  | { kind: "unavailable" }
  | { kind: "corrupt" };

export function isPdfName(name: string): boolean {
  return name.toLowerCase().endsWith(".pdf");
}

export function openPdfDocument(bytes: Uint8Array | null): OpenedPdf {
  if (bytes == null || bytes.length === 0) return { kind: "unavailable" };
  if (!hasPdfHeader(bytes)) return { kind: "corrupt" };
  return { kind: "pdf" };
}

export function turnPdfPage(pageIndex: number, pageCount: number, direction: "next" | "prev"): number {
  const place = { chapterIndex: 0, pageIndex };
  const next =
    direction === "next" ? turnForward(place, pageCount, 1) : turnBackward(place);
  return next.pageIndex < 0 ? pageIndex : next.pageIndex;
}

export function readPdfFailure(data: unknown): boolean {
  let value = data;
  if (typeof value === "string") {
    try {
      value = JSON.parse(value) as unknown;
    } catch {
      return false;
    }
  }
  if (typeof value !== "object" || value == null) return false;
  return (value as { type?: unknown }).type === "failed";
}

export function readPdfPageText(data: unknown): { pageIndex: number; text: string } | null {
  let value = data;
  if (typeof value === "string") {
    try {
      value = JSON.parse(value) as unknown;
    } catch {
      return null;
    }
  }
  if (typeof value !== "object" || value == null) return null;
  const record = value as { type?: unknown; pageIndex?: unknown; text?: unknown };
  if (record.type !== "text") return null;
  if (typeof record.pageIndex !== "number" || !Number.isInteger(record.pageIndex) || record.pageIndex < 0) return null;
  if (typeof record.text !== "string") return null;
  return { pageIndex: record.pageIndex, text: record.text };
}

export type PdfTextItem = {
  str: string;
  x: number;
  y: number;
  width: number;
  height: number;
  hasEOL?: boolean;
};

export type PdfQuoteBox = {
  x: number;
  y: number;
  width: number;
  height: number;
};

export function pdfQuoteBoxes(items: PdfTextItem[], quotes: string[]): PdfQuoteBox[] {
  const needles = quotes
    .map((quote) => quote.trim())
    .filter((quote) => quote.length > 0)
    .sort((left, right) => right.length - left.length);
  if (needles.length === 0) return [];
  const glyphs: { item: number; offset: number }[] = [];
  let text = "";
  for (let index = 0; index < items.length; index += 1) {
    const item = items[index];
    const str = item?.str ?? "";
    for (let offset = 0; offset < str.length; offset += 1) {
      text += str[offset] ?? "";
      glyphs.push({ item: index, offset });
    }
    if (item?.hasEOL) {
      text += "\n";
      glyphs.push({ item: -1, offset: 0 });
    }
  }
  const ranges: { start: number; end: number }[] = [];
  let cursor = 0;
  while (cursor < text.length) {
    let hitAt = -1;
    let hit = "";
    for (const quote of needles) {
      const at = text.indexOf(quote, cursor);
      if (at < 0) continue;
      if (hitAt < 0 || at < hitAt) {
        hitAt = at;
        hit = quote;
      }
    }
    if (hitAt < 0) break;
    ranges.push({ start: hitAt, end: hitAt + hit.length });
    cursor = hitAt + hit.length;
  }
  const boxes: PdfQuoteBox[] = [];
  for (const range of ranges) {
    let runItem = -1;
    let runStart = 0;
    let runEnd = 0;
    const flush = () => {
      if (runItem < 0) return;
      const item = items[runItem];
      if (item != null && item.str.length > 0 && item.width > 0 && item.height > 0) {
        boxes.push({
          x: item.x + (runStart / item.str.length) * item.width,
          y: item.y,
          width: ((runEnd - runStart) / item.str.length) * item.width,
          height: item.height,
        });
      }
      runItem = -1;
    };
    for (let index = range.start; index < range.end; index += 1) {
      const glyph = glyphs[index];
      if (glyph == null || glyph.item < 0) {
        flush();
        continue;
      }
      if (glyph.item !== runItem) {
        flush();
        runItem = glyph.item;
        runStart = glyph.offset;
      }
      runEnd = glyph.offset + 1;
    }
    flush();
  }
  return boxes;
}

export function textForReportedPage(
  report: { pageIndex: number; text: string } | null,
  pageIndex: number,
): string {
  if (report == null || report.pageIndex !== pageIndex) return "";
  return report.text;
}

export type PdfSearchHit = {
  pageIndex: number;
  excerpt: string;
};

const PDF_SEARCH_HIT_LIMIT = 10;

export function searchPdf(bytes: Uint8Array, query: string): PdfSearchHit[] {
  const needle = query.trim();
  if (needle.length === 0) return [];
  const pages = pdfPageTexts(bytes);
  const hits: PdfSearchHit[] = [];
  for (let index = 0; index < pages.length; index += 1) {
    const text = pages[index] ?? "";
    const at = text.indexOf(needle);
    if (at < 0) continue;
    hits.push({ pageIndex: index, excerpt: excerptAround(text, at, needle.length) });
    if (hits.length >= PDF_SEARCH_HIT_LIMIT) break;
  }
  return hits;
}

function pdfPageTexts(bytes: Uint8Array): string[] {
  if (!hasPdfHeader(bytes)) return [];
  const source = latin1(bytes);
  const pageCount = source.match(/\/Type\s*\/Page(?![s\w])/g)?.length ?? 0;
  const strings = [...source.matchAll(/\((?:\\.|[^\\)])*\)\s*Tj/g)]
    .map((match) => unescapePdfString(match[0]))
    .filter((text) => text.trim().length > 0);
  if (pageCount === 0 || strings.length === 0) return [];
  if (strings.length === pageCount) return strings;
  const perPage = Math.ceil(strings.length / pageCount);
  const pages: string[] = [];
  for (let index = 0; index < pageCount; index += 1) {
    const start = index * perPage;
    if (start >= strings.length) break;
    pages.push(strings.slice(start, start + perPage).join(" "));
  }
  return pages;
}

function unescapePdfString(match: string): string {
  const start = match.indexOf("(");
  const end = match.lastIndexOf(")");
  if (start < 0 || end <= start) return "";
  return match
    .slice(start + 1, end)
    .replaceAll("\\(", "(")
    .replaceAll("\\)", ")")
    .replaceAll("\\n", "\n")
    .replaceAll("\\r", "\r")
    .replaceAll("\\t", "\t")
    .replaceAll("\\\\", "\\");
}

function excerptAround(text: string, start: number, queryLength: number): string {
  const from = start < 24 ? 0 : start - 24;
  const to = Math.min(text.length, start + queryLength + 24);
  return text.slice(from, to).trim();
}

function latin1(bytes: Uint8Array): string {
  let text = "";
  const size = 0x8000;
  for (let index = 0; index < bytes.length; index += size) {
    text += String.fromCharCode(...bytes.subarray(index, index + size));
  }
  return text;
}

function hasPdfHeader(bytes: Uint8Array): boolean {
  let index = 0;
  while (index < bytes.length && bytes[index] <= 32) index += 1;
  const header = [0x25, 0x50, 0x44, 0x46, 0x2d];
  if (index + header.length > bytes.length) return false;
  return header.every((byte, offset) => bytes[index + offset] === byte);
}
