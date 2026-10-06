import iconv from "iconv-lite";

import { FormatError } from "./text-document";

export const rtfTextCharLimit = 2 * 1024 * 1024;

export type OpenedRtf =
  | { kind: "rtf"; document: RtfReaderDocument }
  | { kind: "unavailable" }
  | { kind: "corrupt" };

type RtfChapter = {
  title: string;
  body: string;
};

type RtfBlock = {
  text: string;
  headingLevel: number | null;
};

type ParsedRtf = {
  title: string;
  author: string;
  chapters: RtfChapter[];
  truncated: boolean;
};

export function isRtfName(name: string): boolean {
  return name.toLowerCase().endsWith(".rtf");
}

export function openRtfDocument(bytes: Uint8Array | null): OpenedRtf {
  if (bytes == null || bytes.length === 0) return { kind: "unavailable" };
  try {
    return { kind: "rtf", document: new RtfReaderDocument(parseRtf(bytes)) };
  } catch (error) {
    if (error instanceof FormatError) return { kind: "corrupt" };
    throw error;
  }
}

export class RtfReaderDocument {
  private sectionIndex = 0;

  constructor(private readonly parsed: ParsedRtf) {}

  get title(): string {
    return this.parsed.title;
  }

  get author(): string {
    return this.parsed.author;
  }

  get chapterIndex(): number {
    return this.sectionIndex;
  }

  get chapterCount(): number {
    return this.parsed.chapters.length;
  }

  get currentChapterTitle(): string {
    return this.current.title;
  }

  get currentChapterText(): string {
    return this.current.body;
  }

  get truncated(): boolean {
    return this.parsed.truncated;
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
    for (let index = 0; index < this.parsed.chapters.length; index += 1) {
      const chapter = this.parsed.chapters[index];
      if (chapter == null) continue;
      const haystack =
        chapter.title.length === 0 || chapter.body.startsWith(chapter.title)
          ? chapter.body
          : `${chapter.title}\n${chapter.body}`;
      const at = haystack.indexOf(needle);
      if (at < 0) continue;
      const from = at < 24 ? 0 : at - 24;
      const to = Math.min(haystack.length, at + needle.length + 24);
      hits.push({ chapterIndex: index, excerpt: haystack.slice(from, to).trim() });
      if (hits.length >= 10) break;
    }
    return hits;
  }

  private get current(): RtfChapter {
    return this.parsed.chapters[this.sectionIndex] ?? { title: "", body: "" };
  }
}

function parseRtf(bytes: Uint8Array): ParsedRtf {
  if (!looksLikeRtf(bytes)) throw new FormatError("corrupt rtf");
  const blocks = new RtfParser(bytes).parse();
  const title = infoValue(bytes, "title") ?? "";
  const author = infoValue(bytes, "author") ?? infoValue(bytes, "operator") ?? "";
  const built = buildChapters(blocks, title);
  return { title, author, chapters: built.chapters, truncated: built.truncated };
}

class RtfParser {
  private readonly blocks: RtfBlock[] = [];
  private readonly frames: { ignored: boolean }[] = [{ ignored: false }];
  private readonly tableRows: string[][] = [];
  private paragraph = "";
  private readonly pending: number[] = [];
  private index: number;
  private codePage = 1252;
  private headingLevel: number | null = null;
  private tableRowOpen = false;
  private tableRow: string[] = [];
  private closedRoot = false;

  constructor(private readonly bytes: Uint8Array) {
    this.index = preambleEnd(bytes);
  }

  parse(): RtfBlock[] {
    while (this.index < this.bytes.length) {
      const byte = this.bytes[this.index] ?? 0;
      this.index += 1;
      if (byte === 0x7b) {
        this.flushPending();
        this.frames.push({ ignored: false });
      } else if (byte === 0x7d) {
        this.flushPending();
        if (this.frames.length > 1) this.frames.pop();
        if (this.frames.length === 1) this.closedRoot = true;
      } else if (byte === 0x5c) {
        this.control();
      } else if (byte === 0x0a || byte === 0x0d) {
        continue;
      } else if (byte === 0x09) {
        this.appendLiteral("\t");
      } else {
        this.pending.push(byte);
      }
    }
    this.flushPending();
    this.flushTable();
    this.flushParagraph();
    if (this.frames.length !== 1 || !this.closedRoot) throw new FormatError("corrupt rtf");
    return this.blocks;
  }

