[CmdletBinding()]
param(
    [string[]]$ArchivePath = @(),
    [switch]$SelfTest
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

# This is a known-pattern check, not proof that an artifact has no secrets.
# Inspect decompressed bytes without extracting files or printing matches.
$contentPatterns = @{
    GoogleApiKey = 'AIza[A-Za-z0-9_-]{35}'
    GoogleAccessToken = 'ya29\.[A-Za-z0-9_-]{40,2048}'
    PrivateKey = '-----BEGIN (?:(?:RSA|EC|DSA|OPENSSH|ENCRYPTED) )?PRIVATE KEY-----\s*[A-Za-z0-9+/=\s]{64,8192}-----END (?:(?:RSA|EC|DSA|OPENSSH|ENCRYPTED) )?PRIVATE KEY-----'
    TestProbe = 'non-secret-native-smoke-value|fixture-secret-never-export'
}
$prohibitedName = '(?i)(?:^|/)(?:test|tests|integration_test|fixtures|__pycache__)(?:/|$)|(?:^|/)(?:\.env(?:\..*)?|service_account[^/]*\.json|credentials[^/]*\.json|key\.properties|[^/]*signing[^/]*password[^/]*\.clixml)$|\.(?:py|pyc|pyo|p12|jks|keystore|key|pem)$'

function Read-ContentFindings {
    param([System.IO.Stream]$Stream, [long]$MaxBytes = 536870912)
    $encoding = [System.Text.Encoding]::GetEncoding(28591)
    $buffer = New-Object byte[] 65536
    $tail = ''
    $count = 0L
    $found = [System.Collections.Generic.HashSet[string]]::new()
    while (($read = $Stream.Read($buffer, 0, $buffer.Length)) -gt 0) {
        $count += $read
        if ($count -gt $MaxBytes) { throw 'Release entry exceeds the inspection size limit.' }
        # ASCII secrets can occur in UTF-8 or UTF-16 AOT/native strings.
        # Normalize JSON-escaped newlines for complete PEM payload detection.
        $window = ($tail + $encoding.GetString($buffer, 0, $read)).Replace([string][char]0, '')
        $window = $window.Replace('\r\n', "`n").Replace('\n', "`n").Replace('\r', "`r")
        foreach ($entry in $contentPatterns.GetEnumerator()) {
            if ([regex]::IsMatch($window, $entry.Value)) { [void]$found.Add($entry.Key) }
        }
        # Covers every bounded pattern even when a value straddles read blocks.
        $tail = $window.Substring([Math]::Max(0, $window.Length - 16384))
    }
    [pscustomobject]@{ BytesRead = $count; Matches = @($found) }
}

if ($SelfTest) {
    $fakeKey = 'AIza' + ('Z' * 35)
    $fakePem = "-----BEGIN PRIVATE KEY-----`n" + ('A' * 128) + "`n-----END PRIVATE KEY-----"
    $fixtures = @(
        @{ Text = ('x' * 65530) + $fakeKey; Encoding = [Text.Encoding]::UTF8; Expected = 'GoogleApiKey' },
        @{ Text = ('x' * 32760) + $fakeKey; Encoding = [Text.Encoding]::Unicode; Expected = 'GoogleApiKey' },
        @{ Text = ('x' * 65530) + $fakePem.Replace("`n", '\n'); Encoding = [Text.Encoding]::UTF8; Expected = 'PrivateKey' },
        @{ Text = $fakePem; Encoding = [Text.Encoding]::BigEndianUnicode; Expected = 'PrivateKey' },
        @{ Text = 'ya29.' + ('z' * 80); Encoding = [Text.Encoding]::UTF8; Expected = 'GoogleAccessToken' },
        @{ Text = 'non-secret-native-smoke-value'; Encoding = [Text.Encoding]::UTF8; Expected = 'TestProbe' },
        @{ Text = '-----BEGIN PRIVATE KEY----- plus a regex AIza[A-Za-z0-9_-]{35}'; Encoding = [Text.Encoding]::UTF8; Expected = $null }
    )
    foreach ($fixture in $fixtures) {
        $stream = [IO.MemoryStream]::new($fixture.Encoding.GetBytes($fixture.Text), $false)
        try { $result = Read-ContentFindings -Stream $stream } finally { $stream.Dispose() }
        if ($null -eq $fixture.Expected) {
            if ($result.Matches.Count -ne 0) { throw 'Verifier self-test falsely flagged a marker without a credential value.' }
        } elseif ($result.Matches -notcontains $fixture.Expected) {
            throw 'Verifier self-test missed a synthetic credential.'
        }
    }
    foreach ($name in @('assets/fixtures/input.json', '.env', 'data/service_account.json', 'android-release.p12', 'cache/test/demo.txt', 'runner.py')) {
        if ($name -notmatch $prohibitedName) { throw 'Verifier self-test missed a prohibited filename.' }
    }
    if ('data/flutter_assets/assets/prompts/audit_v1.txt' -match $prohibitedName) { throw 'Verifier self-test rejected the production prompt.' }
    $stream = [IO.MemoryStream]::new([byte[]](1, 2, 3), $false)
    $bounded = $false
    try { $null = Read-ContentFindings -Stream $stream -MaxBytes 2 } catch { $bounded = $true } finally { $stream.Dispose() }
    if (-not $bounded) { throw 'Verifier self-test failed to enforce actual byte limits.' }
    Write-Output 'Release verifier self-tests passed (synthetic values only).'
}

if ($ArchivePath.Count -eq 0) {
    if ($SelfTest) { return }
    throw 'Supply one or more release APK/ZIP paths, or -SelfTest.'
}

foreach ($path in $ArchivePath) {
    $resolved = (Resolve-Path -LiteralPath $path).Path
    if ([IO.Path]::GetExtension($resolved) -notin @('.apk', '.zip')) { throw 'Only APK/ZIP release archives are supported.' }
    $archive = [IO.Compression.ZipFile]::OpenRead($resolved)
    $entries = 0
    $totalBytes = 0L
    $issues = [System.Collections.Generic.List[string]]::new()
    try {
        foreach ($entry in $archive.Entries) {
            $entries++
            $name = $entry.FullName.Replace('\', '/')
            if ($name -match $prohibitedName) { $issues.Add("Entry $entries has a prohibited filename.") }
            if ($entry.Length -gt 536870912) { throw 'Release entry exceeds the inspection size limit.' }
            $stream = $entry.Open()
            try { $result = Read-ContentFindings -Stream $stream } finally { $stream.Dispose() }
            $totalBytes += $result.BytesRead
            if ($totalBytes -gt 2147483648) { throw 'Release archive exceeds the inspection size limit.' }
            foreach ($finding in $result.Matches) { $issues.Add("Entry $entries contains a potential $finding value.") }
        }
    } finally { $archive.Dispose() }
    if ($entries -eq 0) { throw 'Release archive is empty.' }
    if ($issues.Count -gt 0) {
        # Entry numbers and detector names only: never print the matching value.
        throw ("Release inspection failed: " + ($issues -join ' '))
    }
    [pscustomobject]@{
        Archive = [IO.Path]::GetFileName($resolved)
        Entries = $entries
        InspectedBytes = $totalBytes
        Findings = 0
        Sha256 = (Get-FileHash -LiteralPath $resolved -Algorithm SHA256).Hash
    }
}
