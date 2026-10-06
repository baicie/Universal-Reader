import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import { zipSync } from "fflate";

import { odtTextCharLimit, openOdtDocument } from "./odt-document";

const encoder = new TextEncoder();
const odtMime = "application/vnd.oasis.opendocument.text";

function odt(files: Record<string, string>): Uint8Array {
  const entries: Record<string, Uint8Array> = {};
  for (const [name, text] of Object.entries(files)) entries[name] = encoder.encode(text);
  return zipSync(entries);
}

function content(body: string): string {
  return `<?xml version="1.0" encoding="UTF-8"?>
<office:document-content xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0" xmlns:xlink="http://www.w3.org/1999/xlink">
  <office:body><office:text>${body}</office:text></office:body>
</office:document-content>`;
}

function meta(title: string, creator: string, initial = ""): string {
  return `<?xml version="1.0" encoding="UTF-8"?>
<office:document-meta xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:meta="urn:oasis:names:tc:opendocument:xmlns:meta:1.0">
  <office:meta><dc:title>${title}</dc:title><dc:creator>${creator}</dc:creator><meta:initial-creator>${initial}</meta:initial-creator></office:meta>
</office:document-meta>`;
}

function book(body: string, files: Record<string, string> = {}): Uint8Array {
  return odt({ mimetype: odtMime, "content.xml": content(body), ...files });
}

test("empty odt bytes stay unavailable and a broken file stays corrupt", () => {
  assert.equal(openOdtDocument(null).kind, "unavailable");
  assert.equal(openOdtDocument(new Uint8Array()).kind, "unavailable");
  assert.equal(openOdtDocument(Uint8Array.from([1, 2, 3])).kind, "corrupt");
  assert.equal(openOdtDocument(odt({ "content.xml": content("<text:p>Hello</text:p>") })).kind, "corrupt");
  assert.equal(
    openOdtDocument(odt({ mimetype: "application/vnd.oasis.opendocument.spreadsheet", "content.xml": content("<text:p>Hello</text:p>") })).kind,
    "corrupt",
  );
  assert.equal(openOdtDocument(book("")).kind, "corrupt");
  assert.equal(
    openOdtDocument(
      odt({
        mimetype: odtMime,
        "content.xml": `<?xml version="1.0"?><office:document-content xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0"><office:body><office:spreadsheet/></office:body></office:document-content>`,
      }),
    ).kind,
    "corrupt",
  );
  const opened = openOdtDocument(book("<text:p>Hello</text:p>", { mimetype: `${odtMime}\n` }));
  assert.equal(opened.kind, "odt");
  if (opened.kind !== "odt") return;
  assert.equal(opened.document.title, "");
  assert.equal(opened.document.currentChapterText, "Hello");
});

test("the shared odt samples open their own chapters", () => {
  const minimal = openOdtDocument(readFileSync(new URL("../../test-books/odt/minimal.odt", import.meta.url)));
  const cjk = openOdtDocument(readFileSync(new URL("../../test-books/odt/edge-cjk.odt", import.meta.url)));
  assert.equal(minimal.kind, "odt");
  assert.equal(cjk.kind, "odt");
  if (minimal.kind !== "odt" || cjk.kind !== "odt") return;
  assert.equal(minimal.document.title, "ODT Compatibility Book");
  assert.equal(minimal.document.author, "Libre Writer");
  assert.equal(cjk.document.title, "开放文档样本");
  assert.equal(cjk.document.author, "测试作者");
  assert.equal(minimal.document.chapterCount, 2);
  assert.equal(minimal.document.truncated, false);
  assert.equal(minimal.document.currentChapterTitle, "Chapter One");
  const first = minimal.document.currentChapterText;
  assert.equal(
    first,
    [
      "Hello bold and italic and strong underline.",
      "- First item\n- Second item",
      "Key\tValue\nFormat\tODT",
      "External link",
    ].join("\n\n"),
  );
  assert.equal(first.includes("https://example.com"), false);
  assert.equal(first.includes("开放文档样本"), false);
  minimal.document.next();
  assert.equal(minimal.document.currentChapterTitle, "Chapter Two");
  assert.equal(minimal.document.currentChapterText, "Second chapter body.");
  minimal.document.next();
  assert.equal(minimal.document.currentChapterText, "Second chapter body.");
  assert.equal(cjk.document.currentChapterTitle, "第一章");
  assert.equal(cjk.document.currentChapterText.includes("ODT Compatibility Book"), false);
  cjk.document.next();
  assert.equal(cjk.document.currentChapterTitle, "第二章");
});

