import { Buffer } from "buffer";
import { unzipSync } from "fflate";

import { extractArchive } from "./compressed-archive";
import { FormatError } from "./text-document";

const imageSuffixes = [".png", ".jpg", ".jpeg", ".webp", ".gif"];

export type ComicFormat = "cbz" | "cbt" | "cbr" | "cb7";

export type ComicPage = {
  name: string;
  bytes: Uint8Array;
};

export type OpenedComic =
  | { kind: "comic"; format: ComicFormat; pages: ComicPage[] }
  | { kind: "unavailable" }
  | { kind: "corrupt" }
  | { kind: "unsupported" };

export function comicFormatFromName(name: string): ComicFormat | null {
  const lower = name.toLowerCase();
  if (lower.endsWith(".cbz")) return "cbz";
  if (lower.endsWith(".cbt")) return "cbt";
  if (lower.endsWith(".cbr")) return "cbr";
  if (lower.endsWith(".cb7")) return "cb7";
  return null;
}

export async function openComicDocument(name: string, bytes: Uint8Array | null): Promise<OpenedComic> {
  if (bytes == null || bytes.length === 0) return { kind: "unavailable" };
  const format = comicFormatFromName(name);
  if (format == null) return { kind: "unsupported" };
  if (format === "cbr" || format === "cb7") return openCompressedComic(format, bytes);
  return openStoredComic(format, bytes);
}

export function openStoredComic(format: "cbz" | "cbt", bytes: Uint8Array): OpenedComic {
  try {
    const pages = startsWithZip(bytes) ? readZip(bytes) : looksLikeTar(bytes) ? readTar(bytes) : readZip(bytes);
    if (pages.length === 0) return { kind: "corrupt" };
    return { kind: "comic", format, pages };
  } catch (error) {
    if (error instanceof FormatError) return { kind: "corrupt" };
    throw error;
  }
}

async function openCompressedComic(format: "cbr" | "cb7", bytes: Uint8Array): Promise<OpenedComic> {
  if (startsWithZip(bytes) || looksLikeTar(bytes)) return { kind: "unsupported" };
  if (format === "cbr" && !isRar(bytes)) return { kind: "corrupt" };
  if (format === "cb7" && !is7z(bytes)) return { kind: "corrupt" };
  try {
    const pages = collectPages(await extractArchive(bytes));
    if (pages.length === 0) return { kind: "corrupt" };
    return { kind: "comic", format, pages };
  } catch (error) {
    if (error instanceof FormatError) return { kind: "corrupt" };
    throw error;
  }
}

export function comicPageUri(page: ComicPage): string {
  const lower = page.name.toLowerCase();
  const mime = lower.endsWith(".jpg") || lower.endsWith(".jpeg")
    ? "image/jpeg"
    : lower.endsWith(".webp")
      ? "image/webp"
      : lower.endsWith(".gif")
        ? "image/gif"
        : "image/png";
  return `data:${mime};base64,${Buffer.from(page.bytes).toString("base64")}`;
}

export function comicPageImage(page: ComicPage): { alt: string; src: string } {
  return { alt: page.name, src: comicPageUri(page) };
}

function readZip(bytes: Uint8Array): ComicPage[] {
  let entries: Record<string, Uint8Array>;
  try {
    entries = unzipSync(bytes);
  } catch {
    throw new FormatError("corrupt comic");
  }
  return collectPages(Object.entries(entries).filter(([name]) => !name.endsWith("/")));
}

