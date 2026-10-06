import { unzipSync } from "fflate";
import { XMLParser, XMLValidator } from "fast-xml-parser";

import { FormatError } from "./text-document";

export const odtTextCharLimit = 2 * 1024 * 1024;
const odtMime = "application/vnd.oasis.opendocument.text";

const parser = new XMLParser({
  ignoreAttributes: false,
  attributeNamePrefix: "@_",
  removeNSPrefix: true,
  preserveOrder: true,
  trimValues: false,
});

export type OpenedOdt =
  | { kind: "odt"; document: OdtReaderDocument }
  | { kind: "unavailable" }
  | { kind: "corrupt" };

type OdtChapter = {
  title: string;
  body: string;
};

type OdtBlock = {
  text: string;
  headingLevel: number | null;
};

type ParsedOdt = {
  title: string;
  author: string;
  chapters: OdtChapter[];
  truncated: boolean;
};

type OrderedNode = Record<string, unknown>;

export function isOdtName(name: string): boolean {
  return name.toLowerCase().endsWith(".odt");
}

export function openOdtDocument(bytes: Uint8Array | null): OpenedOdt {
  if (bytes == null || bytes.length === 0) return { kind: "unavailable" };
  try {
    return { kind: "odt", document: new OdtReaderDocument(parseOdt(bytes)) };
  } catch (error) {
    if (error instanceof FormatError) return { kind: "corrupt" };
    throw error;
  }
}

export class OdtReaderDocument {
  private sectionIndex = 0;

  constructor(private readonly parsed: ParsedOdt) {}

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

  private get current(): OdtChapter {
    return this.parsed.chapters[this.sectionIndex] ?? { title: "", body: "" };
  }
}

function parseOdt(bytes: Uint8Array): ParsedOdt {
  const files = unzip(bytes);
  const mime = files.get("mimetype");
  if (mime == null || decodeXml(mime).trim() !== odtMime) throw new FormatError("corrupt odt");
  const contentFile = files.get("content.xml");
  if (contentFile == null) throw new FormatError("corrupt odt");
  const text = documentText(parseXml(contentFile));
  if (text == null) throw new FormatError("corrupt odt");
  const blocks = blocksFrom(text);
  if (blocks.length === 0) throw new FormatError("corrupt odt");
  const metaFile = files.get("meta.xml");
  const meta = metaFile == null ? [] : parseXml(metaFile);
  const title = firstText(meta, "title").trim();
  const author = (firstText(meta, "creator") || firstText(meta, "initial-creator")).trim();
  const built = buildChapters(blocks, title);
  return { title, author, chapters: built.chapters, truncated: built.truncated };
}

function blocksFrom(container: OrderedNode): OdtBlock[] {
  const blocks: OdtBlock[] = [];
  for (const child of children(container)) {
    const name = tagName(child);
    if (name === "h") {
      const block = headingBlock(child);
      if (block != null) blocks.push(block);
    } else if (name === "p") {
      const block = paragraphBlock(child);
      if (block != null) blocks.push(block);
    } else if (name === "list") {
      const block = listBlock(child);
      if (block != null) blocks.push(block);
    } else if (name === "table") {
      const block = tableBlock(child);
      if (block != null) blocks.push(block);
    } else if (name === "section") {
      blocks.push(...blocksFrom(child));
    }
  }
  return blocks;
}

function headingBlock(heading: OrderedNode): OdtBlock | null {
  const text = textContent(heading).trim();
  if (text.length === 0) return null;
  const outline = integerAttr(attr(heading, "outline-level"));
  const level = clamp(outline ?? headingLevelFromStyle(attr(heading, "style-name")) ?? 1, 1, 6);
  return { text, headingLevel: level };
}

function paragraphBlock(paragraph: OrderedNode): OdtBlock | null {
  const text = textContent(paragraph).trim();
  if (text.length === 0) return null;
  return { text, headingLevel: null };
}

function listBlock(list: OrderedNode): OdtBlock | null {
  const lines: string[] = [];
  for (const item of children(list)) {
    if (tagName(item) !== "list-item") continue;
    const itemText = blocksFrom(item)
      .map((block) => block.text.trim())
      .filter((value) => value.length > 0)
      .join("\n");
    if (itemText.length === 0) continue;
    lines.push(`- ${itemText}`);
  }
  if (lines.length === 0) return null;
  return { text: lines.join("\n"), headingLevel: null };
}

function tableBlock(table: OrderedNode): OdtBlock | null {
  const lines: string[] = [];
  let hasContent = false;
  for (const row of children(table)) {
    if (tagName(row) !== "table-row") continue;
    const rowText: string[] = [];
    for (const cell of children(row)) {
      if (tagName(cell) !== "table-cell") continue;
      const cellText = blocksFrom(cell)
        .map((block) => block.text.trim())
        .filter((value) => value.length > 0)
        .join("\n");
      if (cellText.length > 0) hasContent = true;
      rowText.push(cellText);
    }
    if (rowText.some((value) => value.length > 0)) lines.push(rowText.join("\t"));
  }
  if (!hasContent) return null;
  return { text: lines.join("\n").trim(), headingLevel: null };
}

