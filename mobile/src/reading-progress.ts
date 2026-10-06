export function readingProgress(index: number, count: number, pageIndex = 0, pageCount = 1): number {
  if (!Number.isInteger(count) || count <= 0 || !Number.isInteger(index) || index < 0) return 0;
  const chapter = Math.min(index, count - 1);
  const pages = Number.isInteger(pageCount) && pageCount > 1 ? pageCount : 1;
  const page = Number.isInteger(pageIndex) && pageIndex > 0 ? Math.min(pageIndex, pages - 1) : 0;
  const pagePart = pages <= 1 ? 0 : page / pages;
  return (chapter + pagePart) / count;
}

export function readingPercent(progress: number): number {
  if (!Number.isFinite(progress)) return 0;
  const clamped = Math.min(1, Math.max(0, progress));
  return Math.round(clamped * 100);
}

export function readingIndexForProgress(progress: number, count: number): number {
  if (!Number.isInteger(count) || count <= 0) return 0;
  const value = Number.isFinite(progress) ? Math.min(0.999, Math.max(0, progress)) : 0;
  return Math.min(count - 1, Math.floor(value * count));
}

export function readingPageIndexForProgress(input: {
  progress: number;
  chapterCount: number;
  chapterIndex: number;
  pageCount: number;
}): number {
  if (input.pageCount <= 0 || input.chapterCount <= 0) return 0;
  const value = Number.isFinite(input.progress) ? Math.min(0.999, Math.max(0, input.progress)) : 0;
  const local = value * input.chapterCount - input.chapterIndex;
  return Math.min(input.pageCount - 1, Math.max(0, Math.floor(local * input.pageCount)));
}
