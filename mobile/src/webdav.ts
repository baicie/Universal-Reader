import { XMLParser } from "fast-xml-parser";

export const WEBDAV_BYTE_LIMIT = 64 * 1024 * 1024;

const SYNC_FILE = "universal-reader-sync.json";

const PROPFIND_BODY = `<?xml version="1.0"?><d:propfind xmlns:d="DAV:"><d:prop><d:resourcetype/></d:prop></d:propfind>`;

const xmlParser = new XMLParser({
  ignoreAttributes: true,
  removeNSPrefix: true,
  trimValues: true,
});

export class WebDavError extends Error {
  constructor() {
    super("webdav");
    this.name = "WebDavError";
  }
}

export type WebDavFile = {
  name: string;
  bytes: Uint8Array;
};

export type WebDavAccount = {
  baseUrl: string;
  username: string;
  password: string;
  maxBytes?: number;
};

export type WebDavShelfBook = {
  title: string;
  format: "txt" | "markdown" | "html" | "rtf" | "docx" | "odt" | "mobi" | "azw3" | "chm" | "djvu" | "epub" | "pdf" | "fb2" | "cbz" | "cbt" | "cbr" | "cb7";
  bytes: Uint8Array;
};

export async function readWebDavObject(
  account: WebDavAccount,
  name: string,
  fetchImpl: typeof fetch = fetch,
): Promise<Uint8Array | null> {
  if (!singleSegment(name)) throw new WebDavError();
  const directory = webDavDirectory(account.baseUrl);
  const response = await requestWebDav(new URL(encodeURIComponent(name), directory).href, account, fetchImpl, "GET");
  if (response.status === 404) return null;
  if (!response.ok) throw new WebDavError();
  return new Uint8Array(await response.arrayBuffer());
}

export async function writeWebDavObject(
  account: WebDavAccount,
  name: string,
  bytes: Uint8Array,
  fetchImpl: typeof fetch = fetch,
): Promise<void> {
  if (!singleSegment(name)) throw new WebDavError();
  const directory = webDavDirectory(account.baseUrl);
  const response = await requestWebDav(new URL(encodeURIComponent(name), directory).href, account, fetchImpl, "PUT", new Uint8Array(bytes));
  if (!response.ok) throw new WebDavError();
}

async function requestWebDav(
  url: string,
  account: WebDavAccount,
  fetchImpl: typeof fetch,
  method: "GET" | "PUT",
  body?: Uint8Array,
): Promise<Response> {
  try {
    return await fetchImpl(url, {
      method,
      headers: { Authorization: basicAuthorization(account.username, account.password) },
      body: body == null ? undefined : (body as unknown as BodyInit),
    });
  } catch {
    throw new WebDavError();
  }
}

export async function pushWebDavBooks(
  account: WebDavAccount,
  books: readonly WebDavShelfBook[],
  fetchImpl: typeof fetch = fetch,
): Promise<{ pushed: string[]; failed: string[] }> {
  const directory = webDavDirectory(account.baseUrl);
  const maxBytes = account.maxBytes ?? WEBDAV_BYTE_LIMIT;
  const authorization = basicAuthorization(account.username, account.password);
  const hrefs = await propfindHrefs(directory, authorization, fetchImpl);
  const remote = new Set<string>();
  for (const href of hrefs) {
    const entry = entryInDirectory(directory, href);
    if (entry != null) remote.add(entry.name);
  }
  const pushed: string[] = [];
  const failed: string[] = [];
  const sent = new Set<string>();
  for (const book of books) {
    const name = portableBookName(book.title, book.format);
    if (name == null || remote.has(name) || sent.has(name)) continue;
    if (book.bytes.byteLength === 0 || book.bytes.byteLength > maxBytes) continue;
    sent.add(name);
    const payload = new Uint8Array(book.bytes);
    let response: Response;
    try {
      response = await fetchImpl(new URL(encodeURIComponent(name), directory).href, {
        method: "PUT",
        headers: { Authorization: authorization },
        body: payload as unknown as BodyInit,
      });
    } catch {
      failed.push(name);
      continue;
    }
    if (!response.ok) {
      failed.push(name);
      continue;
    }
    pushed.push(name);
  }
  return { pushed, failed };
}

export async function listWebDavFiles(account: WebDavAccount, fetchImpl: typeof fetch = fetch): Promise<WebDavFile[]> {
  const directory = webDavDirectory(account.baseUrl);
  const maxBytes = account.maxBytes ?? WEBDAV_BYTE_LIMIT;
  const authorization = basicAuthorization(account.username, account.password);
  const hrefs = await propfindHrefs(directory, authorization, fetchImpl);
  const files: WebDavFile[] = [];
  for (const href of hrefs) {
    const file = webDavFile(directory, href);
    if (file == null) continue;
    let download: Response;
    try {
      download = await fetchImpl(file.url, { headers: { Authorization: authorization } });
    } catch {
      continue;
    }
    if (!download.ok) continue;
    const bytes = await readLimited(download, maxBytes);
    if (bytes == null) continue;
    files.push({ name: file.name, bytes });
  }
  return files;
}

