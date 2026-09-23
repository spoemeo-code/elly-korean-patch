# 엘리 마크 도우미 — 버튼 두 개짜리 창.
# 검은 창에 글자가 쏟아지면 무섭다는 말이 있어서, 클릭만 하면 되게 만든다.
# 실제 설치는 기존 스크립트(install.ps1 / mod-install.ps1)를 그대로 불러 쓴다.

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$BASE = "https://raw.githubusercontent.com/spoemeo-code/elly-korean-patch/main"

# ── 창 ────────────────────────────────────────────────
$form                = New-Object System.Windows.Forms.Form
$form.Text           = "엘리 마크 도우미"
$form.Size           = New-Object System.Drawing.Size(460, 400)
$form.StartPosition  = "CenterScreen"
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox    = $false
$form.BackColor      = [System.Drawing.Color]::FromArgb(246, 245, 241)
$form.Font           = New-Object System.Drawing.Font("맑은 고딕", 9)

$title               = New-Object System.Windows.Forms.Label
$title.Text          = "엘리 마크 도우미"
$title.Font          = New-Object System.Drawing.Font("맑은 고딕", 15, [System.Drawing.FontStyle]::Bold)
$title.ForeColor     = [System.Drawing.Color]::FromArgb(45, 48, 42)
$title.Location      = New-Object System.Drawing.Point(24, 20)
$title.Size          = New-Object System.Drawing.Size(400, 30)
$form.Controls.Add($title)

$sub                 = New-Object System.Windows.Forms.Label
$sub.Text            = "하고 싶은 걸 눌러주세요. 마인크래프트는 꺼놓고 해주세요."
$sub.ForeColor       = [System.Drawing.Color]::FromArgb(110, 114, 105)
$sub.Location        = New-Object System.Drawing.Point(25, 50)
$sub.Size            = New-Object System.Drawing.Size(400, 20)
$form.Controls.Add($sub)

function New-BigButton($text, $desc, $y, $color) {
  $b               = New-Object System.Windows.Forms.Button
  $b.Text          = "$text`n$desc"
  $b.Location      = New-Object System.Drawing.Point(24, $y)
  $b.Size          = New-Object System.Drawing.Size(396, 62)
  $b.FlatStyle     = "Flat"
  $b.BackColor     = $color
  $b.ForeColor     = [System.Drawing.Color]::White
  $b.Font          = New-Object System.Drawing.Font("맑은 고딕", 10, [System.Drawing.FontStyle]::Bold)
  $b.TextAlign     = "MiddleLeft"
  $b.Padding       = New-Object System.Windows.Forms.Padding(18, 0, 0, 0)
  $b.FlatAppearance.BorderSize = 0
  $b.Cursor        = "Hand"
  return $b
}

$btnPatch = New-BigButton "한글패치 업데이트" "모드 글자를 한글로 바꿔줘요" 88 ([System.Drawing.Color]::FromArgb(79, 122, 54))
$btnMods  = New-BigButton "서버 모드 업데이트" "잔누서버 모드를 내 마크에 맞춰줘요" 160 ([System.Drawing.Color]::FromArgb(70, 96, 130))
$form.Controls.Add($btnPatch)
$form.Controls.Add($btnMods)

# 버튼 오른쪽에 "내가 받은 날 / 서버가 올린 날"을 적는다.
# 두 날짜를 나란히 보여주면 "나 최신인가?"를 스스로 판단할 수 있다.
function New-Stamp($y) {
  $l              = New-Object System.Windows.Forms.Label
  $l.Location     = New-Object System.Drawing.Point(232, $y)
  $l.Size         = New-Object System.Drawing.Size(180, 44)
  $l.ForeColor    = [System.Drawing.Color]::FromArgb(226, 236, 214)
  $l.BackColor    = [System.Drawing.Color]::Transparent
  $l.TextAlign    = "MiddleRight"
  $l.Font         = New-Object System.Drawing.Font("맑은 고딕", 8)
  return $l
}
$stampPatch = New-Stamp 97
$stampMods  = New-Stamp 169
$btnPatch.Controls.Add($stampPatch)
$btnMods.Controls.Add($stampMods)
$stampPatch.Location = New-Object System.Drawing.Point(208, 9)
$stampMods.Location  = New-Object System.Drawing.Point(208, 9)

$log             = New-Object System.Windows.Forms.TextBox
$log.Multiline   = $true
$log.ScrollBars  = "Vertical"
$log.ReadOnly    = $true
$log.Location    = New-Object System.Drawing.Point(24, 236)
$log.Size        = New-Object System.Drawing.Size(396, 92)
$log.BackColor   = [System.Drawing.Color]::White
$log.ForeColor   = [System.Drawing.Color]::FromArgb(60, 64, 58)
$log.BorderStyle = "FixedSingle"
$log.Text        = "준비됐어요."
$form.Controls.Add($log)

$hint            = New-Object System.Windows.Forms.Label
$hint.Text       = "다른 마크 폴더에 하려면 Shift 를 누른 채 눌러주세요"
$hint.ForeColor  = [System.Drawing.Color]::FromArgb(150, 153, 145)
$hint.Location   = New-Object System.Drawing.Point(25, 334)
$hint.Size       = New-Object System.Drawing.Size(400, 18)
$form.Controls.Add($hint)

