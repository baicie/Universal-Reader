import { Buffer } from "buffer";
import { unzipSync } from "fflate";
import { XMLParser, XMLValidator } from "fast-xml-parser";

import { openStoredComic } from "./comic-document";
import { fb2CoverBytes } from "./fb2-document";
import type { ShelfFormat } from "./shelf-store";

const imageSuffixes = [".png", ".jpg", ".jpeg", ".webp", ".gif"];

const xmlParser = new XMLParser({
  ignoreAttributes: false,
  attributeNamePrefix: "@_",
  removeNSPrefix: true,
});

type XmlNode = Record<string, unknown>;

export function extractCover(format: ShelfFormat, bytes: Uint8Array): Uint8Array | null {
  if (bytes.length === 0) return null;
  try {
    if (format === "cbz" || format === "cbt") return comicCover(format, bytes);
    if (format === "epub") return epubCover(bytes);
    if (format === "fb2") return fb2CoverBytes(bytes);
    return null;
  } catch {
    // A cover problem must not stop the book from opening.
    return null;
  }
}

export function coverUri(bytes: Uint8Array): string | null {
  const mime = imageMime(bytes);
  if (mime == null) return null;
  return `data:${mime};base64,${Buffer.from(bytes).toString("base64")}`;
}

function comicCover(format: "cbz" | "cbt", bytes: Uint8Array): Uint8Array | null {
  const opened = openStoredComic(format, bytes);
  if (opened.kind !== "comic") return null;
  const page = opened.pages[0];
  return page ? copyBytes(page.bytes) : null;
}

function epubCover(bytes: Uint8Array): Uint8Array | null {
  const files = unzip(bytes);
  if (files == null) return null;
  const container = files.find((file) => normalize(file.name) === "meta-inf/container.xml");
  if (container == null) return null;
  const containerXml = decodeXml(container.bytes);
  if (containerXml == null) return null;
  const rootfile = findElements(containerXml, "rootfile")[0];
  const fullPath = rootfile?.["@_full-path"];
  if (typeof fullPath !== "string" || fullPath.length === 0) return firstImage(files);
  const opf = files.find((file) => normalize(file.name) === normalize(fullPath));
  if (opf == null) return null;
  const opfXml = decodeXml(opf.bytes);
  if (opfXml == null) return null;
  const href = coverHref(opfXml, normalize(fullPath));
  if (href != null) {
    const image = files.find((file) => normalize(file.name) === href);
    if (image) return copyBytes(image.bytes);
  }
  return firstImage(files);
}

function coverHref(opf: XmlNode, opfPath: string): string | null {
  const items = findElements(opf, "item");
  const coverMeta = findElements(opf, "meta").find((meta) => meta["@_name"] === "cover");
  const coverId = coverMeta?.["@_content"];
  if (typeof coverId === "string" && coverId.length > 0) {
    const item = items.find((entry) => entry["@_id"] === coverId);
    if (typeof item?.["@_href"] === "string") return resolve(opfPath, item["@_href"]);
  }
  const property = items.find(
    (entry) => typeof entry["@_properties"] === "string" && entry["@_properties"].includes("cover-image"),
  );
  if (typeof property?.["@_href"] === "string") return resolve(opfPath, property["@_href"]);
  return null;
}

function firstImage(files: ZipFile[]): Uint8Array | null {
  const images = files.filter((file) => isImagePath(file.name)).sort((left, right) => {
    if (left.name < right.name) return -1;
    if (left.name > right.name) return 1;
    return 0;
  });
  const image = images[0];
  return image ? copyBytes(image.bytes) : null;
}

function unzip(bytes: Uint8Array): ZipFile[] | null {
  try {
    return Object.entries(unzipSync(bytes))
      .filter(([name]) => !name.endsWith("/"))
      .map(([name, data]) => ({ name, bytes: data }));
  } catch {
    return null;
  }
}

type ZipFile = { name: string; bytes: Uint8Array };

function decodeXml(bytes: Uint8Array): XmlNode | null {
  const source = new TextDecoder().decode(bytes);
  if (XMLValidator.validate(source) !== true) return null;
  const parsed = xmlParser.parse(source);
  return isNode(parsed) ? parsed : null;
}

function findElements(node: unknown, name: string): XmlNode[] {
  if (!isNode(node)) return [];
  const found: XmlNode[] = [];
  for (const [key, value] of Object.entries(node)) {
    if (key.startsWith("@_") || key === "#text") continue;
    for (const child of asNodes(value)) {
      if (key === name) found.push(child);
      found.push(...findElements(child, name));
    }
  }
  return found;
}

function asNodes(value: unknown): XmlNode[] {
  if (Array.isArray(value)) return value.filter(isNode);
  return isNode(value) ? [value] : [];
}

function isNode(value: unknown): value is XmlNode {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function isImagePath(path: string): boolean {
  if (path.toLowerCase().includes("__macosx")) return false;
  const base = path.replace(/\\/g, "/").split("/").pop() ?? "";
  if (base.length === 0 || base.startsWith(".")) return false;
  return imageSuffixes.some((suffix) => base.toLowerCase().endsWith(suffix));
}

function resolve(basePath: string, href: string): string {
  const cleaned = href.split("#")[0]?.replace(/\\/g, "/") ?? "";
  const slash = basePath.lastIndexOf("/");
  const dir = slash < 0 ? "" : basePath.slice(0, slash + 1);
  return normalize(cleaned.startsWith("/") ? cleaned.slice(1) : `${dir}${cleaned}`);
}

function normalize(path: string): string {
  return path.replace(/\\/g, "/").replace(/^\/+/, "").toLowerCase();
}

function imageMime(bytes: Uint8Array): string | null {
  if (bytes.length >= 8 && bytes[0] === 0x89 && bytes[1] === 0x50 && bytes[2] === 0x4e && bytes[3] === 0x47) {
    return "image/png";
  }
  if (bytes.length >= 3 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) return "image/jpeg";
  if (bytes.length >= 6 && bytes[0] === 0x47 && bytes[1] === 0x49 && bytes[2] === 0x46) return "image/gif";
  if (
    bytes.length >= 12 &&
    bytes[0] === 0x52 &&
    bytes[1] === 0x49 &&
    bytes[2] === 0x46 &&
    bytes[3] === 0x46 &&
    bytes[8] === 0x57 &&
    bytes[9] === 0x45 &&
    bytes[10] === 0x42 &&
    bytes[11] === 0x50
  ) {
    return "image/webp";
  }
  return null;
}

function copyBytes(bytes: Uint8Array): Uint8Array {
  return new Uint8Array(bytes);
}
