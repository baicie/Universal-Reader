import { Pressable, StyleSheet, View } from "react-native";

import type { Copy } from "../copy";

type Props = {
  copy: Copy;
  onTap: (x: number, width: number) => void;
};

export function ReflowTapZones({ copy, onTap }: Props) {
  return (
    <View pointerEvents="box-none" style={styles.zones}>
      <Pressable
        accessibilityLabel={copy.previousSide}
        accessibilityRole="button"
        onPress={() => onTap(0, 3)}
        style={styles.side}
      />
      <View pointerEvents="none" style={styles.center} />
      <Pressable
        accessibilityLabel={copy.nextSide}
        accessibilityRole="button"
        onPress={() => onTap(3, 3)}
        style={styles.side}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  zones: {
    bottom: 0,
    flexDirection: "row",
    left: 0,
    position: "absolute",
    right: 0,
    top: 0,
  },
  side: {
    flex: 1,
  },
  center: {
    flex: 1,
  },
});
