#!/usr/bin/env bash
set -euo pipefail

expected_version="${1:?usage: build_ios_signed_release.sh <version> <output.ipa>}"
output="${2:?missing output IPA path}"
export_method="${IOS_EXPORT_METHOD:-development}"

case "$export_method" in
  app-store|ad-hoc|development|enterprise) ;;
  *)
    echo "Unsupported IOS_EXPORT_METHOD: $export_method" >&2
    exit 2
    ;;
esac

env_file="$(mktemp "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/ios-signing-env.XXXXXX")"
signing_xcconfig="ios/Flutter/ReleaseSigning.xcconfig"

cleanup() {
  rm -f "$signing_xcconfig"
  if [[ -n "${IOS_PROVISIONING_PROFILE_UUID:-}" ]]; then
    rm -f "$HOME/Library/MobileDevice/Provisioning Profiles/$IOS_PROVISIONING_PROFILE_UUID.mobileprovision"
  fi
  if [[ -n "${IOS_KEYCHAIN_PATH:-}" && -e "$IOS_KEYCHAIN_PATH" ]]; then
    security delete-keychain "$IOS_KEYCHAIN_PATH" >/dev/null 2>&1 || true
  fi
  if [[ -n "${IOS_SIGNING_TEMP_DIR:-}" ]]; then
    rm -rf "$IOS_SIGNING_TEMP_DIR"
  fi
  rm -f "$env_file"
}
trap cleanup EXIT

bash tool/install_ios_signing.sh --keep --output-env "$env_file"
# shellcheck disable=SC1090
source "$env_file"

export FLUTTER_XCODE_CODE_SIGN_STYLE=Manual
export FLUTTER_XCODE_DEVELOPMENT_TEAM="$IOS_TEAM_ID"
export FLUTTER_XCODE_PROVISIONING_PROFILE="$IOS_PROVISIONING_PROFILE_UUID"
export FLUTTER_XCODE_PROVISIONING_PROFILE_SPECIFIER="$IOS_PROVISIONING_PROFILE_NAME"

{
  printf 'CODE_SIGN_STYLE = Manual\n'
  printf 'DEVELOPMENT_TEAM = %s\n' "$IOS_TEAM_ID"
  printf 'PROVISIONING_PROFILE = %s\n' "$IOS_PROVISIONING_PROFILE_UUID"
  printf 'PROVISIONING_PROFILE_SPECIFIER = %s\n' "$IOS_PROVISIONING_PROFILE_NAME"
} >"$signing_xcconfig"

rm -rf build/ios/ipa
flutter build ipa --release --export-method "$export_method"

ipa_paths="$(find build/ios/ipa -type f -name '*.ipa' -print)"
ipa_count="$(printf '%s\n' "$ipa_paths" | sed '/^$/d' | wc -l | tr -d ' ')"
if [[ "$ipa_count" -ne 1 ]]; then
  echo "Expected exactly one IPA, found $ipa_count." >&2
  exit 1
fi

bash tool/verify_ios_ipa.sh \
  "$ipa_paths" \
  "$expected_version" \
  "$output" \
  "$IOS_TEAM_ID" \
  "$IOS_PROVISIONING_PROFILE_UUID"
