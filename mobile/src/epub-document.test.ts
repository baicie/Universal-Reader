import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import { strToU8, zipSync } from "fflate";

import { openEpubDocument } from "./epub-document";

const png = Uint8Array.from([
  0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00, 0x00, 0x00, 0x0d, 0x49, 0x48, 0x44,
  0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1f,
  0x15, 0xc4, 0x89, 0x00, 0x00, 0x00, 0x0a, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9c, 0x63, 0x00,
  0x01, 0x00, 0x00, 0x05, 0x00, 0x01, 0x0d, 0x0a, 0x2d, 0xb4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4e, 0x44, 0xae, 0x42, 0x60, 0x82,
]);

function zip(files: Record<string, string | Uint8Array>): Uint8Array {
  const entries: Record<string, Uint8Array> = {};
  for (const [name, value] of Object.entries(files)) {
    entries[name] = typeof value === "string" ? strToU8(value) : value;
  }
  return zipSync(entries);
}

function minimalEpub(options?: {
  firstMarkup?: string;
  extra?: Record<string, string | Uint8Array>;
  nav?: string;
  linearExtra?: string;
}): Uint8Array {
  const nav =
    options?.nav ??
    `<?xml version="1.0"?>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
  <body>
    <nav epub:type="toc">
      <ol>
        <li><a href="ch1.xhtml">第一章</a></li>
        <li><a href="ch2.xhtml">第二章</a></li>
      </ol>
    </nav>
  </body>
</html>`;
  return zip({
    mimetype: "application/epub+zip",
    "META-INF/container.xml": `<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>`,
    "OEBPS/content.opf": `<?xml version="1.0"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>Fixture Book</dc:title>
    <dc:creator>Fixture Author</dc:creator>
  </metadata>
  <manifest>
    <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
    <item id="ch1" href="ch1.xhtml" media-type="application/xhtml+xml"/>
    <item id="ch2" href="ch2.xhtml" media-type="application/xhtml+xml"/>
    <item id="skip" href="skip.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine>
    <itemref idref="ch1"/>
    <itemref idref="ch2"/>
    <itemref idref="skip" linear="no"/>
  </spine>
</package>`,
    "OEBPS/nav.xhtml": nav,
    "OEBPS/ch1.xhtml": `<?xml version="1.0"?><html xmlns="http://www.w3.org/1999/xhtml"><body><h1>第一章</h1><p>hello from epub</p>${options?.firstMarkup ?? ""}</body></html>`,
    "OEBPS/ch2.xhtml":
      '<?xml version="1.0"?><html xmlns="http://www.w3.org/1999/xhtml"><body><h1>第二章</h1><p>second chapter text</p></body></html>',
    "OEBPS/skip.xhtml":
      '<?xml version="1.0"?><html><body><p>not in the reading order</p></body></html>',
    ...options?.extra,
  });
}

test("opens a minimal epub with toc and chapter jump", () => {
  const opened = openEpubDocument(minimalEpub());
  assert.equal(opened.kind, "epub");
  if (opened.kind !== "epub") return;
  const document = opened.document;
  assert.equal(document.title, "Fixture Book");
  assert.equal(document.author, "Fixture Author");
  assert.deepEqual(
    document.toc().map((item) => item.title),
    ["第一章", "第二章"],
  );
  assert.match(document.currentChapterText, /hello from epub/);
  assert.equal(document.currentChapterText.includes("not in the reading order"), false);
  assert.equal(document.goTo("OEBPS/ch2.xhtml"), true);
  assert.match(document.currentChapterText, /second chapter text/);
  assert.equal(document.goTo("OEBPS/missing.xhtml"), false);
  assert.match(document.currentChapterText, /second chapter text/);
});

test("nav nested entries keep a fragment on the current chapter", () => {
  const opened = openEpubDocument(
    minimalEpub({
      firstMarkup: '<p id="note">footnote target</p>',
      nav: `<?xml version="1.0"?>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
  <body>
    <nav epub:type="toc">
      <ol>
        <li>
          <a href="ch1.xhtml">第一章</a>
          <ol><li><a href="ch1.xhtml#note">注释</a></li></ol>
        </li>
        <li><a href="ch2.xhtml">第二章</a></li>
        <li><a href="ghost.xhtml">幽灵章</a></li>
      </ol>
    </nav>
  </body>
</html>`,
    }),
  );
  assert.equal(opened.kind, "epub");
  if (opened.kind !== "epub") return;
  const toc = opened.document.toc();
  assert.deepEqual(
    toc.map((item) => item.title),
    ["第一章", "第二章"],
  );
  assert.equal(toc[0]?.children.length, 1);
  assert.equal(toc[0]?.children[0]?.title, "注释");
  assert.equal(toc[0]?.children[0]?.fragment, "note");
  assert.equal(toc[0]?.fragment, null);
  assert.equal(toc[1]?.children.length, 0);
});