function textContent(node: OrderedNode): string {
  let output = "";
  for (const child of children(node)) {
    const name = tagName(child);
    if (name === "#text") output += typeof child["#text"] === "string" ? child["#text"] : "";
    else if (name === "s") output += " ".repeat(clamp(integerAttr(attr(child, "c")) ?? 1, 1, 100));
    else if (name === "tab") output += "\t";
    else if (name === "line-break") output += "\n";
    else if (name === "note") continue;
    else output += textContent(child);
  }
  return output;
}

function headingLevelFromStyle(styleName: string): number | null {
  const normalized = styleName.replaceAll("_20_", " ").replaceAll("_", " ").toLowerCase();
  const match = /(?:heading|标题)\s*([1-6])/.exec(normalized);
  const level = match?.[1];
  return level == null ? null : Number(level);
}

function buildChapters(blocks: OdtBlock[], fallbackTitle: string): { chapters: OdtChapter[]; truncated: boolean } {
  const raw: OdtChapter[] = [];
  let current: OdtBlock[] = [];
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
  if (raw.length === 0) throw new FormatError("corrupt odt");
  const chapters: OdtChapter[] = [];
  let fullLength = 0;
  let truncated = false;
  for (const chapter of raw) {
    if (fullLength >= odtTextCharLimit) {
      truncated = true;
      break;
    }
    const remaining = odtTextCharLimit - fullLength;
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
  if (chapters.length === 0) throw new FormatError("corrupt odt");
  return { chapters, truncated };
}

function chapterBody(blocks: OdtBlock[], title: string): string {
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

function documentText(nodes: OrderedNode[]): OrderedNode | null {
  for (const body of named(nodes, "body")) {
    const text = directChild(body, "text");
    if (text != null) return text;
  }
  return null;
}

function unzip(bytes: Uint8Array): Map<string, Uint8Array> {
  let entries: Record<string, Uint8Array>;
  try {
    entries = unzipSync(bytes);
  } catch {
    throw new FormatError("corrupt odt");
  }
  const files = new Map<string, Uint8Array>();
  for (const [name, data] of Object.entries(entries)) files.set(normalizePath(name), data);
  return files;
}

function parseXml(bytes: Uint8Array): OrderedNode[] {
  const xml = decodeXml(bytes);
  if (XMLValidator.validate(xml) !== true) throw new FormatError("corrupt odt");
  try {
    return asNodes(parser.parse(xml));
  } catch {
    throw new FormatError("corrupt odt");
  }
}

function decodeXml(bytes: Uint8Array): string {
  try {
    return new TextDecoder("utf-8", { fatal: true }).decode(bytes);
  } catch {
    throw new FormatError("corrupt odt");
  }
}

function firstText(nodes: OrderedNode[], name: string): string {
  for (const node of nodes) {
    if (tagName(node) === name) {
      const text = textContent(node).trim();
      if (text.length > 0) return text;
    }
    const nested = firstText(children(node), name);
    if (nested.length > 0) return nested;
  }
  return "";
}

function named(nodes: OrderedNode[], name: string): OrderedNode[] {
  const found: OrderedNode[] = [];
  for (const node of nodes) {
    if (tagName(node) === name) found.push(node);
    found.push(...named(children(node), name));
  }
  return found;
}

function directChild(node: OrderedNode, name: string): OrderedNode | null {
  for (const child of children(node)) {
    if (tagName(child) === name) return child;
  }
  return null;
}

function children(node: OrderedNode): OrderedNode[] {
  return asNodes(node[tagName(node)]);
}

function asNodes(value: unknown): OrderedNode[] {
  if (!Array.isArray(value)) return [];
  return value.filter((item): item is OrderedNode => item != null && typeof item === "object");
}

function tagName(node: OrderedNode): string {
  for (const key of Object.keys(node)) {
    if (key !== ":@") return key;
  }
  return "";
}

function attr(node: OrderedNode, name: string): string {
  const attrs = node[":@"];
  if (attrs == null || typeof attrs !== "object") return "";
  const value = (attrs as Record<string, unknown>)[`@_${name}`];
  return typeof value === "string" ? value : "";
}

function integerAttr(raw: string): number | null {
  if (!/^-?\d+$/.test(raw)) return null;
  return Number(raw);
}

function normalizePath(path: string): string {
  return path.replaceAll("\\", "/").replace(/^\/+/, "").toLowerCase();
}

function clamp(value: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, value));
}
