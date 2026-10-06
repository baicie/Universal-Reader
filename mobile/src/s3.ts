export const S3_BYTE_LIMIT = 64 * 1024 * 1024;

const SYNC_FILE = "universal-reader-sync.json";
const MAX_LIST_PAGES = 10_000;
const EMPTY_PAYLOAD = new Uint8Array(0);

export class S3Error extends Error {
  constructor() {
    super("s3");
    this.name = "S3Error";
  }
}

export type S3Account = {
  endpoint: string;
  region: string;
  bucket: string;
  prefix: string;
  accessKey: string;
  secretKey: string;
  maxBytes?: number;
  now?: Date;
};

export type S3File = {
  name: string;
  bytes: Uint8Array;
};

export type S3ShelfBook = {
  title: string;
  format: "txt" | "markdown" | "html" | "rtf" | "docx" | "odt" | "mobi" | "azw3" | "chm" | "djvu" | "epub" | "pdf" | "fb2" | "cbz" | "cbt" | "cbr" | "cb7";
  bytes: Uint8Array;
};

type S3Config = {
  endpoint: URL;
  region: string;
  bucket: string;
  prefix: string;
  accessKey: string;
  secretKey: string;
  maxBytes: number;
  now: Date;
};

export async function pushS3Books(
  account: S3Account,
  books: readonly S3ShelfBook[],
  fetchImpl: typeof fetch = fetch,
): Promise<{ pushed: string[]; failed: string[] }> {
  const config = configure(account);
  if (!config) throw new S3Error();
  const keys = await listKeys(config, fetchImpl);
  const remote = new Set<string>();
  for (const key of keys) {
    if (!keyInPrefix(key, config.prefix)) continue;
    const name = baseName(key);
    if (name == null || name === SYNC_FILE) continue;
    remote.add(name);
  }
  const pushed: string[] = [];
  const failed: string[] = [];
  const sent = new Set<string>();
  for (const book of books) {
    const name = portableBookName(book.title, book.format);
    if (name == null || remote.has(name) || sent.has(name)) continue;
    if (book.bytes.byteLength === 0 || book.bytes.byteLength > config.maxBytes) continue;
    sent.add(name);
    const payload = new Uint8Array(book.bytes);
    let response: Response;
    try {
      response = await signedRequest(config, "PUT", `${config.prefix}${name}`, [], payload, fetchImpl);
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

export async function readS3Object(
  account: S3Account,
  name: string,
  fetchImpl: typeof fetch = fetch,
): Promise<Uint8Array | null> {
  const config = configure(account);
  if (!config || !singleObjectName(name)) throw new S3Error();
  const response = await signedRequest(config, "GET", `${config.prefix}${name}`, [], EMPTY_PAYLOAD, fetchImpl);
  if (response.status === 404) return null;
  if (!response.ok) throw new S3Error();
  return new Uint8Array(await response.arrayBuffer());
}

export async function writeS3Object(
  account: S3Account,
  name: string,
  bytes: Uint8Array,
  fetchImpl: typeof fetch = fetch,
): Promise<void> {
  const config = configure(account);
  if (!config || !singleObjectName(name)) throw new S3Error();
  const payload = new Uint8Array(bytes);
  const response = await signedRequest(config, "PUT", `${config.prefix}${name}`, [], payload, fetchImpl);
  if (!response.ok) throw new S3Error();
}

export async function listS3Files(account: S3Account, fetchImpl: typeof fetch = fetch): Promise<S3File[]> {
  const config = configure(account);
  if (!config) throw new S3Error();
  const keys = await listKeys(config, fetchImpl);
  const files: S3File[] = [];
  for (const key of keys) {
    const name = baseName(key);
    if (!name || name === SYNC_FILE || !supportedBookName(name) || !keyInPrefix(key, config.prefix)) continue;
    const bytes = await getObject(config, key, fetchImpl);
    if (bytes) files.push({ name, bytes });
  }
  return files;
}

function configure(account: S3Account): S3Config | null {
  let endpoint: URL;
  try {
    endpoint = new URL(account.endpoint.trim());
  } catch {
    return null;
  }
  if ((endpoint.protocol !== "http:" && endpoint.protocol !== "https:") || endpoint.hostname.length === 0) {
    return null;
  }
  endpoint.username = "";
  endpoint.password = "";
  const bucket = account.bucket.trim();
  if (bucket.length === 0 || bucket.includes("/")) return null;
  const region = account.region.trim();
  const accessKey = account.accessKey.trim();
  const secretKey = account.secretKey.trim();
  if (region.length === 0 || accessKey.length === 0 || secretKey.length === 0) return null;
  let prefix = account.prefix.trim().replaceAll("\\", "/");
  while (prefix.startsWith("/")) prefix = prefix.slice(1);
  if (prefix.length > 0 && !prefix.endsWith("/")) prefix += "/";
  const maxBytes = account.maxBytes ?? S3_BYTE_LIMIT;
  if (!Number.isFinite(maxBytes) || maxBytes < 0) return null;
  return {
    endpoint,
    region,
    bucket,
    prefix,
    accessKey,
    secretKey,
    maxBytes,
    now: account.now ?? new Date(),
  };
}

async function listKeys(config: S3Config, fetchImpl: typeof fetch): Promise<string[]> {
  const keys: string[] = [];
  let continuation: string | null = null;
  for (let page = 0; page < MAX_LIST_PAGES; page += 1) {
    const query: [string, string][] = [
      ["list-type", "2"],
      ["prefix", config.prefix],
    ];
    if (continuation) query.push(["continuation-token", continuation]);
    const response = await signedRequest(config, "GET", null, query, EMPTY_PAYLOAD, fetchImpl);
    if (!response.ok) throw new S3Error();
    const xml = await response.text();
    keys.push(...xmlValues(xml, "Key"));
    if (!xmlFlag(xml, "IsTruncated")) return keys;
    const token = xmlValues(xml, "NextContinuationToken")[0];
    if (!token) throw new S3Error();
    continuation = token;
  }
  throw new S3Error();
}

async function getObject(config: S3Config, key: string, fetchImpl: typeof fetch): Promise<Uint8Array | null> {
  let response: Response;
  try {
    response = await signedRequest(config, "GET", key, [], EMPTY_PAYLOAD, fetchImpl);
  } catch {
    return null;
  }
  if (!response.ok) return null;
  const declared = Number(response.headers.get("content-length"));
  if (Number.isFinite(declared) && declared > config.maxBytes) return null;
  const bytes = new Uint8Array(await response.arrayBuffer());
  if (bytes.byteLength === 0 || bytes.byteLength > config.maxBytes) return null;
  return bytes;
}

async function signedRequest(
  config: S3Config,
  method: "GET" | "PUT",
  key: string | null,
  query: [string, string][],
  payload: Uint8Array,
  fetchImpl: typeof fetch,
): Promise<Response> {
  const url = requestUrl(config, key, query);
  const { date, amzDate } = amzStamp(config.now);
  const payloadHash = await sha256Hex(payload);
  const host = url.host;
  const canonicalHeaders = `host:${host}\nx-amz-content-sha256:${payloadHash}\nx-amz-date:${amzDate}\n`;
  const signedHeaders = "host;x-amz-content-sha256;x-amz-date";
  const canonicalRequest = `${method}\n${url.pathname}\n${url.search.slice(1)}\n${canonicalHeaders}\n${signedHeaders}\n${payloadHash}`;
  const scope = `${date}/${config.region}/s3/aws4_request`;
  const stringToSign = `AWS4-HMAC-SHA256\n${amzDate}\n${scope}\n${await sha256Hex(textBytes(canonicalRequest))}`;
  const dateKey = await hmacSha256(textBytes(`AWS4${config.secretKey}`), date);
  const regionKey = await hmacSha256(dateKey, config.region);
  const serviceKey = await hmacSha256(regionKey, "s3");
  const signingKey = await hmacSha256(serviceKey, "aws4_request");
  const signature = hex(await hmacSha256(signingKey, stringToSign));
  const authorization = `AWS4-HMAC-SHA256 Credential=${config.accessKey}/${scope}, SignedHeaders=${signedHeaders}, Signature=${signature}`;
  try {
    return await fetchImpl(url.href, {
      method,
      headers: {
        authorization,
        "x-amz-content-sha256": payloadHash,
        "x-amz-date": amzDate,
      },
      body: payload.byteLength > 0 ? (payload as unknown as BodyInit) : undefined,
    });
  } catch (error) {
    if (error instanceof S3Error) throw error;
    throw new S3Error();
  }
}

function requestUrl(config: S3Config, key: string | null, query: [string, string][]): URL {
  const url = new URL(config.endpoint.href);
  const base = url.pathname.endsWith("/") ? url.pathname.slice(0, -1) : url.pathname;
  const segments = [config.bucket];
  if (key) {
    for (const segment of key.split("/")) segments.push(segment);
  }
  url.pathname = `${base}/${segments.map((segment) => awsEncode(segment, false)).join("/")}`;
  const canonicalQuery = [...query]
    .sort((left, right) => (left[0] < right[0] ? -1 : left[0] > right[0] ? 1 : left[1] < right[1] ? -1 : left[1] > right[1] ? 1 : 0))
    .map(([name, value]) => `${awsEncode(name, true)}=${awsEncode(value, true)}`)
    .join("&");
  url.search = canonicalQuery;
  return url;
}

function singleObjectName(name: string): boolean {
  return name.length > 0 && name !== "." && name !== ".." && !name.includes("/") && !name.includes("\\") && !name.includes("\0");
}

function portableBookName(title: string, format: S3ShelfBook["format"]): string | null {
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

function keyInPrefix(key: string, prefix: string): boolean {
  if (prefix.length > 0 && !key.startsWith(prefix)) return false;
  return !key.split("/").some((segment) => segment === "." || segment === "..");
}

function baseName(key: string): string | null {
  const name = key.split("/").at(-1) ?? "";
  return name.length === 0 ? null : name;
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

function amzStamp(now: Date): { date: string; amzDate: string } {
  const iso = now.toISOString();
  const date = `${iso.slice(0, 4)}${iso.slice(5, 7)}${iso.slice(8, 10)}`;
  return { date, amzDate: `${date}T${iso.slice(11, 13)}${iso.slice(14, 16)}${iso.slice(17, 19)}Z` };
}

function textBytes(value: string): Uint8Array<ArrayBuffer> {
  return new Uint8Array(new TextEncoder().encode(value));
}

async function sha256Hex(bytes: Uint8Array): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new Uint8Array(bytes));
  return hex(new Uint8Array(digest));
}

async function hmacSha256(key: Uint8Array, value: string): Promise<Uint8Array<ArrayBuffer>> {
  const cryptoKey = await crypto.subtle.importKey("raw", new Uint8Array(key), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const signature = await crypto.subtle.sign("HMAC", cryptoKey, textBytes(value));
  return new Uint8Array(signature);
}

function hex(bytes: Uint8Array): string {
  let output = "";
  for (const byte of bytes) output += byte.toString(16).padStart(2, "0");
  return output;
}

function awsEncode(value: string, encodeSlash: boolean): string {
  let output = "";
  for (const byte of textBytes(value)) {
    const allowed =
      (byte >= 0x30 && byte <= 0x39) ||
      (byte >= 0x41 && byte <= 0x5a) ||
      (byte >= 0x61 && byte <= 0x7a) ||
      byte === 0x2d ||
      byte === 0x5f ||
      byte === 0x2e ||
      byte === 0x7e ||
      (!encodeSlash && byte === 0x2f);
    output += allowed ? String.fromCharCode(byte) : `%${byte.toString(16).toUpperCase().padStart(2, "0")}`;
  }
  return output;
}

function xmlValues(xml: string, tag: string): string[] {
  const open = `<${tag}>`;
  const close = `</${tag}>`;
  const values: string[] = [];
  let rest = xml;
  while (rest.length > 0) {
    const start = rest.indexOf(open);
    if (start < 0) break;
    const valueStart = start + open.length;
    const end = rest.indexOf(close, valueStart);
    if (end < 0) break;
    values.push(xmlUnescape(rest.slice(valueStart, end)));
    rest = rest.slice(end + close.length);
  }
  return values;
}

function xmlFlag(xml: string, tag: string): boolean {
  return xmlValues(xml, tag)[0]?.toLowerCase() === "true";
}

function xmlUnescape(value: string): string {
  return value
    .replaceAll("&lt;", "<")
    .replaceAll("&gt;", ">")
    .replaceAll("&quot;", '"')
    .replaceAll("&apos;", "'")
    .replaceAll("&amp;", "&");
}
