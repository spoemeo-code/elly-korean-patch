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
  [string]$Server = "elly",
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
$AppHome      = "elly-helper"
$IconFile     = "elly-icon.ico"
$LauncherFile = "elly-helper.bat"
$GuiFileName  = "gui-elly.ps1"
# 관리자 기능은 암호를 한 번 넣어 열어둔 PC 에서만 나타난다.
# 암호 자체가 아니라 지문만 넣어 두므로, 이 파일을 봐도 암호는 알 수 없다.
$AdminMark    = Join-Path (Join-Path $env:APPDATA "elly-helper") "admin.txt"
$AdminHash    = "35d7c71e808dcd78cb92bcebee80c139501b3cc2e5cee9c2aad2f91324991f96"
$IsAdmin      = Test-Path -LiteralPath $AdminMark
function Get-Fingerprint($text) {
  $h = [Security.Cryptography.SHA256]::Create().ComputeHash([Text.Encoding]::UTF8.GetBytes($text))
  return ([BitConverter]::ToString($h)).Replace("-", "").ToLower()
}
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
  $MainRemember  = "elly-mc-target.txt"
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
# 한 번 확인한 목록은 창이 떠 있는 동안 다시 받지 않는다
$script:RelM = $null
function Get-Rel {
  if (-not $script:RelM) { $script:RelM = Get-ReleaseManifest }
  return $script:RelM
}

# ── 휴대용(USB) ──────────────────────────────────────
# USB 의 시작 파일이 ELLY_PORTABLE_ROOT 로 자기 폴더를 알려준다. 그러면 설치 위치와 프리즘을
# USB 안 것으로 고정하고, 남의 PC 에 바로가기 같은 흔적을 남기지 않는다.
$PortableRoot = $null
if ($env:ELLY_PORTABLE_ROOT -and (Test-Path -LiteralPath (Join-Path $env:ELLY_PORTABLE_ROOT "prism\portable.txt"))) { $PortableRoot = $env:ELLY_PORTABLE_ROOT }
# 휴대용이면 기록·임시 파일도 USB 안에만 쓴다(남의 PC 에 흔적을 남기지 않게). 여기서 띄우는 프리즘·자바도 이 값을 물려받는다.
if ($PortableRoot) {
  $ptmp = Join-Path $PortableRoot "helper\temp"
  try { [void][IO.Directory]::CreateDirectory($ptmp); $env:TEMP = $ptmp; $env:TMP = $ptmp } catch { }
}

# ── 창 (WPF) ─────────────────────────────────────────
# 둥근 카드와 도트 그림을 쓰려고 WPF 로 그린다. 동작(설치·실행·켜기)은 예전 그대로이고
# 겉모습만 바뀌었다. 예전 코드가 쓰던 이름(Text, Enabled, ForeColor, PerformClick)은
# 아래 "예전 이름 맞춰 주기" 에서 그대로 쓸 수 있게 붙여 둔다.
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

function Brush($hex) { return (New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.ColorConverter]::ConvertFromString($hex))) }
function Brush-Of([System.Drawing.Color]$c) { return (New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromArgb($c.A, $c.R, $c.G, $c.B))) }
$UiFont = New-Object System.Windows.Media.FontFamily("맑은 고딕")

# 예전 글자색은 어두운 버튼 위에 얹는 밝은 색이었다. 밝은 카드 위에서는 읽히지 않아서 짝을 바꿔 준다.
$ColorSwap = @{
  "150,235,140" = "#2F7D3A"   # 최신
  "255,150,140" = "#B8473B"   # 갱신 필요
  "210,210,205" = "#7C766A"   # 확인 실패·안내
  "226,236,214" = "#7C766A"
}
function Swap-Color($c) {
  if ($c -is [System.Drawing.Color]) {
    $k = "$($c.R),$($c.G),$($c.B)"
    if ($ColorSwap.ContainsKey($k)) { return (Brush $ColorSwap[$k]) }
    return (Brush-Of $c)
  }
  return $c
}

# 그림: elly-helper\assets 에 있으면 그걸 쓰고, 없으면 임시 도형을 그린다.
# 그림을 준비하는 동안 남길 기록. 아래에서 같은 이름으로 다시 정의되지만 경로와 형식은 같다.
$script:LogPath = Join-Path $env:TEMP ($Server + "-helper-log.txt")
function Log($t) {
  try { ((Get-Date -Format "HH:mm:ss") + "  " + $t) | Out-File $script:LogPath -Encoding UTF8 -Append } catch { }
}
$AssetDir = Join-Path (Join-Path $env:APPDATA $AppHome) "assets"
if ($env:ELLY_ASSET_DIR) { $AssetDir = $env:ELLY_ASSET_DIR }

