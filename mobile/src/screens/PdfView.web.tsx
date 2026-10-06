import { createElement, forwardRef, useImperativeHandle, useLayoutEffect, useRef } from "react";
import { StyleSheet, View } from "react-native";

import { readPdfFailure, readPdfPageText } from "../pdf-document";
import { readChapterSelection, readRelocated } from "../reading-place";
import type { PdfViewHandle } from "./pdf-view-handle";

type Props = {
  html: string;
  onRelocated: (event: { pageIndex: number; pageCount: number }) => void;
  onPageText: (event: { pageIndex: number; text: string }) => void;
  onSelection: (quote: string) => void;
  onFailed: () => void;
};

export const PdfView = forwardRef<PdfViewHandle, Props>(function PdfView(
  { html, onRelocated, onPageText, onSelection, onFailed },
  ref,
) {
  const frame = useRef<HTMLIFrameElement>(null);
  useImperativeHandle(ref, () => ({
    goTo(pageIndex) {
      frame.current?.contentWindow?.postMessage(JSON.stringify({ type: "page", pageIndex }), "*");
    },
    paintQuotes(quotes) {
      frame.current?.contentWindow?.postMessage(JSON.stringify({ type: "quotes", quotes }), "*");
    },
    setZoom(zoom) {
      frame.current?.contentWindow?.postMessage(JSON.stringify({ type: "zoom", zoom }), "*");
    },
  }));
  useLayoutEffect(() => {
    function onMessage(event: MessageEvent) {
      if (event.source !== frame.current?.contentWindow) return;
      if (readPdfFailure(event.data)) {
        onFailed();
        return;
      }
      const quote = readChapterSelection(event.data);
      if (quote) onSelection(quote);
      const pageText = readPdfPageText(event.data);
      if (pageText) onPageText(pageText);
      const relocated = readRelocated(event.data);
      if (relocated) onRelocated(relocated);
    }
    window.addEventListener("message", onMessage);
    return () => window.removeEventListener("message", onMessage);
  }, [onFailed, onPageText, onRelocated, onSelection]);
  return (
    <View style={styles.frame}>
      {createElement("iframe", {
        ref: frame,
        title: "pdf",
        srcDoc: html,
        style: {
          border: 0,
          width: "100%",
          height: "100%",
          background: "#F5F0E8",
        },
      })}
    </View>
  );
});

const styles = StyleSheet.create({
  frame: {
    flex: 1,
    minHeight: 0,
  },
});
