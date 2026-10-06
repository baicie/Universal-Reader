import { readFileSync } from "node:fs";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);

export async function wasmBytes(): Promise<ArrayBuffer> {
  const file = readFileSync(require.resolve("7z-wasm/7zz.wasm"));
  return file.buffer.slice(file.byteOffset, file.byteOffset + file.byteLength) as ArrayBuffer;
}
