import iconv from "iconv-lite";

export const TEXT_READER_BYTE_LIMIT = 1024 * 1024;
export const TEXT_SECTION_CHAR_LIMIT = 4000;

export type TextFormat = "txt" | "markdown" | "html";

export type DocumentMetadata = {
  id: string;
  title: string;
  author: string;
  format: TextFormat;
};

export type TextSection = {
  title: string;
  body: string;
  startOffset: number;
};

export type ParsedTextDocument = {
  fullText: string;
  sections: TextSection[];
  truncated: boolean;
};

export type TextLocator = {
  kind: "text";
  offset: number;
};

export class FormatError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "FormatError";
  }
}

export type OpenedTextDocument =
  | { kind: "text"; document: TextReaderDocument }
  | { kind: "unavailable"; metadata: DocumentMetadata }
  | { kind: "corrupt"; metadata: DocumentMetadata };

export function textFormatFromName(name: string): TextFormat | null {
  const lower = name.toLowerCase();
  if (lower.endsWith(".txt")) return "txt";
  if (lower.endsWith(".markdown") || lower.endsWith(".md")) return "markdown";
  if (lower.endsWith(".html") || lower.endsWith(".htm")) return "html";
  return null;
}

export function titleFromName(name: string): string {
  const slash = Math.max(name.lastIndexOf("/"), name.lastIndexOf("\\"));
  const base = name.slice(slash + 1);
  const dot = base.lastIndexOf(".");
  if (dot <= 0) return base.length > 0 ? base : name;
  const title = base.slice(0, dot);
  return title.length > 0 ? title : base;
}

export function openTextDocument(
  metadata: DocumentMetadata,
  bytes: Uint8Array | null,
): OpenedTextDocument {
  if (bytes == null || bytes.length === 0) {
    return { kind: "unavailable", metadata };
  }
  try {
    return { kind: "text", document: TextReaderDocument.parse(metadata, bytes) };
  } catch (error) {
    if (error instanceof FormatError) return { kind: "corrupt", metadata };
    throw error;
  }
}

export class TextReaderDocument {
  private sectionIndex = 0;

  private constructor(
    readonly metadata: DocumentMetadata,
    private readonly parsed: ParsedTextDocument,
  ) {}

  static parse(metadata: DocumentMetadata, bytes: Uint8Array): TextReaderDocument {
    return new TextReaderDocument(metadata, parseTextDocument(bytes, metadata.format));
  }

  get chapterIndex(): number {
    return this.sectionIndex;
  }

  get chapterCount(): number {
    return this.parsed.sections.length;
  }

  get currentChapterTitle(): string {
    return this.currentSection.title;
  }

  get currentChapterText(): string {
    return this.currentSection.body;
  }

  get truncated(): boolean {
    return this.parsed.truncated;
  }

  goTo(locator: TextLocator): void {
    let index = -1;
    for (let i = 0; i < this.parsed.sections.length; i += 1) {
      const section = this.parsed.sections[i];
      if (section != null && section.startOffset <= locator.offset) index = i;
    }
    this.sectionIndex = index < 0 ? 0 : index;
  }

  next(): void {
    if (this.sectionIndex < this.chapterCount - 1) this.sectionIndex += 1;
  }

  previous(): void {
    if (this.sectionIndex > 0) this.sectionIndex -= 1;
  }

  moveTo(index: number): void {
    if (this.chapterCount === 0) return;
    this.sectionIndex = Math.min(Math.max(index, 0), this.chapterCount - 1);
  }

  search(query: string): { chapterIndex: number; excerpt: string }[] {
    const needle = query.trim();
    if (needle.length === 0) return [];
    const hits: { chapterIndex: number; excerpt: string }[] = [];
    for (let index = 0; index < this.parsed.sections.length; index += 1) {
      const section = this.parsed.sections[index];
      if (section == null) continue;
      const haystack = searchableText(section);
      const at = haystack.indexOf(needle);
      if (at < 0) continue;
      hits.push({
        chapterIndex: index,
        excerpt: excerptAround(haystack, at, needle.length),
      });
      if (hits.length >= 10) break;
    }
    return hits;
  }

