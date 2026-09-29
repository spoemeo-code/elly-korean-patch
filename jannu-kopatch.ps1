# 잔누 한글패치 설치기: 커스포지 인스턴스를 찾아 Elly-Korean-Patch.zip 을 resourcepacks 에 넣고 켠다.
# 받은 파일은 elly 가 서명한 manifest 의 sha256·크기와 맞을 때만 쓴다(도우미와 같은 확인).
# options.txt 는 resourcePacks 줄 하나만 고치고 \n 줄바꿈을 그대로 둔다(\r\n 이면 언어·소리 설정이 풀린다).
# 시험: -InstancesRoot <가짜 폴더> -TestAuto -CaptureTo <png> (실제 인스턴스로 시험하지 않는다)
param(
  [string]$InstancesRoot,
  [switch]$TestAuto,
  [string]$CaptureTo,
  [switch]$NoGui
)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$BASE = "https://raw.githubusercontent.com/spoemeo-code/elly-korean-patch/main"
$PatchName = "Elly-Korean-Patch-NoFont.zip"
$ReleasePubKey = '<RSAKeyValue><Modulus>uTUYzFZRiZNplu/l4TAOk/zWBNs8vsiHsA8RCicdwyHtezCk2++NsLi6TrfQL942dbTRmQiASXOEa3xqG8Gth6jMt024PlV9/mEGcyq079I8O+Uow9pPPsxe1OzidLex4ehen9G6eAAHpdqWFSjJ/CcbXqp3sLTMox5TqX/ALjyErO7xfeWASHmm9oA1PNP0O6mn06O/vpwvQkNKHPtbhqmoMl+YS6Kc9wL5XG0ob3NuQS2RylkPG0vdwmMB4cU+Pkw2Gus2ieC7nO6GcdxCmoltfUeYosOG+cJnU1OBIRuPLSN5c9PE7uxoQxJwDowNCh0JcxMIa0Mvr/1Sa0eT6/KyarWgguSzkp490od1p0UcP9qnpoRMokN359r7tQtrL4ABayCKq5jxbjA0RUoVpmIgWU0DIR3BoAQ3NE5wJc23OsTjRx8/L1R15eWDY/rjk7N3KUWVH9mHmU9rqlU6fbOJDB1GL/8few4bNy51trjsmzMThsiPdL5jSVqcshGF</Modulus><Exponent>AQAB</Exponent></RSAKeyValue>'

# ── 인스턴스 찾기 ──
function Get-InstanceRoots {
  if ($InstancesRoot) { return @($InstancesRoot) }
  $roots = @()
  try {
    $st = Get-Content -LiteralPath (Join-Path $env:APPDATA "CurseForge\storage.json") -Raw -Encoding UTF8 | ConvertFrom-Json
    $ms = $st.'minecraft-settings'; if ($ms -is [string]) { $ms = $ms | ConvertFrom-Json }
    if ($ms.minecraftRoot) { $roots += (Join-Path $ms.minecraftRoot "Instances") }
  } catch { }
  $roots += (Join-Path $env:USERPROFILE "curseforge\minecraft\Instances")
  return @($roots | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -Unique)
}
function Get-Instances {
  $list = @()
  foreach ($r in Get-InstanceRoots) {
    foreach ($d in Get-ChildItem -LiteralPath $r -Directory -ErrorAction SilentlyContinue) {
      $mi = Join-Path $d.FullName "minecraftinstance.json"; if (-not (Test-Path -LiteralPath $mi)) { continue }
      $name = $d.Name; try { $j = Get-Content -LiteralPath $mi -Raw -Encoding UTF8 | ConvertFrom-Json; if ($j.name) { $name = [string]$j.name } } catch { }
      $score = 0
      if ($name -match '잔누|jannu|마쿠|maku|두두') { $score += 2 }
      if (Test-Path -LiteralPath (Join-Path $d.FullName "packwiz.json")) { $score += 2 }
      if (Test-Path -LiteralPath (Join-Path $d.FullName "mod-sync.ps1")) { $score += 1 }
      $list += [pscustomobject]@{ Name = $name; Path = $d.FullName; Score = $score; Used = (Get-Item -LiteralPath $d.FullName).LastWriteTime }
    }
  }
  return @($list | Sort-Object @{ e = "Score"; Descending = $true }, @{ e = "Used"; Descending = $true })
}

