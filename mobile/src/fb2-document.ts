import { Buffer } from "buffer";
import { XMLParser } from "fast-xml-parser";

import { decodeTextBytes, FormatError } from "./text-document";

const parser = new XMLParser({
  ignoreAttributes: false,
  attributeNamePrefix: "@_",
  removeNSPrefix: true,
  preserveOrder: true,
  trimValues: false,
});

const blockNames = new Set(["p", "subtitle", "poem", "epigraph", "cite", "table", "annotation"]);
const leadNames = new Set(["epigraph", "cite", "subtitle", "poem", "table", "annotation", "title", "p"]);

type OrderedNode = Record<string, unknown>;

export type OpenedFb2 =
  | { kind: "fb2"; document: Fb2ReaderDocument }
  | { kind: "unavailable" }
  | { kind: "corrupt" };

type Fb2Chapter = {
  title: string;
  body: string;
};

type ParsedFb2 = {
  title: string;
  author: string;
  chapters: Fb2Chapter[];
};

export function isFb2Name(name: string): boolean {
  return name.toLowerCase().endsWith(".fb2");
}

export function openFb2Document(bytes: Uint8Array | null): OpenedFb2 {
  if (bytes == null || bytes.length === 0) return { kind: "unavailable" };
  try {
    return { kind: "fb2", document: new Fb2ReaderDocument(parseFb2(bytes)) };
  } catch (error) {
    if (error instanceof FormatError) return { kind: "corrupt" };
    throw error;
  }
}

export function fb2CoverBytes(bytes: Uint8Array): Uint8Array | null {
  if (bytes.length === 0) return null;
  let root: OrderedNode;
  try {
    const found = fictionBook(parseOrdered(bytes));
    if (found == null) return null;
    root = found;
  } catch (error) {
    if (error instanceof FormatError) return null;
    throw error;
  }
  const href = coverHref(root);
  if (href == null) return null;
  const lower = href.toLowerCase();
  if (lower.startsWith("http://") || lower.startsWith("https://") || lower.startsWith("//")) return null;
  const id = href.startsWith("#") ? href.slice(1) : href;
  if (id.length === 0) return null;
  for (const node of descendants(root)) {
    if (tagName(node) !== "binary") continue;
    const binaryId = attr(node, "id").trim();
    if (binaryId !== id && binaryId.toLowerCase() !== id.toLowerCase()) continue;
    return decodeBinary(textContent(node));
  }
  return null;
}

export class Fb2ReaderDocument {
  private sectionIndex = 0;

  constructor(private readonly parsed: ParsedFb2) {}

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
    return false;
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

  private get current(): Fb2Chapter {
    return this.parsed.chapters[this.sectionIndex] ?? { title: "", body: "" };
  }
}

function parseFb2(bytes: Uint8Array): ParsedFb2 {
  const root = fictionBook(parseOrdered(bytes));
  if (root == null) throw new FormatError("corrupt fb2");
  const chapters: Fb2Chapter[] = [];
  const blurb = annotationText(root);
  if (blurb != null) {
    const line = blurb.split("\n")[0]?.trim() ?? "";
    chapters.push({ title: line.length > 0 ? line : firstLine(blurb), body: blurb });
  }
  const deferred: OrderedNode[] = [];
  let bodyChapters = 0;
  for (const body of childElements(root, "body")) {
    if (hasSection(body)) {
      let prefix = bodyLead(body);
      for (const section of sectionsIn(body)) {
        const chapter = emitChapter(section, prefix);
        if (chapter == null) continue;
        chapters.push(chapter);
        bodyChapters += 1;
        prefix = [];
      }
      continue;
    }
    const name = attr(body, "name").trim().toLowerCase();
    if (name === "notes" || name === "comments") {
      deferred.push(body);
      continue;
    }
    const chapter = emitChapter(body, []);
    if (chapter != null) {
      chapters.push(chapter);
      bodyChapters += 1;
    }
  }
  if (bodyChapters > 0) {
    for (const body of deferred) {
      const chapter = emitChapter(body, []);
      if (chapter != null) chapters.push(chapter);
    }
  }
  if (bodyChapters === 0) throw new FormatError("corrupt fb2");
  const first = firstText(root, "first-name");
  const last = firstText(root, "last-name");
  return {
    title: firstText(root, "book-title"),
    author: [first, last].filter((part) => part.length > 0).join(" "),
    chapters,
  };
}

function parseOrdered(bytes: Uint8Array): unknown {
  try {
    return parser.parse(decodeTextBytes(bytes));
  } catch {
    throw new FormatError("corrupt fb2");
  }
}

function fictionBook(parsed: unknown): OrderedNode | null {
  if (!Array.isArray(parsed)) return null;
  for (const node of parsed) {
    if (!isNode(node)) continue;
    const name = tagName(node);
    if (name === "fictionbook") return node;
  }
  return null;
}

