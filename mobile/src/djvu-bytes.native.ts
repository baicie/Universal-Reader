import { Asset } from "expo-asset";

declare function require(id: string): number;

const scalarWasm = require("../node_modules/djvu-rs/scalar/djvu_rs_bg.wasm");
const simdWasm = require("../node_modules/djvu-rs/simd128/djvu_rs_bg.wasm");

export async function wasmBytes(simd: boolean): Promise<Uint8Array> {
  const asset = Asset.fromModule(simd ? simdWasm : scalarWasm);
  if (!asset.downloaded) await asset.downloadAsync();
  const uri = asset.localUri ?? asset.uri;
  const response = await fetch(uri);
  if (!response.ok) throw new Error("wasm");
  return new Uint8Array(await response.arrayBuffer());
}
