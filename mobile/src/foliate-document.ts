export type FoliateChapter = {
  hostSource: string;
  paginatorSource: string;
  chapterHtml: string;
  href: string;
  pageIndex: number;
  fragment: string | null;
  quotes?: string[];
  fontSize?: number;
  lineHeight?: number;
  fontFamily?: string;
  background?: string;
  color?: string;
};

function scriptJson(value: unknown): string {
  return JSON.stringify(value).replace(/</g, "\\u003c");
}

function replaceOnce(html: string, pattern: RegExp, replacement: string, label: string): string {
  if (!pattern.test(html)) throw new Error(`foliate host is missing ${label}`);
  return html.replace(pattern, replacement);
}

export function buildFoliateDocument(chapter: FoliateChapter): string {
  let html = replaceOnce(
    chapter.hostSource,
    /await import\('\.\/paginator\.js'\);/,
    "await import(URL.createObjectURL(new Blob([window.__paginatorSource], { type: 'text/javascript' })));",
    "paginator import",
  );
  html = replaceOnce(
    html,
    /function post\(payload\) \{\r?\n      if \(window\.FoliateHost && window\.FoliateHost\.postMessage\) \{\r?\n        window\.FoliateHost\.postMessage\(JSON\.stringify\(payload\)\);\r?\n      \}\r?\n    \}/,
    `function post(payload) {
      var body = JSON.stringify(payload);
      if (window.FoliateHost && window.FoliateHost.postMessage) {
        window.FoliateHost.postMessage(body);
      }
      if (window.ReactNativeWebView && window.ReactNativeWebView.postMessage) {
        window.ReactNativeWebView.postMessage(body);
      }
      if (window.parent && window.parent !== window) {
        window.parent.postMessage(body, "*");
      }
    }`,
    "host post",
  );
  html = replaceOnce(
    html,
    /function viewportFromPaginator\(\) \{\r?\n      if \(!paginator\) return null;\r?\n      var pages = paginator\.pages \|\| 0;\r?\n      var page = paginator\.page \|\| 0;/,
    `function viewportFromPaginator() {
      if (!paginator) return null;
      var pages = 0;
      var page = 0;
      try {
        pages = paginator.pages || 0;
        page = paginator.page || 0;
      } catch (layoutError) {
        return null;
      }`,
    "viewport",
  );
  html = replaceOnce(
    html,
    /async function goToPage\(index\) \{\r?\n      if \(!paginator\) return;\r?\n      var view = viewportFromPaginator\(\);\r?\n      var pageCount = view \? view\.pageCount : 1;\r?\n      var fraction = pageCount <= 1 \? 0 : index \/ pageCount;\r?\n      await paginator\.goTo\(\{ index: 0, anchor: fraction \}\);\r?\n    \}/,
    `async function goToPage(index) {
      if (!paginator) return;
      if (index < 0) {
        await paginator.goTo({ index: 0, anchor: 1 });
        return;
      }
      var view = viewportFromPaginator();
      if (!view) {
        await paginator.goTo({ index: 0, anchor: 0 });
        return;
      }
      if (lastCommand) lastCommand._paged = true;
      var pageCount = view.pageCount;
      var target = index > pageCount - 1 ? pageCount - 1 : index;
      var fraction = pageCount <= 1 ? 0 : target / (pageCount - 1);
      await paginator.goTo({ index: 0, anchor: fraction });
    }`,
    "goToPage",
  );
  html = replaceOnce(
    html,
    /paginator\.addEventListener\('relocate', function \(\) \{\r?\n        postRelocated\(lastCommand\);\r?\n      \}\);/,
    `paginator.addEventListener('relocate', async function () {
        postRelocated(lastCommand);
        if (!lastCommand || !(lastCommand.pageIndex > 0) || lastCommand._paged || lastCommand._paging) return;
        lastCommand._paging = true;
        var contents = paginator.getContents && paginator.getContents();
        var laidOut = contents && contents[0] && contents[0].doc;
        if (laidOut && laidOut.fonts && laidOut.fonts.ready) await laidOut.fonts.ready;
        await new Promise(function (resolve) {
          requestAnimationFrame(function () { requestAnimationFrame(resolve); });
        });
        var placed = viewportFromPaginator();
        lastCommand._paging = false;
        if (!placed) return;
        lastCommand._paged = true;
        if (placed.pageCount <= 1 || placed.pageIndex === lastCommand.pageIndex) return;
        var saved = lastCommand.pageIndex > placed.pageCount - 1 ? placed.pageCount - 1 : lastCommand.pageIndex;
        await paginator.goTo({ index: 0, anchor: saved / (placed.pageCount - 1) });
      });`,
    "relocate",
  );
  html = replaceOnce(
    html,
    /paginator\.addEventListener\('load', function \(\) \{\r?\n        paintQuotes\(\(lastCommand && lastCommand\.quotes\) \|\| \[\]\);\r?\n        bindPaginatorLinks\(\);\r?\n      \}\);/,
    `paginator.addEventListener('load', function (event) {
        paintQuotes((lastCommand && lastCommand.quotes) || []);
        bindPaginatorLinks();
        var doc = event && event.detail && event.detail.doc;
        if (!doc || doc.__selectionWatch) return;
        doc.__selectionWatch = true;
        doc.addEventListener('selectionchange', function () {
          var selected = doc.getSelection && doc.getSelection();
          var text = (selected && selected.toString()) || '';
          post({ type: 'selection', text: text, cfi: currentCfi });
        });
      });`,
    "chapter selection",
  );
  html = replaceOnce(
    html,
    /if \(data\.type === 'paintQuotes'\) paintQuotes\(data\.quotes \|\| \[\]\);/,
    `if (data.type === 'paintQuotes') paintQuotes(data.quotes || []);
      if (data.type === 'next' && window.FoliateView) window.FoliateView.next();
      if (data.type === 'prev' && window.FoliateView) window.FoliateView.prev();`,
    "page turn messages",
  );
  const command = {
    html: chapter.chapterHtml,
    href: chapter.href,
    pageIndex: chapter.pageIndex,
    fragment: chapter.fragment ?? "",
    ...(chapter.quotes != null && chapter.quotes.length > 0 ? { quotes: chapter.quotes } : {}),
    background: chapter.background ?? "#F5F0E8",
    color: chapter.color ?? "#2A2620",
    fontSize: chapter.fontSize ?? 18,
    lineHeight: chapter.lineHeight ?? 1.7,
    ...(chapter.fontFamily != null ? { fontFamily: chapter.fontFamily } : {}),
  };
  const boot =
    `<script>window.__paginatorSource=${scriptJson(chapter.paginatorSource)};` +
    `window.FoliateView.open(${scriptJson(command)});</script>`;
  return replaceOnce(html, /<script type="module">/, `${boot}<script type="module">`, "module script");
}