test("a heading style, spaces, a line break, and a note stay in this chapter", () => {
  const opened = openOdtDocument(
    book(`
      <text:h text:style-name="Heading_20_1">Styled</text:h>
      <text:p>A<text:s text:c="3"/>B<text:line-break/>C</text:p>
      <text:p>visible<text:note><text:note-body><text:p>secret note</text:p></text:note-body></text:note></text:p>
      <text:section><text:h text:outline-level="3">Sub</text:h></text:section>
      <text:h text:style-name="Heading_20_3">Deep</text:h>
    `),
  );
  assert.equal(opened.kind, "odt");
  if (opened.kind !== "odt") return;
  assert.equal(opened.document.chapterCount, 1);
  assert.equal(opened.document.currentChapterTitle, "Styled");
  assert.equal(opened.document.currentChapterText, "A   B\nC\n\nvisible\n\nSub\n\nDeep");
  assert.equal(opened.document.currentChapterText.includes("secret note"), false);
});

test("an initial creator names the book when creator is absent", () => {
  const opened = openOdtDocument(
    book("<text:p>Hello</text:p>", {
      "meta.xml": `<?xml version="1.0"?>
<office:document-meta xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" xmlns:meta="urn:oasis:names:tc:opendocument:xmlns:meta:1.0">
  <office:meta><meta:initial-creator>Op Name</meta:initial-creator></office:meta>
</office:document-meta>`,
    }),
  );
  assert.equal(opened.kind, "odt");
  if (opened.kind !== "odt") return;
  assert.equal(opened.document.title, "");
  assert.equal(opened.document.author, "Op Name");
  const named = openOdtDocument(book("<text:p>Hello</text:p>", { "meta.xml": meta("Book", "Ada", "Other") }));
  assert.equal(named.kind, "odt");
  if (named.kind !== "odt") return;
  assert.equal(named.document.title, "Book");
  assert.equal(named.document.author, "Ada");
});

test("search stays inside this odt", () => {
  const opened = openOdtDocument(
    book(`
      <text:h text:outline-level="1">One</text:h>
      <text:p>alpha marker</text:p>
      <text:h text:outline-level="2">Two</text:h>
      <text:p>beta marker</text:p>
    `),
  );
  assert.equal(opened.kind, "odt");
  if (opened.kind !== "odt") return;
  assert.deepEqual(opened.document.search("  "), []);
  const hits = opened.document.search("beta marker");
  assert.equal(hits.length, 1);
  assert.equal(hits[0]?.chapterIndex, 1);
  assert.equal(hits[0]?.excerpt.includes("alpha marker"), false);
  opened.document.moveTo(hits[0]?.chapterIndex ?? 0);
  assert.equal(opened.document.currentChapterText, "beta marker");
  const many = openOdtDocument(
    book(
      Array.from(
        { length: 11 },
        (_, index) =>
          `<text:h text:outline-level="1">Chapter ${index}</text:h><text:p>hit ${index}</text:p>`,
      ).join(""),
    ),
  );
  assert.equal(many.kind, "odt");
  if (many.kind !== "odt") return;
  assert.equal(many.document.search("hit").length, 10);
});

test("a chapter past the character limit is cut and the rest is not shown", () => {
  const opened = openOdtDocument(book(`<text:p>${"a".repeat(odtTextCharLimit + 8)}</text:p>`));
  assert.equal(opened.kind, "odt");
  if (opened.kind !== "odt") return;
  assert.equal(opened.document.truncated, true);
  assert.equal(opened.document.currentChapterText.length, odtTextCharLimit);
  assert.equal(opened.document.chapterCount, 1);
});
