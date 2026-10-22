import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

import { readChmFromBytes } from "./chm-bytes.native";
import { openComicDocument } from "./comic-document";
import { openDjvuDocument } from "./djvu-document";

function sample(format: string): Uint8Array {
  return new Uint8Array(readFileSync(new URL(`../../test-books/${format}/minimal.${format}`, import.meta.url)));
}

test("the native CHM entry reads the shared sample with the in-memory JavaScript decoder", async () => {
  const opened = await readChmFromBytes(sample("chm"));
  assert.ok(opened);
  assert.equal(opened.title, "rustchm basic test");
  assert.equal(opened.chapters.length, 2);
  assert.equal(opened.chapters[0]?.title, "Alpha Page");
  assert.ok(opened.chapters[0]?.body.includes("The quick brown fox jumps over the lazy dog."));
  assert.equal(opened.chapters[1]?.title, "Beta Page");
});

test("without WebAssembly, compressed formats are unsupported while CHM and stored comics still open", async () => {
  const descriptor = Object.getOwnPropertyDescriptor(globalThis, "WebAssembly");
  assert.ok(descriptor);
  Object.defineProperty(globalThis, "WebAssembly", { ...descriptor, value: undefined });
  try {
    assert.equal((await openDjvuDocument(sample("djvu"))).kind, "unsupported");
    assert.equal((await openComicDocument("minimal.cbr", sample("cbr"))).kind, "unsupported");
    assert.equal((await openComicDocument("minimal.cb7", sample("cb7"))).kind, "unsupported");
    assert.equal((await openComicDocument("minimal.cbz", sample("cbz"))).kind, "comic");
    assert.equal((await openComicDocument("minimal.cbt", sample("cbt"))).kind, "comic");
    assert.equal((await readChmFromBytes(sample("chm")))?.chapters.length, 2);
    assert.equal((await openDjvuDocument(Uint8Array.of(1, 2, 3))).kind, "corrupt");
    assert.equal((await openComicDocument("invalid.cbr", Uint8Array.of(1, 2, 3))).kind, "corrupt");
    assert.equal((await openComicDocument("invalid.cb7", Uint8Array.of(1, 2, 3))).kind, "corrupt");
  } finally {
    Object.defineProperty(globalThis, "WebAssembly", descriptor);
  }
});
