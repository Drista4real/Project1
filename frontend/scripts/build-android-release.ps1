param(
    [Parameter(Mandatory = $true)]
    [string]$ApiBaseUrl,
    [string]$FlutterCommand = 'flutter'
)

$ErrorActionPreference = 'Stop'
$frontendRoot = Split-Path $PSScriptRoot -Parent
$apiUri = $null
if (-not [Uri]::TryCreate($ApiBaseUrl, [UriKind]::Absolute, [ref]$apiUri) -or
    $apiUri.Scheme -ne 'https' -or $apiUri.IsLoopback -or
    $apiUri.AbsolutePath -ne '/' -or $apiUri.Query -or $apiUri.Fragment -or $apiUri.UserInfo) {
    throw 'API_BASE_URL phải là URL gốc HTTPS của backend, không có /api/v1.'
}
if (-not (Test-Path -LiteralPath (Join-Path $frontendRoot 'android/key.properties'))) {
    throw 'Chạy scripts/initialize-android-signing.ps1 trước khi build APK phát hành.'
}

Push-Location $frontendRoot
try {
    & $FlutterCommand build apk --release "--dart-define=API_BASE_URL=$($ApiBaseUrl.TrimEnd('/'))"
    if ($LASTEXITCODE -ne 0) { throw 'Build APK thất bại.' }
    $apkPath = Join-Path $frontendRoot 'build/app/outputs/flutter-apk/app-release.apk'
    $releaseDir = Join-Path $frontendRoot 'build/releases'
    New-Item -ItemType Directory -Path $releaseDir -Force | Out-Null
    $versionLine = (Select-String -Path 'pubspec.yaml' -Pattern '^version:\s*(\S+)').Matches[0].Groups[1].Value
    $releasePath = Join-Path $releaseDir "kakeibo-$versionLine.apk"
    Copy-Item -LiteralPath $apkPath -Destination $releasePath -Force
    $hash = (Get-FileHash -LiteralPath $releasePath -Algorithm SHA256).Hash
    "$hash  $(Split-Path $releasePath -Leaf)" | Set-Content -LiteralPath "$releasePath.sha256" -Encoding ascii
    @{ version = $versionLine; apiBaseUrl = $ApiBaseUrl.TrimEnd('/'); sha256 = $hash } |
        ConvertTo-Json | Set-Content -LiteralPath "$releasePath.json" -Encoding utf8
    Write-Output "APK: $releasePath"
} finally {
    Pop-Location
}
