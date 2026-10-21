$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')
$env:CI = 'true'
$env:FLUTTER_SUPPRESS_ANALYTICS = 'true'
flutter pub get --enforce-lockfile
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
dart run build_runner build --delete-conflicting-outputs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
dart format --output=none --set-exit-if-changed lib test
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
flutter analyze --fatal-infos
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
if (-not (Get-Command openssl -ErrorAction SilentlyContinue)) {
    throw 'HTTPS tests need OpenSSL in PATH to generate disposable certificates.'
}
$nativeDir = Join-Path $PWD 'build/windows/x64/runner/Debug'
if (-not (Test-Path (Join-Path $nativeDir 'sqlite3.dll'))) {
    flutter build windows --debug
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
$env:PATH = "$nativeDir;$env:PATH"
flutter test --coverage --reporter expanded
exit $LASTEXITCODE