# ── 서명 확인과 받기 ──
function Get-Text($url) { $wc = New-Object Net.WebClient; $wc.Encoding = [Text.Encoding]::UTF8; $wc.Headers.Add("User-Agent", "jannu-kopatch"); $wc.Headers.Add("Cache-Control", "no-cache"); try { return $wc.DownloadString($url) } finally { $wc.Dispose() } }
function Get-File($url, $dest) { $wc = New-Object Net.WebClient; $wc.Headers.Add("User-Agent", "jannu-kopatch"); $wc.Headers.Add("Cache-Control", "no-cache"); try { $wc.DownloadFile($url, $dest) } finally { $wc.Dispose() } }
function Get-SignedEntry {
  $t = [DateTime]::UtcNow.Ticks
  $mj = Join-Path $env:TEMP "jannu-kopatch-manifest.json"; $ms = Join-Path $env:TEMP "jannu-kopatch-manifest.sig"
  Get-File "$BASE/manifest.json?v=$t" $mj; Get-File "$BASE/manifest.sig?v=$t" $ms
  $bytes = [IO.File]::ReadAllBytes($mj)
  $csp = New-Object Security.Cryptography.CspParameters(24); $rsa = New-Object Security.Cryptography.RSACryptoServiceProvider($csp)
  try { $rsa.PersistKeyInCsp = $false; $rsa.FromXmlString($ReleasePubKey); $ok = $rsa.VerifyData($bytes, "SHA256", [Convert]::FromBase64String(([IO.File]::ReadAllText($ms)).Trim())) } finally { $rsa.Dispose() }
  if (-not $ok) { throw "배포 목록의 서명이 맞지 않습니다." }
  $m = [Text.Encoding]::UTF8.GetString($bytes) | ConvertFrom-Json
  $e = $m.files.$PatchName; if (-not $e -or -not $e.sha256) { throw "배포 목록에 한글패치가 없습니다." }
  return [pscustomobject]@{ Version = $m.version; Sha256 = ([string]$e.sha256).ToLower(); Size = [long]$e.size }
}

# ── options.txt: resourcePacks 줄만 ──
function Set-PatchOnTop([string]$line) {
  $cur = ($line -replace '^resourcePacks:', '').Trim(); $items = @()
  try { $parsed = $cur | ConvertFrom-Json; $items = @(foreach ($x in $parsed) { [string]$x }) } catch { return $line }
  $mine = "file/" + $PatchName
  $keep = @(foreach ($n in $items) { if ($n -eq $mine -or $n -match '^file/Elly-Korean-Patch([-_ ].*)?\.zip$') { continue }; $n })
  return 'resourcePacks:' + (ConvertTo-Json -InputObject ([string[]](@($keep) + @($mine))) -Compress)
}
function Enable-Patch($inst) {
  $opt = Join-Path $inst "options.txt"
  if (-not (Test-Path -LiteralPath $opt)) { return "no-options" }
  $raw = [IO.File]::ReadAllText($opt, [Text.Encoding]::UTF8)
  $nl = if ($raw -match "`r`n") { "`r`n" } else { "`n" }
  $rows = $raw -split "`r?`n"; $done = $false
  for ($k = 0; $k -lt $rows.Count; $k++) { if ($rows[$k] -like 'resourcePacks:*') { $rows[$k] = Set-PatchOnTop $rows[$k]; $done = $true; break } }
  if (-not $done) { return "no-line" }
  $out = $rows -join $nl
  if ($out -eq $raw) { return "already" }
  $bak = "$opt.before-kopatch"; if (-not (Test-Path -LiteralPath $bak)) { [IO.File]::Copy($opt, $bak, $false) }
  [IO.File]::WriteAllText($opt, $out, (New-Object Text.UTF8Encoding($false)))
  return "enabled"
}
function Test-GameRunning($inst) {
  try { foreach ($p in Get-CimInstance Win32_Process -Filter "Name='javaw.exe' OR Name='java.exe'") { if ($p.CommandLine -and $p.CommandLine.IndexOf($inst, [StringComparison]::OrdinalIgnoreCase) -ge 0) { return $true } } } catch { }
  return $false
}

if ($NoGui) { return }   # function tests dot-source the script without opening the window

# ── 화면 ──
$font = New-Object Drawing.Font("맑은 고딕", 10); $bold = New-Object Drawing.Font("맑은 고딕", 13, [Drawing.FontStyle]::Bold)
$form = New-Object Windows.Forms.Form
$form.Text = "잔누 한글패치 설치기"; $form.ClientSize = New-Object Drawing.Size(560, 420); $form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedSingle"; $form.MaximizeBox = $false; $form.Font = $font; $form.BackColor = [Drawing.Color]::FromArgb(250, 246, 238)

