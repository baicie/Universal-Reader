#!/usr/bin/env bash
set -euo pipefail

keep_signing_material=false
output_env=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --keep)
      keep_signing_material=true
      shift
      ;;
    --output-env)
      if [[ $# -lt 2 ]]; then
        echo "--output-env requires a path" >&2
        exit 2
      fi
      output_env="$2"
      shift 2
      ;;
    -h|--help)
      echo "usage: install_ios_signing.sh [--keep --output-env PATH]" >&2
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

if [[ "$keep_signing_material" == true && -z "$output_env" ]]; then
  echo "--keep requires --output-env" >&2
  exit 2
fi

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
installed_profile=""
verification_succeeded=false

cleanup() {
  if [[ "$keep_signing_material" == true && "$verification_succeeded" == true ]]; then
    return
  fi
  if [[ -n "$installed_profile" ]]; then
    rm -f "$installed_profile"
  fi
  if [[ -n "${keychain:-}" && -e "$keychain" ]]; then
    security delete-keychain "$keychain" >/dev/null 2>&1 || true
  fi
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
profile_name="$(plutil -extract Name raw -o - "$profile_plist")"
profile_team="$(plutil -extract TeamIdentifier.0 raw -o - "$profile_plist")"
application_identifier="$(
  plutil -extract Entitlements.application-identifier raw -o - "$profile_plist"
)"
test -n "$profile_uuid"
test -n "$profile_name"
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
installed_profile="$profile_directory/$profile_uuid.mobileprovision"
cp "$profile" "$installed_profile"

identity="$(
  security find-identity -v -p codesigning "$keychain" |
    sed -n 's/.*"\(.*\)"/\1/p' |
    head -n 1
)"
test -n "$identity"

if [[ "$keep_signing_material" == true ]]; then
  umask 077
  {
    printf 'export IOS_SIGNING_TEMP_DIR=%q\n' "$temp"
    printf 'export IOS_KEYCHAIN_PATH=%q\n' "$keychain"
    printf 'export IOS_CODESIGN_IDENTITY=%q\n' "$identity"
    printf 'export IOS_PROVISIONING_PROFILE_UUID=%q\n' "$profile_uuid"
    printf 'export IOS_PROVISIONING_PROFILE_NAME=%q\n' "$profile_name"
  } >"$output_env"
fi

verification_succeeded=true

echo "iOS signing verified: profile=$profile_uuid team=$profile_team"
echo "Codesigning identity: $identity"
