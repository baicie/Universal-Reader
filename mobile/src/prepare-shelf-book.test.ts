import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

import { prepareShelfBook } from "./prepare-shelf-book";

const encoder = new TextEncoder();

test("a text file becomes a shelf book and an unreadable file does not", async () => {
  const notes = await prepareShelfBook("my book.txt", encoder.encode("hello shelf"));
  assert.equal(notes?.format, "txt");
  assert.equal(notes?.title, "my book");
  assert.equal(notes?.author, "");
  assert.equal(await prepareShelfBook("picture.cbr", encoder.encode("not a comic")), null);
  assert.equal(await prepareShelfBook("empty.txt", new Uint8Array()), null);
  assert.equal(await prepareShelfBook("pages.pdf", encoder.encode("not a pdf")), null);
  assert.equal(await prepareShelfBook("broken.epub", Uint8Array.from([1, 2, 3])), null);
  assert.equal(await prepareShelfBook("broken.fb2", encoder.encode("not fb2")), null);
  assert.equal(await prepareShelfBook("broken.rtf", encoder.encode("not rtf")), null);
  assert.equal(await prepareShelfBook("broken.docx", encoder.encode("not docx")), null);
  assert.equal(await prepareShelfBook("broken.odt", encoder.encode("not odt")), null);
  assert.equal(await prepareShelfBook("broken.mobi", encoder.encode("not mobi")), null);
  assert.equal(await prepareShelfBook("broken.azw3", encoder.encode("not azw3")), null);
  assert.equal(await prepareShelfBook("broken.chm", encoder.encode("not chm")), null);
  assert.equal(await prepareShelfBook("broken.djvu", encoder.encode("not djvu")), null);
  const fb2 = await prepareShelfBook(
    "ignored.fb2",
    readFileSync(new URL("../../test-books/fb2/minimal.fb2", import.meta.url)),
  );
  assert.equal(fb2?.format, "fb2");
  assert.equal(fb2?.title, "FB2 Book");
  assert.equal(fb2?.author, "Ann Author");
  assert.equal(fb2?.cover, null);
  const rtf = await prepareShelfBook(
    "ignored.rtf",
    readFileSync(new URL("../../test-books/rtf/minimal.rtf", import.meta.url)),
  );
  assert.equal(rtf?.format, "rtf");
  assert.equal(rtf?.title, "RTF Compatibility Book");
  assert.equal(rtf?.author, "Rich Text");
  assert.equal(rtf?.cover, null);
  const docx = await prepareShelfBook(
    "ignored.docx",
    readFileSync(new URL("../../test-books/docx/minimal.docx", import.meta.url)),
  );
  assert.equal(docx?.format, "docx");
  assert.equal(docx?.title, "DOCX Compatibility Book");
  assert.equal(docx?.author, "Ada Reader");
  assert.equal(docx?.cover, null);
  const odt = await prepareShelfBook(
    "ignored.odt",
    readFileSync(new URL("../../test-books/odt/minimal.odt", import.meta.url)),
  );
  assert.equal(odt?.format, "odt");
  assert.equal(odt?.title, "ODT Compatibility Book");
  assert.equal(odt?.author, "Libre Writer");
  assert.equal(odt?.cover, null);
  const mobi = await prepareShelfBook(
    "ignored.mobi",
    readFileSync(new URL("../../test-books/mobi/minimal.mobi", import.meta.url)),
  );
  assert.equal(mobi?.format, "mobi");
  assert.equal(mobi?.title, "ignored");
  assert.equal(mobi?.cover, null);
  const azw3 = await prepareShelfBook(
    "sample.azw3",
    readFileSync(new URL("../../test-books/azw3/minimal.azw3", import.meta.url)),
  );
  assert.equal(azw3?.format, "azw3");
  assert.equal(azw3?.title, "sample");
  assert.equal(azw3?.cover, null);
  const chm = await prepareShelfBook(
    "ignored.chm",
    readFileSync(new URL("../../test-books/chm/minimal.chm", import.meta.url)),
  );
  assert.equal(chm?.format, "chm");
  assert.equal(chm?.title, "rustchm basic test");
  assert.equal(chm?.cover, null);
  const djvu = await prepareShelfBook(
    "ignored.djvu",
    readFileSync(new URL("../../test-books/djvu/minimal.djvu", import.meta.url)),
  );
  assert.equal(djvu?.format, "djvu");
  assert.equal(djvu?.title, "ignored");
  assert.equal(djvu?.cover?.[0], 0x89);
  const djv = await prepareShelfBook(
    "notes.djv",
    readFileSync(new URL("../../test-books/djvu/minimal.djvu", import.meta.url)),
  );
  assert.equal(djv?.format, "djvu");
});
