import { EpubReaderDocument, openEpubDocument } from "./epub-document";
import { decodeTextBytes } from "./text-document";

const hasLetters = /[A-Za-z\u4e00-\u9fff]/;

export type OpenedMobi =
  | { kind: "mobi"; document: MobiReaderDocument }
  | { kind: "unavailable" }
  | { kind: "corrupt" };

export function isMobiName(name: string): boolean {
  return name.toLowerCase().endsWith(".mobi");
}

export function isAzw3Name(name: string): boolean {
  return name.toLowerCase().endsWith(".azw3");
}

export function openMobiDocument(bytes: Uint8Array | null): OpenedMobi {
  if (bytes == null || bytes.length === 0) return { kind: "unavailable" };
  const epub = epubInside(bytes);
  if (epub != null) return { kind: "mobi", document: MobiReaderDocument.fromEpub(epub) };
  const text = readableRuns(bytes).trim();
  if (text.length === 0) return { kind: "corrupt" };
  return { kind: "mobi", document: MobiReaderDocument.fromRun(text) };
}

export class MobiReaderDocument {
  private constructor(private readonly epub: EpubReaderDocument | null, private readonly run: string) {}

  static fromEpub(epub: EpubReaderDocument): MobiReaderDocument {
    return new MobiReaderDocument(epub, "");
  }

  static fromRun(run: string): MobiReaderDocument {
    return new MobiReaderDocument(null, run);
  }

  get title(): string {
    return this.epub?.title ?? "";
  }

  get author(): string {
    return this.epub?.author ?? "";
  }

  get chapterIndex(): number {
    return this.epub?.chapterIndex ?? 0;
  }

  get chapterCount(): number {
    return this.epub?.chapterCount ?? 1;
  }

  get currentChapterTitle(): string {
    return this.epub?.currentChapterTitle ?? "";
  }

  get currentChapterText(): string {
    return this.epub?.currentChapterText ?? this.run;
  }

  get truncated(): boolean {
    return this.epub?.truncated ?? false;
  }

  next(): void {
    this.epub?.next();
  }

  previous(): void {
    this.epub?.previous();
  }

  moveTo(index: number): void {
    this.epub?.moveTo(index);
  }

  search(query: string): { chapterIndex: number; excerpt: string }[] {
    const needle = query.trim();
    if (needle.length === 0) return [];
    if (this.epub != null) {
      return this.epub.search(needle).flatMap((hit) => {
        const chapterIndex = this.epub?.indexOfHref(hit.href) ?? -1;
        return chapterIndex < 0 ? [] : [{ chapterIndex, excerpt: hit.excerpt }];
      });
    }
    const at = this.run.indexOf(needle);
    if (at < 0) return [];
    const from = at < 24 ? 0 : at - 24;
    const to = Math.min(this.run.length, at + needle.length + 24);
    return [{ chapterIndex: 0, excerpt: this.run.slice(from, to).trim() }];
  }
}

function epubInside(bytes: Uint8Array): EpubReaderDocument | null {
  const direct = openEpubDocument(bytes);
  if (direct.kind === "epub") return direct.document;
  const offset = zipOffset(bytes);
  if (offset == null || offset === 0) return null;
  const sliced = openEpubDocument(bytes.subarray(offset));
  return sliced.kind === "epub" ? sliced.document : null;
}

function zipOffset(bytes: Uint8Array): number | null {
  for (let index = 0; index < bytes.length - 3; index += 1) {
    if (bytes[index] === 0x50 && bytes[index + 1] === 0x4b && bytes[index + 2] === 0x03 && bytes[index + 3] === 0x04) {
      return index;
    }
  }
  return null;
}

function readableRuns(bytes: Uint8Array): string {
  const matches = decodeTextBytes(bytes).match(/[\t\n\r\x20-\x7E\u00A0-\uFFFF]{24,}/g) ?? [];
  return matches
    .map((run) => run.trim())
    .filter((run) => hasLetters.test(run))
    .join("\n\n");
}
