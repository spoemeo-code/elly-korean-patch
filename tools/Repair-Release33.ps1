#requires -Version 5.1
<#
Creates a candidate OUTSIDE the repository. With no signing option, signed_at is
null and no manifest.sig is produced. Never publish that unsigned candidate.
Use the existing private XML key, OR an existing signer returning raw RSA
PKCS#1 v1.5/SHA-256 signature bytes. Never change the public key to make it pass.
#>
[CmdletBinding(DefaultParameterSetName='Prepare')]
param(
    [string]$RepoRoot = (Split-Path $PSScriptRoot -Parent),
    [Parameter(Mandatory=$true)][string]$OutputDirectory,
    [Parameter(Mandatory=$true, ParameterSetName='XmlSign')][string]$PrivateKeyXmlPath,
    [Parameter(Mandatory=$true, ParameterSetName='ExternalSign')][scriptblock]$SignBytes
)
. (Join-Path $PSScriptRoot 'ReleaseTools.ps1')
$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)
$rootPrefix = $RepoRoot.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
if ($OutputDirectory -eq $RepoRoot -or $OutputDirectory.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'OutputDirectory must be outside the repository.'
}
if (Test-Path -LiteralPath $OutputDirectory) { throw 'Choose a NEW output directory; existing files will not be overwritten.' }
$manifestPath = Join-Path $RepoRoot 'manifest.json'
$bytes = [IO.File]::ReadAllBytes($manifestPath)
# Fail if another release or an unreviewed manifest edit has appeared.
if ((Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash.ToLowerInvariant() -ne 'dbf01935635fb9f8c4a3383008d95b1173bc81e66044a1507bf3eb03cb1e9fd9') {
    throw 'Baseline changed. This repair is only for the audited release-32 manifest at 4d3fcba.'
}
$signature = [Convert]::FromBase64String([IO.File]::ReadAllText((Join-Path $RepoRoot 'manifest.sig')).Trim())
Assert-ReleaseSignature $bytes $signature
$m = Read-ReleaseManifest $manifestPath
if ([int]$m.version -ne 32) { throw 'Expected baseline version 32.' }
foreach ($property in $m.files.PSObject.Properties) {
    if ($property.Name -ne 'Elly-Korean-Patch.zip') { Assert-ReleaseFile $RepoRoot $property.Name $property.Value }
}
Assert-Release33Zip $RepoRoot

# Edit only five exact literals in the pinned baseline. Re-serializing the whole
# JSON can convert unrelated jannu timestamps on some PowerShell versions.
function Set-UniqueLiteral([string]$Text, [string]$Old, [string]$New) {
    $at = $Text.IndexOf($Old, [StringComparison]::Ordinal)
    if ($at -lt 0 -or $at -ne $Text.LastIndexOf($Old, [StringComparison]::Ordinal)) {
        throw 'Expected exactly one baseline literal.'
    }
    return $Text.Replace($Old, $New)
}
$raw = [Text.Encoding]::UTF8.GetString($bytes)
$raw = Set-UniqueLiteral $raw '"version":  32,' '"version":  33,'
$raw = Set-UniqueLiteral $raw 'ad2533fe43db58b273b8baaa6a75b15e796b0012780cb952871311fd5d7b8ba4' $script:Release33Sha256
$raw = Set-UniqueLiteral $raw '197fa19475a25942ef9d0ffcd38504a8320b3cc9' $script:Release33Sha1
$raw = Set-UniqueLiteral $raw '"size":  2285625,' '"size":  2286943,'
$rsa = $null
$signed = $PSCmdlet.ParameterSetName -ne 'Prepare'
try {
    if ($PSCmdlet.ParameterSetName -eq 'XmlSign') {
        $keyPath = (Resolve-Path -LiteralPath $PrivateKeyXmlPath).Path
        if ($keyPath.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
            throw 'Keep the EXISTING private key outside the repository.'
        }
        $rsa = New-ReleaseRsa
        $rsa.FromXmlString([IO.File]::ReadAllText($keyPath))
        if ($rsa.PublicOnly -or $rsa.ToXmlString($false) -cne $script:ReleasePublicKey) {
            throw 'This is not the existing release private key. Nothing was written.'
        }
    }
    $stamp = 'null'
    if ($signed) { $stamp = '"' + [DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(9)).ToString('yyyy-MM-ddTHH:mm:sszzz') + '"' }
    $raw = Set-UniqueLiteral $raw '"signed_at":  "2026-10-02T11:06:24+09:00"' ('"signed_at":  ' + $stamp)
    $utf8 = New-Object Text.UTF8Encoding($false)
    $candidate = $utf8.GetBytes($raw)
    if ($signed) {
        if ($rsa) { $newSignature = $rsa.SignData($candidate, 'SHA256') }
        else { [byte[]]$newSignature = & $SignBytes $candidate }
        # Wrong algorithm/key/base64 output or modified bytes must fail before writing.
        Assert-ReleaseSignature $candidate $newSignature
    }
    [void][IO.Directory]::CreateDirectory($OutputDirectory)
    [IO.File]::WriteAllBytes((Join-Path $OutputDirectory 'manifest.json'), $candidate)
    if ($signed) {
        [IO.File]::WriteAllText((Join-Path $OutputDirectory 'manifest.sig'), [Convert]::ToBase64String($newSignature), $utf8)
        & (Join-Path $PSScriptRoot 'Test-Release.ps1') -RepoRoot $RepoRoot -ManifestDirectory $OutputDirectory -ExpectedVersion 33
        Write-Host 'SIGNED AND VERIFIED. Publish both manifest files in ONE commit after review.'
    } else {
        Write-Host 'UNSIGNED CANDIDATE ONLY. Do not publish. Run again into a new directory with the existing signer.'
    }
} finally { if ($rsa) { $rsa.Dispose() } }
