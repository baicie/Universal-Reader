export type PendingRemoval = {
  id: string;
  title: string;
};

export function confirmRemoval(pending: PendingRemoval | null, choice: "cancel" | "delete"): string | null {
  if (pending == null || choice === "cancel" || pending.id.length === 0) return null;
  return pending.id;
}
