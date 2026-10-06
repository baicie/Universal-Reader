import { Pressable, StyleSheet, Text, View } from "react-native";

import type { Copy } from "../copy";
import { bookmarkPlace, bookmarksOf, type BookNote } from "../note-store";

type Props = {
  copy: Copy;
  notes: BookNote[];
  onAdd: () => void;
  onOpen: (chapterIndex: number, pageIndex: number) => void;
  onDelete: (id: string) => void;
};

export function BookmarksPanel({ copy, notes, onAdd, onOpen, onDelete }: Props) {
  const marks = bookmarksOf(notes);
  return (
    <View style={styles.panel}>
      <Text style={styles.title}>{copy.bookmarks}</Text>
      <Pressable accessibilityRole="button" onPress={onAdd} style={styles.add}>
        <Text style={styles.addLabel}>{copy.addBookmark}</Text>
      </Pressable>
      {marks.length === 0 ? <Text style={styles.empty}>{copy.noBookmarks}</Text> : null}
      {marks.map((mark) => {
        const place = bookmarkPlace(mark.locatorLabel);
        if (place == null) return null;
        return (
          <View key={mark.id} style={styles.row}>
            <Pressable
              accessibilityRole="button"
              onPress={() => onOpen(place.chapterIndex, place.pageIndex)}
              style={styles.place}
            >
              <Text style={styles.placeLabel}>{copy.bookmarkAt(place.chapterIndex + 1, place.pageIndex + 1)}</Text>
            </Pressable>
            <Pressable accessibilityRole="button" onPress={() => onDelete(mark.id)} style={styles.delete}>
              <Text style={styles.deleteLabel}>{copy.deleteBookmark}</Text>
            </Pressable>
          </View>
        );
      })}
    </View>
  );
}

const styles = StyleSheet.create({
  panel: {
    backgroundColor: "#F7F4EE",
    gap: 8,
    paddingHorizontal: 16,
    paddingVertical: 12,
  },
  title: {
    color: "#1C2423",
    fontSize: 16,
    fontWeight: "600",
  },
  add: {
    alignSelf: "flex-start",
    paddingVertical: 4,
  },
  addLabel: {
    color: "#2F5B57",
    fontSize: 16,
  },
  empty: {
    color: "#8A7358",
    fontSize: 14,
  },
  row: {
    alignItems: "center",
    flexDirection: "row",
    gap: 12,
  },
  place: {
    flex: 1,
    paddingVertical: 4,
  },
  placeLabel: {
    color: "#1C2423",
    fontSize: 16,
  },
  delete: {
    paddingVertical: 4,
  },
  deleteLabel: {
    color: "#8A3D32",
    fontSize: 14,
  },
});
