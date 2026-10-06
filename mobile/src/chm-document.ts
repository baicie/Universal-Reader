import { readChmFromBytes, type ChmChapter } from "./chm-bytes";

export type OpenedChm =
  | { kind: "chm"; document: ChmReaderDocument }
  | { kind: "unavailable" }
  | { kind: "corrupt" };

export function isChmName(name: string): boolean {
  return name.toLowerCase().endsWith(".chm");
}

export async function openChmDocument(bytes: Uint8Array | null): Promise<OpenedChm> {
  if (bytes == null || bytes.length === 0) return { kind: "unavailable" };
  if (bytes.length < 4 || bytes[0] !== 0x49 || bytes[1] !== 0x54 || bytes[2] !== 0x53 || bytes[3] !== 0x46) {
    return { kind: "corrupt" };
  }
  try {
    const result = await readChmFromBytes(bytes);
    if (result == null) return { kind: "unavailable" };
    if (result.chapters.length === 0) return { kind: "corrupt" };
    const title = result.title || result.chapters[0]?.title || "";
    return { kind: "chm", document: new ChmReaderDocument(title, result.chapters) };
  } catch {
    return { kind: "corrupt" };
  }
}

export class ChmReaderDocument {
  private sectionIndex = 0;

  constructor(
    readonly title: string,
    private readonly chapters: ChmChapter[],
  ) {}

  get author(): string {
    return "";
  }

  get chapterIndex(): number {
    return this.sectionIndex;
  }

  get chapterCount(): number {
    return this.chapters.length;
  }

  get currentChapterTitle(): string {
    return this.current.title;
  }

  get currentChapterText(): string {
    return this.current.body;
  }

  get truncated(): boolean {
    return false;
  }

  next(): void {
    if (this.sectionIndex < this.chapterCount - 1) this.sectionIndex += 1;
  }

  previous(): void {
    if (this.sectionIndex > 0) this.sectionIndex -= 1;
  }

  moveTo(index: number): void {
    if (this.chapterCount === 0) return;
    this.sectionIndex = Math.min(Math.max(index, 0), this.chapterCount - 1);
  }

  search(query: string): { chapterIndex: number; excerpt: string }[] {
    const needle = query.trim();
    if (needle.length === 0) return [];
    const hits: { chapterIndex: number; excerpt: string }[] = [];
    for (let index = 0; index < this.chapters.length; index += 1) {
      const chapter = this.chapters[index];
      if (chapter == null) continue;
      const haystack =
        chapter.title.length === 0 || chapter.body.startsWith(chapter.title)
          ? chapter.body
          : `${chapter.title}\n${chapter.body}`;
      const at = haystack.indexOf(needle);
      if (at < 0) continue;
      const from = at < 24 ? 0 : at - 24;
      const to = Math.min(haystack.length, at + needle.length + 24);
      hits.push({ chapterIndex: index, excerpt: haystack.slice(from, to).trim() });
      if (hits.length >= 10) break;
    }
    return hits;
  }

  private get current(): ChmChapter {
    return this.chapters[Math.min(Math.max(this.sectionIndex, 0), this.chapters.length - 1)] ?? { title: "", body: "" };
  }
}
