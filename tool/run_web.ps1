param([int]$Port = 52341)
$ErrorActionPreference = 'Stop'
Push-Location (Split-Path -Parent $PSScriptRoot)
try {
  $flutterCommand = if (Get-Command flutter -ErrorAction SilentlyContinue) { 'flutter' } else { 'C:\Src\flutter\bin\flutter.bat' }
  $dartCommand = if (Get-Command dart -ErrorAction SilentlyContinue) { 'dart' } else { 'C:\Src\flutter\bin\dart.bat' }
  & $flutterCommand build web --release --no-wasm-dry-run --dart-define=LOCAL_DEVICE_LOCATION=true --dart-define=PHOTON_SEARCH_URL=/__ride/geocoder/api/
  if ($LASTEXITCODE -ne 0) { throw 'Web build failed' }
  & $dartCommand run tool/preview_server.dart $Port
} finally { Pop-Location }
