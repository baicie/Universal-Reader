// Native JavaScript engines do not necessarily provide a WebAssembly runtime.
// Check before loading a decoder so a supported file is not reported as damaged.
export function supportsWebAssembly(): boolean {
  return (
    typeof WebAssembly === "object" &&
    typeof WebAssembly.instantiate === "function" &&
    typeof WebAssembly.validate === "function" &&
    typeof WebAssembly.Memory === "function" &&
    typeof WebAssembly.Module === "function" &&
    typeof WebAssembly.Instance === "function"
  );
}
