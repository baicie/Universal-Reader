import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

import { isPdfName, openPdfDocument, pdfQuoteBoxes, readPdfFailure, readPdfPageText, searchPdf, textForReportedPage, turnPdfPage } from "./pdf-document";

const books = new URL("../../test-books/pdf/", import.meta.url);

test("empty pdf bytes stay unavailable and other bytes stay corrupt", () => {
  assert.equal(openPdfDocument(null).kind, "unavailable");
  assert.equal(openPdfDocument(new Uint8Array()).kind, "unavailable");
  assert.equal(openPdfDocument(Uint8Array.from([0xff])).kind, "corrupt");
  assert.equal(openPdfDocument(Uint8Array.from([1, 2, 3])).kind, "corrupt");
  assert.equal(openPdfDocument(new TextEncoder().encode("not a pdf")).kind, "corrupt");
});

test("a pdf header can be opened, including one after leading spaces", () => {
  const header = openPdfDocument(new TextEncoder().encode("%PDF-1.1\n"));
  assert.equal(header.kind, "pdf");
  const spaced = openPdfDocument(Uint8Array.from([0x20, 0x20, 0x20, 0x20, 0x25, 0x50, 0x44, 0x46, 0x2d]));
  assert.equal(spaced.kind, "pdf");
  assert.equal(openPdfDocument(readFileSync(new URL("minimal.pdf", books))).kind, "pdf");
  assert.equal(openPdfDocument(readFileSync(new URL("edge-leading-space.pdf", books))).kind, "pdf");
});

test("pdf names are recognized without treating other extensions as pdf", () => {
  assert.equal(isPdfName("Scan.PDF"), true);
  assert.equal(isPdfName("notes.pdf.txt"), false);
  assert.equal(isPdfName("chapter.epub"), false);
});

test("pdf page turns stay inside this file", () => {
  assert.equal(turnPdfPage(0, 3, "next"), 1);
  assert.equal(turnPdfPage(2, 3, "next"), 2);
  assert.equal(turnPdfPage(0, 0, "next"), 0);
  assert.equal(turnPdfPage(0, 3, "prev"), 0);
  assert.equal(turnPdfPage(2, 3, "prev"), 1);
});

test("search stays inside this pdf and returns one hit per matching page", () => {
  const bytes = minimalPdfBytes(["alpha content", "beta content", "alpha again"]);
  const hits = searchPdf(bytes, "alpha");
  assert.deepEqual(
    hits.map((hit) => hit.pageIndex),
    [0, 2],
  );
  assert.equal(hits.every((hit) => hit.excerpt.includes("alpha")), true);
  assert.equal(hits.some((hit) => hit.excerpt.includes("beta content")), false);
  assert.deepEqual(searchPdf(bytes, ""), []);
  assert.deepEqual(searchPdf(bytes, "   "), []);
  assert.deepEqual(searchPdf(bytes, "zzz-not-here"), []);
  assert.deepEqual(searchPdf(new TextEncoder().encode("only in the other book"), "only in the other book"), []);
});

test("search keeps the first ten matching pages", () => {
  const hits = searchPdf(
    minimalPdfBytes(Array.from({ length: 11 }, () => "marker")),
    "marker",
  );
  assert.equal(hits.length, 10);
  assert.equal(hits[9]?.pageIndex, 9);
});

test("search reads escaped page text and splits several strings across pages", () => {
  const escaped = searchPdf(minimalPdfBytes(["line1\nline2\twith\\slash and(paren)"]), "(paren)");
  assert.equal(escaped.length, 1);
  assert.equal(escaped[0]?.excerpt.includes("(paren)"), true);
  assert.equal(escaped[0]?.excerpt.includes("\\slash"), true);

  const split = searchPdf(
    minimalPdfBytes(["p1", "p2"], [
      ["a", "b", "c"],
      ["d", "e", "f"],
    ]),
    "b",
  );
  assert.deepEqual(
    split.map((hit) => hit.pageIndex),
    [0],
  );
  assert.equal(split[0]?.excerpt.includes("a b c"), true);
  assert.equal(split[0]?.excerpt.includes("d e f"), false);
});

test("a pdf without page text and the shared sample stay on their own words", () => {
  assert.deepEqual(searchPdf(new TextEncoder().encode("%PDF-1.1\n"), "hello from pdf"), []);
  assert.deepEqual(searchPdf(minimalPdfBytes(["   "]), "hello from pdf"), []);
  const spaced = Uint8Array.from([0x20, 0x20, 0x20, 0x20, ...minimalPdfBytes(["after leading space"])]);
  assert.equal(searchPdf(spaced, "after leading space")[0]?.pageIndex, 0);
  const sample = searchPdf(readFileSync(new URL("minimal.pdf", books)), "hello from pdf");
  assert.deepEqual(
    sample.map((hit) => hit.pageIndex),
    [0],
  );
  assert.equal(sample[0]?.excerpt.includes("hello from pdf"), true);
  assert.deepEqual(searchPdf(readFileSync(new URL("minimal.pdf", books)), "zinc chapter marker"), []);
});

