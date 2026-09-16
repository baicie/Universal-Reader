# Release candidate gate

## Frozen version

The current candidate is:

- Tag: `v1.0.0-rc.1`
- Flutter: `1.0.0-rc.1+15`
- Rust workspace and lockfile: `1.0.0-rc.1`

`app/tool/check_release_versions.dart` verifies all sources plus the `CHANGELOG.md` section before the Release workflow publishes anything.

## Release model

- The default candidate is unsigned: Android APKs use the Gradle debug signing key and iOS publishes an unsigned `Runner.app` ZIP.
- Android/iOS signing, `Signing preflight`, and physical-device smoke are optional extensions. They are not required for this release candidate.
- Store distribution and installation on locked-down physical devices remain out of scope until real signing material is provided.

## Automated gates

- Normal CI: formatting, analyze, Flutter tests, coverage, Web, Windows, Rust, Android APK packaging, secretless Android release-signing verification, and iOS symbol checks.
- `Native smoke`: nightly/manual Android emulator and iOS Simulator conversion tests.
- `Release rehearsal`: released persistence upgrade/rollback, Windows launch, Web launch, and Android APK launch.
- Release publication: tag/version verification, structured `release-manifest.json`, `SHA256SUMS`, and independent asset verification.
- Optional signed release: when a complete credential set is present for a platform, the Release workflow can build and verify that platform's signed artifact.

## Manual checklist

- [ ] `Release rehearsal` passes for the candidate tag.
- [ ] Release notes come from the matching `CHANGELOG.md` section.
- [ ] Published `release-manifest.json` and `SHA256SUMS` are attached and match downloaded assets.
- [ ] Release assets clearly remain debug-signed Android APKs and unsigned iOS archives.

Before a tag exists, run the complete release matrix as a dry run:

```powershell
gh workflow run release.yml `
  -f tag=v1.0.0-rc.1 `
  -f source_ref=main `
  -f dry_run=true
```

The dry run builds every platform artifact without requiring signing secrets. Android uses debug signing, iOS publishes an unsigned archive, and the workflow generates release notes, creates the manifest, verifies all hashes, and uploads the complete bundle without creating a GitHub Release.

## Optional signing

After configuring Android secrets, run the manual `Signing preflight` workflow. It decodes the keystore outside the repository, validates the alias and key password, and prints only the public certificate fingerprint.

The local PowerShell helper can validate and upload the four secrets without writing them to disk:

```powershell
cd app
./tool/configure_android_signing.ps1 `
  -Keystore C:\secure\universal-reader-release.jks `
  -Alias universal-reader `
  -ValidateOnly

./tool/configure_android_signing.ps1 `
  -Keystore C:\secure\universal-reader-release.jks `
  -Alias universal-reader
```

Set `ANDROID_KEYSTORE_PASSWORD` and `ANDROID_KEY_PASSWORD` in the shell to avoid interactive prompts. The upload uses stdin, not command-line arguments.

For iOS, configure these GitHub secrets and run the `Signing preflight` workflow:

- `IOS_CERTIFICATE_BASE64`: base64-encoded `.p12`
- `IOS_CERTIFICATE_PASSWORD`
- `IOS_PROVISIONING_PROFILE_BASE64`: base64-encoded `.mobileprovision`
- `IOS_TEAM_ID`

On macOS, the bootstrap helper validates the P12 and provisioning profile before uploading the four secrets through `gh` stdin:

```bash
cd app
export IOS_CERTIFICATE_PASSWORD='...'
./tool/configure_ios_signing.sh \
  --certificate /secure/universal-reader.p12 \
  --profile /secure/universal-reader.mobileprovision \
  --team-id ABCDE12345 \
  --export-method development \
  --validate-only

./tool/configure_ios_signing.sh \
  --certificate /secure/universal-reader.p12 \
  --profile /secure/universal-reader.mobileprovision \
  --team-id ABCDE12345 \
  --export-method development
```

The helper rejects expired profiles, Team ID or bundle mismatches, profile/export-method mismatches, and development/distribution identity mismatches. The macOS preflight imports the certificate into a temporary keychain and applies the same checks. When iOS signing secrets are absent, the Release workflow publishes the unsigned archive instead of failing. Manual workflow dispatches can select `development`, `ad-hoc`, `app-store`, or `enterprise` for `ios_export_method`; tag pushes default to `development`.

## Commands

```powershell
cd app
dart run tool/check_release_versions.dart --tag v1.0.0-rc.1
flutter test test/tool/check_release_versions_test.dart
```

Create and publish the tag only after the manual checklist is ready:

```powershell
git tag -a v1.0.0-rc.1 -m "Universal Reader v1.0.0-rc.1"
git push origin v1.0.0-rc.1
```
