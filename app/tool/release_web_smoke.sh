#!/usr/bin/env bash
set -euo pipefail

web_root="${1:?usage: release_web_smoke.sh <web-root> [report] [port]}"
report="${2:-release-launch-web.md}"
port="${3:-8765}"
temp="$(mktemp -d)"
server_log="$temp/server.log"
dom="$temp/dom.html"
server_pid=""

cleanup() {
  if [[ -n "$server_pid" ]]; then
    kill "$server_pid" 2>/dev/null || true
    wait "$server_pid" 2>/dev/null || true
  fi
  rm -rf "$temp"
}
trap cleanup EXIT

python3 -m http.server "$port" --directory "$web_root" >"$server_log" 2>&1 &
server_pid=$!

for _ in $(seq 1 30); do
  if curl -fsS "http://127.0.0.1:$port/" >/dev/null; then
    break
  fi
  sleep 1
done
curl -fsS "http://127.0.0.1:$port/" | grep -q 'flutter_bootstrap.js'

chrome_bin="${CHROME_BIN:-}"
if [[ -z "$chrome_bin" ]]; then
  chrome_bin="$(command -v google-chrome || command -v chromium || command -v chromium-browser || true)"
fi
if [[ -z "$chrome_bin" || ! -x "$chrome_bin" ]]; then
  echo "No headless Chromium binary found." >&2
  exit 2
fi

"$chrome_bin" \
  --headless \
  --no-sandbox \
  --disable-gpu \
  --disable-dev-shm-usage \
  --virtual-time-budget=30000 \
  --dump-dom \
  "http://127.0.0.1:$port/" >"$dom"
grep -Eq 'flt-glass-pane|flutter-view|flt-scene-host' "$dom"

{
  echo "# Release launch smoke"
  echo
  echo "- Platform: Web"
  echo "- Web root: $web_root"
  echo "- Result: PASS"
  echo "- Detail: headless browser rendered a Flutter host element"
} >"$report"

echo "Web release launch smoke passed: $web_root"
