import { Pressable, StyleSheet, Text, View } from "react-native";

import type { Copy } from "../copy";
import {
  clampFontSize,
  clampLineHeight,
  pdfZoomStops,
  type ReadingPrefs,
} from "../reading-prefs";

type Props = {
  copy: Copy;
  prefs: ReadingPrefs;
  onChange: (prefs: ReadingPrefs) => void;
  showPdfZoom?: boolean;
  showComicLayout?: boolean;
};

export function ReadingSettings({ copy, prefs, onChange, showPdfZoom = false, showComicLayout = false }: Props) {
  const fontStuck = (delta: number) => clampFontSize(prefs.fontSize + delta) === prefs.fontSize;
  const lineStuck = (delta: number) => clampLineHeight(prefs.lineHeight + delta) === prefs.lineHeight;
  return (
    <View style={styles.panel}>
      <Text style={styles.title}>{copy.readingSettings}</Text>
      <View style={styles.row}>
        <Text style={styles.label}>{copy.bodyFontSize}</Text>
        <Step
          disabled={fontStuck(-1)}
          label={copy.smaller}
          onPress={() => onChange({ ...prefs, fontSize: clampFontSize(prefs.fontSize - 1) })}
        />
        <Text style={styles.value}>{String(prefs.fontSize)}</Text>
        <Step
          disabled={fontStuck(1)}
          label={copy.larger}
          onPress={() => onChange({ ...prefs, fontSize: clampFontSize(prefs.fontSize + 1) })}
        />
      </View>
      <View style={styles.row}>
        <Text style={styles.label}>{copy.bodyLineHeight}</Text>
        <Step
          disabled={lineStuck(-0.1)}
          label={copy.tighter}
          onPress={() => onChange({ ...prefs, lineHeight: clampLineHeight(prefs.lineHeight - 0.1) })}
        />
        <Text style={styles.value}>{prefs.lineHeight.toFixed(1)}</Text>
        <Step
          disabled={lineStuck(0.1)}
          label={copy.looser}
          onPress={() => onChange({ ...prefs, lineHeight: clampLineHeight(prefs.lineHeight + 0.1) })}
        />
      </View>
      <View style={styles.row}>
        <Text style={styles.label}>{copy.bodyFontFamily}</Text>
        <Choice
          label={copy.fontSerif}
          onPress={() => onChange({ ...prefs, fontFamily: "serif" })}
          selected={prefs.fontFamily === "serif"}
        />
        <Choice
          label={copy.fontSans}
          onPress={() => onChange({ ...prefs, fontFamily: "sans" })}
          selected={prefs.fontFamily === "sans"}
        />
        <Choice
          label={copy.fontMono}
          onPress={() => onChange({ ...prefs, fontFamily: "mono" })}
          selected={prefs.fontFamily === "mono"}
        />
      </View>
      <View style={styles.row}>
        <Text style={styles.label}>{copy.readingPaper}</Text>
        <Choice
          label={copy.readingPaperFollow}
          onPress={() => onChange({ ...prefs, paper: "followApp" })}
          selected={prefs.paper === "followApp"}
        />
        <Choice
          label={copy.themeLight}
          onPress={() => onChange({ ...prefs, paper: "light" })}
          selected={prefs.paper === "light"}
        />
        <Choice
          label={copy.themeDark}
          onPress={() => onChange({ ...prefs, paper: "dark" })}
          selected={prefs.paper === "dark"}
        />
      </View>
      {showPdfZoom ? (
        <View style={styles.row}>
          <Text style={styles.label}>{copy.pageZoom}</Text>
          {pdfZoomStops.map((stop) => (
            <Choice
              key={stop}
              label={`${Math.round(stop * 100)}%`}
              onPress={() => onChange({ ...prefs, pdfZoom: stop })}
              selected={prefs.pdfZoom === stop}
            />
          ))}
        </View>
      ) : null}
      {showComicLayout ? (
        <View style={styles.row}>
          <Text style={styles.label}>{copy.comicLayout}</Text>
          <Choice
            label={copy.comicLayoutSingle}
            onPress={() => onChange({ ...prefs, comicLayout: "single" })}
            selected={prefs.comicLayout === "single"}
          />
          <Choice
            label={copy.comicLayoutDouble}
            onPress={() => onChange({ ...prefs, comicLayout: "double" })}
            selected={prefs.comicLayout === "double"}
          />
          <Choice
            label={copy.comicLayoutVertical}
            onPress={() => onChange({ ...prefs, comicLayout: "vertical" })}
            selected={prefs.comicLayout === "vertical"}
          />
          <Choice
            label={copy.comicReadRtl}
            onPress={() => onChange({ ...prefs, comicDirection: prefs.comicDirection === "rtl" ? "ltr" : "rtl" })}
            selected={prefs.comicDirection === "rtl"}
          />
        </View>
      ) : null}
    </View>
  );
}

function Step({ disabled, label, onPress }: { disabled: boolean; label: string; onPress: () => void }) {
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityState={{ disabled }}
      disabled={disabled}
      onPress={onPress}
      style={styles.choice}
    >
      <Text style={[styles.choiceLabel, disabled && styles.choiceDisabled]}>{label}</Text>
    </Pressable>
  );
}

function Choice({
  label,
  onPress,
  selected,
}: {
  label: string;
  onPress: () => void;
  selected: boolean;
}) {
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityState={{ selected }}
      onPress={onPress}
      style={[styles.choice, selected && styles.choiceSelected]}
    >
      <Text style={styles.choiceLabel}>{label}</Text>
    </Pressable>
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
  row: {
    alignItems: "center",
    flexDirection: "row",
    flexWrap: "wrap",
    gap: 8,
  },
  label: {
    color: "#5C5346",
    fontSize: 14,
    width: 96,
  },
  value: {
    color: "#1C2423",
    fontSize: 16,
    minWidth: 32,
    textAlign: "center",
  },
  choice: {
    borderColor: "#C4B8A8",
    borderRadius: 8,
    borderWidth: 1,
    paddingHorizontal: 10,
    paddingVertical: 6,
  },
  choiceSelected: {
    backgroundColor: "#E7D7BC",
    borderColor: "#8A7358",
  },
  choiceLabel: {
    color: "#2F5B57",
    fontSize: 14,
  },
  choiceDisabled: {
    color: "#C4B8A8",
  },
});
