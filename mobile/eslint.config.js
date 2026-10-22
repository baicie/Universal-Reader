const { defineConfig } = require("eslint/config");
const expoConfig = require("eslint-config-expo/flat");

module.exports = defineConfig([
  { ignores: ["dist/**", "web-build/**", ".expo/**", "log-extract/**"] },
  expoConfig,
]);
