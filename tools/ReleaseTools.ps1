#requires -Version 5.1
# Shared, read-only checks. This file never discovers, creates or persists private keys.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:Release33Sha256 = 'cd04d10f7feed858b2201c4b1dcc07f268895151a4fbe93186fc2d9de92aab14'
$script:Release33Sha1 = 'dcabf514b5ef4809e30ba583b1775f9d4cac11d7'
$script:Release33Size = 2286943
$script:ReleasePublicKey = '<RSAKeyValue><Modulus>uTUYzFZRiZNplu/l4TAOk/zWBNs8vsiHsA8RCicdwyHtezCk2++NsLi6TrfQL942dbTRmQiASXOEa3xqG8Gth6jMt024PlV9/mEGcyq079I8O+Uow9pPPsxe1OzidLex4ehen9G6eAAHpdqWFSjJ/CcbXqp3sLTMox5TqX/ALjyErO7xfeWASHmm9oA1PNP0O6mn06O/vpwvQkNKHPtbhqmoMl+YS6Kc9wL5XG0ob3NuQS2RylkPG0vdwmMB4cU+Pkw2Gus2ieC7nO6GcdxCmoltfUeYosOG+cJnU1OBIRuPLSN5c9PE7uxoQxJwDowNCh0JcxMIa0Mvr/1Sa0eT6/KyarWgguSzkp490od1p0UcP9qnpoRMokN359r7tQtrL4ABayCKq5jxbjA0RUoVpmIgWU0DIR3BoAQ3NE5wJc23OsTjRx8/L1R15eWDY/rjk7N3KUWVH9mHmU9rqlU6fbOJDB1GL/8few4bNy51trjsmzMThsiPdL5jSVqcshGF</Modulus><Exponent>AQAB</Exponent></RSAKeyValue>'

function New-ReleaseRsa {
    # CSP 24 is the same Windows provider used by the existing clients.
    if ($env:OS -eq 'Windows_NT') {
        $csp = New-Object Security.Cryptography.CspParameters(24)
        $rsa = New-Object Security.Cryptography.RSACryptoServiceProvider($csp)
    } else {
        $rsa = New-Object Security.Cryptography.RSACryptoServiceProvider
    }
    $rsa.PersistKeyInCsp = $false
    return $rsa
}

function Read-ReleaseManifest([string]$ManifestPath) {
    $text = [Text.Encoding]::UTF8.GetString([IO.File]::ReadAllBytes($ManifestPath)).TrimStart([char]0xFEFF)
    if ((Get-Command ConvertFrom-Json).Parameters.ContainsKey('DateKind')) {
        return ($text | ConvertFrom-Json -DateKind String)
    }
    return ($text | ConvertFrom-Json)
}

function Assert-ReleaseSignature([byte[]]$Bytes, [byte[]]$Signature) {
    $rsa = New-ReleaseRsa
    try {
        $rsa.FromXmlString($script:ReleasePublicKey)
        if (-not $rsa.VerifyData($Bytes, 'SHA256', $Signature)) {
            throw 'Signature rejected by the existing release public key.'
        }
    } finally { $rsa.Dispose() }
}

function Assert-ReleaseFile([string]$Root, [string]$Name, $Entry) {
    # The current signed manifest contains root-level files only.
    if ($Name -notmatch '^[A-Za-z0-9][A-Za-z0-9_.-]*$') { throw "Unsafe manifest path: $Name" }
    $path = Join-Path $Root $Name
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing file: $Name" }
    if ((Get-Item -LiteralPath $path).Length -ne [long]$Entry.size) { throw "Size mismatch: $Name" }
    if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() -ne $Entry.sha256) {
        throw "SHA256 mismatch: $Name"
    }
    if ($Entry.PSObject.Properties['sha1']) {
        $sha1 = (Get-FileHash -LiteralPath $path -Algorithm SHA1).Hash.ToLowerInvariant()
        if ($sha1 -ne $Entry.sha1) { throw "SHA1 mismatch: $Name" }
        $sidecar = Join-Path $Root ($Name + '.sha1')
        if (-not (Test-Path -LiteralPath $sidecar -PathType Leaf)) { throw "Missing SHA1 sidecar: $Name" }
        if ([IO.File]::ReadAllText($sidecar).Trim() -ne $sha1) { throw "SHA1 sidecar mismatch: $Name" }
    }
}

function Assert-Release33Zip([string]$Root) {
    $entry = [pscustomobject]@{ sha256=$script:Release33Sha256; sha1=$script:Release33Sha1; size=$script:Release33Size }
    Assert-ReleaseFile $Root 'Elly-Korean-Patch.zip' $entry
}
