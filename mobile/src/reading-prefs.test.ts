import assert from "node:assert/strict";
import { DatabaseSync } from "node:sqlite";
import test from "node:test";

import { importShelfBook, loadShelf, type ShelfDatabase } from "./shelf-store";
import {
  clampFontSize,
  clampLineHeight,
  clampPdfZoom,
  defaultReadingPrefs,
  loadReadingPrefs,
  readingPrefsFrom,
  readingSurface,
  saveReadingPrefs,
} from "./reading-prefs";

function memoryDatabase(): ShelfDatabase {
  const sqlite = new DatabaseSync(":memory:");
  return {
    async exec(sql) {
      sqlite.exec(sql);
    },
    async all(sql, params = []) {
      return sqlite.prepare(sql).all(...params) as Record<string, unknown>[];
    },
    async run(sql, params = []) {
      sqlite.prepare(sql).run(...params);
    },
  };
}

test("reading text stays inside the font and line limits", () => {
  assert.deepEqual(defaultReadingPrefs, {
    fontSize: 18,
    lineHeight: 1.7,
    fontFamily: "serif",
    paper: "followApp",
    pdfZoom: 1,
    comicLayout: "single",
    comicDirection: "ltr",
  });
  assert.equal(clampFontSize(13.6), 14);
  assert.equal(clampFontSize(28.4), 28);
  assert.equal(clampFontSize(18.4), 18);
  assert.equal(clampFontSize(Number.NaN), 18);
  assert.equal(clampLineHeight(1.36), 1.4);
  assert.equal(clampLineHeight(2.26), 2.2);
  assert.equal(clampLineHeight(1.75), 1.8);
  assert.equal(clampLineHeight(Number.POSITIVE_INFINITY), 1.7);
});

test("a broken reading preference falls back to the default for that field", () => {
  assert.deepEqual(readingPrefsFrom(null), defaultReadingPrefs);
  assert.deepEqual(readingPrefsFrom("nope"), defaultReadingPrefs);
  assert.deepEqual(
    readingPrefsFrom({ fontSize: 40, lineHeight: 0, fontFamily: "comic", paper: "sepia" }),
    { fontSize: 28, lineHeight: 1.4, fontFamily: "serif", paper: "followApp", pdfZoom: 1, comicLayout: "single", comicDirection: "ltr" },
  );
  assert.equal(readingPrefsFrom({ comicLayout: "wide", comicDirection: "sideways" }).comicLayout, "single");
  assert.equal(readingPrefsFrom({ comicLayout: "wide", comicDirection: "sideways" }).comicDirection, "ltr");
  assert.deepEqual(readingPrefsFrom({ fontSize: 16, lineHeight: 2, fontFamily: "mono", paper: "dark", pdfZoom: 2, comicLayout: "vertical", comicDirection: "rtl" }), {
    fontSize: 16,
    lineHeight: 2,
    fontFamily: "mono",
    paper: "dark",
    pdfZoom: 2,
    comicLayout: "vertical",
    comicDirection: "rtl",
  });
});

test("paper follows the requested brightness and keeps this reader's type", () => {
  const light = readingSurface(defaultReadingPrefs, "light");
  assert.equal(light.background, "#F5F0E8");
  assert.equal(light.color, "#2A2620");
  assert.equal(light.dark, false);
  assert.equal(light.cssFontFamily.includes("Georgia"), true);
  const dark = readingSurface({ ...defaultReadingPrefs, paper: "dark", fontFamily: "mono" }, "light");
  assert.equal(dark.background, "#1C1B18");
  assert.equal(dark.color, "#E8E2D6");
  assert.equal(dark.dark, true);
  assert.equal(dark.cssFontFamily.includes("monospace"), true);
  assert.equal(dark.nativeFontFamily, "Courier");
  const followed = readingSurface(defaultReadingPrefs, "dark");
  assert.equal(followed.background, "#1C1B18");
});

test("pdf zoom stays on quarter steps and leaves this book's place alone", async () => {
  assert.equal(clampPdfZoom(0.2), 1);
  assert.equal(clampPdfZoom(5), 3);
  assert.equal(clampPdfZoom(1.6), 1.5);
  assert.equal(clampPdfZoom(Number.NaN), 1);
  assert.equal(readingPrefsFrom({ fontSize: 19, lineHeight: 1.7, fontFamily: "serif", paper: "dark" }).pdfZoom, 1);
  assert.equal(readingPrefsFrom({ pdfZoom: 1.5 }).pdfZoom, 1.5);
  assert.equal(readingPrefsFrom({ pdfZoom: 0 }).pdfZoom, 1);
  const db = memoryDatabase();
  const book = await importShelfBook(db, {
    title: "notes",
    format: "txt",
    bytes: new TextEncoder().encode("hello shelf"),
  });
  await saveReadingPrefs(db, {
    fontSize: 19,
    lineHeight: 1.7,
    fontFamily: "serif",
    paper: "dark",
    pdfZoom: 1.6,
    comicLayout: "double",
    comicDirection: "rtl",
  });
  const loaded = await loadReadingPrefs(db);
  assert.equal(loaded.pdfZoom, 1.5);
  assert.equal(loaded.fontSize, 19);
  assert.equal(loaded.paper, "dark");
  assert.equal(loaded.comicLayout, "double");
  assert.equal(loaded.comicDirection, "rtl");
  const shelf = await loadShelf(db);
  assert.equal(shelf[0]?.id, book.id);
  assert.equal(shelf[0]?.chapterIndex, 0);
});

test("saved reading preferences reload and leave the shelf version and books alone", async () => {
  const db = memoryDatabase();
  assert.deepEqual(await loadReadingPrefs(db), defaultReadingPrefs);
  const book = await importShelfBook(db, {
    title: "notes",
    format: "txt",
    bytes: new TextEncoder().encode("hello shelf"),
  });
  await saveReadingPrefs(db, {
    fontSize: 22,
    lineHeight: 2,
    fontFamily: "sans",
    paper: "light",
    pdfZoom: 1,
    comicLayout: "single",
    comicDirection: "ltr",
  });
  assert.deepEqual(await loadReadingPrefs(db), {
    fontSize: 22,
    lineHeight: 2,
    fontFamily: "sans",
    paper: "light",
    pdfZoom: 1,
    comicLayout: "single",
    comicDirection: "ltr",
  });
  const version = await db.all("PRAGMA user_version");
  assert.equal(version[0]?.user_version, 5);
  const shelf = await loadShelf(db);
  assert.equal(shelf.length, 1);
  assert.equal(shelf[0]?.id, book.id);
  assert.equal(shelf[0]?.chapterIndex, 0);
  await db.run("UPDATE reader_prefs SET payload = ? WHERE id = ?", ["{", "reading"]);
  assert.deepEqual(await loadReadingPrefs(db), defaultReadingPrefs);
  const stored = await db.all("SELECT payload FROM reader_prefs WHERE id = ?", ["reading"]);
  assert.equal(stored[0]?.payload, "{");
});