function readTar(bytes: Uint8Array): ComicPage[] {
  const files: [string, Uint8Array][] = [];
  let offset = 0;
  let pendingName: string | null = null;
  while (offset + 512 <= bytes.length) {
    if (isZeroBlock(bytes, offset)) break;
    const header = bytes.subarray(offset, offset + 512);
    const size = readOctal(header, 124, 136);
    if (size == null || offset + 512 + size > bytes.length) throw new FormatError("corrupt comic");
    const typeflag = header[156] ?? 0;
    const storedName = readCString(header, 0, 100);
    const prefix = readCString(header, 345, 500);
    const path = pendingName ?? (prefix.length > 0 ? `${prefix}/${storedName}` : storedName);
    pendingName = null;
    const data = bytes.slice(offset + 512, offset + 512 + size);
    offset += 512 + Math.ceil(size / 512) * 512;
    if (typeflag === 0x4c) {
      pendingName = new TextDecoder().decode(data).replace(/\0+$/, "");
      continue;
    }
    if (typeflag !== 0 && typeflag !== 0x30) continue;
    files.push([path, data]);
  }
  return collectPages(files);
}

function collectPages(files: [string, Uint8Array][]): ComicPage[] {
  const pages = files
    .filter(([name]) => isImagePath(name))
    .map(([name, data]) => ({ name: baseName(name), bytes: data }));
  pages.sort((left, right) => {
    const a = left.name.toLowerCase();
    const b = right.name.toLowerCase();
    if (a < b) return -1;
    if (a > b) return 1;
    return 0;
  });
  return pages;
}

function isImagePath(path: string): boolean {
  if (path.toLowerCase().includes("__macosx")) return false;
  const base = baseName(path).toLowerCase();
  if (base.length === 0 || base.startsWith(".")) return false;
  return imageSuffixes.some((suffix) => base.endsWith(suffix));
}

function baseName(path: string): string {
  const parts = path.replace(/\\/g, "/").split("/");
  return parts[parts.length - 1] ?? "";
}

function isRar(bytes: Uint8Array): boolean {
  return (
    bytes.length >= 7 &&
    bytes[0] === 0x52 &&
    bytes[1] === 0x61 &&
    bytes[2] === 0x72 &&
    bytes[3] === 0x21 &&
    bytes[4] === 0x1a &&
    bytes[5] === 0x07 &&
    (bytes[6] === 0x00 || bytes[6] === 0x01)
  );
}

function is7z(bytes: Uint8Array): boolean {
  return (
    bytes.length >= 6 &&
    bytes[0] === 0x37 &&
    bytes[1] === 0x7a &&
    bytes[2] === 0xbc &&
    bytes[3] === 0xaf &&
    bytes[4] === 0x27 &&
    bytes[5] === 0x1c
  );
}

function startsWithZip(bytes: Uint8Array): boolean {
  return bytes.length >= 4 && bytes[0] === 0x50 && bytes[1] === 0x4b && bytes[2] === 0x03 && bytes[3] === 0x04;
}

function looksLikeTar(bytes: Uint8Array): boolean {
  if (bytes.length < 512) return false;
  if (bytes[257] === 0x75 && bytes[258] === 0x73 && bytes[259] === 0x74 && bytes[260] === 0x61 && bytes[261] === 0x72) {
    return true;
  }
  const stored = readOctal(bytes, 148, 156);
  if (stored == null) return false;
  let checksum = 0;
  for (let index = 0; index < 512; index += 1) {
    checksum += index >= 148 && index < 156 ? 0x20 : (bytes[index] ?? 0);
  }
  return checksum === stored;
}

function readOctal(bytes: Uint8Array, start: number, end: number): number | null {
  let value = 0;
  let seen = false;
  for (let index = start; index < end && index < bytes.length; index += 1) {
    const byte = bytes[index] ?? 0;
    if (byte === 0 || byte === 0x20) {
      if (seen) break;
      continue;
    }
    if (byte < 0x30 || byte > 0x37) return null;
    seen = true;
    value = value * 8 + (byte - 0x30);
  }
  return seen ? value : null;
}

function readCString(bytes: Uint8Array, start: number, end: number): string {
  let stop = start;
  while (stop < end && bytes[stop] !== 0) stop += 1;
  return new TextDecoder().decode(bytes.subarray(start, stop));
}

function isZeroBlock(bytes: Uint8Array, offset: number): boolean {
  for (let index = 0; index < 512; index += 1) {
    if (bytes[offset + index] !== 0) return false;
  }
  return true;
}
