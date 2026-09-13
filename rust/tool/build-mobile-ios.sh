#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

rustup target add aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios
cargo build -p universal-reader-mobile --release --target aarch64-apple-ios
cargo build -p universal-reader-mobile --release --target aarch64-apple-ios-sim
cargo build -p universal-reader-mobile --release --target x86_64-apple-ios

mkdir -p target/ios
xcodebuild -create-xcframework \
  -library target/aarch64-apple-ios/release/libuniversal_reader_native.a \
  -headers crates/reader-mobile/include \
  -library target/aarch64-apple-ios-sim/release/libuniversal_reader_native.a \
  -headers crates/reader-mobile/include \
  -library target/x86_64-apple-ios/release/libuniversal_reader_native.a \
  -headers crates/reader-mobile/include \
  -output target/ios/UniversalReaderNative.xcframework
