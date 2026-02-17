$ErrorActionPreference = "Stop"

# Extract version from pubspec.yaml
$pubspec = Get-Content pubspec.yaml -Raw
$versionMatch = [regex]::Match($pubspec, 'flutter_vodozemac:\s+\^?([\d\.]+)')
if ($versionMatch.Success) {
      $version = $versionMatch.Groups[1].Value
}
else {
      $version = "0.5.0" # Fallback
}

Write-Host "Setting up web environment for flutter_vodozemac version: $version..."

# Clone the repository
if (Test-Path .vodozemac) { Remove-Item -Path .vodozemac -Recurse -Force }
git clone https://github.com/famedly/dart-vodozemac.git -b $version .vodozemac

# Build WASM
Push-Location .vodozemac
Write-Host "Checking for Rust dependencies..."

if (!(Get-Command cargo -ErrorAction SilentlyContinue)) {
      Write-Error "Cargo (Rust) not found. Please install Rust from https://rustup.rs/"
      exit 1
}

Write-Host "Ensuring Rust web target is installed..."
rustup target add wasm32-unknown-unknown

Write-Host "Ensuring flutter_rust_bridge_codegen is installed..."
if (!(Get-Command flutter_rust_bridge_codegen -ErrorAction SilentlyContinue)) {
      cargo install flutter_rust_bridge_codegen
}

Write-Host "Ensuring wasm-pack is installed..."
if (!(Get-Command wasm-pack -ErrorAction SilentlyContinue)) {
      cargo install wasm-pack
}

Write-Host "Building web bindings..."
$rustPath = (Get-Item rust).FullName
# Try to run the build, capturing output
try {
      flutter_rust_bridge_codegen build-web --dart-root dart --rust-root $rustPath --release
}
catch {
      Write-Host "Build stage failed. Please check the logs above." -ForegroundColor Red
      Pop-Location
      exit 1
}

# --- DEBUG ENHANCEMENT START ---
Write-Host "Build finished. Searching for output files..." -ForegroundColor Cyan
$searchPath = Join-Path (Get-Location).Path "dart"
$foundFiles = Get-ChildItem -Path $searchPath -Filter "vodozemac_bindings_dart*" -Recurse -ErrorAction SilentlyContinue

if ($foundFiles) {
      Write-Host "Found output files at:" -ForegroundColor Green
      $foundFiles | ForEach-Object { Write-Host " - $($_.FullName)" }
      $sourcePkgPath = $foundFiles[0].DirectoryName
}
else {
      Write-Host "Could not find 'vodozemac_bindings_dart*' files in $searchPath. Listing all files in 'dart' directory for debugging:" -ForegroundColor Yellow
      Get-ChildItem -Path $searchPath -Recurse | Select-Object FullName
      Pop-Location
      exit 1
}
# --- DEBUG ENHANCEMENT END ---
Pop-Location

# Move files to assets
Write-Host "Updating assets..."
if (!(Test-Path assets/vodozemac)) { New-Item -ItemType Directory -Path assets/vodozemac }
Remove-Item -Path ./assets/vodozemac/vodozemac_bindings_dart* -Force -ErrorAction SilentlyContinue

Move-Item -Path "$sourcePkgPath/vodozemac_bindings_dart*" -Destination ./assets/vodozemac/ -Force

# Cleanup (Disabled temporarily for debugging if you want, but kept for now)
Write-Host "Cleaning up temporary build folder..."
Remove-Item -Path .vodozemac -Recurse -Force

# Finalize
Write-Host "Finalizing flutter project..."
flutter pub get
Write-Host "Compiling web worker..."
dart compile js ./web/native_executor.dart -o ./web/native_executor.js -m

Write-Host "------------------------------------------------"
Write-Host "Success! The web environment is ready." -ForegroundColor Green
Write-Host "You can now run: flutter run -d chrome"
Write-Host "------------------------------------------------"
