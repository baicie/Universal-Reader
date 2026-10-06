import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

import { buildFoliateDocument } from "./foliate-document";
import { hostSource, paginatorSource } from "./foliate-source";

const foliateDir = new URL("../../app/assets/reader/foliate/", import.meta.url);

test("bundled foliate sources match the flutter assets", () => {
  assert.equal(hostSource, readFileSync(new URL("host.html", foliateDir), "utf8"));
  assert.equal(paginatorSource, readFileSync(new URL("paginator.js", foliateDir), "utf8"));
});

test("a chapter document loads the paginator and reports pages to the parent", () => {
  const html = buildFoliateDocument({
    hostSource,
    paginatorSource,
    chapterHtml: "<h1>第一章</h1><p>hello from epub</p>",
    href: "OEBPS/ch1.xhtml",
    pageIndex: 0,
    fragment: null,
  });
  assert.equal(html.includes("import('./paginator.js')"), false);
  assert.match(html, /customElements\.define\('foliate-paginator'/);
  assert.match(html, /window\.parent\.postMessage/);
  assert.match(html, /window\.ReactNativeWebView/);
  assert.match(html, /hello from epub/);
  assert.match(html, /data\.type === 'next'/);
  assert.match(html, /data\.type === 'prev'/);
  assert.match(html, /layoutError/);
  assert.match(html, /target \/ \(pageCount - 1\)/);
  assert.match(html, /lastCommand\._paging/);
});

test("opening the previous chapter asks the paginator for its last page", () => {
  const html = buildFoliateDocument({
    hostSource,
    paginatorSource,
    chapterHtml: "<p>second chapter text</p>",
    href: "OEBPS/ch2.xhtml",
    pageIndex: -1,
    fragment: "note",
  });
  assert.match(html, /"pageIndex":-1/);
  assert.match(html, /"fragment":"note"/);
  assert.match(html, /index < 0/);
  assert.match(html, /anchor: 1/);
  assert.equal(html.includes('"quotes"'), false);
});

test("a chapter command carries only the quotes it was given", () => {
  const html = buildFoliateDocument({
    hostSource,
    paginatorSource,
    chapterHtml: "<p>hello from epub</p>",
    href: "OEBPS/ch1.xhtml",
    pageIndex: 0,
    fragment: null,
    quotes: ["hello from epub"],
  });
  assert.match(html, /"quotes":\["hello from epub"\]/);
  assert.equal(html.includes("hello shelf"), false);
  assert.match(html, /__selectionWatch/);
});

test("a chapter command keeps the reading surface it was given", () => {
  const html = buildFoliateDocument({
    hostSource,
    paginatorSource,
    chapterHtml: "<p>hello from epub</p>",
    href: "OEBPS/ch1.xhtml",
    pageIndex: 0,
    fragment: null,
    fontSize: 22,
    lineHeight: 2,
    fontFamily: "ui-monospace, monospace",
    background: "#1C1B18",
    color: "#E8E2D6",
  });
  assert.match(html, /"fontSize":22/);
  assert.match(html, /"lineHeight":2/);
  assert.match(html, /"fontFamily":"ui-monospace, monospace"/);
  assert.match(html, /"background":"#1C1B18"/);
  assert.match(html, /"color":"#E8E2D6"/);
  assert.equal(html.includes("hello shelf"), false);
});
