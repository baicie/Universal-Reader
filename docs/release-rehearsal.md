# Release upgrade rehearsal

The release rehearsal uses the published `v0.0.1-dev.11` tag as the previous-version baseline.

## What it verifies

- The fixture identifies the exact source tag, commit, and app version.
- Released SharedPreferences shapes load without data loss.
- Current code upgrades them to the versioned envelope and dual-writes the legacy payload.
- Removing the versioned payload simulates rollback and still loads the released data.
- A released SQLite v0 schema migrates in place to `PRAGMA user_version = 1`.

The golden payloads live under `app/test/fixtures/release_upgrade/v0.0.1-dev.11/` and are SHA-256 checked by the test.

## Manual workflow

Run the `Release rehearsal` workflow with a released tag and platform. Persistence rehearsal always runs; launch jobs can be selected independently:

- `windows`: downloads the previous Windows x86_64 ZIP and starts `app.exe` for eight seconds.
- `web`: builds the current Web release and renders it in headless Chrome.
- `android`: installs the previous x86_64 APK in an emulator, launches it, and verifies a live app process.
- `all`: runs every launch job.

The workflow also sets `PREVIOUS_RELEASE_TAG`, so the fixture and downloaded release identity must agree.

## Limits

Windows and Web verify process/browser startup, and Android verifies package install plus process launch. These are launch smoke checks rather than full GUI interaction suites. Physical-device and interactive UI checks remain optional extensions and are not part of the release gate.

## Commands

```powershell
cd app
flutter test test/release_upgrade_rehearsal_test.dart
flutter build web --release
bash tool/release_web_smoke.sh build/web release-launch-web.md
```

```powershell
./tool/release_launch_smoke.ps1 `
  -Archive ../universal-reader-v0.0.1-dev.11-windows-x86_64.zip `
  -Report release-launch-windows.md
```
