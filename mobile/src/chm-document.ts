import type { ChmFile } from "chmlib-ts";

import { stripHtml } from "./text-document";

type ChmChapter = {
  title: string;
  body: string;
};

export type OpenedChm =
  | { kind: "chm"; document: ChmReaderDocument }
  | { kind: "unavailable" }
  | { kind: "corrupt" };

export function isChmName(name: string): boolean {
  return name.toLowerCase().endsWith(".chm");
}

export async function openChmDocument(bytes: Uint8Array | null): Promise<OpenedChm> {
  if (bytes == null || bytes.length === 0) return { kind: "unavailable" };
  if (bytes.length < 4 || bytes[0] !== 0x49 || bytes[1] !== 0x54 || bytes[2] !== 0x53 || bytes[3] !== 0x46) {
    return { kind: "corrupt" };
  }
  try {
    const chm = await import("chmlib-ts");
    const file = await chm.ChmFile.open(chm.chmReaderFromBuffer(bytes));
    try {
      const chapters = await htmlChapters(file, chm.ChmEnumerateFlags.Normal | chm.ChmEnumerateFlags.Files);
      if (chapters.length === 0) return { kind: "corrupt" };
      const title = (await systemTitle(file)) || chapters[0]?.title || "";
      return { kind: "chm", document: new ChmReaderDocument(title, chapters) };
    } finally {
      file.close();
    }
  } catch {
    return { kind: "corrupt" };
  }
}

export class ChmReaderDocument {
  private sectionIndex = 0;

  constructor(
    readonly title: string,
    private readonly chapters: ChmChapter[],
  ) {}

  get author(): string {
    return "";
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
    for (let index = 0; index < this.chapters.length; index += 1) {
      const chapter = this.chapters[index];
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

  private get current(): ChmChapter {
    return this.chapters[Math.min(Math.max(this.sectionIndex, 0), this.chapters.length - 1)] ?? { title: "", body: "" };
  }
}

async function htmlChapters(file: ChmFile, filesFlag: number): Promise<ChmChapter[]> {
  const pages: { path: string; html: string }[] = [];
  for await (const entry of file.enumerate(filesFlag)) {
    const path = normalizePath(entry.path);
    if (path == null || !isHtml(path)) continue;
    let bytes: Uint8Array;
    try {
      bytes = await file.retrieve(entry);
    } catch {
      continue;
    }
    pages.push({ path, html: new TextDecoder("utf-8", { fatal: false }).decode(bytes) });
  }
  pages.sort((left, right) => {
    const rank = pageRank(left.path) - pageRank(right.path);
    if (rank !== 0) return rank;
    return left.path.toLowerCase().localeCompare(right.path.toLowerCase());
  });
  const chapters: ChmChapter[] = [];
  for (const page of pages) {
    const title = htmlTitle(page.html) || fileName(page.path);
    const body = visibleText(page.html);
    if (title.length === 0 && body.length === 0) continue;
    chapters.push({ title, body });
  }
  return chapters;
}

async function systemTitle(file: ChmFile): Promise<string> {
  try {
    const raw = await file.getSystemRaw();
    if (raw == null) return "";
    const chm = await import("chmlib-ts");
    return chm.parseSystemInfo(raw).title?.trim() ?? "";
  } catch {
    return "";
  }
}

function visibleText(html: string): string {
  const withoutHead = html.replace(/<head[\s\S]*?<\/head>/gi, "");
  return stripHtml(withoutHead.replaceAll("\r\n", "\n").replaceAll("\r", "\n"));
}

function htmlTitle(html: string): string {
  const match = /<title[^>]*>([\s\S]*?)<\/title>/i.exec(html);
  if (match?.[1] == null) return "";
  return match[1].replaceAll("&amp;", "&").replaceAll("&lt;", "<").replaceAll("&gt;", ">").trim();
}

function normalizePath(path: string): string | null {
  const parts: string[] = [];
  for (const part of path.replaceAll("\\", "/").split("/")) {
    if (part.length === 0 || part === ".") continue;
    if (part === "..") return null;
    parts.push(part);
  }
  return parts.length === 0 ? null : parts.join("/");
}

function isHtml(path: string): boolean {
  const lower = path.toLowerCase();
  return lower.endsWith(".htm") || lower.endsWith(".html") || lower.endsWith(".xhtml");
}

function pageRank(path: string): number {
  const name = path.toLowerCase().split("/").at(-1) ?? path.toLowerCase();
  if (name.startsWith("index.")) return 0;
  if (name.startsWith("default.")) return 1;
  return 2;
}

function fileName(path: string): string {
  return path.split("/").at(-1) ?? path;
}
