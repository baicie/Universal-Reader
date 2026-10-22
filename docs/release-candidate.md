# Release checklist

## Current release path

The active phone client is the Expo / React Native project in `mobile/`. The current [Release workflow](../.github/workflows/release.yml) builds an Android APK through EAS using `mobile/eas.json`'s `preview` profile and attaches it to a GitHub Release. iOS and Flutter desktop artifacts are not part of this workflow.

Published versions remain available independently:

- [v0.1.0-test](https://github.com/baicie/Universal-Reader/releases/tag/v0.1.0-test), published 2026-10-06: Expo Android test APK.
- [v1.0.0-rc.1](https://github.com/baicie/Universal-Reader/releases/tag/v1.0.0-rc.1), published 2026-09-16: historical Flutter multi-platform RC, including desktop and Web/server packages.

The latest observed pre-fix Release failure was missing `EXPO_TOKEN`. The corrected workflow checks token presence and Expo authentication before starting an EAS build. A published test APK does not establish that the current automation is working; the workflow must complete for the intended source revision and tag.

## Automated checks

The normal [CI workflow](../.github/workflows/ci.yml) covers:

- Mobile: `npm ci`, TypeScript, lint with zero warnings, Node tests, and Android / iOS Metro bundle export.
- Rust: `cargo fmt --all -- --check` and `cargo test --all`.

Metro export verifies native bundles and asset resolution. It does not compile or install Android / iOS applications and does not prove that WASM decoders run inside the phone runtime.

The retained `Native smoke`, `Physical device smoke`, `Release rehearsal`, and `Signing preflight` workflows target the Flutter project in `app/`. Their conversion, signing, launch, persistence, and rollback results apply to Flutter artifacts only. The former Flutter tag/version, manifest, and checksum gates are not the active Expo release workflow.

## EAS prerequisites

- `mobile/app.json` must identify the intended Expo owner, project, Android package, and application version.
- The EAS project must be accessible to the Expo account used by CI, with Android build credentials configured.
- A GitHub Actions secret named `EXPO_TOKEN` must provide an authorized Expo access token. Keep the value in the secret store; do not commit it or print it in logs.
- The intended tag must resolve to the source revision being released. Manual dispatch must use that source, rather than accidentally packaging another checkout.

The `preview` profile creates an internally distributed APK. The `release` profile creates an Android App Bundle, but is not used by the current GitHub release path. `Signing preflight` checks the separate Flutter signing setup; it does not configure EAS credentials. No iOS EAS release is currently automated.

## Run the workflow

Tag pushes matching `v*` invoke the workflow. To rebuild an existing tag with the workflow on `main`, supply the tag explicitly:

```powershell
gh workflow run release.yml --ref main -f tag=v0.1.0-test
```

This command publishes an actual GitHub Release if the build succeeds; it is not a dry run. Use the intended existing version tag. The workflow reads its release tooling from the workflow revision and checks out the application source at that tag, then verifies that the checked-out commit matches the tag. After dependency installation, the source checkout must still be clean, including untracked files, so EAS cannot silently include changes absent from the tag.

The workflow pins EAS CLI, authenticates before building, and runs `eas build --platform android --profile preview --non-interactive --freeze-credentials --wait --json`. A missing credential must be configured in EAS before this run; CI does not create or replace signing credentials. The completed build must match the Android platform, APK profile, EAS project, and tagged commit. The downloaded file must be an intact APK containing `AndroidManifest.xml`. It generates `app.apk.sha256`, then a separate publication job verifies that checksum before uploading both files.

## Before publishing a phone build

- [ ] Record the source commit, release tag, Expo application version, and Android version code.
- [ ] Normal CI passes for the source revision.
- [ ] EAS produces a finished Android build; the artifact is downloaded successfully and confirmed to be an APK.
- [ ] Complete [Expo device smoke](expo-device-smoke.md) on the actual APK. Record the device, OS, commit, APK SHA-256, and outcome. Leave unavailable or untested cases explicit.
- [ ] Release notes name the tested formats and known limitations. Expo CHM now uses the shared TypeScript parser, but native-entry unit tests do not establish device validation. DjVu and RAR / 7z comics report unsupported when WebAssembly is absent; their successful decoding still requires a suitable runtime and device validation.
- [ ] The published APK matches the EAS build and tag. Retain its SHA-256 with the release record.

Do not check an item merely because a corresponding instruction exists. Physical-device verification is pending until a device report records actual results.

## Historical Flutter RC

`v1.0.0-rc.1` froze Flutter `1.0.0-rc.1+15` and Rust `1.0.0-rc.1`. Its published assets and associated manifests, checksums, and rehearsal reports describe that release, not the current Expo build.

The Flutter tooling remains available for manual maintenance:

```powershell
cd app
dart run tool/check_release_versions.dart --tag v1.0.0-rc.1
flutter test test/tool/check_release_versions_test.dart
```

Flutter signing helpers remain in `app/tool/`; physical-device FFI validation is described in [physical-device-smoke.md](physical-device-smoke.md). A future Flutter release needs a separately reviewed build and publication path; pushing a new `v*` tag currently invokes the Expo Android workflow.
