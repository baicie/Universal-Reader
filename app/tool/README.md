# Development tools

Standalone Dart scripts that help contributors run the same quality checks
locally that CI runs. None of these are required for the app to build or run;
they are wrappers around commands already shipped with Dart and Flutter.

## check_coverage.dart

Reads `coverage/lcov.info` (produced by `flutter test --coverage`) and exits
non-zero when overall line coverage is below the threshold passed on the
command line. Used by CI to enforce the gate.

```bash
flutter test --coverage
dart run tool/check_coverage.dart 70
```

## compute_coverage.dart

Prints a single-line summary of overall line coverage. Useful for a quick
local check without exit-code enforcement.

```bash
dart run tool/compute_coverage.dart
```

## coverage_report.dart

Lists the files with the lowest line coverage so you can spot untested
modules fast. Useful right before adding tests for a new feature.

```bash
dart run tool/coverage_report.dart
```

## diff_l10n_keys.dart

Compares `lib/l10n/app_en.arb` and `lib/l10n/app_zh.arb` to find keys that
exist in only one file. Translation keys missing from one locale show up as
fallback strings in the running app, so this catches gaps before release.

```bash
dart run tool/diff_l10n_keys.dart
```

## Notes

These scripts are excluded from `flutter analyze` because they intentionally
print to stdout (lints forbid `print` in production code) and use plain
string parsing. They have no dependencies beyond the Dart SDK.
