import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import { strToU8, zipSync } from "fflate";

import { comicPageImage, comicPageUri, openComicDocument } from "./comic-document";

const png = Uint8Array.from([
  0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00, 0x00, 0x00, 0x0d, 0x49, 0x48, 0x44,
  0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1f,
  0x15, 0xc4, 0x89, 0x00, 0x00, 0x00, 0x0a, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9c, 0x63, 0x00,
  0x01, 0x00, 0x00, 0x05, 0x00, 0x01, 0x0d, 0x0a, 0x2d, 0xb4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4e, 0x44, 0xae, 0x42, 0x60, 0x82,
]);

function zip(files: Record<string, Uint8Array>): Uint8Array {
  return zipSync(files);
}

test("empty comic bytes stay unavailable and a broken cbz stays corrupt", async () => {
  assert.equal((await openComicDocument("book.cbz", null)).kind, "unavailable");
  assert.equal((await openComicDocument("book.cbz", new Uint8Array())).kind, "unavailable");
  assert.equal((await openComicDocument("book.cbz", Uint8Array.from([0xff]))).kind, "corrupt");
  assert.equal((await openComicDocument("book.cbz", zip({ "readme.txt": strToU8("notes") }))).kind, "corrupt");
});

test("a cbz opens image pages in case-insensitive name order", async () => {
  const opened = await openComicDocument(
    "Pages.CBZ",
    zip({
      "Page-02.png": png,
      "dir/page-01.jpg": png,
      "readme.txt": strToU8("skip"),
      "__MACOSX/._page-01.jpg": png,
      ".hidden.png": png,
    }),
  );
  assert.equal(opened.kind, "comic");
  if (opened.kind !== "comic") return;
  assert.equal(opened.format, "cbz");
  assert.deepEqual(
    opened.pages.map((page) => page.name),
    ["page-01.jpg", "Page-02.png"],
  );
  assert.equal(comicPageUri(opened.pages[0]).startsWith("data:image/jpeg;base64,"), true);
  assert.equal(comicPageUri(opened.pages[1]).startsWith("data:image/png;base64,"), true);
});

test("a backslash path keeps only the image file name", async () => {
  const opened = await openComicDocument("nested.cbz", zip({ "subdir\\page-01.jpg": png }));
  assert.equal(opened.kind, "comic");
  if (opened.kind !== "comic") return;
  assert.equal(opened.pages[0]?.name, "page-01.jpg");
});

test("cbr and cb7 stay unsupported instead of borrowing another archive", async () => {
  const cbz = zip({ "page-01.png": png });
  assert.equal((await openComicDocument("book.cbr", cbz)).kind, "unsupported");
  assert.equal((await openComicDocument("book.cb7", cbz)).kind, "unsupported");
  assert.equal((await openComicDocument("notes.txt", cbz)).kind, "unsupported");
  assert.equal((await openComicDocument("book.cbr", Uint8Array.from([0x52, 0x61, 0x72, 0x21, 0x1a, 0x07, 0x01]))).kind, "corrupt");
  assert.equal((await openComicDocument("book.cb7", Uint8Array.from([0x37, 0x7a, 0xbc, 0xaf, 0x27]))).kind, "corrupt");
});

test("a comic page image uses that page's own bytes", () => {
  const page = { name: "page-01.png", bytes: png };
  const image = comicPageImage(page);
  assert.equal(image.alt, "page-01.png");
  assert.equal(image.src, comicPageUri(page));
  const encoded = image.src.slice("data:image/png;base64,".length);
  assert.deepEqual(Uint8Array.from(Buffer.from(encoded, "base64")), png);
});

test("the shared cbr and cb7 samples open their own pictures", async () => {
  const cbr = await openComicDocument(
    "minimal.cbr",
    readFileSync(new URL("../../test-books/cbr/minimal.cbr", import.meta.url)),
  );
  const cb7 = await openComicDocument(
    "minimal.cb7",
    readFileSync(new URL("../../test-books/cb7/minimal.cb7", import.meta.url)),
  );
  assert.equal(cbr.kind, "comic");
  assert.equal(cb7.kind, "comic");
  if (cbr.kind !== "comic" || cb7.kind !== "comic") return;
  assert.equal(cbr.format, "cbr");
  assert.equal(cb7.format, "cb7");
  assert.deepEqual(
    cbr.pages.map((page) => page.name),
    ["page001.png", "page002.png", "page003.png"],
  );
  assert.deepEqual(
    cb7.pages.map((page) => page.name),
    ["page001.png", "page002.png", "page003.png"],
  );
  assert.equal(cbr.pages[0]?.bytes[0], 0x89);
  assert.equal(cb7.pages[0]?.bytes[0], 0x89);
  assert.notDeepEqual(cbr.pages[0]?.bytes, png);
  assert.notDeepEqual(cb7.pages[0]?.bytes, png);
  const cbrImage = comicPageImage(cbr.pages[0]);
  const cb7Image = comicPageImage(cb7.pages[0]);
  assert.equal(cbrImage.alt, "page001.png");
  assert.equal(cb7Image.alt, "page001.png");
  assert.ok(cbrImage.src.length > 1000);
  assert.ok(cb7Image.src.length > 1000);
  assert.deepEqual(
    Uint8Array.from(Buffer.from(cbrImage.src.slice("data:image/png;base64,".length), "base64")),
    cbr.pages[0].bytes,
  );
  assert.deepEqual(
    Uint8Array.from(Buffer.from(cb7Image.src.slice("data:image/png;base64,".length), "base64")),
    cb7.pages[0].bytes,
  );
});

test("the shared cbz and cbt samples open their own pictures", async () => {
  const cbz = await openComicDocument(
    "minimal.cbz",
    readFileSync(new URL("../../test-books/cbz/minimal.cbz", import.meta.url)),
  );
  const cbt = await openComicDocument(
    "minimal.cbt",
    readFileSync(new URL("../../test-books/cbt/minimal.cbt", import.meta.url)),
  );
  assert.equal(cbz.kind, "comic");
  assert.equal(cbt.kind, "comic");
  if (cbz.kind !== "comic" || cbt.kind !== "comic") return;
  assert.ok(cbz.pages.length > 0);
  assert.ok(cbt.pages.length > 0);
  assert.equal(cbt.format, "cbt");
});
