import { forwardRef, useImperativeHandle, useRef } from "react";
import { StyleSheet } from "react-native";
import { WebView } from "react-native-webview";

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
  const webRef = useRef<WebView>(null);
  useImperativeHandle(ref, () => ({
    goTo(pageIndex) {
      webRef.current?.postMessage(JSON.stringify({ type: "page", pageIndex }));
    },
    paintQuotes(quotes) {
      webRef.current?.postMessage(JSON.stringify({ type: "quotes", quotes }));
    },
    setZoom(zoom) {
      webRef.current?.postMessage(JSON.stringify({ type: "zoom", zoom }));
    },
  }));
  return (
    <WebView
      onMessage={(event) => {
        if (readPdfFailure(event.nativeEvent.data)) {
          onFailed();
          return;
        }
        const quote = readChapterSelection(event.nativeEvent.data);
        if (quote) onSelection(quote);
        const pageText = readPdfPageText(event.nativeEvent.data);
        if (pageText) onPageText(pageText);
        const relocated = readRelocated(event.nativeEvent.data);
        if (relocated) onRelocated(relocated);
      }}
      originWhitelist={["*"]}
      ref={webRef}
      setSupportMultipleWindows={false}
      source={{ html }}
      style={styles.web}
    />
  );
});

const styles = StyleSheet.create({
  web: {
    backgroundColor: "#F5F0E8",
    flex: 1,
    minHeight: 0,
  },
});
