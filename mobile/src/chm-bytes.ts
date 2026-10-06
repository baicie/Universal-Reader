import type { ChmFile } from "chmlib-ts";

import { stripHtml } from "./text-document";

export type ChmChapter = {
  title: string;
  body: string;
};

export type ChmParseResult = {
  title: string;
  chapters: ChmChapter[];
};

export async function readChmFromBytes(bytes: Uint8Array): Promise<ChmParseResult | null> {
  const chm = await import("chmlib-ts");
  const file = await chm.ChmFile.open(chm.chmReaderFromBuffer(bytes));
  try {
    const chapters = await htmlChapters(file, chm.ChmEnumerateFlags.Normal | chm.ChmEnumerateFlags.Files);
    if (chapters.length === 0) return null;
    const fromSystem = await readSystemTitle(file, chm);
    const title = fromSystem || chapters[0]?.title || "";
    return { title, chapters };
  } finally {
    file.close();
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

async function readSystemTitle(file: ChmFile, chm: typeof import("chmlib-ts")): Promise<string> {
  try {
    const raw = await file.getSystemRaw();
    if (raw == null) return "";
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