# 잔누서버 모드팩을 내 마크에 맞춰준다.
#
# 원칙: 내가 직접 깐 모드는 절대 지우지 않는다. 팩에 있는데 없는 것만 받아온다.
# 어디에 넣을지는 한 번만 묻고 기억한다(서버를 여러 개 하는 사람이 많아서).

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

$Repo = "JannuH2/Jannu-maku-dudutown"
$Branch = "main"
$rememberFile = Join-Path $env:APPDATA "jannu-pack-target.txt"

Write-Host ""
Write-Host "  잔누서버 모드 맞추기" -ForegroundColor Cyan
Write-Host "  ─────────────────────────────"

# ── 마크가 켜져 있으면 안 된다 ─────────────────────────
# 자바를 쓰는 프로그램은 많으므로(런처 포함) 명령줄로 마크인지 가린다.
$mcRunning = @(Get-Process javaw, java -ErrorAction SilentlyContinue | Where-Object {
  try {
    $c = (Get-CimInstance Win32_Process -Filter "ProcessId=$($_.Id)" -ErrorAction SilentlyContinue).CommandLine
    $c -and ($c -match 'net\.minecraft\.client\.main\.Main|net\.fabricmc\.loader|--gameDir|\.minecraft')
  } catch { $false }
})
if ($mcRunning.Count -gt 0) {
  Write-Host "  마인크래프트가 켜져 있어. 끄고 다시 실행해줘." -ForegroundColor Yellow
  Write-Host ""
  Read-Host "  엔터를 누르면 창이 닫혀"; exit 1
}

# ── 1. 마크 폴더 찾기 ──────────────────────────────────
function Is-GameDir([System.IO.DirectoryInfo]$d) {
  if ($d.FullName -match '\\config\\') { return $false }
  if ($d.FullName -match '\\\.fabric\\') { return $false }
  foreach ($sub in @("mods", "saves", "resourcepacks", "versions")) {
    if (Test-Path (Join-Path $d.FullName $sub)) { return $true }
  }
  return $false
}

$shiftHeld = $false
try {
  Add-Type -AssemblyName System.Windows.Forms
  $shiftHeld = [System.Windows.Forms.Control]::ModifierKeys -band [System.Windows.Forms.Keys]::Shift
} catch { }

$target = $null
if (-not $shiftHeld -and (Test-Path $rememberFile)) {
  $saved = (Get-Content $rememberFile -Encoding UTF8 | Select-Object -First 1)
  if ($saved -and (Test-Path $saved)) {
    $target = Get-Item $saved
    Write-Host "  지난번에 고른 곳: $($target.Name)" -ForegroundColor Green
    Write-Host "  (다른 곳에 하려면 Shift 를 누른 채 실행해줘)" -ForegroundColor DarkGray
  }
}

if (-not $target) {
  Write-Host "  마인크래프트 폴더를 찾는 중..." -ForegroundColor Gray
  $roots = @(
    "$env:USERPROFILE\curseforge\minecraft\Instances",
    "$env:APPDATA\ModrinthApp\profiles",
    "$env:APPDATA\PrismLauncher\instances",
    "$env:APPDATA\com.modrinth.theseus\profiles",
    "$env:USERPROFILE\Documents\MultiMC\instances"
  ) | Where-Object { Test-Path $_ }

  $found = @()
  foreach ($r in $roots) {
    $launcher = Split-Path (Split-Path $r -Parent) -Leaf
    Get-ChildItem -Path $r -Recurse -File -Depth 3 -Filter "options.txt" -ErrorAction SilentlyContinue |
      ForEach-Object { if (Is-GameDir $_.Directory) { $found += [pscustomobject]@{ Dir = $_.Directory; Launcher = $launcher } } }
  }
  if ((Test-Path "$env:APPDATA\.minecraft\options.txt") -and (Is-GameDir (Get-Item "$env:APPDATA\.minecraft"))) {
    $found += [pscustomobject]@{ Dir = (Get-Item "$env:APPDATA\.minecraft"); Launcher = "기본 런처" }
  }
  $found = $found | Sort-Object { $_.Dir.FullName } -Unique |
           Sort-Object { (Get-Item (Join-Path $_.Dir.FullName "options.txt")).LastWriteTime } -Descending

  if (-not $found) {
    Write-Host "  마인크래프트 폴더를 못 찾았어. 엘리한테 알려줘." -ForegroundColor Red
    Read-Host "  엔터를 누르면 창이 닫혀"; exit 1
  }

  if ($found.Count -eq 1) {
    $target = $found[0].Dir
    Write-Host "  찾았어: $($target.Name)" -ForegroundColor Green
  } else {
    Write-Host ""
    Write-Host "  어느 마크에 맞출까?" -ForegroundColor Yellow
    Write-Host "  (최근에 플레이한 순서야. 한 번 고르면 다음부턴 안 물어봐)" -ForegroundColor DarkGray
    Write-Host ""
    for ($i = 0; $i -lt $found.Count; $i++) {
      $f = $found[$i]
      $mods = (Get-ChildItem (Join-Path $f.Dir.FullName "mods") -Filter *.jar -ErrorAction SilentlyContinue | Measure-Object).Count
      $when = (Get-Item (Join-Path $f.Dir.FullName "options.txt")).LastWriteTime
      Write-Host ("    {0}. {1}" -f ($i + 1), $f.Dir.Name) -ForegroundColor White
      Write-Host ("       {0} · 모드 {1}개 · 마지막 플레이 {2:yyyy-MM-dd}" -f $f.Launcher, $mods, $when) -ForegroundColor DarkGray
    }
    Write-Host ""
    $pick = Read-Host "  번호"
    $n = 0
    if (-not [int]::TryParse($pick, [ref]$n) -or $n -lt 1 -or $n -gt $found.Count) {
      Write-Host "  그런 번호는 없어." -ForegroundColor Red; Read-Host "  엔터"; exit 1
    }
    $target = $found[$n - 1].Dir
    try { $target.FullName | Set-Content $rememberFile -Encoding UTF8; Write-Host "  기억해뒀어." -ForegroundColor DarkGray } catch { }
  }
}

