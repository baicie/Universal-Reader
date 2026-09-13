#!/usr/bin/env bash
set -euo pipefail

for variable in ANDROID_KEYSTORE_BASE64 ANDROID_KEYSTORE_PASSWORD ANDROID_KEY_ALIAS ANDROID_KEY_PASSWORD; do
  if [[ -z "${!variable:-}" ]]; then
    echo "Missing required release secret: $variable" >&2
    exit 1
  fi
done

temp="$(mktemp -d)"
cleanup() {
  rm -rf "$temp"
}
trap cleanup EXIT

keystore="$temp/release.jks"
certificate="$temp/release.der"
printf '%s' "$ANDROID_KEYSTORE_BASE64" | base64 --decode >"$keystore"
test -s "$keystore"

keytool -list \
  -keystore "$keystore" \
  -storepass "$ANDROID_KEYSTORE_PASSWORD" \
  -alias "$ANDROID_KEY_ALIAS" >/dev/null
keytool -exportcert \
  -keystore "$keystore" \
  -storepass "$ANDROID_KEYSTORE_PASSWORD" \
  -alias "$ANDROID_KEY_ALIAS" \
  -keypass "$ANDROID_KEY_PASSWORD" \
  -file "$certificate" >/dev/null

openssl x509 \
  -inform DER \
  -in "$certificate" \
  -noout \
  -fingerprint \
  -sha256
echo "Android release signing secrets verified."
