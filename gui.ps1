# 마크 도우미 — 버튼만 누르면 되는 창.
#
# 예전에는 버튼을 누르면 설치 스크립트를 검은 창에서 따로 돌렸다.
# 그 창이 보기 싫다는 말이 있었고, 한글패치 쪽은 창 안에서 번호를 물어보는데
# 그걸 모르고 지나쳐서 "버튼이 안 먹는다"는 일이 생겼다.
# 그래서 설치를 전부 이 창 안에서 한다. 검은 창은 더 이상 뜨지 않는다.
#
# 배포본이 두 가지다. 누누 서버 사람들에게 엘리 서버 버튼을 보여주면 헷갈리므로
# 실행할 때 -Server 로 어느 쪽인지 받아 버튼 구성을 바꾼다.
param(
  [ValidateSet("elly", "jannu")]
  [string]$Server = "jannu",
  [string]$Launcher = "",
  [string]$Notice = ""
)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.Windows.Forms.Application]::EnableVisualStyles()
# 옛날 TLS 로 붙으면 깃허브가 거절한다
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch { }

# 상태 글자 색. 어두운 버튼 위에 얹히므로 밝은 쪽으로 고른다.
$ColorGood = [System.Drawing.Color]::FromArgb(150, 235, 140)   # 최신
$ColorBad  = [System.Drawing.Color]::FromArgb(255, 150, 140)   # 갱신 필요
$ColorDim  = [System.Drawing.Color]::FromArgb(210, 210, 205)   # 확인 실패

$BASE      = "https://raw.githubusercontent.com/spoemeo-code/elly-korean-patch/main"
$AppHome      = "jannu-helper"
$IconFile     = "jannu-icon.ico"
$LauncherFile = "jannu-helper.bat"
$GuiFileName  = "gui.ps1"
$PatchUrl  = "$BASE/Elly-Korean-Patch.zip"
$PatchName = "Elly-Korean-Patch.zip"
# 설치 위치는 한글패치·모드가 같은 폴더다. 따로 기억했더니 한쪽만 아는 상태가 생겼다.
$PatchRemember = "elly-korean-patch-target.txt"   # 예전 판에서 쓰던 파일 (읽기만)
# 설치 위치와 설치 기록은 배포본마다 따로 둔다. 같이 쓰면 서버를 둘 다 하시는 분이
# 한쪽을 쓸 때마다 다른 쪽 설치 위치가 덮어써진다. (아래 $Server 에 따라 정해진다)

if ($Server -eq "elly") {
  $AppName      = "엘리 마크 도우미"
  $PackRepo     = "spoemeo-code/elly-modpack-packwiz"
  $PackLabel    = "엘리서버"
  $PackRemember  = "elly-pack-target.txt"
  $MainRemember  = "elly-helper-target.txt"
  $ModMapName    = "elly-helper-modmap.json"
  $ServerAddr   = "ellymc.duckdns.org"
  $PingHost     = "ellymc.duckdns.org"
  $PingPort     = 25565
  $NewsUrl      = $null
  $NewsWeb      = $null
} else {
  $AppName      = "잔누 마크 도우미"
  $PackRepo     = "JannuH2/Jannu-maku-dudutown"
  $PackLabel    = "잔누서버"
  $PackRemember  = "jannu-pack-target.txt"
  $MainRemember  = "jannu-helper-target.txt"
  $ModMapName    = "jannu-helper-modmap.json"
  $ServerAddr   = $null
  $PingHost     = "112.146.202.159"
  $PingPort     = 25565
  # 디스코드 앱이 깔려 있으면 앱에서 바로 열리고, 아니면 브라우저로 넘어간다
  $NewsUrl      = "https://discord.com/channels/1534098593483456644/1540822932857823352"
  $NewsWeb      = "discord://discord.com/channels/1534098593483456644/1540822932857823352"
}

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
  try { Rel-Fetch $url $tmp } catch { throw "연결: $($_.Exception.Message)" }
  if ((Get-Item -LiteralPath $tmp).Length -ne [long]$e.size -or (Rel-Sha256 $tmp) -ne ([string]$e.sha256).ToLower()) {
    Remove-Item -LiteralPath $tmp -ErrorAction SilentlyContinue
    throw "확인: $name 이(가) 배포된 파일과 다릅니다"
  }
  Move-Item -LiteralPath $tmp -Destination $dest -Force
}
# ── 서명 확인 끝 ──
# 한 번 확인한 목록은 창이 떠 있는 동안 다시 받지 않는다
$script:RelM = $null
function Get-Rel {
  if (-not $script:RelM) { $script:RelM = Get-ReleaseManifest }
  return $script:RelM
}

# ── 창 ────────────────────────────────────────────────
$form                 = New-Object System.Windows.Forms.Form
$form.Text            = $AppName
$form.Size            = New-Object System.Drawing.Size(556, 548)
$form.StartPosition   = "CenterScreen"
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox     = $false
$form.BackColor       = [System.Drawing.Color]::FromArgb(246, 245, 241)
$form.Font            = New-Object System.Drawing.Font("맑은 고딕", 9)

# 창 아이콘. 파일을 따로 받지 않아도 되게 그림을 글자로 바꿔 넣어 뒀다.
$IconB64 = "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"
try {
  $iconMs  = New-Object System.IO.MemoryStream(,[Convert]::FromBase64String($IconB64))
  $iconBmp = New-Object System.Drawing.Bitmap($iconMs)
  $form.Icon = [System.Drawing.Icon]::FromHandle($iconBmp.GetHicon())
} catch { }

$title           = New-Object System.Windows.Forms.Label
$title.Text      = $AppName
$title.Font      = New-Object System.Drawing.Font("맑은 고딕", 15, [System.Drawing.FontStyle]::Bold)
$title.ForeColor = [System.Drawing.Color]::FromArgb(45, 48, 42)
$title.Location  = New-Object System.Drawing.Point(24, 20)
$title.Size      = New-Object System.Drawing.Size(270, 30)
$form.Controls.Add($title)

$sub           = New-Object System.Windows.Forms.Label
$sub.Text      = "서버 모드 업데이트 버튼을 누르기 전 마인크래프트가 종료되어있는지 확인해 주세요."
$sub.ForeColor = [System.Drawing.Color]::FromArgb(110, 114, 105)
$sub.Location  = New-Object System.Drawing.Point(25, 50)
$sub.Size      = New-Object System.Drawing.Size(500, 20)
$form.Controls.Add($sub)

# 서버가 지금 켜져 있는지. 주소에 붙어보기만 하면 알 수 있어서 따로 인증이 필요 없다.
$srvLbl           = New-Object System.Windows.Forms.Label
$srvLbl.Text      = ""
$srvLbl.Location  = New-Object System.Drawing.Point(310, 22)
$srvLbl.Size      = New-Object System.Drawing.Size(206, 24)
$srvLbl.TextAlign = "MiddleRight"
$srvLbl.Font      = New-Object System.Drawing.Font("맑은 고딕", 9, [System.Drawing.FontStyle]::Bold)
$srvLbl.ForeColor = [System.Drawing.Color]::FromArgb(150, 153, 145)
$form.Controls.Add($srvLbl)

function New-BigButton($text, $y, $color) {
  $b           = New-Object System.Windows.Forms.Button
  $b.Text      = $text
  $b.Location  = New-Object System.Drawing.Point(24, $y)
  $b.Size      = New-Object System.Drawing.Size(492, 52)
  $b.FlatStyle = "Flat"
  $b.BackColor = $color
  $b.ForeColor = [System.Drawing.Color]::White
  $b.Font      = New-Object System.Drawing.Font("맑은 고딕", 10, [System.Drawing.FontStyle]::Bold)
  $b.TextAlign = "MiddleLeft"
  $b.Padding   = New-Object System.Windows.Forms.Padding(18, 0, 0, 0)
  $b.FlatAppearance.BorderSize = 0
  $b.Cursor    = "Hand"
  # 마우스를 올리면 한 톤 밝아진다. 누를 수 있는 자리라는 표시.
  $b.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(
    [Math]::Min(255, [int]$color.R + 28), [Math]::Min(255, [int]$color.G + 28), [Math]::Min(255, [int]$color.B + 28))
  $b.FlatAppearance.MouseDownBackColor = [System.Drawing.Color]::FromArgb(
    [Math]::Max(0, [int]$color.R - 20), [Math]::Max(0, [int]$color.G - 20), [Math]::Max(0, [int]$color.B - 20))
  return $b
}

# 모드가 안 맞으면 아예 못 들어가니 서버 모드를 위에 둔다. 한글패치는 안 해도 들어가진다.
$btnMods  = New-BigButton "$PackLabel 모드 업데이트" 88  ([System.Drawing.Color]::FromArgb(70, 96, 130))
$btnPatch = New-BigButton "한글패치 업데이트"        150 ([System.Drawing.Color]::FromArgb(79, 122, 54))
$form.Controls.Add($btnMods)
$form.Controls.Add($btnPatch)

# 세 번째 칸은 서버마다 다르다. 엘리 서버는 접속 주소, 잔누 서버는 업데이트 내역.
$btnJoin = $null
$btnNews = $null
if ($ServerAddr) {
  $btnJoin = New-BigButton "서버 주소 복사" 212 ([System.Drawing.Color]::FromArgb(120, 96, 60))
  $form.Controls.Add($btnJoin)
} elseif ($NewsUrl) {
  $btnNews = New-BigButton "업데이트 내역 보기" 212 ([System.Drawing.Color]::FromArgb(88, 80, 120))
  $form.Controls.Add($btnNews)
}

