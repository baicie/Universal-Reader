import { Pressable, StyleSheet, Text, View } from "react-native";

import type { Copy } from "../copy";
import { bookmarkPlace, noteListLabel, notesOf, type BookNote } from "../note-store";

type Props = {
  copy: Copy;
  notes: BookNote[];
  onOpen: (chapterIndex: number, pageIndex: number) => void;
  onDelete: (id: string) => void;
};

export function NotesPanel({ copy, notes, onOpen, onDelete }: Props) {
  const marks = notesOf(notes);
  return (
    <View style={styles.panel}>
      <Text style={styles.title}>{copy.notesTitle}</Text>
      {marks.length === 0 ? <Text style={styles.empty}>{copy.noNotes}</Text> : null}
      {marks.map((mark) => {
        const place = bookmarkPlace(mark.locatorLabel);
        const label = noteListLabel(mark);
        return (
          <View key={mark.id} style={styles.row}>
            {place ? (
              <Pressable
                accessibilityRole="button"
                onPress={() => onOpen(place.chapterIndex, place.pageIndex)}
                style={styles.place}
              >
                <Text style={styles.placeLabel}>{label}</Text>
              </Pressable>
            ) : (
              <Text style={styles.placeLabel}>{label}</Text>
            )}
            <Pressable accessibilityRole="button" onPress={() => onDelete(mark.id)} style={styles.delete}>
              <Text style={styles.deleteLabel}>{copy.deleteNote}</Text>
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
    flex: 1,
    fontSize: 16,
  },
  delete: {
    paddingVertical: 4,
  },
  deleteLabel: {
    color: "#8A7358",
    fontSize: 14,
  },
});
