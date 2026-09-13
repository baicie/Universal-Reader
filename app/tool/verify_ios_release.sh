#!/usr/bin/env bash
set -euo pipefail

app_path="${1:?usage: verify_ios_release.sh <Runner.app> <version> <output.zip>}"
expected_version="${2:?missing expected version}"
output="${3:?missing output zip}"
plist="$app_path/Info.plist"

test -d "$app_path"
test -f "$plist"
plutil -lint "$plist"

bundle_id="$(plutil -extract CFBundleIdentifier raw -o - "$plist")"
version="$(plutil -extract CFBundleShortVersionString raw -o - "$plist")"
executable="$(plutil -extract CFBundleExecutable raw -o - "$plist")"
test "$bundle_id" = 'io.universalreader.app'
test "$version" = "$expected_version"
test -x "$app_path/$executable"

nm -gU "$app_path/$executable" | grep -q '_ur_native_api_version'
nm -gU "$app_path/$executable" | grep -q '_ur_chm_to_epub'

mkdir -p "$(dirname "$output")"
rm -f "$output"
ditto -c -k --sequesterRsrc --keepParent "$app_path" "$output"
unzip -tq "$output"

echo "iOS release artifact verified: $bundle_id $version -> $output"
