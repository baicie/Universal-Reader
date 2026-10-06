import assert from "node:assert/strict";
import test from "node:test";

import { S3_BYTE_LIMIT, S3Error, listS3Files, pushS3Books } from "./s3";

const account = {
  endpoint: "https://s3.example.test",
  region: "us-east-1",
  bucket: "books",
  prefix: "library",
  accessKey: "access",
  secretKey: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
  now: new Date("2013-05-24T00:00:00.000Z"),
};

test("the s3 byte limit is 64 MiB", () => {
  assert.equal(S3_BYTE_LIMIT, 64 * 1024 * 1024);
});

test("a non-http s3 endpoint is refused before any request", async () => {
  let called = 0;
  const fetchImpl: typeof fetch = async () => {
    called += 1;
    throw new Error("should not fetch");
  };
  await assert.rejects(
    () =>
      listS3Files(
        {
          ...account,
          endpoint: "file:///tmp/books",
          secretKey: "secret-pass",
        },
        fetchImpl,
      ),
    (error: unknown) => {
      assert.ok(error instanceof S3Error);
      assert.equal(error.message, "s3");
      assert.equal(error.message.includes("secret-pass"), false);
      return true;
    },
  );
  assert.equal(called, 0);
});

test("an empty region or a bucket with a slash is refused before any request", async () => {
  let called = 0;
  const fetchImpl: typeof fetch = async () => {
    called += 1;
    throw new Error("should not fetch");
  };
  await assert.rejects(() => listS3Files({ ...account, region: " " }, fetchImpl), S3Error);
  await assert.rejects(() => listS3Files({ ...account, bucket: "my/bucket" }, fetchImpl), S3Error);
  await assert.rejects(() => listS3Files({ ...account, accessKey: "" }, fetchImpl), S3Error);
  assert.equal(called, 0);
});

test("listing keeps books under the prefix and signs the list request", async () => {
  const calls: { url: string; method: string; authorization: string; hash: string; date: string }[] = [];
  const fetchImpl: typeof fetch = async (input, init) => {
    const url = String(input);
    const headers = new Headers(init?.headers);
    calls.push({
      url,
      method: init?.method ?? "GET",
      authorization: headers.get("authorization") ?? "",
      hash: headers.get("x-amz-content-sha256") ?? "",
      date: headers.get("x-amz-date") ?? "",
    });
    if (url.includes("list-type=2")) {
      return new Response(listXml(false, ["library/notes.txt", "library/b&amp;c.txt", "library/nested/chapter.md", "library/universal-reader-sync.json", "library/book.cbr", "other/secret.txt", "library/../secrets.txt", "library/"]), {
        status: 200,
      });
    }
    if (url.endsWith("/books/library/notes.txt")) {
      return new Response(new Uint8Array([110, 111, 116, 101, 115]), { status: 200 });
    }
    if (url.endsWith("/books/library/b%26c.txt")) {
      return new Response(new Uint8Array([98]), { status: 200 });
    }
    if (url.endsWith("/books/library/nested/chapter.md")) {
      return new Response(new Uint8Array([109, 100]), { status: 200 });
    }
    return new Response("missing", { status: 404 });
  };

  const files = await listS3Files(account, fetchImpl);
  assert.deepEqual(
    files.map((file) => file.name),
    ["notes.txt", "b&c.txt", "chapter.md"],
  );
  assert.equal(new TextDecoder().decode(files[0]?.bytes), "notes");
  const list = calls[0];
  assert.equal(list?.method, "GET");
  assert.equal(list?.url, "https://s3.example.test/books?list-type=2&prefix=library%2F");
  assert.equal(list?.date, "20130524T000000Z");
  assert.equal(list?.hash, "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855");
  assert.equal(
    list?.authorization,
    "AWS4-HMAC-SHA256 Credential=access/20130524/us-east-1/s3/aws4_request, SignedHeaders=host;x-amz-content-sha256;x-amz-date, Signature=dc9af19cfa54c7dab1741629f6312545f8c7e93aa4013fa901b08535ac0ff845",
  );
  assert.equal(list?.authorization.includes(account.secretKey), false);
  assert.equal(
    calls.some((call) => call.url.includes("secret") || call.url.includes("universal-reader-sync")),
    false,
  );
});

test("a truncated listing follows the continuation token and a failed object does not drop the rest", async () => {
  const urls: string[] = [];
  const fetchImpl: typeof fetch = async (input) => {
    const url = String(input);
    urls.push(url);
    if (url.includes("continuation-token=page-two")) {
      return new Response(listXml(false, ["library/chapter.md"]), { status: 200 });
    }
    if (url.includes("list-type=2")) {
      return new Response(
        `${listXml(true, ["library/notes.txt"])}<NextContinuationToken>page-two</NextContinuationToken>`,
        { status: 200 },
      );
    }
    if (url.endsWith("/notes.txt")) {
      throw new Error("network");
    }
    if (url.endsWith("/chapter.md")) {
      return new Response(new Uint8Array([109]), { status: 200 });
    }
    return new Response("no", { status: 500 });
  };

  const files = await listS3Files(account, fetchImpl);
  assert.deepEqual(
    files.map((file) => file.name),
    ["chapter.md"],
  );
  assert.equal(urls.some((url) => url.includes("continuation-token=page-two")), true);
});