  private get ignored(): boolean {
    return this.frames.some((frame) => frame.ignored);
  }

  private control(): void {
    if (this.index >= this.bytes.length) return;
    const current = this.bytes[this.index] ?? 0;
    if (isAsciiLetter(current)) {
      this.controlWord();
      return;
    }
    this.index += 1;
    if (current === 0x27) {
      if (this.index + 1 >= this.bytes.length) throw new FormatError("corrupt rtf");
      const high = this.bytes[this.index] ?? 0;
      const low = this.bytes[this.index + 1] ?? 0;
      const value = parseHex(high, low);
      this.index += 2;
      if (value == null) throw new FormatError("corrupt rtf");
      if (!this.ignored) this.pending.push(value);
      return;
    }
    if (current === 0x7b) this.appendLiteral("{");
    else if (current === 0x7d) this.appendLiteral("}");
    else if (current === 0x5c) this.appendLiteral("\\");
    else if (current === 0x7e) this.appendLiteral("\u00A0");
    else if (current === 0x5f) this.appendLiteral("-");
    else if (current === 0x2a) {
      const frame = this.frames[this.frames.length - 1];
      if (frame != null) frame.ignored = true;
    }
  }

  private controlWord(): void {
    const start = this.index;
    while (this.index < this.bytes.length && isAsciiLetter(this.bytes[this.index] ?? 0)) this.index += 1;
    const name = latin1(this.bytes.subarray(start, this.index));
    let sign = 1;
    if (this.bytes[this.index] === 0x2d) {
      sign = -1;
      this.index += 1;
    }
    const numberStart = this.index;
    while (this.index < this.bytes.length && isDigit(this.bytes[this.index] ?? 0)) this.index += 1;
    const parameter = numberStart === this.index ? null : sign * readParameter(this.bytes, numberStart, this.index);
    if (this.bytes[this.index] === 0x20) this.index += 1;
    if (this.ignored) return;
    if (name === "ansicpg") {
      this.codePage = parameter ?? this.codePage;
      return;
    }
    if (
      name === "fonttbl" ||
      name === "colortbl" ||
      name === "stylesheet" ||
      name === "info" ||
      name === "pict" ||
      name === "object" ||
      name === "header" ||
      name === "footer" ||
      name === "footnote" ||
      name === "field"
    ) {
      const frame = this.frames[this.frames.length - 1];
      if (frame != null) frame.ignored = true;
      return;
    }
    if (name === "par") {
      this.flushPending();
      if (this.tableRowOpen) this.appendLineBreak();
      else this.flushParagraph();
      return;
    }
    if (name === "line") {
      this.appendLineBreak();
      return;
    }
    if (name === "tab") {
      this.appendLiteral("\t");
      return;
    }
    if (name === "pard") {
      this.flushPending();
      if (!this.tableRowOpen) this.flushTable();
      this.headingLevel = null;
      return;
    }
    if (name === "plain" || name === "b" || name === "i" || name === "ul" || name === "ulnone" || name === "strike" || name === "super" || name === "sub" || name === "nosupersub") {
      this.flushPending();
      return;
    }
    if (name === "outlinelevel") {
      this.flushPending();
      this.headingLevel = parameter == null ? null : clamp(parameter + 1, 1, 6);
      return;
    }
    if (name === "s") {
      this.flushPending();
      if (parameter != null && parameter > 0 && parameter <= 6) this.headingLevel = parameter;
      return;
    }
    if (name === "u") {
      this.flushPending();
      if (parameter != null) {
        const code = parameter < 0 ? parameter + 65536 : parameter;
        this.appendLiteral(String.fromCharCode(code));
        if (this.bytes[this.index] === 0x3f) this.index += 1;
      }
      return;
    }
    if (name === "bin") {
      this.flushPending();
      if (parameter != null && parameter > 0) {
        this.index = Math.min(this.bytes.length, this.index + parameter);
      }
      return;
    }
    if (name === "trowd") {
      this.flushParagraph();
      this.tableRowOpen = true;
      this.tableRow = [];
      return;
    }
    if (name === "cell") {
      this.flushPending();
      this.finishCell();
      return;
    }
    if (name === "row") {
      this.flushPending();
      this.finishCell();
      if (this.tableRow.length > 0) this.tableRows.push(this.tableRow);
      this.tableRow = [];
      this.tableRowOpen = false;
      return;
    }
    if (name === "emdash") this.appendLiteral("\u2014");
    else if (name === "endash") this.appendLiteral("\u2013");
    else if (name === "bullet") this.appendLiteral("\u2022");
    else if (name === "lquote") this.appendLiteral("\u2018");
    else if (name === "rquote") this.appendLiteral("\u2019");
    else if (name === "ldblquote") this.appendLiteral("\u201C");
    else if (name === "rdblquote") this.appendLiteral("\u201D");
  }