# 그림 묶음(elly-helper-assets.zip)은 서명된 배포 목록에 들어 있다. loader 가 방금 확인해 둔 manifest 로
# 기대하는 해시를 알고, 가진 묶음이 다르면 받아서 해시가 맞을 때만 푼다.
# 목록에 없거나, 못 받거나, 해시가 틀리면 그림 없이(단색 카드) 뜬다.
function Sync-Assets {
  if ($env:ELLY_ASSET_DIR) { return }
  try {
    $cm = Join-Path $RelDir "manifest.json"; $cs = Join-Path $RelDir "manifest.sig"
    if (-not (Test-Path -LiteralPath $cm) -or -not (Test-Path -LiteralPath $cs)) { return }
    $bytes = [IO.File]::ReadAllBytes($cm)
    if (-not (Rel-Verify $bytes ([IO.File]::ReadAllText($cs)))) { Log "  [그림] 확인된 목록의 서명이 맞지 않아 그림 없이 엽니다"; return }
    $m = [Text.Encoding]::UTF8.GetString($bytes).TrimStart([char]0xFEFF) | ConvertFrom-Json
    $e = $m.files."elly-helper-assets.zip"
    if (-not $e) { return }
    $want = ([string]$e.sha256).ToLower()
    $mark = Join-Path $AssetDir ".sha256"
    if ((Test-Path -LiteralPath $mark) -and ([IO.File]::ReadAllText($mark).Trim() -eq $want)) { return }
    $zip = Join-Path $RelHome "assets-download.zip"
    # 받는 곳을 바꿔도(시험용) 서명 목록의 해시와 같을 때만 쓴다
    $ab = if ($env:ELLY_ASSET_BASE) { $env:ELLY_ASSET_BASE } else { $BASE }
    Get-ReleaseFile $m "elly-helper-assets.zip" "$ab/elly-helper-assets.zip" $zip
    $new = "$AssetDir.new"
    if (Test-Path -LiteralPath $new) { [IO.Directory]::Delete($new, $true) }
    [void][IO.Directory]::CreateDirectory($new)
    $z = [System.IO.Compression.ZipFile]::OpenRead($zip)
    try {
      foreach ($en in $z.Entries) {
        if (-not $en.Name) { continue }
        # 그림과 테마 목록만 푼다. 폴더 밖을 가리키는 이름은 건너뛴다
        $fn = [string]$en.FullName
        if ($fn.Contains("..") -or $fn.StartsWith("/") -or $fn.StartsWith("\") -or $fn.Contains(":")) { continue }
        if (-not ($fn.EndsWith(".png") -or $fn.EndsWith(".json"))) { continue }
        $to = Join-Path $new $fn.Replace("/", "\")
        [void][IO.Directory]::CreateDirectory((Split-Path $to -Parent))
        [System.IO.Compression.ZipFileExtensions]::ExtractToFile($en, $to, $true)
      }
    } finally { $z.Dispose() }
    [IO.File]::WriteAllText((Join-Path $new ".sha256"), $want)
    if (Test-Path -LiteralPath $AssetDir) { [IO.Directory]::Delete($AssetDir, $true) }
    [IO.Directory]::Move($new, $AssetDir)
    [IO.File]::Delete($zip)
    Log "  [그림] 새 그림 묶음을 받았습니다"
  } catch { Log "  [그림] 그림 묶음을 받지 못해 그림 없이 엽니다 — $($_.Exception.Message)" }
}
Sync-Assets

# 이벤트 테마: 묶음 안 themes.json 의 기간(월-일)에 오늘이 들어가면 themes\<이름>\ 의 그림을 먼저 쓴다.
# 그 폴더에 없는 그림은 기본 그림을 쓴다.
$ThemeDir = $null
try {
  $tj = Join-Path $AssetDir "themes.json"
  if (Test-Path -LiteralPath $tj) {
    $today = (Get-Date).ToString("MM-dd")
    if ($env:ELLY_THEME_DATE) { $today = $env:ELLY_THEME_DATE }
    foreach ($th in @(([IO.File]::ReadAllText($tj, [Text.Encoding]::UTF8) | ConvertFrom-Json).themes)) {
      $f = [string]$th.from; $u = [string]$th.to
      $in = if ($f -le $u) { ($today -ge $f -and $today -le $u) } else { ($today -ge $f -or $today -le $u) }
      if ($in -and ([string]$th.name) -match '^[a-z0-9_-]+$') {
        $cand = Join-Path $AssetDir ("themes\" + $th.name)
        if (Test-Path -LiteralPath $cand) { $ThemeDir = $cand; Log "  [그림] 테마: $($th.name)"; break }
      }
    }
  }
} catch { }
function Get-AssetImage($name) {
  $p = $null
  if ($ThemeDir) { $tp = Join-Path $ThemeDir ($name + ".png"); if (Test-Path -LiteralPath $tp) { $p = $tp } }
  if (-not $p) { $p = Join-Path $AssetDir ($name + ".png") }
  if (-not (Test-Path -LiteralPath $p)) { return $null }
  try {
    $bi = New-Object System.Windows.Media.Imaging.BitmapImage
    $bi.BeginInit(); $bi.CacheOption = "OnLoad"; $bi.UriSource = New-Object System.Uri($p); $bi.EndInit(); $bi.Freeze()
    return $bi
  } catch { return $null }
}
function New-Pic($name, $size, $fallbackColor, $fallbackText) {
  $src = Get-AssetImage $name
  if ($src) {
    $im = New-Object System.Windows.Controls.Image
    $im.Source = $src; $im.Width = $size; $im.Height = $size
    [System.Windows.Media.RenderOptions]::SetBitmapScalingMode($im, "NearestNeighbor")
    return $im
  }
  $b = New-Object System.Windows.Controls.Border
  $b.Width = $size; $b.Height = $size; $b.CornerRadius = 6
  $b.Background = Brush $fallbackColor
  $t = New-Object System.Windows.Controls.TextBlock
  $t.Text = $fallbackText; $t.Foreground = Brush "#FFFFFF"; $t.FontFamily = $UiFont
  $t.FontSize = [Math]::Max(9, [int]($size / 3)); $t.FontWeight = "Bold"
  $t.HorizontalAlignment = "Center"; $t.VerticalAlignment = "Center"
  $b.Child = $t
  return $b
}

# 카드·작은 버튼 모양. 마우스를 올리면 테두리가 짙어지고, 누르면 살짝 눌린다.
$BtnTemplate = [System.Windows.Markup.XamlReader]::Parse(@'
<ControlTemplate xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
                 xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" TargetType="Button">
  <Border x:Name="bd" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}"
          BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="10" Padding="{TemplateBinding Padding}"
          SnapsToDevicePixels="True">
    <Border.Effect><DropShadowEffect BlurRadius="6" ShadowDepth="1.5" Opacity="0.18" Direction="270"/></Border.Effect>
    <ContentPresenter HorizontalAlignment="Stretch" VerticalAlignment="Center"/>
  </Border>
  <ControlTemplate.Triggers>
    <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="bd" Property="BorderThickness" Value="2.5"/></Trigger>
    <Trigger Property="IsPressed" Value="True"><Setter TargetName="bd" Property="RenderTransform"><Setter.Value><TranslateTransform Y="1.5"/></Setter.Value></Setter></Trigger>
    <Trigger Property="IsEnabled" Value="False"><Setter TargetName="bd" Property="Opacity" Value="0.55"/></Trigger>
  </ControlTemplate.Triggers>
</ControlTemplate>
'@)

function New-Text($text, $size, $color, $bold) {
  $t = New-Object System.Windows.Controls.TextBlock
  $t.Text = $text; $t.FontFamily = $UiFont; $t.FontSize = $size
  $t.Foreground = Brush $color
  if ($bold) { $t.FontWeight = "Bold" }
  $t.TextWrapping = "Wrap"
  return $t
}

# 예전 이름 맞춰 주기: 글자(TextBlock)에 ForeColor 를 붙인다
function Add-ForeColor($tb) {
  Add-Member -InputObject $tb -MemberType ScriptProperty -Name ForeColor -Value { $null } -SecondValue { param($c) $this.Foreground = (Swap-Color $c) } -Force
  return $tb
}
# 예전 이름 맞춰 주기: 버튼에 Text · Enabled · PerformClick 을 붙인다
function Add-ButtonShim($b, $titleBlock) {
  $b | Add-Member -NotePropertyName TitleBlock -NotePropertyValue $titleBlock -Force
  Add-Member -InputObject $b -MemberType ScriptProperty -Name Text -Value { $this.TitleBlock.Text } -SecondValue { param($v) $this.TitleBlock.Text = $v } -Force
  Add-Member -InputObject $b -MemberType ScriptProperty -Name Enabled -Value { $this.IsEnabled } -SecondValue { param($v) $this.IsEnabled = [bool]$v } -Force
  Add-Member -InputObject $b -MemberType ScriptMethod -Name PerformClick -Value { $this.RaiseEvent((New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent))) } -Force
  return $b
}

# 큰 카드: [그림] 제목 / 한 줄 설명 ………… 오른쪽 작은 글자 >
$Compact = ($Server -eq "elly")
function New-Card($title, $bg, $border, $titleColor, $subColor, $picName, $picColor, $picText, $height, $titleSize) {
  $b = New-Object System.Windows.Controls.Button
  $b.Template = $BtnTemplate; $b.Background = Brush $bg; $b.BorderBrush = Brush $border
  $b.BorderThickness = 1.5; $b.Padding = New-Object System.Windows.Thickness(16, 6, 12, 6)
  $b.Height = $height; $b.Margin = New-Object System.Windows.Thickness(0, 0, 0, $(if ($Compact) { 8 } else { 10 })); $b.Cursor = "Hand"
  $g = New-Object System.Windows.Controls.Grid
  foreach ($w in @(64, -1, -2, 26)) {
    $cd = New-Object System.Windows.Controls.ColumnDefinition
    if ($w -eq -1) { $cd.Width = New-Object System.Windows.GridLength(1, "Star") } elseif ($w -eq -2) { $cd.Width = [System.Windows.GridLength]::Auto } else { $cd.Width = New-Object System.Windows.GridLength($w) }
    $g.ColumnDefinitions.Add($cd)
  }
  $pic = New-Pic $picName 52 $picColor $picText
  $pic.VerticalAlignment = "Center"; $pic.HorizontalAlignment = "Left"
  [System.Windows.Controls.Grid]::SetColumn($pic, 0); [void]$g.Children.Add($pic)
  $sp = New-Object System.Windows.Controls.StackPanel; $sp.VerticalAlignment = "Center"; $sp.Margin = New-Object System.Windows.Thickness(8, 0, 8, 0)
  $tt = New-Text $title $titleSize $titleColor $true; $tt.TextWrapping = "NoWrap"
  $st = New-Text "" $(if ($Compact) { 11.5 } else { 12.5 }) $subColor $false; $st.Margin = New-Object System.Windows.Thickness(0, $(if ($Compact) { 1 } else { 3 }), 0, 0); $st.LineHeight = $(if ($Compact) { 15 } else { 18 }); $st.LineStackingStrategy = "BlockLineHeight"
  [void]$sp.Children.Add($tt); [void]$sp.Children.Add($st)
  [System.Windows.Controls.Grid]::SetColumn($sp, 1); [void]$g.Children.Add($sp)
  $rp = New-Object System.Windows.Controls.StackPanel; $rp.VerticalAlignment = "Center"; $rp.HorizontalAlignment = "Right"; $rp.Margin = New-Object System.Windows.Thickness(0, 0, 8, 0)
  $rl = New-Text "" 11.5 $subColor $false; $rl.HorizontalAlignment = "Right"; $rl.TextWrapping = "NoWrap"
  $rv = New-Text "" 13 $subColor $false; $rv.HorizontalAlignment = "Right"; $rv.TextWrapping = "NoWrap"
  [void]$rp.Children.Add($rl); [void]$rp.Children.Add($rv)
  [System.Windows.Controls.Grid]::SetColumn($rp, 2); [void]$g.Children.Add($rp)
  $chev = New-Object System.Windows.Shapes.Path
  $chev.Data = [System.Windows.Media.Geometry]::Parse("M 0,0 L 7,7 L 0,14"); $chev.Stroke = Brush $titleColor; $chev.StrokeThickness = 2.2
  $chev.VerticalAlignment = "Center"; $chev.HorizontalAlignment = "Center"
  [System.Windows.Controls.Grid]::SetColumn($chev, 3); [void]$g.Children.Add($chev)
  $b.Content = $g
  $b = Add-ButtonShim $b $tt
  $b | Add-Member -NotePropertyName SubBlock -NotePropertyValue $st -Force
  $b | Add-Member -NotePropertyName RightLabel -NotePropertyValue $rl -Force
  $b | Add-Member -NotePropertyName RightValue -NotePropertyValue $rv -Force
  return $b
}

# 카드 오른쪽·아래 글자. 예전에는 버튼 위에 얹은 글자 하나(stamp)였다. 같은 이름으로 받아서
# "최근 … 날짜" 줄은 오른쪽에, 나머지 설명은 제목 아래에 나눠 놓는다. 문구는 그대로다.
function New-Stamp($card) {
  $o = [pscustomobject]@{ Card = $card; Raw = "" }
  Add-Member -InputObject $o -MemberType ScriptProperty -Name Text -Value { $this.Raw } -SecondValue {
    param($v)
    $this.Raw = [string]$v
    $lines = @(([string]$v) -split "`r?`n" | Where-Object { $_ -ne "" })
    $c = $this.Card
    if ($lines.Count -ge 2 -and $lines[0] -like "최근*") {
      $first = $lines[0]; $i = $first.LastIndexOf(" ")
      if ($i -gt 0) { $c.RightLabel.Text = $first.Substring(0, $i); $c.RightValue.Text = $first.Substring($i + 1) } else { $c.RightLabel.Text = ""; $c.RightValue.Text = $first }
      $c.SubBlock.Text = ($lines[1..($lines.Count - 1)] -join "`n")
    } else {
      $c.RightLabel.Text = ""; $c.RightValue.Text = ""
      $c.SubBlock.Text = ($lines -join "`n")
    }
  } -Force
  Add-Member -InputObject $o -MemberType ScriptProperty -Name ForeColor -Value { $null } -SecondValue {
    param($col) $br = Swap-Color $col; $this.Card.SubBlock.Foreground = $br; $this.Card.RightValue.Foreground = $br
  } -Force
  return $o
}

# 작은 버튼: 선 그림 + 글자
$SmallIcons = @{
  folder  = "M 1,4 L 7,4 L 9,6 L 19,6 L 19,17 L 1,17 Z"
  pin     = "M 10,1 C 5,1 3,5 3,8 C 3,13 10,19 10,19 C 10,19 17,13 17,8 C 17,5 15,1 10,1 Z M 10,5 A 3,3 0 1 1 9.99,5 Z"
  doc     = "M 4,1 L 13,1 L 17,5 L 17,19 L 4,19 Z M 7,8 L 14,8 M 7,11 L 14,11 M 7,14 L 12,14"
  box     = "M 2,6 L 10,2 L 18,6 L 18,15 L 10,19 L 2,15 Z M 2,6 L 10,10 L 18,6 M 10,10 L 10,19"
  gear    = "M 10,6 A 4,4 0 1 1 9.99,6 Z M 10,1 L 10,4 M 10,16 L 10,19 M 1,10 L 4,10 M 16,10 L 19,10 M 3.6,3.6 L 5.8,5.8 M 14.2,14.2 L 16.4,16.4 M 3.6,16.4 L 5.8,14.2 M 14.2,5.8 L 16.4,3.6"
  person  = "M 10,2 A 4,4 0 1 1 9.99,2 Z M 2,19 C 2,13 18,13 18,19 Z"
  coin    = "M 10,2 A 8,8 0 1 1 9.99,2 Z M 10,6 L 10,14 M 7.5,8 C 7.5,6 12.5,6 12.5,8 C 12.5,10 7.5,10 7.5,12 C 7.5,14 12.5,14 12.5,12"
  door    = "M 4,1 L 16,1 L 16,19 L 4,19 Z M 12,10 L 13,10"
}
# 작은 선 그림: assets 에 btn_<이름>.png 등이 있으면 그 그림을, 없으면 선으로 그린다
$IconFile = @{ folder = "btn_folder"; pin = "btn_pin"; doc = "btn_doc"; box = "btn_chest"; gear = "btn_gear"; person = "btn_person"; coin = "btn_coin"; door = "btn_door" }
function New-LineIcon($icon, $size) {
  $name = if ($IconFile.ContainsKey($icon)) { $IconFile[$icon] } else { $icon }
  $src = Get-AssetImage $name
  if ($src) {
    $im = New-Object System.Windows.Controls.Image
    $im.Source = $src; $im.Width = $size; $im.Height = $size; $im.VerticalAlignment = "Center"
    # 작은 버튼 그림은 부드러운 선이라 도트처럼 확대하지 않고 곱게 줄인다
    [System.Windows.Media.RenderOptions]::SetBitmapScalingMode($im, "HighQuality")
    return $im
  }
  $p = New-Object System.Windows.Shapes.Path
  $p.Data = [System.Windows.Media.Geometry]::Parse($SmallIcons[$icon]); $p.Stroke = Brush "#5C5648"; $p.StrokeThickness = 1.6
  $p.Width = $size; $p.Height = $size; $p.Stretch = "Uniform"; $p.VerticalAlignment = "Center"
  return $p
}
function New-SmallButton($text, $icon) {
  $b = New-Object System.Windows.Controls.Button
  $b.Template = $BtnTemplate; $b.Background = Brush "#F6F1E6"; $b.BorderBrush = Brush "#D8CFBD"; $b.BorderThickness = 1.2
  $b.Height = $(if ($IsAdmin) { 34 } else { 40 }); $b.Margin = New-Object System.Windows.Thickness(0, 0, 8, $(if ($IsAdmin) { 6 } else { 8 })); $b.Padding = New-Object System.Windows.Thickness(12, 0, 8, 0); $b.Cursor = "Hand"
  $sp = New-Object System.Windows.Controls.StackPanel; $sp.Orientation = "Horizontal"
  $ic = New-LineIcon $icon 20
  $tb = New-Text $text 13 "#3D3A33" $false; $tb.TextWrapping = "NoWrap"; $tb.VerticalAlignment = "Center"; $tb.Margin = New-Object System.Windows.Thickness(12, 0, 0, 0)
  [void]$sp.Children.Add($ic); [void]$sp.Children.Add($tb)
  $b.Content = $sp
  return (Add-ButtonShim $b $tb)
}

$form = New-Object System.Windows.Window
$form.Title = $AppName
$form.Width = 1220; $form.Height = 810
$form.ResizeMode = "CanMinimize"
$form.WindowStartupLocation = "CenterScreen"
$form.Background = Brush "#F2ECDF"
$form.FontFamily = $UiFont
[System.Windows.Media.TextOptions]::SetTextFormattingMode($form, "Display")

# 창 아이콘. 파일을 따로 받지 않아도 되게 그림을 글자로 바꿔 넣어 뒀다.
# WPF 창에는 그림으로, 작은 창(윈폼)에는 아이콘으로 쓴다.
$IconB64 = "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"
$script:WinIcon = $null
try {
  $iconMs  = New-Object System.IO.MemoryStream(,[Convert]::FromBase64String($IconB64))
  $iconBmp = New-Object System.Drawing.Bitmap($iconMs)
  $script:WinIcon = [System.Drawing.Icon]::FromHandle($iconBmp.GetHicon())
  $form.Icon = [System.Windows.Media.Imaging.BitmapFrame]::Create((New-Object System.IO.MemoryStream(,[Convert]::FromBase64String($IconB64))))
} catch { }
# 작은 창(폴더 고르기·암호 등)이 이 창 위에 뜨도록 주인을 알려 준다
$script:Owner = New-Object System.Windows.Forms.NativeWindow
$form.Add_SourceInitialized({ try { $script:Owner.AssignHandle((New-Object System.Windows.Interop.WindowInteropHelper($form)).Handle) } catch { } })
Add-Member -InputObject $form -MemberType ScriptProperty -Name Handle -Value { (New-Object System.Windows.Interop.WindowInteropHelper($this)).Handle } -Force

$root = New-Object System.Windows.Controls.Grid
$root.Margin = New-Object System.Windows.Thickness(18, 14, 18, 16)
$c0 = New-Object System.Windows.Controls.ColumnDefinition; $c0.Width = New-Object System.Windows.GridLength(470)
$c1 = New-Object System.Windows.Controls.ColumnDefinition; $c1.Width = New-Object System.Windows.GridLength(1, "Star")
$root.ColumnDefinitions.Add($c0); $root.ColumnDefinitions.Add($c1)
$form.Content = $root

# ── 왼쪽 ──
$left = New-Object System.Windows.Controls.DockPanel
$left.Margin = New-Object System.Windows.Thickness(4, 0, 18, 0); $left.LastChildFill = $false
[System.Windows.Controls.Grid]::SetColumn($left, 0); [void]$root.Children.Add($left)

$head = New-Object System.Windows.Controls.Grid
$head.Margin = New-Object System.Windows.Thickness(0, 4, 0, 14)
$hc0 = New-Object System.Windows.Controls.ColumnDefinition; $hc0.Width = [System.Windows.GridLength]::Auto
$hc1 = New-Object System.Windows.Controls.ColumnDefinition; $hc1.Width = New-Object System.Windows.GridLength(1, "Star")
$hc2 = New-Object System.Windows.Controls.ColumnDefinition; $hc2.Width = [System.Windows.GridLength]::Auto
$head.ColumnDefinitions.Add($hc0); $head.ColumnDefinitions.Add($hc1); $head.ColumnDefinitions.Add($hc2)
$hr0 = New-Object System.Windows.Controls.RowDefinition; $hr0.Height = [System.Windows.GridLength]::Auto
$hr1 = New-Object System.Windows.Controls.RowDefinition; $hr1.Height = [System.Windows.GridLength]::Auto
$head.RowDefinitions.Add($hr0); $head.RowDefinitions.Add($hr1)
$logo = New-Pic "title_grass" 50 "#5E9E3F" "잔디"
$logo.Margin = New-Object System.Windows.Thickness(0, 0, 12, 0); $logo.VerticalAlignment = "Center"; [System.Windows.Controls.Grid]::SetRowSpan($logo, 2)
[void]$head.Children.Add($logo)
$tsp = New-Object System.Windows.Controls.StackPanel; $tsp.VerticalAlignment = "Center"
$title = New-Text $AppName 27 "#2F2D28" $true; $title.TextWrapping = "NoWrap"
$sub = Add-ForeColor (New-Text "" 12.5 "#6E6A60" $false)
$sub.Text = if ($IsAdmin) { "모드를 맞추기 전에 마인크래프트를 종료해 주세요." } else { "모드는 프리즘 런처가 켜질 때 알아서 맞춰집니다." }
[void]$tsp.Children.Add($title)
$sub.Margin = New-Object System.Windows.Thickness(0, 2, 0, 0)
[System.Windows.Controls.Grid]::SetRow($sub, 1); [System.Windows.Controls.Grid]::SetColumn($sub, 1); [System.Windows.Controls.Grid]::SetColumnSpan($sub, 2); [void]$head.Children.Add($sub)
[System.Windows.Controls.Grid]::SetColumn($tsp, 1); [void]$head.Children.Add($tsp)
# 서버 상태: 점 + 글자가 들어간 알약 모양
$pill = New-Object System.Windows.Controls.Border
$pill.CornerRadius = 14; $pill.Background = Brush "#FBF7EE"; $pill.BorderBrush = Brush "#DDD4C2"; $pill.BorderThickness = 1
$pill.Padding = New-Object System.Windows.Thickness(10, 5, 12, 5); $pill.VerticalAlignment = "Top"; $pill.Margin = New-Object System.Windows.Thickness(8, 6, 0, 0)
$psp = New-Object System.Windows.Controls.StackPanel; $psp.Orientation = "Horizontal"
$srvDot = New-Object System.Windows.Shapes.Ellipse; $srvDot.Width = 11; $srvDot.Height = 11; $srvDot.Fill = Brush "#B9B4A8"; $srvDot.Margin = New-Object System.Windows.Thickness(0, 0, 7, 0); $srvDot.VerticalAlignment = "Center"
$srvLbl = New-Text "" 12.5 "#96918A" $true; $srvLbl.TextWrapping = "NoWrap"; $srvLbl.VerticalAlignment = "Center"
Add-Member -InputObject $srvLbl -MemberType ScriptProperty -Name ForeColor -Value { $null } -SecondValue { param($c) $br = Swap-Color $c; $this.Foreground = $br; $srvDot.Fill = $br } -Force
[void]$psp.Children.Add($srvDot); [void]$psp.Children.Add($srvLbl)
$pill.Child = $psp
[System.Windows.Controls.Grid]::SetColumn($pill, 2); [void]$head.Children.Add($pill)
[System.Windows.Controls.DockPanel]::SetDock($head, "Top"); [void]$left.Children.Add($head)

# 카드. 가장 자주 누르는 "게임 실행" 을 맨 위, 가장 눈에 띄게.
$cardH = if ($Compact) { 70 } else { 84 }
$runT = if ($Compact) { 19 } else { 21 }; $cardT = if ($Compact) { 17 } else { 19 }
$btnRun   = New-Card "게임 실행" "#3E8E47" "#2C6B33" "#FFFFFF" "#E6F3E3" "card_sword" "#2C6B33" "검" $cardH $runT
$stampRun = New-Stamp $btnRun
$btnPatch = New-Card "한글패치 업데이트" "#F1E8D8" "#DCCFB7" "#34312A" "#6E685C" "card_grass" "#6C9B45" "잔디" $cardH $cardT
$stampPatch = New-Stamp $btnPatch
$btnNews  = New-Card "업데이트 내역 보기" "#E3DAF0" "#CBBCE0" "#34312A" "#6E685C" "card_book" "#7B63A8" "책" $cardH $cardT
$stampNews = New-Stamp $btnNews
$btnWake  = New-Card "서버 켜기" "#EEDFCB" "#D9C3A5" "#34312A" "#6E685C" "card_chest" "#8A6236" "상자" $cardH $cardT
$stampWake = New-Stamp $btnWake
$btnMods = $null; $stampMods = $null
if ($Server -eq "elly") {
  $btnMods = New-Card "서버 모드 맞추기" "#DDE5EE" "#BFCBDA" "#34312A" "#6E685C" "card_mods" "#46607F" "모드" $cardH $cardT
  $stampMods = New-Stamp $btnMods
}
$btnJoin = $null; $stampJoin = $null
foreach ($cb in @($btnRun, $btnPatch, $btnNews, $btnWake, $btnMods)) {
  if ($cb) { [System.Windows.Controls.DockPanel]::SetDock($cb, "Top"); [void]$left.Children.Add($cb) }
}

# 어디에 설치되는지 늘 보이게 한다. 안 보이면 "어디에 받는다는 거야?"가 된다.
$pathLbl = Add-ForeColor (New-Text "" 13 "#5A5E56" $false)
$pathLbl.Margin = New-Object System.Windows.Thickness(2, 6, 0, 8)
[System.Windows.Controls.DockPanel]::SetDock($pathLbl, "Top"); [void]$left.Children.Add($pathLbl)

$tools = New-Object System.Windows.Controls.Primitives.UniformGrid
$tools.Columns = 2; $tools.Margin = New-Object System.Windows.Thickness(0, 0, -8, 0)
$btnOpen    = New-SmallButton "설치된 폴더 열기" "folder"
$btnChange  = New-SmallButton "설치 위치 바꾸기" "pin"
$btnLog     = New-SmallButton "기록 보기" "doc"
# 새 인스턴스를 깔면 단축키가 처음 상태로 돌아간다. 쓰던 곳에서 그것만 옮겨온다.
$btnKeys    = New-SmallButton "단축키 가져오기" "box"
$btnRestore = New-SmallButton "설정 되돌리기" "gear"
$adminLabel = if ($IsAdmin) { "관리자 모드 끄기" } else { "관리자 모드 열기" }
$btnAdmin   = New-SmallButton $adminLabel "person"
$btnCost    = $null
if ($IsAdmin) { $btnCost = New-SmallButton "서버 비용 보기" "coin" }
# 휴대용: 이 PC 에서 로그아웃 (USB 에 마이크로소프트 로그인이 남지 않게)
$btnLogout = $null
if ($PortableRoot) { $btnLogout = New-SmallButton "이 PC에서 로그아웃" "door" }
foreach ($sb in @($btnOpen, $btnChange, $btnLog, $btnKeys, $btnRestore, $btnAdmin, $btnCost, $btnLogout)) { if ($sb) { [void]$tools.Children.Add($sb) } }
[System.Windows.Controls.DockPanel]::SetDock($tools, "Top"); [void]$left.Children.Add($tools)

# 지금 뭘 하는 중인지 한 줄 + 얼마나 됐는지 막대. 글자가 쏟아지는 것보다 읽기 쉽다.
$hint = New-Text "다른 폴더에 설치 하시려면 Shift 버튼을 누른채 위의 버튼을 눌러주세요" 11.5 "#9A958B" $false
$hint.Margin = New-Object System.Windows.Thickness(2, 6, 0, 0)
[System.Windows.Controls.DockPanel]::SetDock($hint, "Bottom"); [void]$left.Children.Add($hint)
$barBox = New-Object System.Windows.Controls.Grid
$bar = New-Object System.Windows.Controls.ProgressBar
$bar.Minimum = 0; $bar.Maximum = 100; $bar.Value = 0; $bar.Height = 22
$bar.Background = Brush "#E4DED2"; $bar.Foreground = Brush "#5FA548"; $bar.BorderBrush = Brush "#CFC7B6"; $bar.BorderThickness = 1
[void]$barBox.Children.Add($bar)
$barLogo = New-Pic "title_grass" 26 "#5E9E3F" ""
$barLogo.HorizontalAlignment = "Left"; $barLogo.Margin = New-Object System.Windows.Thickness(-4, 0, 0, 0)
[void]$barBox.Children.Add($barLogo)
[System.Windows.Controls.DockPanel]::SetDock($barBox, "Bottom"); [void]$left.Children.Add($barBox)
$statusLbl = Add-ForeColor (New-Text "버튼을 눌러주세요" 14 "#3C3F3A" $true)
$statusLbl.Margin = New-Object System.Windows.Thickness(2, 0, 0, 8)
[System.Windows.Controls.DockPanel]::SetDock($statusLbl, "Bottom"); [void]$left.Children.Add($statusLbl)
# 진행 막대: 예전 "Marquee"(계속 도는 막대) 와 "Continuous" 를 그대로 받는다
function Set-BarStyle($s) { $bar.IsIndeterminate = ($s -eq "Marquee") }


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
  foreach ($b in @($btnPatch, $btnNews, $btnRun, $btnWake, $btnMods, $btnOpen, $btnChange, $btnLog, $btnKeys, $btnRestore, $btnAdmin, $btnCost, $btnLogout)) {
    if ($b) { $b.Enabled = -not $on }
  }
  $form.Cursor = if ($on) { [System.Windows.Input.Cursors]::Wait } else { $null }
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
  if ($fb.ShowDialog($script:Owner) -ne [System.Windows.Forms.DialogResult]::OK) { return $null }

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
# 엘리용은 엘리 것만 본다. 예전 판의 공용 파일까지 읽었더니 잔누 인스턴스를
# 가리키는 일이 생겼다.
function Get-SavedTarget {
  if ($PortableRoot) {
    $pp = Join-Path $PortableRoot "prism\instances\엘리서버\.minecraft"
    if (Test-Path -LiteralPath $pp) { return $pp }
  }
  foreach ($f in @($MainRemember, $PackRemember)) {
    $c = Get-Content (Join-Path $env:APPDATA $f) -Encoding UTF8 -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($c -and (Test-Path $c)) { return $c }
  }
  return $null
}
function Save-Target($p) {
  foreach ($f in @($MainRemember, $PackRemember)) {
    try { $p | Set-Content (Join-Path $env:APPDATA $f) -Encoding UTF8 } catch { }
  }
  Update-SubText
}

# 고른 폴더가 커스포지 프로필(커스포지 Instances 폴더 아래)인가
function Test-CurseForgeTarget($target) {
  if (-not $target) { return $false }
  return ("$target" -like "*\curseforge\minecraft\Instances\*")
}

# 창 위쪽 안내 한 줄. 커스포지 프로필은 켤 때 저절로 맞춰지지 않으므로 버튼을 알려드린다.
function Update-SubText {
  if (-not $sub) { return }
  $sub.Text = if ($IsAdmin) { "모드를 맞추기 전에 마인크래프트를 종료해 주세요." }
              elseif (Test-CurseForgeTarget (Get-SavedTarget)) { "모드는 [서버 모드 맞추기]를 누르면 맞춰집니다." }
              else { "모드는 프리즘 런처가 켜질 때 알아서 맞춰집니다." }
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
    # 서명 목록에 적힌 해시로 주소를 바꿔 raw 캐시(최대 5분)의 옛 zip 을 피한다
    $pv = ""
    try { $pv = "?v=" + ([string](Get-Rel).files."Elly-Korean-Patch.zip".sha256).Substring(0, 12) } catch { }
    Get-Web ($PatchUrl + $pv) $tmp

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

    # 팩에 들어 있는 설정 파일(config/). 작아서 내용째 들고 있다가 Install-Configs 가 쓴다.
    $script:packConfig = @()
    $cfgSrc = Get-ChildItem $work -Directory | ForEach-Object { Join-Path $_.FullName "config" } |
              Where-Object { Test-Path $_ } | Select-Object -First 1
    if ($cfgSrc) {
      foreach ($f in Get-ChildItem $cfgSrc -File -Recurse) {
        if ($f.Name -like "*.pw.toml") { continue }
        $rel = $f.FullName.Substring($cfgSrc.Length).TrimStart('\')
        $b = [IO.File]::ReadAllBytes($f.FullName)
        $h = [BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash($b)).Replace("-", "").ToLower()
        $script:packConfig += [pscustomobject]@{ Rel = $rel; Bytes = $b; Sha = $h }
      }
    }
    $script:packWanted = $want
    return $want
  } finally {
    Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
  }
}

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

# 같은 모드(같은 id)가 두 벌이면 마크가 "duplicate mod" 로 안 켜진다. 팩에 있는 쪽을 남기고
#  - 도우미가 전에 깐 기록이 있는 옛 파일은 지운다
#  - 기록이 없는 파일(직접 까셨을 수 있는 것)은 지우지 않고 mods-중복보관 폴더로 옮긴다
function Resolve-DuplicateMods($target, $want, $oldMap) {
  $modsDir = Join-Path $target "mods"
  $wantFiles = @{}; foreach ($w in $want) { $wantFiles[$w.File] = $true }
  $byId = @{}
  foreach ($w in $want) {
    $p = Join-Path $modsDir $w.File
    if (Test-Path -LiteralPath $p) { $id = Get-JarModId $p; if ($id) { $byId[$id] = $w.File } }
    [System.Windows.Forms.Application]::DoEvents()
  }
  $mine = @{}; foreach ($v in $oldMap.Values) { if ($v) { $mine[[string]$v] = $true } }
  $removed = 0; $moved = @()
  foreach ($j in @(Get-ChildItem -LiteralPath $modsDir -Filter "*.jar" -File -ErrorAction SilentlyContinue)) {
    if ($wantFiles.ContainsKey($j.Name)) { continue }
    $id = Get-JarModId $j.FullName
    if (-not $id -or -not $byId.ContainsKey($id)) { continue }
    if ($mine.ContainsKey($j.Name)) {
      [IO.File]::Delete($j.FullName); $removed++
      Log "  옛 버전 지움: $($j.Name) (같은 모드: $($byId[$id]))"
    } else {
      $keep = Join-Path $target "mods-중복보관"
      if (-not (Test-Path -LiteralPath $keep)) { [void][IO.Directory]::CreateDirectory($keep) }
      $to = Join-Path $keep $j.Name
      if (Test-Path -LiteralPath $to) { $to = Join-Path $keep ((Get-Date -Format "yyyyMMdd-HHmmss") + "-" + $j.Name) }
      [IO.File]::Move($j.FullName, $to); $moved += $j.Name
      Log "  중복이라 옮김: $($j.Name) → mods-중복보관 (같은 모드: $($byId[$id]))"
    }
  }
  return [pscustomobject]@{ Removed = $removed; Moved = $moved }
}

# 팩의 설정 파일(config/)을 맞춘다.
#  - 없으면 넣는다
#  - 팩 쪽 파일이 지난번과 달라졌을 때만 덮어쓴다. 직접 바꾸신 설정이면 덮기 전에 .bak 으로 남긴다
#  - 팩이 그대로면 직접 바꾸신 설정을 건드리지 않는다
#  - 단축키·조작 관련 파일은 어떤 경우에도 건드리지 않는다 (options.txt 는 config 밖이라 애초에 대상이 아니다)
function Get-ModsNote($dup, $cfg) {
  $n = ""
  if ($dup.Removed -gt 0) { $n += " · 옛 버전 $($dup.Removed) 개 정리" }
  if ($dup.Moved.Count -gt 0) { $n += " · 겹치는 모드 $($dup.Moved.Count) 개를 mods-중복보관 으로 옮김" }
  if ($cfg.Added -gt 0) { $n += " · 설정 $($cfg.Added) 개 넣음" }
  if ($cfg.Updated -gt 0) { $n += " · 설정 $($cfg.Updated) 개 갱신" }
  return $n
}

function Install-Configs($target) {
  $res = [pscustomobject]@{ Added = 0; Updated = 0 }
  if (-not $script:packConfig -or $script:packConfig.Count -eq 0) { return $res }
  $mapFile = Join-Path $env:APPDATA ($ModMapName -replace 'modmap', 'configmap')
  $map = @{}
  try { if (Test-Path $mapFile) { $j = Get-Content $mapFile -Raw -Encoding UTF8 | ConvertFrom-Json; foreach ($pp in $j.PSObject.Properties) { $map[$pp.Name] = [string]$pp.Value } } } catch { }
  foreach ($c in $script:packConfig) {
    if ($c.Rel -match '(?i)key|bind|control|options') { Log "  설정 건너뜀(단축키·조작): $($c.Rel)"; continue }
    $dest = Join-Path (Join-Path $target "config") $c.Rel
    $dir = Split-Path $dest -Parent
    if (-not (Test-Path -LiteralPath $dir)) { [void][IO.Directory]::CreateDirectory($dir) }
    $rec = $map[$c.Rel]
    if (-not (Test-Path -LiteralPath $dest)) {
      [IO.File]::WriteAllBytes($dest, $c.Bytes); $map[$c.Rel] = $c.Sha; $res.Added++
      Log "  설정 넣음: $($c.Rel)"
      continue
    }
    $cur = (Get-FileHash -LiteralPath $dest -Algorithm SHA256).Hash.ToLower()
    if ($cur -eq $c.Sha) { $map[$c.Rel] = $c.Sha; continue }
    if ($rec -and $rec -ne $c.Sha) {
      if ($cur -ne $rec) { [IO.File]::Copy($dest, "$dest.bak-" + (Get-Date -Format "yyyyMMdd-HHmmss"), $true) }
      [IO.File]::WriteAllBytes($dest, $c.Bytes); $map[$c.Rel] = $c.Sha; $res.Updated++
      Log "  설정 바꿈(팩이 달라짐): $($c.Rel)"
    } elseif (-not $rec) {
      # 처음 보는 파일인데 이미 다르게 있다 → 직접 맞춰두신 것으로 보고 두되, 다음 팩 변경부터는 따른다
      $map[$c.Rel] = $c.Sha
      Log "  설정 그대로 둠(이미 있음): $($c.Rel)"
    }
  }
  try { ($map | ConvertTo-Json -Compress) | Set-Content $mapFile -Encoding UTF8 } catch { }
  return $res
}

function Install-Mods {
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
      SetStep "같은 모드가 두 벌 있는지 확인하고 있습니다..." 90
      $dup = Resolve-DuplicateMods $target $want $oldMap
      $cfg = Install-Configs $target
      Save-ModMap $mapFile $want
      SetStep ("이미 최신입니다. 바로 들어가시면 됩니다. (서버 모드 $($want.Count)개" + (Get-ModsNote $dup $cfg) + ")") 100
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

    SetStep "같은 모드가 두 벌 있는지 확인하고 있습니다..." 98
    $dup = Resolve-DuplicateMods $target $want $oldMap
    $cleaned += $dup.Removed
    $cfg = Install-Configs $target
    Save-ModMap $mapFile $want
    $cleanNote = $(if ($cleaned -gt 0) { " · 옛 버전 $cleaned 개 정리" } else { "" }) + (Get-ModsNote ([pscustomobject]@{ Removed = 0; Moved = $dup.Moved }) $cfg)
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

# 서버가 켜졌다 꺼졌다 하는 동안에도 창이 따라가야 한다. 주소에 붙어보기만 하면
# 알 수 있어서 가볍다. 15초마다 이것만 다시 본다.
function Update-ServerState {
  try {
    $c = New-Object System.Net.Sockets.TcpClient
    $ar = $c.BeginConnect($PingHost, $PingPort, $null, $null)
    $up = $ar.AsyncWaitHandle.WaitOne(1500, $false) -and $c.Connected
    $c.Close()
    if ($up) {
      $srvLbl.Text = "서버상태 : ON"
      $srvLbl.ForeColor = [System.Drawing.Color]::FromArgb(62, 140, 62)
      if ($btnWake) { $stampWake.Text = "이미 켜져 있습니다"; $stampWake.ForeColor = $ColorGood }
    } else {
      $srvLbl.Text = "서버상태 : OFF"
      $srvLbl.ForeColor = [System.Drawing.Color]::FromArgb(186, 86, 76)
      if ($btnWake) { $stampWake.Text = "눌러서 서버를 켜실 수 있습니다`r`n보통 1~3분 걸립니다"; $stampWake.ForeColor = $ColorDim }
    }
  } catch { $srvLbl.Text = "" }
}

function Refresh-Stamps($keepMessage) {
  # 뭔가 하고 있다는 걸 알 수 있게. 조용히 멈춰 있으면 고장난 줄 안다.
  $stampPatch.Text = "확인 중..."
  Log "상태 확인 시작"
  if (-not $keepMessage) {
    $statusLbl.Text = "불러오는 중입니다..."
    Set-BarStyle "Marquee"
    
  }
  [System.Windows.Forms.Application]::DoEvents()

  # 지금 어디에 설치되는지 — 안 보이면 "어디에 받는다는 거야?"가 된다
  $tp = Get-SavedTarget
  if ($tp) {
    $pathLbl.Text = if ($PortableRoot) { "설치 위치 : USB 휴대용 (" + $PortableRoot + ")" } else { "설치 위치 : " + (Split-Path $tp -Leaf) }
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

    # 서명된 manifest 의 sha1 을 쓴다. 예전에는 별도 .sha1 파일을 읽었는데, 그 파일은
    # 서명 때 자동으로 갱신되지 않아서 배포할 때마다 낡은 값이 남아 "최신 버전이 아닙니다"로
    # 잘못 떴다(2026-09-29).
    $srvSha = [string](Get-Rel).files."Elly-Korean-Patch.zip".sha1
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

  # 엘리 전용 — 팩과 내 모드가 맞는지
  if ($stampMods) {
    try {
      $want = $script:packWanted
      if ($want) { $cnt = $want.Count }
      else {
        $idx = Get-WebText "https://raw.githubusercontent.com/$PackRepo/refs/heads/main/index.toml"
        $cnt = ([regex]::Matches($idx, '(?m)^file\s*=\s*"mods/')).Count
      }
      if ($cnt -le 0) { throw "목록 없음" }
      $t3 = Get-SavedTarget
      if ($t3 -and (Test-Path (Join-Path $t3 "mods"))) {
        $have = @{}
        Get-ChildItem (Join-Path $t3 "mods") -Filter *.jar -File -ErrorAction SilentlyContinue | ForEach-Object { $have[$_.Name] = $true }
        if ($want) { $miss = @($want | Where-Object { -not $have.ContainsKey($_.File) }).Count }
        else { $miss = [Math]::Max(0, $cnt - $have.Count) }
        if ($miss -eq 0) {
          $stampMods.Text = "서버 파일 $cnt 개 모두 일치`r`n클라이언트 파일 $($have.Count) 개 · 최신 버전입니다"
          $stampMods.ForeColor = $ColorGood
        } else {
          $stampMods.Text = "서버 파일 $cnt 개 중 $miss 개 없음`r`n클라이언트 파일 $($have.Count) 개 · 최신 버전이 아닙니다"
          $stampMods.ForeColor = $ColorBad
        }
      } else {
        $stampMods.Text = "서버 파일 $cnt 개`r`n아직 확인하지 않았습니다"
        $stampMods.ForeColor = $ColorDim
      }
    } catch { $stampMods.Text = "확인 실패"; $stampMods.ForeColor = $ColorDim }
  }
  Log "  한글패치: $($stampPatch.Text -replace [char]13, ' / ' -replace [char]10, '')"

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

  } catch {
    $srvLbl.Text = ""
  }

  # 업데이트 내역은 마지막 날짜만 미리 보여준다. 눌러야 전부 읽을 수 있다.
  try {
    # ConvertFrom-Json 이 배열을 통째로 하나로 넘겨줄 때가 있어 한 번 펴준다
    $u = (Get-WebText "$BASE/updates.json") | ConvertFrom-Json
    $u = @($u | ForEach-Object { $_ })
    if ($u.Count -gt 0) { $stampNews.Text = "최근 $($u[0].date)`r`n눌러서 전체 내역을 보실 수 있습니다" }
    else { $stampNews.Text = "등록된 내역이 없습니다" }
    $stampNews.ForeColor = $ColorDim
  } catch { $stampNews.Text = "내역을 불러오지 못했습니다"; $stampNews.ForeColor = $ColorDim }

  # 실행 버튼은 깔려 있는 런처에 맞춰 이름을 바꾼다. "커스포지 실행" 이라고 적혀 있으면
  # 뭐가 열릴지 누르기 전에 안다.
  if ($btnRun) {
    $lc = $null
    try { $lc = Find-Launcher (Get-SavedTarget) } catch { }
    if ($lc -and $lc.Kind -eq "prism") {
      $btnRun.Text = "게임 실행"
      $stampRun.Text = "$($lc.Name)로 바로 실행됩니다"
    } elseif ($lc) {
      $btnRun.Text = "게임 실행"
      $stampRun.Text = "$($lc.Name)가 열립니다`r`n인스턴스에서 [플레이] 를 눌러주세요"
    } else {
      $btnRun.Text = "프리즘 런처 받기"
      $stampRun.Text = "엘리서버는 프리즘 런처로 들어옵니다`r`n눌러서 받으실 수 있습니다"
    }
    $stampRun.ForeColor = [System.Drawing.Color]::FromArgb(226, 244, 230)
  }

  if (-not $keepMessage) {
    
    Set-BarStyle "Continuous"
    $bar.Value = 0
    $statusLbl.Text = "버튼을 눌러주세요"
  }
  [System.Windows.Forms.Application]::DoEvents()
}

# ── 마인크래프트 실행 ─────────────────────────────────
# 런처마다 사정이 다르다. 프리즘·멀티MC 는 인스턴스를 지정해서 바로 켤 수 있지만,
# 커스포지는 "이 인스턴스를 켜라" 는 길을 안 열어놔서 앱까지만 열어드린다.
# 엘리서버는 프리즘 런처를 쓴다. 프리즘은 인스턴스를 지정해서 바로 켤 수 있어서,
# 폴더를 찾아 들어가 [플레이] 를 누를 필요가 없다.
function Find-Prism {
  if ($PortableRoot) {
    $pe = Join-Path $PortableRoot "prism\prismlauncher.exe"
    if (Test-Path -LiteralPath $pe) { return $pe }
  }
  $c = @(
    "$env:LOCALAPPDATA\Programs\PrismLauncher\prismlauncher.exe",
    "$env:PROGRAMFILES\PrismLauncher\prismlauncher.exe",
    "${env:PROGRAMFILES(X86)}\PrismLauncher\prismlauncher.exe",
    "$env:LOCALAPPDATA\Programs\Prism Launcher\prismlauncher.exe",
    "$env:PROGRAMFILES\Prism Launcher\prismlauncher.exe",
    "$env:USERPROFILE\scoop\apps\prismlauncher\current\prismlauncher.exe"
  )
  foreach ($e in $c) { if (Test-Path $e) { return $e } }
  # 설치 위치를 옮겼을 수도 있으니 윈도가 적어둔 곳도 본다
  foreach ($k in @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
                   "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*")) {
    try {
      foreach ($r in (Get-ItemProperty $k -ErrorAction SilentlyContinue)) {
        if ("$($r.DisplayName)" -like "*Prism*Launcher*" -and $r.InstallLocation) {
          $e = Join-Path $r.InstallLocation "prismlauncher.exe"
          if (Test-Path $e) { return $e }
        }
      }
    } catch { }
  }
  return $null
}

function Find-Launcher($target) {
  $t = "$target".ToLower()
  # 커스포지 zip 으로 가져온 프로필은 커스포지로 켠다(새로 오신 친구분들은 이 길로 들어오신다).
  if (Test-CurseForgeTarget $target) {
    $e = "$env:LOCALAPPDATA\Programs\CurseForge Windows\CurseForge.exe"
    if (Test-Path $e) { return @{ Kind = "app"; Exe = $e; Name = "CurseForge" } }
    return @{ Kind = "app"; Exe = "curseforge://"; Name = "CurseForge" }
  }
  # 프리즘이 깔려 있으면 무조건 프리즘으로 켠다.
  $prism = Find-Prism
  if ($prism) { return @{ Kind = "prism"; Exe = $prism; Name = "프리즘 런처" } }
  if ($t -like "*multimc*") {
    $e = "$env:USERPROFILE\Documents\MultiMC\MultiMC.exe"
    if (Test-Path $e) { return @{ Kind = "prism"; Exe = $e; Name = "멀티MC" } }
  }
  # 친구들에게는 프리즘만 권한다. 다만 엘리는 커스포지를 쓰므로 열어둔다.
  if ($IsAdmin) {
    if ($t -like "*modrinth*") {
      $e = "$env:LOCALAPPDATA\Programs\Modrinth App\Modrinth App.exe"
      if (Test-Path $e) { return @{ Kind = "app"; Exe = $e; Name = "모드린스" } }
    }
    $e = "$env:LOCALAPPDATA\Programs\CurseForge Windows\CurseForge.exe"
    if (Test-Path $e) { return @{ Kind = "app"; Exe = $e; Name = "CurseForge" } }
  }
  return $null
}

function Start-Minecraft {
  if (Test-MinecraftRunning) { Say "마인크래프트가 이미 켜져 있습니다."; return }
  $target = Get-SavedTarget
  if (-not $target) { Say "설치 위치를 먼저 정해주세요. 위의 버튼을 누르시면 고르실 수 있습니다."; return }

  $lc = Find-Launcher $target
  if (-not $lc) {
    # 엘리서버는 프리즘 런처로 들어온다. 없으면 받는 곳을 열어드린다.
    Say "프리즘 런처가 필요합니다. 받는 곳을 열어드릴게요."
    try { Start-Process "https://prismlauncher.org/download/windows/" } catch { }
    return
  }
  # 들어갈 서버를 목록에 미리 넣어둔다. 주소를 손으로 적을 일이 없게.
  $added = Add-ServerEntry $target "엘리서버" $ServerAddr
  Log "서버 목록: $added"

  try {
    if ($lc.Kind -eq "prism") {
      # 인스턴스 폴더 이름이 곧 인스턴스 이름이다(.minecraft 안쪽이면 한 칸 위)
      $inst = Split-Path $target -Leaf
      if ($inst -eq "minecraft" -or $inst -eq ".minecraft") { $inst = Split-Path (Split-Path $target -Parent) -Leaf }
      Start-Process $lc.Exe -ArgumentList @("--launch", $inst)
      $tail = if ($added -eq "넣음") { " 멀티플레이 목록에 엘리서버를 넣어두었습니다." } else { "" }
      Say "마인크래프트를 실행합니다. 잠시만 기다려 주세요.$tail"
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
  $dlg.Icon            = $script:WinIcon

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
  [void]$dlg.ShowDialog($script:Owner)
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
# ── 멀티플레이 서버 목록 ──────────────────────────────
# 마크는 서버 목록을 servers.dat 에 NBT 라는 형식으로 담는다. 압축이 없어서
# 직접 읽고 쓸 수 있다. 실행 버튼을 누르면 엘리서버가 목록에 없을 때 넣어준다.
$script:nbtPos = 0
function Nbt-U8($b)  { $v = $b[$script:nbtPos]; $script:nbtPos += 1; return [int]$v }
function Nbt-U16($b) { $v = ([int]$b[$script:nbtPos] -shl 8) -bor [int]$b[$script:nbtPos+1]; $script:nbtPos += 2; return $v }
function Nbt-I32($b) {
  $v = ([int]$b[$script:nbtPos] -shl 24) -bor ([int]$b[$script:nbtPos+1] -shl 16) -bor ([int]$b[$script:nbtPos+2] -shl 8) -bor [int]$b[$script:nbtPos+3]
  $script:nbtPos += 4; return $v
}
function Nbt-Str($b) {
  $n = Nbt-U16 $b
  $s = [Text.Encoding]::UTF8.GetString($b, $script:nbtPos, $n)
  $script:nbtPos += $n; return $s
}
function Nbt-Raw($b, $n) { $r = New-Object byte[] $n; [Array]::Copy($b, $script:nbtPos, $r, 0, $n); $script:nbtPos += $n; return $r }

function Nbt-ReadValue($b, $t) {
  switch ($t) {
    1  { return Nbt-Raw $b 1 }
    2  { return Nbt-Raw $b 2 }
    3  { return Nbt-Raw $b 4 }
    4  { return Nbt-Raw $b 8 }
    5  { return Nbt-Raw $b 4 }
    6  { return Nbt-Raw $b 8 }
    7  { $n = Nbt-I32 $b; return @{ len = $n; data = (Nbt-Raw $b $n) } }
    8  { return Nbt-Str $b }
    9  {
         $et = Nbt-U8 $b; $n = Nbt-I32 $b; $items = @()
         for ($i = 0; $i -lt $n; $i++) { $items += ,(Nbt-ReadValue $b $et) }
         return @{ elem = $et; items = $items }
       }
    10 {
         $o = New-Object System.Collections.Specialized.OrderedDictionary
         while ($true) {
           $ct = Nbt-U8 $b
           if ($ct -eq 0) { break }
           $cn = Nbt-Str $b
           $o[$cn] = @{ t = $ct; v = (Nbt-ReadValue $b $ct) }
         }
         return $o
       }
    11 { $n = Nbt-I32 $b; return @{ len = $n; data = (Nbt-Raw $b ($n * 4)) } }
    12 { $n = Nbt-I32 $b; return @{ len = $n; data = (Nbt-Raw $b ($n * 8)) } }
  }
  throw "모르는 NBT 종류: $t"
}

function Nbt-PutU16($w, $v) { $w.Add([byte](($v -shr 8) -band 0xFF)); $w.Add([byte]($v -band 0xFF)) }
function Nbt-PutI32($w, $v) {
  $w.Add([byte](($v -shr 24) -band 0xFF)); $w.Add([byte](($v -shr 16) -band 0xFF))
  $w.Add([byte](($v -shr 8) -band 0xFF));  $w.Add([byte]($v -band 0xFF))
}
function Nbt-PutStr($w, $s) {
  $bs = [Text.Encoding]::UTF8.GetBytes($s)
  Nbt-PutU16 $w $bs.Length
  foreach ($x in $bs) { $w.Add($x) }
}
function Nbt-WriteValue($w, $t, $v) {
  switch ($t) {
    { $_ -in 1,2,3,4,5,6 } { foreach ($x in $v) { $w.Add($x) }; return }
    7  { Nbt-PutI32 $w $v.len; foreach ($x in $v.data) { $w.Add($x) }; return }
    8  { Nbt-PutStr $w $v; return }
    9  {
         $w.Add([byte]$v.elem); Nbt-PutI32 $w $v.items.Count
         foreach ($it in $v.items) { Nbt-WriteValue $w $v.elem $it }
         return
       }
    10 {
         foreach ($k in $v.Keys) {
           $w.Add([byte]$v[$k].t); Nbt-PutStr $w $k; Nbt-WriteValue $w $v[$k].t $v[$k].v
         }
         $w.Add([byte]0); return
       }
    11 { Nbt-PutI32 $w $v.len; foreach ($x in $v.data) { $w.Add($x) }; return }
    12 { Nbt-PutI32 $w $v.len; foreach ($x in $v.data) { $w.Add($x) }; return }
  }
  throw "모르는 NBT 종류: $t"
}

function Add-ServerEntry($gameDir, $name, $addr) {
  $p = Join-Path $gameDir "servers.dat"
  try {
    $root = New-Object System.Collections.Specialized.OrderedDictionary
    $rootName = ""
    if (Test-Path -LiteralPath $p) {
      $b = [IO.File]::ReadAllBytes($p)
      # 압축된 파일이면 건드리지 않는다(1.21 기준으로는 압축이 없다)
      if ($b.Length -ge 2 -and $b[0] -eq 0x1F -and $b[1] -eq 0x8B) { return "압축됨" }
      $script:nbtPos = 0
      $t = Nbt-U8 $b
      if ($t -ne 10) { return "형식이 다름" }
      $rootName = Nbt-Str $b
      $root = Nbt-ReadValue $b 10
    }
    if (-not $root.Contains("servers")) {
      $root["servers"] = @{ t = 9; v = @{ elem = 10; items = @() } }
    }
    $list = $root["servers"].v
    if ($list.elem -ne 10) { $list.elem = 10 }
    foreach ($it in $list.items) {
      if ($it.Contains("ip") -and "$($it['ip'].v)" -eq $addr) { return "이미 있음" }
    }
    $entry = New-Object System.Collections.Specialized.OrderedDictionary
    $entry["name"] = @{ t = 8; v = $name }
    $entry["ip"]   = @{ t = 8; v = $addr }
    $list.items = @($list.items) + ,$entry

    $w = New-Object System.Collections.Generic.List[byte]
    $w.Add([byte]10); Nbt-PutStr $w $rootName; Nbt-WriteValue $w 10 $root
    if (Test-Path -LiteralPath $p) { [IO.File]::Copy($p, "$p.bak", $true) }
    [IO.File]::WriteAllBytes($p, $w.ToArray())
    return "넣음"
  } catch { return "실패: $($_.Exception.Message)" }
}
# ── 서버 켜기 ─────────────────────────────────────────
# 봇에 작은 창구가 열려 있다. 거기에 암호와 함께 "켜 주세요" 를 보내면 켜진다.
# 암호를 공개 파일에 넣으면 아무나 켤 수 있으므로, 친구가 처음 한 번 입력해
# 자기 PC 에 기억해 둔다.
$KeyFile = Join-Path $env:APPDATA "elly-helper-key.txt"

function Get-BotEndpoint {
  # 봇 주소가 바뀌어도 친구들이 파일을 다시 받지 않아도 되게, 주소를 따로 읽어온다.
  # 배포 목록에 적힌 것과 같을 때만 믿는다. 아니면 기본 주소를 쓴다.
  try {
    $tmp = Join-Path $env:TEMP ("bot-ep-" + [guid]::NewGuid().ToString("N") + ".txt")
    Get-ReleaseFile (Get-Rel) "bot-endpoint.txt" "$BASE/bot-endpoint.txt" $tmp
    $a = ([IO.File]::ReadAllText($tmp)).Trim()
    Remove-Item -LiteralPath $tmp -ErrorAction SilentlyContinue
    if ($a) { return $a }
  } catch { Log "  [봇 주소 확인 실패] $($_.Exception.Message)" }
  return "http://34.123.58.169:8787"
}

function Ask-Key { return (Ask-Secret "서버 켜기 암호" "서버 켜기 암호를 입력해 주세요." "엘리에게 받으신 암호입니다. 한 번만 입력하시면 됩니다.") }

function Ask-Secret($winTitle, $line1, $line2) {
  $d = New-Object System.Windows.Forms.Form
  $d.Text = $winTitle
  $d.Size = New-Object System.Drawing.Size(460, 210)
  $d.StartPosition = "CenterParent"; $d.FormBorderStyle = "FixedDialog"
  $d.MaximizeBox = $false; $d.MinimizeBox = $false
  $d.BackColor = [System.Drawing.Color]::FromArgb(246, 245, 241)
  $d.Font = New-Object System.Drawing.Font("맑은 고딕", 9)
  $d.Icon = $script:WinIcon

  $l1 = New-Object System.Windows.Forms.Label
  $l1.Text = $line1
  $l1.Location = New-Object System.Drawing.Point(18, 18)
  $l1.Size = New-Object System.Drawing.Size(410, 20)
  $l1.Font = New-Object System.Drawing.Font("맑은 고딕", 9, [System.Drawing.FontStyle]::Bold)
  $d.Controls.Add($l1)

  $l2 = New-Object System.Windows.Forms.Label
  $l2.Text = $line2
  $l2.Location = New-Object System.Drawing.Point(18, 40)
  $l2.Size = New-Object System.Drawing.Size(410, 20)
  $l2.ForeColor = [System.Drawing.Color]::FromArgb(120, 124, 115)
  $d.Controls.Add($l2)

  $tb = New-Object System.Windows.Forms.TextBox
  $tb.Location = New-Object System.Drawing.Point(18, 70)
  $tb.Size = New-Object System.Drawing.Size(410, 26)
  $tb.UseSystemPasswordChar = $true
  $d.Controls.Add($tb)

  $script:keyIn = $null
  $ok = New-Object System.Windows.Forms.Button
  $ok.Text = "확인"; $ok.Location = New-Object System.Drawing.Point(238, 112)
  $ok.Size = New-Object System.Drawing.Size(92, 30); $ok.FlatStyle = "Flat"
  $ok.BackColor = [System.Drawing.Color]::FromArgb(140, 98, 52); $ok.ForeColor = [System.Drawing.Color]::White
  $ok.Add_Click({ $script:keyIn = $tb.Text.Trim(); $d.Close() })
  $d.Controls.Add($ok)
  $no = New-Object System.Windows.Forms.Button
  $no.Text = "취소"; $no.Location = New-Object System.Drawing.Point(336, 112)
  $no.Size = New-Object System.Drawing.Size(92, 30); $no.FlatStyle = "Flat"
  $no.Add_Click({ $script:keyIn = $null; $d.Close() })
  $d.Controls.Add($no)
  $d.AcceptButton = $ok; $d.CancelButton = $no
  [void]$d.ShowDialog($script:Owner)
  $d.Dispose()
  return $script:keyIn
}

function Wake-Server {
  Set-Busy $true
  try {
    $key = $null
    if (Test-Path $KeyFile) { $key = (Get-Content $KeyFile -Encoding UTF8 | Select-Object -First 1) }
    if (-not $key) {
      $key = Ask-Key
      if (-not $key) { SetStep "취소되었습니다." 0; return }
    }
    $ep = Get-BotEndpoint
    SetStep "서버를 켜는 중입니다..." 5
    Set-BarStyle "Marquee"; 

    $r = $null
    try { $r = (Get-WebText ($ep + "/start?t=" + [uri]::EscapeDataString($key))) | ConvertFrom-Json }
    catch { SetStep "봇에 연결하지 못했습니다. 잠시 뒤 다시 눌러주세요." 0; Log "창구 연결 실패: $($_.Exception.Message)"; return }

    if (-not $r.ok) {
      if ("$($r.why)" -like "*암호*") { try { [IO.File]::Delete($KeyFile) } catch { } }
      SetStep "$($r.why)" 0
      return
    }
    if ($r.already) { SetStep "서버가 이미 켜져 있습니다. 바로 들어가시면 됩니다." 100; Update-ServerState; return }
    # 암호가 맞았으니 기억해 둔다
    try { $key | Set-Content $KeyFile -Encoding UTF8 } catch { }

    # 켜지는 데 보통 1~3분 걸린다. 접속이 열릴 때까지 지켜본다.
    $t0 = Get-Date
    while (((Get-Date) - $t0).TotalMinutes -lt 8) {
      Start-Sleep -Milliseconds 2500
      [System.Windows.Forms.Application]::DoEvents()
      $el = [int]((Get-Date) - $t0).TotalSeconds
      SetStep "서버를 켜는 중입니다... ($el 초 지남)" -1
      try {
        $st = (Get-WebText ($ep + "/status?t=" + [uri]::EscapeDataString($key))) | ConvertFrom-Json
        if ($st.ok -and $st.ready) {
          Set-BarStyle "Continuous"
          SetStep "서버가 켜졌습니다. 들어가셔도 됩니다. ($el 초 걸림)" 100
          Update-ServerState
          return
        }
      } catch { }
    }
    SetStep "8분이 지나도 접속이 열리지 않습니다. 엘리에게 알려주세요." 0
  } catch {
    SetStep "문제가 생겼습니다 — $($_.Exception.Message)" 0
  } finally {
    Set-BarStyle "Continuous"
    Set-Busy $false
  }
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
      # 도우미가 받아 둔 새 판(latest.bat)과 백업은 실행 파일이 아니다
      if ($b.Name -ieq "latest.bat" -or $b.Name -like "*.bak") { continue }
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
  # 휴대용이면 남의 PC 에 바로가기나 실행 파일을 만들지 않는다(도우미 갱신은 loader 가 USB 안에서 한다)
  if ($PortableRoot) { return }
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
      $isLatest = $false
      try { $isLatest = ([IO.Path]::GetFullPath($Launcher) -ieq [IO.Path]::GetFullPath((Join-Path $home2 "latest.bat"))) } catch { }
      if ($isLatest) { Log "실행 파일 경로가 받아 둔 새 판과 같아서 건너뜀" }
      elseif ((Rel-Sha256 $Launcher) -ne ([string]$m.files.$LauncherFile.sha256).ToLower()) {
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
if ($btnLogout) {
  $btnLogout.Add_Click({
    $acc = Join-Path $PortableRoot "prism\accounts.json"
    if (Get-Process prismlauncher -ErrorAction SilentlyContinue) { Say "프리즘 런처를 먼저 종료해 주세요."; return }
    if (Test-Path -LiteralPath $acc) {
      try { [IO.File]::Delete($acc); Say "이 PC에서 로그아웃했습니다. USB에 로그인 정보가 남지 않습니다." }
      catch { Say "로그아웃하지 못했습니다 — $($_.Exception.Message)" }
    } else { Say "저장된 로그인 정보가 없습니다." }
  })
}

if ($btnCost) {
  $btnCost.Add_Click({
    # 봇이 가동 기록을 요약해 준다. 창 안에서 바로 읽는다.
    Set-Busy $true
    try {
      $key = $null
      if (Test-Path $KeyFile) { $key = (Get-Content $KeyFile -Encoding UTF8 | Select-Object -First 1) }
      if (-not $key) { $key = Ask-Key; if (-not $key) { SetStep "취소되었습니다." 0; return } }
      SetStep "서버 비용을 불러오는 중입니다..." 0
      Set-BarStyle "Marquee"; 
      $txt = Get-WebText ((Get-BotEndpoint) + "/cost?t=" + [uri]::EscapeDataString($key))
      Set-BarStyle "Continuous"
      try { $key | Set-Content $KeyFile -Encoding UTF8 } catch { }
      Show-TextWindow "서버 비용" $txt
      SetStep "버튼을 눌러주세요" 0
    } catch {
      Set-BarStyle "Continuous"
      SetStep "비용을 불러오지 못했습니다 — $($_.Exception.Message)" 0
    } finally { Set-Busy $false }
  })
}

$btnAdmin.Add_Click({
  # 열려 있으면 닫고, 닫혀 있으면 암호를 물어 연다. 어느 쪽이든 창을 새로 띄워
  # 버튼 구성을 다시 그린다.
  if ($IsAdmin) {
    try { [IO.File]::Delete($AdminMark) } catch { }
    Say "관리자 모드를 닫았습니다. 창을 다시 띄웁니다."
    Restart-Helper
    return
  }
  $k = Ask-Secret "관리자 모드" "관리자 암호를 입력해 주세요." "엘리만 쓰는 기능이 나타납니다."
  if (-not $k) { Say "취소되었습니다."; return }
  if ((Get-Fingerprint $k) -ne $AdminHash) { Say "암호가 맞지 않습니다."; Log "관리자 암호 틀림"; return }
  try {
    [void][IO.Directory]::CreateDirectory((Split-Path $AdminMark -Parent))
    [IO.File]::WriteAllText($AdminMark, "elly", (New-Object Text.UTF8Encoding($false)))
  } catch { Say "열지 못했습니다 — $($_.Exception.Message)"; return }
  Say "관리자 모드를 열었습니다. 창을 다시 띄웁니다."
  Restart-Helper
})

function Restart-Helper {
  try {
    $me = $MyInvocation.MyCommand.Path
    if (-not $me) { $me = $PSCommandPath }
    Start-Process powershell -ArgumentList @("-NoProfile","-ExecutionPolicy","Bypass","-WindowStyle","Hidden","-File","`"$me`"","-Launcher","`"$Launcher`"") -WindowStyle Hidden
    Start-Sleep -Milliseconds 400
    $form.Close()
  } catch { Say "창을 다시 띄우지 못했습니다. 직접 닫았다 켜주세요." }
}

$btnWake.Add_Click({ Wake-Server })
if ($btnMods) { $btnMods.Add_Click({ Install-Mods }) }
# 실행 버튼에서 오류가 나도 도우미 창은 살아 있어야 한다. 무엇이 났는지는 기록에 남긴다
$btnRun.Add_Click({
  Log "실행 버튼 누름"
  try { Start-Minecraft; Log "실행 버튼 처리 끝" }
  catch { Log "  [실행 오류] $($_.Exception.Message)"; Say "실행하지 못했습니다. 기록 보기를 눌러 나오는 내용을 서버장에게 보내주세요." }
})

$btnPatch.Add_Click({ Install-Patch })

if ($btnJoin) {
  $btnJoin.Add_Click({
    try {
      Set-Clipboard -Value $ServerAddr
      Say "주소를 복사했습니다. 마인크래프트 → 멀티플레이 → 서버 추가 에 붙여넣어 주세요."
    } catch { Say "복사하지 못했습니다. 직접 입력해 주세요: $ServerAddr" }
  })
}

# 긴 글을 창 하나로 보여준다. 비용표처럼 줄이 많은 것에 쓴다.
function Show-TextWindow($winTitle, $text) {
  $w = New-Object System.Windows.Forms.Form
  $w.Text = $winTitle
  $w.Size = New-Object System.Drawing.Size(620, 520)
  $w.StartPosition = "CenterParent"
  $w.BackColor = [System.Drawing.Color]::FromArgb(246, 245, 241)
  $w.Icon = $script:WinIcon
  $w.MinimizeBox = $false
  $box = New-Object System.Windows.Forms.TextBox
  # 표가 줄바꿈 없이 이어 붙지 않도록 자동 줄바꿈을 끄고 가로 스크롤을 준다
  $box.Multiline = $true; $box.ReadOnly = $true; $box.WordWrap = $false; $box.ScrollBars = "Both"
  $box.Location = New-Object System.Drawing.Point(18, 18)
  $box.Size = New-Object System.Drawing.Size(568, 410)
  $box.BackColor = [System.Drawing.Color]::White
  $box.BorderStyle = "FixedSingle"
  # 표가 어긋나지 않게 폭이 일정한 글꼴로
  $box.Font = New-Object System.Drawing.Font("D2Coding", 10)
  # Consolas 는 한글 폭이 영문 두 칸이 아니라 표가 밀린다. 굴림체는 윈도우에 늘 있다
  if ($box.Font.Name -ne "D2Coding") { $box.Font = New-Object System.Drawing.Font("GulimChe", 10) }
  # 봇은 LF 로만 줄을 나눈다. TextBox 는 CRLF 가 아니면 줄을 바꾸지 않는다
  $box.Text = ([string]$text) -replace "`r?`n", "`r`n"
  $box.Select(0, 0)
  $w.Controls.Add($box)
  $c = New-Object System.Windows.Forms.Button
  $c.Text = "닫기"; $c.Location = New-Object System.Drawing.Point(486, 440)
  $c.Size = New-Object System.Drawing.Size(100, 32); $c.FlatStyle = "Flat"
  $c.Add_Click({ $w.Close() })
  $w.Controls.Add($c); $w.CancelButton = $c
  [void]$w.ShowDialog($script:Owner)
  $w.Dispose()
}

function Show-Updates {
  Set-Busy $true
  try {
    SetStep "업데이트 내역을 불러오고 있습니다..." 0
    Set-BarStyle "Marquee"; 
    $raw = Get-WebText "$BASE/updates.json"
    $items = @(($raw | ConvertFrom-Json) | ForEach-Object { $_ })
  } catch {
    Set-BarStyle "Continuous"
    SetStep "업데이트 내역을 불러오지 못했습니다." 0
    Set-Busy $false
    return
  }
  Set-BarStyle "Continuous"
  SetStep "버튼을 눌러주세요" 0
  Set-Busy $false

  $w                 = New-Object System.Windows.Forms.Form
  $w.Text            = "엘리서버 업데이트 내역"
  $w.Size            = New-Object System.Drawing.Size(640, 560)
  $w.StartPosition   = "CenterParent"
  $w.BackColor       = [System.Drawing.Color]::FromArgb(246, 245, 241)
  $w.Font            = New-Object System.Drawing.Font("맑은 고딕", 9)
  $w.Icon            = $script:WinIcon
  $w.MinimizeBox     = $false

  $box               = New-Object System.Windows.Forms.TextBox
  $box.Multiline     = $true
  $box.ReadOnly      = $true
  $box.ScrollBars    = "Vertical"
  $box.Location      = New-Object System.Drawing.Point(18, 18)
  $box.Size          = New-Object System.Drawing.Size(588, 452)
  $box.BackColor     = [System.Drawing.Color]::White
  $box.BorderStyle   = "FixedSingle"
  $box.Font          = New-Object System.Drawing.Font("맑은 고딕", 9.5)

  $sb = New-Object System.Text.StringBuilder
  if ($items.Count -eq 0) { [void]$sb.AppendLine("아직 등록된 내역이 없습니다.") }
  foreach ($it in $items) {
    [void]$sb.AppendLine("──────────────────────────────────")
    [void]$sb.AppendLine("  $($it.date)   $($it.title)")
    [void]$sb.AppendLine("──────────────────────────────────")
    foreach ($ln in ("$($it.body)" -split "`n")) { [void]$sb.AppendLine("  $ln") }
    [void]$sb.AppendLine("")
  }
  $box.Text = $sb.ToString()
  $box.Select(0, 0)
  $w.Controls.Add($box)

  $close           = New-Object System.Windows.Forms.Button
  $close.Text      = "닫기"
  $close.Location  = New-Object System.Drawing.Point(506, 482)
  $close.Size      = New-Object System.Drawing.Size(100, 32)
  $close.FlatStyle = "Flat"
  $close.Add_Click({ $w.Close() })
  $w.Controls.Add($close)
  $w.CancelButton = $close
  [void]$w.ShowDialog($script:Owner)
  $w.Dispose()
}

if ($btnNews) {
  $btnNews.Add_Click({ Show-Updates })
}

if ($false) {
  $btnNews.Add_Click({
    try {
      Start-Process $NewsUrl
      Say "디스코드에서 업데이트 내역을 열었습니다."
    } catch {
      try {
        Start-Process $NewsWeb
        Say "브라우저에서 업데이트 내역을 열었습니다."
      } catch { Say "열지 못했습니다. 디스코드의 서버-업데이트 채널을 확인해 주세요." }
    }
  })
}

$btnKeys.Add_Click({
  # 단축키는 options.txt 안에 key_ 로 시작하는 줄들이다. 그 줄만 옮겨 담는다.
  # 화면·소리·언어 같은 나머지 설정은 건드리지 않는다.
  if (Test-MinecraftRunning) { Say "마인크래프트가 켜져 있습니다. 종료한 뒤 다시 눌러주세요."; return }
  $to = Get-SavedTarget
  if (-not $to) { Say "설치 위치를 먼저 정해주세요."; return }
  $from = Show-FolderPicker "단축키를 가져올 마인크래프트를 골라주세요"
  if (-not $from) { Say "취소되었습니다."; return }
  if ($from -eq $to) { Say "같은 폴더입니다. 다른 마인크래프트를 골라주세요."; return }

  $src = Join-Path $from "options.txt"
  $dst = Join-Path $to "options.txt"
  if (-not (Test-Path $src)) { Say "고르신 폴더에 설정 파일이 없습니다."; return }
  if (-not (Test-Path $dst)) { Say "지금 설치 위치에 설정 파일이 없습니다. 마인크래프트를 한 번 켰다 꺼주세요."; return }
  try {
    $sKeys = @{}
    foreach ($ln in ((([IO.File]::ReadAllText($src, [Text.Encoding]::UTF8)) -split "`r?`n"))) {
      if ($ln -like "key_*" -and $ln.Contains(":")) { $sKeys[($ln -split ':', 2)[0]] = ($ln -split ':', 2)[1] }
    }
    if ($sKeys.Count -eq 0) { Say "고르신 곳에 단축키 설정이 없습니다."; return }

    $raw  = [IO.File]::ReadAllText($dst, [Text.Encoding]::UTF8)
    $rows = $raw -split "`r?`n"
    $n = 0
    for ($k = 0; $k -lt $rows.Count; $k++) {
      if ($rows[$k] -like "key_*" -and $rows[$k].Contains(":")) {
        $nm = ($rows[$k] -split ':', 2)[0]
        if ($sKeys.ContainsKey($nm) -and $rows[$k] -ne ($nm + ":" + $sKeys[$nm])) {
          $rows[$k] = $nm + ":" + $sKeys[$nm]; $n++
        }
      }
    }
    # 저쪽에만 있는 단축키(그쪽에만 깔린 모드)는 굳이 넣지 않는다. 마크가 알아서 만든다.
    [IO.File]::Copy($dst, "$dst.bak", $true)
    [IO.File]::WriteAllText($dst, ($rows -join "`n"), (New-Object Text.UTF8Encoding($false)))
    Log "단축키 가져오기: $from -> $to ($n 개 바뀜)"
    if ($n -eq 0) { Say "이미 같은 단축키입니다. 바꿀 것이 없었습니다." }
    else { Say "단축키 $n 개를 가져왔습니다. ($(Split-Path $from -Leaf) 에서)" }
  } catch { Say "가져오지 못했습니다 — $($_.Exception.Message)" }
})


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

# ── 오른쪽 (WPF) ─────────────────────────────────────
# 위: 섬 지도 + 지금 누가 어디에 있는지. 아래: 서버 소식 · 진행도 | 접속자 현황.
# 좌표나 공략은 쓰지 않는다. 장소는 서버가 알려 주는 공개 장소 이름만 쓴다.
$right = New-Object System.Windows.Controls.Grid
[System.Windows.Controls.Grid]::SetColumn($right, 1); [void]$root.Children.Add($right)
$r0 = New-Object System.Windows.Controls.RowDefinition; $r0.Height = New-Object System.Windows.GridLength(392)
$r1 = New-Object System.Windows.Controls.RowDefinition; $r1.Height = New-Object System.Windows.GridLength(1, "Star")
$right.RowDefinitions.Add($r0); $right.RowDefinitions.Add($r1)

function New-Panel {
  $p = New-Object System.Windows.Controls.Border
  $p.CornerRadius = 14; $p.Background = Brush "#FBF8F1"; $p.BorderBrush = Brush "#E1D8C6"; $p.BorderThickness = 1
  $p.Effect = New-Object System.Windows.Media.Effects.DropShadowEffect -Property @{ BlurRadius = 8; ShadowDepth = 1.5; Opacity = 0.15; Direction = 270 }
  return $p
}

# 지도
$mapBox = New-Object System.Windows.Controls.Border
$mapBox.CornerRadius = 16; $mapBox.ClipToBounds = $true; $mapBox.Margin = New-Object System.Windows.Thickness(0, 4, 0, 12)
$mapGrid = New-Object System.Windows.Controls.Grid
$mapBox.Child = $mapGrid
$mapSrc = Get-AssetImage "map"
if ($mapSrc) {
  $mapImg = New-Object System.Windows.Controls.Image
  $mapImg.Source = $mapSrc; $mapImg.Stretch = "UniformToFill"; $mapImg.VerticalAlignment = "Center"; $mapImg.HorizontalAlignment = "Center" # Map-Point assumes a centred crop (9/29: it was top-aligned, dots sat ~57px high)
  [System.Windows.Media.RenderOptions]::SetBitmapScalingMode($mapImg, "NearestNeighbor")
  [void]$mapGrid.Children.Add($mapImg)
} else {
  # 그림이 오기 전 임시 바다와 섬
  $sea = New-Object System.Windows.Controls.Border
  $sea.Background = New-Object System.Windows.Media.LinearGradientBrush ([System.Windows.Media.ColorConverter]::ConvertFromString("#5DB2E8")), ([System.Windows.Media.ColorConverter]::ConvertFromString("#2F7FC4")), 90
  [void]$mapGrid.Children.Add($sea)
  $isl = New-Object System.Windows.Shapes.Ellipse
  $isl.Fill = Brush "#6DB54A"; $isl.Stroke = Brush "#E3CF8E"; $isl.StrokeThickness = 8
  $isl.Margin = New-Object System.Windows.Thickness(110, 110, 90, 30)
  [void]$mapGrid.Children.Add($isl)
  $ph = New-Text "섬 지도 자리 (그림이 오면 바뀝니다)" 13 "#FFFFFF" $true
  $ph.HorizontalAlignment = "Center"; $ph.VerticalAlignment = "Bottom"; $ph.Margin = New-Object System.Windows.Thickness(0, 0, 0, 12); $ph.Opacity = 0.8
  [void]$mapGrid.Children.Add($ph)
}
$mapLayer = New-Object System.Windows.Controls.Canvas
[void]$mapGrid.Children.Add($mapLayer)
# 다른 차원(네더·엔드 등)에 있는 친구는 지도 왼쪽 아래 칸에 모은다
$dimBox = New-Object System.Windows.Controls.StackPanel
$dimBox.Orientation = "Horizontal"; $dimBox.HorizontalAlignment = "Left"; $dimBox.VerticalAlignment = "Bottom"
$dimBox.Margin = New-Object System.Windows.Thickness(14, 0, 0, 6)
[void]$mapGrid.Children.Add($dimBox)
$shadow = New-Object System.Windows.Media.Effects.DropShadowEffect -Property @{ BlurRadius = 4; ShadowDepth = 1.5; Opacity = 0.75; Color = [System.Windows.Media.Colors]::Black }
$mapTitle = New-Text "지금 엘리서버에서는…" 30 "#FFFFFF" $true
$mapTitle.Effect = $shadow; $mapTitle.TextWrapping = "NoWrap"
$mapLine = New-Text "" 15 "#FFFFFF" $true
$mapLine.TextWrapping = "NoWrap"; $mapLine.TextTrimming = "CharacterEllipsis"
$mapLine.Effect = $shadow.Clone()
# 제목과 문장은 반투명 띠 위에 둔다. 지도 위 머리·이름표는 이 띠 아래에만 놓아서 글자와 겹치지 않게 한다.
$mapBand = New-Object System.Windows.Controls.Border
$mapBand.VerticalAlignment = "Top"
$bandBrush = New-Object System.Windows.Media.LinearGradientBrush
$bandBrush.StartPoint = New-Object System.Windows.Point(0, 0); $bandBrush.EndPoint = New-Object System.Windows.Point(0, 1)
$bandBrush.GradientStops.Add((New-Object System.Windows.Media.GradientStop ([System.Windows.Media.Color]::FromArgb(150, 16, 32, 52)), 0))
$bandBrush.GradientStops.Add((New-Object System.Windows.Media.GradientStop ([System.Windows.Media.Color]::FromArgb(110, 16, 32, 52)), 0.8))
$bandBrush.GradientStops.Add((New-Object System.Windows.Media.GradientStop ([System.Windows.Media.Color]::FromArgb(0, 16, 32, 52)), 1))
$mapBand.Background = $bandBrush
$mapHead = New-Object System.Windows.Controls.StackPanel
$mapHead.Margin = New-Object System.Windows.Thickness(24, 14, 190, 18); $mapHead.HorizontalAlignment = "Left"
[void]$mapHead.Children.Add($mapTitle); [void]$mapHead.Children.Add($mapLine)
$mapBand.Child = $mapHead
[void]$mapGrid.Children.Add($mapBand)
$mapPill = New-Object System.Windows.Controls.Border
$mapPill.CornerRadius = 8; $mapPill.Background = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromArgb(200, 24, 44, 68))
$mapPill.Padding = New-Object System.Windows.Thickness(12, 5, 12, 5); $mapPill.Margin = New-Object System.Windows.Thickness(0, 18, 18, 0)
$mapPill.HorizontalAlignment = "Right"; $mapPill.VerticalAlignment = "Top"
$mapCount = New-Text "" 13.5 "#FFFFFF" $false; $mapCount.TextWrapping = "NoWrap"
$mapPill.Child = $mapCount
[void]$mapGrid.Children.Add($mapPill)
[System.Windows.Controls.Grid]::SetRow($mapBox, 0); [void]$right.Children.Add($mapBox)

# 아래 두 칸
$lower = New-Object System.Windows.Controls.Grid
$l0 = New-Object System.Windows.Controls.ColumnDefinition; $l0.Width = New-Object System.Windows.GridLength(1.15, "Star")
$l1 = New-Object System.Windows.Controls.ColumnDefinition; $l1.Width = New-Object System.Windows.GridLength(1, "Star")
$lower.ColumnDefinitions.Add($l0); $lower.ColumnDefinitions.Add($l1)
[System.Windows.Controls.Grid]::SetRow($lower, 1); [void]$right.Children.Add($lower)

# 서버 소식 · 진행도
$newsPanel = New-Panel; $newsPanel.Margin = New-Object System.Windows.Thickness(0, 0, 12, 0)
[System.Windows.Controls.Grid]::SetColumn($newsPanel, 0); [void]$lower.Children.Add($newsPanel)
$newsDock = New-Object System.Windows.Controls.DockPanel; $newsDock.Margin = New-Object System.Windows.Thickness(16, 12, 10, 10)
$newsPanel.Child = $newsDock
$newsHead = New-Object System.Windows.Controls.DockPanel; $newsHead.Margin = New-Object System.Windows.Thickness(0, 0, 0, 8)
$megaphone = New-Object System.Windows.Shapes.Path
$megaphone.Data = [System.Windows.Media.Geometry]::Parse("M 1,7 L 5,7 L 15,2 L 15,18 L 5,13 L 1,13 Z M 5,13 L 7,19 L 10,19 L 8,14")
$megaphone.Stroke = Brush "#4A463D"; $megaphone.StrokeThickness = 1.6; $megaphone.Fill = Brush "#E8C07A"; $megaphone.Width = 22; $megaphone.Height = 22; $megaphone.Stretch = "Uniform"
$megaphone.Margin = New-Object System.Windows.Thickness(0, 0, 10, 0)
$mgImg = Get-AssetImage "megaphone"
if ($mgImg) { $megaphone = New-Object System.Windows.Controls.Image; $megaphone.Source = $mgImg; $megaphone.Width = 22; $megaphone.Height = 22; $megaphone.Margin = New-Object System.Windows.Thickness(0, 0, 10, 0); [System.Windows.Media.RenderOptions]::SetBitmapScalingMode($megaphone, "HighQuality") }
[void]$newsHead.Children.Add($megaphone)
$newsTitle = New-Text "소식" 17 "#2F2D28" $true; $newsTitle.TextWrapping = "NoWrap"; $newsTitle.VerticalAlignment = "Center"
[void]$newsHead.Children.Add($newsTitle)
$tabs = New-Object System.Windows.Controls.StackPanel; $tabs.Orientation = "Horizontal"; $tabs.HorizontalAlignment = "Right"
function New-Tab($text) {
  $b = New-Object System.Windows.Controls.Border
  $b.Padding = New-Object System.Windows.Thickness(12, 4, 12, 5); $b.Cursor = "Hand"; $b.BorderThickness = New-Object System.Windows.Thickness(0, 0, 0, 3); $b.Background = [System.Windows.Media.Brushes]::Transparent
  $t = New-Text $text 13 "#3B6F3E" $true; $t.TextWrapping = "NoWrap"
  $b.Child = $t
  return $b
}
$tabNotice = New-Tab "공지사항"; $tabNews = New-Tab "서버 소식"; $tabProg = New-Tab "진행도"
[void]$tabs.Children.Add($tabNotice); [void]$tabs.Children.Add($tabNews); [void]$tabs.Children.Add($tabProg)
[System.Windows.Controls.DockPanel]::SetDock($tabs, "Right"); $newsHead.Children.Insert(0, $tabs)
[System.Windows.Controls.DockPanel]::SetDock($newsHead, "Top"); [void]$newsDock.Children.Add($newsHead)
$feedScroll = New-Object System.Windows.Controls.ScrollViewer; $feedScroll.VerticalScrollBarVisibility = "Auto"
$feedNotice = New-Object System.Windows.Controls.StackPanel
$feedNews = New-Object System.Windows.Controls.StackPanel
$feedProg = New-Object System.Windows.Controls.StackPanel
$feedScroll.Content = $feedNews
[void]$newsDock.Children.Add($feedScroll)
function Select-Tab($which) {
  foreach ($p in @(@($tabNotice, "notice"), @($tabNews, "news"), @($tabProg, "prog"))) {
    $on = ($p[1] -eq $which)
    $p[0].BorderBrush = if ($on) { Brush "#3B8A45" } else { [System.Windows.Media.Brushes]::Transparent }
    $p[0].Child.Foreground = if ($on) { Brush "#2F7D3A" } else { Brush "#8A857B" }
  }
  $feedScroll.Content = switch ($which) { "notice" { $feedNotice } "news" { $feedNews } default { $feedProg } }
  $feedScroll.ScrollToTop()
}
$tabNotice.Add_MouseLeftButtonUp({ Select-Tab "notice" })
$tabNews.Add_MouseLeftButtonUp({ Select-Tab "news" })
$tabProg.Add_MouseLeftButtonUp({ Select-Tab "prog" })
Select-Tab "notice"

# ── 공지사항 ─────────────────────────────────────────
# 봇이 디스코드 엘리서버 #공지사항 글을 소식(feed.notices)에 실어 준다: [{ at, title, body }] 최근 것부터.
# 목록 한 줄: 점 · 제목 · NEW(3일 안) · 날짜(MM.DD). 줄을 누르면 본문, [더보기] 는 전체 목록 창.
function Get-Notices($feed) {
  $list = @()
  try { if ($feed -and $feed.notices) { $list = @($feed.notices | Where-Object { $_.title } | Sort-Object { [string]$_.at } -Descending) } } catch { }
  return $list
}
function Notice-Date($n) { try { return ([DateTimeOffset]::Parse([string]$n.at).LocalDateTime).ToString("MM.dd") } catch { return "" } }
function Notice-IsNew($n) { try { return (((Get-Date) - [DateTimeOffset]::Parse([string]$n.at).LocalDateTime).TotalDays -lt 3) } catch { return $false } }
function New-NoticeRow($n, $onClick) {
  $row = New-Object System.Windows.Controls.Grid; $row.Margin = New-Object System.Windows.Thickness(2, 0, 6, 9); $row.Cursor = "Hand"; $row.Background = [System.Windows.Media.Brushes]::Transparent
  foreach ($w in @(16, -1, -2, 46)) {
    $cd = New-Object System.Windows.Controls.ColumnDefinition
    if ($w -eq -1) { $cd.Width = New-Object System.Windows.GridLength(1, "Star") } elseif ($w -eq -2) { $cd.Width = [System.Windows.GridLength]::Auto } else { $cd.Width = New-Object System.Windows.GridLength($w) }
    $row.ColumnDefinitions.Add($cd)
  }
  $isNew = Notice-IsNew $n
  $dot = New-Object System.Windows.Shapes.Rectangle; $dot.Width = 8; $dot.Height = 8; $dot.RadiusX = 2; $dot.RadiusY = 2; $dot.VerticalAlignment = "Center"
  $dot.Fill = if ($isNew) { Brush "#E8736B" } else { Brush "#C9C2B4" }
  [void]$row.Children.Add($dot)
  $tt = New-Text ([string]$n.title) 13 "#2F2D28" $false; $tt.TextWrapping = "NoWrap"; $tt.TextTrimming = "CharacterEllipsis"; $tt.VerticalAlignment = "Center"
  [System.Windows.Controls.Grid]::SetColumn($tt, 1); [void]$row.Children.Add($tt)
  if ($isNew) {
    $nb = New-Object System.Windows.Controls.Border; $nb.CornerRadius = 4; $nb.Background = Brush "#F2B233"; $nb.Padding = New-Object System.Windows.Thickness(5, 0, 5, 1); $nb.Margin = New-Object System.Windows.Thickness(6, 0, 0, 0); $nb.VerticalAlignment = "Center"
    $nt = New-Text "NEW" 10 "#FFFFFF" $true; $nt.TextWrapping = "NoWrap"; $nb.Child = $nt
    [System.Windows.Controls.Grid]::SetColumn($nb, 2); [void]$row.Children.Add($nb)
  }
  $dt = New-Text (Notice-Date $n) 11.5 "#8A857B" $false; $dt.TextWrapping = "NoWrap"; $dt.HorizontalAlignment = "Right"; $dt.VerticalAlignment = "Center"
  [System.Windows.Controls.Grid]::SetColumn($dt, 3); [void]$row.Children.Add($dt)
  $row.Tag = $n
  $row.Add_MouseLeftButtonUp($onClick)
  return $row
}
# 공지 창: 왼쪽 목록, 오른쪽 본문
function Show-NoticeBody($n) {
  $body = $script:nwBody; $body.Children.Clear()
  $h = New-Text ([string]$n.title) 17 "#2F2D28" $true; [void]$body.Children.Add($h)
  $dd = New-Text ((Notice-Date $n) + $(if (Notice-IsNew $n) { "  ·  NEW" } else { "" })) 11.5 "#8A857B" $false; $dd.Margin = New-Object System.Windows.Thickness(0, 3, 0, 12); [void]$body.Children.Add($dd)
  $tx = New-Text ([string]$n.body) 13.5 "#34312A" $false; $tx.LineHeight = 21; [void]$body.Children.Add($tx)
  $script:nwScroll.ScrollToTop()
}
function Show-NoticeWindow($pick) {
  $all = Get-Notices $script:lastFeed
  if ($all.Count -eq 0) { return }
  $w = New-Object System.Windows.Window
  $w.Title = "공지사항"; $w.Width = 760; $w.Height = 520; $w.WindowStartupLocation = "CenterOwner"; $w.Owner = $form
  $w.Background = Brush "#F2ECDF"; $w.FontFamily = $UiFont; $w.ResizeMode = "CanResize"; $w.Icon = $form.Icon
  $g = New-Object System.Windows.Controls.Grid; $g.Margin = New-Object System.Windows.Thickness(14)
  $c0 = New-Object System.Windows.Controls.ColumnDefinition; $c0.Width = New-Object System.Windows.GridLength(270)
  $c1 = New-Object System.Windows.Controls.ColumnDefinition; $c1.Width = New-Object System.Windows.GridLength(1, "Star")
  $g.ColumnDefinitions.Add($c0); $g.ColumnDefinitions.Add($c1)
  $lp = New-Panel; $lp.Margin = New-Object System.Windows.Thickness(0, 0, 12, 0)
  $ls = New-Object System.Windows.Controls.ScrollViewer; $ls.VerticalScrollBarVisibility = "Auto"; $ls.Margin = New-Object System.Windows.Thickness(10)
  $lst = New-Object System.Windows.Controls.StackPanel; $ls.Content = $lst; $lp.Child = $ls
  [void]$g.Children.Add($lp)
  $rp = New-Panel; [System.Windows.Controls.Grid]::SetColumn($rp, 1)
  $rs = New-Object System.Windows.Controls.ScrollViewer; $rs.VerticalScrollBarVisibility = "Auto"; $rs.Margin = New-Object System.Windows.Thickness(18, 14, 14, 14)
  $body = New-Object System.Windows.Controls.StackPanel; $rs.Content = $body; $rp.Child = $rs
  [void]$g.Children.Add($rp)
  $script:nwBody = $body; $script:nwScroll = $rs
  foreach ($n in $all) { [void]$lst.Children.Add((New-NoticeRow $n { param($s, $e) Show-NoticeBody $s.Tag })) }
  Show-NoticeBody $(if ($pick) { $pick } else { $all[0] })
  $w.Content = $g
  [void]$w.ShowDialog()
}
function Show-Notices($feed) {
  $feedNotice.Children.Clear()
  $all = Get-Notices $feed
  if ($all.Count -eq 0) { Add-FeedNote $feedNotice "아직 공지가 없습니다."; return }
  foreach ($n in @($all | Select-Object -First 6)) { [void]$feedNotice.Children.Add((New-NoticeRow $n { param($s, $e) Show-NoticeWindow $s.Tag })) }
  $more = New-Text "더보기 >" 12 "#3B6F3E" $true; $more.HorizontalAlignment = "Right"; $more.Cursor = "Hand"; $more.Margin = New-Object System.Windows.Thickness(0, 2, 8, 0)
  $more.Add_MouseLeftButtonUp({ Show-NoticeWindow $null })
  [void]$feedNotice.Children.Add($more)
}

# 접속자 현황
$onPanel = New-Panel
[System.Windows.Controls.Grid]::SetColumn($onPanel, 1); [void]$lower.Children.Add($onPanel)
$onDock = New-Object System.Windows.Controls.DockPanel; $onDock.Margin = New-Object System.Windows.Thickness(16, 12, 12, 10)
$onPanel.Child = $onDock
$onHead = New-Object System.Windows.Controls.StackPanel; $onHead.Orientation = "Horizontal"; $onHead.Margin = New-Object System.Windows.Thickness(0, 0, 0, 10)
$people = New-Object System.Windows.Shapes.Path
$people.Data = [System.Windows.Media.Geometry]::Parse($SmallIcons.person); $people.Stroke = Brush "#4A463D"; $people.StrokeThickness = 1.6; $people.Width = 22; $people.Height = 22; $people.Stretch = "Uniform"
$people.Margin = New-Object System.Windows.Thickness(0, 0, 10, 0)
$opImg = Get-AssetImage "online_person"
if ($opImg) { $people = New-Object System.Windows.Controls.Image; $people.Source = $opImg; $people.Width = 22; $people.Height = 22; $people.Margin = New-Object System.Windows.Thickness(0, 0, 10, 0); [System.Windows.Media.RenderOptions]::SetBitmapScalingMode($people, "HighQuality") }
[void]$onHead.Children.Add($people)
$onTitle = New-Text "접속자 현황" 17 "#2F2D28" $true; $onTitle.TextWrapping = "NoWrap"
[void]$onHead.Children.Add($onTitle)
[System.Windows.Controls.DockPanel]::SetDock($onHead, "Top"); [void]$onDock.Children.Add($onHead)
$onScroll = New-Object System.Windows.Controls.ScrollViewer; $onScroll.VerticalScrollBarVisibility = "Auto"
$onList = New-Object System.Windows.Controls.StackPanel
$onScroll.Content = $onList
[void]$onDock.Children.Add($onScroll)

# ── 서버 소식 (카드 목록) ────────────────────────────
# 봇이 모아 둔 소식과 친구들 진행도를 보여준다. 서버가 꺼져 있어도 봇은 켜져 있어서
# 지난 소식이 그대로 보인다. 좌표나 공략은 봇 쪽 문장에 애초에 넣지 않는다.
# "방금 / 12분 전 / 3시간 전 / 어제 / 9월 23일"
function Format-Ago($iso) {
  try {
    $t = [DateTimeOffset]::Parse($iso).LocalDateTime
    $m = ((Get-Date) - $t).TotalMinutes
    if ($m -lt 1)  { return "방금" }
    if ($m -lt 60) { return ("{0}분 전" -f [int]$m) }
    if ($t.Date -eq (Get-Date).Date) { return ("{0}시간 전" -f [int]($m / 60)) }
    if ($t.Date -eq (Get-Date).Date.AddDays(-1)) { return "어제" }
    return $t.ToString("M월 d일")
  } catch { return "" }
}

$FeedColors = @{
  jackpot   = "#C48C14"
  shiny     = "#9650BE"
  myth_pull = "#C8463C"
  myth_all  = "#C8463C"
  dex_tier  = "#3A6E96"
}
$FeedDim = "#96918A"

# 소식 한 칸: 왼쪽 점과 세로줄, 오른쪽에 시각·본문
function Add-FeedItem($box, $when, $text, $color, $dot, $bold, $extra) {
  $g = New-Object System.Windows.Controls.Grid
  $a = New-Object System.Windows.Controls.ColumnDefinition; $a.Width = New-Object System.Windows.GridLength(22)
  $b = New-Object System.Windows.Controls.ColumnDefinition; $b.Width = New-Object System.Windows.GridLength(1, "Star")
  $g.ColumnDefinitions.Add($a); $g.ColumnDefinitions.Add($b)
  $line = New-Object System.Windows.Shapes.Rectangle; $line.Width = 2; $line.Fill = Brush "#E3DCCD"; $line.HorizontalAlignment = "Center"
  [void]$g.Children.Add($line)
  $d = New-Object System.Windows.Shapes.Ellipse; $d.Width = 11; $d.Height = 11; $d.Fill = Brush $dot; $d.VerticalAlignment = "Top"; $d.Margin = New-Object System.Windows.Thickness(0, 4, 0, 0)
  [void]$g.Children.Add($d)
  $sp = New-Object System.Windows.Controls.StackPanel; $sp.Margin = New-Object System.Windows.Thickness(6, 0, 6, 12)
  if ($when) { [void]$sp.Children.Add((New-Text $when 11 $FeedDim $false)) }
  $tb = New-Text $text 13 $color $bold; $tb.Margin = New-Object System.Windows.Thickness(0, 2, 0, 0)
  [void]$sp.Children.Add($tb)
  if ($extra) { [void]$sp.Children.Add((New-Text $extra 12 $FeedDim $false)) }
  [System.Windows.Controls.Grid]::SetColumn($sp, 1); [void]$g.Children.Add($sp)
  [void]$box.Children.Add($g)
}
function Add-FeedNote($box, $text) { $t = New-Text $text 13 $FeedDim $false; $t.Margin = New-Object System.Windows.Thickness(4, 6, 4, 6); [void]$box.Children.Add($t) }

function Show-Feed($feed, $notice) {
  $feedNews.Children.Clear()
  if ($notice) {
    Add-FeedItem $feedNews "$($notice.date)" ("새 소식 · " + $notice.title) "#3F7A36" "#4FA84A" $true (($notice.body -split "`n")[0])
  }
  $ev = @()
  if ($feed -and $feed.events) { $ev = @($feed.events | Sort-Object { $_.at } -Descending | Select-Object -First 20) }
  if ($ev.Count -eq 0) {
    Add-FeedNote $feedNews "아직 소식이 없습니다."
  } else {
    foreach ($e in $ev) {
      $c = $FeedColors[[string]$e.type]
      $ago = Format-Ago $e.at
      $dot = if ($ago -like "*분 전" -or $ago -like "*시간 전" -or $ago -eq "방금") { "#E8923A" } else { "#8A857B" }
      Add-FeedItem $feedNews $ago $e.text $(if ($c) { $c } else { "#34312A" }) $dot ([bool]$c) $null
    }
  }

  $feedProg.Children.Clear()
  $ps = @()
  if ($feed -and $feed.players) { $ps = @($feed.players | Where-Object { [int]$_.dex -gt 0 } | Sort-Object { [int]$_.dex } -Descending) }
  if ($ps.Count -eq 0) {
    Add-FeedNote $feedProg "아직 진행도가 없습니다."
  } else {
    foreach ($p in $ps) {
      $sp = New-Object System.Windows.Controls.StackPanel; $sp.Margin = New-Object System.Windows.Thickness(4, 0, 4, 12)
      $nm = New-Object System.Windows.Controls.TextBlock; $nm.FontFamily = $UiFont; $nm.TextWrapping = "Wrap"
      $r1 = New-Object System.Windows.Documents.Run($p.name); $r1.FontSize = 14.5; $r1.FontWeight = "Bold"; $r1.Foreground = Brush "#2F2D28"
      [void]$nm.Inlines.Add($r1)
      if ($p.title) { $r2 = New-Object System.Windows.Documents.Run("  「" + $p.title + "」"); $r2.FontSize = 12.5; $r2.FontWeight = "Bold"; $r2.Foreground = Brush "#C8463C"; [void]$nm.Inlines.Add($r2) }
      [void]$sp.Children.Add($nm)
      [void]$sp.Children.Add((New-Text ("도감 {0:N0}칸 · 등급 점수 {1:N0}점 · 신화 {2}/150" -f [int]$p.dex, [int]$p.points, [int]$p.myth) 12.5 "#34312A" $false))
      if ($p.bonus) { [void]$sp.Children.Add((New-Text ("받는 능력치: " + $p.bonus) 12 $FeedDim $false)) }
      # 카이 홀덤 전적. 한 판도 안 했으면 줄을 만들지 않는다.
      if ($p.kai -and [int]$p.kai.hands -gt 0) {
        $kh = [int]$p.kai.hands; $kw = [int]$p.kai.wins; $kn = [long]$p.kai.net
        $sign = if ($kn -gt 0) { "+" } elseif ($kn -lt 0) { "-" } else { "" }
        $kc = if ($kn -gt 0) { "#4F7A36" } elseif ($kn -lt 0) { "#C8463C" } else { $FeedDim }
        $kt = New-Object System.Windows.Controls.TextBlock; $kt.FontFamily = $UiFont; $kt.FontSize = 12
        $k1 = New-Object System.Windows.Documents.Run(("카이 전적 {0}판 {1}승 · 승률 {2}% · " -f $kh, $kw, [int][Math]::Round(100.0 * $kw / $kh))); $k1.Foreground = Brush "#34312A"
        $k2 = New-Object System.Windows.Documents.Run(($sign + ("{0:N0}" -f [Math]::Abs($kn)))); $k2.Foreground = Brush $kc; $k2.FontWeight = "Bold"
        [void]$kt.Inlines.Add($k1); [void]$kt.Inlines.Add($k2)
        [void]$sp.Children.Add($kt)
      }
      [void]$feedProg.Children.Add($sp)
    }
    if ($feed.updated) { Add-FeedNote $feedProg ("기준: " + (Format-Ago $feed.updated)) }
  }
  $script:lastFeed = $feed
  Show-Notices $feed
  Show-Online
}

# 봇 주소는 한 번만 물어보고 기억한다. 받는 중에 타이머가 또 부르면 건너뛴다.
$script:feedBusy = $false
$script:feedEp = $null
$script:lastFeed = $null
function Refresh-Feed {
  if ($script:feedBusy) { return }
  $script:feedBusy = $true
  try {
    $notice = $null
    # PowerShell 5.1 은 JSON 배열을 한 덩어리로 돌려줘서, 한 번 풀어낸 뒤 첫 항목을 고른다
    try { $notice = (Get-WebText "$BASE/updates.json") | ConvertFrom-Json | ForEach-Object { $_ } | Select-Object -First 1 } catch { }
    $feed = $null
    try {
      if ($env:ELLY_FEED_FILE) { $raw = Get-Content $env:ELLY_FEED_FILE -Raw -Encoding UTF8 }
      else {
        if (-not $script:feedEp) { $script:feedEp = Get-BotEndpoint }
        $raw = Get-WebText ($script:feedEp + "/feed")
      }
      $feed = $raw | ConvertFrom-Json
    } catch { Log "  [소식 불러오기 실패] $($_.Exception.Message)" }
    Show-Feed $feed $notice
    if (-not $feed) {
      $feedNews.Children.Clear(); $feedProg.Children.Clear()
      Add-FeedNote $feedNews "소식을 불러오지 못했습니다.`n잠시 뒤 다시 불러옵니다."
      Add-FeedNote $feedProg "진행도를 불러오지 못했습니다."
    }
  } finally { $script:feedBusy = $false }
}

# ── 접속자 ────────────────────────────────────────────
# 누가 들어와 있는지는 마크 서버에 직접 물어본다(서버 목록 화면이 쓰는 방법과 같다).
# 어느 장소에 있는지는 서버가 소식(feed.online)에 공개 장소 이름으로만 실어 줄 때 보여 준다.
function Ping-Players {
  $c = New-Object System.Net.Sockets.TcpClient
  try {
    $ar = $c.BeginConnect($PingHost, $PingPort, $null, $null)
    if (-not ($ar.AsyncWaitHandle.WaitOne(1500, $false) -and $c.Connected)) { return $null }
    $s = $c.GetStream(); $s.ReadTimeout = 2000
    function VarInt([int]$v) { $o = New-Object System.Collections.Generic.List[byte]; do { $b = $v -band 0x7F; $v = $v -shr 7; if ($v -ne 0) { $b = $b -bor 0x80 }; $o.Add([byte]$b) } while ($v -ne 0); return ,$o.ToArray() }
    $hb = [Text.Encoding]::UTF8.GetBytes($PingHost)
    $body = New-Object System.Collections.Generic.List[byte]
    $body.AddRange((VarInt 0)); $body.AddRange((VarInt 767)); $body.AddRange((VarInt $hb.Length)); $body.AddRange($hb)
    $body.Add([byte](($PingPort -shr 8) -band 0xFF)); $body.Add([byte]($PingPort -band 0xFF)); $body.AddRange((VarInt 1))
    $pk = New-Object System.Collections.Generic.List[byte]
    $pk.AddRange((VarInt $body.Count)); $pk.AddRange($body.ToArray()); $pk.AddRange((VarInt 1)); $pk.Add(0)
    $s.Write($pk.ToArray(), 0, $pk.Count)
    function ReadVarInt($st) { $n = 0; $sh = 0; do { $b = $st.ReadByte(); if ($b -lt 0) { throw "끊김" }; $n = $n -bor (($b -band 0x7F) -shl $sh); $sh += 7 } while ($b -band 0x80); return $n }
    [void](ReadVarInt $s); [void](ReadVarInt $s); $len = ReadVarInt $s
    $buf = New-Object byte[] $len; $got = 0
    while ($got -lt $len) { $n = $s.Read($buf, $got, $len - $got); if ($n -le 0) { break }; $got += $n }
    $j = [Text.Encoding]::UTF8.GetString($buf, 0, $got) | ConvertFrom-Json
    $names = @(); if ($j.players.sample) { $names = @($j.players.sample | ForEach-Object { [string]$_.name } | Where-Object { $_ -and $_ -notmatch '^§' }) }
    return [pscustomobject]@{ Online = [int]$j.players.online; Max = [int]$j.players.max; Names = $names }
  } catch { return $null } finally { $c.Close() }
}

# 공개 장소: 이름 → 지도 위 자리(0~1 비율)와 그림. 지도 그림이 오면 자리를 맞춘다(지금은 임시).
# X·Y 는 섬 지도 그림(map.png) 안의 자리(0~1). 그림이 없을 때는 임시 섬 위의 자리로 쓴다.
# 이름은 서버(feed_cron)가 보내는 공개 장소 이름과 같아야 한다. 자리는 섬 지도 그림에 맞춘 임시값.
$Places = [ordered]@{
  "카지노"       = @{ X = 0.81; Y = 0.55; Icon = "place_sign"; Color = "#C8463C"; Mark = "???" }
  "부두"         = @{ X = 0.64; Y = 0.57; Icon = "place_rod"; Color = "#3A7FC4"; Mark = "부" }
  "마을 광장"    = @{ X = 0.38; Y = 0.55; Icon = "place_rabbit"; Color = "#D98BB0"; Mark = "광" }
  "마을"         = @{ X = 0.40; Y = 0.38; Icon = "place_carrot"; Color = "#E8823A"; Mark = "마" }
  "언덕 마을"    = @{ X = 0.62; Y = 0.30; Icon = "place_hill"; Color = "#6C9B45"; Mark = "언" }
  "옛 카지노 섬" = @{ X = 0.14; Y = 0.25; Icon = "place_islet"; Color = "#8A6236"; Mark = "섬" }
  # (9/29 b3 지도 A안) 새 자리 — GPT 검수 review-helper-map-spots·v2 뒤 elly가 고름(호수 쉼터 섬=왼쪽 아래 작은 섬, 호수 다리=위쪽 잔교)
  "호수 쉼터 섬" = @{ X = 0.13; Y = 0.72; Icon = "place_lakeislet"; Color = "#4E9A8A"; Mark = "쉼" }
  "호수 다리"    = @{ X = 0.58; Y = 0.42; Icon = "place_bridge"; Color = "#9A7040"; Mark = "다" }
  "식당 거리"    = @{ X = 0.48; Y = 0.42; Icon = "place_diner"; Color = "#D9A13A"; Mark = "식" }
  "광산"         = @{ X = 0.52; Y = 0.73; Icon = "place_mine"; Color = "#6E6A64"; Mark = "산" }
}
# 다른 차원: 지도 위가 아니라 지도 왼쪽 아래 칸에 모아 보여 준다
$Dims = [ordered]@{
  "네더"      = @{ Icon = "dim_nether"; Color = "#8E2A1E"; Mark = "네" }
  "엔드"      = @{ Icon = "dim_end"; Color = "#4A3470"; Mark = "엔" }
  "에테르"    = @{ Icon = "dim_aether"; Color = "#4F8FC0"; Mark = "에" }
  "다른 세계" = @{ Icon = "dim_other"; Color = "#5A5A5A"; Mark = "?" }
  # 정해진 자리가 없는 곳도 같은 칸에(GPT 검수: 지도 위 점 없음)
  "섬 어딘가" = @{ Icon = "place_somewhere"; Color = "#4F6B3A"; Mark = "?" }
  "섬 지하"   = @{ Icon = "place_under"; Color = "#5A4A3A"; Mark = "굴" }
  "먼 곳"     = @{ Icon = "place_far"; Color = "#4A7AA0"; Mark = "먼" }
}
# 그림 안의 자리 → 지도 칸 위의 자리. 그림은 칸을 꽉 채우도록(UniformToFill) 가운데 기준으로 잘린다.
function Map-Point($pl, $w, $h) {
  if ($mapSrc) {
    $iw = $mapSrc.PixelWidth; $ih = $mapSrc.PixelHeight
    $sc = [Math]::Max($w / $iw, $h / $ih)
    return @((($w - $iw * $sc) / 2 + $pl.X * $iw * $sc), (($h - $ih * $sc) / 2 + $pl.Y * $ih * $sc))
  }
  return @(($w * $pl.X), ($h * $pl.Y))
}

# 친구 머리: 모장 공식 경로로 스킨을 받아 얼굴(8×8)과 모자층을 겹친다. 하루 한 번만 받는다.
$HeadDir = Join-Path (Join-Path $env:APPDATA $AppHome) "heads"
function Get-SteveFace {
  $px = @("2B1E0D","2B1E0D","2B1E0D","2B1E0D","2B1E0D","2B1E0D","2B1E0D","2B1E0D",
          "2B1E0D","2B1E0D","2B1E0D","2B1E0D","2B1E0D","2B1E0D","2B1E0D","2B1E0D",
          "2B1E0D","B4846D","B4846D","B4846D","B4846D","B4846D","B4846D","2B1E0D",
          "B4846D","B4846D","B4846D","B4846D","B4846D","B4846D","B4846D","B4846D",
          "B4846D","FFFFFF","523D89","B4846D","B4846D","523D89","FFFFFF","B4846D",
          "AA7D66","B4846D","B4846D","6A4030","6A4030","B4846D","B4846D","AA7D66",
          "AA7D66","AA7D66","6A4030","B4846D","B4846D","6A4030","AA7D66","AA7D66",
          "AA7D66","AA7D66","6A4030","6A4030","6A4030","6A4030","AA7D66","AA7D66")
  $bmp = New-Object System.Drawing.Bitmap(8, 8)
  for ($i = 0; $i -lt 64; $i++) { $bmp.SetPixel($i % 8, [Math]::Floor($i / 8), [System.Drawing.ColorTranslator]::FromHtml("#" + $px[$i])) }
  return $bmp
}
function To-ImageSource([System.Drawing.Bitmap]$bmp) {
  $ms = New-Object System.IO.MemoryStream
  $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png); $ms.Position = 0
  $bi = New-Object System.Windows.Media.Imaging.BitmapImage
  $bi.BeginInit(); $bi.CacheOption = "OnLoad"; $bi.StreamSource = $ms; $bi.EndInit(); $bi.Freeze()
  return $bi
}
$script:headMem = @{}
function Get-Head($name) {
  if ($script:headMem.ContainsKey($name)) { return $script:headMem[$name] }
  $face = $null
  try {
    [void][IO.Directory]::CreateDirectory($HeadDir)
    $safe = ($name -replace '[^A-Za-z0-9_]', '_')
    $cache = Join-Path $HeadDir ($safe + ".png"); $miss = Join-Path $HeadDir ($safe + ".none")
    $fresh = { param($p) (Test-Path -LiteralPath $p) -and (((Get-Date) - (Get-Item -LiteralPath $p).LastWriteTime).TotalHours -lt 24) }
    if (& $fresh $cache) { $face = New-Object System.Drawing.Bitmap((New-Object System.Drawing.Bitmap($cache))) }
    elseif (-not (& $fresh $miss)) {
      try {
        $id = ((Get-WebText ("https://api.mojang.com/users/profiles/minecraft/" + [uri]::EscapeDataString($name))) | ConvertFrom-Json).id
        $prof = (Get-WebText ("https://sessionserver.mojang.com/session/minecraft/profile/" + $id)) | ConvertFrom-Json
        $tex = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String((@($prof.properties) | Where-Object { $_.name -eq "textures" } | Select-Object -First 1).value)) | ConvertFrom-Json
        $url = [string]$tex.textures.SKIN.url
        if ($url -notmatch '^https?://textures\.minecraft\.net/') { throw "스킨 주소가 공식 주소가 아닙니다" }
        $tmp = Join-Path $env:TEMP ("skin-" + [guid]::NewGuid().ToString("N") + ".png")
        Get-Web ($url -replace '^http:', 'https:') $tmp
        $skin = New-Object System.Drawing.Bitmap($tmp)
        $face = New-Object System.Drawing.Bitmap(8, 8)
        $g = [System.Drawing.Graphics]::FromImage($face)
        $g.InterpolationMode = "NearestNeighbor"; $g.PixelOffsetMode = "Half"
        $g.DrawImage($skin, (New-Object System.Drawing.Rectangle(0, 0, 8, 8)), (New-Object System.Drawing.Rectangle(8, 8, 8, 8)), "Pixel")
        # 옛 스킨은 모자층이 불투명한 검정으로 채워져 있기도 하다. 마크처럼 전부 불투명하면 모자층을 쓰지 않는다
        $hatSolid = $true
        for ($hy = 8; $hy -lt 16 -and $hatSolid; $hy++) { for ($hx = 40; $hx -lt 48; $hx++) { if ($skin.GetPixel($hx, $hy).A -lt 255) { $hatSolid = $false; break } } }
        if (-not $hatSolid) { $g.DrawImage($skin, (New-Object System.Drawing.Rectangle(0, 0, 8, 8)), (New-Object System.Drawing.Rectangle(40, 8, 8, 8)), "Pixel") }
        $g.Dispose(); $skin.Dispose(); Remove-Item -LiteralPath $tmp -ErrorAction SilentlyContinue
        $face.Save($cache, [System.Drawing.Imaging.ImageFormat]::Png)
      } catch {
        Log "  [머리 받기 실패] $name — $($_.Exception.Message)"
        try { [IO.File]::WriteAllText($miss, "") } catch { }
      }
    }
  } catch { }
  if (-not $face) { $face = Get-SteveFace }
  $src = To-ImageSource $face; $face.Dispose()
  $script:headMem[$name] = $src
  return $src
}
function New-HeadImage($name, $size) {
  $im = New-Object System.Windows.Controls.Image
  $im.Source = Get-Head $name; $im.Width = $size; $im.Height = $size
  [System.Windows.Media.RenderOptions]::SetBitmapScalingMode($im, "NearestNeighbor")
  return $im
}

$script:lastPing = $null
$script:pingAt = $null
function Update-Online {
  $script:lastPing = Ping-Players
  $script:pingAt = Get-Date
  Show-Online
}
function Show-Online {
  $p = $script:lastPing
  $placeOf = @{}
  # 위치는 서버가 소식(feed.online)에 공개 장소 이름을 실어 줄 때만, 그것도 3분 안의 것만 쓴다(서버가 1분마다 갱신 — b3 9/29).
  # 서버 쪽이 아직 없으면 이름과 머리만 보이고, 지도 위 머리와 장소 칸은 뜨지 않는다.
  try {
    $on = if ($script:lastFeed) { $script:lastFeed.online } else { $null }
    $fresh = $false
    if ($on -and $on.at) { try { $fresh = (((Get-Date) - [DateTimeOffset]::Parse([string]$on.at).LocalDateTime).TotalMinutes -lt 3) } catch { } }
    if ($fresh -and $on.list) { foreach ($o in @($on.list)) { if ($o.name) { $placeOf[[string]$o.name] = [string]$o.place } } }
  } catch { }
  $script:placeOf = $placeOf
  $when = if ($script:pingAt) { $script:pingAt.ToString("tt h:mm", [Globalization.CultureInfo]::GetCultureInfo("ko-KR")) } else { "" }
  $onList.Children.Clear(); $mapLayer.Children.Clear(); $dimBox.Children.Clear()
  if (-not $p) {
    $mapCount.Text = "서버 꺼짐 · $when"
    $mapLine.Text = "지금은 서버가 꺼져 있습니다. [서버 켜기] 를 누르시면 켤 수 있습니다."
    Add-FeedNote $onList "서버가 꺼져 있습니다."
    return
  }
  $mapCount.Text = "접속 $($p.Online)명 · $when"
  if ($p.Online -eq 0) {
    $mapLine.Text = "지금은 접속한 사람이 없습니다."
    Add-FeedNote $onList "지금은 접속한 사람이 없습니다."
    return
  }
  $tags = @(); $byPlace = [ordered]@{}; $byDim = [ordered]@{}
  foreach ($n in $p.Names) {
    $place = $placeOf[$n]
    # 목록 한 줄: 초록 점 · 머리 · 이름 · 장소 그림 · 장소 이름
    $row = New-Object System.Windows.Controls.Grid; $row.Margin = New-Object System.Windows.Thickness(0, 0, 12, 10)
    foreach ($w in @(18, 40, -1, 34, -2)) {
      $cd = New-Object System.Windows.Controls.ColumnDefinition
      if ($w -eq -1) { $cd.Width = New-Object System.Windows.GridLength(1, "Star") } elseif ($w -eq -2) { $cd.Width = [System.Windows.GridLength]::Auto } else { $cd.Width = New-Object System.Windows.GridLength($w) }
      $row.ColumnDefinitions.Add($cd)
    }
    $dot = New-Object System.Windows.Shapes.Ellipse; $dot.Width = 9; $dot.Height = 9; $dot.Fill = Brush "#3FAE4A"; $dot.VerticalAlignment = "Center"
    [void]$row.Children.Add($dot)
    $hd = New-HeadImage $n 32; [System.Windows.Controls.Grid]::SetColumn($hd, 1); [void]$row.Children.Add($hd)
    $nt = New-Text $n 13.5 "#2F2D28" $false; $nt.TextWrapping = "NoWrap"; $nt.VerticalAlignment = "Center"; $nt.Margin = New-Object System.Windows.Thickness(4, 0, 4, 0)
    [System.Windows.Controls.Grid]::SetColumn($nt, 2); [void]$row.Children.Add($nt)
    if ($place -and $Places.Contains($place)) {
      $pl = $Places[$place]
      $pi = New-Pic $pl.Icon 26 $pl.Color $pl.Mark; $pi.VerticalAlignment = "Center"
      [System.Windows.Controls.Grid]::SetColumn($pi, 3); [void]$row.Children.Add($pi)
      $pn = New-Text $place 12.5 "#4A463D" $false; $pn.TextWrapping = "NoWrap"; $pn.VerticalAlignment = "Center"
      [System.Windows.Controls.Grid]::SetColumn($pn, 4); [void]$row.Children.Add($pn)
      if (-not $byPlace.Contains($place)) { $byPlace[$place] = @() }
      $byPlace[$place] += $n
    } elseif ($place -and $Dims.Contains($place)) {
      $dm = $Dims[$place]
      $pi = New-Pic $dm.Icon 26 $dm.Color $dm.Mark; $pi.VerticalAlignment = "Center"
      [System.Windows.Controls.Grid]::SetColumn($pi, 3); [void]$row.Children.Add($pi)
      $pn = New-Text $place 12.5 "#4A463D" $false; $pn.TextWrapping = "NoWrap"; $pn.VerticalAlignment = "Center"
      [System.Windows.Controls.Grid]::SetColumn($pn, 4); [void]$row.Children.Add($pn)
      if (-not $byDim.Contains($place)) { $byDim[$place] = @() }
      $byDim[$place] += $n
    } elseif ($placeOf.ContainsKey($n)) {
      # 서버가 위치를 알려 줬지만 공개 장소 밖(빈 값)인 경우. 지도에는 띄우지 않는다.
      $pn = New-Text "섬 어딘가" 12.5 "#8A857B" $false; $pn.TextWrapping = "NoWrap"; $pn.VerticalAlignment = "Center"
      [System.Windows.Controls.Grid]::SetColumn($pn, 4); [void]$row.Children.Add($pn)
    }
    [void]$onList.Children.Add($row)
  }
  if ($p.Online -gt $p.Names.Count) { Add-FeedNote $onList ("외 {0}명" -f ($p.Online - $p.Names.Count)) }
  # 지도 밑 문장은 한 줄. 대표 한 명을 몇 초마다 돌려 가며 보여 준다(모두 한 번씩 차례가 간다).
  $script:rotNames = @($p.Names); $script:rotOnline = $p.Online
  if ($script:rotIdx -ge $script:rotNames.Count) { $script:rotIdx = 0 }
  Set-MapLine
  # 지도 위: 장소마다 이름표 하나(같은 곳에 여럿이면 이름을 묶고 머리를 나란히)
  foreach ($place in $byPlace.Keys) {
    $who = @($byPlace[$place]); $pl = $Places[$place]
    $tag = New-Object System.Windows.Controls.StackPanel
    $bub = New-Object System.Windows.Controls.Border; $bub.CornerRadius = 4; $bub.Background = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromArgb(215, 30, 30, 30)); $bub.Padding = New-Object System.Windows.Thickness(6, 1, 6, 2); $bub.HorizontalAlignment = "Center"
    $label = if ($who.Count -le 2) { $who -join " · " } else { ($who[0..1] -join " · ") + (" 외 {0}명" -f ($who.Count - 2)) }
    $bt = New-Text $label 12 "#FFFFFF" $true; $bt.TextWrapping = "NoWrap"; $bub.Child = $bt
    [void]$tag.Children.Add($bub)
    $heads = New-Object System.Windows.Controls.StackPanel; $heads.Orientation = "Horizontal"; $heads.HorizontalAlignment = "Center"; $heads.Margin = New-Object System.Windows.Thickness(0, 3, 0, 0)
    foreach ($n in @($who | Select-Object -First 4)) { $mh = New-HeadImage $n 26; $mh.Margin = New-Object System.Windows.Thickness(1, 0, 1, 0); [void]$heads.Children.Add($mh) }
    [void]$tag.Children.Add($heads)
    $tags += ,@($tag, $pl)
    [void]$mapLayer.Children.Add($tag)
  }
  # 다른 차원 칸: 지도 왼쪽 아래에 차원마다 한 칸(이름·인원·머리)
  foreach ($dn in $byDim.Keys) {
    $who = @($byDim[$dn]); $dm = $Dims[$dn]
    $cell = New-Object System.Windows.Controls.Border
    $cell.CornerRadius = 8; $cell.Padding = New-Object System.Windows.Thickness(8, 3, 8, 4); $cell.Margin = New-Object System.Windows.Thickness(0, 0, 8, 0)
    $bc = [System.Windows.Media.ColorConverter]::ConvertFromString($dm.Color)
    $cell.Background = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromArgb(225, $bc.R, $bc.G, $bc.B))
    $cs = New-Object System.Windows.Controls.StackPanel
    $top = New-Object System.Windows.Controls.StackPanel; $top.Orientation = "Horizontal"
    $di = New-Pic $dm.Icon 18 $dm.Color $dm.Mark; $di.Margin = New-Object System.Windows.Thickness(0, 0, 5, 0); [void]$top.Children.Add($di)
    $dt = New-Text ("{0} · {1}명" -f $dn, $who.Count) 12 "#FFFFFF" $true; $dt.TextWrapping = "NoWrap"; $dt.VerticalAlignment = "Center"; [void]$top.Children.Add($dt)
    [void]$cs.Children.Add($top)
    $hs = New-Object System.Windows.Controls.StackPanel; $hs.Orientation = "Horizontal"; $hs.Margin = New-Object System.Windows.Thickness(0, 3, 0, 0)
    foreach ($n in @($who | Select-Object -First 5)) { $mh = New-HeadImage $n 18; $mh.Margin = New-Object System.Windows.Thickness(0, 0, 2, 0); $mh.ToolTip = $n; [void]$hs.Children.Add($mh) }
    [void]$cs.Children.Add($hs)
    $cell.Child = $cs
    [void]$dimBox.Children.Add($cell)
  }
  # 문장 줄 수가 늘어도 띠 아래로만: 띠 높이를 잰 뒤 머리·이름표 자리를 정한다
  $mapGrid.UpdateLayout()
  $w = $mapGrid.ActualWidth; $h = $mapGrid.ActualHeight; $floor = $mapBand.ActualHeight + 4; $placed = @()
  foreach ($t in $tags) {
    $tag = $t[0]; $pl = $t[1]; $tag.UpdateLayout()
    $tw = [Math]::Max(60, $tag.ActualWidth); $th = [Math]::Max(52, $tag.ActualHeight)
    $pt = Map-Point $pl $w $h
    $x = [Math]::Min([Math]::Max(4, $pt[0] - $tw / 2), $w - $tw - 4)
    $y = [Math]::Min([Math]::Max($floor, $pt[1] - $th), $h - $th - 4)
    # 다른 장소 이름표와 겹치면 겹치지 않을 때까지 아래로 조금씩 내린다
    $bump = 0
    while ($bump -lt 60) {
      $hit = $false
      foreach ($q in $placed) { if ($x -lt $q.R -and ($x + $tw) -gt $q.L -and $y -lt $q.B -and ($y + $th) -gt $q.T) { $hit = $true; break } }
      if (-not $hit) { break }
      $y = [Math]::Min($y + 6, $h - $th - 4); $bump++
      if ($y -ge $h - $th - 4) { $x = [Math]::Min($x + 8, $w - $tw - 4) }
    }
    $placed += [pscustomobject]@{ L = $x; T = $y; R = $x + $tw; B = $y + $th }
    [System.Windows.Controls.Canvas]::SetLeft($tag, $x); [System.Windows.Controls.Canvas]::SetTop($tag, $y)
  }
}

$script:rotNames = @(); $script:rotIdx = 0; $script:rotOnline = 0; $script:placeOf = @{}
function Set-MapLine {
  if ($script:rotNames.Count -eq 0) { return }
  $n = $script:rotNames[$script:rotIdx % $script:rotNames.Count]
  if ($script:rotOnline -le 1) {
    $pl = $script:placeOf[$n]
    $mapLine.Text = if ($pl -and ($Places.Contains($pl) -or $Dims.Contains($pl))) { "${n}님이 ${pl}에 있습니다!" } else { "${n}님이 접속해 계십니다!" }
  } else {
    $mapLine.Text = "${n}님 외 $($script:rotOnline - 1)명이 함께 놀고 있습니다!"
  }
}
$rotTimer = New-Object System.Windows.Forms.Timer
$rotTimer.Interval = 4000
$rotTimer.Add_Tick({ if ($script:rotNames.Count -gt 1) { $script:rotIdx = ($script:rotIdx + 1) % $script:rotNames.Count; Set-MapLine } })

$feedTimer = New-Object System.Windows.Forms.Timer
$feedTimer.Interval = 60000
$feedTimer.Add_Tick({ Refresh-Feed })

$srvTimer = New-Object System.Windows.Forms.Timer
$srvTimer.Interval = 15000
$srvTimer.Add_Tick({ Update-ServerState; Update-Online })
$form.Add_ContentRendered({ Tend-Launcher; Refresh-Stamps $false; Update-ServerState; Update-Online; $srvTimer.Start(); Refresh-Feed; $feedTimer.Start(); $rotTimer.Start(); if ($Notice) { Say $Notice } })
$form.Add_Closed({
  $srvTimer.Stop(); $srvTimer.Dispose(); $feedTimer.Stop(); $feedTimer.Dispose(); $rotTimer.Stop(); $rotTimer.Dispose()
  try { $script:Owner.ReleaseHandle() } catch { }
  # 휴대용: keep-login.txt 가 없으면 USB 에 로그인을 남기지 않는다. 프리즘이 아직 켜져 있으면 꺼질 때까지 기다렸다가 지운다.
  if ($PortableRoot -and -not (Test-Path -LiteralPath (Join-Path $PortableRoot "keep-login.txt"))) {
    $acc = Join-Path $PortableRoot "prism\accounts.json"
    if (Get-Process prismlauncher -ErrorAction SilentlyContinue) {
      $cmd = "Wait-Process -Name prismlauncher -ErrorAction SilentlyContinue; Remove-Item -LiteralPath '" + ($acc -replace "'", "''") + "' -Force -ErrorAction SilentlyContinue"
      try { Start-Process powershell -ArgumentList @("-NoProfile", "-WindowStyle", "Hidden", "-Command", $cmd) -WindowStyle Hidden } catch { }
    } elseif (Test-Path -LiteralPath $acc) {
      try { [IO.File]::Delete($acc) } catch { }
    }
  }
})
Update-SubText
[void]$form.ShowDialog()
