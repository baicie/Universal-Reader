import { openDatabaseAsync, type SQLiteDatabase } from "expo-sqlite";

import type { ShelfDatabase } from "./shelf-store";

function fromExpo(db: SQLiteDatabase): ShelfDatabase {
  return {
    exec(sql) {
      return db.execAsync(sql);
    },
    async all(sql, params = []) {
      return db.getAllAsync<Record<string, unknown>>(sql, params);
    },
    async run(sql, params = []) {
      await db.runAsync(sql, params);
    },
  };
}

export async function openExpoShelfDatabase(): Promise<ShelfDatabase> {
  const db = await openDatabaseAsync("shelf.db");
  return fromExpo(db);
}