# 버튼 오른쪽에 버전과 최신 여부를 적는다. 색으로 먼저 알아채게 한다.
function New-Stamp {
  $l           = New-Object System.Windows.Forms.Label
  $l.Location  = New-Object System.Drawing.Point(198, 4)
  $l.Size      = New-Object System.Drawing.Size(286, 44)
  $l.ForeColor = [System.Drawing.Color]::FromArgb(226, 236, 214)
  $l.BackColor = [System.Drawing.Color]::Transparent
  $l.TextAlign = "MiddleRight"
  $l.Font      = New-Object System.Drawing.Font("맑은 고딕", 8)
  return $l
}
$stampMods  = New-Stamp
$stampPatch = New-Stamp
$btnMods.Controls.Add($stampMods)
$btnPatch.Controls.Add($stampPatch)
# 글자가 버튼 위에 얹혀 있어서, 그냥 두면 글자를 누른 클릭을 버튼이 못 받는다.
# "몇 번 눌러야 겨우 되던" 이유였다. 글자 쪽 클릭을 버튼으로 넘겨준다.
$stampMods.Add_Click({ $btnMods.PerformClick() })
$stampPatch.Add_Click({ $btnPatch.PerformClick() })
$stampMods.Cursor  = "Hand"
$stampPatch.Cursor = "Hand"
$stampJoin = $null
if ($btnJoin) {
  $stampJoin = New-Stamp
  $btnJoin.Controls.Add($stampJoin)
  $stampJoin.Add_Click({ $btnJoin.PerformClick() })
  $stampJoin.Cursor = "Hand"
}
if ($btnNews) {
  $stampNews = New-Stamp
  $stampNews.Text = "디스코드 페이지로 연결됩니다."
  $btnNews.Controls.Add($stampNews)
  $stampNews.Add_Click({ $btnNews.PerformClick() })
  $stampNews.Cursor = "Hand"
}

# 맨 아래는 실행. 업데이트 → 실행 순서로 읽히게 둔다.
$btnRun = New-BigButton "마인크래프트 실행" 274 ([System.Drawing.Color]::FromArgb(58, 96, 92))
$form.Controls.Add($btnRun)
$stampRun = New-Stamp
$btnRun.Controls.Add($stampRun)
$stampRun.Add_Click({ $btnRun.PerformClick() })
$stampRun.Cursor = "Hand"

# 어디에 깔렸는지 확인하고 바꿀 수 있게. 잘못 고른 사람이 스스로 고칠 길이 필요하다.
function New-SmallButton($text, $x, $y, $w) {
  $b           = New-Object System.Windows.Forms.Button
  $b.Text      = $text
  $b.Location  = New-Object System.Drawing.Point($x, $y)
  $b.Size      = New-Object System.Drawing.Size($w, 26)
  $b.FlatStyle = "Flat"
  $b.BackColor = [System.Drawing.Color]::FromArgb(233, 231, 224)
  $b.ForeColor = [System.Drawing.Color]::FromArgb(70, 73, 67)
  $b.Font      = New-Object System.Drawing.Font("맑은 고딕", 8)
  $b.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(205, 202, 192)
  $b.Cursor    = "Hand"
  $b.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(221, 218, 209)
  $b.FlatAppearance.MouseDownBackColor = [System.Drawing.Color]::FromArgb(205, 202, 192)
  return $b
}
# 어디에 설치되는지 늘 보이게 한다. 안 보이면 "어디에 받는다는 거야?"가 된다.
$pathLbl           = New-Object System.Windows.Forms.Label
$pathLbl.Location  = New-Object System.Drawing.Point(25, 342)
$pathLbl.Size      = New-Object System.Drawing.Size(492, 22)
$pathLbl.ForeColor = [System.Drawing.Color]::FromArgb(90, 94, 86)
$pathLbl.Font      = New-Object System.Drawing.Font("맑은 고딕", 8)
$form.Controls.Add($pathLbl)

$toolY     = 372
$btnOpen   = New-SmallButton "설치된 폴더 열기" 24 $toolY 130
$btnChange = New-SmallButton "설치 위치 바꾸기" 160 $toolY 130
$btnLog    = New-SmallButton "기록 보기" 296 $toolY 96
$btnRestore = New-SmallButton "설정 되돌리기" 398 $toolY 124
$form.Controls.Add($btnOpen)
$form.Controls.Add($btnChange)
$form.Controls.Add($btnLog)
$form.Controls.Add($btnRestore)

$logY = 410

