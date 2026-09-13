#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

rustup target add aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios
cargo build -p universal-reader-mobile --release --target aarch64-apple-ios
cargo build -p universal-reader-mobile --release --target aarch64-apple-ios-sim
cargo build -p universal-reader-mobile --release --target x86_64-apple-ios

rm -rf target/ios
mkdir -p target/ios/simulator
lipo -create \
  target/aarch64-apple-ios-sim/release/libuniversal_reader_native.a \
  target/x86_64-apple-ios/release/libuniversal_reader_native.a \
  -output target/ios/simulator/libuniversal_reader_native.a

xcodebuild -create-xcframework \
  -library target/aarch64-apple-ios/release/libuniversal_reader_native.a \
  -headers crates/reader-mobile/include \
  -library target/ios/simulator/libuniversal_reader_native.a \
  -headers crates/reader-mobile/include \
  -output target/ios/UniversalReaderNative.xcframework
