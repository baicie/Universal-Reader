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

Run the `Release rehearsal` workflow with a released tag. It downloads that tag's Windows x86_64 ZIP, verifies the archive and `app.exe`, then runs the same rehearsal with `PREVIOUS_RELEASE_TAG` set so the fixture and release identity must agree.

## Limits

This is a persistence and package-identity rehearsal, not an automated GUI upgrade installation. Interactive installation, first launch, and platform signing remain covered by the physical-device and release workflows.

## Commands

```powershell
cd app
flutter test test/release_upgrade_rehearsal_test.dart
```
