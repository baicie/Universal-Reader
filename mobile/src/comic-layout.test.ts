import assert from "node:assert/strict";
import test from "node:test";

import {
  comicNextPageIndex,
  comicPreviousPageIndex,
  comicSpread,
  comicSpreadCount,
  comicTapAction,
  comicTapTurn,
  parseComicLayout,
  parseComicReadDirection,
} from "./comic-layout";

const pages = [
  { name: "page-01.png" },
  { name: "page-02.png" },
  { name: "page-03.png" },
];

test("double page pairs two images and leaves the last page alone", () => {
  const first = comicSpread({ pages, pageIndex: 0, layout: "double", direction: "ltr" });
  assert.equal(first.left?.name, "page-01.png");
  assert.equal(first.right?.name, "page-02.png");
  const last = comicSpread({ pages, pageIndex: 2, layout: "double", direction: "ltr" });
  const lastNames = [last.left, last.right].flatMap((page) => (page ? [page.name] : []));
  assert.equal(last.left?.name, "page-03.png");
  assert.equal(last.right, null);
  assert.deepEqual(lastNames, ["page-03.png"]);
});

test("rtl double puts the earlier page on the right", () => {
  const first = comicSpread({ pages, pageIndex: 1, layout: "double", direction: "rtl" });
  assert.equal(first.left?.name, "page-02.png");
  assert.equal(first.right?.name, "page-01.png");
  const last = comicSpread({ pages, pageIndex: 2, layout: "double", direction: "rtl" });
  assert.equal(last.left, null);
  assert.equal(last.right?.name, "page-03.png");
});

test("double page turn skips a spread and stays inside this book", () => {
  assert.equal(comicNextPageIndex({ pageIndex: 0, pageCount: 3, layout: "double" }), 2);
  assert.equal(comicNextPageIndex({ pageIndex: 2, pageCount: 3, layout: "double" }), 2);
  assert.equal(comicPreviousPageIndex({ pageIndex: 2, pageCount: 3, layout: "double" }), 0);
  assert.equal(comicNextPageIndex({ pageIndex: 0, pageCount: 0, layout: "double" }), 0);
});

test("vertical layout keeps one page per slot in file order", () => {
  assert.equal(comicSpreadCount(3, "vertical"), 3);
  assert.equal(comicSpreadCount(3, "double"), 2);
  assert.equal(comicSpreadCount(0, "single"), 0);
  const middle = comicSpread({ pages, pageIndex: 1, layout: "vertical", direction: "rtl" });
  assert.equal(middle.left?.name, "page-02.png");
  assert.equal(middle.right, null);
});

test("ltr tap on the right advances and rtl tap on the left advances", () => {
  assert.equal(comicTapAction(90, 100, "ltr"), "next");
  assert.equal(comicTapAction(10, 100, "ltr"), "previous");
  assert.equal(comicTapAction(10, 100, "rtl"), "next");
  assert.equal(comicTapAction(50, 100, "ltr"), "chrome");
  assert.equal(comicTapAction(10, 0, "ltr"), "chrome");
});

test("a comic tap stays inside this book", () => {
  assert.deepEqual(comicTapTurn({ x: 90, width: 100, direction: "ltr", layout: "single", pageIndex: 0, pageCount: 2 }), {
    pageIndex: 1,
    toggleChrome: false,
  });
  assert.deepEqual(comicTapTurn({ x: 10, width: 100, direction: "ltr", layout: "single", pageIndex: 1, pageCount: 2 }), {
    pageIndex: 0,
    toggleChrome: false,
  });
  assert.deepEqual(comicTapTurn({ x: 50, width: 100, direction: "ltr", layout: "single", pageIndex: 1, pageCount: 2 }), {
    pageIndex: 1,
    toggleChrome: true,
  });
  assert.deepEqual(comicTapTurn({ x: 10, width: 100, direction: "ltr", layout: "single", pageIndex: 0, pageCount: 2 }), {
    pageIndex: 0,
    toggleChrome: false,
  });
  assert.deepEqual(comicTapTurn({ x: 90, width: 100, direction: "ltr", layout: "single", pageIndex: 1, pageCount: 2 }), {
    pageIndex: 1,
    toggleChrome: false,
  });
  assert.deepEqual(comicTapTurn({ x: 90, width: 100, direction: "rtl", layout: "single", pageIndex: 1, pageCount: 2 }), {
    pageIndex: 0,
    toggleChrome: false,
  });
  assert.deepEqual(comicTapTurn({ x: 90, width: 100, direction: "ltr", layout: "double", pageIndex: 0, pageCount: 3 }), {
    pageIndex: 2,
    toggleChrome: false,
  });
  assert.deepEqual(comicTapTurn({ x: 10, width: 0, direction: "ltr", layout: "single", pageIndex: 1, pageCount: 2 }), {
    pageIndex: 1,
    toggleChrome: true,
  });
});

test("unknown layout and direction fall back to single ltr", () => {
  assert.equal(parseComicLayout("wide"), "single");
  assert.equal(parseComicLayout("double"), "double");
  assert.equal(parseComicLayout("vertical"), "vertical");
  assert.equal(parseComicReadDirection("vertical"), "ltr");
  assert.equal(parseComicReadDirection("rtl"), "rtl");
});

test("single page moves by one and stays inside this book", () => {
  assert.equal(comicNextPageIndex({ pageIndex: 0, pageCount: 3, layout: "single" }), 1);
  assert.equal(comicNextPageIndex({ pageIndex: 2, pageCount: 3, layout: "single" }), 2);
  assert.equal(comicNextPageIndex({ pageIndex: 0, pageCount: 1, layout: "vertical" }), 0);
  assert.equal(comicPreviousPageIndex({ pageIndex: 2, pageCount: 3, layout: "single" }), 1);
  assert.equal(comicPreviousPageIndex({ pageIndex: 0, pageCount: 3, layout: "single" }), 0);
  assert.equal(comicPreviousPageIndex({ pageIndex: 0, pageCount: 1, layout: "vertical" }), 0);
});
