import { unzipSync } from "fflate";
import { XMLParser, XMLValidator } from "fast-xml-parser";

import { FormatError } from "./text-document";

export const docxTextCharLimit = 2 * 1024 * 1024;

const parser = new XMLParser({
  ignoreAttributes: false,
  attributeNamePrefix: "@_",
  removeNSPrefix: true,
  preserveOrder: true,
  trimValues: false,
});

export type OpenedDocx =
  | { kind: "docx"; document: DocxReaderDocument }
  | { kind: "unavailable" }
  | { kind: "corrupt" };

type DocxChapter = {
  title: string;
  body: string;
};

type DocxBlock = {
  text: string;
  headingLevel: number | null;
};

type ParsedDocx = {
  title: string;
  author: string;
  chapters: DocxChapter[];
  truncated: boolean;
};

type OrderedNode = Record<string, unknown>;

export function isDocxName(name: string): boolean {
  return name.toLowerCase().endsWith(".docx");
}

export function openDocxDocument(bytes: Uint8Array | null): OpenedDocx {
  if (bytes == null || bytes.length === 0) return { kind: "unavailable" };
  try {
    return { kind: "docx", document: new DocxReaderDocument(parseDocx(bytes)) };
  } catch (error) {
    if (error instanceof FormatError) return { kind: "corrupt" };
    throw error;
  }
}

export class DocxReaderDocument {
  private sectionIndex = 0;

  constructor(private readonly parsed: ParsedDocx) {}

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

  private get current(): DocxChapter {
    return this.parsed.chapters[this.sectionIndex] ?? { title: "", body: "" };
  }
}

function parseDocx(bytes: Uint8Array): ParsedDocx {
  const files = unzip(bytes);
  const documentFile = files.get("word/document.xml");
  if (documentFile == null) throw new FormatError("corrupt docx");
  const document = parseXml(documentFile);
  const body = firstNamed(document, "body");
  if (body == null) throw new FormatError("corrupt docx");
  const blocks: DocxBlock[] = [];
  for (const child of children(body)) {
    const name = tagName(child);
    if (name === "p") {
      const block = paragraphBlock(child);
      if (block != null) blocks.push(block);
    } else if (name === "tbl") {
      const block = tableBlock(child);
      if (block != null) blocks.push(block);
    }
  }
  if (blocks.length === 0) throw new FormatError("corrupt docx");
  const coreFile = files.get("docprops/core.xml");
  const core = coreFile == null ? [] : parseXml(coreFile);
  const title = firstText(core, "title");
  const author = firstText(core, "creator");
  const built = buildChapters(blocks, title);
  return { title, author, chapters: built.chapters, truncated: built.truncated };
}

function paragraphBlock(paragraph: OrderedNode): DocxBlock | null {
  const text = textContent(paragraph).trim();
  if (text.length === 0) return null;
  const properties = directChild(paragraph, "pPr");
  const level = headingLevel(properties);
  if (level != null) return { text, headingLevel: level };
  return { text: isList(properties) ? `- ${text}` : text, headingLevel: null };
}

function tableBlock(table: OrderedNode): DocxBlock | null {
  const lines: string[] = [];
  let hasContent = false;
  for (const row of children(table)) {
    if (tagName(row) !== "tr") continue;
    const rowText: string[] = [];
    for (const cell of children(row)) {
      if (tagName(cell) !== "tc") continue;
      const cellText: string[] = [];
      for (const child of children(cell)) {
        const name = tagName(child);
        const block = name === "p" ? paragraphBlock(child) : name === "tbl" ? tableBlock(child) : null;
        if (block == null) continue;
        cellText.push(block.text);
      }
      const content = cellText.join("\n");
      if (content.length > 0) hasContent = true;
      rowText.push(content);
    }
    if (rowText.some((value) => value.length > 0)) lines.push(rowText.join("\t"));
  }
  if (!hasContent) return null;
  return { text: lines.join("\n").trim(), headingLevel: null };
}

