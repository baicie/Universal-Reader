import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import test from "node:test";

import { listS3Files } from "./s3";
import { contentHash } from "./shelf-store";

test("book identities and S3 signatures remain compatible without browser WebCrypto", async () => {
  const descriptor = Object.getOwnPropertyDescriptor(globalThis, "crypto");
  Object.defineProperty(globalThis, "crypto", { configurable: true, value: undefined });
  try {
    for (const bytes of [new Uint8Array(), new TextEncoder().encode("abc"), Uint8Array.of(0, 255, 128, 1)]) {
      assert.equal(await contentHash(bytes), createHash("sha256").update(bytes).digest("hex"));
    }
    let calls = 0;
    const fetchImpl: typeof fetch = async (_input, init) => {
      calls += 1;
      const headers = new Headers(init?.headers);
      assert.equal(headers.get("x-amz-content-sha256"), "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855");
      assert.equal(
        headers.get("authorization"),
        "AWS4-HMAC-SHA256 Credential=access/20130524/us-east-1/s3/aws4_request, SignedHeaders=host;x-amz-content-sha256;x-amz-date, Signature=dc9af19cfa54c7dab1741629f6312545f8c7e93aa4013fa901b08535ac0ff845",
      );
      return new Response("<ListBucketResult><IsTruncated>false</IsTruncated></ListBucketResult>");
    };
    assert.deepEqual(await listS3Files({
      endpoint: "https://s3.example.test",
      region: "us-east-1",
      bucket: "books",
      prefix: "library",
      accessKey: "access",
      // Public AWS documentation example, never a real account credential.
      secretKey: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
      now: new Date("2013-05-24T00:00:00.000Z"),
    }, fetchImpl), []);
    assert.equal(calls, 1);
  } finally {
    if (descriptor) Object.defineProperty(globalThis, "crypto", descriptor);
    else Reflect.deleteProperty(globalThis, "crypto");
  }
});
