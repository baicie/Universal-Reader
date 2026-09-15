#!/usr/bin/env bash
set -euo pipefail

certificate=""
profile=""
team_id=""
repo=""
export_method="${IOS_EXPORT_METHOD:-development}"
validate_only=false

usage() {
  cat >&2 <<'EOF'
usage: configure_ios_signing.sh --certificate PATH --profile PATH --team-id TEAM [options]

Validates Apple release signing material, then uploads the four GitHub Actions
secrets used by Universal Reader. IOS_CERTIFICATE_PASSWORD must be set in the
environment. This helper must run on macOS.

Options:
  --export-method METHOD  development, ad-hoc, app-store, or enterprise
  --repo OWNER/REPO       GitHub repository to configure (defaults to origin)
  --validate-only         Validate without changing GitHub secrets
  -h, --help              Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --certificate)
      certificate="${2:-}"
      shift 2
      ;;
    --profile)
      profile="${2:-}"
      shift 2
      ;;
    --team-id)
      team_id="${2:-}"
      shift 2
      ;;
    --export-method)
      export_method="${2:-}"
      shift 2
      ;;
    --repo)
      repo="${2:-}"
      shift 2
      ;;
    --validate-only)
      validate_only=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 2
      ;;
  esac
done

if [[ "$(uname -s)" != Darwin ]]; then
  echo "iOS signing validation requires macOS." >&2
  exit 1
fi

if [[ -z "$certificate" || -z "$profile" || -z "$team_id" ]]; then
  echo "--certificate, --profile, and --team-id are required." >&2
  usage
  exit 2
fi

if [[ -z "${IOS_CERTIFICATE_PASSWORD:-}" ]]; then
  echo "IOS_CERTIFICATE_PASSWORD must be set in the environment." >&2
  exit 1
fi

case "$export_method" in
  development|ad-hoc|app-store|enterprise) ;;
  *)
    echo "Unsupported export method: $export_method" >&2
    exit 2
    ;;
esac

test -f "$certificate"
test -s "$certificate"
test -f "$profile"
test -s "$profile"

if [[ "$validate_only" == false ]]; then
  command -v gh >/dev/null
  gh auth status >/dev/null
fi

temp="$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/ios-signing-bootstrap.XXXXXX")"
keychain="$temp/bootstrap.keychain-db"
keychain_password="$(uuidgen)"
profile_plist="$temp/profile.plist"

cleanup() {
  if [[ -e "$keychain" ]]; then
    security delete-keychain "$keychain" >/dev/null 2>&1 || true
  fi
  rm -rf "$temp"
}
trap cleanup EXIT

security create-keychain -p "$keychain_password" "$keychain"
security set-keychain-settings -lut 21600 "$keychain"
security unlock-keychain -p "$keychain_password" "$keychain"
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

security cms -D -i "$profile" >"$profile_plist"

profile_uuid="$(plutil -extract UUID raw -o - "$profile_plist")"
profile_name="$(plutil -extract Name raw -o - "$profile_plist")"
profile_team="$(plutil -extract TeamIdentifier.0 raw -o - "$profile_plist")"
application_identifier="$(
  plutil -extract Entitlements.application-identifier raw -o - "$profile_plist"
)"
expiration_date="$(plutil -extract ExpirationDate raw -o - "$profile_plist")"

test -n "$profile_uuid"
test -n "$profile_name"
test "$profile_team" = "$team_id"
test "$application_identifier" = "$team_id.io.universalreader.app"

expiration_epoch="$(date -j -f '%Y-%m-%dT%H:%M:%SZ' "$expiration_date" +%s)"
now_epoch="$(date +%s)"
if (( expiration_epoch <= now_epoch )); then
  echo "Provisioning profile expired at $expiration_date" >&2
  exit 1
fi
if (( expiration_epoch - now_epoch < 30 * 24 * 60 * 60 )); then
  echo "Warning: provisioning profile expires soon at $expiration_date" >&2
fi

provisioned_devices="$(
  plutil -extract ProvisionedDevices json -o - "$profile_plist" 2>/dev/null || true
)"
provisions_all_devices="$(
  plutil -extract ProvisionsAllDevices raw -o - "$profile_plist" 2>/dev/null || true
)"

case "$export_method" in
  development|ad-hoc)
    if [[ -z "$provisioned_devices" || "$provisioned_devices" == "[]" ]]; then
      echo "Provisioning profile has no registered devices for $export_method" >&2
      exit 1
    fi
    ;;
  app-store)
    if [[ -n "$provisioned_devices" && "$provisioned_devices" != "[]" ]]; then
      echo "App Store provisioning profile must not contain registered devices" >&2
      exit 1
    fi
    if [[ "$provisions_all_devices" == true ]]; then
      echo "App Store provisioning profile cannot provision all devices" >&2
      exit 1
    fi
    ;;
  enterprise)
    if [[ "$provisions_all_devices" != true ]]; then
      echo "Enterprise provisioning profile must provision all devices" >&2
      exit 1
    fi
    ;;
esac

identity_list="$(
  security find-identity -v -p codesigning "$keychain" |
    sed -n 's/.*"\(.*\)"/\1/p'
)"
test -n "$identity_list"

case "$export_method" in
  development)
    identity="$(
      grep -E '^(Apple Development|iPhone Developer):' <<<"$identity_list" |
        head -n 1 || true
    )"
    ;;
  ad-hoc|app-store|enterprise)
    identity="$(
      grep -E '^(Apple Distribution|iPhone Distribution):' <<<"$identity_list" |
        head -n 1 || true
    )"
    ;;
esac

if [[ -z "$identity" ]]; then
  echo "No codesigning identity matches export method: $export_method" >&2
  exit 1
fi

echo "Validated iOS signing: profile=$profile_uuid team=$profile_team"
echo "Export method: $export_method"
echo "Codesigning identity: $identity"

if [[ "$validate_only" == true ]]; then
  echo "Validation complete; GitHub secrets were not changed."
  exit 0
fi

set_secret() {
  if [[ -n "$repo" ]]; then
    gh secret set "$1" --repo "$repo"
  else
    gh secret set "$1"
  fi
}

base64 <"$certificate" | tr -d '\n' | set_secret IOS_CERTIFICATE_BASE64
printf '%s' "$IOS_CERTIFICATE_PASSWORD" | set_secret IOS_CERTIFICATE_PASSWORD
base64 <"$profile" | tr -d '\n' | set_secret IOS_PROVISIONING_PROFILE_BASE64
printf '%s' "$team_id" | set_secret IOS_TEAM_ID

echo "iOS release signing secrets configured."