function headingLevel(properties: OrderedNode | null): number | null {
  if (properties == null) return null;
  const style = attr(directChild(properties, "pStyle"), "val").toLowerCase().replaceAll("-", " ");
  if (style === "title") return 1;
  const match = /(?:heading|标题)\s*([1-6])/.exec(style);
  const level = match?.[1];
  if (level != null) return Number(level);
  const outline = attr(directChild(properties, "outlineLvl"), "val");
  if (!/^\d+$/.test(outline)) return null;
  return clamp(Number(outline) + 1, 1, 6);
}

function isList(properties: OrderedNode | null): boolean {
  if (properties == null) return false;
  if (hasDescendant(properties, "numPr")) return true;
  return attr(directChild(properties, "pStyle"), "val").toLowerCase().includes("list");
}

function buildChapters(blocks: DocxBlock[], fallbackTitle: string): { chapters: DocxChapter[]; truncated: boolean } {
  const raw: DocxChapter[] = [];
  let current: DocxBlock[] = [];
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
  if (raw.length === 0) throw new FormatError("corrupt docx");
  const chapters: DocxChapter[] = [];
  let fullLength = 0;
  let truncated = false;
  for (const chapter of raw) {
    if (fullLength >= docxTextCharLimit) {
      truncated = true;
      break;
    }
    const remaining = docxTextCharLimit - fullLength;
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
  if (chapters.length === 0) throw new FormatError("corrupt docx");
  return { chapters, truncated };
}

function chapterBody(blocks: DocxBlock[], title: string): string {
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

function unzip(bytes: Uint8Array): Map<string, Uint8Array> {
  let entries: Record<string, Uint8Array>;
  try {
    entries = unzipSync(bytes);
  } catch {
    throw new FormatError("corrupt docx");
  }
  const files = new Map<string, Uint8Array>();
  for (const [name, data] of Object.entries(entries)) {
    files.set(normalizePath(name), data);
  }
  return files;
}

function parseXml(bytes: Uint8Array): OrderedNode[] {
  let xml: string;
  try {
    xml = new TextDecoder("utf-8", { fatal: true }).decode(bytes);
  } catch {
    throw new FormatError("corrupt docx");
  }
  if (XMLValidator.validate(xml) !== true) throw new FormatError("corrupt docx");
  try {
    return asNodes(parser.parse(xml));
  } catch {
    throw new FormatError("corrupt docx");
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

function firstNamed(nodes: OrderedNode[], name: string): OrderedNode | null {
  for (const node of nodes) {
    if (tagName(node) === name) return node;
    const found = firstNamed(children(node), name);
    if (found != null) return found;
  }
  return null;
}

function textContent(node: OrderedNode): string {
  const name = tagName(node);
  if (name === "#text") return typeof node["#text"] === "string" ? node["#text"] : "";
  if (name === "tab") return "\t";
  if (name === "br" || name === "cr") return "\n";
  return children(node).map((child) => textContent(child)).join("");
}

function hasDescendant(node: OrderedNode, name: string): boolean {
  for (const child of children(node)) {
    if (tagName(child) === name || hasDescendant(child, name)) return true;
  }
  return false;
}

function directChild(node: OrderedNode, name: string): OrderedNode | null {
  for (const child of children(node)) {
    if (tagName(child) === name) return child;
  }
  return null;
}

function children(node: OrderedNode): OrderedNode[] {
  const name = tagName(node);
  return asNodes(node[name]);
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

function attr(node: OrderedNode | null, name: string): string {
  if (node == null) return "";
  const attrs = node[":@"];
  if (attrs == null || typeof attrs !== "object") return "";
  const value = (attrs as Record<string, unknown>)[`@_${name}`];
  return typeof value === "string" ? value : "";
}

function normalizePath(path: string): string {
  return path.replaceAll("\\", "/").replace(/^\/+/, "").toLowerCase();
}

function clamp(value: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, value));
}