function emitChapter(node: OrderedNode, prefix: string[]): Fb2Chapter | null {
  const local = tagName(node);
  const kids = childTags(node);
  if (local === "section" && kids.length > 0 && kids.every((child) => tagName(child) === "section")) return null;
  const heading = local === "body" ? "" : sectionTitle(node);
  const blocks = kids
    .filter((child) => blockNames.has(tagName(child) ?? ""))
    .map((child) => textContent(child).trim())
    .filter((text) => text.length > 0);
  const body = [...prefix, ...blocks].join("\n\n");
  if (heading.length === 0 && body.length === 0) return null;
  return { title: heading.length > 0 ? heading : firstLine(body), body };
}

function bodyLead(body: OrderedNode): string[] {
  const name = attr(body, "name").trim().toLowerCase();
  if (name === "notes" || name === "comments") return [];
  const texts: string[] = [];
  for (const child of childTags(body)) {
    const local = tagName(child) ?? "";
    if (local === "section") break;
    if (!leadNames.has(local)) continue;
    const text = textContent(child).trim();
    if (text.length > 0) texts.push(text);
  }
  return texts;
}

function hasSection(node: OrderedNode): boolean {
  return sectionsIn(node).length > 0;
}

function sectionsIn(node: OrderedNode): OrderedNode[] {
  const found: OrderedNode[] = [];
  for (const child of childTags(node)) {
    if (tagName(child) === "section") found.push(child);
    found.push(...sectionsIn(child));
  }
  return found;
}

function sectionTitle(node: OrderedNode): string {
  for (const child of childTags(node)) {
    if (tagName(child) === "title") return textContent(child).trim();
  }
  return "";
}

function annotationText(root: OrderedNode): string | null {
  for (const description of childElements(root, "description")) {
    for (const info of childElements(description, "title-info")) {
      for (const child of childElements(info, "annotation")) {
        const text = textContent(child).trim();
        if (text.length > 0) return text;
      }
    }
  }
  return null;
}

function coverHref(root: OrderedNode): string | null {
  for (const description of childElements(root, "description")) {
    for (const info of childElements(description, "title-info")) {
      for (const page of childElements(info, "coverpage")) {
        for (const image of childElements(page, "image")) {
          const href = attr(image, "href").trim();
          if (href.length > 0) return href;
        }
      }
    }
  }
  return null;
}

function firstText(node: OrderedNode, name: string): string {
  if (tagName(node) === name) {
    const text = textContent(node).trim();
    if (text.length > 0) return text;
  }
  for (const child of childTags(node)) {
    const text = firstText(child, name);
    if (text.length > 0) return text;
  }
  return "";
}

function descendants(node: OrderedNode): OrderedNode[] {
  const found: OrderedNode[] = [];
  for (const child of childTags(node)) {
    found.push(child, ...descendants(child));
  }
  return found;
}

function childElements(node: OrderedNode, name: string): OrderedNode[] {
  return childTags(node).filter((child) => tagName(child) === name);
}

function childTags(node: OrderedNode): OrderedNode[] {
  return childrenOf(node).filter((child) => {
    const name = tagName(child);
    return name != null && name !== "#text";
  });
}

function childrenOf(node: OrderedNode): OrderedNode[] {
  const name = Object.keys(node).find((key) => key !== ":@");
  if (name == null) return [];
  const value = node[name];
  if (!Array.isArray(value)) return [];
  return value.filter(isNode);
}

function textContent(node: OrderedNode): string {
  if (typeof node["#text"] === "string") return node["#text"];
  return childrenOf(node).map(textContent).join("");
}

function tagName(node: OrderedNode): string | null {
  const name = Object.keys(node).find((key) => key !== ":@");
  return name == null ? null : name.toLowerCase();
}

function attr(node: OrderedNode, local: string): string {
  const attrs = node[":@"];
  if (attrs == null || typeof attrs !== "object") return "";
  for (const [key, value] of Object.entries(attrs)) {
    const bare = key.startsWith("@_") ? key.slice(2) : key;
    if (bare.toLowerCase() === local && typeof value === "string") return value;
  }
  return "";
}

function decodeBinary(text: string): Uint8Array | null {
  const compact = text.replace(/\s+/g, "");
  if (compact.length === 0 || !/^[A-Za-z0-9+/]+={0,2}$/.test(compact)) return null;
  const decoded = Buffer.from(compact, "base64");
  return decoded.length === 0 ? null : new Uint8Array(decoded);
}

function firstLine(text: string): string {
  const line = text.split("\n")[0]?.trim() ?? "";
  return Array.from(line).length <= 40 ? line : "";
}

function isNode(value: unknown): value is OrderedNode {
  return value != null && typeof value === "object" && !Array.isArray(value);
}