  private get currentSection(): TextSection {
    const last = this.parsed.sections.length - 1;
    const index = Math.min(Math.max(this.sectionIndex, 0), last);
    const section = this.parsed.sections[index];
    if (section == null) {
      return { title: "", body: "", startOffset: 0 };
    }
    return section;
  }
}

export function parseTextDocument(
  bytes: Uint8Array,
  format: TextFormat,
): ParsedTextDocument {
  const truncated = bytes.length > TEXT_READER_BYTE_LIMIT;
  const slice = truncated ? bytes.subarray(0, TEXT_READER_BYTE_LIMIT) : bytes;
  let text = format === "html" ? decodeTextBytes(slice) : decodePlainTextBytes(slice);
  if (format === "html") text = stripHtml(text);
  text = text.replaceAll("\r\n", "\n").replaceAll("\r", "\n").trim();
  const raw = format === "markdown" ? splitMarkdown(text) : splitPlainText(text);
  const sections = raw.length === 0 ? [{ title: "", body: text, startOffset: 0 }] : raw;
  return { fullText: text, sections: packSections(sections), truncated };
}

export function decodePlainTextBytes(bytes: Uint8Array): string {
  if (bytes.length >= 2 && bytes[0] === 0xff && bytes[1] === 0xfe) {
    return decodeUtf16(bytes, 2, false);
  }
  if (bytes.length >= 2 && bytes[0] === 0xfe && bytes[1] === 0xff) {
    return decodeUtf16(bytes, 2, true);
  }
  let offset = 0;
  if (bytes.length >= 3 && bytes[0] === 0xef && bytes[1] === 0xbb && bytes[2] === 0xbf) {
    offset = 3;
  }
  const slice = bytes.subarray(offset);
  if (offset === 3) return decodeUtf8Strict(slice);
  try {
    return decodeUtf8Strict(slice);
  } catch (error) {
    if (error instanceof FormatError) return decodeGbk(slice);
    throw error;
  }
}

export function decodeTextBytes(bytes: Uint8Array): string {
  if (bytes.length >= 2 && bytes[0] === 0xff && bytes[1] === 0xfe) {
    return decodeUtf16(bytes, 2, false);
  }
  if (bytes.length >= 2 && bytes[0] === 0xfe && bytes[1] === 0xff) {
    return decodeUtf16(bytes, 2, true);
  }
  let offset = 0;
  if (bytes.length >= 3 && bytes[0] === 0xef && bytes[1] === 0xbb && bytes[2] === 0xbf) {
    offset = 3;
  }
  return new TextDecoder("utf-8", { fatal: false }).decode(bytes.subarray(offset));
}

function decodeUtf8Strict(bytes: Uint8Array): string {
  try {
    return new TextDecoder("utf-8", { fatal: true }).decode(bytes);
  } catch (error) {
    if (error instanceof TypeError) throw new FormatError("utf-8");
    throw error;
  }
}

function decodeGbk(bytes: Uint8Array): string {
  const decoded = iconv.decode(
    Buffer.from(bytes.buffer, bytes.byteOffset, bytes.byteLength),
    "gbk",
  );
  if (decoded.includes("\uFFFD")) throw new FormatError("gbk");
  return decoded;
}

function decodeUtf16(bytes: Uint8Array, offset: number, bigEndian: boolean): string {
  const slice = bytes.subarray(offset);
  const even = slice.length % 2 === 0 ? slice : slice.subarray(0, slice.length - 1);
  const encoding = bigEndian ? "utf-16be" : "utf-16le";
  return new TextDecoder(encoding).decode(even);
}

