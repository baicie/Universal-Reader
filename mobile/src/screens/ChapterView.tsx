import { forwardRef, useImperativeHandle, useRef } from "react";
import { StyleSheet } from "react-native";
import { WebView } from "react-native-webview";

import { readChapterSelection, readRelocated } from "../reading-place";
import type { ChapterViewHandle } from "./chapter-view-handle";

type Props = {
  html: string;
  onRelocated: (event: { pageIndex: number; pageCount: number }) => void;
  onSelection: (quote: string) => void;
};

export const ChapterView = forwardRef<ChapterViewHandle, Props>(function ChapterView(
  { html, onRelocated, onSelection },
  ref,
) {
  const webRef = useRef<WebView>(null);
  useImperativeHandle(ref, () => ({
    turn(direction) {
      webRef.current?.injectJavaScript(`window.FoliateView&&window.FoliateView.${direction}();true;`);
    },
  }));
  return (
    <WebView
      onMessage={(event) => {
        const quote = readChapterSelection(event.nativeEvent.data);
        if (quote) onSelection(quote);
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
