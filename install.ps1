# 엘리 한글패치를 받아서 마인크래프트 리소스팩 폴더에 넣는다.
# 나중에 번역이 갱신되면 이 파일을 다시 실행하기만 하면 된다.
#
# 파일 이름을 항상 elly-korean-patch.zip 으로 고정하는 이유:
# 마크는 팩을 "파일 이름"으로 기억하기 때문에, 이름이 버전마다 바뀌면
# 켜둔 설정이 풀려서 매번 다시 켜야 한다.

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

$Url      = "https://raw.githubusercontent.com/spoemeo-code/elly-korean-patch/main/Elly-Korean-Patch.zip"
$PackName = "Elly-Korean-Patch.zip"

Write-Host ""
Write-Host "  엘리 한글패치 설치" -ForegroundColor Cyan
Write-Host "  ───────────────────────────"
Write-Host ""

# 마크가 켜져 있으면 설정 파일을 덮어써버려서, 꺼놓고 실행해야 한다
# 자바를 쓰는 프로그램은 많다(런처, 다른 게임, 개발도구). java 프로세스가 있다고
# 마크로 단정하면 런처만 켜둔 사람이 막힌다. 실행 명령줄에 마크 고유의 흔적이
# 있는지 확인한다. 명령줄을 못 읽으면 막지 않는다 — 괜히 못 하게 하는 편이 더 나쁘다.
$mcRunning = @(Get-Process javaw, java -ErrorAction SilentlyContinue | Where-Object {
  try {
    $c = (Get-CimInstance Win32_Process -Filter "ProcessId=$($_.Id)" -ErrorAction SilentlyContinue).CommandLine
    $c -and ($c -match 'net\.minecraft\.client\.main\.Main|net\.fabricmc\.loader|--gameDir|\.minecraft')
  } catch { $false }
})
if ($mcRunning.Count -gt 0) {
  Write-Host "  마인크래프트가 켜져 있어. 끄고 다시 실행해줘." -ForegroundColor Yellow
  Write-Host "  (켜둔 채로 하면 설정이 되돌아가 버려)"
  Write-Host ""
  Read-Host "  엔터를 누르면 창이 닫혀"; exit 1
}

# ── 1. 마크 폴더 찾기 ───────────────────────────────
Write-Host "  마인크래프트 폴더를 찾는 중..." -ForegroundColor Gray
$roots = @(
  "$env:USERPROFILE\curseforge\minecraft\Instances",
  "$env:APPDATA\ModrinthApp\profiles",
  "$env:APPDATA\PrismLauncher\instances",
  "$env:APPDATA\com.modrinth.theseus\profiles",
  "$env:USERPROFILE\Documents\MultiMC\instances"
) | Where-Object { Test-Path $_ }

# options.txt 가 있다고 다 게임 폴더는 아니다. yosbr 같은 모드가 config 안에
# 똑같은 이름의 견본 파일을 두기 때문에, 진짜 게임 폴더인지 한 번 더 따진다.
function Is-GameDir([System.IO.DirectoryInfo]$d) {
  if ($d.FullName -match '\\config\\') { return $false }      # 모드 설정 폴더
  if ($d.FullName -match '\\\.fabric\\') { return $false }
  foreach ($sub in @("mods", "saves", "resourcepacks", "versions", "shaderpacks")) {
    if (Test-Path (Join-Path $d.FullName $sub)) { return $true }
  }
  return $false
}

$found = @()
foreach ($r in $roots) {
  $launcher = Split-Path $r -Leaf
  Get-ChildItem -Path $r -Recurse -File -Depth 3 -Filter "options.txt" -ErrorAction SilentlyContinue |
    ForEach-Object {
      if (Is-GameDir $_.Directory) {
        $found += [pscustomobject]@{ Dir = $_.Directory; Launcher = $launcher }
      }
    }
}
if ((Test-Path "$env:APPDATA\.minecraft\options.txt") -and (Is-GameDir (Get-Item "$env:APPDATA\.minecraft"))) {
  $found += [pscustomobject]@{ Dir = (Get-Item "$env:APPDATA\.minecraft"); Launcher = "기본 런처" }
}
# 같은 폴더가 두 번 잡히는 일이 없게 정리하고, 최근에 쓴 순서로 보여준다
$found = $found | Sort-Object { $_.Dir.FullName } -Unique |
         Sort-Object { (Get-Item (Join-Path $_.Dir.FullName "options.txt")).LastWriteTime } -Descending
$instances = $found | ForEach-Object { $_.Dir }

