import { Buffer } from "buffer";

import { pdfQuoteBoxes } from "./pdf-document";
import { clampPdfZoom } from "./reading-prefs";

export function buildPdfViewer(input: {
  pdfjsSource: string;
  pdfWorkerSource: string;
  bytes: Uint8Array;
  pageIndex: number;
  zoom?: number;
}): string {
  const open = { base64: Buffer.from(input.bytes).toString("base64"), pageIndex: input.pageIndex };
  const pageZoom = clampPdfZoom(input.zoom ?? 1);
  return `<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <style>
    html, body { margin: 0; height: 100%; background: #F5F0E8; }
    body { overflow: auto; }
    #stage { position: relative; width: fit-content; margin: 0 auto; }
    #text { position: absolute; left: 0; top: 0; }
    #text span { position: absolute; color: transparent; white-space: pre; }
    #notes { position: absolute; inset: 0; pointer-events: none; }
    canvas { display: block; margin: 0; background: #fff; }
  </style>
</head>
<body>
  <div id="stage">
    <canvas id="page"></canvas>
    <div id="text"></div>
    <div id="notes"></div>
  </div>
  <script>
    window.__pdfQuotes = [];
    window.addEventListener("message", function (event) {
      var data = event.data;
      if (typeof data === "string") {
        try { data = JSON.parse(data); } catch (error) { return; }
      }
      if (data && data.type === "quotes" && Array.isArray(data.quotes)) {
        window.__pdfQuotes = data.quotes.filter(function (quote) { return typeof quote === "string"; });
        if (window.__paintPdfQuotes) window.__paintPdfQuotes();
      }
    });
  </script>
  <script>
    window.__pdfjsSource = ${scriptJson(input.pdfjsSource)};
    window.__pdfWorkerSource = ${scriptJson(input.pdfWorkerSource)};
    window.__pdfOpen = ${scriptJson(open)};
  </script>
  <script type="module">
    var pdfjs = await import(URL.createObjectURL(new Blob([window.__pdfjsSource], { type: "text/javascript" })));
    pdfjs.GlobalWorkerOptions.workerSrc = URL.createObjectURL(new Blob([window.__pdfWorkerSource], { type: "text/javascript" }));
    ${pdfQuoteBoxes.toString()}
    var pdfDoc = null;
    var renderToken = 0;
    var current = 0;
    var textRuns = [];
    var pageZoom = ${pageZoom};

    function paintQuotes() {
      var layer = document.getElementById("notes");
      if (!layer) return;
      layer.replaceChildren();
      var boxes = pdfQuoteBoxes(textRuns, window.__pdfQuotes || []);
      for (var i = 0; i < boxes.length; i++) {
        var box = boxes[i];
        var mark = document.createElement("div");
        mark.className = "note";
        mark.style.position = "absolute";
        mark.style.left = box.x + "px";
        mark.style.top = box.y + "px";
        mark.style.width = box.width + "px";
        mark.style.height = box.height + "px";
        mark.style.background = "rgba(196, 165, 116, 0.4)";
        layer.appendChild(mark);
      }
    }
    window.__paintPdfQuotes = paintQuotes;

    document.addEventListener("selectionchange", function () {
      var layer = document.getElementById("text");
      var selected = window.getSelection && window.getSelection();
      var anchor = selected && selected.anchorNode;
      if (!layer || !anchor || !layer.contains(anchor)) return;
      var text = selected.toString();
      if (!text.trim()) return;
      post({ type: "selection", text: text });
    });

    function paintTextLayer(viewport) {
      var layer = document.getElementById("text");
      if (!layer) return;
      layer.replaceChildren();
      layer.style.width = viewport.width + "px";
      layer.style.height = viewport.height + "px";
      for (var i = 0; i < textRuns.length; i++) {
        var run = textRuns[i];
        if (!run.str) continue;
        var span = document.createElement("span");
        span.textContent = run.str;
        span.style.left = run.x + "px";
        span.style.top = run.y + "px";
        span.style.fontSize = Math.max(run.height, 1) + "px";
        span.style.lineHeight = Math.max(run.height, 1) + "px";
        if (run.width > 0) span.style.width = run.width + "px";
        layer.appendChild(span);
      }
    }

    function post(payload) {
      var body = JSON.stringify(payload);
      if (window.ReactNativeWebView && window.ReactNativeWebView.postMessage) {
        window.ReactNativeWebView.postMessage(body);
      }
      if (window.parent && window.parent !== window) {
        window.parent.postMessage(body, "*");
      }
    }

    async function show(index) {
      if (!pdfDoc) return;
      var token = ++renderToken;
      var pageNumber = index < 0 ? 0 : index;
      if (pageNumber > pdfDoc.numPages - 1) pageNumber = pdfDoc.numPages - 1;
      current = pageNumber;
      var page = await pdfDoc.getPage(pageNumber + 1);
      if (token !== renderToken) return;
      var canvas = document.getElementById("page");
      var base = page.getViewport({ scale: 1 });
      var width = document.documentElement.clientWidth || base.width;
      var fitted = width / base.width;
      var viewport = page.getViewport({ scale: fitted * pageZoom });
      var ratio = window.devicePixelRatio || 1;
      canvas.width = Math.floor(viewport.width * ratio);
      canvas.height = Math.floor(viewport.height * ratio);
      canvas.style.width = viewport.width + "px";
      canvas.style.height = viewport.height + "px";
      var context = canvas.getContext("2d");
      if (!context) {
        post({ type: "failed" });
        return;
      }
      var params = { canvasContext: context, viewport: viewport };
      if (ratio !== 1) params.transform = [ratio, 0, 0, ratio, 0, 0];
      try {
        await page.render(params).promise;
      } catch {
        if (token !== renderToken) return;
      }
      if (token !== renderToken) return;
      var text = "";
      try {
        var content = await page.getTextContent();
        if (token !== renderToken) return;
        var parts = [];
        var runs = [];
        var items = content.items || [];
        for (var n = 0; n < items.length; n++) {
          var item = items[n];
          if (!item || typeof item.str !== "string") continue;
          var tx = pdfjs.Util.transform(viewport.transform, item.transform || [1, 0, 0, 1, 0, 0]);
          var fontHeight = Math.hypot(tx[2], tx[3]);
          runs.push({
            str: item.str,
            x: tx[4],
            y: tx[5] - fontHeight,
            width: (typeof item.width === "number" ? item.width : 0) * viewport.scale,
            height: fontHeight,
            hasEOL: item.hasEOL === true
          });
          parts.push(item.str);
          if (item.hasEOL) parts.push("\\n");
        }
        text = parts.join("");
        textRuns = runs;
      } catch (textError) {
        text = "";
        textRuns = [];
      }
      if (token !== renderToken) return;
      var notes = document.getElementById("notes");
      if (notes) notes.replaceChildren();
      paintTextLayer(viewport);
      post({ type: "text", pageIndex: pageNumber, text: text });
      post({ type: "relocated", pageIndex: pageNumber, pageCount: pdfDoc.numPages });
      paintQuotes();
    }

    window.addEventListener("resize", function () {
      if (pdfDoc) show(current);
    });

    async function open(command) {
      try {
        var binary = atob(command.base64);
        var bytes = new Uint8Array(binary.length);
        for (var i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
        var task = pdfjs.getDocument({ data: bytes, isEvalSupported: false, enableScripting: false });
        pdfDoc = await task.promise;
        await show(command.pageIndex || 0);
      } catch (error) {
        post({ type: "failed" });
      }
    }

    window.addEventListener("message", function (event) {
      var data = event.data;
      if (typeof data === "string") {
        try { data = JSON.parse(data); } catch (error) { return; }
      }
      if (!data) return;
      if (data.type === "zoom" && typeof data.zoom === "number" && Number.isFinite(data.zoom)) {
        pageZoom = data.zoom;
        if (pdfDoc) show(current);
        return;
      }
      if (data.type !== "page" || typeof data.pageIndex !== "number") return;
      show(data.pageIndex);
    });

    open(window.__pdfOpen);
  </script>
</body>
</html>`;
}

function scriptJson(value: unknown): string {
  return JSON.stringify(value).replace(/</g, "\\u003c");
}