  private appendLiteral(value: string): void {
    if (this.ignored || value.length === 0) return;
    this.flushPending();
    this.paragraph += value;
  }

  private appendLineBreak(): void {
    if (this.ignored || this.tableRowOpen) return;
    this.flushPending();
    this.paragraph += "\n";
  }

  private flushPending(): void {
    if (this.pending.length === 0) return;
    const decoded = decodeBytes(this.pending, this.codePage);
    this.pending.length = 0;
    if (!this.ignored && decoded.length > 0) this.paragraph += decoded;
  }

  private flushParagraph(): void {
    this.flushPending();
    const text = this.paragraph.trim();
    if (text.length > 0) this.blocks.push({ text, headingLevel: this.headingLevel });
    this.paragraph = "";
  }

  private finishCell(): void {
    const text = this.paragraph.trim();
    if (text.length > 0) this.tableRow.push(text);
    this.paragraph = "";
  }

  private flushTable(): void {
    if (this.tableRows.length === 0) return;
    const text = this.tableRows.map((row) => row.join("\t")).join("\n").trim();
    if (text.length > 0) this.blocks.push({ text, headingLevel: null });
    this.tableRows.length = 0;
  }
}

function buildChapters(blocks: RtfBlock[], fallbackTitle: string): { chapters: RtfChapter[]; truncated: boolean } {
  const raw: RtfChapter[] = [];
  let current: RtfBlock[] = [];
  let currentTitle: string | null = null;
  const flush = () => {
    if (current.length === 0) return;
    const title = currentTitle ?? fallbackTitle;
    const body = chapterBody(current, title);
    current = [];
    currentTitle = null;
    if (body.length === 0 && title.length === 0) return;
    raw.push({ title, body });
  };
  for (const block of blocks) {
    const startsChapter = block.headingLevel != null && block.headingLevel <= 2;
    if (startsChapter && current.length > 0) flush();
    if (startsChapter && block.text.trim().length > 0) currentTitle = block.text.trim();
    current.push(block);
  }
  flush();
  if (raw.length === 0) throw new FormatError("corrupt rtf");
  const chapters: RtfChapter[] = [];
  let fullLength = 0;
  let truncated = false;
  for (const chapter of raw) {
    if (fullLength >= rtfTextCharLimit) {
      truncated = true;
      break;
    }
    const remaining = rtfTextCharLimit - fullLength;
    let body = chapter.body;
    if (body.length > remaining) {
      body = body.slice(0, remaining);
      truncated = true;
    }
    if (fullLength > 0) fullLength += 2;
    fullLength += body.length;
    chapters.push({ title: chapter.title, body });
    if (truncated) break;
  }
  if (chapters.length === 0) throw new FormatError("corrupt rtf");
  return { chapters, truncated };
}