# 지금 뭘 하는 중인지 한 줄 + 얼마나 됐는지 막대. 글자가 쏟아지는 것보다 읽기 쉽다.
$statusLbl           = New-Object System.Windows.Forms.Label
$statusLbl.Text      = "버튼을 눌러주세요"
$statusLbl.Location  = New-Object System.Drawing.Point(24, $logY)
$statusLbl.Size      = New-Object System.Drawing.Size(492, 36)
$statusLbl.ForeColor = [System.Drawing.Color]::FromArgb(60, 64, 58)
$statusLbl.Font      = New-Object System.Drawing.Font("맑은 고딕", 9, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($statusLbl)

$bar          = New-Object System.Windows.Forms.ProgressBar
$bar.Location = New-Object System.Drawing.Point(24, ($logY + 38))
$bar.Size     = New-Object System.Drawing.Size(492, 18)
$bar.Style    = "Continuous"
$bar.Minimum  = 0; $bar.Maximum = 100; $bar.Value = 0
$form.Controls.Add($bar)

$hint           = New-Object System.Windows.Forms.Label
$hint.Text      = "다른 폴더에 설치 하시려면 Shift 버튼을 누른채 위의 버튼을 눌러주세요"
$hint.ForeColor = [System.Drawing.Color]::FromArgb(150, 153, 145)
$hint.Location  = New-Object System.Drawing.Point(25, ($logY + 64))
$hint.Size      = New-Object System.Drawing.Size(496, 18)
$form.Controls.Add($hint)

# 무슨 일이 있었는지 파일로 남긴다. 실패했을 때 "왜" 를 볼 수 있어야 한다.
$script:LogPath = Join-Path $env:TEMP ($Server + "-helper-log.txt")
function Log($t) {
  try { ((Get-Date -Format "HH:mm:ss") + "  " + $t) | Out-File $script:LogPath -Encoding UTF8 -Append } catch { }
}
Log "----- 도우미 시작 ($Server) -----"

function SetStep($text, $pct) {
  $statusLbl.Text = $text
  Log $text
  if ($pct -ge 0) { $bar.Value = [Math]::Min(100, [Math]::Max(0, [int]$pct)) }
  [System.Windows.Forms.Application]::DoEvents()
}
function Say($t) { SetStep $t -1 }

function Set-Busy($on) {
  foreach ($b in @($btnMods, $btnPatch, $btnJoin, $btnNews, $btnRun, $btnOpen, $btnChange, $btnLog, $btnRestore)) {
    if ($b) { $b.Enabled = -not $on }
  }
  $form.Cursor = if ($on) { "WaitCursor" } else { "Default" }
  [System.Windows.Forms.Application]::DoEvents()
}

# ── 내려받기 ──────────────────────────────────────────
# 창이 멈춘 것처럼 보이면 사람들이 강제 종료한다. 받는 동안에도 창이 살아 있도록
# 비동기로 받아두고 기다리는 동안 창을 계속 그려준다.
function Get-Web($url, $dest) {
  $wc = New-Object System.Net.WebClient
  $wc.Headers.Add("User-Agent", "elly-helper")
  $wc.Headers.Add("Cache-Control", "no-cache")
  try {
    $task = $wc.DownloadFileTaskAsync([Uri]$url, $dest)
    while (-not $task.IsCompleted) {
      Start-Sleep -Milliseconds 40
      [System.Windows.Forms.Application]::DoEvents()
    }
    if ($task.IsFaulted) { throw $task.Exception.GetBaseException() }
  } finally { $wc.Dispose() }
}
function Get-WebText($url) {
  $tmp = Join-Path $env:TEMP ("helper-" + [guid]::NewGuid().ToString("N") + ".txt")
  try {
    Get-Web $url $tmp
    return (Get-Content $tmp -Raw -Encoding UTF8)
  } finally { Remove-Item $tmp -ErrorAction SilentlyContinue }
}

# ── 마크가 켜져 있으면 안 된다 ────────────────────────
# 자바를 쓰는 프로그램은 많으므로(런처 포함) 명령줄로 마크인지 가린다.
# 명령줄을 못 읽으면 막지 않는다 — 괜히 못 하게 하는 편이 더 나쁘다.
function Test-MinecraftRunning {
  $r = @(Get-Process javaw, java -ErrorAction SilentlyContinue | Where-Object {
    try {
      $c = (Get-CimInstance Win32_Process -Filter "ProcessId=$($_.Id)" -ErrorAction SilentlyContinue).CommandLine
      $c -and ($c -match 'net\.minecraft\.client\.main\.Main|net\.fabricmc\.loader|--gameDir|\.minecraft')
    } catch { $false }
  })
  return ($r.Count -gt 0)
}

# ── 마크 폴더 찾기 / 고르기 ───────────────────────────
# options.txt 가 있다고 다 게임 폴더는 아니다. yosbr 같은 모드가 config 안에
# 똑같은 이름의 견본 파일을 두기 때문에, 진짜 게임 폴더인지 한 번 더 따진다.
function Test-GameDir([System.IO.DirectoryInfo]$d) {
  if ($d.FullName -match '\\config\\') { return $false }
  if ($d.FullName -match '\\\.fabric\\') { return $false }
  foreach ($sub in @("mods", "saves", "resourcepacks", "versions", "shaderpacks")) {
    if (Test-Path (Join-Path $d.FullName $sub)) { return $true }
  }
  return $false
}

function Find-Instances {
  $roots = @(
    "$env:USERPROFILE\curseforge\minecraft\Instances",
    "$env:APPDATA\ModrinthApp\profiles",
    "$env:APPDATA\PrismLauncher\instances",
    "$env:APPDATA\com.modrinth.theseus\profiles",
    "$env:USERPROFILE\Documents\MultiMC\instances"
  ) | Where-Object { Test-Path $_ }

  # 예전에는 런처 폴더 전체를 훑었는데, 모드가 수백 개면 파일이 수만 개라
  # 선택창이 뜨기까지 한참 걸렸다. 인스턴스는 늘 정해진 자리에 있으므로 거기만 본다.
  $found = @()
  foreach ($r in $roots) {
    $launcher = Split-Path (Split-Path $r -Parent) -Leaf
    foreach ($d in @(Get-ChildItem -Path $r -Directory -ErrorAction SilentlyContinue)) {
      foreach ($cand in @($d.FullName, (Join-Path $d.FullName "minecraft"), (Join-Path $d.FullName ".minecraft"))) {
        if (Test-Path (Join-Path $cand "options.txt")) {
          $dir = Get-Item $cand
          if (Test-GameDir $dir) { $found += [pscustomobject]@{ Dir = $dir; Launcher = $launcher } }
          break
        }
      }
    }
  }
  if ((Test-Path "$env:APPDATA\.minecraft\options.txt") -and (Test-GameDir (Get-Item "$env:APPDATA\.minecraft"))) {
    $found += [pscustomobject]@{ Dir = (Get-Item "$env:APPDATA\.minecraft"); Launcher = "기본 런처" }
  }
  # 같은 폴더가 두 번 잡히는 일이 없게 정리하고, 최근에 쓴 순서로 보여준다
  return @($found | Sort-Object { $_.Dir.FullName } -Unique |
           Sort-Object { (Get-Item (Join-Path $_.Dir.FullName "options.txt")).LastWriteTime } -Descending)
}

# 폴더 고르기. 런처 폴더를 통째로 훑으면 파일이 수만 개라 창이 한참 뒤에 떴다.
# 그래서 탐색기 창을 바로 띄우고, 고르신 폴더가 마크 폴더인지 그 자리에서 확인한다.
function Show-FolderPicker($caption) {
  $fb = New-Object System.Windows.Forms.FolderBrowserDialog
  $fb.Description = $caption + "  (mods 폴더가 들어있는 폴더를 골라주세요)"
  $fb.ShowNewFolderButton = $false
  foreach ($r in @(
      "$env:USERPROFILE\curseforge\minecraft\Instances",
      "$env:APPDATA\ModrinthApp\profiles",
      "$env:APPDATA\PrismLauncher\instances",
      "$env:USERPROFILE\Documents\MultiMC\instances",
      "$env:APPDATA\.minecraft")) {
    if (Test-Path $r) { $fb.SelectedPath = $r; break }
  }
  if ($fb.ShowDialog($form) -ne [System.Windows.Forms.DialogResult]::OK) { return $null }

  # 인스턴스 폴더를 고르시는 분이 많아서, 안쪽 minecraft 폴더까지 한 번 더 본다.
  $p = $fb.SelectedPath
  foreach ($cand in @($p, (Join-Path $p "minecraft"), (Join-Path $p ".minecraft"))) {
    if ((Test-Path (Join-Path $cand "mods")) -or (Test-Path (Join-Path $cand "options.txt"))) {
      return (Get-Item $cand).FullName
    }
  }
  [void][System.Windows.Forms.MessageBox]::Show(
    "고르신 폴더 안에 mods 폴더가 없습니다." + [Environment]::NewLine +
    "마인크래프트 폴더를 골라주세요." + [Environment]::NewLine + [Environment]::NewLine + $p,
    "설치 위치", "OK", "Warning")
  return $null
}

# 한 번 고른 곳을 기억해두고 다음부터는 묻지 않는다.
# Shift 를 누른 채 누르면 기억해둔 곳을 무시하고 다시 묻는다.
function Test-ShiftHeld {
  try { return ([System.Windows.Forms.Control]::ModifierKeys -band [System.Windows.Forms.Keys]::Shift) -ne 0 } catch { return $false }
}

# 기억해둔 설치 위치. 예전 판에서 따로 적어둔 것도 읽어준다.
function Get-SavedTarget {
  foreach ($f in @($MainRemember, $PackRemember, $PatchRemember)) {
    $c = Get-Content (Join-Path $env:APPDATA $f) -Encoding UTF8 -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($c -and (Test-Path $c)) { return $c }
  }
  return $null
}
function Save-Target($p) {
  foreach ($f in @($MainRemember, $PackRemember, $PatchRemember)) {
    try { $p | Set-Content (Join-Path $env:APPDATA $f) -Encoding UTF8 } catch { }
  }
}

function Get-Target($caption, $force) {
  if (-not $force) {
    $saved = Get-SavedTarget
    if ($saved) { return $saved }
  }
  $p = Show-FolderPicker $caption
  if ($p) { Save-Target $p }
  return $p
}

# ── 한글패치 설치 ─────────────────────────────────────
# 파일 이름을 늘 같게 두는 이유: 마크는 리소스팩을 "파일 이름"으로 기억해서,
# 이름이 버전마다 바뀌면 켜둔 설정이 풀려 매번 다시 켜야 한다.
# resourcePacks 줄 하나만 고친다. 목록의 맨 뒤에 있는 팩이 가장 우선이라,
#  - 새 한글패치를 맨 뒤(가장 우선)로 옮기고
#  - 예전 한글패치(Elly-Korean-Patch-v12, -v13, -Extra 등)는 켜진 목록에서만 뺀다. 파일은 지우지 않는다
# 다른 팩의 순서와 options.txt 의 다른 줄(단축키 포함)은 건드리지 않는다.
function Set-PatchOnTop([string]$line, [string]$patchName) {
  $cur = ($line -replace '^resourcePacks:', '').Trim()
  $items = @()
  # PowerShell 5.1 은 JSON 배열을 한 덩어리로 돌려준다. foreach 로 풀어야 항목별로 나온다
  try { $parsed = $cur | ConvertFrom-Json; $items = @(foreach ($x in $parsed) { [string]$x }) } catch { return $line }
  $mine = "file/" + $patchName
  $keep = @(); $dropped = @()
  foreach ($n in $items) {
    if ($n -eq $mine) { continue }
    if ($n -match '^file/Elly-Korean-Patch[-_ ].*\.zip$') { $dropped += $n; continue }
    $keep += $n
  }
  if ($dropped.Count -gt 0) { Log ("  예전 한글패치를 켜진 목록에서 뺌: " + ($dropped -join ", ")) }
  $all = @($keep) + @($mine)
  return 'resourcePacks:' + (ConvertTo-Json -InputObject ([string[]]$all) -Compress)
}

function Install-Patch {
  $force = Test-ShiftHeld
  Set-Busy $true
  try {
    # 한글패치는 켜둔 채로도 넣을 수 있다. 넣고 나서 F3 + T 를 누르면 바로 적용된다.
    $mcOn = Test-MinecraftRunning
    if ($mcOn) { SetStep "게임이 켜진 채로 받으시면 리소스팩을 직접 켜주셔야 할 수 있습니다." -1 }
    SetStep "설치할 곳을 확인하고 있습니다..." 5
    $target = Get-Target "한글패치를 어느 마인크래프트에 넣을까요?" $force
    if (-not $target) { SetStep "취소되었습니다." 0; return }

    SetStep "최신 한글패치를 받고 있습니다..." 15
    $tmp = Join-Path $env:TEMP "elly-patch-download.zip"
    Remove-Item $tmp -ErrorAction SilentlyContinue
    Get-Web $PatchUrl $tmp

    # 서명된 배포 목록의 해시와 같을 때만 넣는다
    $pe = $null
    try { $pe = (Get-Rel).files."Elly-Korean-Patch.zip" } catch { Log "  [배포 목록 확인 실패] $($_.Exception.Message)" }
    if (-not $pe -or (Rel-Sha256 $tmp) -ne ([string]$pe.sha256).ToLower()) {
      Remove-Item $tmp -ErrorAction SilentlyContinue
      SetStep "배포되지 않은 한글패치라 받지 않았습니다." 0
      Log "한글패치 해시가 배포 목록과 다름"
      return
    }

    # 받은 게 진짜 리소스팩인지 확인한다(깨진 파일을 넣으면 마크가 켜지다 만다)
    SetStep "받은 파일을 확인하고 있습니다..." 55
    $z = [System.IO.Compression.ZipFile]::OpenRead($tmp)
    $hasMeta   = ($z.Entries | Where-Object { $_.FullName -eq "pack.mcmeta" }).Count -gt 0
    $langCount = ($z.Entries | Where-Object { $_.Name -ieq "ko_kr.json" }).Count
    $z.Dispose()
    if (-not $hasMeta -or $langCount -eq 0) {
      Remove-Item $tmp -ErrorAction SilentlyContinue
      SetStep "받은 파일이 리소스팩이 아닙니다. 엘리에게 알려주세요." 0
      return
    }

    SetStep "리소스팩 폴더에 넣고 있습니다..." 70
    $rp = Join-Path $target "resourcepacks"
    if (-not (Test-Path $rp)) { New-Item -ItemType Directory -Path $rp -Force | Out-Null }

    # 옛날 본체 패치가 남아 있으면 치운다. 이름만 보고 지우면 부가팩(Extra)까지
    # 날아가므로, zip 을 열어 번역 줄 수를 보고 "본체인지"를 판단한다.
    $mainThreshold = [Math]::Max(50, [int]($langCount * 0.5))
    foreach ($o in @(Get-ChildItem $rp -Filter "*.zip" -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne $PatchName })) {
      try {
        $oz = [System.IO.Compression.ZipFile]::OpenRead($o.FullName)
        $oLang = ($oz.Entries | Where-Object { $_.Name -ieq "ko_kr.json" }).Count
        $oz.Dispose()
      } catch { continue }
      if ($oLang -ge $mainThreshold) { Remove-Item $o.FullName -Force -ErrorAction SilentlyContinue }
    }

    # 마크가 그 팩을 쓰는 중이면 파일을 붙들고 있어서 덮어쓸 수 없다.
    try {
      Copy-Item $tmp (Join-Path $rp $PatchName) -Force
    } catch {
      if ($mcOn) {
        SetStep "마인크래프트가 한글패치를 쓰는 중이라 바꿀 수 없습니다. 게임을 끄고 다시 눌러주세요." 0
      } else {
        SetStep "리소스팩 폴더에 넣지 못했습니다 — $($_.Exception.Message)" 0
      }
      return
    }
    Remove-Item $tmp -ErrorAction SilentlyContinue

    # options.txt 는 마크가 종료할 때 다시 쓴다. 켜져 있을 때 고치면 되돌아가므로 건드리지 않는다.
    if ($mcOn) {
      # 이미 켜 둔 적이 있으면 F3+T 로 끝나지만, 처음이면 리소스팩 목록에 없어서
      # 게임을 껐다 켜야 한다. 그 차이를 분명히 알려준다.
      $already = $false
      try {
        $optNow = Join-Path $target "options.txt"
        if (Test-Path $optNow) {
          $already = (([IO.File]::ReadAllText($optNow, [Text.Encoding]::UTF8)) -match [regex]::Escape($PatchName))
        }
      } catch { }
      if ($already) {
        SetStep "한글패치를 넣었습니다. 마인크래프트에서 F3 + T 를 누르시면 바로 적용됩니다. (번역 $langCount 개)" 100
      } else {
        # 게임이 켜져 있으면 리소스팩 목록을 건드릴 수 없다. 직접 켜는 길과
        # 자동으로 켜지는 길을 둘 다 알려드린다.
        SetStep ("한글패치를 넣었습니다. 게임이 켜진 채로 받으셔서 아직 적용되지 않았습니다." + [char]13 + [char]10 +
                 "설정 → 리소스팩 에서 [엘리 한글패치] 를 오른쪽으로 옮겨주세요. (게임을 끄고 다시 누르시면 자동으로 켜집니다)") 100
      }
      return
    }

    # 켜져 있지 않으면 설정에 추가해 준다(마크가 꺼져 있을 때만 안전하다)
    SetStep "마인크래프트 설정에서 켜고 있습니다..." 90
    $opt = Join-Path $target "options.txt"
    if (Test-Path $opt) {
      try {
        # 마크는 이 파일을 줄바꿈 \n 으로 읽는다. 윈도 방식(\r\n)으로 저장하면 값 끝에
        # 보이지 않는 \r 이 붙어서 lang(언어) 과 soundCategory(소리) 가 초기화돼 버린다.
        # 그래서 줄 단위 명령을 쓰지 않고 글자 그대로 읽고 쓴다.
        $raw  = [IO.File]::ReadAllText($opt, [Text.Encoding]::UTF8)
        $rows = $raw -split "`r?`n"
        $entry = '"file/' + $PatchName + '"'
        # resourcePacks 줄이 아예 없는 파일도 있다. 없으면 만들어 준다.
        if (-not ($rows | Where-Object { $_ -like 'resourcePacks:*' })) {
          $rows = @($rows) + @('resourcePacks:[]')
        }
        for ($k = 0; $k -lt $rows.Count; $k++) {
          if ($rows[$k] -like 'resourcePacks:*') {
            $rows[$k] = Set-PatchOnTop $rows[$k] $PatchName
            break
          }
        }
        # 줄바꿈이 이미 윈도 방식으로 바뀌어 있던 파일도 여기서 되돌려 놓는다.
        $out = $rows -join "`n"
        if ($out -ne $raw) {
          # 맨 처음 백업은 손대지 않는다. 덮어쓰면 "고치기 전 설정"을 영영 잃는다.
          if (-not (Test-Path "$opt.bak")) { [IO.File]::Copy($opt, "$opt.bak", $false) }
          [IO.File]::Copy($opt, "$opt.bak-latest", $true)
          [IO.File]::WriteAllText($opt, $out, (New-Object Text.UTF8Encoding($false)))
        }
      } catch { }
    }

    SetStep "한글패치 업데이트가 완료되었습니다. (번역 $langCount 개)" 100
  } catch {
    SetStep "문제가 생겼습니다 — $($_.Exception.Message)" 0; Log "  [오류] $($_.ScriptStackTrace)"
  } finally {
    Set-Busy $false
    Refresh-Stamps $true
  }
}

