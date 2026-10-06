import SevenZip from "7z-wasm";
import type { SevenZipModule } from "7z-wasm";

import { wasmBytes } from "./archive-bytes";
import { FormatError } from "./text-document";

let loading: Promise<SevenZipModule> | null = null;
let gate: Promise<void> = Promise.resolve();
let ticket = 0;

function engine(): Promise<SevenZipModule> {
  loading ??= wasmBytes().then((wasmBinary) =>
    SevenZip({
      wasmBinary,
      print() {},
      printErr() {},
    }),
  );
  return loading;
}

export async function extractArchive(bytes: Uint8Array): Promise<[string, Uint8Array][]> {
  const previous = gate;
  let release: () => void = () => undefined;
  gate = new Promise((resolve) => {
    release = resolve;
  });
  await previous;
  try {
    return await extractNow(bytes);
  } finally {
    release();
  }
}

async function extractNow(bytes: Uint8Array): Promise<[string, Uint8Array][]> {
  const zip = await engine();
  const stamp = ticket;
  ticket += 1;
  const input = `/in-${stamp}`;
  const output = `/out-${stamp}`;
  zip.FS.writeFile(input, bytes);
  zip.FS.mkdir(output);
  try {
    const code = zip.callMain(["x", input, `-o${output}`, "-y", "-bd"]) as unknown as number;
    if (code !== 0) throw new FormatError("corrupt comic");
    return collect(zip, output, output);
  } catch (error) {
    if (error instanceof FormatError) throw error;
    throw new FormatError("corrupt comic");
  } finally {
    removeTree(zip, output);
    try {
      zip.FS.unlink(input);
    } catch {
      // The archive file is only a scratch copy.
    }
  }
}

function collect(zip: SevenZipModule, dir: string, root: string): [string, Uint8Array][] {
  const files: [string, Uint8Array][] = [];
  for (const name of zip.FS.readdir(dir)) {
    if (name === "." || name === "..") continue;
    const path = `${dir}/${name}`;
    const stat = zip.FS.stat(path);
    if (zip.FS.isDir(stat.mode)) {
      files.push(...collect(zip, path, root));
      continue;
    }
    const data = zip.FS.readFile(path);
    files.push([path.slice(root.length + 1), new Uint8Array(data)]);
  }
  return files;
}

function removeTree(zip: SevenZipModule, dir: string): void {
  let names: string[] = [];
  try {
    names = zip.FS.readdir(dir);
  } catch {
    return;
  }
  for (const name of names) {
    if (name === "." || name === "..") continue;
    const path = `${dir}/${name}`;
    const stat = zip.FS.stat(path);
    if (zip.FS.isDir(stat.mode)) removeTree(zip, path);
    else zip.FS.unlink(path);
  }
  zip.FS.rmdir(dir);
}