$title = New-Object Windows.Forms.Label; $title.Text = "잔누 한글패치 설치기"; $title.Font = $bold; $title.AutoSize = $true; $title.Location = New-Object Drawing.Point(20, 16); $form.Controls.Add($title)
$info = New-Object Windows.Forms.Label; $info.Location = New-Object Drawing.Point(22, 52); $info.Size = New-Object Drawing.Size(520, 44)
$info.Text = "한글패치를 넣을 마인크래프트를 골라 주세요.`r`n커스포지에서 찾은 마인크래프트 목록입니다. 잔누 서버용은 미리 골라 두었습니다."; $form.Controls.Add($info)
$lv = New-Object Windows.Forms.ListView; $lv.View = "Details"; $lv.FullRowSelect = $true; $lv.MultiSelect = $false; $lv.HideSelection = $false
$lv.Location = New-Object Drawing.Point(22, 100); $lv.Size = New-Object Drawing.Size(516, 170)
[void]$lv.Columns.Add("이름", 200); [void]$lv.Columns.Add("위치", 312); $form.Controls.Add($lv)
$pick = New-Object Windows.Forms.Button; $pick.Text = "다른 폴더 고르기"; $pick.Location = New-Object Drawing.Point(22, 280); $pick.Size = New-Object Drawing.Size(150, 34); $form.Controls.Add($pick)
$go = New-Object Windows.Forms.Button; $go.Text = "설치하기"; $go.Location = New-Object Drawing.Point(388, 280); $go.Size = New-Object Drawing.Size(150, 34)
$go.BackColor = [Drawing.Color]::FromArgb(232, 106, 126); $go.ForeColor = [Drawing.Color]::White; $go.FlatStyle = "Flat"; $form.Controls.Add($go)
$bar = New-Object Windows.Forms.ProgressBar; $bar.Location = New-Object Drawing.Point(22, 330); $bar.Size = New-Object Drawing.Size(516, 20); $form.Controls.Add($bar)
$status = New-Object Windows.Forms.Label; $status.Location = New-Object Drawing.Point(22, 356); $status.Size = New-Object Drawing.Size(516, 50); $form.Controls.Add($status)

$done = New-Object Windows.Forms.Panel; $done.Location = New-Object Drawing.Point(0, 0); $done.Size = $form.ClientSize; $done.BackColor = $form.BackColor; $done.Visible = $false
$dTitle = New-Object Windows.Forms.Label; $dTitle.Text = "완료되었습니다"; $dTitle.Font = New-Object Drawing.Font("맑은 고딕", 18, [Drawing.FontStyle]::Bold); $dTitle.AutoSize = $true; $dTitle.Location = New-Object Drawing.Point(20, 40); $done.Controls.Add($dTitle)
$dText = New-Object Windows.Forms.Label; $dText.Location = New-Object Drawing.Point(22, 100); $dText.Size = New-Object Drawing.Size(516, 220); $done.Controls.Add($dText)
$dClose = New-Object Windows.Forms.Button; $dClose.Text = "닫기"; $dClose.Location = New-Object Drawing.Point(388, 340); $dClose.Size = New-Object Drawing.Size(150, 34); $dClose.Add_Click({ $form.Close() }); $done.Controls.Add($dClose)
$form.Controls.Add($done); $done.BringToFront()

function Step($text, $pct) { $status.Text = $text; $bar.Value = [Math]::Max(0, [Math]::Min(100, $pct)); [Windows.Forms.Application]::DoEvents() }
function Add-Row($name, $path) { $it = New-Object Windows.Forms.ListViewItem($name); [void]$it.SubItems.Add($path); $it.Tag = $path; [void]$lv.Items.Add($it); return $it }

$found = Get-Instances
foreach ($i in $found) { [void](Add-Row $i.Name $i.Path) }
if ($lv.Items.Count -gt 0) { $lv.Items[0].Selected = $true }
if ($found.Count -eq 0) { Step "커스포지 마인크래프트를 찾지 못했습니다. [다른 폴더 고르기]로 직접 골라 주세요." 0 }
elseif ($found[0].Score -gt 0) { Step "마인크래프트 $($found.Count)개를 찾았고, 그중 잔누 서버용을 골라 두었습니다." 0 }
else { Step "마인크래프트 $($found.Count)개를 찾았습니다. 잔누 서버용인지 확인하고 골라 주세요." 0 }

$pick.Add_Click({
  $fb = New-Object Windows.Forms.FolderBrowserDialog; $fb.Description = "한글패치를 넣을 마인크래프트 폴더(mods 폴더가 있는 곳)를 골라 주세요."
  if ($fb.ShowDialog($form) -eq "OK") {
    $p = $fb.SelectedPath
    if (-not (Test-Path -LiteralPath (Join-Path $p "mods")) -and -not (Test-Path -LiteralPath (Join-Path $p "options.txt"))) {
      [void][Windows.Forms.MessageBox]::Show($form, "이 폴더에는 mods 폴더나 options.txt 가 없습니다.`r`n마인크래프트 폴더가 맞는지 확인해 주세요.", "잔누 한글패치 설치기"); return }
    $it = Add-Row (Split-Path $p -Leaf) $p; foreach ($x in $lv.Items) { $x.Selected = $false }; $it.Selected = $true; $it.EnsureVisible() } })