# ── 서버 모드 맞추기 ──────────────────────────────────
# 원칙: 직접 깔아두신 모드는 절대 지우지 않는다. 팩에 있는데 없는 것만 받아온다.
#
# 모드 목록은 팩 저장소를 통째로 zip 으로 한 번만 받아서 읽는다.
# 예전에는 모드마다 깃허브에 물어봤는데, 로그인 없이 시간당 60번 제한이라
# 곧바로 막혀서 "확인 실패"가 떴다.
#
# 팩에 들어 있는 모드 목록(파일 이름 + 받는 주소)을 돌려준다.
# 한 번 받아두면 창을 닫을 때까지 다시 받지 않는다.
# 이번에 어떤 모드를 어떤 파일 이름으로 깔았는지 적어둔다. 다음 업데이트 때
# 버전이 올라가면 이 기록을 보고 옛 파일을 지운다.
function Save-ModMap($mapFile, $want) {
  try {
    $o = @{}
    foreach ($w in $want) { if ($w.Key) { $o[$w.Key] = $w.File } }
    ($o | ConvertTo-Json -Compress) | Set-Content $mapFile -Encoding UTF8
  } catch { }
}

$script:packWanted = $null
function Get-PackWanted($refresh) {
  if ($script:packWanted -and -not $refresh) { return $script:packWanted }
  $work = Join-Path $env:TEMP ("pack-" + [guid]::NewGuid().ToString("N"))
  try {
    New-Item -ItemType Directory -Path $work -Force | Out-Null
    $packZip = Join-Path $work "pack.zip"
    if (-not $script:packRef) { $script:packRef = "refs/heads/main" }
    Get-Web "https://codeload.github.com/$PackRepo/zip/$($script:packRef)" $packZip
    [System.IO.Compression.ZipFile]::ExtractToDirectory($packZip, $work)

    $modsSrc = Get-ChildItem $work -Directory | ForEach-Object { Join-Path $_.FullName "mods" } |
               Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $modsSrc) { return $null }

    # .pw.toml 은 "이 모드를 어디서 받는지" 적힌 쪽지다. 안을 읽어야 파일명과 주소가 나온다.
    $want = @()
    foreach ($e in Get-ChildItem $modsSrc -File) {
      if ($e.Name -like "*.jar") {
        $want += [pscustomobject]@{ Key = $e.Name; File = $e.Name; Url = "https://raw.githubusercontent.com/$PackRepo/$($script:packRef)/mods/$($e.Name)" }
      } elseif ($e.Name -like "*.pw.toml") {
        $t = Get-Content $e.FullName -Raw -Encoding UTF8
        $fn  = [regex]::Match($t, '(?m)^\s*filename\s*=\s*"(.+)"').Groups[1].Value
        $url = [regex]::Match($t, '(?m)^\s*url\s*=\s*"(.+)"').Groups[1].Value
        if (-not $url) {
          $projId = [regex]::Match($t, '(?m)^\s*project-id\s*=\s*(\d+)').Groups[1].Value
          $fileId = [regex]::Match($t, '(?m)^\s*file-id\s*=\s*(\d+)').Groups[1].Value
          if ($projId -and $fileId) { $url = "https://www.curseforge.com/api/v1/mods/$projId/files/$fileId/download" }
        }
        if ($fn -and $url) { $want += [pscustomobject]@{ Key = $e.Name; File = $fn; Url = $url } }
      }
      [System.Windows.Forms.Application]::DoEvents()
    }
    if ($want.Count -eq 0) { return $null }
    $script:packWanted = $want
    return $want
  } finally {
    Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
  }
}

# 잔누 서버는 누누님이 만든 update.bat 으로 모드를 맞춘다. 그쪽이 버전이 올라간
# 옛 모드를 치워주고 비교 화면도 보여줘서, 우리가 따로 받는 것보다 안전하다.
# 인스턴스 폴더에 없으면 저장소에서 받아 넣어준다.
# 모드 jar 안의 fabric.mod.json 에 적힌 id. 파일 이름은 버전·날짜마다 바뀌지만 id 는 그대로다.
function Get-JarModId($path) {
  $z = $null
  try {
    $z = [System.IO.Compression.ZipFile]::OpenRead($path)
    $e = $z.GetEntry("fabric.mod.json")
    if (-not $e) { return $null }
    $sr = New-Object System.IO.StreamReader($e.Open(), [Text.Encoding]::UTF8)
    $t = $sr.ReadToEnd(); $sr.Close()
    try { $id = ($t | ConvertFrom-Json).id; if ($id) { return [string]$id } } catch { }
    $m = [regex]::Match($t, '"id"\s*:\s*"([^"]+)"')
    if ($m.Success) { return $m.Groups[1].Value }
    return $null
  } catch { return $null } finally { if ($z) { $z.Dispose() } }
}