async function propfindHrefs(directory: URL, authorization: string, fetchImpl: typeof fetch): Promise<string[]> {
  let response: Response;
  try {
    response = await fetchImpl(directory.href, {
      method: "PROPFIND",
      headers: {
        Authorization: authorization,
        "Content-Type": "application/xml; charset=utf-8",
        Depth: "1",
      },
      body: PROPFIND_BODY,
    });
  } catch {
    throw new WebDavError();
  }
  if (!response.ok) throw new WebDavError();
  try {
    return hrefsFromXml(await response.text());
  } catch (error) {
    if (error instanceof WebDavError) throw error;
    throw new WebDavError();
  }
}

function webDavDirectory(baseUrl: string): URL {
  let parsed: URL;
  try {
    parsed = new URL(baseUrl.trim());
  } catch {
    throw new WebDavError();
  }
  if ((parsed.protocol !== "http:" && parsed.protocol !== "https:") || parsed.hostname.length === 0) {
    throw new WebDavError();
  }
  parsed.username = "";
  parsed.password = "";
  parsed.search = "";
  parsed.hash = "";
  if (!parsed.pathname.endsWith("/")) parsed.pathname += "/";
  return parsed;
}

function webDavFile(directory: URL, href: string): { name: string; url: string } | null {
  const entry = entryInDirectory(directory, href);
  if (entry == null || entry.name === SYNC_FILE || !supportedBookName(entry.name)) return null;
  return entry;
}

function entryInDirectory(directory: URL, href: string): { name: string; url: string } | null {
  let parsed: URL;
  try {
    parsed = new URL(href, directory);
  } catch {
    return null;
  }
  if (parsed.protocol !== directory.protocol || parsed.host !== directory.host) return null;
  if (parsed.pathname.endsWith("/")) return null;
  if (!parsed.pathname.startsWith(directory.pathname)) return null;
  const segment = parsed.pathname.slice(directory.pathname.length);
  if (segment.length === 0 || segment.includes("/")) return null;
  let name: string;
  try {
    name = decodeURIComponent(segment);
  } catch {
    return null;
  }
  if (!singleSegment(name)) return null;
  parsed.search = "";
  parsed.hash = "";
  return { name, url: parsed.href };
}

function portableBookName(title: string, format: WebDavShelfBook["format"]): string | null {
  const trimmed = title.trim();
  if (trimmed.length === 0 || !singleSegment(trimmed) || trimmed.includes("..")) return null;
  const extension = format === "markdown" ? "md" : format;
  const dot = trimmed.lastIndexOf(".");
  const current = dot > 0 ? trimmed.slice(dot + 1).toLowerCase() : "";
  const name = current === extension ? trimmed : `${dot > 0 ? trimmed.slice(0, dot) : trimmed}.${extension}`;
  if (!singleSegment(name) || name.includes("..") || name === SYNC_FILE) return null;
  return name;
}

function singleSegment(name: string): boolean {
  return name !== "." && name !== ".." && !name.includes("/") && !name.includes("\\") && !name.includes("\0");
}

function supportedBookName(name: string): boolean {
  const lower = name.toLowerCase();
  return (
    lower.endsWith(".txt") ||
    lower.endsWith(".md") ||
    lower.endsWith(".markdown") ||
    lower.endsWith(".html") ||
    lower.endsWith(".htm") ||
    lower.endsWith(".epub") ||
    lower.endsWith(".pdf") ||
    lower.endsWith(".cbz") ||
    lower.endsWith(".cbt") ||
    lower.endsWith(".fb2") ||
    lower.endsWith(".rtf") ||
    lower.endsWith(".docx") ||
    lower.endsWith(".odt") ||
    lower.endsWith(".mobi") ||
    lower.endsWith(".azw3") ||
    lower.endsWith(".chm") ||
    lower.endsWith(".djvu") ||
    lower.endsWith(".djv") ||
    lower.endsWith(".cbr") ||
    lower.endsWith(".cb7")
  );
}

function hrefsFromXml(xml: string): string[] {
  let parsed: unknown;
  try {
    parsed = xmlParser.parse(xml);
  } catch {
    throw new WebDavError();
  }
  const hrefs: string[] = [];
  collectHrefs(parsed, hrefs);
  return hrefs;
}

function collectHrefs(node: unknown, out: string[]): void {
  if (node == null || typeof node === "string" || typeof node === "number" || typeof node === "boolean") return;
  if (Array.isArray(node)) {
    for (const item of node) collectHrefs(item, out);
    return;
  }
  if (typeof node !== "object") return;
  for (const [key, value] of Object.entries(node)) {
    if (key === "href") pushHref(value, out);
    else collectHrefs(value, out);
  }
}

function pushHref(value: unknown, out: string[]): void {
  if (typeof value === "string") {
    const trimmed = value.trim();
    if (trimmed.length > 0) out.push(trimmed);
    return;
  }
  if (typeof value === "number") {
    out.push(String(value));
    return;
  }
  if (Array.isArray(value)) {
    for (const item of value) pushHref(item, out);
  }
}

async function readLimited(response: Response, maxBytes: number): Promise<Uint8Array | null> {
  const declared = Number(response.headers.get("content-length"));
  if (Number.isFinite(declared) && declared > maxBytes) return null;
  let bytes: Uint8Array;
  try {
    bytes = new Uint8Array(await response.arrayBuffer());
  } catch {
    return null;
  }
  if (bytes.byteLength === 0 || bytes.byteLength > maxBytes) return null;
  return bytes;
}

function basicAuthorization(username: string, password: string): string {
  const bytes = new TextEncoder().encode(`${username}:${password}`);
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return `Basic ${btoa(binary)}`;
}
