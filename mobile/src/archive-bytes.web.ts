import { Asset } from "expo-asset";

declare function require(id: string): number;

const wasmModule = require("7z-wasm/7zz.wasm");

export async function wasmBytes(): Promise<ArrayBuffer> {
  const asset = Asset.fromModule(wasmModule);
  if (!asset.downloaded) await asset.downloadAsync();
  const uri = asset.localUri ?? asset.uri;
  const response = await fetch(uri);
  if (!response.ok) throw new Error("wasm");
  return response.arrayBuffer();
}