# mod-sync 가 적어둔 packwiz.json 의 파일(= 팩이 관리하는 것)과 id 가 같은 다른 jar 를 옮긴다.
# 팩이 관리하지 않는 모드끼리는 건드리지 않는다. 지우지 않고 옮기기만 한다.
function Move-DuplicateMods($target) {
  $moved = @()
  try {
    $modsDir = Join-Path $target "mods"
    $pj = Join-Path $target "packwiz.json"
    if (-not (Test-Path -LiteralPath $pj)) { return $moved }
    $man = Get-Content -LiteralPath $pj -Raw -Encoding UTF8 | ConvertFrom-Json
    $packNames = @{}
    foreach ($pp in $man.cachedFiles.PSObject.Properties) {
      $loc = [string]$pp.Value.cachedLocation
      if ($loc) { $packNames[(Split-Path $loc -Leaf)] = $true }
    }
    $byId = @{}
    foreach ($n in $packNames.Keys) {
      $p = Join-Path $modsDir $n
      if ($n -like "*.jar" -and (Test-Path -LiteralPath $p)) { $id = Get-JarModId $p; if ($id) { $byId[$id] = $n } }
      [System.Windows.Forms.Application]::DoEvents()
    }
    foreach ($j in @(Get-ChildItem -LiteralPath $modsDir -Filter "*.jar" -File -ErrorAction SilentlyContinue)) {
      if ($packNames.ContainsKey($j.Name)) { continue }
      $id = Get-JarModId $j.FullName
      if (-not $id -or -not $byId.ContainsKey($id)) { continue }
      $keep = Join-Path $target "mods-중복보관"
      if (-not (Test-Path -LiteralPath $keep)) { [void][IO.Directory]::CreateDirectory($keep) }
      $to = Join-Path $keep $j.Name
      if (Test-Path -LiteralPath $to) { $to = Join-Path $keep ((Get-Date -Format "yyyyMMdd-HHmmss") + "-" + $j.Name) }
      [IO.File]::Move($j.FullName, $to); $moved += $j.Name
      Log "  중복이라 옮김: $($j.Name) → mods-중복보관 (같은 모드: $($byId[$id]))"
    }
  } catch { Log "  [중복 확인 실패] $($_.Exception.Message)" }
  return $moved
}

function Install-Mods {
  Set-Busy $true
  try {
    if (Test-MinecraftRunning) {
      SetStep "마인크래프트가 켜져 있습니다. 종료한 뒤 다시 눌러주세요." 0
      return
    }
    SetStep "설치할 곳을 확인하고 있습니다..." 5
    $target = Get-Target "$PackLabel 모드를 어느 마인크래프트에 맞출까요?" (Test-ShiftHeld)
    if (-not $target) { SetStep "취소되었습니다." 0; return }

    # 커스포지 인스턴스가 맞는지 — update.bat 이 그 표시를 보고 움직인다
    if (-not (Test-Path -LiteralPath (Join-Path $target "minecraftinstance.json"))) {
      SetStep "커스포지 인스턴스 폴더가 아닙니다. 설치 위치 바꾸기로 다시 골라주세요." 0
      Log "update.bat 못 씀 — minecraftinstance.json 없음: $target"
      return
    }

    # 누누님 update.bat 은 실행될 때마다 main 의 mod-sync.ps1 을 새로 받아 실행해서
    # 배포 시점에 고정할 수 없다. 그래서 elly 가 서명한 커밋의 mod-sync.ps1 을
    # 해시로 확인한 뒤 같은 커밋의 pack.toml 로 직접 실행한다.
    $j = $null
    try { $j = (Get-Rel).jannu } catch { Log "  [배포 목록 확인 실패] $($_.Exception.Message)" }
    if (-not $j -or -not $j.commit -or -not $j.files."mod-sync.ps1") {
      SetStep "배포 확인에 실패해 모드를 맞추지 않았습니다. 잠시 뒤 다시 해 주세요." 0
      return
    }
    SetStep "업데이트 도구를 확인하는 중입니다..." 20
    $sync = Join-Path $target "mod-sync.ps1"
    $raw  = "https://raw.githubusercontent.com/$PackRepo/$($j.commit)"
    try { Get-ReleaseFile $j "mod-sync.ps1" "$raw/mod-sync.ps1" $sync }
    catch {
      SetStep "배포되지 않은 업데이트 도구라 실행하지 않았습니다." 0
      Log "mod-sync.ps1 확인 실패: $($_.Exception.Message)"
      return
    }
    Log "mod-sync.ps1 확인됨 — 커밋 $($j.commit)"

    SetStep "비교 화면을 여는 중입니다. 열린 창에서 이어서 해주세요." 50
    $bar.Style = "Marquee"; $bar.MarqueeAnimationSpeed = 30
    $proc = Start-Process powershell -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-WindowStyle", "Hidden", "-File", "`"$sync`"", "-PackUrl", "$raw/pack.toml") -WorkingDirectory $target -WindowStyle Hidden -PassThru
    while (-not $proc.HasExited) {
      Start-Sleep -Milliseconds 400
      [System.Windows.Forms.Application]::DoEvents()
    }
    $bar.MarqueeAnimationSpeed = 0; $bar.Style = "Continuous"
    Log "mod-sync 끝남 (코드 $($proc.ExitCode))"
    # 팩에 jar 로 직접 들어간 모드는 이름이 바뀌면 옛 파일이 "내pc모드"로 남아 두 벌이 된다.
    # 같은 모드(같은 id)가 두 벌이면 팩이 적어둔 쪽만 남기고 나머지는 mods-중복보관 으로 옮긴다(지우지 않는다).
    SetStep "같은 모드가 두 벌 있는지 확인하고 있습니다..." 95
    $moved = @(Move-DuplicateMods $target)
    if ($moved.Count -gt 0) {
      SetStep "$PackLabel 모드 업데이트가 완료되었습니다. (겹치는 모드 $($moved.Count) 개를 mods-중복보관 으로 옮김)" 100
    } else {
      SetStep "$PackLabel 모드 업데이트가 완료되었습니다." 100
    }
  } catch {
    $bar.MarqueeAnimationSpeed = 0; $bar.Style = "Continuous"
    SetStep "문제가 생겼습니다 — $($_.Exception.Message)" 0
  } finally {
    Set-Busy $false
    Refresh-Stamps $true
  }
}

function Install-Mods-Old {
  $force = Test-ShiftHeld
  Set-Busy $true
  try {
    if (Test-MinecraftRunning) {
      SetStep "마인크래프트가 켜져 있습니다. 종료한 뒤 다시 눌러주세요." 0
      return
    }
    SetStep "설치할 곳을 확인하고 있습니다..." 3
    $target = Get-Target "$PackLabel 모드를 어느 마인크래프트에 맞출까요?" $force
    if (-not $target) { SetStep "취소되었습니다." 0; return }

    $modsDir = Join-Path $target "mods"
    if (-not (Test-Path $modsDir)) { New-Item -ItemType Directory -Path $modsDir -Force | Out-Null }

    # 호환이 안 맞아 일부러 안 올리고 두는 때가 있어서, 배포 선언 전에는 받지 않는다.
    if ($script:packLocked) {
      SetStep "아직 배포되지 않았습니다. 누누님이 배포를 완료하시면 받으실 수 있습니다." 0
      return
    }
    SetStep "서버 모드 목록을 받고 있습니다..." 8
    $want = Get-PackWanted $true
    if (-not $want) { SetStep "서버 모드 목록을 읽지 못했습니다. 잠시 뒤 다시 눌러주세요." 0; return }

    $have = @{}
    Get-ChildItem $modsDir -Filter "*.jar" -File -ErrorAction SilentlyContinue | ForEach-Object { $have[$_.Name] = $true }
    $missing = @($want | Where-Object { -not $have.ContainsKey($_.File) })

    # 지난번에 이 팩으로 뭘 깔았는지 적어둔 것. 모드 버전이 올라가면 파일 이름이 바뀌는데,
    # 옛 파일을 안 지우면 같은 모드가 두 벌 남아 마크가 아예 안 켜진다.
    $mapFile = Join-Path $env:APPDATA $ModMapName
    $oldMap = @{}
    try {
      if (Test-Path $mapFile) {
        $j = Get-Content $mapFile -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($pp in $j.PSObject.Properties) { $oldMap[$pp.Name] = $pp.Value }
      }
    } catch { }
    $cleaned = 0

    if ($missing.Count -eq 0) {
      Save-ModMap $mapFile $want
      SetStep "이미 최신입니다. 바로 들어가시면 됩니다. (서버 모드 $($want.Count)개)" 100
      return
    }

    $ok = 0; $fail = 0; $failNames = @(); $firstWhy = ""
    for ($i = 0; $i -lt $missing.Count; $i++) {
      $m = $missing[$i]
      SetStep ("모드를 받고 있습니다 — " + ($i + 1) + " / " + $missing.Count) (20 + ($i / $missing.Count) * 78)
      $dest = Join-Path $modsDir $m.File
      $part = "$dest.part"
      try {
        # 이름에 대괄호가 들어간 모드(예: "... [Fabric].jar")가 있다. 그냥 두면
        # PowerShell 이 대괄호를 와일드카드로 읽어서, 다 받아놓고 이름 바꾸는 데서 실패한다.
        if (Test-Path -LiteralPath $part) { [IO.File]::Delete($part) }
        Get-Web $m.Url $part
        # 받다 만 파일을 모드 폴더에 남기면 마크가 안 켜진다. 다 받은 뒤에만 이름을 바꾼다.
        if ((Get-Item -LiteralPath $part).Length -lt 1000) { throw "파일이 너무 작습니다" }
        if (Test-Path -LiteralPath $dest) { [IO.File]::Delete($dest) }
        [IO.File]::Move($part, $dest)
        $ok++
        # 같은 자리에 있던 옛 버전을 치운다. 직접 깔아두신 모드는 이 목록에 없어 건드리지 않는다.
        $prev = $oldMap[$m.Key]
        if ($prev -and $prev -ne $m.File) {
          $oldPath = Join-Path $modsDir $prev
          if (Test-Path -LiteralPath $oldPath) { [IO.File]::Delete($oldPath); $cleaned++ }
        }
      } catch {
        if (Test-Path -LiteralPath $part) { [IO.File]::Delete($part) }
        $fail++
        $why = $_.Exception.Message
        # 흔한 이유는 사람 말로 바꿔준다
        if ($why -match "404|NotFound") { $why = "서버에서 파일을 찾을 수 없습니다" }
        elseif ($why -match "timed out|시간") { $why = "시간이 초과되었습니다" }
        elseif ($why -match "403|Forbidden") { $why = "받을 권한이 없다고 합니다" }
        elseif ($why -match "너무 작") { $why = "파일이 제대로 받아지지 않았습니다" }
        elseif ($why -match "remote name|연결할 수 없|Unable to connect") { $why = "인터넷 연결이 끊겼습니다" }
        if ($fail -eq 1) { $firstWhy = $why }
        $failNames += $m.File
        Log "  [실패] $($m.File) — $($_.Exception.Message)"
      }
    }

    Save-ModMap $mapFile $want
    $cleanNote = if ($cleaned -gt 0) { " · 옛 버전 $cleaned 개 정리" } else { "" }
    if ($fail -gt 0) {
      SetStep "$PackLabel 모드 $ok 개 완료 · $fail 개 실패 — $firstWhy`r`n($($failNames[0])) 다시 누르시면 못 받은 것만 받습니다." 100
    } else {
      SetStep "$PackLabel 모드 업데이트가 완료되었습니다. ($ok 개$cleanNote)" 100
    }
  } catch {
    SetStep "문제가 생겼습니다 — $($_.Exception.Message)" 0; Log "  [오류] $($_.ScriptStackTrace)"
  } finally {
    Set-Busy $false
    Refresh-Stamps $true
  }
}

