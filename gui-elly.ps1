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
  [string]$Server = "elly"
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

# ── 창 ────────────────────────────────────────────────
$form                 = New-Object System.Windows.Forms.Form
$form.Text            = $AppName
$form.Size            = New-Object System.Drawing.Size(556, 646)
$form.StartPosition   = "CenterScreen"
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox     = $false
$form.BackColor       = [System.Drawing.Color]::FromArgb(246, 245, 241)
$form.Font            = New-Object System.Drawing.Font("맑은 고딕", 9)

# 창 아이콘. 파일을 따로 받지 않아도 되게 그림을 글자로 바꿔 넣어 뒀다.
$IconB64 = "iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAYAAACqaXHeAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAACU2SURBVHhenXrXV135kp7WeNb4hr6d1ULknA855yyCQEIgAUKAQKCcQEiAAAkkJHLO6ZBzRrnT7b5xbM9aXrO8xh4/+cX2gx/84j/g81e/fTY6zVV75vqh1s6/XfVV1VdV+5wjdm7xZQ5eyUZb9wSjvYdJZJ9ia9q3cokzZiRmGE8nJxsDA+KMtq5xRhuXMF6T/Rijg3uiule/394jUa0jayqR8wfXY9Qzxx3CjB6GEGP5mQyjwSfSaOWaYHQxJBhvlhcZAwP5Th4frKM/e2j/Q9f1Y10PK6cIo4V9sPH6zavGrpo7xodlhcaOlhrj5p7ROLW2aDzi4B637uybASefNCXOvumw80iAnXu82pdzNp4pyE7Lxu0L+QgIjIGLIY3XY+HolUhJgZN3KhxNz5uLoyH1YN/ZbOvolQwqClu3MNTduYZLZ/P5zmSuk46UlEx4efly/WTYuMXAyXCCz2l66Gv8nOjXD95L/W3d42DjGo0rxcUYfliFjsormOx/hh//vIsB4wSO2NObTt4pYBRQkmAvyrlHwdEj4uCcFcGIiTyBB6UF8PAMhLVzJBWOh5VzGOw9E3l/vLpPPc9jfd+BAL3f167Zy74nhc9YOIQiLjkTI631SIxJha1HEhgZ+LWHKyz8omHNfUu7AA0w0/Pm6/2cHNznnQxLl0i4GeJx++oltNy4hKYrF9Hb3og3368gv7RCAIgxOioAdAWT+UACPR1PL/GY52yomH9AIhouFeJMahoBiIE9n7FyIBh8gb273JfANZLpuTgKr5vAM1dIra+E+zy2c4uFhX0I7lbdQEnBKXxhYSAwybCK4fmCOEZIFI46+PH9cXAU0MzW+leJAEBn+YacwMOaW2i+WobHBMI404OdN3NIyjyPI5KPTl4nDlC2ZmgLAEmxJ7iIAJLEMEokAElorb6OZqLoF8DwpKLOHtHw84uk5xJVyigvESwbKm5v5v0PKa3updi6xdHTfohOT0bOjSuwdo2CnUs8bPPiYXMmERbu0fjMJ4LrC8DaMwdr6MAeOn4vBMAxAsGR6WiquYknly+ite4O9t8sYGZpEAYCc8SWpKQiwFt7wMY5FE40LDU+Ba4MHTsib0vxMMSh9/lDTHXUIz8ji3kVpzx/KjkdYaESarE0XlLhBM+L92LUeuYKHSj8E0WTGfaRCEo8jeHv9pBZcRkWtpGw8YmBd0UaXMMSyUX0YmAsQdcccthQW7doxSn6NV3kmjUB9jBE4GH5BTRfK8XkVCe+/mENz7uf8HoiU4AAOJHI5GY7ei8gMBEGvzhkJZ+ATyAX5zkBwZFe7XzWgJe7RrSRSEJDUmh0AsIjTuB6wVm4esUQlPdG25iU0pU0F3MDtH2GvXMsojLzUdvZhKjkLBy1jULyyTzcrL4NB9dwZKekw+CfSGfwfrPnxXkCgA1T8TDgIpK+Af5RqC8rQGfTA+zS+2+/W8HlytuwciMAfJAAaA/K4qEhyQgLS0Lh2bMICZWU0BSUvPbx80VqZhKyU+MQ5hekRQGfqb11DTcuFDB0o2h4rLpfOMGW4XxYIXMxB0KesXCMRmzSKXT0PEFQ9Ekcd4pF5f1KnM4vhK9PLDKSWJFcCaqJD3SxI0dYOgT95JyIcI21WwKys3LRcu8qVtfH8eLdInZfzSDh5BnyVzyOWDmFEAB5IFmFun9APKLC4+Hu5QNrO0+mRorGDwzrf2PwwxE/Hxxxd8ff2tnhK3tfhmUSohIz0Xj/Cs5mZMLaKVyVHiEgRpciug95RlPwPQB6+B5zjEJWbhGetjXCxScBgeEnMTDSTkDS4OIeDB+mhk6iB2t5MgUdAhitfK/ZebnP1i0ed+7ewtLyIF5+vYjXXy9hZLobrr4SSeQAGzYKjnyxUkBSgbXZytIJIUmpiD59hgtoiEup+1V4HP4mLRV/l5eFL6qy8UWYB6xtwxm+0Si4XIbhgWYUF+TDyj6UIMQzPAkCAVCA/AwIukhZPW7vz7SJwVH7SJzJL8HN2zfJDxEov3YTnb3NKsyzk08ihmknnlVllrrZUX8vVi0PP8l9szV53sk7Hv3DHXj3/Sr2Xs+p8L95v4rRxR6DvYJKAY28REHJxVBY2LnieksrLj1pVMapRWnMZ16e+Dw7GA5DF+A8cwF2xZEITczAUbso5JRcwZvv1rC3P40rl8thw0iwJvqypvCBnef7XuFDIs2Xg2sAMjJPIy6J4NqEIzP7PE6fK6Rj4jA+3o3rt27CjVxTfOo0fFmVhJ/kWalCUupCo9lLqJTVztuwcviHZWB+aRgvGfrC/tsvZxCXfhbsbk0AuEYb7VxNYUpDXf2SEJl1CkU1taga6GRZEjJjBJAwbMtTYDdyDlbjebAdOAuf0iQ8aK5FREIGm5pIPHragO9+3MCbb5ZQ13if1SSKRKmF5b8EgigbHJmBgsLz6OpqRkFRGY5xzcSMXHgHJSMrpwi725OIT8shF8WTq6Rb1Yy1IwDeQak4lXtWRZKeHlau8YiMO4WNnSnsv13AO3r/eU8LAeM9Eh0+qSyDHtLPS93WcsaFAEQR4fNVVXi+Ng8Hlj+pDrZczOPGSaQYK1A0chc1g7UYHm/F7GwvZhcHEJmYBTvXSLR1N+PbH9bxzW/X0c593+AEklusUlLeY6capr8EQBSSlCm+VIHblbfw8uUsblbdZurFwtkzis9Gorf3OQYGW5RTrF2k4mjlTqqUu28KSi6WsB3W7JA1BYC45Gxs703jFZ2y82oWSVnnDpyiIsCBA4Oqo+IdPujMheJyz+Hcnbvo2F2DK0PNhgsdtfHH+fISLK8PYZelcHNjEpu7U2rRVySXlc0JnDpbCBfvWNyrq8HOyzn8+MctLK4M03t5SmlLrsPGS3uXmfG6SFimZBbgyq2r6Ol7hu9+u4pHj+vg7BWLz62CkZKWy/eO4AT7EGmgpFPVQKAx3okE4CLc/RmlAgDF0jkOaZnn8JbE9/LreRRWlNMZEUwTrWdREcDQN0rJklIibC8DTkB4LE6QAGuePYRboOQwW1NbA27euoXXzKXtFzPMp3mWkzkSi7aVHHvxdh6PnzayKpxELIea29V3MbUwhK0XRjQ/qUd04imGrQwnjDjFOz8FQPNcAi5R0Zs3r+HF/hy+freEVlYEZ0OsapjaOlrQ2dGIjKwcOEhq6s+SQ9JP58CT+ioAeE6IrqCoFHMrQ8g+X6wI1ZbpLlGlqhPtVgDIzRIFwgOOXCjQOxDZp09jYrwNfsxLZ2/OBmGxqKl7oPJIN1qXHYbrLiNh79U83ny7hC1GRsPjGmRl59DoNObtKVwoq0D5latITM8hyLH0NtvbA/LVQUg0hW0OLl0qxeBgK16/nsU7gv2ouQ5WLJHJJ89jdqYXdyuvISQ6k87ROkAVvV6h3L5viKR99mUn6RkkMwfLM422Z4eqiQCQxE7QK5Gt8AnYsomRB4WookJiUVxSimWGtW/kScWwCSfS2ZTcZRlZ1QxniO+K4S802WFa7Ms+r+3tGfGGIL1iRMwT/VZOezduXMOpMwUIi05nBIQzFKNorBCsqVxKSaPSWm/AFjs3Dw/qq9UaeySxt2Tw6zevk2zDGAHNqG+ohKe/lFgTETJyvrB0g5VTmOoOtbUSYMlqZOkss4R4nX2JTK40XNp4d790AkAOUHOzhKUilESEBMahuLScoTMM9yByAsvS6dwzqGRb+vZbArBvJA9Ma4bT2N29GTL0lOIGiQIBY3dnmiXRyM5rCa/pwbcsPy92JzFr7MXDumqcOJlD46NZQrWe4cBrDGup8YbQVBSVlmJ7fwZ7ZP992ZLMok+QiE9kYXyyk/nOblPxAJ+jsZ4coZ283lcBldoymdJgadMlxZWTeU1ItPByrRYBAoANI0CVB170NkSSUMoxNdXLB+KQV1CKCyWFqKmtojELNJbG74jhRuxQMc1gEqIY/YKRsU9g5LqAJJEikUEjdiiveE28ubM9jp6eZuTkFXK8DqWXYjny6s2MDFcxiIxNxfrWNPa5hrzjzdtF9Aw+g09AJEZH21FQdlm1y2KgEKKzZwS54j23iNetnZgWhhSW2Wg6maVYqhFBcXYPx6Nu+SAiAPgwAhgeAoKa411DUVJagb7+Z2yEInDr9m3cuHMdLc8a8UoMFACo0A5zfY/G7YnhciznJRpezmNbjOd5dcyoUFGzNUkv0pMEQcJaIuMlwWhpa2C5pLLOUaqt9mTlOe4Uh1hOiJvifeEceU7Si2tdrCjF/XvXUFVzj8CZGjV628kzVHldB0B4zcLCQ4EjLb21UwhBCud0GAkf/3jUd45JJxhBANLUAvLpSAD4yjZQpUBdUy1zLgJPmutxnbW5b7CNzEyDxDAdAAlN7suxSgMatkcARGGJiF2JEBNnyL1yLPvqmkQHr737fhnT870IjpaGKowNVJCaDn1C0zG7MMg0YtTJGpRXLGmtXY24U3UZt6pu0bN6BMSxCuTCgxOspLHwivqg8pktbO1DeJ3pwPPuhhj4BcSxmYrTACAbGx0ZIipkpB8gWsdodBEbkoJLbGmdIzHISLh6/TLGprpJdDSAhorXlXe53REuYMirc/SypIYYJ/mrK66LgCGyTQKV6iH9uVQV6dH7h1s5AMXCi/N/wolTJLAo3KupVsSrVZo5ltoFzCz2o2/4KSpulMPRoPGWkFtBSTF8wtIUj0jrLtPp0U/tYHnUg3aQCGmjAOHmxQjwi0Fj16j2QUQjDSLmIaway9ISzxG0CH6hCfDyiYJxugflFWWYmxtgPtKjW+PK02LonuS6eFlFgQkUAcRk8IHhJoP1fXWexq9tT2BxbViB8O67ZdQ0VOOYnTfSM7MQHJUGr4AETM0MsM9gJ2f2/B5H2jv3r1NvjQjFsCKWTkMYKxqPpRLIPHL0M3sFgrUNp0Xa5sCBT5oxV4LwSACQKqBKEFGUKiBcIFHg5hvDUTQRaSezMG3sYYtagvWVUYb3DLYJgIT/jgkELdRpoOoMxcOasYdFGqj1HZIh93VDxiY7CADXJQAi+wQlhxPl6ZxczgbxBCMA5RyuXpAAFWgKOOk3lpmi97RvkuJx6l565TIjIJXRQAAY1cftAvHlRxzbP7GDxReusHEMMzmYXSnLZXbxbY0EBQCZ99+nAfmAC5dcuoTyq5cwNtaGErbBKtdJZtvC+PScGC5lUIkYSQPVlgDoBuoixq2zDPYMPMHgaOvB+S2uJ+SmHWsd5Rjn9YuXLqK69i7n9mh2hqVMvy51Te6TtWWu7+x/ym5QmF2+PcSjlFHqywiQFBBecGO+e7r64ujHdvjklxY4+rkLLFl2LQnEMVt/AhGjRYCjgWFDAtRLhyWblJjEbLR1NaG2/h46ux7jxrVyMrZW40W2twiA7AsIP+PxD4lEwYZEiqQSj3Wvmt8jhjY+qSYBDuBsUSGqHlSis+8RQeS9QqCme4YnOuHiy9aaBjuyhJdfZQoEa2OylMeM7ELMLw+i6uEdxGdkICgqAUERKQiibXGn8lFcXfO+D1BtIhcRQvnKNhgnT59H31ALHj++h7rm+6ipuY3XJKBd5XWmAbtErfYzpOlFcwP+X/Ihgw+LGLq4NqLG2G5GzPXbV2Cc7+MxCVYHgLpMzPQp1rfhqC4fPu5WX2flIABMAekrMvOKMLo/ged7w2jaGEDT8gBal8fRtT2PoXfrWPvH3+p9QJpmvPqoKWNkDPMvkwA8V+FacbMcXT1POKKaFJdQ35LOjwBwX9je3IC/RgQMMXhf9Qocsngs3+306rDBtLly4yKW10i8pkiTKHrBazNLQ/CPSKe+ZHbfBNQ1VsErkKTozkmQg1A+uaNrcxAdqwMYXB3C2PooJvmOnjeUbxcw9x/faSkgY6FqHKQdZi6paYqAdHH+3tyfRkHxeSwskaiE3UUBETK+yv0PhL8oePic+fk9PiNkJ+utM5VmOC+MrYxhan8Jw6vjGCfpSrlTwHAWqH/MqZLe3pMUNK0jzdHs0jAByKC34zmsZeDcBc76jsHMf3ICI+JqfRUGd0bxfKUPTxd70LTYRelG9Uwrqhbb8PTd1HsApBRKGWRjRDCSYUEEb925rZQpLiUBSo8vLzcpoG8ll/8lg3XZo2yyn1/cGMfU6hiGVifRvT6NxzPDqOprQxmHrYSkRPg4OeJqeSHH6Fm8+mYF3f3NmF0cVGVTX/cFO8hJlmVvDmrWTAEPNja2Lq74yiaQI3w6sm5fQ+VsKx5s9uDeOmWtB1Vr3dyncFu53IG6vUEdAKaAKoMMfzU5xatv5kkJmbhUVoL6pofswJYPDFEAmBmnH3/ovL6V8J3bm0Xf5hweTQ3iLuf6spoqnDp/DiHBgXCysID1Rx/B7uNP4PDpF7D+zSc4eyqDETKpQJNqYf4OAWBcOCAoWelqCErAMXtnfH7cmw6MR2JhCeqM7WjY6EMdpX5rAI3bQ2jc0aRhexDNbyYJgHuc0cnACCAAMibayU9VbCBkcpJPXJ4eARgeaMVLAiAfFA8i4K8QCee+4RZk5mQhITkRvp4ecDx2jEZ+DKuPfgOnzz9HvLszCiMDcSk+nNsgxLo4wtPeHs3tjxQnHAZaABhhg+YRkKwiwNEzBJ9ZObIEBiM89Sxyr91C/8Y0hr5ewcA3qxj+fgMjP2xi7IctjFJkf+Yf3midoAwKeiMkUWBDw23ZB8inMA//RNy/fhUr8wPYoyHy8g95/efOy7l9GlCYlwWrX/ySHv4YvlYWyPBxR36YP85RriVHobPkFAYv5VByMUBpzUvj2HwHQy+WsSGTpCnVdJHGqG+0jY6KV6zvFcru9XIZaoe70M9npn63j9k/vcLMn19h7s+vMU+Z47GInBfZ+s+/11LAwVO+o7H5kSaIAIhYOoayf46CV0Q2UvOKcetCDhYmOQsQeTFKD8mfA0NE7hGSXN+bQlSAN+zp8dwQXzzJT0dv2RllaH9ZjpLe0jPoKTl9IB3nM9DW34aBrTlsshyq6DNb++XXi3je9QTe4enIv3MPTQsjysujv9/B4I+b6P9+FX3frigZ/G4Nw79dx+iPWxj/3Q6m/rAH4x9fYPOfCICDlEHvE6r9lfHRjkSo+mhOUpbOIUQ3AaGB/siJ9cLVnDSMdz+l0SQjEpK5Qj8nwuSzbEayz+fg4ulU9JVko0839qLJYNkqyUYvj7sLM9FQkIWa9ieYWh5l7X+/ng74C1aEpp5mXHhSi6evpvD07SQa90ZQtz2Aus1+1OqypclDckADc//x7hievJhAK0vh+L/fJwAGcoCQINth+TAqHaE2HJFZvTlAOIdxegpHbpw3MsJccTo6GE9rbmFjfUz7ocGk2M+JhO7CyjD6X66io70eXfS+uad7i2lwURa6Ck+irSADT4vPoOnBddS2PsLAZA/7DKP6qGpOggoEHl9jh1f4rBZ35ttxd6kd91Y7cZ+Mf3+jFw902TTbp9zfkOs96nzTuwkciTlbbnTzlxFSPi4mqm8CCgg2E+H+fghlrlq6xiHUzw9pQfYoyU1EV3sDWgjC5FCbmv0lzLfMjD4sm+zguuaG0DozhCclZ/C8IBPPL5zCM+4/LTuHJ2x0mutukvAeo2WiHz3s1iZZ9tTXJpPHBQD1DlM0zC4NILeoBK7B6fBNTINPSiLO115H/VovqlY6CUaXkmqWvPssfdrWZLwJiEdvx3GkqLnLGJNbASsOCNrncZZAR/nnRyx8fMNwNs4TvoYQckIIUqMDORp34TXzam6RIVV9DS11d7GyPKKalG3W7cPlapveEyMWVkcwsDKJ1ql+tDC3W8a6Ccgg2hdG0bVmxBBzfXKH97HDlK9A8sFVGW1aT98XsGfZ0goAiSfzYOEQg08sXGHvG4Ty9hrUMwWUoRQxWgGx1oUqRocCZpnCbdVSBx7uDuHI6YorxqLGJjj5kk3lTw5SCp0D4egSCGevKC30wz3xlbUfElNzWc/FUNZ15vYG67OE9cPKKxjseIQt+VBCIMRTB8rTi0pxnhPD5jenML83h5mtacxxf4EzxSq7QYkSNVOYPXtYBEiZEeaWBjHLtPIJTYWlfTicg0JR0noftdt9WshvciteJgiyr/KfPcAjdoXNe+N4sjuBJzsT6PxmkRFw96rxHMPR4OWt/RDqxYrAMujs5ApH9wikR/ogO8oVceH+LJXxuN9Qx1F0USkkQIjBy+yxW1seoOHeVYwNtKjQFYB043WR+9UUKFEh+yYx9/DPidyzRqDGGYGv3i2g/mmdmumtSdQnb11E7W4/arb6aHQvSZCDz84Ynr2YQvvrGbS/mUUbpfW1Ec9fT6Pl5RRaXnA0/3EFR84kBhovpNDIaHc4u/gyBWQOSIazqw+cXP0RyfKVEeaCno4aVNZWw53j59BYj5rGdOXEKPlIMbvE8G6+h/rKy5gea9e+BhMI84j414je+ekixsu5CWOn2h+b7YabfziO2YXAwRCG4uf3yPR9qtN7TnC72CN0EqTnNLiZjN+wM6wqQQ2jQUQnxMfCAXlxXsbiE37Ii/dCTKCb9mGUfYG9ezQs7QwI8vZGyekYrDJUX3LRq3duICopi3P2CKsAjTNTVEJ0Tz5ddz9CZXEenlbfwCSbFfGyioi/EggRYXvZTs70YF0+nzEK/KOj8KmFN70fji9s3JBSnI8ODmb937LSvJ1D0/64KoeSDhrr/7QSvAeAVSA/wWDMSzAgK9KNJc4djm4hbIo4TTES5Autl4s7HtVe4VSm/SYobe292rs4k3ce8xxopM5vHfLYHstjI0vU7fxc3Dl/BnU3yzAx0qqITSJFL2viVXPRnzffFxHjV5hmaxy/o1NT8G8/t4KVUwgs7APgFRaF+yTV/u9W0UzDVRqYmN7c2+b7uigAziZ4GLOjPRTb58V7wODtq76oyI+Yx1kZvH3DMTHZpSmuFJpWILR1N6Hi6kVMclqU+eDAEF6XH06v3ruOyMgI1JQWoKH0PK6ezWJLfZFAMCLUZMkOj/fqBv/EaHpT35+e68Xy6jAJdwpJHI7E+M+tXHHcPhh+kUmoH+9D/2/XULczqBmuk6B437SvjD8EwEEZTA1zNZ6J8UBBog/OJ3oh1N9LzQAOBMDNyQ0+gXGYWRgm+zMPqbCurDRBxjnO2c9rsLwx9pPw3mepqm2pg29sLJLiohgFZ9F5+wqqL+ThUnYGGu5exczsAHZMjdRhACTsN3enaXwfVjbHsMSJMDY9Fb/43AafHHfEUVtvAhCI83fvYvz3e2h8wXF6XWuCHnDsrVntRt1qD+pXe1G7xDLIklfF8VdKX9VSJx7wfOP2CDq/ZxWI9rE15icaIGlQkOiNlDABIEJxQVyIDzw9fXGz8h6Zd/FAUV3UgEKml09X5udl7n/wpA5xZ/Nw7+FdxCfEIC06Bk3XLqGdQNQxZwWUZ80PWNKGsM7QVsJ1VrbGSaaDmJrtJQhGjDDCAmNiabw1PrV0ojjgKzs/1n43lFXexux362jbHELbSh/6VgcxtDaEUZbKCaZM78oA6hc6UckuUQCoW+3DM76n790Kpn+3i93/xFkgM8LdeCHZB+fivQmCN3nAi+wfDEvmf0p0GBob7yIqIR1jbGAk36X2mxv7Idlljte3PkZC/gU0Pm+AcaEPXoEBsHFwQ1ZyMqrLitD+4DY66ysx0veUxvZhdLKDLN+tfiFa3RwnGNO411BFPvLFL7+wNRnvpML/CysD7Fy88aytkTPJPFYJnHxul6FpZ5flctuIvrVBNDAaJNRrOBO07E+pYUmGIJkIX/zjH/Dn//7P5ABWgaIU3wMAcjn0eLj74UvrAJxMO6G+vQnpZWafo3EMUbOQ/TlRAHQ0I6HwAu7UVeL1N0sM5x4YgoNx5DcWJFd3hMXGo+xaBZ51NWPM2If5lVH1LxPj0jDqn9UhIiUZHx1zwEdfOXDOd1byiaWj8nxMQioePr6Hfrbi8qFFkTA5YpuyTBA6GA33mQbVNL5ucxDdTLUppsrMn17C+KcXWOBo/O1/+Qf88//+HyYAWAYFAJH8BC/4kwg/PmZAcWkRS5/8YDGLixVlKL1crr7KbjJH5dO2iG60fixkJWxf3/YYsefycaXylmqM5Bve+EQbQqLC8asvbfC3n1riF/SsGGbn4Qvv0AgERMXC2TcQv7FwOPC6XP/Uyolg2POcDZzcgzE53YvRKc79w89VGio9yBlr7EQ7V/qZ4+z7aXztRj+63y1h5g8vNOPp/RmKfBt490//Dv/t//wvPQLeA1BAAML9vfGVjR+aWurVR0khJvk/kPx3p6rmLl8kn6lMBh8SOS8/dDRxYAo/mYmLN64o5TZ32eoSqBmmw6UrxXD1kdC2ViD8+it7/PqoHX5FEa8L0X2mQt4ZH1s4KuZ39vRBbHIKSi6Vqd8ExtgRDo+3KxJV7+U7hsgBNez1xfPC9B2Mjuk/7CvjNe/rILzE+n/4Dn//P//rT1NAAUAijAzwYDvsz46vQw0f8gKdnZ+x9xeCkmNzw81F5vfuoRZEZmYir/yiamE32XuvbYwzVGdULz9BD96srEBgRDjz2kmR3C/o4V8ftWfY2yswfkHDLe1dkJ2bjZGJdjrgGsakJLMiLawMqd8KJPrkLzkLbJKaljkAyeTHdrhpZxzjP+7Q8FeYpsFTv9/H9A88/nYDY6+X0LrHCfWHJQ2AC4cAiAlwQ1BolPrN7rCh0u3JS4W19XNCQOb3CFBTLGEp+eeQz9RZYxlbZzlbI8MLia5yOznTq9JilefbuhpRUnEBcSlJMASGsN0OgG9ICApLCjAw9Fz9DNbW24SGxir1o6j5u+THEnl/P0nvPqe/aoZ/7VI3ul+zTP+Rxv+4i6lv1jH9cgGLu7McwibRwmogHNH4ZuwvAchnSxzPlvhCcdGB9+UFukjJ+4tz5gqZZJ1pUnijAkWSAszNdRKc/DYo1zbJ1POc5iZn+hTAQmTyhUfSZ5Fj89ziIAcsttqsOjJszS4PoebhLY7dwyrUf/JebpcZYS30/kPW+I7FXoxzjelXizC+W8P8/hxW+P4NitzXJsYLUEyRR2/YCB1OAZkJkoI9UFt/n+Sn/TJjbqz+YqnZh8/rooykp/vY/g4wjZTSooTZWps7M0ylfvW935xEVUibGi65X84tsEIscvZYUyC+B0B+Wpfrq9xOsP5PUyTdxNhVltEVOkEcsSHpx3t61vrpeflWYNYJHgbgHFviE+Ee6Ox9otpVeYH+QjFinYupfWUMF9aPD4m8UBtkhJ3lHvP7uL/N85tT5Jk2lj+mhgLU/B4em94nOqzxnlV2nPra5lsRiQRd9HX09JD+YJLNUR0jpFq6RVM7/EjNApICyb6cBbw0ifVAZqwfGZaeI2GJJ0Q0hcSTXNRMpPQoY9S+uWImMZ03l4PnueYC+3z5yHGw9oEBXHfLtC6Pl3nP2qaspQGqv0+tZzJUe/f7fZkepXpt8JnO5X7cM5VHEQHi+dupvwQgJ8oVJdkJZN1O9bPYMD00MtnJPBwmYUmYaqBs7BiV0mtUUgOAXjIpZK7c4fNKyS05p92jKc1jMVad1+/VnpUoEBKVgUhd3zIeut9k9MF76HkxmnyywmNpq8fZYTbOtqmfxKqZAg2cBbq3h9E11y0A+BAAfxrvrQBID3XG7YqzDN059Q1gmiWvd/ApOnoeo7OnCQOjrazBnaoUCpGt0isCgAKExqiwYyuqKWsGhOwrpUVk3/yYOct1RCQtdHDWtsfVvuixQmLTjJTnZD0TAKY15J0SNdJGS5mdnO2hEzswyF7BuDCAoaV+tK/0YnBzBCOcEW7U3IRPZDiO5MQYCIA0Qj7IieEwFOSIp49ucfxdUC8Q44S1ZbvEsij/2ppgZAyQ4HoGnqpubHy6W5W1GV6TDyVLa2NY2RBF9bShqH0qqEBhPisjxID3xisA5Nh0Tr++si4ASATIPXJO1uB6JDrZLq9zgFocUjqMsk8QfUTPFZ5X91C2aYMMbk87GxF5Ih5fOTvjuLu7RIDBWCgAxBmQzUEoOdgZZeUFWKAR0vZqIfheId0g8bgcy8sXVkaU8dNz/UoJAUj+USYywWMZduS6/D6wsvHee+aGm4t2jUIQZbtMXZZWheE1XTRnjHFwGlAdoXha3ikVRdaX62oNyiaNl/8tDhGY3JJzsPHwwJeOTrCk8Tbe3hoAkgIKgCgPJIe4wYrohMTH4mHTAyJM9PZmP6CgppwuunLiEfGyKCJKznG4mVnoVwqKoqPsAOX/PkYqrz9jvra5yBraPklwnRWAuixyzdGpTrWWfIyZJzdpoJqvRRC4L3/fm1seRcWdCrgE+OFze0ccd3OHFUEQOQCgMMmP+W/AqWh3xAS7wdLVDUednHHM2QXJpzPRNdDC8GFTRDTNldPF/Jzap+fMz2s5qwEn50Vp+bo7SnKVGi+GidLm6xxeV6JGIqmzr1nxj0olk8H6/VJOZR1xmLzvweMqBMRG4QtHR1i4uB4Yrou1t5fGAQJAbqw3TkW6IczfFRZEydLdQ6H1pYMj7AwGnLtYqMJIgJCwOnjp/4eI0qL8HDu84fFOlbcrnBN+Ysyh+yW1uvufsFMkMRIM7dpP7xe9JM/b+54iPiuNee6kHCm2WB4y3tKNjhYO4Py/XpYWhPNJviRBDwQH0nBPLxUe1l5eSiw9PbmYCzw4zxddLcXIVC/zagH7bxbZwi69l7fa9uXb5fdb0zld9HPy7Eu5RpGvQuJdGZQ+dP/e60WV33sk5pfvtLXVfWb3yrVRRkZ++QXYc9L8kvrq+uu2yFbEypM20ng7Hx/8XwLk7DWYcXh8AAAAAElFTkSuQmCC"
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
# 접속 주소는 처음 한 번만 쓰므로 아래 작은 버튼으로 내렸다.
$btnJoin = $null
$btnNews = New-BigButton "업데이트 내역 보기" 212 ([System.Drawing.Color]::FromArgb(88, 80, 120))
$form.Controls.Add($btnNews)

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
$stampNews = New-Stamp
$btnNews.Controls.Add($stampNews)
$stampNews.Add_Click({ $btnNews.PerformClick() })
$stampNews.Cursor = "Hand"

