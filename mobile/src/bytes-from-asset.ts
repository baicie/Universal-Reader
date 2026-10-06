import type { DocumentPickerAsset } from "expo-document-picker";
import { File as ExpoFile } from "expo-file-system";

export async function bytesFromAsset(asset: DocumentPickerAsset): Promise<Uint8Array> {
  if (asset.file) {
    return new Uint8Array(await asset.file.arrayBuffer());
  }
  return new ExpoFile(asset.uri).bytes();
}
