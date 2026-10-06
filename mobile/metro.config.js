const path = require("path");
const { getDefaultConfig } = require("expo/metro-config");

const config = getDefaultConfig(__dirname);

config.resolver.assetExts.push("wasm");

config.resolver.extraNodeModules = {
  ...config.resolver.extraNodeModules,
  buffer: path.dirname(require.resolve("buffer/package.json")),
};

module.exports = config;
