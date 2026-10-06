import { useEffect, useState } from "react";
import { Pressable, ScrollView, StyleSheet, Text, TextInput, View } from "react-native";

import type { ConversationTurn } from "../conversation-store";
import type { Copy } from "../copy";
import type { BookNote } from "../note-store";
import { askCurrentChapter, bookAskExcerpt, readJumpProposal, type BookHit } from "../reading-ai";

type Props = {
  copy: Copy;
  open: boolean;
  onClose: () => void;
  bookId: string;
  title: string;
  excerpt: string;
  placeIndex: number;
  placeCount: number;
  onLoadConversation: (id: string) => Promise<ConversationTurn[]>;
  onRememberConversation: (id: string, turn: ConversationTurn) => Promise<ConversationTurn[]>;
  onLoadNotes: (id: string) => Promise<BookNote[]>;
  onRememberNote: (id: string, turn: ConversationTurn) => Promise<BookNote[]>;
  onConfirmJump: (placeIndex: number) => void;
  onSearchBook?: (query: string) => BookHit[];
  onNotesChanged?: (notes: BookNote[]) => void;
};

export function AskPanel({
  copy,
  open,
  onClose,
  bookId,
  title,
  excerpt,
  placeIndex,
  placeCount,
  onLoadConversation,
  onRememberConversation,
  onLoadNotes,
  onRememberNote,
  onConfirmJump,
  onSearchBook,
  onNotesChanged,
}: Props) {
  const [endpoint, setEndpoint] = useState("");
  const [model, setModel] = useState("");
  const [apiKey, setApiKey] = useState("");
  const [question, setQuestion] = useState("");
  const [answer, setAnswer] = useState<string | null>(null);
  const [askFailed, setAskFailed] = useState(false);
  const [noExcerpt, setNoExcerpt] = useState(false);
  const [noHits, setNoHits] = useState(false);
  const [askBook, setAskBook] = useState(false);
  const [sending, setSending] = useState(false);
  const [turns, setTurns] = useState<ConversationTurn[]>([]);
  const [conversationBroken, setConversationBroken] = useState(false);
  const [notes, setNotes] = useState<BookNote[]>([]);
  const [notesBroken, setNotesBroken] = useState(false);
  const [choices, setChoices] = useState<number[]>([]);

  useEffect(() => {
    let cancelled = false;
    void onLoadConversation(bookId)
      .then((loaded) => {
        if (!cancelled) setTurns(loaded);
      })
      .catch(() => {
        if (!cancelled) setConversationBroken(true);
      });
    return () => {
      cancelled = true;
    };
  }, [bookId, onLoadConversation]);

  useEffect(() => {
    let cancelled = false;
    void onLoadNotes(bookId)
      .then((loaded) => {
        if (!cancelled) {
          setNotes(loaded);
          onNotesChanged?.(loaded);
        }
      })
      .catch(() => {
        if (!cancelled) setNotesBroken(true);
      });
    return () => {
      cancelled = true;
    };
  }, [bookId, onLoadNotes, onNotesChanged]);

  useEffect(() => {
    setAnswer(null);
    setAskFailed(false);
    setNoExcerpt(false);
    setNoHits(false);
    setChoices([]);
  }, [placeIndex, placeCount]);

  async function saveTurn(turn: ConversationTurn) {
    try {
      const saved = await onRememberNote(bookId, turn);
      setNotes(saved);
      onNotesChanged?.(saved);
      setNotesBroken(false);
    } catch {
      setNotesBroken(true);
    }
  }

  async function sendExcerpt() {
    if (sending) return;
    setAnswer(null);
    setAskFailed(false);
    setNoExcerpt(false);
    setNoHits(false);
    setChoices([]);
    let excerptToSend = excerpt;
    let chapterIndex = placeIndex;
    let hitProposals: number[] = [];
    if (askBook) {
      const built = bookAskExcerpt(question, onSearchBook?.(question) ?? [], placeCount);
      if (built.excerpt.length === 0) {
        setNoHits(true);
        return;
      }
      excerptToSend = built.excerpt;
      hitProposals = built.proposals;
      chapterIndex = built.proposals[0] ?? placeIndex;
    } else if (excerpt.trim().length === 0) {
      setNoExcerpt(true);
      return;
    }
    setSending(true);
    try {
      const text = await askCurrentChapter({
        endpoint,
        model,
        apiKey,
        title,
        chapterIndex,
        chapterCount: placeCount,
        excerpt: excerptToSend,
        question,
      });
      const parsed = readJumpProposal(text, placeCount);
      const next = [...hitProposals];
      if (parsed.placeIndex != null && !next.includes(parsed.placeIndex)) next.push(parsed.placeIndex);
      setChoices(next);
      setAnswer(parsed.reply);
      try {
        const saved = await onRememberConversation(bookId, {
          kind: "ask",
          question: question.trim(),
          reply: parsed.reply,
          locatorLabel: `${chapterIndex + 1} / ${placeCount}`,
          createdAtMs: Date.now(),
        });
        setTurns(saved);
        if (saved.some((item) => item.reply === parsed.reply)) setAnswer(null);
      } catch {
        setConversationBroken(true);
      }
    } catch {
      setAskFailed(true);
    } finally {
      setSending(false);
    }
  }

  if (!open) return null;

  return (
    <View style={styles.panel}>
      <View style={styles.bar}>
        <Text style={styles.title}>{copy.askThisPage}</Text>
        <Pressable accessibilityRole="button" onPress={onClose}>
          <Text style={styles.action}>{copy.close}</Text>
        </Pressable>
      </View>
      <ScrollView contentContainerStyle={styles.list} keyboardShouldPersistTaps="handled">
        <Text style={styles.hint}>{askBook ? copy.askBookHint : copy.sendExcerptHint}</Text>
        {onSearchBook != null ? (
          <Pressable
            accessibilityRole="button"
            accessibilityState={{ selected: askBook }}
            onPress={() => {
              setAskBook((value) => !value);
              setNoHits(false);
              setNoExcerpt(false);
              setChoices([]);
            }}
            style={styles.mode}
          >
            <Text style={[styles.action, askBook && styles.modeSelected]}>{copy.askThisBook}</Text>
          </Pressable>
        ) : null}
        <TextInput
          accessibilityLabel={copy.endpointLabel}
          autoCapitalize="none"
          autoCorrect={false}
          onChangeText={setEndpoint}
          placeholder={copy.endpointLabel}
          placeholderTextColor="#8A7358"
          style={styles.field}
          value={endpoint}
        />
        <TextInput
          accessibilityLabel={copy.modelLabel}
          autoCapitalize="none"
          autoCorrect={false}
          onChangeText={setModel}
          placeholder={copy.modelLabel}
          placeholderTextColor="#8A7358"
          style={styles.field}
          value={model}
        />
        <TextInput
          accessibilityLabel={copy.apiKeyLabel}
          autoCapitalize="none"
          autoCorrect={false}
          onChangeText={setApiKey}
          placeholder={copy.apiKeyLabel}
          placeholderTextColor="#8A7358"
          secureTextEntry
          style={styles.field}
          value={apiKey}
        />
        <TextInput
          accessibilityLabel={copy.askQuestionHint}
          onChangeText={setQuestion}
          placeholder={copy.askQuestionHint}
          placeholderTextColor="#8A7358"
          style={styles.field}
          value={question}
        />
        <Pressable
          accessibilityRole="button"
          accessibilityState={{ disabled: sending }}
          disabled={sending}
          onPress={() => {
            void sendExcerpt();
          }}
          style={styles.send}
        >
          <Text style={styles.action}>{sending ? copy.sending : copy.sendExcerpt}</Text>
        </Pressable>
        {noExcerpt ? <Text style={styles.notice}>{copy.noExcerpt}</Text> : null}
        {noHits ? <Text style={styles.notice}>{copy.noHits}</Text> : null}
        {askFailed ? <Text style={styles.notice}>{copy.askFailed}</Text> : null}
        {conversationBroken ? <Text style={styles.notice}>{copy.conversationUnavailable}</Text> : null}
        {notesBroken ? <Text style={styles.notice}>{copy.notesUnavailable}</Text> : null}
        {answer != null ? (
          <Text selectable style={styles.reply}>
            {answer}
          </Text>
        ) : null}
        {choices.map((index) => (
          <Pressable
            accessibilityRole="button"
            key={index}
            onPress={() => {
              setChoices([]);
              onConfirmJump(index);
              onClose();
            }}
          >
            <Text style={styles.action}>{copy.jumpToLocation(`${index + 1} / ${placeCount}`)}</Text>
          </Pressable>
        ))}
        {turns.length > 0 ? <Text style={styles.title}>{copy.conversationHistory}</Text> : null}
        {turns.map((turn, index) => (
          <View key={`${turn.createdAtMs}:${index}`} style={styles.turn}>
            {turn.question.length > 0 ? <Text style={styles.question}>{turn.question}</Text> : null}
            <Text style={styles.hint}>{turn.locatorLabel}</Text>
            <Text selectable style={styles.reply}>
              {turn.reply}
            </Text>
            {notes.some((note) => note.id === String(Math.floor(turn.createdAtMs))) ? (
              <Text style={styles.hint}>{copy.noteSaved}</Text>
            ) : (
              <Pressable
                accessibilityRole="button"
                onPress={() => {
                  void saveTurn(turn);
                }}
              >
                <Text style={styles.action}>{copy.saveAsNote}</Text>
              </Pressable>
            )}
          </View>
        ))}
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  panel: {
    backgroundColor: "#F5F0E8",
    bottom: 0,
    left: 0,
    position: "absolute",
    right: 0,
    top: 0,
  },
  bar: {
    alignItems: "center",
    flexDirection: "row",
    justifyContent: "space-between",
    paddingHorizontal: 16,
    paddingVertical: 12,
  },
  title: {
    color: "#1C2423",
    fontSize: 18,
    fontWeight: "600",
  },
  action: {
    color: "#2F5B57",
    fontSize: 16,
  },
  mode: {
    alignSelf: "flex-start",
    marginLeft: 20,
    marginTop: 8,
  },
  modeSelected: {
    fontWeight: "700",
  },
  list: {
    paddingBottom: 24,
    paddingTop: 8,
  },
  hint: {
    color: "#5C6563",
    fontSize: 16,
    paddingHorizontal: 20,
    paddingTop: 8,
  },
  field: {
    borderColor: "#DDD6C8",
    borderRadius: 8,
    borderWidth: StyleSheet.hairlineWidth,
    color: "#1C2423",
    fontSize: 16,
    marginHorizontal: 16,
    marginTop: 8,
    paddingHorizontal: 12,
    paddingVertical: 10,
  },
  send: {
    paddingHorizontal: 20,
    paddingVertical: 12,
  },
  notice: {
    color: "#8A3D32",
    fontSize: 14,
    lineHeight: 20,
    paddingHorizontal: 20,
  },
  reply: {
    color: "#2A2620",
    fontSize: 18,
    lineHeight: 30,
    paddingHorizontal: 20,
    paddingTop: 8,
  },
  turn: {
    borderTopColor: "#DDD6C8",
    borderTopWidth: StyleSheet.hairlineWidth,
    paddingVertical: 12,
  },
  question: {
    color: "#2A2620",
    fontSize: 16,
    lineHeight: 24,
    paddingHorizontal: 20,
  },
});
