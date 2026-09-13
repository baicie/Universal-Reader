param(
  [string[]]$Abi = @("arm64-v8a", "armeabi-v7a", "x86_64")
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$arguments = @()
foreach ($item in $Abi) {
  $arguments += @("-t", $item)
}
$arguments += @(
  "-o", "target/android/jniLibs",
  "build",
  "-p", "universal-reader-mobile",
  "--release"
)

Push-Location $root
try {
  cargo ndk @arguments
} finally {
  Pop-Location
}
