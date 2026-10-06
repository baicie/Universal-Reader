export type TextSegment = { text: string; highlighted: boolean };

type NoteQuote = { quote: string; source: string };

export function quoteHighlights(notes: NoteQuote[]): string[] {
  const quotes: string[] = [];
  for (const note of notes) {
    if (note.source === "bookmark") continue;
    const quote = note.quote.trim();
    if (quote.length === 0 || quotes.includes(quote)) continue;
    quotes.push(quote);
  }
  return quotes;
}

export function annotatePlainText(text: string, notes: NoteQuote[]): TextSegment[] {
  const quotes = [...quoteHighlights(notes)].sort((left, right) => right.length - left.length);
  if (quotes.length === 0 || text.length === 0) return [{ text, highlighted: false }];
  const segments: TextSegment[] = [];
  let cursor = 0;
  while (cursor < text.length) {
    let hitAt = -1;
    let hit = "";
    for (const quote of quotes) {
      const at = text.indexOf(quote, cursor);
      if (at < 0) continue;
      if (hitAt < 0 || at < hitAt) {
        hitAt = at;
        hit = quote;
      }
    }
    if (hitAt < 0) {
      segments.push({ text: text.slice(cursor), highlighted: false });
      break;
    }
    if (hitAt > cursor) segments.push({ text: text.slice(cursor, hitAt), highlighted: false });
    segments.push({ text: hit, highlighted: true });
    cursor = hitAt + hit.length;
  }
  return segments.length === 0 ? [{ text, highlighted: false }] : segments;
}

export function annotateHtml(html: string, notes: NoteQuote[]): string {
  if (quoteHighlights(notes).length === 0 || html.length === 0) return html;
  let painted = false;
  const marked = html.replace(/(<[^>]*>)|([^<]+)/g, (part, tag: string) => {
    if (tag) return tag;
    const segments = annotatePlainText(part, notes);
    if (segments.every((segment) => !segment.highlighted)) return part;
    painted = true;
    return segments
      .map((segment) => (segment.highlighted ? `<mark class="note">${segment.text}</mark>` : segment.text))
      .join("");
  });
  if (!painted) return html;
  return `<style>mark.note{background:rgba(196,165,116,0.4)}</style>${marked}`;
}