$modsDir = Join-Path $target.FullName "mods"
if (-not (Test-Path $modsDir)) { New-Item -ItemType Directory -Path $modsDir -Force | Out-Null }

# ── 2. 팩의 모드 목록 읽기 ────────────────────────────
Write-Host ""
Write-Host "  서버 모드 목록을 받는 중..." -ForegroundColor Cyan
$api = "https://api.github.com/repos/$Repo/contents/mods?per_page=100"
$entries = @()
for ($page = 1; $page -le 5; $page++) {
  try {
    $r = Invoke-RestMethod -Uri ($api + "&page=$page") -Headers @{ "User-Agent" = "elly-mod-sync" } -TimeoutSec 60
  } catch {
    Write-Host "  서버 목록을 받지 못했어: $($_.Exception.Message)" -ForegroundColor Red
    Read-Host "  엔터를 누르면 창이 닫혀"; exit 1
  }
  $entries += $r
  if ($r.Count -lt 100) { break }
}

# .pw.toml 은 "이 모드를 어디서 받는지"가 적힌 쪽지다. 안을 읽어야 실제 파일명과 주소가 나온다.
$want = @()
foreach ($e in $entries) {
  if ($e.name -like "*.jar") {
    $want += [pscustomobject]@{ File = $e.name; Url = $e.download_url }
  } elseif ($e.name -like "*.pw.toml") {
    try {
      $t = (Invoke-WebRequest -Uri $e.download_url -UseBasicParsing -TimeoutSec 30).Content
      if ($t -is [byte[]]) { $t = [Text.Encoding]::UTF8.GetString($t) }
      $fn = [regex]::Match($t, '(?m)^\s*filename\s*=\s*"(.+)"').Groups[1].Value
      $url = [regex]::Match($t, '(?m)^\s*url\s*=\s*"(.+)"').Groups[1].Value
      if (-not $url) {
        $pid2 = [regex]::Match($t, '(?m)^\s*project-id\s*=\s*(\d+)').Groups[1].Value
        $fid = [regex]::Match($t, '(?m)^\s*file-id\s*=\s*(\d+)').Groups[1].Value
        if ($pid2 -and $fid) { $url = "https://www.curseforge.com/api/v1/mods/$pid2/files/$fid/download" }
      }
      if ($fn -and $url) { $want += [pscustomobject]@{ File = $fn; Url = $url } }
    } catch { }
  }
}

if (-not $want) {
  Write-Host "  모드 목록이 비어 있어. 잠시 뒤 다시 해봐." -ForegroundColor Red
  Read-Host "  엔터를 누르면 창이 닫혀"; exit 1
}

$have = @{}
Get-ChildItem $modsDir -Filter "*.jar" -File -ErrorAction SilentlyContinue | ForEach-Object { $have[$_.Name] = $true }
$missing = @($want | Where-Object { -not $have.ContainsKey($_.File) })

Write-Host "  서버 모드 $($want.Count)개 · 내 모드 $($have.Count)개 · 받을 것 $($missing.Count)개"
if ($missing.Count -eq 0) {
  Write-Host ""
  Write-Host "  이미 최신이야! 그냥 들어가면 돼." -ForegroundColor Green
  Write-Host ""
  Read-Host "  엔터를 누르면 창이 닫혀"; exit 0
}

# ── 3. 없는 것만 받는다 ───────────────────────────────
Write-Host ""
Write-Host "  $($missing.Count)개를 받는 중... (처음이면 오래 걸려요)" -ForegroundColor Cyan
$ok = 0; $fail = @()
$n = 0
foreach ($m in $missing) {
  $n++
  Write-Progress -Activity "모드 받는 중" -Status "$n / $($missing.Count)" -PercentComplete ($n / $missing.Count * 100)
  $dest = Join-Path $modsDir $m.File
  $tmp = "$dest.part"
  try {
    Invoke-WebRequest -Uri $m.Url -OutFile $tmp -UseBasicParsing -TimeoutSec 180
    # 받다 만 파일을 모드 폴더에 남기면 마크가 안 켜진다. 다 받은 뒤에만 이름을 바꾼다.
    if ((Get-Item $tmp).Length -lt 1000) { throw "파일이 너무 작아요" }
    Move-Item $tmp $dest -Force
    $ok++
  } catch {
    Remove-Item $tmp -ErrorAction SilentlyContinue
    $fail += $m.File
  }
}
Write-Progress -Activity "모드 받는 중" -Completed

Write-Host ""
Write-Host "  받았어: $ok 개" -ForegroundColor Green
if ($fail.Count) {
  Write-Host "  실패: $($fail.Count) 개" -ForegroundColor Yellow
  $fail | Select-Object -First 5 | ForEach-Object { Write-Host "    · $_" -ForegroundColor DarkGray }
  Write-Host "  다시 실행하면 못 받은 것만 다시 받아요." -ForegroundColor DarkGray
}
Write-Host ""
Write-Host "  내가 직접 깐 모드는 그대로 뒀어." -ForegroundColor DarkGray
Write-Host "  마크 켜서 들어가면 돼!" -ForegroundColor Green
Write-Host ""
Read-Host "  엔터를 누르면 창이 닫혀"
