# Release candidate gate

## Frozen version

The current candidate is:

- Tag: `v1.0.0-rc.1`
- Flutter: `1.0.0-rc.1+15`
- Rust workspace and lockfile: `1.0.0-rc.1`

`app/tool/check_release_versions.dart` verifies all sources plus the `CHANGELOG.md` section before the Release workflow publishes anything.

## Automated gates

- Normal CI: formatting, analyze, Flutter tests, coverage, Web, Windows, Rust, Android APK packaging, and iOS symbol checks.
- `Native smoke`: nightly/manual Android emulator and iOS Simulator conversion tests.
- `Release rehearsal`: released persistence upgrade/rollback, Windows launch, Web launch, and Android APK launch.
- `Physical device smoke`: manually dispatched real-device conversion and optional signed package install.
- Release publication: tag/version verification and `SHA256SUMS` generation.

## Manual checklist

- [ ] Android release signing secrets are configured and verified.
- [ ] iOS signing and provisioning are verified on a physical device.
- [ ] `Release rehearsal` passes for the candidate tag.
- [ ] `Physical device smoke` passes on Android and iOS.
- [ ] Release notes come from the matching `CHANGELOG.md` section.
- [ ] Published `SHA256SUMS` are attached and match downloaded assets.

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
