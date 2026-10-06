import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

import { unzlibSync } from "fflate";

import { openDjvuDocument } from "./djvu-document";

test("empty djvu bytes stay unavailable and a file that is not DjVu stays corrupt", async () => {
  assert.equal((await openDjvuDocument(null)).kind, "unavailable");
  assert.equal((await openDjvuDocument(new Uint8Array())).kind, "unavailable");
  assert.equal((await openDjvuDocument(Uint8Array.from([1, 2, 3, 4]))).kind, "corrupt");
  const form = new Uint8Array(16);
  form.set([0x41, 0x54, 0x26, 0x54, 0x46, 0x4f, 0x52, 0x4d], 0);
  assert.equal((await openDjvuDocument(form)).kind, "corrupt");
});

test("the shared djvu sample opens its own page", async () => {
  const bytes = new Uint8Array(readFileSync(new URL("../../test-books/djvu/minimal.djvu", import.meta.url)));
  const opened = await openDjvuDocument(bytes);
  assert.equal(opened.kind, "djvu");
  if (opened.kind !== "djvu") return;
  assert.equal(opened.pages.length, 1);
  assert.equal(opened.pages[0]?.name, "page-001.png");
  const page = rgbaFromPng(opened.pages[0]?.bytes ?? new Uint8Array());
  assert.equal(page.width, 1024);
  assert.equal(page.height, 1024);
  const counts = countPixels(page.pixels);
  assert.equal(counts.white, 266850);
  assert.equal(counts.black, 781726);
  assert.equal(counts.other, 0);
  assert.equal(bytes[0], 0x41);
});

function rgbaFromPng(png: Uint8Array): { width: number; height: number; pixels: Uint8Array } {
  assert.equal(png[0], 0x89);
  assert.equal(png[1], 0x50);
  let offset = 8;
  let width = 0;
  let height = 0;
  const idat: Uint8Array[] = [];
  while (offset + 8 <= png.length) {
    const length = readU32(png, offset);
    const type = String.fromCharCode(png[offset + 4] ?? 0, png[offset + 5] ?? 0, png[offset + 6] ?? 0, png[offset + 7] ?? 0);
    const data = png.subarray(offset + 8, offset + 8 + length);
    if (type === "IHDR") {
      width = readU32(data, 0);
      height = readU32(data, 4);
      assert.equal(data[8], 8);
      assert.equal(data[9], 6);
    }
    if (type === "IDAT") idat.push(data);
    offset += 12 + length;
    if (type === "IEND") break;
  }
  const compressed = new Uint8Array(idat.reduce((sum, chunk) => sum + chunk.length, 0));
  let at = 0;
  for (const chunk of idat) {
    compressed.set(chunk, at);
    at += chunk.length;
  }
  const raw = unzlibSync(compressed);
  const pixels = new Uint8Array(width * height * 4);
  const stride = width * 4;
  for (let y = 0; y < height; y += 1) {
    assert.equal(raw[y * (stride + 1)], 0);
    pixels.set(raw.subarray(y * (stride + 1) + 1, y * (stride + 1) + 1 + stride), y * stride);
  }
  return { width, height, pixels };
}

function countPixels(pixels: Uint8Array): { white: number; black: number; other: number } {
  let white = 0;
  let black = 0;
  let other = 0;
  for (let index = 0; index < pixels.length; index += 4) {
    const red = pixels[index];
    const green = pixels[index + 1];
    const blue = pixels[index + 2];
    const alpha = pixels[index + 3];
    if (red === 255 && green === 255 && blue === 255 && alpha === 255) white += 1;
    else if (red === 0 && green === 0 && blue === 0 && alpha === 255) black += 1;
    else other += 1;
  }
  return { white, black, other };
}

function readU32(bytes: Uint8Array, offset: number): number {
  return ((bytes[offset] ?? 0) << 24) | ((bytes[offset + 1] ?? 0) << 16) | ((bytes[offset + 2] ?? 0) << 8) | (bytes[offset + 3] ?? 0);
}