if (-not $instances) {
  Write-Host "  마인크래프트 폴더를 못 찾았어. 엘리한테 알려줘." -ForegroundColor Red
  Read-Host "  엔터를 누르면 창이 닫혀"; exit 1
}

# 서버를 여러 개 하는 사람은 인스턴스도 여러 개라, 매번 고르게 하면 번거롭다.
# 한 번 고른 곳을 기억해두고 다음부터는 묻지 않는다.
# 다른 데 깔고 싶으면 Shift 를 누른 채 실행하면 다시 묻는다.
$rememberFile = Join-Path $env:APPDATA "elly-korean-patch-target.txt"
$shiftHeld = $false
try {
  Add-Type -AssemblyName System.Windows.Forms
  $shiftHeld = [System.Windows.Forms.Control]::ModifierKeys -band [System.Windows.Forms.Keys]::Shift
} catch { }

if (-not $shiftHeld -and (Test-Path $rememberFile)) {
  $saved = @(Get-Content $rememberFile -Encoding UTF8 | Where-Object { $_ -and (Test-Path $_) })
  if ($saved.Count -gt 0) {
    $targets = $saved | ForEach-Object { Get-Item $_ }
    Write-Host "  지난번에 고른 곳에 넣을게:" -ForegroundColor Green
    $targets | ForEach-Object { Write-Host "    · $($_.Name)" -ForegroundColor DarkGray }
    Write-Host "  (다른 곳에 넣으려면 Shift 를 누른 채 실행해줘)" -ForegroundColor DarkGray
  }
}

if (-not $targets -and $instances.Count -eq 1) {
  $target = $instances[0]
  Write-Host "  찾았어: $($target.Name)" -ForegroundColor Green
} elseif (-not $targets) {
  Write-Host ""
  Write-Host "  마크 폴더가 여러 개 있어. 어디에 넣을까?" -ForegroundColor Yellow
  Write-Host "  (최근에 플레이한 순서야. 보통 1번이 맞아. 한 번 고르면 다음부턴 안 물어봐)" -ForegroundColor DarkGray
  Write-Host ""
  for ($i = 0; $i -lt $found.Count; $i++) {
    $f = $found[$i]
    $when = (Get-Item (Join-Path $f.Dir.FullName "options.txt")).LastWriteTime
    $mods = (Get-ChildItem (Join-Path $f.Dir.FullName "mods") -Filter *.jar -ErrorAction SilentlyContinue | Measure-Object).Count
    Write-Host ("    {0}. {1}" -f ($i + 1), $f.Dir.Name) -ForegroundColor White
    Write-Host ("       {0} · 모드 {1}개 · 마지막 플레이 {2:yyyy-MM-dd}" -f $f.Launcher, $mods, $when) -ForegroundColor DarkGray
  }
  Write-Host ("    a. 전부 다")
  Write-Host ""
  $pick = Read-Host "  번호"
  if ($pick -eq "a") { $targets = $instances }
  else {
    $n = 0
    if (-not [int]::TryParse($pick, [ref]$n) -or $n -lt 1 -or $n -gt $instances.Count) {
      Write-Host "  그런 번호는 없어." -ForegroundColor Red; Read-Host "  엔터"; exit 1
    }
    $targets = @($instances[$n - 1])
  }
  # 고른 곳을 기억해둔다. 다음 실행 때는 묻지 않는다.
  try {
    $targets | ForEach-Object { $_.FullName } | Set-Content $rememberFile -Encoding UTF8
    Write-Host "  기억해뒀어. 다음부터는 안 물어볼게." -ForegroundColor DarkGray
  } catch { }
}
if (-not $targets) { $targets = @($target) }

# ── 2. 내려받기 ─────────────────────────────────────
Write-Host ""
Write-Host "  최신 한글패치를 받는 중..." -ForegroundColor Gray
$tmp = Join-Path $env:TEMP "elly-patch-download.zip"
try {
  # 캐시를 무시하고 늘 최신을 받는다
  Invoke-WebRequest -Uri $Url -OutFile $tmp -TimeoutSec 120 -Headers @{ "Cache-Control" = "no-cache"; "Pragma" = "no-cache" }
} catch {
  Write-Host "  다운로드 실패: $($_.Exception.Message)" -ForegroundColor Red
  Write-Host "  인터넷이 되는지 확인하고 다시 해봐."
  Read-Host "  엔터를 누르면 창이 닫혀"; exit 1
}