# 맨 아래는 실행. 업데이트 → 실행 순서로 읽히게 둔다.
# 디스코드를 켜지 않아도 서버를 켤 수 있게 한다. 암호는 처음 한 번만 묻는다.
$btnWake = New-BigButton "서버 켜기" 274 ([System.Drawing.Color]::FromArgb(140, 98, 52))
$form.Controls.Add($btnWake)
$stampWake = New-Stamp
$btnWake.Controls.Add($stampWake)
$stampWake.Add_Click({ $btnWake.PerformClick() })
$stampWake.Cursor = "Hand"

$btnRun = New-BigButton "마인크래프트 실행" 336 ([System.Drawing.Color]::FromArgb(58, 96, 92))
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
$pathLbl.Location  = New-Object System.Drawing.Point(25, 404)
$pathLbl.Size      = New-Object System.Drawing.Size(492, 22)
$pathLbl.ForeColor = [System.Drawing.Color]::FromArgb(90, 94, 86)
$pathLbl.Font      = New-Object System.Drawing.Font("맑은 고딕", 8)
$form.Controls.Add($pathLbl)

$toolY     = 434
$btnOpen   = New-SmallButton "설치된 폴더 열기" 24 $toolY 130
$btnChange = New-SmallButton "설치 위치 바꾸기" 160 $toolY 130
$btnLog    = New-SmallButton "기록 보기" 296 $toolY 96
$btnRestore = New-SmallButton "설정 되돌리기" 24 ($toolY + 32) 140
# 새 인스턴스를 깔면 단축키가 처음 상태로 돌아간다. 쓰던 곳에서 그것만 옮겨온다.
$btnKeys   = New-SmallButton "단축키 가져오기" 398 $toolY 124
$form.Controls.Add($btnOpen)
$form.Controls.Add($btnChange)
$form.Controls.Add($btnLog)
$form.Controls.Add($btnRestore)
$form.Controls.Add($btnKeys)

