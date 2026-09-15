#!/usr/bin/env bash
set -euo pipefail

ipa_path="${1:?usage: verify_ios_ipa.sh <input.ipa> <version> <output.ipa> <team-id> <profile-uuid>}"
expected_version="${2:?missing expected version}"
output="${3:?missing output IPA path}"
expected_team="${4:?missing expected team id}"
expected_profile_uuid="${5:?missing expected profile uuid}"

test -f "$ipa_path"
unzip -tq "$ipa_path"

temp="$(mktemp -d)"
cleanup() {
  rm -rf "$temp"
}
trap cleanup EXIT

unzip -q "$ipa_path" -d "$temp"
app_path="$temp/Payload/Runner.app"
test -d "$app_path"

bash tool/verify_ios_release.sh \
  "$app_path" \
  "$expected_version" \
  "$temp/repacked.zip"

codesign --verify --deep --strict --verbose=2 "$app_path"
signature_info="$(codesign -dv --verbose=4 "$app_path" 2>&1)"
signature_team="$(
  printf '%s\n' "$signature_info" |
    sed -n 's/^TeamIdentifier=//p' |
    head -n 1
)"
test -n "$signature_team"
test "$signature_team" = "$expected_team"

entitlements="$temp/entitlements.plist"
codesign -d --entitlements :- "$app_path" >"$entitlements"
test -s "$entitlements"
plutil -lint "$entitlements"
application_identifier="$(
  plutil -extract application-identifier raw -o - "$entitlements"
)"
test "$application_identifier" = "$expected_team.io.universalreader.app"

embedded_profile="$app_path/embedded.mobileprovision"
test -f "$embedded_profile"
profile_plist="$temp/embedded-profile.plist"
security cms -D -i "$embedded_profile" >"$profile_plist"

profile_uuid="$(plutil -extract UUID raw -o - "$profile_plist")"
profile_team="$(plutil -extract TeamIdentifier.0 raw -o - "$profile_plist")"
profile_application_identifier="$(
  plutil -extract Entitlements.application-identifier raw -o - "$profile_plist"
)"
test "$profile_uuid" = "$expected_profile_uuid"
test "$profile_team" = "$expected_team"
test "$profile_application_identifier" = "$expected_team.io.universalreader.app"

mkdir -p "$(dirname "$output")"
rm -f "$output"
cp "$ipa_path" "$output"
unzip -tq "$output"

echo "iOS signed IPA verified: team=$signature_team profile=$profile_uuid -> $output"