# 받은 게 진짜 리소스팩인지 확인한다(깨진 파일을 넣으면 마크가 켜지다 만다)
Add-Type -AssemblyName System.IO.Compression.FileSystem
try {
  $z = [System.IO.Compression.ZipFile]::OpenRead($tmp)
  $hasMeta = ($z.Entries | Where-Object { $_.FullName -eq "pack.mcmeta" }).Count -gt 0
  $langCount = ($z.Entries | Where-Object { $_.Name -ieq "ko_kr.json" }).Count
  $z.Dispose()
} catch {
  Write-Host "  받은 파일이 깨져 있어. 잠시 뒤 다시 해봐." -ForegroundColor Red
  Remove-Item $tmp -ErrorAction SilentlyContinue
  Read-Host "  엔터를 누르면 창이 닫혀"; exit 1
}
if (-not $hasMeta -or $langCount -eq 0) {
  Write-Host "  받은 파일이 리소스팩이 아니야. 엘리한테 알려줘." -ForegroundColor Red
  Remove-Item $tmp -ErrorAction SilentlyContinue
  Read-Host "  엔터를 누르면 창이 닫혀"; exit 1
}
$mb = [math]::Round((Get-Item $tmp).Length / 1MB, 2)
Write-Host "  받았어 — 번역 $langCount 개, $mb MB" -ForegroundColor Green

# ── 3. 넣기 ─────────────────────────────────────────
Write-Host ""
foreach ($t in $targets) {
  $rp = Join-Path $t.FullName "resourcepacks"
  if (-not (Test-Path $rp)) { New-Item -ItemType Directory -Path $rp -Force | Out-Null }

  # 옛날 본체 패치가 남아 있으면 치운다. 이름만 보고 지우면 부가팩(Extra)까지
  # 날아가므로, zip 을 열어 번역 줄 수를 보고 "본체인지"를 판단한다.
  # 본체는 번역 파일이 수백 개, 부가팩은 수십 개 수준이라 확실히 갈린다.
  $mainThreshold = [Math]::Max(50, [int]($langCount * 0.5))
  $olds = Get-ChildItem $rp -Filter "*.zip" -File -ErrorAction SilentlyContinue |
          Where-Object { $_.Name -ne $PackName }
  foreach ($o in $olds) {
    try {
      $oz = [System.IO.Compression.ZipFile]::OpenRead($o.FullName)
      $oLang = ($oz.Entries | Where-Object { $_.Name -ieq "ko_kr.json" }).Count
      $oz.Dispose()
    } catch { continue }
    # 번역 파일이 본체급으로 많은 zip 만 옛 본체로 보고 치운다
    if ($oLang -ge $mainThreshold) {
      Remove-Item $o.FullName -Force -ErrorAction SilentlyContinue
      Write-Host "    옛날 본체 치움: $($o.Name) (번역 $oLang 개)" -ForegroundColor DarkGray
    }
  }

  Copy-Item $tmp (Join-Path $rp $PackName) -Force
  Write-Host "    넣었어: $($t.Name)" -ForegroundColor Green

  # 켜져 있지 않으면 설정에 추가해 준다(마크가 꺼져 있을 때만 안전하다)
  $opt = Join-Path $t.FullName "options.txt"
  if (Test-Path $opt) {
    try {
      $lines = Get-Content $opt -Encoding UTF8
      $idx = ($lines | Select-String -Pattern '^resourcePacks:' | Select-Object -First 1)
      $entry = '"file/' + $PackName + '"'
      if ($idx -and $idx.Line -notlike "*$PackName*") {
        Copy-Item $opt "$opt.bak" -Force
        $cur = $idx.Line -replace '^resourcePacks:', ''
        if ($cur.Trim() -eq "[]") { $new = 'resourcePacks:[' + $entry + ']' }
        else { $new = 'resourcePacks:' + ($cur -replace '\]\s*$', (',' + $entry + ']')) }
        $lines[$idx.LineNumber - 1] = $new
        Set-Content $opt $lines -Encoding UTF8
        Write-Host "    마크 설정에서 켜줬어" -ForegroundColor Green
      } elseif ($idx) {
        Write-Host "    이미 켜져 있어" -ForegroundColor DarkGray
      }
    } catch {
      Write-Host "    설정은 못 건드렸어 — 마크에서 직접 켜줘" -ForegroundColor Yellow
    }
  }
}
Remove-Item $tmp -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "  끝났어!" -ForegroundColor Green
Write-Host ""
Write-Host "  마크 켜서 한글로 나오는지 보면 돼."
Write-Host "  안 되면 설정 → 리소스팩 에서 '엘리 한글패치'를 오른쪽으로 옮겨줘."
Write-Host ""
Write-Host "  나중에 번역이 갱신되면 이 파일을 다시 누르기만 하면 돼." -ForegroundColor Cyan
Write-Host ""
Read-Host "  엔터를 누르면 창이 닫혀"