function chapterBody(blocks: RtfBlock[], title: string): string {
  const first = blocks[0];
  const source =
    first != null && first.headingLevel != null && first.headingLevel <= 2 && first.text.trim() === title
      ? blocks.slice(1)
      : blocks;
  return source
    .map((block) => block.text.trim())
    .filter((text) => text.length > 0)
    .join("\n\n");
}

function infoValue(bytes: Uint8Array, controlWord: string): string | null {
  const source = latin1(bytes);
  const infoAt = source.indexOf("\\info");
  if (infoAt < 0) return null;
  const end = matchingBrace(source, source.lastIndexOf("{", infoAt));
  if (end < 0) return null;
  const info = source.slice(infoAt, end);
  const match = new RegExp(`\\\\${controlWord}(?:\\s+)([^\\\\{}]*)`, "i").exec(info);
  const value = match?.[1]?.trim() ?? "";
  if (value.length === 0) return null;
  return decodeInfo(value);
}

function decodeInfo(value: string): string {
  const hexed = value.replace(/\\'([0-9a-fA-F]{2})/g, (_match, hex: string) => latin1(Uint8Array.from([Number.parseInt(hex, 16)])));
  return hexed
    .replace(/\\u(-?\d+)\??/g, (_match, raw: string) => {
      const code = Number.parseInt(raw, 10);
      return String.fromCharCode(code < 0 ? code + 65536 : code);
    })
    .trim();
}

function matchingBrace(source: string, openAt: number): number {
  if (openAt < 0) return -1;
  let depth = 0;
  for (let index = openAt; index < source.length; index += 1) {
    if (source[index] === "{") depth += 1;
    if (source[index] === "}") {
      depth -= 1;
      if (depth === 0) return index;
    }
  }
  return -1;
}

function looksLikeRtf(bytes: Uint8Array): boolean {
  const offset = preambleEnd(bytes);
  const header = [0x7b, 0x5c, 0x72, 0x74, 0x66];
  if (bytes.length - offset < header.length) return false;
  return header.every((byte, index) => bytes[offset + index] === byte);
}

function preambleEnd(bytes: Uint8Array): number {
  let offset = 0;
  if (bytes.length >= 3 && bytes[0] === 0xef && bytes[1] === 0xbb && bytes[2] === 0xbf) offset = 3;
  while (offset < bytes.length && isSpace(bytes[offset] ?? 0)) offset += 1;
  return offset;
}

function decodeBytes(bytes: number[], codePage: number): string {
  const buffer = Buffer.from(bytes);
  if (codePage === 65001) return buffer.toString("utf8");
  if (codePage === 936 || codePage === 54936) return iconv.decode(buffer, "gbk");
  return buffer.toString("latin1");
}

function readParameter(bytes: Uint8Array, start: number, end: number): number {
  const raw = latin1(bytes.subarray(start, end));
  const value = Number(raw);
  if (!Number.isSafeInteger(value)) throw new FormatError("corrupt rtf");
  return value;
}

function parseHex(high: number, low: number): number | null {
  const highValue = hexValue(high);
  const lowValue = hexValue(low);
  if (highValue == null || lowValue == null) return null;
  return highValue * 16 + lowValue;
}

function hexValue(byte: number): number | null {
  if (byte >= 0x30 && byte <= 0x39) return byte - 0x30;
  if (byte >= 0x41 && byte <= 0x46) return byte - 0x41 + 10;
  if (byte >= 0x61 && byte <= 0x66) return byte - 0x61 + 10;
  return null;
}

function latin1(bytes: Uint8Array): string {
  return Buffer.from(bytes).toString("latin1");
}

function isAsciiLetter(byte: number): boolean {
  return (byte >= 0x41 && byte <= 0x5a) || (byte >= 0x61 && byte <= 0x7a);
}

function isDigit(byte: number): boolean {
  return byte >= 0x30 && byte <= 0x39;
}

function isSpace(byte: number): boolean {
  return byte === 0x20 || byte === 0x09 || byte === 0x0a || byte === 0x0d;
}

function clamp(value: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, value));
}