function Say($t) {
  $log.AppendText("`r`n" + $t)
  $log.SelectionStart = $log.TextLength
  $log.ScrollToCaret()
  [System.Windows.Forms.Application]::DoEvents()
}

# 설치 스크립트는 깃허브에서 받아 새 창에서 돌린다. 진행 상황이 그대로 보이고,
# 스크립트가 바뀌어도 이 파일을 다시 받을 필요가 없다.
function Run-Script($name, $label) {
  $btnPatch.Enabled = $false; $btnMods.Enabled = $false
  try {
    Say "$label 준비 중..."
    $tmp = Join-Path $env:TEMP $name
    Invoke-WebRequest -Uri "$BASE/$name" -OutFile $tmp -UseBasicParsing -TimeoutSec 60
    Say "창이 하나 열려요. 거기서 진행돼요."
    $p = Start-Process powershell -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$tmp`"") -PassThru -Wait
    Say "$label 끝났어요."
  } catch {
    Say "문제가 생겼어요: $($_.Exception.Message)"
    Say "인터넷이 되는지 확인하고 다시 눌러주세요."
  } finally {
    $btnPatch.Enabled = $true; $btnMods.Enabled = $true
  }
}

$btnPatch.Add_Click({ Run-Script "install.ps1" "한글패치"; Refresh-Stamps })
$btnMods.Add_Click({ Run-Script "mod-install.ps1" "서버 모드"; Refresh-Stamps })

# ── 내 버전 / 서버 버전 ───────────────────────────────
# 한글패치 버전은 팩 안 pack.mcmeta 의 설명에 들어 있고(예: 엘리 한글패치 · 1.21.1 · 2026-09-23),
# 서버 쪽은 배포중인 zip 의 sha1 과 내 파일의 sha1 을 맞춰 같은지 본다.
# 모드는 "팩에 있는 개수 / 내가 가진 개수"가 가장 알기 쉬운 버전 표시다.
function Get-InstalledPatchVersion {
  try {
    $t = Get-Content (Join-Path $env:APPDATA "elly-korean-patch-target.txt") -Encoding UTF8 -ErrorAction Stop | Select-Object -First 1
    $zip = Join-Path $t "resourcepacks\Elly-Korean-Patch.zip"
    if (-not (Test-Path $zip)) { return $null }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $z = [System.IO.Compression.ZipFile]::OpenRead($zip)
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

function Refresh-Stamps {
  $stampPatch.Text = "확인 중..."
  $stampMods.Text = "확인 중..."
  [System.Windows.Forms.Application]::DoEvents()

  # 한글패치
  try {
    $mine = Get-InstalledPatchVersion
    $srvSha = (Invoke-WebRequest -Uri "$BASE/Elly-Korean-Patch.zip.sha1" -UseBasicParsing -TimeoutSec 20 -Headers @{ "Cache-Control" = "no-cache" }).Content
    if ($srvSha -is [byte[]]) { $srvSha = [Text.Encoding]::UTF8.GetString($srvSha) }
    $srvSha = $srvSha.Trim()
    $same = $false
    $t = Get-Content (Join-Path $env:APPDATA "elly-korean-patch-target.txt") -Encoding UTF8 -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($t) {
      $zip = Join-Path $t "resourcepacks\Elly-Korean-Patch.zip"
      if (Test-Path $zip) { $same = ((Get-FileHash $zip -Algorithm SHA1).Hash.ToLower() -eq $srvSha) }
    }
    if (-not $mine) { $stampPatch.Text = "아직 안 받음" }
    elseif ($same)  { $stampPatch.Text = "내 버전 $mine`r`n최신이에요 ✓" }
    else            { $stampPatch.Text = "내 버전 $mine`r`n새 버전이 있어요" }
  } catch { $stampPatch.Text = "확인 실패" }

  # 서버 모드
  try {
    $cnt = 0
    for ($page = 1; $page -le 5; $page++) {
      $r = Invoke-RestMethod -Uri "https://api.github.com/repos/JannuH2/Jannu-maku-dudutown/contents/mods?per_page=100&page=$page" -Headers @{ "User-Agent" = "elly-mc-gui" } -TimeoutSec 30
      $cnt += $r.Count
      if ($r.Count -lt 100) { break }
    }
    $t2 = Get-Content (Join-Path $env:APPDATA "jannu-pack-target.txt") -Encoding UTF8 -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($t2 -and (Test-Path (Join-Path $t2 "mods"))) {
      $my = (Get-ChildItem (Join-Path $t2 "mods") -Filter *.jar -ErrorAction SilentlyContinue | Measure-Object).Count
      $stampMods.Text = "내 모드 $my 개`r`n서버 $cnt 개"
    } else {
      $stampMods.Text = "서버 모드 $cnt 개`r`n아직 안 맞췄어요"
    }
  } catch { $stampMods.Text = "확인 실패" }
}

$form.Add_Shown({ Refresh-Stamps })
[void]$form.ShowDialog()
