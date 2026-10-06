import { zlibSync } from "fflate";

import { wasmBytes } from "./djvu-bytes";

export type DjvuPage = {
  name: string;
  bytes: Uint8Array;
};

export type OpenedDjvu =
  | { kind: "djvu"; pages: DjvuPage[] }
  | { kind: "unavailable" }
  | { kind: "corrupt" };

const pngSignature = Uint8Array.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
const crcTable = buildCrcTable();
let wasmReady: Promise<void> | null = null;

export function isDjvuName(name: string): boolean {
  const lower = name.toLowerCase();
  return lower.endsWith(".djvu") || lower.endsWith(".djv");
}

export async function openDjvuDocument(bytes: Uint8Array | null): Promise<OpenedDjvu> {
  if (bytes == null || bytes.length === 0) return { kind: "unavailable" };
  if (!looksLikeDjvu(bytes)) return { kind: "corrupt" };
  try {
    const djvu = await import("djvu-rs");
    await loadWasm(djvu);
    const document = djvu.WasmDocument.from_bytes(bytes.slice());
    try {
      const pages = pagesFrom(document);
      if (pages.length === 0) return { kind: "corrupt" };
      return { kind: "djvu", pages };
    } finally {
      document.free();
    }
  } catch {
    return { kind: "corrupt" };
  }
}

function looksLikeDjvu(bytes: Uint8Array): boolean {
  if (bytes.length < 16) return false;
  const head = ascii(bytes, 0, 8);
  const kind = ascii(bytes, 12, 16);
  return head === "AT&TFORM" && (kind === "DJVU" || kind === "DJVM" || kind === "DJVI");
}

function ascii(bytes: Uint8Array, start: number, end: number): string {
  return String.fromCharCode(...bytes.subarray(start, end));
}

async function loadWasm(djvu: typeof import("djvu-rs")): Promise<void> {
  wasmReady ??= djvu.default(await wasmBytes(djvu.wasmSimd128Supported())).then(() => undefined).catch((error: unknown) => {
    wasmReady = null;
    throw error;
  });
  await wasmReady;
}

function pagesFrom(document: { page_count(): number; page(index: number): DjvuPageHandle }): DjvuPage[] {
  const pages: DjvuPage[] = [];
  for (let index = 0; index < document.page_count(); index += 1) {
    const page = document.page(index);
    try {
      const dpi = page.dpi();
      const target = dpi > 0 ? dpi : 72;
      const width = page.width_at(target);
      const height = page.height_at(target);
      if (width <= 0 || height <= 0) continue;
      pages.push({
        name: `page-${String(index + 1).padStart(3, "0")}.png`,
        bytes: pngFromRgba(width, height, page.render(target)),
      });
    } finally {
      page.free();
    }
  }
  return pages;
}

type DjvuPageHandle = {
  dpi(): number;
  width_at(dpi: number): number;
  height_at(dpi: number): number;
  render(dpi: number): Uint8Array | Uint8ClampedArray;
  free(): void;
};

function pngFromRgba(width: number, height: number, rgba: Uint8Array | Uint8ClampedArray): Uint8Array {
  const stride = width * 4;
  const raw = new Uint8Array((stride + 1) * height);
  for (let y = 0; y < height; y += 1) {
    const row = y * (stride + 1);
    raw[row] = 0;
    raw.set(rgba.subarray(y * stride, y * stride + stride), row + 1);
  }
  const header = new Uint8Array(13);
  const view = new DataView(header.buffer);
  view.setUint32(0, width);
  view.setUint32(4, height);
  header[8] = 8;
  header[9] = 6;
  return concat([pngSignature, chunk("IHDR", header), chunk("IDAT", zlibSync(raw)), chunk("IEND", new Uint8Array())]);
}

function chunk(type: string, data: Uint8Array): Uint8Array {
  const out = new Uint8Array(12 + data.length);
  const view = new DataView(out.buffer);
  view.setUint32(0, data.length);
  out[4] = type.charCodeAt(0);
  out[5] = type.charCodeAt(1);
  out[6] = type.charCodeAt(2);
  out[7] = type.charCodeAt(3);
  out.set(data, 8);
  view.setUint32(8 + data.length, crc32(out.subarray(4, 8 + data.length)));
  return out;
}

function concat(parts: Uint8Array[]): Uint8Array {
  const out = new Uint8Array(parts.reduce((sum, part) => sum + part.length, 0));
  let offset = 0;
  for (const part of parts) {
    out.set(part, offset);
    offset += part.length;
  }
  return out;
}

function crc32(bytes: Uint8Array): number {
  let crc = 0xffffffff;
  for (const byte of bytes) crc = crcTable[(crc ^ byte) & 0xff] ^ (crc >>> 8);
  return (crc ^ 0xffffffff) >>> 0;
}

function buildCrcTable(): Uint32Array {
  const table = new Uint32Array(256);
  for (let index = 0; index < 256; index += 1) {
    let value = index;
    for (let bit = 0; bit < 8; bit += 1) value = value & 1 ? 0xedb88320 ^ (value >>> 1) : value >>> 1;
    table[index] = value >>> 0;
  }
  return table;
}
