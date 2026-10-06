import assert from "node:assert/strict";
import test from "node:test";

import { confirmRemoval } from "./shelf-removal";

test("cancelling a removal leaves the book, and confirming removes only that id", () => {
  const pending = { id: "abc", title: "plain" };
  assert.equal(confirmRemoval(null, "delete"), null);
  assert.equal(confirmRemoval(pending, "cancel"), null);
  assert.equal(confirmRemoval({ id: "", title: "plain" }, "delete"), null);
  assert.equal(confirmRemoval(pending, "delete"), "abc");
});
