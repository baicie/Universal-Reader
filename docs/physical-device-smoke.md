# Flutter physical device smoke

This page and the `Native smoke` / `Physical device smoke` workflows cover the Flutter project in `app/`, including its Rust CHM / DjVu FFI converters. They do not exercise the Expo phone client in `mobile/`. Use [expo-device-smoke.md](expo-device-smoke.md) for Expo phone validation.

The separate `Native smoke` workflow runs Android emulator and iOS Simulator smoke tests. The current normal CI checks Expo bundles and Rust. Flutter physical-device validation is manual because it requires attached hardware, trusted development signing, or a self-hosted runner.

## Local run

Build the native artifact first:

```powershell
cd rust
./tool/build-mobile-android.ps1
```

```bash
cd rust
bash tool/build-mobile-ios.sh
```

Connect one physical device, confirm it appears in `flutter devices`, then run from `app`:

```bash
flutter pub get
dart run tool/physical_smoke.dart --platform=android
dart run tool/physical_smoke.dart --platform=ios
```

Pass `--device-id=<id>` when more than one physical device of that platform is connected. The command runs the same CHM/DjVu FFI smoke against the device and writes `build/physical-smoke/<platform>-<timestamp>.md`.

## Signed release artifact

Install and launch a signed release artifact after the conversion smoke:

```bash
dart run tool/physical_smoke.dart \
  --platform=android \
  --device-id=<serial> \
  --release-artifact=/path/to/app-release.apk
```

For iOS, pass the signed `Runner.app` or signed `IPA` path on macOS:

```bash
dart run tool/physical_smoke.dart \
  --platform=ios \
  --device-id=<udid> \
  --release-artifact=/path/to/universal-reader-ios-signed.ipa
```

The harness extracts an IPA to a temporary `Payload/Runner.app`. Android installation validates the APK signature. iOS installation validates the app signature through `devicectl`. Both paths then launch the release bundle and record the result in the report.

## Self-hosted workflow

The manual `Physical device smoke` workflow expects runners with these labels:

- Android: `self-hosted`, `linux`, `universal-reader`, `android-device`
- iOS: `self-hosted`, `macOS`, `universal-reader`, `ios-device`

The runner must have Flutter, the device tooling, and the platform signing setup. The workflow builds the native artifact, runs the physical conversion smoke, optionally installs a signed release artifact, and uploads the Markdown report.

The separate hosted `Native smoke` workflow provides Flutter simulator coverage. This physical-device workflow remains optional historical Flutter tooling; it is not an Expo release gate.