test("ncx nested navPoints keep fragments on subsections", () => {
  const opened = openEpubDocument(
    zip({
      mimetype: "application/epub+zip",
      "META-INF/container.xml": `<?xml version="1.0"?>
<container xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles><rootfile full-path="OEBPS/content.opf"/></rootfiles>
</container>`,
      "OEBPS/content.opf": `<?xml version="1.0"?>
<package xmlns="http://www.idpf.org/2007/opf" version="2.0">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>NCX Book</dc:title>
    <dc:creator>NCX Author</dc:creator>
  </metadata>
  <manifest>
    <item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>
    <item id="ch1" href="ch1.xhtml" media-type="application/xhtml+xml"/>
    <item id="ch2" href="ch2.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine toc="ncx">
    <itemref idref="ch1"/>
    <itemref idref="ch2"/>
  </spine>
</package>`,
      "OEBPS/toc.ncx": `<?xml version="1.0"?>
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/">
  <navMap>
    <navPoint id="np1">
      <navLabel><text>第一章</text></navLabel>
      <content src="ch1.xhtml"/>
      <navPoint id="np1-1">
        <navLabel><text>第一节</text></navLabel>
        <content src="ch1.xhtml#section1"/>
      </navPoint>
      <navPoint id="np1-2">
        <navLabel><text>第二节</text></navLabel>
        <content src="ch1.xhtml#section2"/>
      </navPoint>
    </navPoint>
    <navPoint id="np2">
      <navLabel><text>第二章</text></navLabel>
      <content src="ch2.xhtml"/>
    </navPoint>
  </navMap>
</ncx>`,
      "OEBPS/ch1.xhtml":
        '<?xml version="1.0"?><html><body><h1>第一章</h1><p>first chapter</p></body></html>',
      "OEBPS/ch2.xhtml":
        '<?xml version="1.0"?><html><body><h1>第二章</h1><p>second chapter</p></body></html>',
    }),
  );
  assert.equal(opened.kind, "epub");
  if (opened.kind !== "epub") return;
  const toc = opened.document.toc();
  assert.deepEqual(
    toc.map((item) => item.title),
    ["第一章", "第二章"],
  );
  assert.equal(toc[0]?.children[0]?.title, "第一节");
  assert.equal(toc[0]?.children[0]?.fragment, "section1");
  assert.equal(toc[0]?.children[1]?.fragment, "section2");
  assert.equal(toc[0]?.fragment, null);
  assert.equal(toc[1]?.children.length, 0);
});

test("strips scripts and inlines a local image without inventing a missing one", () => {
  const opened = openEpubDocument(
    minimalEpub({
      firstMarkup:
        '<script>alert(1)</script><img src="images/spot.png" alt="spot" onload="alert(2)"/><img src="images/missing.png" alt="gone"/><img src="https://example.com/remote.png" alt="remote"/>',
      extra: { "OEBPS/images/spot.png": png },
    }),
  );
  assert.equal(opened.kind, "epub");
  if (opened.kind !== "epub") return;
  const html = opened.document.currentChapterHtml;
  assert.equal(html.toLowerCase().includes("<script"), false);
  assert.equal(html.toLowerCase().includes("onload"), false);
  assert.match(html, /src="data:image\/png;base64,/);
  assert.match(html, /src="images\/missing.png"/);
  assert.match(html, /src="https:\/\/example.com\/remote.png"/);
  assert.match(opened.document.currentChapterText, /hello from epub/);
});

test("corrupt epub bytes are corrupt and empty bytes stay unavailable", () => {
  assert.equal(openEpubDocument(null).kind, "unavailable");
  assert.equal(openEpubDocument(new Uint8Array()).kind, "unavailable");
  const corrupt = openEpubDocument(Uint8Array.from([1, 2, 3]));
  assert.equal(corrupt.kind, "corrupt");
  const notZip = openEpubDocument(strToU8("not-a-zip"));
  assert.equal(notZip.kind, "corrupt");
});

test("the shared minimal epub sample opens its own chapters", () => {
  const bytes = new Uint8Array(readFileSync(new URL("../../test-books/epub/minimal.epub", import.meta.url)));
  const opened = openEpubDocument(bytes);
  assert.equal(opened.kind, "epub");
  if (opened.kind !== "epub") return;
  assert.ok(opened.document.title.length > 0);
  assert.ok(opened.document.chapterCount > 0);
  assert.ok(opened.document.currentChapterText.length > 0);
  assert.ok(opened.document.toc().length > 0);
});

test("search stays inside the current epub", () => {
  const opened = openEpubDocument(minimalEpub());
  assert.equal(opened.kind, "epub");
  if (opened.kind !== "epub") return;
  const hits = opened.document.search("second chapter text");
  assert.equal(hits.length, 1);
  assert.match(hits[0]?.excerpt ?? "", /second chapter text/);
  assert.equal(opened.document.indexOfHref(hits[0]?.href ?? ""), 1);
  assert.equal(opened.document.chapterIndex, 0);
  assert.match(opened.document.currentChapterText, /hello from epub/);
  assert.equal(opened.document.goTo(hits[0]?.href ?? ""), true);
  assert.match(opened.document.currentChapterText, /second chapter text/);
  assert.equal(opened.document.search("").length, 0);
});