$logY = 508

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
  foreach ($b in @($btnMods, $btnPatch, $btnNews, $btnRun, $btnWake, $btnOpen, $btnChange, $btnLog, $btnKeys, $btnRestore)) {
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
function Install-Patch {
  $force = Test-ShiftHeld
  Set-Busy $true
  try {
    # 한글패치는 켜둔 채로도 넣을 수 있다. 넣고 나서 F3 + T 를 누르면 바로 적용된다.
    $mcOn = Test-MinecraftRunning
    SetStep "설치할 곳을 확인하고 있습니다..." 5
    $target = Get-Target "한글패치를 어느 마인크래프트에 넣을까요?" $force
    if (-not $target) { SetStep "취소되었습니다." 0; return }

    SetStep "최신 한글패치를 받고 있습니다..." 15
    $tmp = Join-Path $env:TEMP "elly-patch-download.zip"
    Remove-Item $tmp -ErrorAction SilentlyContinue
    Get-Web $PatchUrl $tmp

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
      SetStep "한글패치를 넣었습니다. 마인크래프트에서 F3 + T 를 누르면 바로 적용됩니다. (번역 $langCount 개)" 100
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
        for ($k = 0; $k -lt $rows.Count; $k++) {
          if ($rows[$k] -like 'resourcePacks:*' -and $rows[$k] -notlike "*$PatchName*") {
            $cur = $rows[$k] -replace '^resourcePacks:', ''
            if ($cur.Trim() -eq "[]") { $rows[$k] = 'resourcePacks:[' + $entry + ']' }
            else { $rows[$k] = 'resourcePacks:' + ($cur -replace '\]\s*$', (',' + $entry + ']')) }
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
  # release.json 은 잔누 팩 전용이다(누누가 /배포완료 를 쳤을 때 찍히는 도장).
  # 엘리 팩은 내가 직접 관리하므로 늘 최신을 본다.
  $script:packRef = "refs/heads/main"
  $script:packLocked = $false

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
        $stampMods.Text = "서버 파일 $cnt 개`r`n아직 확인하지 않았습니다"
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
      $btnRun.Text = "$($lc.Name) 로 실행"
      $stampRun.Text = "바로 실행됩니다"
    } elseif ($lc) {
      $btnRun.Text = "$($lc.Name) 실행"
      $stampRun.Text = "인스턴스에서 [플레이] 를 눌러주세요"
    } else {
      $btnRun.Text = "프리즘 런처 받기"
      $stampRun.Text = "엘리서버는 프리즘 런처로 들어옵니다`r`n눌러서 받으실 수 있습니다"
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
# 엘리서버는 프리즘 런처를 쓴다. 프리즘은 인스턴스를 지정해서 바로 켤 수 있어서,
# 폴더를 찾아 들어가 [플레이] 를 누를 필요가 없다.
function Find-Prism {
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
  # 프리즘이 깔려 있으면 무조건 프리즘으로 켠다.
  $prism = Find-Prism
  if ($prism) { return @{ Kind = "prism"; Exe = $prism; Name = "프리즘 런처" } }
  if ($t -like "*multimc*") {
    $e = "$env:USERPROFILE\Documents\MultiMC\MultiMC.exe"
    if (Test-Path $e) { return @{ Kind = "prism"; Exe = $e; Name = "멀티MC" } }
  }
  if ($t -like "*modrinth*") {
    $e = "$env:LOCALAPPDATA\Programs\Modrinth App\Modrinth App.exe"
    if (Test-Path $e) { return @{ Kind = "app"; Exe = $e; Name = "모드린스" } }
  }
  if ($t -like "*curseforge*") {
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
  try {
    $a = (Get-WebText "$BASE/bot-endpoint.txt").Trim()
    if ($a) { return $a }
  } catch { }
  return "http://34.123.58.169:8787"
}

function Ask-Key {
  $d = New-Object System.Windows.Forms.Form
  $d.Text = "서버 켜기 암호"
  $d.Size = New-Object System.Drawing.Size(460, 210)
  $d.StartPosition = "CenterParent"; $d.FormBorderStyle = "FixedDialog"
  $d.MaximizeBox = $false; $d.MinimizeBox = $false
  $d.BackColor = [System.Drawing.Color]::FromArgb(246, 245, 241)
  $d.Font = New-Object System.Drawing.Font("맑은 고딕", 9)
  $d.Icon = $form.Icon

  $l1 = New-Object System.Windows.Forms.Label
  $l1.Text = "서버 켜기 암호를 입력해 주세요."
  $l1.Location = New-Object System.Drawing.Point(18, 18)
  $l1.Size = New-Object System.Drawing.Size(410, 20)
  $l1.Font = New-Object System.Drawing.Font("맑은 고딕", 9, [System.Drawing.FontStyle]::Bold)
  $d.Controls.Add($l1)

  $l2 = New-Object System.Windows.Forms.Label
  $l2.Text = "엘리에게 받으신 암호입니다. 한 번만 입력하시면 됩니다."
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
  [void]$d.ShowDialog($form)
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
    $bar.Style = "Marquee"; $bar.MarqueeAnimationSpeed = 30

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
          $bar.MarqueeAnimationSpeed = 0; $bar.Style = "Continuous"
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
    $bar.MarqueeAnimationSpeed = 0; $bar.Style = "Continuous"
    Set-Busy $false
  }
}

# ── 버튼 연결 ─────────────────────────────────────────
$btnWake.Add_Click({ Wake-Server })
$btnRun.Add_Click({ Start-Minecraft })
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

function Show-Updates {
  Set-Busy $true
  try {
    SetStep "업데이트 내역을 불러오고 있습니다..." 0
    $bar.Style = "Marquee"; $bar.MarqueeAnimationSpeed = 30
    $raw = Get-WebText "$BASE/updates.json"
    $items = @(($raw | ConvertFrom-Json) | ForEach-Object { $_ })
  } catch {
    $bar.MarqueeAnimationSpeed = 0; $bar.Style = "Continuous"
    SetStep "업데이트 내역을 불러오지 못했습니다." 0
    Set-Busy $false
    return
  }
  $bar.MarqueeAnimationSpeed = 0; $bar.Style = "Continuous"
  SetStep "버튼을 눌러주세요" 0
  Set-Busy $false

  $w                 = New-Object System.Windows.Forms.Form
  $w.Text            = "엘리서버 업데이트 내역"
  $w.Size            = New-Object System.Drawing.Size(640, 560)
  $w.StartPosition   = "CenterParent"
  $w.BackColor       = [System.Drawing.Color]::FromArgb(246, 245, 241)
  $w.Font            = New-Object System.Drawing.Font("맑은 고딕", 9)
  $w.Icon            = $form.Icon
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
  [void]$w.ShowDialog($form)
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

# 창을 켜 둔 채로도 서버 상태가 따라오게 한다
$srvTimer = New-Object System.Windows.Forms.Timer
$srvTimer.Interval = 15000
$srvTimer.Add_Tick({ Update-ServerState })
$form.Add_Shown({ Refresh-Stamps $false; $srvTimer.Start() })
$form.Add_FormClosed({ $srvTimer.Stop(); $srvTimer.Dispose() })
[void]$form.ShowDialog()
