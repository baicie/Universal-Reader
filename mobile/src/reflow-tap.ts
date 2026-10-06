import { turnBackward, turnForward, type ReadingPlace } from "./reading-place";

export type ReflowTapAction = "next" | "previous" | "chrome";

export function reflowTapAction(x: number, width: number): ReflowTapAction {
  if (!(width > 0)) return "chrome";
  const t = x / width;
  if (t < 1 / 3) return "previous";
  if (t > 2 / 3) return "next";
  return "chrome";
}

export function reflowTapTurn(input: {
  x: number;
  width: number;
  chapterIndex: number;
  pageIndex: number;
  pageCount: number;
  chapterCount: number;
  pendingQuote: boolean;
}): { place: ReadingPlace; toggleChrome: boolean } {
  const place = { chapterIndex: input.chapterIndex, pageIndex: input.pageIndex };
  const action = reflowTapAction(input.x, input.width);
  if (action === "chrome") return { place, toggleChrome: !input.pendingQuote };
  if (!(input.pageCount >= 1)) return { place, toggleChrome: false };
  const next =
    action === "next"
      ? turnForward(place, input.pageCount, input.chapterCount)
      : turnBackward(place);
  return { place: next, toggleChrome: false };
}