# ── 내 버전 / 서버 버전 ───────────────────────────────
# 한글패치 버전은 팩 안 pack.mcmeta 의 설명에 들어 있고(예: 엘리 한글패치 · 1.21.1 · 2026-09-23),
# 같은지 여부는 배포중인 zip 의 sha1 과 내 파일의 sha1 을 맞춰 본다.
function Get-ZipPackDate($zipPath) {
  try {
    $z = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
    $e = $z.Entries | Where-Object { $_.FullName -eq "pack.mcmeta" } | Select-Object -First 1
    $desc = $null
    if ($e) {
      $sr = New-Object System.IO.StreamReader($e.Open(), [Text.Encoding]::UTF8)
      $desc = ($sr.ReadToEnd() | ConvertFrom-Json).pack.description
      $sr.Close()
    }
    $z.Dispose()
    if ($desc -match '(\d{4}-\d{2}-\d{2})') { return $Matches[1] }
    return $desc
  } catch { return $null }
}

function Refresh-Stamps($keepMessage) {
  # 뭔가 하고 있다는 걸 알 수 있게. 조용히 멈춰 있으면 고장난 줄 안다.
  $stampPatch.Text = "확인 중..."
  $stampMods.Text  = "확인 중..."
  Log "상태 확인 시작"
  if (-not $keepMessage) {
    $statusLbl.Text = "불러오는 중입니다..."
    $bar.Style = "Marquee"
    $bar.MarqueeAnimationSpeed = 30
  }
  [System.Windows.Forms.Application]::DoEvents()

  # 지금 어디에 설치되는지 — 안 보이면 "어디에 받는다는 거야?"가 된다
  $tp = Get-SavedTarget
  if ($tp) {
    $pathLbl.Text = "설치 위치 : " + (Split-Path $tp -Leaf)
    $pathLbl.ForeColor = [System.Drawing.Color]::FromArgb(90, 94, 86)
  } else {
    $pathLbl.Text = "설치 위치가 정해지지 않았습니다. 버튼을 누르시면 고르실 수 있습니다."
    $pathLbl.ForeColor = [System.Drawing.Color]::FromArgb(186, 86, 76)
  }
  [System.Windows.Forms.Application]::DoEvents()

  # 한글패치
  try {
    $mine = $null
    $t = Get-SavedTarget
    $myZip = if ($t) { Join-Path $t "resourcepacks\$PatchName" } else { $null }
    if ($myZip -and (Test-Path $myZip)) { $mine = Get-ZipPackDate $myZip }

    $srvSha = (Get-WebText "$BASE/Elly-Korean-Patch.zip.sha1").Trim()
    $same = $false
    if ($myZip -and (Test-Path $myZip)) {
      $same = ((Get-FileHash $myZip -Algorithm SHA1).Hash.ToLower() -eq $srvSha.ToLower())
    }

    # 서버 쪽 날짜는 아직 안 받으신 분에게도 보여준다
    $srvVer = ""
    if (-not $same) {
      try {
        $tmpz = Join-Path $env:TEMP "patch-ver-check.zip"
        Get-Web $PatchUrl $tmpz
        $srvVer = Get-ZipPackDate $tmpz
        Remove-Item $tmpz -ErrorAction SilentlyContinue
      } catch { }
    }

    # 최신이면 초록, 아니면 빨강. 글자만 읽지 않고 색으로 먼저 알아채게 한다.
    if ($same) {
      $stampPatch.Text = "최근 업데이트 $mine`r`n최신 버전입니다"
      $stampPatch.ForeColor = $ColorGood
    } else {
      $stampPatch.Text = "최근 업데이트 $srvVer`r`n최신 버전이 아닙니다"
      $stampPatch.ForeColor = $ColorBad
    }
  } catch { $stampPatch.Text = "확인 실패"; $stampPatch.ForeColor = $ColorDim; Log "  [한글패치 확인 실패] $($_.Exception.Message)" }
  Log "  한글패치: $($stampPatch.Text -replace [char]13, ' / ' -replace [char]10, '')"

  # 서버 모드.
  #
  # 누누님이 저장소에 올렸다고 바로 받으면 안 된다. 호환이 안 맞아 일부러
  # 안 올리고 두는 때가 있어서, 디스코드에서 /배포완료 를 치신 그 시점의 팩만 받는다.
  # 봇이 그때의 커밋을 release.json 에 적어두고, 여기서는 그 커밋을 그대로 쓴다.
  $script:packRef = "refs/heads/main"
  $script:packLocked = $false
  $relNote = $null
  # 이제는 elly 가 서명한 배포 목록(manifest)의 잔누 커밋만 쓴다. 확인이 안 되면 잠근다.
  try {
    $j = (Get-Rel).jannu
    if ($j -and $j.commit) {
      $script:packRef = $j.commit
      if ($j.released_at) { $relNote = $j.released_at }
    } else {
      $script:packLocked = $true
    }
  } catch {
    Log "  [배포 목록 확인 실패] $($_.Exception.Message)"
    $script:packLocked = $true
  }

  try {
    if ($script:packLocked) {
      $stampMods.Text = "아직 배포되지 않았습니다`r`n누누님이 배포를 완료하면 열립니다"
      $stampMods.ForeColor = $ColorDim
      $btnMods.Enabled = $false
    } else {
      $btnMods.Enabled = $true
      $want = $script:packWanted
      if ($want) { $cnt = $want.Count }
      else {
        $idx = Get-WebText "https://raw.githubusercontent.com/$PackRepo/$($script:packRef)/index.toml"
        $cnt = ([regex]::Matches($idx, '(?m)^file\s*=\s*"mods/')).Count
      }
      if ($cnt -le 0) { throw "목록 없음" }
      $t2 = Get-SavedTarget
      if ($t2 -and (Test-Path (Join-Path $t2 "mods"))) {
        $have = @{}
        Get-ChildItem (Join-Path $t2 "mods") -Filter *.jar -File -ErrorAction SilentlyContinue | ForEach-Object { $have[$_.Name] = $true }
        # 파일 이름을 알면 정확히 세고, 모르면 개수로만 본다.
        if ($want) { $miss = @($want | Where-Object { -not $have.ContainsKey($_.File) }).Count }
        else { $miss = [Math]::Max(0, $cnt - $have.Count) }
        if ($miss -eq 0) {
          # 직접 깔아두신 모드가 있어 클라이언트 쪽이 더 많을 수 있다. 그건 문제가 아니다.
          $stampMods.Text = "서버 파일 $cnt 개 모두 일치`r`n클라이언트 파일 $($have.Count) 개 · 최신 버전입니다"
          $stampMods.ForeColor = $ColorGood
        } else {
          $stampMods.Text = "서버 파일 $cnt 개 중 $miss 개 없음`r`n클라이언트 파일 $($have.Count) 개 · 최신 버전이 아닙니다"
          $stampMods.ForeColor = $ColorBad
        }
      } else {
        $stampMods.Text = "서버 파일 $cnt 개`r`n설치 위치를 정하면 확인됩니다"
        $stampMods.ForeColor = $ColorDim
      }
    }
  } catch { $stampMods.Text = "확인 실패"; $stampMods.ForeColor = $ColorDim; Log "  [모드 확인 실패] $($_.Exception.Message)" }
  Log "  모드: $($stampMods.Text -replace [char]13, ' / ' -replace [char]10, '')"
  Log "  설치 위치: $tp"

  # 서버가 켜져 있는지
  try {
    $c = New-Object System.Net.Sockets.TcpClient
    $ar = $c.BeginConnect($PingHost, $PingPort, $null, $null)
    $up = $ar.AsyncWaitHandle.WaitOne(2500, $false) -and $c.Connected
    $c.Close()
    if ($up) {
      $srvLbl.Text = "서버상태 : ON"
      $srvLbl.ForeColor = [System.Drawing.Color]::FromArgb(62, 140, 62)
    } else {
      $srvLbl.Text = "서버상태 : OFF"
      $srvLbl.ForeColor = [System.Drawing.Color]::FromArgb(186, 86, 76)
    }
    if ($stampJoin) {
      $stampJoin.Text = if ($up) { "$ServerAddr" } else { "$ServerAddr`r`n디스코드에서 /서버켜기" }
    }
  } catch {
    $srvLbl.Text = ""
    if ($stampJoin) { $stampJoin.Text = "" }
  }

  # 실행 버튼은 깔려 있는 런처에 맞춰 이름을 바꾼다. "커스포지 실행" 이라고 적혀 있으면
  # 뭐가 열릴지 누르기 전에 안다.
  if ($btnRun) {
    $lc = $null
    try { $lc = Find-Launcher (Get-SavedTarget) } catch { }
    if ($lc -and $lc.Kind -eq "prism") {
      $btnRun.Text = "마인크래프트 실행"
      $stampRun.Text = "바로 실행됩니다"
    } elseif ($lc) {
      $btnRun.Text = "$($lc.Name) 실행"
      $stampRun.Text = "인스턴스에서 [플레이] 를 눌러주세요"
    } else {
      $btnRun.Text = "마인크래프트 실행"
      $stampRun.Text = ""
    }
    $stampRun.ForeColor = $ColorDim
  }

  if (-not $keepMessage) {
    $bar.MarqueeAnimationSpeed = 0
    $bar.Style = "Continuous"
    $bar.Value = 0
    $statusLbl.Text = "버튼을 눌러주세요"
  }
  [System.Windows.Forms.Application]::DoEvents()
}

