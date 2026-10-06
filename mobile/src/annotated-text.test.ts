import assert from "node:assert/strict";
import test from "node:test";

import { annotateHtml, annotatePlainText, quoteHighlights } from "./annotated-text";

const note = {
  quote: "hello from notes",
  source: "assistant",
};

test("a quote that appears in the chapter is marked and the other words stay", () => {
  const segments = annotatePlainText("before hello from notes after", [note]);
  assert.deepEqual(segments, [
    { text: "before ", highlighted: false },
    { text: "hello from notes", highlighted: true },
    { text: " after", highlighted: false },
  ]);
  assert.equal(segments.map((segment) => segment.text).join(""), "before hello from notes after");
});

test("the same quote on two notes is one highlight", () => {
  const notes = [
    { quote: "second chapter text", source: "user" },
    { quote: "  second chapter text  ", source: "assistant" },
  ];
  assert.deepEqual(quoteHighlights(notes), ["second chapter text"]);
  assert.deepEqual(annotatePlainText("second chapter text", notes), [
    { text: "second chapter text", highlighted: true },
  ]);
});

test("a missing quote leaves the chapter unchanged", () => {
  const segments = annotatePlainText("no match here", [note]);
  assert.deepEqual(segments, [{ text: "no match here", highlighted: false }]);
  assert.equal(segments.map((segment) => segment.text).join("").includes("hello from notes"), false);
});

test("bookmarks and blank quotes are not painted", () => {
  const segments = annotatePlainText("hello from notes", [
    { quote: "hello from notes", source: "bookmark" },
    { quote: "   ", source: "assistant" },
  ]);
  assert.deepEqual(segments, [{ text: "hello from notes", highlighted: false }]);
});

test("the longer quote wins when both could mark the same words", () => {
  const segments = annotatePlainText("needle", [
    { quote: "ne", source: "user" },
    { quote: "needle", source: "assistant" },
  ]);
  assert.deepEqual(segments, [{ text: "needle", highlighted: true }]);
});

test("every occurrence of the quote is marked", () => {
  const segments = annotatePlainText("aa bb aa bb", [{ quote: "aa", source: "user" }]);
  assert.deepEqual(
    segments.filter((segment) => segment.highlighted).map((segment) => segment.text),
    ["aa", "aa"],
  );
  assert.equal(segments.map((segment) => segment.text).join(""), "aa bb aa bb");
});

test("epub html marks the chapter text and leaves an attribute alone", () => {
  const html = `<p title="second chapter text">hello from epub</p>`;
  const marked = annotateHtml(html, [{ quote: "hello from epub", source: "assistant" }]);
  assert.equal(marked.includes(`<mark class="note">hello from epub</mark>`), true);
  assert.equal(marked.includes(`<mark class="note">second chapter text</mark>`), false);
  assert.equal(marked.includes(`title="second chapter text"`), true);

  const missing = annotateHtml(html, [{ quote: "hello shelf", source: "assistant" }]);
  assert.equal(missing, html);
  assert.equal(missing.includes("hello shelf"), false);
});
