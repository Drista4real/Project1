param([string]$KeytoolCommand = 'keytool')

$ErrorActionPreference = 'Stop'
$androidRoot = Join-Path (Split-Path $PSScriptRoot -Parent) 'android'
$propertiesPath = Join-Path $androidRoot 'key.properties'
$keystorePath = Join-Path $androidRoot 'kakeibo-release.jks'
if ((Test-Path -LiteralPath $propertiesPath) -or (Test-Path -LiteralPath $keystorePath)) {
    throw 'Đã có cấu hình ký hoặc keystore. Giữ nguyên khóa hiện có để cập nhật app.'
}

$randomBytes = New-Object byte[] 32
$rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
try { $rng.GetBytes($randomBytes) } finally { $rng.Dispose() }
$signingPassword = [Convert]::ToBase64String($randomBytes)
$env:KAKEIBO_SIGNING_PASSWORD = $signingPassword
try {
    & $KeytoolCommand -genkeypair -v -keystore $keystorePath -storetype JKS `
        -keyalg RSA -keysize 2048 -validity 10000 -alias kakeibo `
        -storepass:env KAKEIBO_SIGNING_PASSWORD -keypass:env KAKEIBO_SIGNING_PASSWORD `
        -dname 'CN=Kakeibo Zen, OU=Mobile, O=Kakeibo Zen, C=VN'
    if ($LASTEXITCODE -ne 0) { throw 'Không tạo được keystore.' }
    @(
        "storePassword=$signingPassword"
        "keyPassword=$signingPassword"
        'keyAlias=kakeibo'
        'storeFile=kakeibo-release.jks'
    ) | Set-Content -LiteralPath $propertiesPath -Encoding ascii
    Write-Output 'Đã tạo khóa ký riêng. Sao lưu android/key.properties và android/kakeibo-release.jks ở nơi riêng tư.'
} finally {
    Remove-Item Env:KAKEIBO_SIGNING_PASSWORD -ErrorAction SilentlyContinue
    $signingPassword = $null
}
