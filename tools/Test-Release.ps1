#requires -Version 5.1
# No installs, cache resets, key writes, or server changes. Remote mode downloads
# into a temporary folder; run it separately for a pinned commit and for main.
[CmdletBinding()]
param(
    [string]$RepoRoot = (Split-Path $PSScriptRoot -Parent),
    [string]$ManifestDirectory,
    [ValidateRange(1,2147483647)][int]$ExpectedVersion = 33,
    [ValidateRange(0,2147483647)][int]$MinimumVersion = 0,
    [switch]$Remote,
    [string]$Ref = 'main'
)
. (Join-Path $PSScriptRoot 'ReleaseTools.ps1')
$temporary = $null
try {
    if ($Remote) {
        if ($Ref -ne 'main' -and $Ref -notmatch '^[0-9a-f]{40}$') { throw 'Ref must be main or a full commit SHA.' }
        $temporary = Join-Path ([IO.Path]::GetTempPath()) ('elly-release-check-' + [Guid]::NewGuid().ToString('N'))
        [void][IO.Directory]::CreateDirectory($temporary)
        $RepoRoot = $temporary
        $ManifestDirectory = $temporary
        $base = 'https://raw.githubusercontent.com/spoemeo-code/elly-korean-patch/' + $Ref
        try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch { }
        $wc = New-Object Net.WebClient
        try {
            $wc.Headers.Add('User-Agent','elly-release-audit')
            $wc.Headers.Add('Cache-Control','no-cache')
            $nonce = [Guid]::NewGuid().ToString('N')
            foreach ($name in @('manifest.json','manifest.sig')) {
                $wc.DownloadFile(($base + '/' + $name + '?v=' + $nonce), (Join-Path $temporary $name))
            }
        } finally { $wc.Dispose() }
    }
    if (-not $ManifestDirectory) { $ManifestDirectory = $RepoRoot }
    $manifestPath = Join-Path $ManifestDirectory 'manifest.json'
    Assert-ReleaseSignature ([IO.File]::ReadAllBytes($manifestPath)) ([Convert]::FromBase64String([IO.File]::ReadAllText((Join-Path $ManifestDirectory 'manifest.sig')).Trim()))
    $m = Read-ReleaseManifest $manifestPath
    if ([int]$m.version -ne $ExpectedVersion) { throw "Expected version $ExpectedVersion; got $($m.version)." }
    if ([int]$m.version -lt $MinimumVersion) { throw 'Rollback rejected: below the trusted version.' }
    $stamp = [DateTimeOffset]::Parse([string]$m.signed_at)
    $count = 0
    foreach ($property in $m.files.PSObject.Properties) {
        $name = $property.Name
        if ($name -notmatch '^[A-Za-z0-9][A-Za-z0-9_.-]*$') { throw "Unsafe manifest path: $name" }
        $entry = $property.Value
        if ($Remote) {
            $wc = New-Object Net.WebClient
            try {
                $wc.Headers.Add('User-Agent','elly-release-audit')
                $wc.Headers.Add('Cache-Control','no-cache')
                $wc.DownloadFile(($base + '/' + $name + '?v=' + ([string]$entry.sha256).Substring(0,12)), (Join-Path $temporary $name))
                if ($entry.PSObject.Properties['sha1']) {
                    $wc.DownloadFile(($base + '/' + $name + '.sha1?v=' + $nonce), (Join-Path $temporary ($name + '.sha1')))
                }
            } finally { $wc.Dispose() }
        }
        Assert-ReleaseFile $RepoRoot $name $entry
        $count++
    }
    if ($ExpectedVersion -eq 33) { Assert-Release33Zip $RepoRoot }
    [pscustomobject]@{ Result='PASS'; Version=$m.version; SignedAt=$stamp; FilesChecked=$count; Remote=[bool]$Remote; Ref=$Ref }
} finally {
    if ($temporary -and (Test-Path -LiteralPath $temporary)) { Remove-Item -LiteralPath $temporary -Recurse -Force }
}
