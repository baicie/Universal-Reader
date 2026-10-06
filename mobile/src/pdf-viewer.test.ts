import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

import { pdfjsSource, pdfWorkerSource } from "./pdfjs-source";
import { buildPdfViewer } from "./pdf-viewer";

test("bundled pdf.js matches the installed package", () => {
  const build = new URL("../node_modules/pdfjs-dist/build/", import.meta.url);
  assert.equal(pdfjsSource, readFileSync(new URL("pdf.min.mjs", build), "utf8"));
  assert.equal(pdfWorkerSource, readFileSync(new URL("pdf.worker.min.mjs", build), "utf8"));
});

test("a pdf viewer draws this file and can report failure", () => {
  const bytes = new TextEncoder().encode("%PDF-1.1\n");
  const html = buildPdfViewer({ pdfjsSource, pdfWorkerSource, bytes, pageIndex: 1 });
  assert.match(html, /getDocument/);
  assert.match(html, /WorkerMessageHandler/);
  assert.match(html, /window\.parent\.postMessage/);
  assert.match(html, /ReactNativeWebView/);
  assert.match(html, /type: "failed"/);
  assert.match(html, /getTextContent\(\)/);
  assert.match(html, /type: "text", pageIndex: pageNumber/);
  assert.match(html, /"pageIndex":1/);
  assert.match(html, /isEvalSupported:\s*false/);
  assert.match(html, /function pdfQuoteBoxes/);
  assert.match(html, /className = "note"/);
  assert.match(html, /data\.type === "quotes"/);
  assert.match(html, /id="text"/);
  assert.match(html, /function paintTextLayer/);
  assert.match(html, /type: "selection", text: text/);
  assert.match(html, /var pageZoom = 1;/);
  assert.match(html, /fitted \* pageZoom/);
  assert.match(html, /data\.type === "zoom"[\s\S]{0,180}show\(current\)/);
  assert.match(html, /await page\.render\(params\)\.promise;[\s\S]*notes\.replaceChildren\(\);[\s\S]*paintQuotes\(\);/);
  const zoomed = buildPdfViewer({ pdfjsSource, pdfWorkerSource, bytes, pageIndex: 1, zoom: 1.6 });
  assert.match(zoomed, /var pageZoom = 1\.5;/);
  assert.equal(html.includes("zinc chapter marker"), false);
  assert.equal(/<script[^>]+src=["']https?:/.test(html), false);
  assert.match(html, /JVBERi0xLjEK/);
});
