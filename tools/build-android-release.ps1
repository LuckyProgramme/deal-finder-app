[CmdletBinding()]
param(
    [switch]$CreateSigningKey,
    [string]$FlutterPath = 'flutter',
    [string]$KeytoolPath = 'C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe',
    [string]$SigningDirectory = (Join-Path ([Environment]::GetFolderPath('UserProfile')) '.local\share\deal-finder-signing')
)

$ErrorActionPreference = 'Stop'
if ($env:OS -ne 'Windows_NT') { throw 'This helper uses Windows account-protected storage. Use signing environment variables on other hosts.' }
$repoDirectory = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$appDirectory = Join-Path $repoDirectory 'deal_finder_app'
$signingRoot = [System.IO.Path]::GetFullPath($SigningDirectory)
if ($signingRoot.StartsWith($repoDirectory + '\', [StringComparison]::OrdinalIgnoreCase) -or $signingRoot -eq $repoDirectory) {
    throw 'Signing material must be stored outside the repository.'
}
$keyFile = Join-Path $signingRoot 'android-release.p12'
$passwordFile = Join-Path $signingRoot 'android-signing-password.clixml'
$keyAlias = 'deal-finder-release'

if (-not (Test-Path -LiteralPath $keyFile)) {
    if (-not $CreateSigningKey) { throw 'No signing key exists. Use -CreateSigningKey only when creating a new release identity.' }
    New-Item -ItemType Directory -Path $signingRoot -Force | Out-Null
    if (-not (Test-Path -LiteralPath $passwordFile)) {
        $randomBytes = New-Object byte[] 32
        $generator = [Security.Cryptography.RandomNumberGenerator]::Create()
        try { $generator.GetBytes($randomBytes) } finally { $generator.Dispose() }
        $newPassword = ConvertTo-SecureString ([Convert]::ToBase64String($randomBytes)) -AsPlainText -Force
        # On Windows Export-Clixml encrypts SecureString with the current user's DPAPI key.
        $newPassword | Export-Clixml -LiteralPath $passwordFile -NoClobber
        [Array]::Clear($randomBytes, 0, $randomBytes.Length)
        $newPassword.Dispose()
    }
}
if (-not (Test-Path -LiteralPath $passwordFile)) { throw 'The protected signing password is missing. Restore it; do not generate a replacement key.' }
$protectedPassword = Import-Clixml -LiteralPath $passwordFile
if ($protectedPassword -isnot [Security.SecureString]) { throw 'Invalid protected signing password file.' }
$signingPassword = [PSCredential]::new('signing', $protectedPassword).GetNetworkCredential().Password
$variables = @{
    DEAL_FINDER_STORE_FILE = $keyFile
    DEAL_FINDER_STORE_PASSWORD = $signingPassword
    DEAL_FINDER_KEY_ALIAS = $keyAlias
    DEAL_FINDER_KEY_PASSWORD = $signingPassword
}
$previous = @{}
foreach ($name in $variables.Keys) {
    $previous[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
    [Environment]::SetEnvironmentVariable($name, $variables[$name], 'Process')
}
try {
    if (-not (Test-Path -LiteralPath $keyFile)) {
        & $KeytoolPath -genkeypair -keystore $keyFile -storetype PKCS12 -alias $keyAlias -keyalg RSA -keysize 4096 -validity 10000 -dname 'CN=Deal Finder Personal Release' -storepass:env DEAL_FINDER_STORE_PASSWORD -keypass:env DEAL_FINDER_KEY_PASSWORD -noprompt
        if ($LASTEXITCODE -ne 0) { throw 'Signing key generation failed. Existing files were retained for recovery.' }
        Write-Host "Created private signing key: $keyFile"
    }
    & $KeytoolPath -list -keystore $keyFile -storetype PKCS12 -alias $keyAlias -storepass:env DEAL_FINDER_STORE_PASSWORD
    if ($LASTEXITCODE -ne 0) { throw 'Cannot open the existing signing key. It has not been replaced.' }
    Push-Location $appDirectory
    try {
        # Pub preparation also regenerates the release-only plugin registrant.
        # --no-pub can retain integration_test registration from a debug run.
        & $FlutterPath build apk --release
        if ($LASTEXITCODE -ne 0) { throw 'Android release build failed.' }
    } finally { Pop-Location }
} finally {
    foreach ($name in $variables.Keys) {
        [Environment]::SetEnvironmentVariable($name, $previous[$name], 'Process')
    }
    $variables.Clear()
    $signingPassword = $null
    $protectedPassword.Dispose()
}

Write-Host 'Back up the keystore and signing password securely. DPAPI password storage can only be opened by this Windows account on this computer.'
