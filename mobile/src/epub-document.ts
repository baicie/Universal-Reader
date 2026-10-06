import { Buffer } from "buffer";
import { unzipSync } from "fflate";
import { XMLParser } from "fast-xml-parser";

import { decodeTextBytes, FormatError, stripHtml } from "./text-document";

const EPUB_TEXT_LIMIT = 2 * 1024 * 1024;

const xmlParser = new XMLParser({
  ignoreAttributes: false,
  attributeNamePrefix: "@_",
  removeNSPrefix: true,
  isArray: (name) =>
    ["ol", "li", "a", "nav", "navPoint", "item", "itemref", "rootfile"].includes(name),
});

const scriptBlock = /<script\b[^>]*>[\s\S]*?<\/script>/gi;
const scriptEmpty = /<script\b[^>]*\/>/gi;
const eventHandlerAttr = /\s+on[a-z]{3,}\s*=\s*(?:"[^"]*"|'[^']*'|[^\s>]+)/gi;
const imgSrc = /<img\b([^>]*?)\bsrc\s*=\s*(["'])([^"']+)\2([^>]*)>/gi;

type XmlNode = Record<string, unknown>;

export type EpubTocItem = {
  title: string;
  href: string;
  fragment: string | null;
  children: EpubTocItem[];
};

type EpubChapter = {
  href: string;
  title: string;
  text: string;
  html: string;
};

export type EpubSearchHit = {
  title: string;
  excerpt: string;
  href: string;
};

export type OpenedEpub =
  | { kind: "epub"; document: EpubReaderDocument }
  | { kind: "unavailable" }
  | { kind: "corrupt" };

export function isEpubName(name: string): boolean {
  return name.toLowerCase().endsWith(".epub");
}

export function openEpubDocument(bytes: Uint8Array | null): OpenedEpub {
  if (bytes == null || bytes.length === 0) return { kind: "unavailable" };
  try {
    return { kind: "epub", document: EpubReaderDocument.parse(bytes) };
  } catch (error) {
    if (error instanceof FormatError) return { kind: "corrupt" };
    throw error;
  }
}

export class EpubReaderDocument {
  private sectionIndex = 0;

  private constructor(
    readonly title: string,
    readonly author: string,
    private readonly chapters: EpubChapter[],
    private readonly navItems: EpubTocItem[],
    readonly truncated: boolean,
  ) {}

  static parse(bytes: Uint8Array): EpubReaderDocument {
    const files = readZip(bytes);
    const container = parseXml(readRequired(files, "meta-inf/container.xml"));
    const rootPath = attr(asArray(child(container, "container", "rootfiles", "rootfile"))[0], "full-path");
    if (rootPath == null) throw new FormatError("corrupt epub");
    const opfPath = normalizePath(rootPath);
    const opf = parseXml(readRequired(files, opfPath));
    const metadata = child(opf, "package", "metadata");
    const title = textContent(isNode(metadata) ? metadata.title : "") ?? "";
    const author = textContent(isNode(metadata) ? metadata.creator : "") ?? "";
    const manifest = readManifest(opf, opfPath);
    const spineHrefs = readSpine(opf, manifest);
    if (spineHrefs.length === 0) throw new FormatError("corrupt epub");
    const titles = navTitles(files, manifest);
    const navItems = navTocItems(files, manifest);
    const chapters: EpubChapter[] = [];
    let fullLength = 0;
    let truncated = false;
    for (const href of spineHrefs) {
      if (fullLength >= EPUB_TEXT_LIMIT) {
        truncated = true;
        break;
      }
      const raw = tryRead(files, href);
      if (raw == null) continue;
      let body = stripHtml(raw).trim();
      if (body.length === 0) continue;
      if (fullLength + body.length > EPUB_TEXT_LIMIT) {
        body = body.slice(0, EPUB_TEXT_LIMIT - fullLength);
        truncated = true;
      }
      chapters.push({
        href,
        title: titles.get(href) ?? firstLine(body),
        text: body,
        html: inlineChapterHtml(raw, href, files),
      });
      fullLength += body.length;
      if (truncated) break;
    }
    if (chapters.length === 0) throw new FormatError("corrupt epub");
    return new EpubReaderDocument(title, author, chapters, navItems, truncated);
  }

  get chapterIndex(): number {
    return this.sectionIndex;
  }

  get chapterCount(): number {
    return this.chapters.length;
  }

  get currentChapterTitle(): string {
    return this.current.title;
  }

  get currentChapterText(): string {
    return this.current.text;
  }

  get currentChapterHtml(): string {
    return this.current.html;
  }

  get currentChapterHref(): string {
    return this.current.href;
  }

  toc(): EpubTocItem[] {
    return tocFromSpine(this.chapters, this.navItems);
  }

  indexOfHref(href: string): number {
    return this.chapters.findIndex((chapter) => sameHref(chapter.href, href));
  }

  goTo(href: string): boolean {
    const index = this.indexOfHref(href);
    if (index < 0) return false;
    this.sectionIndex = index;
    return true;
  }

  moveTo(index: number): void {
    if (this.chapterCount === 0) return;
    this.sectionIndex = Math.min(Math.max(index, 0), this.chapterCount - 1);
  }

  next(): void {
    if (this.sectionIndex < this.chapterCount - 1) this.sectionIndex += 1;
  }

  previous(): void {
    if (this.sectionIndex > 0) this.sectionIndex -= 1;
  }

  search(query: string): EpubSearchHit[] {
    if (query.length === 0) return [];
    const hits: EpubSearchHit[] = [];
    for (const chapter of this.chapters) {
      const at = chapter.text.indexOf(query);
      if (at < 0) continue;
      hits.push({
        title: chapter.title.length > 0 ? chapter.title : this.title,
        excerpt: excerptAround(chapter.text, at, query.length),
        href: chapter.href,
      });
      if (hits.length >= 10) break;
    }
    return hits;
  }

  private get current(): EpubChapter {
    const index = Math.min(Math.max(this.sectionIndex, 0), this.chapters.length - 1);
    return this.chapters[index] ?? { href: "", title: "", text: "", html: "" };
  }
}

function readZip(bytes: Uint8Array): Map<string, Uint8Array> {
  let entries: Record<string, Uint8Array>;
  try {
    entries = unzipSync(bytes);
  } catch {
    throw new FormatError("corrupt epub");
  }
  const files = new Map<string, Uint8Array>();
  for (const [name, data] of Object.entries(entries)) {
    if (name.endsWith("/")) continue;
    files.set(normalizePath(name), data);
  }
  if (files.size === 0) throw new FormatError("corrupt epub");
  return files;
}

function readRequired(files: Map<string, Uint8Array>, path: string): string {
  const text = tryRead(files, path);
  if (text == null) throw new FormatError("corrupt epub");
  return text;
}

function tryRead(files: Map<string, Uint8Array>, path: string): string | null {
  const bytes = files.get(normalizePath(path));
  if (bytes == null) return null;
  return decodeTextBytes(bytes);
}

function parseXml(source: string): XmlNode {
  try {
    const parsed = xmlParser.parse(source);
    if (!isNode(parsed)) throw new FormatError("corrupt epub");
    return parsed;
  } catch (error) {
    if (error instanceof FormatError) throw error;
    throw new FormatError("corrupt epub");
  }
}

function readManifest(opf: XmlNode, opfPath: string): Map<string, string> {
  const manifest = new Map<string, string>();
  for (const item of asArray(child(opf, "package", "manifest", "item"))) {
    const id = attr(item, "id");
    const href = attr(item, "href");
    if (id == null || href == null) continue;
    manifest.set(id, resolveHref(opfPath, href));
  }
  return manifest;
}

function readSpine(opf: XmlNode, manifest: Map<string, string>): string[] {
  const hrefs: string[] = [];
  for (const item of asArray(child(opf, "package", "spine", "itemref"))) {
    if (attr(item, "linear") === "no") continue;
    const href = manifest.get(attr(item, "idref") ?? "");
    if (href != null) hrefs.push(href);
  }
  return hrefs;
}

function navTitles(files: Map<string, Uint8Array>, manifest: Map<string, string>): Map<string, string> {
  const titles = new Map<string, string>();
  for (const href of manifest.values()) {
    if (!href.endsWith(".xhtml") && !href.endsWith(".html")) continue;
    const raw = tryRead(files, href);
    if (raw == null || !raw.includes('epub:type="toc"')) continue;
    try {
      for (const anchor of collectAnchors(parseXml(raw))) {
        const target = attr(anchor, "href");
        const label = textContent(anchor);
        if (target == null || label.length === 0) continue;
        const key = resolveHref(href, target);
        if (!titles.has(key)) titles.set(key, label);
      }
    } catch {
      // A damaged nav falls back to the chapter text. The book still opens.
    }
  }
  if (titles.size > 0) return titles;
  const ncxHref = [...manifest.values()].find((href) => href.endsWith(".ncx"));
  if (ncxHref == null) return titles;
  const ncxRaw = tryRead(files, ncxHref);
  if (ncxRaw == null) return titles;
  try {
    for (const point of asArray(child(parseXml(ncxRaw), "ncx", "navMap", "navPoint"))) {
      collectNcxTitles(point, ncxHref, titles);
    }
  } catch {
    // A damaged NCX falls back to the chapter text.
  }
  return titles;
}

function collectNcxTitles(point: XmlNode, ncxHref: string, titles: Map<string, string>): void {
  const label = textContent(isNode(point.navLabel) ? point.navLabel.text : "");
  const src = attr(point.content, "src");
  if (src != null && label.length > 0 && !titles.has(resolveHref(ncxHref, src))) {
    titles.set(resolveHref(ncxHref, src), label);
  }
  for (const childPoint of asArray(point.navPoint)) collectNcxTitles(childPoint, ncxHref, titles);
}

function navTocItems(files: Map<string, Uint8Array>, manifest: Map<string, string>): EpubTocItem[] {
  for (const href of manifest.values()) {
    if (!href.endsWith(".xhtml") && !href.endsWith(".html")) continue;
    const raw = tryRead(files, href);
    if (raw == null || !raw.includes('epub:type="toc"')) continue;
    try {
      const nav = asArray(child(parseXml(raw), "html", "body", "nav")).find(
        (item) => attr(item, "type") === "toc",
      );
      const list = nav == null ? undefined : asArray(nav.ol)[0];
      if (list == null) continue;
      const items = navListItems(list, href);
      if (items.length > 0) return items;
    } catch {
      // A damaged nav falls back to the spine list.
    }
  }
  const ncxHref = [...manifest.values()].find((href) => href.endsWith(".ncx"));
  if (ncxHref == null) return [];
  const ncxRaw = tryRead(files, ncxHref);
  if (ncxRaw == null) return [];
  try {
    return ncxItems(asArray(child(parseXml(ncxRaw), "ncx", "navMap", "navPoint")), ncxHref);
  } catch {
    return [];
  }
}

function navListItems(ol: XmlNode, navHref: string): EpubTocItem[] {
  const items: EpubTocItem[] = [];
  for (const li of asArray(ol.li)) {
    const anchor = asArray(li.a)[0];
    const nested = asArray(li.ol)[0];
    if (anchor == null) {
      if (nested != null) items.push(...navListItems(nested, navHref));
      continue;
    }
    const href = attr(anchor, "href");
    const title = textContent(anchor);
    if (href == null || title.length === 0) continue;
    items.push({
      title,
      href: resolveHref(navHref, href),
      fragment: hrefFragment(href),
      children: nested == null ? [] : navListItems(nested, navHref),
    });
  }
  return items;
}

function ncxItems(points: XmlNode[], ncxHref: string): EpubTocItem[] {
  const items: EpubTocItem[] = [];
  for (const point of points) {
    const label = textContent(isNode(point.navLabel) ? point.navLabel.text : "");
    const src = attr(point.content, "src");
    if (src == null || label.length === 0) continue;
    const nested = asArray(point.navPoint);
    items.push({
      title: label,
      href: resolveHref(ncxHref, src),
      fragment: hrefFragment(src),
      children: nested.length === 0 ? [] : ncxItems(nested, ncxHref),
    });
  }
  return items;
}

function tocFromSpine(chapters: EpubChapter[], navItems: EpubTocItem[]): EpubTocItem[] {
  if (navItems.length === 0) {
    return chapters.map((chapter) => ({
      title: chapter.title,
      href: chapter.href,
      fragment: null,
      children: [],
    }));
  }
  const used = navItems.map(() => false);
  return chapters.map((chapter) => {
    for (let index = 0; index < navItems.length; index += 1) {
      if (used[index]) continue;
      const item = navItems[index];
      if (item == null || !sameHref(item.href, chapter.href)) continue;
      used[index] = true;
      return {
        title: item.title.length > 0 ? item.title : chapter.title,
        href: chapter.href,
        fragment: null,
        children: item.children,
      };
    }
    return { title: chapter.title, href: chapter.href, fragment: null, children: [] };
  });
}

function inlineChapterHtml(
  html: string,
  chapterHref: string,
  files: Map<string, Uint8Array>,
): string {
  const stripped = html.replace(scriptBlock, "").replace(scriptEmpty, "").replace(eventHandlerAttr, "");
  return stripped.replace(imgSrc, (match, before: string, quote: string, src: string, after: string) => {
    if (src.startsWith("data:") || isExternalHref(src)) return match;
    const dataUri = dataUriFor(files, resolveHref(chapterHref, src));
    if (dataUri == null) return match;
    return `<img${before}src=${quote}${dataUri}${quote}${after}>`;
  });
}

function dataUriFor(files: Map<string, Uint8Array>, path: string): string | null {
  const bytes = files.get(normalizePath(path));
  if (bytes == null) return null;
  const extension = path.split(".").pop()?.toLowerCase() ?? "";
  const mime =
    extension === "png"
      ? "image/png"
      : extension === "jpg" || extension === "jpeg"
        ? "image/jpeg"
        : extension === "gif"
          ? "image/gif"
          : extension === "webp"
            ? "image/webp"
            : extension === "svg"
              ? "image/svg+xml"
              : "application/octet-stream";
  return `data:${mime};base64,${Buffer.from(bytes).toString("base64")}`;
}

function isExternalHref(href: string): boolean {
  const lower = href.trim().toLowerCase();
  return (
    lower.startsWith("https://") ||
    lower.startsWith("http://") ||
    lower.startsWith("mailto:") ||
    lower.startsWith("//")
  );
}

function resolveHref(basePath: string, href: string): string {
  const cleaned = (href.split("#")[0] ?? "").replaceAll("\\", "/");
  let decoded = cleaned;
  try {
    decoded = decodeURIComponent(cleaned);
  } catch {
    decoded = cleaned;
  }
  const slash = basePath.replaceAll("\\", "/").lastIndexOf("/");
  const dir = slash < 0 ? "" : basePath.slice(0, slash + 1);
  return normalizePath(decoded.startsWith("/") ? decoded : `${dir}${decoded}`);
}

function hrefFragment(raw: string): string | null {
  const hash = raw.indexOf("#");
  if (hash < 0 || hash === raw.length - 1) return null;
  const fragment = raw.slice(hash + 1);
  if (fragment.length === 0) return null;
  try {
    return decodeURIComponent(fragment);
  } catch {
    return fragment;
  }
}

function normalizePath(path: string): string {
  const parts: string[] = [];
  for (const part of path.replaceAll("\\", "/").split("/")) {
    if (part.length === 0 || part === ".") continue;
    if (part === "..") {
      parts.pop();
      continue;
    }
    parts.push(part);
  }
  return parts.join("/").toLowerCase();
}

function sameHref(left: string, right: string): boolean {
  const a = normalizePath(left);
  const b = normalizePath(right);
  return a === b || a.endsWith(b) || b.endsWith(a);
}

function firstLine(body: string): string {
  const line = body.split("\n")[0]?.trim() ?? "";
  return Array.from(line).length <= 40 ? line : "";
}

function excerptAround(text: string, start: number, queryLength: number): string {
  const from = start < 24 ? 0 : start - 24;
  const to = Math.min(text.length, start + queryLength + 24);
  return text.slice(from, to).trim();
}

function collectAnchors(node: unknown, out: XmlNode[] = []): XmlNode[] {
  if (Array.isArray(node)) {
    for (const item of node) collectAnchors(item, out);
    return out;
  }
  if (!isNode(node)) return out;
  for (const anchor of asArray(node.a)) out.push(anchor);
  for (const value of Object.values(node)) {
    if (value !== node.a) collectAnchors(value, out);
  }
  return out;
}

function child(node: XmlNode, ...names: string[]): unknown {
  let current: unknown = node;
  for (const name of names) {
    if (!isNode(current)) return undefined;
    current = current[name];
  }
  return current;
}

function asArray(value: unknown): XmlNode[] {
  if (Array.isArray(value)) return value.filter(isNode);
  if (isNode(value)) return [value];
  return [];
}

function isNode(value: unknown): value is XmlNode {
  return value != null && typeof value === "object" && !Array.isArray(value);
}

function attr(node: unknown, name: string): string | null {
  if (!isNode(node)) return null;
  const value = node[`@_${name}`];
  return typeof value === "string" && value.length > 0 ? value : null;
}

function textContent(value: unknown): string {
  if (typeof value === "string" || typeof value === "number") return String(value).trim();
  if (!isNode(value)) return "";
  const text = value["#text"];
  if (typeof text === "string" || typeof text === "number") return String(text).trim();
  return "";
}
