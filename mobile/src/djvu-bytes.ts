import { readFileSync } from "node:fs";
import { createRequire } from "node:module";
import { dirname, join } from "node:path";

const require = createRequire(import.meta.url);

export function wasmBytes(simd: boolean): Uint8Array {
  const root = dirname(require.resolve("djvu-rs"));
  return new Uint8Array(readFileSync(join(root, simd ? "simd128" : "scalar", "djvu_rs_bg.wasm")));
}
