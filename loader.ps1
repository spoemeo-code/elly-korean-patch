# 엘리/잔누 마크 도우미 — 확인 후 실행기
# .bat 은 이 파일만 실행한다. 이 파일은 elly 가 서명한 manifest 를 확인하고,
# 거기 적힌 해시와 똑같은 도우미 창 파일만 실행한다. 확인에 실패하면 마지막으로
# 확인된 사본으로 실행하고, 그 사실을 창에 알린다.
param(
  [string]$Server = "elly",
  [string]$Launcher = ""
)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Windows.Forms

$BASE = "https://raw.githubusercontent.com/spoemeo-code/elly-korean-patch/main"
$AppHome = if ($Server -eq "elly") { "elly-helper" } else { "jannu-helper" }
$GuiName = if ($Server -eq "elly") { "gui-elly.ps1" } else { "gui.ps1" }
$AppName = if ($Server -eq "elly") { "엘리 마크 도우미" } else { "잔누 마크 도우미" }

# ── 배포 서명 확인 (loader.ps1 · gui-elly.ps1 · gui.ps1 에 같은 내용) ──
# elly PC 에만 있는 열쇠로 서명한 manifest.json 만 믿는다. 공개키는 밖에 내보내도 되는 쪽이다.
$ReleasePubKey = '<RSAKeyValue><Modulus>uTUYzFZRiZNplu/l4TAOk/zWBNs8vsiHsA8RCicdwyHtezCk2++NsLi6TrfQL942dbTRmQiASXOEa3xqG8Gth6jMt024PlV9/mEGcyq079I8O+Uow9pPPsxe1OzidLex4ehen9G6eAAHpdqWFSjJ/CcbXqp3sLTMox5TqX/ALjyErO7xfeWASHmm9oA1PNP0O6mn06O/vpwvQkNKHPtbhqmoMl+YS6Kc9wL5XG0ob3NuQS2RylkPG0vdwmMB4cU+Pkw2Gus2ieC7nO6GcdxCmoltfUeYosOG+cJnU1OBIRuPLSN5c9PE7uxoQxJwDowNCh0JcxMIa0Mvr/1Sa0eT6/KyarWgguSzkp490od1p0UcP9qnpoRMokN359r7tQtrL4ABayCKq5jxbjA0RUoVpmIgWU0DIR3BoAQ3NE5wJc23OsTjRx8/L1R15eWDY/rjk7N3KUWVH9mHmU9rqlU6fbOJDB1GL/8few4bNy51trjsmzMThsiPdL5jSVqcshGF</Modulus><Exponent>AQAB</Exponent></RSAKeyValue>'
$RelHome = Join-Path $env:APPDATA $AppHome
$RelDir  = Join-Path $RelHome "verified"
function Rel-Fetch($url, $dest) {
  $wc = New-Object System.Net.WebClient
  $wc.Headers.Add("User-Agent", "elly-helper")
  $wc.Headers.Add("Cache-Control", "no-cache")
  try { $wc.DownloadFile($url, $dest) } finally { $wc.Dispose() }
}
function Rel-Sha256($path) { return (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLower() }
function Rel-Verify([byte[]]$bytes, [string]$sigB64) {
  $csp = New-Object System.Security.Cryptography.CspParameters(24)
  $rsa = New-Object System.Security.Cryptography.RSACryptoServiceProvider($csp)
  try {
    $rsa.PersistKeyInCsp = $false
    $rsa.FromXmlString($ReleasePubKey)
    return $rsa.VerifyData($bytes, "SHA256", [Convert]::FromBase64String($sigB64.Trim()))
  } finally { $rsa.Dispose() }
}
# 받아서 서명과 버전을 확인한 manifest 를 돌려준다. 실패하면 "확인:" 또는 "연결:" 로 시작하는 오류를 던진다.
function Get-ReleaseManifest {
  $tag = [DateTime]::UtcNow.Ticks
  $mj = Join-Path $env:TEMP ("elly-manifest-" + $tag + ".json")
  $ms = "$mj.sig"
  try {
    try {
      Rel-Fetch "$BASE/manifest.json?v=$tag" $mj
      Rel-Fetch "$BASE/manifest.sig?v=$tag" $ms
    } catch { throw "연결: $($_.Exception.Message)" }
    $bytes = [IO.File]::ReadAllBytes($mj)
    $ok = $false
    try { $ok = Rel-Verify $bytes ([IO.File]::ReadAllText($ms)) } catch { $ok = $false }
    if (-not $ok) { throw "확인: 서명이 맞지 않습니다" }
    $m = [Text.Encoding]::UTF8.GetString($bytes).TrimStart([char]0xFEFF) | ConvertFrom-Json
    # 옛 배포를 다시 내미는 것을 막는다. 한 번 본 번호보다 작으면 받지 않는다.
    $tf = Join-Path $RelHome "trusted-version.txt"
    $last = 0
    if (Test-Path -LiteralPath $tf) { try { $last = [int]([IO.File]::ReadAllText($tf).Trim()) } catch { $last = 0 } }
    if ([int]$m.version -lt $last) { throw "확인: 이전 배포($($m.version))입니다. 마지막으로 확인한 배포는 $last 입니다" }
    [void][IO.Directory]::CreateDirectory($RelDir)
    [IO.File]::WriteAllText($tf, [string][int]$m.version)
    [IO.File]::Copy($mj, (Join-Path $RelDir "manifest.json"), $true)
    [IO.File]::Copy($ms, (Join-Path $RelDir "manifest.sig"), $true)
    return $m
  } finally {
    Remove-Item -LiteralPath $mj, $ms -ErrorAction SilentlyContinue
  }
}
# manifest 에 적힌 파일을 받아 크기와 해시가 맞을 때만 dest 에 놓는다.
function Get-ReleaseFile($m, [string]$name, [string]$url, [string]$dest) {
  $e = $m.files.$name
  if (-not $e) { throw "확인: $name 이(가) 배포 목록에 없습니다" }
  $tmp = "$dest.part"
  # 배포 직후 raw 캐시(최대 5분)가 옛 파일을 주지 않게, 기대하는 해시로 주소를 바꿔서 받는다
  $sep = if ($url.Contains("?")) { "&" } else { "?" }
  $fresh = $url + $sep + "v=" + ([string]$e.sha256).Substring(0, 12)
  try { Rel-Fetch $fresh $tmp } catch { throw "연결: $($_.Exception.Message)" }
  if ((Get-Item -LiteralPath $tmp).Length -ne [long]$e.size -or (Rel-Sha256 $tmp) -ne ([string]$e.sha256).ToLower()) {
    Remove-Item -LiteralPath $tmp -ErrorAction SilentlyContinue
    throw "확인: $name 이(가) 배포된 파일과 다릅니다"
  }
  Move-Item -LiteralPath $tmp -Destination $dest -Force
}
# ── 서명 확인 끝 ──

$notice = ""
$guiPath = Join-Path $RelDir $GuiName
try {
  $m = Get-ReleaseManifest
  $e = $m.files.$GuiName
  if (-not (Test-Path -LiteralPath $guiPath) -or (Rel-Sha256 $guiPath) -ne ([string]$e.sha256).ToLower()) {
    Get-ReleaseFile $m $GuiName "$BASE/$GuiName" $guiPath
  }
  # 이 파일도 배포 목록과 다르면 확인된 새것으로 바꿔 둔다(다음 실행부터 적용)
  $me = $PSCommandPath
  $le = $m.files."loader.ps1"
  if ($me -and $le -and (Rel-Sha256 $me) -ne ([string]$le.sha256).ToLower()) {
    try { Get-ReleaseFile $m "loader.ps1" "$BASE/loader.ps1" $me } catch { }
  }
} catch {
  $why = $_.Exception.Message
  $notice = if ($why -like "연결:*") { "배포 서버에 연결하지 못해 이전 버전으로 실행합니다." }
            else { "배포되지 않은 파일이라 받지 않았습니다. 이전 버전으로 실행합니다." }
  try {
    [void][IO.Directory]::CreateDirectory($RelHome)
    ((Get-Date -Format "yyyy-MM-dd HH:mm:ss") + "  [확인 실패] " + $why) |
      Out-File (Join-Path $RelHome "loader-log.txt") -Encoding UTF8 -Append
  } catch { }
}

# 실행하기 전에, 가진 사본이 마지막으로 확인된 manifest 와 맞는지 한 번 더 본다.
$okToRun = $false
try {
  $cm = Join-Path $RelDir "manifest.json"; $cs = Join-Path $RelDir "manifest.sig"
  if ((Test-Path -LiteralPath $guiPath) -and (Test-Path -LiteralPath $cm) -and (Test-Path -LiteralPath $cs)) {
    $cb = [IO.File]::ReadAllBytes($cm)
    if (Rel-Verify $cb ([IO.File]::ReadAllText($cs))) {
      $cmo = [Text.Encoding]::UTF8.GetString($cb).TrimStart([char]0xFEFF) | ConvertFrom-Json
      $okToRun = ((Rel-Sha256 $guiPath) -eq ([string]$cmo.files.$GuiName.sha256).ToLower())
    }
  }
} catch { $okToRun = $false }

if (-not $okToRun) {
  [void][System.Windows.Forms.MessageBox]::Show(
    "배포된 프로그램을 확인하지 못해 실행하지 않았습니다.`n인터넷 연결을 확인하신 뒤 다시 실행해 주세요.`n계속 안 되면 서버장에게 알려주세요.",
    $AppName, "OK", "Warning")
  exit 1
}

$args2 = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-WindowStyle", "Hidden", "-File", "`"$guiPath`"", "-Server", $Server)
if ($Launcher) { $args2 += @("-Launcher", "`"$Launcher`"") }
if ($notice)   { $args2 += @("-Notice", "`"$notice`"") }
Start-Process powershell -ArgumentList $args2 -WindowStyle Hidden