test("an object larger than the limit is skipped", async () => {
  const fetchImpl: typeof fetch = async (input) => {
    const url = String(input);
    if (url.includes("list-type=2")) {
      return new Response(listXml(false, ["library/notes.txt", "library/huge.txt"]), { status: 200 });
    }
    if (url.endsWith("/huge.txt")) {
      return new Response(new Uint8Array(21), { status: 200, headers: { "content-length": "21" } });
    }
    return new Response(new Uint8Array([49]), { status: 200 });
  };
  const files = await listS3Files({ ...account, maxBytes: 20 }, fetchImpl);
  assert.deepEqual(
    files.map((file) => file.name),
    ["notes.txt"],
  );
});

test("a failed listing uploads nothing and does not invent a book", async () => {
  let gets = 0;
  const fetchImpl: typeof fetch = async (input) => {
    const url = String(input);
    if (!url.includes("list-type=2")) gets += 1;
    return new Response("denied", { status: 403 });
  };
  await assert.rejects(() => listS3Files(account, fetchImpl), (error: unknown) => {
    assert.ok(error instanceof S3Error);
    assert.equal(error.message.includes(account.secretKey), false);
    return true;
  });
  assert.equal(gets, 0);
});

test("a truncated page without a continuation token does not return partial books", async () => {
  let gets = 0;
  const fetchImpl: typeof fetch = async (input) => {
    const url = String(input);
    if (!url.includes("list-type=2")) gets += 1;
    return new Response(listXml(true, ["library/notes.txt"]), { status: 200 });
  };
  await assert.rejects(() => listS3Files(account, fetchImpl), S3Error);
  assert.equal(gets, 0);
});

test("push uploads shelf books the prefix does not already have", async () => {
  const puts: { url: string; authorization: string; hash: string; body: string }[] = [];
  const fetchImpl: typeof fetch = async (input, init) => {
    const url = String(input);
    const headers = new Headers(init?.headers);
    if (url.includes("list-type=2")) {
      return new Response(
        listXml(false, [
          "library/notes.txt",
          "library/nested/kept.txt",
          "library/picture.cbr",
          "library/universal-reader-sync.json",
          "other/Chapter.md",
          "library/../stolen.txt",
        ]),
        { status: 200 },
      );
    }
    if (init?.method === "PUT") {
      const raw = init.body instanceof Uint8Array ? init.body : new Uint8Array();
      puts.push({
        url,
        authorization: headers.get("authorization") ?? "",
        hash: headers.get("x-amz-content-sha256") ?? "",
        body: new TextDecoder().decode(raw),
      });
      return new Response(null, { status: 200 });
    }
    return new Response("unexpected", { status: 500 });
  };

  const result = await pushS3Books(
    { ...account, maxBytes: 20 },
    [
      book("notes", "txt", "local notes"),
      book("kept", "txt", "already nested"),
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
      url: "https://s3.example.test/books/library/Chapter.md",
      authorization:
        "AWS4-HMAC-SHA256 Credential=access/20130524/us-east-1/s3/aws4_request, SignedHeaders=host;x-amz-content-sha256;x-amz-date, Signature=af04619027c6f18197cebe01377116cf0bc4ffb8e6d6f77adc477d2b74b16010",
      hash: "4a88e4ccb20fded3a09b1ab1005cde51b604102680e96705adfaec446580db4d",
      body: "md body",
    },
  ]);
  assert.equal(puts[0]?.authorization.includes(account.secretKey), false);
  assert.deepEqual(result.pushed, ["Chapter.md"]);
  assert.deepEqual(result.failed, []);
});

test("a failed s3 upload keeps the book that did upload", async () => {
  const fetchImpl: typeof fetch = async (input, init) => {
    const url = String(input);
    if (url.includes("list-type=2")) return new Response(listXml(false, []), { status: 200 });
    if (url.endsWith("/kept.txt")) return new Response(null, { status: 200 });
    if (url.endsWith("/lost.txt")) throw new Error("network");
    return new Response("no", { status: 500 });
  };
  const result = await pushS3Books(account, [book("kept", "txt", "kept"), book("lost", "txt", "lost")], fetchImpl);
  assert.deepEqual(result.pushed, ["kept.txt"]);
  assert.deepEqual(result.failed, ["lost.txt"]);
});

test("a failed s3 listing uploads nothing", async () => {
  let puts = 0;
  const fetchImpl: typeof fetch = async (_input, init) => {
    if (init?.method === "PUT") puts += 1;
    return new Response("denied", { status: 403 });
  };
  await assert.rejects(
    () => pushS3Books(account, [book("notes", "txt", "hi")], fetchImpl),
    (error: unknown) => error instanceof S3Error && !error.message.includes(account.secretKey),
  );
  assert.equal(puts, 0);
});

function book(title: string, format: "txt" | "markdown", bytes: string) {
  return { title, format, bytes: new TextEncoder().encode(bytes) };
}

function listXml(truncated: boolean, keys: string[]): string {
  const contents = keys.map((key) => `<Contents><Key>${key}</Key></Contents>`).join("");
  return `<ListBucketResult>${contents}<IsTruncated>${truncated ? "true" : "false"}</IsTruncated></ListBucketResult>`;
}
