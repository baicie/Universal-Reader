import type { ShelfDatabase } from "./shelf-store";
import { parseComicLayout, parseComicReadDirection, type ComicLayout, type ComicReadDirection } from "./comic-layout";

export const minFontSize = 14;
export const maxFontSize = 28;
export const defaultFontSize = 18;
export const minLineHeight = 1.4;
export const maxLineHeight = 2.2;
export const defaultLineHeight = 1.7;
export const minPdfZoom = 1;
export const maxPdfZoom = 3;
export const defaultPdfZoom = 1;
export const pdfZoomStops = [1, 1.25, 1.5, 2, 3] as const;

export type ReaderFontFamily = "serif" | "sans" | "mono";
export type ReaderPaper = "followApp" | "light" | "dark";
export type ReadingBrightness = "light" | "dark";

export type ReadingPrefs = {
  fontSize: number;
  lineHeight: number;
  fontFamily: ReaderFontFamily;
  paper: ReaderPaper;
  pdfZoom: number;
  comicLayout: ComicLayout;
  comicDirection: ComicReadDirection;
};

export type ReadingSurface = {
  fontSize: number;
  lineHeight: number;
  fontFamily: ReaderFontFamily;
  cssFontFamily: string;
  nativeFontFamily: string | undefined;
  background: string;
  color: string;
  muted: string;
  dark: boolean;
};

export const defaultReadingPrefs: ReadingPrefs = {
  fontSize: defaultFontSize,
  lineHeight: defaultLineHeight,
  fontFamily: "serif",
  paper: "followApp",
  pdfZoom: defaultPdfZoom,
  comicLayout: "single",
  comicDirection: "ltr",
};

const serifCss = 'Georgia, "Noto Serif", "Songti SC", serif';
const sansCss = 'system-ui, "Segoe UI", "PingFang SC", "Noto Sans", sans-serif';
const monoCss = 'ui-monospace, "Cascadia Mono", "Sarasa Mono SC", monospace';
const lightBackground = "#F5F0E8";
const lightInk = "#2A2620";
const darkBackground = "#1C1B18";
const darkInk = "#E8E2D6";
const lightMuted = "#8A7358";
const darkMuted = "#B7A894";

export function clampFontSize(value: number): number {
  if (!Number.isFinite(value)) return defaultFontSize;
  return Math.min(maxFontSize, Math.max(minFontSize, Math.round(value)));
}

export function clampLineHeight(value: number): number {
  if (!Number.isFinite(value)) return defaultLineHeight;
  const tenths = Math.round(value * 10) / 10;
  return Math.min(maxLineHeight, Math.max(minLineHeight, tenths));
}

export function clampPdfZoom(value: number): number {
  if (!Number.isFinite(value)) return defaultPdfZoom;
  const quarters = Math.round(value * 4) / 4;
  return Math.min(maxPdfZoom, Math.max(minPdfZoom, quarters));
}

export function readingPrefsFrom(raw: unknown): ReadingPrefs {
  if (raw == null || typeof raw !== "object" || Array.isArray(raw)) return { ...defaultReadingPrefs };
  const record = raw as Record<string, unknown>;
  const fontSize = typeof record.fontSize === "number" ? record.fontSize : null;
  const lineHeight = typeof record.lineHeight === "number" ? record.lineHeight : null;
  const pdfZoom = typeof record.pdfZoom === "number" ? record.pdfZoom : null;
  return {
    fontSize: fontSize == null || !Number.isFinite(fontSize) ? defaultFontSize : clampFontSize(fontSize),
    lineHeight: lineHeight == null || !Number.isFinite(lineHeight) ? defaultLineHeight : clampLineHeight(lineHeight),
    fontFamily: record.fontFamily === "sans" || record.fontFamily === "mono" ? record.fontFamily : "serif",
    paper: record.paper === "light" || record.paper === "dark" ? record.paper : "followApp",
    pdfZoom: pdfZoom == null ? defaultPdfZoom : clampPdfZoom(pdfZoom),
    comicLayout: parseComicLayout(record.comicLayout),
    comicDirection: parseComicReadDirection(record.comicDirection),
  };
}

export function readingSurface(prefs: ReadingPrefs, brightness: ReadingBrightness): ReadingSurface {
  const choice = readingPrefsFrom(prefs);
  const dark = choice.paper === "dark" || (choice.paper === "followApp" && brightness === "dark");
  return {
    fontSize: choice.fontSize,
    lineHeight: choice.lineHeight,
    fontFamily: choice.fontFamily,
    cssFontFamily: choice.fontFamily === "sans" ? sansCss : choice.fontFamily === "mono" ? monoCss : serifCss,
    nativeFontFamily: choice.fontFamily === "sans" ? undefined : choice.fontFamily === "mono" ? "Courier" : "Georgia",
    background: dark ? darkBackground : lightBackground,
    color: dark ? darkInk : lightInk,
    muted: dark ? darkMuted : lightMuted,
    dark,
  };
}

export async function loadReadingPrefs(db: ShelfDatabase): Promise<ReadingPrefs> {
  await db.exec(`
    CREATE TABLE IF NOT EXISTS reader_prefs (
      id TEXT PRIMARY KEY,
      payload TEXT NOT NULL
    )
  `);
  const rows = await db.all("SELECT payload FROM reader_prefs WHERE id = ?", ["reading"]);
  const payload = rows[0]?.payload;
  if (typeof payload !== "string") return { ...defaultReadingPrefs };
  try {
    return readingPrefsFrom(JSON.parse(payload));
  } catch {
    return { ...defaultReadingPrefs };
  }
}

export async function saveReadingPrefs(db: ShelfDatabase, prefs: ReadingPrefs): Promise<void> {
  await db.exec(`
    CREATE TABLE IF NOT EXISTS reader_prefs (
      id TEXT PRIMARY KEY,
      payload TEXT NOT NULL
    )
  `);
  const stored = readingPrefsFrom(prefs);
  await db.run(
    "INSERT INTO reader_prefs (id, payload) VALUES (?, ?) ON CONFLICT(id) DO UPDATE SET payload = excluded.payload",
    ["reading", JSON.stringify(stored)],
  );
}
