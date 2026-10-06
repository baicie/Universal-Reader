import { useState } from "react";
import { Pressable, StyleSheet, Text, View } from "react-native";

import type { Copy } from "../copy";
import { readingPercent } from "../reading-progress";

type Props = {
  copy: Copy;
  progress: number;
  onSeek: (progress: number) => void;
};

export function ReadingProgress({ copy, progress, onSeek }: Props) {
  const [width, setWidth] = useState(0);
  const percent = readingPercent(progress);
  return (
    <View style={styles.wrap}>
      <Text style={styles.percent}>{copy.readingPercent(percent)}</Text>
      <Pressable
        accessibilityLabel={copy.readingProgress}
        accessibilityRole="button"
        onLayout={(event) => setWidth(event.nativeEvent.layout.width)}
        onPress={(event) => {
          if (width <= 0) return;
          const point = event.nativeEvent as { locationX?: number; offsetX?: number };
          const x = point.locationX ?? point.offsetX;
          if (x == null) return;
          onSeek(Math.min(1, Math.max(0, x / width)));
        }}
        style={styles.track}
      >
        <View style={[styles.fill, { width: `${percent}%` }]} />
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: {
    backgroundColor: "#F5F0E8",
    gap: 4,
    paddingHorizontal: 16,
    paddingTop: 8,
  },
  percent: {
    color: "#8A7358",
    fontSize: 14,
  },
  track: {
    backgroundColor: "#E4D8C4",
    height: 28,
    width: "100%",
  },
  fill: {
    backgroundColor: "#2F5B57",
    height: "100%",
  },
});
