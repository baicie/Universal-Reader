const path = require("path");
const { getDefaultConfig } = require("expo/metro-config");

const config = getDefaultConfig(__dirname);

config.resolver.assetExts.push("wasm");

const nodeBuiltinsShim = path.resolve(__dirname, "shims/node-builtins.native.js");

// Node builtins used transitively by 7z-wasm / iconv-lite UMD wrappers.
// In RN `process.versions.node` is undefined, so the Node branches are
// dead code at runtime — Metro still needs an importable module to satisfy
// `require(...)` calls at bundle time.
const nodeBuiltins = new Set([
  "fs",
  "crypto",
  "path",
  "url",
  "string_decoder",
  "util",
  "stream",
  "os",
  "events",
  "assert",
  "child_process",
  "cluster",
  "dgram",
  "dns",
  "domain",
  "http",
  "https",
  "net",
  "punycode",
  "querystring",
  "readline",
  "tls",
  "tty",
  "vm",
  "zlib",
  "module",
]);

config.resolver.resolveRequest = (context, moduleName, platform) => {
  if (
    platform === "android" ||
    platform === "ios" ||
    platform === "native"
  ) {
    if (nodeBuiltins.has(moduleName)) {
      return { type: "sourceFile", filePath: nodeBuiltinsShim };
    }
  }
  return context.resolveRequest(context, moduleName, platform);
};

config.resolver.extraNodeModules = {
  ...config.resolver.extraNodeModules,
  buffer: path.dirname(require.resolve("buffer/package.json")),
};

module.exports = config;