# ── 마인크래프트 실행 ─────────────────────────────────
# 런처마다 사정이 다르다. 프리즘·멀티MC 는 인스턴스를 지정해서 바로 켤 수 있지만,
# 커스포지는 "이 인스턴스를 켜라" 는 길을 안 열어놔서 앱까지만 열어드린다.
function Find-Launcher($target) {
  $t = "$target".ToLower()
  if ($t -like "*prismlauncher*" -or $t -like "*\prism*") {
    foreach ($e in @("$env:LOCALAPPDATA\Programs\PrismLauncher\prismlauncher.exe", "$env:PROGRAMFILES\PrismLauncher\prismlauncher.exe")) {
      if (Test-Path $e) { return @{ Kind = "prism"; Exe = $e } }
    }
  }
  if ($t -like "*multimc*") {
    $e = "$env:USERPROFILE\Documents\MultiMC\MultiMC.exe"
    if (Test-Path $e) { return @{ Kind = "prism"; Exe = $e } }
  }
  if ($t -like "*modrinth*") {
    $e = "$env:LOCALAPPDATA\Programs\Modrinth App\Modrinth App.exe"
    if (Test-Path $e) { return @{ Kind = "app"; Exe = $e; Name = "모드린스" } }
  }
  if ($t -like "*curseforge*") {
    $e = "$env:LOCALAPPDATA\Programs\CurseForge Windows\CurseForge.exe"
    if (Test-Path $e) { return @{ Kind = "app"; Exe = $e; Name = "CurseForge" } }
    return @{ Kind = "proto"; Exe = "curseforge://"; Name = "CurseForge" }
  }
  return $null
}

function Start-Minecraft {
  if (Test-MinecraftRunning) { Say "마인크래프트가 이미 켜져 있습니다."; return }
  $target = Get-SavedTarget
  if (-not $target) { Say "설치 위치를 먼저 정해주세요. 위의 버튼을 누르시면 고르실 수 있습니다."; return }

  $lc = Find-Launcher $target
  if (-not $lc) { Say "런처를 찾지 못했습니다. 평소 쓰시는 런처에서 직접 실행해 주세요."; return }
  try {
    if ($lc.Kind -eq "prism") {
      # 인스턴스 폴더 이름이 곧 인스턴스 이름이다(.minecraft 안쪽이면 한 칸 위)
      $inst = Split-Path $target -Leaf
      if ($inst -eq "minecraft" -or $inst -eq ".minecraft") { $inst = Split-Path (Split-Path $target -Parent) -Leaf }
      Start-Process $lc.Exe -ArgumentList @("--launch", $inst)
      Say "마인크래프트를 실행합니다. 잠시만 기다려 주세요."
    } else {
      Start-Process $lc.Exe
      Say "$($lc.Name) 를 열었습니다. 인스턴스에서 [플레이] 를 눌러주세요."
    }
  } catch { Say "실행하지 못했습니다. 런처에서 직접 켜주세요." }
}


# 설정을 되돌린다. 한글패치가 설정을 건드리기 전 파일을 백업해 두므로,
# 그것을 골라 되돌리면 언어·소리·조작키가 한꺼번에 돌아온다.
function Restore-Options {
  if (Test-MinecraftRunning) { Say "마인크래프트가 켜져 있습니다. 종료한 뒤 다시 눌러주세요."; return }
  $t = Get-SavedTarget
  if (-not $t) { Say "설치 위치를 먼저 정해주세요."; return }
  $opt = Join-Path $t "options.txt"
  $all = @(Get-ChildItem $t -Filter "options.txt*" -File -ErrorAction SilentlyContinue)
  Log "되돌리기: $t 에서 찾은 파일 — " + (($all | ForEach-Object { $_.Name + "(" + $_.Length + "B)" }) -join ", ")
  $baks = @($all | Where-Object { $_.Name -ne "options.txt" -and $_.Length -gt 200 } | Sort-Object LastWriteTime -Descending)
  if ($baks.Count -eq 0) {
    Say "되돌릴 백업이 없습니다. 기록 보기를 눌러 나오는 내용을 서버장에게 보내주세요."
    return
  }

  $dlg                 = New-Object System.Windows.Forms.Form
  $dlg.Text            = "설정 되돌리기"
  $dlg.Size            = New-Object System.Drawing.Size(560, 360)
  $dlg.StartPosition   = "CenterParent"
  $dlg.FormBorderStyle = "FixedDialog"
  $dlg.MaximizeBox = $false; $dlg.MinimizeBox = $false
  $dlg.BackColor       = [System.Drawing.Color]::FromArgb(246, 245, 241)
  $dlg.Font            = New-Object System.Drawing.Font("맑은 고딕", 9)
  $dlg.Icon            = $form.Icon

  $lb = New-Object System.Windows.Forms.Label
  $lb.Text = "어느 시점으로 되돌릴까요?"
  $lb.Location = New-Object System.Drawing.Point(18, 16)
  $lb.Size = New-Object System.Drawing.Size(500, 20)
  $lb.Font = New-Object System.Drawing.Font("맑은 고딕", 9, [System.Drawing.FontStyle]::Bold)
  $dlg.Controls.Add($lb)

  $lb2 = New-Object System.Windows.Forms.Label
  $lb2.Text = "언어, 소리 크기, 조작키가 그 시점으로 한꺼번에 돌아갑니다."
  $lb2.Location = New-Object System.Drawing.Point(18, 38)
  $lb2.Size = New-Object System.Drawing.Size(500, 20)
  $lb2.ForeColor = [System.Drawing.Color]::FromArgb(120, 124, 115)
  $dlg.Controls.Add($lb2)

  $list = New-Object System.Windows.Forms.ListBox
  $list.Location = New-Object System.Drawing.Point(18, 64)
  $list.Size = New-Object System.Drawing.Size(508, 190)
  $list.IntegralHeight = $false
  foreach ($b in $baks) {
    $keys = 0
    try { foreach ($ln in (([IO.File]::ReadAllText($b.FullName, [Text.Encoding]::UTF8)) -split "`r?`n")) { if ($ln -like "key_*" -and $ln -notlike "*unknown") { $keys++ } } } catch { }
    [void]$list.Items.Add(("{0:yyyy-MM-dd HH:mm}   ·   조작키 {1}개   ·   {2}" -f $b.LastWriteTime, $keys, $b.Name))
  }
  $list.SelectedIndex = 0
  $dlg.Controls.Add($list)

  $script:restorePick = $null
  $ok = New-Object System.Windows.Forms.Button
  $ok.Text = "이걸로 되돌리기"; $ok.Location = New-Object System.Drawing.Point(300, 268)
  $ok.Size = New-Object System.Drawing.Size(130, 32); $ok.FlatStyle = "Flat"
  $ok.BackColor = [System.Drawing.Color]::FromArgb(70, 96, 130); $ok.ForeColor = [System.Drawing.Color]::White
  $ok.Add_Click({ $script:restorePick = $list.SelectedIndex; $dlg.Close() })
  $dlg.Controls.Add($ok)
  $no = New-Object System.Windows.Forms.Button
  $no.Text = "취소"; $no.Location = New-Object System.Drawing.Point(438, 268)
  $no.Size = New-Object System.Drawing.Size(88, 32); $no.FlatStyle = "Flat"
  $no.Add_Click({ $script:restorePick = $null; $dlg.Close() })
  $dlg.Controls.Add($no)
  $dlg.CancelButton = $no
  [void]$dlg.ShowDialog($form)
  $dlg.Dispose()

  if ($script:restorePick -eq $null) { Say "되돌리지 않았습니다."; return }
  $pick = $baks[$script:restorePick]
  try {
    # 지금 상태도 한 번 남겨둔다. 되돌린 게 마음에 안 들 수도 있다.
    [IO.File]::Copy($opt, "$opt.bak-되돌리기전", $true)
    $txt = [IO.File]::ReadAllText($pick.FullName, [Text.Encoding]::UTF8)
    if ($txt.Length -gt 0 -and $txt[0] -eq [char]0xFEFF) { $txt = $txt.Substring(1) }
    $txt = ($txt -split "`r?`n") -join "`n"
    [IO.File]::WriteAllText($opt, $txt, (New-Object Text.UTF8Encoding($false)))
    Log "설정 되돌림: $($pick.Name)"
    Say "$($pick.LastWriteTime.ToString('MM월 dd일 HH:mm')) 시점으로 되돌렸습니다. 마인크래프트를 켜서 확인해 주세요."
  } catch { Say "되돌리지 못했습니다 — $($_.Exception.Message)" }
}

