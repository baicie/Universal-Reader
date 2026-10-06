// Empty stub for native bundling. The 7z-wasm package's UMD wrapper does
// `if (ENVIRONMENT_IS_NODE) var fs = require("fs")` and `require("crypto")`.
// In RN `process.versions.node` is undefined, so `ENVIRONMENT_IS_NODE` is
// false at runtime and these stubs are never actually read. Metro still tries
// to resolve these requires at bundle time, so the alias has to point
// somewhere importable.
module.exports = {};