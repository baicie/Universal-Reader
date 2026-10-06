import { createElement, forwardRef, useImperativeHandle, useLayoutEffect, useRef } from "react";
import { StyleSheet, View } from "react-native";

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
  const frame = useRef<HTMLIFrameElement>(null);
  useImperativeHandle(ref, () => ({
    turn(direction) {
      frame.current?.contentWindow?.postMessage(JSON.stringify({ type: direction }), "*");
    },
  }));
  useLayoutEffect(() => {
    function onMessage(event: MessageEvent) {
      if (event.source !== frame.current?.contentWindow) return;
      const quote = readChapterSelection(event.data);
      if (quote) onSelection(quote);
      const relocated = readRelocated(event.data);
      if (relocated) onRelocated(relocated);
    }
    window.addEventListener("message", onMessage);
    return () => window.removeEventListener("message", onMessage);
  }, [onRelocated, onSelection]);
  return (
    <View style={styles.frame}>
      {createElement("iframe", {
        ref: frame,
        title: "chapter",
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
