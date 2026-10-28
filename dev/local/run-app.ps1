param([string]$Device = 'chrome')
$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$webDevices = @('chrome', 'edge', 'web-server')
$desktopDevices = @('windows', 'linux', 'macos')
$targetConfig = if ($Device -in $webDevices -or $Device -in $desktopDevices) { 'web' } else { 'android' }
$configPath = Join-Path $PSScriptRoot "runtime/flutter-$targetConfig.json"
if (-not (Test-Path -LiteralPath $configPath)) {
    throw 'Run python dev/local/demo.py start first.'
}
Push-Location (Join-Path $projectRoot 'frontend')
try {
    if ($Device -in $webDevices) {
        flutter run -d $Device --web-port=5173 "--dart-define-from-file=$configPath"
    } else {
        flutter run -d $Device "--dart-define-from-file=$configPath"
    }
    if ($LASTEXITCODE -ne 0) { throw 'Flutter run failed.' }
} finally { Pop-Location }
