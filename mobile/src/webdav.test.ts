import assert from "node:assert/strict";
import test from "node:test";

import { WEBDAV_BYTE_LIMIT, WebDavError, listWebDavFiles, pushWebDavBooks } from "./webdav";

const base = "http://127.0.0.1:8765/dav/";

function listing(hrefs: string[]): string {
  const responses = hrefs
    .map((href) => `<d:response><d:href>${href}</d:href></d:response>`)
    .join("");
  return `<?xml version="1.0"?><d:multistatus xmlns:d="DAV:">${responses}</d:multistatus>`;
}

test("the webdav byte limit is 64 MiB", () => {
  assert.equal(WEBDAV_BYTE_LIMIT, 64 * 1024 * 1024);
});

test("a non-http webdav address is refused before any request", async () => {
  let called = 0;
  const fetchImpl: typeof fetch = async () => {
    called += 1;
    throw new Error("should not fetch");
  };
  await assert.rejects(
    () =>
      listWebDavFiles(
        { baseUrl: "file:///tmp/books", username: "reader", password: "secret-pass" },
        fetchImpl,
      ),
    (error: unknown) => {
      assert.ok(error instanceof WebDavError);
      assert.equal(error.message.includes("secret-pass"), false);
      return true;
    },
  );
  assert.equal(called, 0);
});

test("listing keeps books in this folder and skips other hosts, paths, and formats", async () => {
  const requests: { url: string; method: string; authorization: string | null; depth: string | null; body: string }[] =
    [];
  const fetchImpl: typeof fetch = async (input, init) => {
    const url = String(input);
    const headers = new Headers(init?.headers);
    requests.push({
      url,
      method: init?.method ?? "GET",
      authorization: headers.get("authorization"),
      depth: headers.get("depth"),
      body: typeof init?.body === "string" ? init.body : "",
    });
    if ((init?.method ?? "GET") === "PROPFIND") {
      return new Response(
        listing([
          "/dav/",
          "/dav/notes.txt",
          "/dav/universal-reader-sync.json",
          "/dav/picture.cbr",
          "/dav/subdir/",
          "/dav/sub/nested.txt",
          "/other/outside.txt",
          "/dav/../secrets.txt",
          "http://evil.example/stolen.txt",
          "/dav/my%20book.md",
          "/dav/huge.txt",
          "/dav/missing.epub",
        ]),
        { status: 207 },
      );
    }
    if (url.endsWith("/dav/notes.txt")) return new Response("hello", { status: 200 });
    if (url.includes("my%20book.md") || url.includes("my book.md")) {
      return new Response("markdown body", { status: 200 });
    }
    if (url.endsWith("/dav/huge.txt")) {
      return new Response("too-big", { status: 200, headers: { "content-length": "99" } });
    }
    if (url.endsWith("/dav/missing.epub")) return new Response("no", { status: 404 });
    return new Response(`unexpected ${url}`, { status: 500 });
  };

  const files = await listWebDavFiles(
    { baseUrl: base, username: "reader", password: "secret-pass", maxBytes: 20 },
    fetchImpl,
  );

  assert.deepEqual(
    files.map((file) => file.name),
    ["notes.txt", "my book.md"],
  );
  assert.equal(new TextDecoder().decode(files[0]?.bytes), "hello");
  assert.equal(new TextDecoder().decode(files[1]?.bytes), "markdown body");
  const propfind = requests[0];
  assert.equal(propfind?.method, "PROPFIND");
  assert.equal(propfind?.url, base);
  assert.equal(propfind?.depth, "1");
  assert.equal(propfind?.authorization, `Basic ${btoa("reader:secret-pass")}`);
  assert.match(propfind?.body ?? "", /propfind/);
  const gets = requests.slice(1).map((request) => request.url);
  assert.deepEqual(gets, [
    "http://127.0.0.1:8765/dav/notes.txt",
    "http://127.0.0.1:8765/dav/picture.cbr",
    "http://127.0.0.1:8765/dav/my%20book.md",
    "http://127.0.0.1:8765/dav/huge.txt",
    "http://127.0.0.1:8765/dav/missing.epub",
  ]);
});

test("a failed listing does not invent a book", async () => {
  const fetchImpl: typeof fetch = async () => new Response("nope", { status: 401 });
  await assert.rejects(
    () => listWebDavFiles({ baseUrl: base, username: "", password: "" }, fetchImpl),
    (error: unknown) => error instanceof WebDavError && !error.message.includes("password"),
  );
});