export function stripHtml(source: string): string {
  let text = source.replaceAll(/<script[\s\S]*?<\/script>/gi, "");
  text = text.replaceAll(/<style[\s\S]*?<\/style>/gi, "");
  text = text.replaceAll(/<br\s*\/?>/gi, "\n");
  text = text.replaceAll(/<\/p>/gi, "\n\n");
  text = text.replaceAll(/<h[1-6][^>]*>/gi, "\n\n");
  text = text.replaceAll(/<\/h[1-6]>/gi, "\n\n");
  text = text.replaceAll(/<[^>]+>/g, "");
  return text
    .replaceAll("&nbsp;", " ")
    .replaceAll("&amp;", "&")
    .replaceAll("&lt;", "<")
    .replaceAll("&gt;", ">")
    .replaceAll("&quot;", '"')
    .replaceAll("&#39;", "'")
    .replaceAll(/\n{3,}/g, "\n\n")
    .trim();
}

function splitMarkdown(text: string): TextSection[] {
  const heading = /^#{1,6}\s+(.+)$/gm;
  const matches = [...text.matchAll(heading)];
  if (matches.length === 0) return splitPlainText(text);
  const sections: TextSection[] = [];
  const first = matches[0];
  if (first != null && first.index > 0) {
    const preface = text.slice(0, first.index).trim();
    if (preface.length > 0) {
      sections.push({ title: "", body: preface, startOffset: 0 });
    }
  }
  for (let i = 0; i < matches.length; i += 1) {
    const match = matches[i];
    if (match == null || match.index == null) continue;
    const next = matches[i + 1];
    const end = next?.index ?? text.length;
    const title = match[1]?.trim() ?? "";
    sections.push({
      title,
      body: text.slice(match.index + match[0].length, end).trim(),
      startOffset: match.index,
    });
  }
  return sections;
}

function splitPlainText(text: string): TextSection[] {
  if (text.length === 0) return [{ title: "", body: "", startOffset: 0 }];
  const blocks = text
    .split(/\n{2,}/)
    .map((block) => block.trim())
    .filter((block) => block.length > 0);
  if (blocks.length === 1) {
    return [{ title: "", body: blocks[0] ?? "", startOffset: 0 }];
  }

  const sections: TextSection[] = [];
  let cursor = 0;
  let i = 0;
  while (i < blocks.length) {
    const block = blocks[i] ?? "";
    const start = text.indexOf(block, cursor);
    const offset = start < 0 ? cursor : start;
    const isTitle =
      i + 1 < blocks.length && !block.includes("\n") && runeCount(block) <= 40;
    if (isTitle) {
      sections.push({
        title: block,
        body: blocks[i + 1] ?? "",
        startOffset: offset,
      });
      cursor = offset + block.length;
      i += 2;
      continue;
    }
    sections.push({
      title: firstLine(block),
      body: block,
      startOffset: offset,
    });
    cursor = offset + block.length;
    i += 1;
  }
  return sections;
}

function packSections(sections: TextSection[]): TextSection[] {
  return sections.flatMap((section) =>
    section.body.length > TEXT_SECTION_CHAR_LIMIT ? chunkBody(section) : [section],
  );
}

function chunkBody(section: TextSection): TextSection[] {
  const chunks: TextSection[] = [];
  let offset = section.startOffset;
  let index = 0;
  while (index < section.body.length) {
    const end = Math.min(index + TEXT_SECTION_CHAR_LIMIT, section.body.length);
    chunks.push({
      title: section.title,
      body: section.body.slice(index, end),
      startOffset: offset,
    });
    offset += end - index;
    index = end;
  }
  return chunks;
}

function searchableText(section: TextSection): string {
  if (section.title.length === 0 || section.body.startsWith(section.title)) return section.body;
  return `${section.title}\n${section.body}`;
}

function excerptAround(text: string, start: number, queryLength: number): string {
  const from = start < 24 ? 0 : start - 24;
  const to = Math.min(text.length, start + queryLength + 24);
  return text.slice(from, to).trim();
}

function firstLine(block: string): string {
  const line = block.split("\n")[0]?.trim() ?? "";
  return runeCount(line) <= 40 ? line : "";
}

function runeCount(value: string): number {
  return Array.from(value).length;
}
