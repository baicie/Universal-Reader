export type ComicLayout = "single" | "double" | "vertical";
export type ComicReadDirection = "ltr" | "rtl";
export type ComicTapAction = "next" | "previous" | "chrome";

export type NamedComicPage = { name: string };

export type ComicSpread = {
  left: NamedComicPage | null;
  right: NamedComicPage | null;
};

export function parseComicLayout(raw: unknown): ComicLayout {
  return raw === "double" || raw === "vertical" ? raw : "single";
}

export function parseComicReadDirection(raw: unknown): ComicReadDirection {
  return raw === "rtl" ? "rtl" : "ltr";
}

export function comicSpreadCount(pageCount: number, layout: ComicLayout): number {
  if (pageCount <= 0) return 0;
  if (layout === "double") return Math.floor((pageCount + 1) / 2);
  return pageCount;
}

export function comicSpread<T extends NamedComicPage>(input: {
  pages: T[];
  pageIndex: number;
  layout: ComicLayout;
  direction: ComicReadDirection;
}): { left: T | null; right: T | null } {
  const { pages, layout, direction } = input;
  if (pages.length === 0) return { left: null, right: null };
  const index = Math.min(Math.max(input.pageIndex, 0), pages.length - 1);
  if (layout !== "double") return { left: pages[index] ?? null, right: null };
  const start = Math.trunc(index / 2) * 2;
  const first = pages[start] ?? null;
  const second = start + 1 < pages.length ? (pages[start + 1] ?? null) : null;
  if (direction === "ltr") return { left: first, right: second };
  return { left: second, right: first };
}

export function comicNextPageIndex(input: { pageIndex: number; pageCount: number; layout: ComicLayout }): number {
  const { pageIndex, pageCount, layout } = input;
  if (pageCount <= 0) return 0;
  if (layout === "double") {
    const next = (Math.trunc(pageIndex / 2) + 1) * 2;
    if (next >= pageCount) return pageCount - 1;
    return next;
  }
  if (pageIndex >= pageCount - 1) return pageCount - 1;
  return pageIndex + 1;
}

export function comicPreviousPageIndex(input: { pageIndex: number; pageCount: number; layout: ComicLayout }): number {
  const { pageIndex, pageCount, layout } = input;
  if (pageCount <= 0) return 0;
  if (layout === "double") {
    const previous = (Math.trunc(pageIndex / 2) - 1) * 2;
    return previous < 0 ? 0 : previous;
  }
  return pageIndex <= 0 ? 0 : pageIndex - 1;
}

export function comicTapTurn(input: {
  x: number;
  width: number;
  direction: ComicReadDirection;
  layout: ComicLayout;
  pageIndex: number;
  pageCount: number;
}): { pageIndex: number; toggleChrome: boolean } {
  const action = comicTapAction(input.x, input.width, input.direction);
  if (action === "chrome") return { pageIndex: input.pageIndex, toggleChrome: true };
  const pageIndex =
    action === "next"
      ? comicNextPageIndex({ pageIndex: input.pageIndex, pageCount: input.pageCount, layout: input.layout })
      : comicPreviousPageIndex({ pageIndex: input.pageIndex, pageCount: input.pageCount, layout: input.layout });
  return { pageIndex, toggleChrome: false };
}

export function comicTapAction(x: number, width: number, direction: ComicReadDirection): ComicTapAction {
  if (width <= 0) return "chrome";
  const t = x / width;
  if (t < 1 / 3) return direction === "rtl" ? "next" : "previous";
  if (t > 2 / 3) return direction === "rtl" ? "previous" : "next";
  return "chrome";
}
