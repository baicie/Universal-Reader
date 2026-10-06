import assert from "node:assert/strict";
import { Buffer } from "buffer";
import test from "node:test";
import { strToU8, zipSync } from "fflate";

import { coverUri, extractCover } from "./cover";

const png = Uint8Array.from([
  0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00, 0x00, 0x00, 0x0d, 0x49, 0x48, 0x44,
  0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1f,
  0x15, 0xc4, 0x89, 0x00, 0x00, 0x00, 0x0a, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9c, 0x63, 0x00,
  0x01, 0x00, 0x00, 0x05, 0x00, 0x01, 0x0d, 0x0a, 0x2d, 0xb4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4e, 0x44, 0xae, 0x42, 0x60, 0x82,
]);

const container = strToU8(`<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>
`);

function epub(opf: string, files: Record<string, Uint8Array>): Uint8Array {
  return zipSync({
    mimetype: strToU8("application/epub+zip"),
    "META-INF/container.xml": container,
    "OEBPS/content.opf": strToU8(opf),
    ...files,
  });
}

test("an epub cover meta image wins over another picture", () => {
  const bytes = epub(
    `<?xml version="1.0"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0">
  <metadata>
    <meta name="cover" content="cover-image"/>
  </metadata>
  <manifest>
    <item id="cover-image" href="images/cover.png" media-type="image/png"/>
    <item id="other" href="aaa.jpg" media-type="image/jpeg"/>
  </manifest>
</package>`,
    {
      "OEBPS/aaa.jpg": Uint8Array.from([1, 2, 3]),
      "OEBPS/images/cover.png": png,
    },
  );
  assert.deepEqual(extractCover("epub", bytes), png);
});

test("an epub without cover metadata uses the first image in path order", () => {
  const bytes = epub(
    `<?xml version="1.0"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0">
  <manifest>
    <item id="late" href="zzz.png" media-type="image/png"/>
    <item id="early" href="aaa.jpg" media-type="image/jpeg"/>
  </manifest>
</package>`,
    {
      "OEBPS/zzz.png": Uint8Array.from([1, 2, 3]),
      "OEBPS/aaa.jpg": png,
    },
  );
  assert.deepEqual(extractCover("epub", bytes), png);
});

test("an epub with a missing or damaged container stays without a cover", () => {
  const picture = { "OEBPS/aaa.png": png };
  assert.equal(extractCover("epub", zipSync(picture)), null);
  assert.equal(
    extractCover(
      "epub",
      zipSync({
        ...picture,
        "META-INF/container.xml": strToU8("not-xml-at-all"),
      }),
    ),
    null,
  );
});

test("a cbz cover is the first reading page and skips resource forks", () => {
  const bytes = zipSync({
    "Page-02.png": Uint8Array.from([1, 2, 3]),
    "dir/page-01.jpg": png,
    "readme.txt": strToU8("notes"),
    "__MACOSX/._page-01.jpg": Uint8Array.from([9, 9, 9]),
  });
  assert.deepEqual(extractCover("cbz", bytes), png);
  assert.equal(extractCover("cbz", zipSync({ "__MACOSX/cover.png": png })), null);
  assert.equal(extractCover("cbz", Uint8Array.from([1, 2, 3])), null);
});

test("a cbt cover is the first image page", () => {
  assert.deepEqual(extractCover("cbt", tarArchive({ "zzz.png": Uint8Array.from([1, 2, 3]), "aaa.jpg": png })), png);
});

test("an fb2 cover is the coverpage image", () => {
  const encoded = Buffer.from(png).toString("base64");
  const other = Buffer.from(Uint8Array.from([1, 2, 3, 4])).toString("base64");
  const book = (href: string) =>
    strToU8(`<?xml version="1.0" encoding="UTF-8"?>
<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0" xmlns:l="http://www.w3.org/1999/xlink">
  <description><title-info><book-title>Covered</book-title><coverpage><image l:href="${href}"/></coverpage></title-info></description>
  <body><section><title>Chapter</title><p>body text</p></section></body>
  <binary id="other.png" content-type="image/png">${other}</binary>
  <binary id="cover.png" content-type="image/png">${encoded}</binary>
</FictionBook>`);
  assert.deepEqual(extractCover("fb2", book("#cover.png")), png);
  assert.equal(extractCover("fb2", book("https://example.com/cover.png")), null);
  assert.equal(
    extractCover(
      "fb2",
      strToU8(`<?xml version="1.0"?><FictionBook><body><section><p>body text</p></section></body><binary id="cover.png">${encoded}</binary></FictionBook>`),
    ),
    null,
  );
});

test("text and pdf files stay without a cover", () => {
  assert.equal(extractCover("txt", strToU8("hello")), null);
  assert.equal(extractCover("rtf", strToU8("{\\rtf1 hello}")), null);
  assert.equal(extractCover("docx", strToU8("not a zip")), null);
  assert.equal(extractCover("odt", strToU8("not a zip")), null);
  assert.equal(extractCover("mobi", strToU8("BOOKMOBI")), null);
  assert.equal(extractCover("azw3", strToU8("BOOKMOBI")), null);
  assert.equal(extractCover("chm", strToU8("ITSF")), null);
  assert.equal(extractCover("djvu", strToU8("AT&TFORM")), null);
  assert.equal(extractCover("pdf", png), null);
  assert.equal(extractCover("epub", new Uint8Array()), null);
});

test("a cover uri is the image itself and unknown bytes stay blank", () => {
  assert.equal(coverUri(png)?.startsWith("data:image/png;base64,"), true);
  assert.equal(coverUri(Uint8Array.from([1, 2, 3])), null);
});

function tarArchive(files: Record<string, Uint8Array>): Uint8Array {
  const parts: Uint8Array[] = [];
  for (const [name, data] of Object.entries(files)) {
    const header = new Uint8Array(512);
    header.set(new TextEncoder().encode(name), 0);
    header.set(new TextEncoder().encode(data.length.toString(8).padStart(11, "0")), 124);
    header[156] = 0x30;
    header.set(new TextEncoder().encode("ustar"), 257);
    parts.push(header, data);
    const pad = (512 - (data.length % 512)) % 512;
    if (pad > 0) parts.push(new Uint8Array(pad));
  }
  parts.push(new Uint8Array(1024));
  const out = new Uint8Array(parts.reduce((sum, part) => sum + part.length, 0));
  let offset = 0;
  for (const part of parts) {
    out.set(part, offset);
    offset += part.length;
  }
  return out;
}
