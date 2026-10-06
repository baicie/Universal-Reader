import { ensureShelfSchema, type ShelfDatabase } from "./shelf-store";

export const MAX_CONVERSATION_TURNS = 50;

const kinds = new Set(["summarize", "explain", "translate", "ask"]);

export type ConversationKind = "summarize" | "explain" | "translate" | "ask";

export type ConversationTurn = {
  kind: ConversationKind;
  question: string;
  reply: string;
  locatorLabel: string;
  createdAtMs: number;
};

export class ConversationError extends Error {
  constructor() {
    super("conversation");
    this.name = "ConversationError";
  }
}

export function trimConversation(turns: ConversationTurn[]): ConversationTurn[] {
  if (turns.length <= MAX_CONVERSATION_TURNS) return turns.slice();
  return turns.slice(turns.length - MAX_CONVERSATION_TURNS);
}

export async function loadBookConversation(db: ShelfDatabase, documentId: string): Promise<ConversationTurn[]> {
  if (documentId.length === 0) return [];
  await ensureShelfSchema(db);
  const rows = await db.all("SELECT turns_json FROM conversations WHERE document_id = ?", [documentId]);
  const raw = rows[0]?.turns_json;
  if (typeof raw !== "string") return [];
  return parseTurns(raw);
}

export async function appendBookConversation(
  db: ShelfDatabase,
  documentId: string,
  turn: ConversationTurn,
): Promise<ConversationTurn[]> {
  const existing = await loadBookConversation(db, documentId);
  if (turn.reply.trim().length === 0 || documentId.length === 0) return existing;
  const next = trimConversation([
    ...existing,
    {
      kind: turn.kind,
      question: turn.question,
      reply: turn.reply.trim(),
      locatorLabel: turn.locatorLabel,
      createdAtMs: openedAt(turn.createdAtMs),
    },
  ]);
  await db.run("INSERT OR REPLACE INTO conversations (document_id, turns_json) VALUES (?, ?)", [
    documentId,
    JSON.stringify(next.map(toStored)),
  ]);
  return next;
}

function parseTurns(raw: string): ConversationTurn[] {
  let decoded: unknown;
  try {
    decoded = JSON.parse(raw);
  } catch {
    throw new ConversationError();
  }
  if (!Array.isArray(decoded)) throw new ConversationError();
  return decoded.map((item) => {
    if (item == null || typeof item !== "object") throw new ConversationError();
    const record = item as Record<string, unknown>;
    const reply = record.reply;
    if (typeof reply !== "string") throw new ConversationError();
    return {
      kind: kindFrom(record.kind),
      question: textFrom(record.question),
      reply,
      locatorLabel: textFrom(record.locator_label ?? record.locatorLabel),
      createdAtMs: openedAt(record.created_at_ms ?? record.createdAtMs),
    };
  });
}

function toStored(turn: ConversationTurn): Record<string, string | number> {
  return {
    kind: turn.kind,
    question: turn.question,
    reply: turn.reply,
    locator_label: turn.locatorLabel,
    created_at_ms: turn.createdAtMs,
  };
}

function kindFrom(value: unknown): ConversationKind {
  return typeof value === "string" && kinds.has(value) ? (value as ConversationKind) : "ask";
}

function textFrom(value: unknown): string {
  if (value == null) return "";
  if (typeof value !== "string") throw new ConversationError();
  return value;
}

function openedAt(value: unknown): number {
  if (typeof value !== "number" || !Number.isFinite(value) || value < 0) return 0;
  return Math.floor(value);
}