$doInstall = {
  if ($lv.SelectedItems.Count -eq 0) { Step "먼저 목록에서 마인크래프트를 하나 골라 주세요." 0; return }
  $inst = [string]$lv.SelectedItems[0].Tag
  if (Test-GameRunning $inst) { [void][Windows.Forms.MessageBox]::Show($form, "이 마인크래프트가 지금 켜져 있습니다.`r`n게임을 끈 뒤 다시 [설치하기]를 눌러 주세요.", "잔누 한글패치 설치기"); return }
  $go.Enabled = $false; $pick.Enabled = $false; $lv.Enabled = $false
  try {
    Step "배포 목록을 받아 서명을 확인하고 있습니다..." 10
    $e = Get-SignedEntry
    Step "한글패치를 받고 있습니다... (약 $([Math]::Round($e.Size / 1MB, 1))MB)" 30
    $tmp = Join-Path $env:TEMP ("jannu-kopatch-" + [guid]::NewGuid().ToString("N") + ".zip")
    Get-File "$BASE/$PatchName`?v=$($e.Sha256.Substring(0, 12))" $tmp
    Step "받은 파일이 배포본과 같은지 확인하고 있습니다..." 60
    if ((Get-Item -LiteralPath $tmp).Length -ne $e.Size -or (Get-FileHash -LiteralPath $tmp -Algorithm SHA256).Hash.ToLower() -ne $e.Sha256) {
      Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
      throw "받은 파일이 배포본과 다릅니다. 몇 분 뒤 다시 해 주세요." }
    Step "resourcepacks 폴더에 넣고 있습니다..." 75
    $rp = Join-Path $inst "resourcepacks"; if (-not (Test-Path -LiteralPath $rp)) { [void][IO.Directory]::CreateDirectory($rp) }
    $dst = Join-Path $rp $PatchName
    if (Test-Path -LiteralPath $dst) { [IO.File]::Copy($dst, "$dst.bak", $true) }
    [IO.File]::Copy($tmp, $dst, $true); Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
    Step "리소스팩 설정을 켜고 있습니다..." 90
    $en = Enable-Patch $inst
    Step "완료되었습니다." 100
    $how = switch ($en) {
      "enabled" { "한글패치를 리소스팩 목록 맨 위(가장 우선)로 켜 두었습니다." }
      "already" { "한글패치는 이미 켜져 있어서 설정은 그대로 두었습니다." }
      default { "아직 게임 설정 파일이 없어 자동으로 켜지 못했습니다.`r`n게임을 켠 뒤 [옵션] → [리소스 팩]에서 Elly-Korean-Patch-NoFont 를 한 번 켜 주세요." } }
    $dText.Text = "한글패치 $($e.Version)판을 넣었습니다.`r`n`r`n넣은 곳: $inst`r`n`r`n$how`r`n`r`n예전 한글패치가 있었다면 같은 폴더에 .bak 으로 남겨 두었습니다.`r`n게임이 켜져 있었다면 F3 + T 를 누르면 새 한글패치가 불러와집니다."
    foreach ($c in @($title, $info, $lv, $pick, $go, $bar, $status)) { $c.Visible = $false }
    $done.Visible = $true
  } catch {
    Step ("설치하지 못했습니다. " + $_.Exception.Message) 0
    $go.Enabled = $true; $pick.Enabled = $true; $lv.Enabled = $true }
}
$go.Add_Click($doInstall)

if ($TestAuto) {
  # test path: the form is never shown (so it cannot take focus from a running game); it is laid out and drawn into PNGs
  $snap = { param($n) $bmp = New-Object Drawing.Bitmap($form.ClientSize.Width, $form.ClientSize.Height); $form.DrawToBitmap($bmp, (New-Object Drawing.Rectangle(0, 0, $form.ClientSize.Width, $form.ClientSize.Height))); $bmp.Save(($CaptureTo -replace '.png$', "-$n.png")); $bmp.Dispose() }
  [void]$form.Handle; foreach ($c in @($lv, $go, $pick, $bar, $status, $info, $title, $done, $dTitle, $dText, $dClose)) { [void]$c.Handle }
  $form.PerformLayout()
  if ($CaptureTo) { & $snap 1 }
  & $doInstall
  if ($CaptureTo) { & $snap 2 }
  $form.Dispose(); return
}
[void]$form.ShowDialog()