function minimalPdfBytes(pages: string[], stringsPerPage?: string[][]): Uint8Array {
  const perPage = stringsPerPage ?? pages.map((page) => [page]);
  const objects = ["1 0 obj << /Type /Catalog /Pages 2 0 R >> endobj"];
  const kids = pages.map((_, index) => `${3 + index * 2} 0 R`).join(" ");
  objects.push(`2 0 obj << /Type /Pages /Kids [${kids}] /Count ${pages.length} >> endobj`);
  for (let index = 0; index < pages.length; index += 1) {
    const pageObject = 3 + index * 2;
    const contentObject = pageObject + 1;
    const stream = (perPage[index] ?? [])
      .map((raw) => {
        const text = raw.replaceAll("\\", "\\\\").replaceAll("(", "\\(").replaceAll(")", "\\)");
        return `BT /F1 12 Tf 72 720 Td (${text}) Tj ET`;
      })
      .join("\n");
    objects.push(
      `${pageObject} 0 obj << /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents ${contentObject} 0 R /Resources << /Font << /F1 ${3 + pages.length * 2} 0 R >> >> >> endobj`,
    );
    objects.push(`${contentObject} 0 obj << /Length ${stream.length} >> stream\n${stream}\nendstream endobj`);
  }
  const fontObject = 3 + pages.length * 2;
  objects.push(`${fontObject} 0 obj << /Type /Font /Subtype /Type1 /BaseFont /Helvetica >> endobj`);
  let source = "%PDF-1.1\n";
  const offsets: number[] = [];
  for (const object of objects) {
    offsets.push(source.length);
    source += `${object}\n`;
  }
  const xrefAt = source.length;
  source += `xref\n0 ${objects.length + 1}\n0000000000 65535 f \n`;
  for (const offset of offsets) source += `${String(offset).padStart(10, "0")} 00000 n \n`;
  source += `trailer << /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n${xrefAt}\n%%EOF`;
  return new TextEncoder().encode(source);
}

test("a quote on this page becomes a box and a missing quote adds nothing", () => {
  const item = { str: "abcdef", x: 0, y: 4, width: 60, height: 12 };
  assert.deepEqual(pdfQuoteBoxes([item], ["cd"]), [{ x: 20, y: 4, width: 20, height: 12 }]);
  assert.deepEqual(pdfQuoteBoxes([item], ["zinc chapter marker"]), []);
  assert.deepEqual(pdfQuoteBoxes([item], ["", "   "]), []);
  assert.deepEqual(pdfQuoteBoxes([{ ...item, width: 0 }], ["cd"]), []);
});

test("the longer quote wins and a quote can cross text runs", () => {
  const item = { str: "needle", x: 0, y: 0, width: 60, height: 10 };
  assert.deepEqual(pdfQuoteBoxes([item], ["ne", "needle"]), [{ x: 0, y: 0, width: 60, height: 10 }]);
  const boxes = pdfQuoteBoxes(
    [
      { str: "ab", x: 0, y: 8, width: 20, height: 10 },
      { str: "cd", x: 20, y: 8, width: 20, height: 10, hasEOL: true },
    ],
    ["bc"],
  );
  assert.deepEqual(boxes, [
    { x: 10, y: 8, width: 10, height: 10 },
    { x: 20, y: 8, width: 10, height: 10 },
  ]);
  assert.deepEqual(
    pdfQuoteBoxes(
      [
        { str: "ab", x: 0, y: 0, width: 20, height: 10, hasEOL: true },
        { str: "cd", x: 0, y: 20, width: 20, height: 10 },
      ],
      ["bc"],
    ),
    [],
  );
});

test("a viewer failure is a failure and a page report is not", () => {
  assert.equal(readPdfFailure({ type: "failed" }), true);
  assert.equal(readPdfFailure('{"type":"failed"}'), true);
  assert.equal(readPdfFailure({ type: "relocated", pageIndex: 0, pageCount: 2 }), false);
  assert.equal(readPdfFailure("not json"), false);
});

test("a page text report is only that page's text", () => {
  assert.deepEqual(readPdfPageText({ type: "text", pageIndex: 1, text: "second page text" }), {
    pageIndex: 1,
    text: "second page text",
  });
  assert.deepEqual(readPdfPageText('{"type":"text","pageIndex":0,"text":"first page text"}'), {
    pageIndex: 0,
    text: "first page text",
  });
  assert.deepEqual(readPdfPageText({ type: "text", pageIndex: 0, text: "" }), {
    pageIndex: 0,
    text: "",
  });
  assert.equal(readPdfPageText({ type: "relocated", pageIndex: 0, pageCount: 2 }), null);
  assert.equal(readPdfPageText({ type: "text", pageIndex: 0 }), null);
  assert.equal(readPdfPageText({ type: "failed" }), null);

  const first = readPdfPageText({ type: "text", pageIndex: 0, text: "first page text" });
  assert.equal(textForReportedPage(first, 1), "");
  assert.equal(textForReportedPage(first, 0), "first page text");
  assert.equal(textForReportedPage(readPdfPageText({ type: "text", pageIndex: 1, text: "" }), 1), "");
  assert.equal(textForReportedPage(null, 0), "");
});
