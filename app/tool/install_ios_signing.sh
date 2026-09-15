#!/usr/bin/env bash
set -euo pipefail

for variable in IOS_CERTIFICATE_BASE64 IOS_CERTIFICATE_PASSWORD IOS_PROVISIONING_PROFILE_BASE64 IOS_TEAM_ID; do
  if [[ -z "${!variable:-}" ]]; then
    echo "Missing required release secret: $variable" >&2
    exit 1
  fi
done

temp="$(mktemp -d)"
keychain="$temp/app-signing.keychain-db"
keychain_password="$(uuidgen)"
certificate="$temp/certificate.p12"
profile="$temp/profile.mobileprovision"
profile_plist="$temp/profile.plist"

cleanup() {
  rm -rf "$temp"
}
trap cleanup EXIT

security create-keychain -p "$keychain_password" "$keychain"
security set-keychain-settings -lut 21600 "$keychain"
security unlock-keychain -p "$keychain_password" "$keychain"

printf '%s' "$IOS_CERTIFICATE_BASE64" | base64 --decode >"$certificate"
test -s "$certificate"
security import "$certificate" \
  -k "$keychain" \
  -P "$IOS_CERTIFICATE_PASSWORD" \
  -T /usr/bin/codesign \
  -T /usr/bin/security
security set-key-partition-list \
  -S apple-tool:,apple: \
  -s \
  -k "$keychain_password" \
  "$keychain" >/dev/null
security list-keychains -d user -s "$keychain"

printf '%s' "$IOS_PROVISIONING_PROFILE_BASE64" | base64 --decode >"$profile"
test -s "$profile"
security cms -D -i "$profile" >"$profile_plist"

profile_uuid="$(plutil -extract UUID raw -o - "$profile_plist")"
profile_team="$(plutil -extract TeamIdentifier.0 raw -o - "$profile_plist")"
application_identifier="$(
  plutil -extract Entitlements.application-identifier raw -o - "$profile_plist"
)"
test "$profile_team" = "$IOS_TEAM_ID"
case "$application_identifier" in
  "$IOS_TEAM_ID.io.universalreader.app") ;;
  *)
    echo "Provisioning profile does not target io.universalreader.app" >&2
    exit 1
    ;;
esac

profile_directory="$HOME/Library/MobileDevice/Provisioning Profiles"
mkdir -p "$profile_directory"
cp "$profile" "$profile_directory/$profile_uuid.mobileprovision"

identity="$(
  security find-identity -v -p codesigning "$keychain" |
    sed -n 's/.*"\(.*\)"/\1/p' |
    head -n 1
)"
test -n "$identity"

echo "iOS signing verified: profile=$profile_uuid team=$profile_team"
echo "Codesigning identity: $identity"