test("an unprefixed href listing still returns the book in that folder", async () => {
  const fetchImpl: typeof fetch = async (input, init) => {
    if ((init?.method ?? "GET") === "PROPFIND") {
      return new Response(
        `<?xml version="1.0"?><multistatus xmlns="DAV:"><response><href>/dav/plain.txt</href></response></multistatus>`,
        { status: 207 },
      );
    }
    return new Response("plain words", { status: 200 });
  };
  const files = await listWebDavFiles({ baseUrl: base, username: "reader", password: "pw" }, fetchImpl);
  assert.deepEqual(
    files.map((file) => file.name),
    ["plain.txt"],
  );
  assert.equal(new TextDecoder().decode(files[0]?.bytes), "plain words");
});

test("a download that throws keeps the other book", async () => {
  const fetchImpl: typeof fetch = async (input, init) => {
    const url = String(input);
    if ((init?.method ?? "GET") === "PROPFIND") {
      return new Response(listing(["/dav/broken.txt", "/dav/kept.txt"]), { status: 207 });
    }
    if (url.endsWith("/dav/broken.txt")) throw new Error("socket reset secret-pass");
    return new Response("kept", { status: 200 });
  };
  const files = await listWebDavFiles(
    { baseUrl: base, username: "reader", password: "secret-pass" },
    fetchImpl,
  );
  assert.deepEqual(
    files.map((file) => [file.name, new TextDecoder().decode(file.bytes)]),
    [["kept.txt", "kept"]],
  );
});

const encoder = new TextEncoder();

function book(title: string, format: "txt" | "markdown" | "html" | "epub" | "pdf" | "cbz" | "cbt", text: string) {
  return { title, format, bytes: encoder.encode(text) };
}

test("push uploads shelf books the folder does not already have", async () => {
  const puts: { url: string; authorization: string | null; body: string }[] = [];
  const fetchImpl: typeof fetch = async (input, init) => {
    const url = String(input);
    const headers = new Headers(init?.headers);
    if ((init?.method ?? "GET") === "PROPFIND") {
      return new Response(
        listing([
          "/dav/",
          "/dav/notes.txt",
          "/dav/universal-reader-sync.json",
          "/dav/picture.cbr",
          "http://evil.example/stolen.txt",
        ]),
        { status: 207 },
      );
    }
    if (init?.method === "PUT") {
      const raw = init.body instanceof Uint8Array ? init.body : new Uint8Array();
      puts.push({ url, authorization: headers.get("authorization"), body: new TextDecoder().decode(raw) });
      return new Response(null, { status: 201 });
    }
    return new Response("unexpected", { status: 500 });
  };

  const result = await pushWebDavBooks(
    { baseUrl: base, username: "reader", password: "secret-pass", maxBytes: 20 },
    [
      book("notes", "txt", "local notes"),
      book("Chapter", "markdown", "md body"),
      book("../secrets", "txt", "nope"),
      book("Chapter", "markdown", "other body"),
      book("empty", "txt", ""),
      book("big", "txt", "x".repeat(21)),
    ],
    fetchImpl,
  );

  assert.deepEqual(puts, [
    {
      url: "http://127.0.0.1:8765/dav/Chapter.md",
      authorization: `Basic ${btoa("reader:secret-pass")}`,
      body: "md body",
    },
  ]);
  assert.deepEqual(result.pushed, ["Chapter.md"]);
  assert.deepEqual(result.failed, []);
});

test("a failed push keeps the book that did upload", async () => {
  const fetchImpl: typeof fetch = async (input, init) => {
    if ((init?.method ?? "GET") === "PROPFIND") {
      return new Response(listing(["/dav/"]), { status: 207 });
    }
    const url = String(input);
    if (url.endsWith("/kept.txt")) return new Response(null, { status: 201 });
    return new Response("no", { status: 500 });
  };
  const result = await pushWebDavBooks(
    { baseUrl: base, username: "reader", password: "pw" },
    [book("kept", "txt", "kept"), book("lost", "txt", "lost")],
    fetchImpl,
  );
  assert.deepEqual(result.pushed, ["kept.txt"]);
  assert.deepEqual(result.failed, ["lost.txt"]);
});

test("a failed folder listing uploads nothing", async () => {
  let puts = 0;
  const fetchImpl: typeof fetch = async (_input, init) => {
    if (init?.method === "PUT") puts += 1;
    return new Response("nope", { status: 401 });
  };
  await assert.rejects(
    () => pushWebDavBooks({ baseUrl: base, username: "reader", password: "secret-pass" }, [book("notes", "txt", "hi")], fetchImpl),
    (error: unknown) => error instanceof WebDavError && !error.message.includes("secret-pass"),
  );
  assert.equal(puts, 0);
});