# ── 실행 파일 돌보기 ──────────────────────────────────
# .bat 은 아이콘을 가질 수 없어서, 아이콘 붙은 바로가기를 대신 만들어 둔다.
# 그리고 .bat 자체가 낡았으면 새것으로 갈아끼운다. 그래야 친구들이 파일을
# 다시 받으러 다니지 않아도 된다. (.bat 은 이미 제 할 일을 끝내고 닫혔다)
# 예전 실행 파일은 자기 경로를 알려주지 않는다. 그럴 땐 흔히 두는 자리에서
# 우리 실행 파일을 직접 찾아본다. 그래야 예전 것을 받아 둔 사람도 갱신된다.
function Find-Launcher-File {
  $spots = @(
    [Environment]::GetFolderPath("Desktop"),
    (Join-Path $env:USERPROFILE "Desktop"),
    (Join-Path $env:USERPROFILE "Downloads"),
    (Join-Path $env:APPDATA $AppHome)
  ) | Where-Object { $_ -and (Test-Path $_) } | Sort-Object -Unique
  foreach ($d in $spots) {
    foreach ($b in @(Get-ChildItem $d -Filter "*.bat" -File -ErrorAction SilentlyContinue)) {
      try {
        $t = [IO.File]::ReadAllText($b.FullName, [Text.Encoding]::UTF8)
        # 예전 실행 파일은 주소를 %BASE%/gui-elly.ps1 처럼 나눠 적었다. 합쳐진 주소만 찾으면 못 알아본다
        if ($t -match "elly-korean-patch" -and $t -match ("/" + [regex]::Escape($GuiFileName) + '"')) { return $b.FullName }
      } catch { }
    }
  }
  return $null
}

function Tend-Launcher {
  if (-not $Launcher) { $Launcher = Find-Launcher-File }
  if (-not $Launcher) { return }
  if (-not (Test-Path -LiteralPath $Launcher)) { return }
  try {
    $home2 = Join-Path $env:APPDATA $AppHome
    if (-not (Test-Path $home2)) { [void][IO.Directory]::CreateDirectory($home2) }

    # 1) 아이콘
    $ico = Join-Path $home2 "icon.ico"
    if (-not (Test-Path -LiteralPath $ico)) {
      try { Get-ReleaseFile (Get-Rel) $IconFile "$BASE/$IconFile" $ico; Log "아이콘 받음" } catch { Log "아이콘 받기 실패: $($_.Exception.Message)" }
    }

    # 2) 바탕화면 바로가기 — 바탕화면 위치는 윈도우에 물어본다(원드라이브를 쓰면 다르다)
    $desk = [Environment]::GetFolderPath("Desktop")
    if ($desk -and (Test-Path -LiteralPath $ico)) {
      $lnk = Join-Path $desk ($AppName + ".lnk")
      if (-not (Test-Path -LiteralPath $lnk)) {
        $sh = New-Object -ComObject WScript.Shell
        $sc = $sh.CreateShortcut($lnk)
        $sc.TargetPath = $Launcher
        $sc.WorkingDirectory = (Split-Path $Launcher -Parent)
        $sc.IconLocation = $ico
        $sc.Description = $AppName
        $sc.Save()
        Log "바탕화면 바로가기 만듦"
      }
    }

    # 3) 확인 실행기(loader)와 실행 파일을 서명된 배포 목록과 맞춘다.
    #    목록의 해시와 같은 것만 넣고, 확인이 안 되면 아무것도 바꾸지 않는다.
    #    loader 를 먼저 넣어야 새 실행 파일이 그것을 찾을 수 있다.
    try {
      $m = Get-Rel
      $ld = Join-Path $home2 "loader.ps1"
      if (-not (Test-Path -LiteralPath $ld) -or (Rel-Sha256 $ld) -ne ([string]$m.files."loader.ps1".sha256).ToLower()) {
        Get-ReleaseFile $m "loader.ps1" "$BASE/loader.ps1" $ld
        Log "확인 실행기를 넣음"
      }
      if ((Rel-Sha256 $Launcher) -ne ([string]$m.files.$LauncherFile.sha256).ToLower()) {
        $latest = Join-Path $home2 "latest.bat"
        Get-ReleaseFile $m $LauncherFile "$BASE/$LauncherFile" $latest
        [IO.File]::Copy($Launcher, "$Launcher.bak", $true)
        [IO.File]::Copy($latest, $Launcher, $true)
        Log "실행 파일을 새것으로 바꿈"
      }
    } catch { Log "실행 파일 확인 실패: $($_.Exception.Message)" }
  } catch { Log "실행 파일 돌보기 실패: $($_.Exception.Message)" }
}
# ── 버튼 연결 ─────────────────────────────────────────
# 실행 버튼에서 오류가 나도 도우미 창은 살아 있어야 한다. 무엇이 났는지는 기록에 남긴다
$btnRun.Add_Click({
  Log "실행 버튼 누름"
  try { Start-Minecraft; Log "실행 버튼 처리 끝" }
  catch { Log "  [실행 오류] $($_.Exception.Message)"; Say "실행하지 못했습니다. 기록 보기를 눌러 나오는 내용을 서버장에게 보내주세요." }
})
$btnMods.Add_Click({ Install-Mods })
$btnPatch.Add_Click({ Install-Patch })

if ($btnJoin) {
  $btnJoin.Add_Click({
    try {
      Set-Clipboard -Value $ServerAddr
      Say "주소를 복사했습니다. 마인크래프트 → 멀티플레이 → 서버 추가 에 붙여넣어 주세요."
    } catch { Say "복사하지 못했습니다. 직접 입력해 주세요: $ServerAddr" }
  })
}

if ($btnNews) {
  $btnNews.Add_Click({
    # 디스코드 앱이 깔려 있으면 앱으로 연다. 없을 때만 브라우저로 간다.
    # discord:// 를 윈도우가 알고 있는지 먼저 확인한다.
    $hasApp = $false
    try { $hasApp = Test-Path "Registry::HKEY_CLASSES_ROOT\discord" } catch { }
    if (-not $hasApp) { try { $hasApp = Test-Path "Registry::HKEY_CURRENT_USER\Software\Classes\discord" } catch { } }
    $first  = if ($hasApp) { $NewsWeb } else { $NewsUrl }
    $second = if ($hasApp) { $NewsUrl } else { $NewsWeb }
    try {
      Start-Process $first
      Say "업데이트 내역을 열었습니다."
    } catch {
      try {
        Start-Process $second
        Say "업데이트 내역을 열었습니다."
      } catch { Say "열지 못했습니다. 디스코드의 서버-업데이트 채널을 확인해 주세요." }
    }
  })
}

$btnRestore.Add_Click({ Restore-Options })

$btnLog.Add_Click({
  # 뭐가 어디서 어긋났는지 직접 볼 수 있게. 물어보실 때 이 파일만 보내주시면 된다.
  if (-not (Test-Path $script:LogPath)) { Say "아직 기록이 없습니다."; return }
  try {
    Start-Process -FilePath "notepad.exe" -ArgumentList "`"$($script:LogPath)`""
    Say "기록을 열었습니다."
  } catch {
    try { Invoke-Item $script:LogPath; Say "기록을 열었습니다." }
    catch { Say "열지 못했습니다. 이 파일을 열어주세요: $($script:LogPath)" }
  }
})

$btnOpen.Add_Click({
  $p = Get-SavedTarget
  if (-not $p) { Say "아직 설치하신 곳이 없습니다. 먼저 위의 버튼을 눌러주세요."; return }
  Start-Process explorer.exe $p
  Say "설치된 폴더를 열었습니다."
})

$btnChange.Add_Click({
  # 탐색기에서 직접 고를 수 있게 같은 창을 쓴다. 고른 곳을 두 가지 모두에 적용한다.
  $p = Show-FolderPicker "앞으로 어느 마인크래프트에 설치할까요?"
  if (-not $p) { Say "설치 위치를 바꾸지 않았습니다."; return }
  Save-Target $p
  Say "설치 위치를 바꿨습니다 : $(Split-Path $p -Leaf)"
  Refresh-Stamps $true
})

$form.Add_Shown({ Tend-Launcher; Refresh-Stamps $false; if ($Notice) { Say $Notice } })
[void]$form.ShowDialog()
