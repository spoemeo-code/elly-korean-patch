# release 33 배포 불일치 조사 및 복구

조사 기준: 2026-10-16 KST, `main = 4d3fcba72e690c5fd55232c361f9f402c697300f`.
이 문서와 도구는 수정안이다. 운영 `manifest.json` / `manifest.sig`는 아직 변경하지 않았다.
개인키는 조회·생성·교체하지 않았다. 최종 서명은 기존 키를 가진 엘리 PC에서 해야 한다.

## 1. 확인한 사실

Git 체크아웃과 실제 `raw.githubusercontent.com/.../main/` 다운로드를 각각 검사했다.
ZIP과 sidecar, manifest 및 signature의 원격 바이트는 체크아웃과 같았다.
커밋 시각은 `2026-10-12 18:03:09 UTC + 9시간 = 2026-10-13 03:03:09 KST`이다.

| 항목 | 현재 서명 목록 | 실제 일반 ZIP / 필요한 값 |
|---|---|---|
| `version` | 32 | 33 |
| `signed_at` | `2026-10-02T11:06:24+09:00` | 엘리 PC에서 실제 서명할 때 생성 |
| SHA-256 | `ad2533fe43db58b273b8baaa6a75b15e796b0012780cb952871311fd5d7b8ba4` | `cd04d10f7feed858b2201c4b1dcc07f268895151a4fbe93186fc2d9de92aab14` |
| SHA-1 | `197fa19475a25942ef9d0ffcd38504a8320b3cc9` | `dcabf514b5ef4809e30ba583b1775f9d4cac11d7` |
| 크기 | 2,285,625바이트 | 2,286,943바이트 |

크기 차이는 `2,286,943 - 2,285,625 = 1,318`바이트이다. 해시는 ZIP 원본 바이트를 각각 SHA-256 / SHA-1으로 계산했다.
별도 `Elly-Korean-Patch.zip.sha1`은 이미 새 ZIP과 일치한다. 다시 만들 필요가 없다.

기존 `manifest.sig`는 내장된 **3072비트 RSA 공개키, SHA-256, PKCS#1 v1.5**로 검증에 성공했다.
서명이 망가진 것이 아니라, 유효한 서명이 옛 파일 목록을 보증하고 있는 상태다.
`manifest.files`의 14개 항목 중 일반 ZIP 하나만 해시·크기가 다르고, 나머지 13개는 일치했다.

release 32 ZIP과 파일 내용을 비교한 결과:

- `trial_key.json`의 마지막에 `27405 -> elly:item/vanilla_trial_key`가 추가됐다.
- `ominous_trial_key.json`의 마지막에 `26305 -> elly:item/vanilla_ominous_trial_key`가 추가됐다.
- 위 두 fallback 모델이 새로 생겼다. 두 모델 모두 `minecraft:item/generated`를 부모로 쓰고 원래 열쇠 텍스처를 가리킨다. 원본 키 모델로 되돌아가는 자기 참조는 없다.
- `pack.mcmeta`의 설명 날짜가 `2026-10-13`으로 바뀌었다. 그 외 파일 내용은 같고 삭제된 파일은 없다.
- ZIP CRC 검사 통과. 기존 마지막 값 `27404`, `26304`와 새 경계 `27405`, `26305`, 대상 `2341668`, `2341670`을 규칙 순서대로 계산해 fallback을 확인했다. 이 계산은 실제 Minecraft 렌더링 시험을 대신하지 않는다.

## 2. 배포 경로별 영향

| 경로 | 실제 흐름 | 현재 영향 |
|---|---|---|
| 서버 자동 리소스팩 | README의 URL → 서버 `resource-pack` → 클라이언트 다운로드. `mc-patch-sha.service`가 별도 `.sha1`을 읽어 `resource-pack-sha1` 동기화한다고 문서화됨 | manifest를 쓰지 않아 이번 서명 목록 불일치의 직접 영향은 없다. 서버가 새 SHA-1을 실제로 공지해야 함 |
| 엘리 도우미 실행 | `elly-helper.bat` → `loader.ps1` → 서명·버전 확인 → `gui-elly.ps1`의 SHA-256/크기 확인 | GUI와 loader는 기존 manifest와 일치하므로 이번 ZIP 불일치만으로 실행이 막히지는 않음 |
| 엘리 도우미 설치 | `gui-elly.ps1` → 일반 ZIP 다운로드 → 서명 목록의 SHA-256 비교 → ZIP 검사 → 설치 | 최신 ZIP을 받으면 해시 비교에서 거부. `배포되지 않은 한글패치라 받지 않았습니다.` / 로그 `한글패치 해시가 배포 목록과 다름` |
| 엘리 도우미 최신 표시 | 로컬 일반 ZIP SHA-1 ↔ 서명 목록의 SHA-1 | release 32 로컬 ZIP은 “최신”으로 표시될 수 있음. 수동으로 넣은 release 33 ZIP은 “최신이 아님”으로 표시될 수 있음 |
| 잔누 도우미 | `gui.ps1` → `Elly-Korean-Patch-NoFont.zip` | NoFont 해시·크기는 일치하므로 이번 일반 ZIP 불일치로 설치가 거부되지는 않음 |
| 잔누 단독 설치기 | `jannu-kopatch.ps1` → NoFont ZIP → 서명·해시·크기 검증 | 위와 동일 |

엘리 설치기는 해시 확인 실패 시 임시 ZIP을 지우고 반환한다. 기존 리소스팩 정리·덮어쓰기는 그 뒤에 있으므로, **현재 불일치로 인한 거부 단계에서는 기존 설치 ZIP을 변경하지 않는다.**

NoFont에는 위 두 fallback 규칙과 모델이 **없다**. 따라서 NoFont 다운로드는 정상이어도 release 33의 시각 수정은 포함하지 않는다. 같은 아이템 번호가 사용되고 이 모델이 우선 적용되는 환경이라면 기존 오표시가 남을 수 있다. 실제 잔누 서버에서 해당 아이템을 쓰는지는 확인되지 않았다. 일반 ZIP에서 폰트만 지워 NoFont를 임의로 재생성하지 않는다. 별도 내용 검토와 새 서명이 필요한 작업이다.

서버가 계속 옛 SHA-1을 공지하면 기존 클라이언트가 옛 캐시를 사용하거나, 새 ZIP과 공지된 해시가 달라 다운로드 문제가 생길 수 있다. 파일만 고쳤다고 이미 실행 중인 서버가 새 값을 읽었다고 볼 수 없다.
저장소에는 `mc-patch-sha.service`의 본문·실제 `server.properties`·서버 로그가 없다. 검색한 packwiz 저장소에서도 서비스 정의를 찾지 못했다. **실제 서버 반영 여부와 실제 사용자 실패 발생 여부는 확인할 수 없다.**

`release.json`은 별도의 잔누 승인 커밋 용도이고, `manifest.jannu`에도 고정 커밋과 별도 파일 해시가 있다. 이번 작업에서 변경하지 않는다.
GitHub Releases에서 확인한 `latest`는 9월 23일의 BAT 첨부 배포이며, release 33 ZIP 배포 경로가 아니다. 현재 두 도우미와 README는 raw `main`을 사용한다.

## 3. 정확한 수정 범위와 서명 호환성

`manifest.json`의 아래 다섯 필드만 바뀐다. 도구는 기존 공백·줄바꿈과 나머지 필드를 그대로 보존하며, 최종 바이트 그대로 서명한다.

```diff
- version: 32
+ version: 33
- signed_at: 2026-10-02T11:06:24+09:00
+ signed_at: <실제 서명 시각; 도구가 생성>
  files.Elly-Korean-Patch.zip:
-   sha256: ad2533fe43db58b273b8baaa6a75b15e796b0012780cb952871311fd5d7b8ba4
+   sha256: cd04d10f7feed858b2201c4b1dcc07f268895151a4fbe93186fc2d9de92aab14
-   size: 2285625
+   size: 2286943
-   sha1: 197fa19475a25942ef9d0ffcd38504a8320b3cc9
+   sha1: dcabf514b5ef4809e30ba583b1775f9d4cac11d7
```

`manifest.sig`는 위 JSON **파일 원본 바이트**를 기존 개인키로 RSA-SHA256 / PKCS#1 v1.5 서명한 결과의 Base64 텍스트로 교체한다. JSON 안 `sha256` 문자열에 서명하거나 RSA-PSS를 사용하면 안 된다.
기존 클라이언트는 `ReadAllBytes` → `VerifyData(bytes, "SHA256", signature)`를 사용한다. 기존 공개키와 알고리즘을 유지하면 클라이언트 코드 변경은 필요 없다.
UTF-8 BOM 유무·줄바꿈·공백은 서명 뒤 한 바이트도 바꾸면 안 된다. `.gitattributes`가 JSON/SIG의 Git 줄바꿈 변환을 막고 있다.
버전은 마지막으로 신뢰한 번호보다 작을 때만 거절된다. 32 → 33 및 33 → 33 재확인은 허용된다. 이를 피하려고 `trusted-version.txt`를 지우지 않는다.

도구:

- `tools/Repair-Release33.ps1`: 원본 manifest 지문·기존 서명·나머지 13개 파일·새 ZIP/sidecar 검사 후 외부 작업 폴더에만 후보 생성. 원본 저장소를 덮어쓰지 않는다. 원본 manifest가 달라졌으면 중단한다.
- `tools/Test-Release.ps1`: 기존 공개키로 서명 검증, 기대 버전과 최소 신뢰 버전 검사, root 파일 14개의 SHA-256·크기, SHA-1이 있는 ZIP의 SHA-1/sidecar 검사. `manifest.jannu`의 외부 저장소 파일 다운로드까지 검사하는 도구는 아니다.
- `tools/ReleaseTools.ps1`: 기존 공개키와 공통 검증. 기존 클라이언트의 공개키를 교체하지 않는다.

## 4. 엘리 PC에서 정상 서명하기

먼저 게임과 도우미를 닫는다. 실제 사용 인스턴스의 `resourcepacks`, `options.txt`, `%APPDATA%\elly-helper`, `%APPDATA%\jannu-helper`를 별도 폴더에 백업한다. 휴대용 실행이라면 USB의 해당 상태 폴더도 백업한다.
아래는 이 수정안의 도구가 들어 있는 저장소 루트에서 **Windows PowerShell 5.1**로 실행한다.
`git status --short`에 본인 작업이 있으면 덮어쓰지 말고 분리된 체크아웃을 사용한다.

```powershell
git fetch origin
git status --short
git rev-parse origin/main
# 조사 이후 main이 바뀌었다면 내용을 먼저 비교한다. 최신 배포를 33으로 되돌리면 안 된다.

# 키 없이 검사하고 수정 내용을 확인하는 선택 단계. 폴더는 매번 새 이름을 사용한다.
$preview = Join-Path $env:TEMP ('elly-r33-preview-' + [guid]::NewGuid().ToString('N'))
.\tools\Repair-Release33.ps1 -OutputDirectory $preview
Get-Content (Join-Path $preview 'manifest.json') -Raw
```

위 미서명 후보의 `signed_at`은 null이며 `.sig`가 없다. **이 후보는 배포하지 않는다.**

기존 서명 도구의 위치와 키 저장 형식은 이 저장소에 없다. 이를 추측해 키를 만들지 않는다. 아래 중 실제 기존 키 형식에 맞는 방법 하나만 사용한다.

**A. 원래 개인키가 RSA XML 파일로 보관된 경우** — 실제 기존 경로를 입력한다. 키를 저장소나 채팅에 복사하지 않는다.

```powershell
$stage = Join-Path $env:TEMP ('elly-r33-signed-' + [guid]::NewGuid().ToString('N'))
$keyPath = Read-Host '기존 RSA XML 개인키 파일의 실제 경로'
.\tools\Repair-Release33.ps1 -OutputDirectory $stage -PrivateKeyXmlPath $keyPath
```

도구는 이 키의 공개 부분이 기존 공개키와 정확히 일치하는지 확인한다. 다르면 파일을 쓰지 않고 중단한다. 키 내용은 출력하거나 저장하지 않는다.

**B. 기존 서명 프로그램/인증서 저장소를 사용하는 경우** — 새 키로 바꾸거나 XML로 내보낼 필요가 없다. 그 프로그램으로 열어 둔 기존 RSA 서명 객체가 `$existingReleaseRsa`인 경우의 연결 예시는 다음과 같다. 객체 변수명·열기 방식은 실제 기존 도구에 맞춘다. 이 문서는 그 객체가 이미 존재한다고 단정하지 않는다.

```powershell
$stage = Join-Path $env:TEMP ('elly-r33-signed-' + [guid]::NewGuid().ToString('N'))
$sign = {
    param([byte[]]$bytes)
    $existingReleaseRsa.SignData($bytes,
        [Security.Cryptography.HashAlgorithmName]::SHA256,
        [Security.Cryptography.RSASignaturePadding]::Pkcs1)
}.GetNewClosure()
.\tools\Repair-Release33.ps1 -OutputDirectory $stage -SignBytes $sign
```

외부 서명 콜백은 최종 JSON 바이트를 받고 **raw 서명 byte[]만** 반환해야 한다. Base64 인코딩은 도구가 한다. 기존 공개키 검증을 통과하지 못하면 출력하지 않는다. 기존 키에 접근할 수 없으면 여기서 중단한다. 키 생성·교체·검증 생략은 복구 방법이 아니다.

## 5. 배포 전 검사 및 한 커밋으로 반영

```powershell
.\tools\Test-Release.ps1 -ManifestDirectory $stage -ExpectedVersion 33 -MinimumVersion 32
# PASS 및 FilesChecked=14를 확인한다.

# 두 파일을 함께 복사. 이 사이에는 push하지 않는다.
Copy-Item -LiteralPath (Join-Path $stage 'manifest.json') -Destination .\manifest.json
Copy-Item -LiteralPath (Join-Path $stage 'manifest.sig') -Destination .\manifest.sig
.\tools\Test-Release.ps1 -ExpectedVersion 33 -MinimumVersion 32
git diff -- manifest.json manifest.sig

# 의도한 5개 필드 이외의 의미 변경, ZIP/도우미/공개키 변경이 없는지 확인한다.
git add -- manifest.json manifest.sig
git diff --cached --stat
git commit -m "release 33: synchronize signed manifest with dungeon-key fix"

# Git에 저장된 바이트 자체도 검증한다. 파일을 직접 다시 저장하지 않는다.
$check = Join-Path $env:TEMP ('elly-r33-commit-' + [guid]::NewGuid().ToString('N'))
git worktree add --detach $check HEAD
try {
    & (Join-Path $check 'tools\Test-Release.ps1') -RepoRoot $check -ExpectedVersion 33 -MinimumVersion 32
} finally { git worktree remove $check }
```

서명한 두 파일을 **하나의 커밋으로** 검토 브랜치에 push한다. 저장소의 정상 검토/병합 방식으로 그 커밋을 main에 반영한다. 기존 사용자에게 배포되기 전에 공개 URL도 아래 방식으로 확인한다. main을 강제 push하거나 이전 커밋으로 되돌리지 않는다.
도구·문서만 담긴 이 수정안 브랜치를 main에 합치는 것만으로는 불일치가 해결되지 않는다. 실제 서명한 두 파일이 필요하다.

## 6. 배포 후 원격 검사 및 사용자 확인

서명 파일이 들어간 커밋이 원격에 올라간 뒤:

```powershell
$releaseCommit = git rev-parse HEAD
.\tools\Test-Release.ps1 -Remote -Ref $releaseCommit -ExpectedVersion 33 -MinimumVersion 32
# 위 검사가 성공한 커밋을 정상 절차로 main에 반영한 뒤:
.\tools\Test-Release.ps1 -Remote -Ref main -ExpectedVersion 33 -MinimumVersion 32
```

고정 커밋 검사는 배포 묶음을, main 검사는 실제 도우미 경로를 검사한다. 두 결과 모두 PASS여야 한다. 캐시/전파로 JSON과 SIG가 서로 다른 시점의 파일이면 안전하게 거부된다. 성공할 때까지 클라이언트 캐시 삭제나 반복 실행을 유도하지 않는다.
두 파일을 같은 커밋에 올려도 서로 다른 HTTP 요청에 대한 순간적 혼합을 완전히 없애지는 못한다. 장기적으로는 고정 커밋에 묶인 다운로드 경로 개선을 별도 검토할 수 있다.

사용자 시험은 복제한 테스트 인스턴스에서 먼저 한다.

1. release 32 ZIP이 설치된 상태에서 도우미를 완전히 종료·재실행한다. 창이 열린 동안 manifest를 캐시하므로 재실행이 필요하다. 갱신 필요 표시 → 업데이트 성공 → 최신 표시를 확인한다.
2. 설치된 `resourcepacks\Elly-Korean-Patch.zip`의 `Get-FileHash -Algorithm SHA256`이 위 새 값인지 확인한다. SHA-1도 위 값과 비교한다.
3. 이미 수동으로 release 33 ZIP을 넣은 상태에서도 최신 표시가 되는지 확인한다. 처음 설치하는 별도 테스트 Windows 계정/환경에서도 loader·GUI 실행과 설치를 확인한다. 실사용자의 신뢰 기록을 지우지 않는다.
4. 잔누 도우미의 기존 NoFont ZIP 해시가 그대로이며 설치가 계속 되는지 확인한다. NoFont가 이번 시각 수정을 받았다고 표시하거나 안내하지 않는다.
5. 게임에서 실제 두 사원 열쇠 `2341668`, `2341670`, 기존 가챠 알 `26301~26304`, 할로윈 가면 `27401~27404`를 확인한다. 서버팩 적용 상태와 선택 팩 우선순위를 함께 기록한다. 이 수정은 사원 고유 그림 복원이 아니라 기본 열쇠 모습으로의 fallback이다.

별도 테스트 폴더에서 `manifest.json` 한 바이트 수정 + 기존 `.sig`, 또는 ZIP 변조 시 검증 실패하는지도 확인한다. 운영 파일에 변조 시험을 하지 않는다.

## 7. 서버 자동 리소스팩 확인

서버 관리자가 실제 서버에서 아래 **조회부터** 수행한다. 서비스명과 서버 디렉터리는 실제 설치값을 사용한다.

```bash
systemctl cat mc-patch-sha.service
systemctl status mc-patch-sha.service --no-pager
journalctl -u mc-patch-sha.service -n 80 --no-pager
# 실제 Minecraft 서비스의 systemctl cat 결과에서도 After=/Requires=/ExecStartPre= 등을 확인
# 실제 서버 폴더에서:
rg '^(resource-pack|resource-pack-sha1|require-resource-pack)=' server.properties
```

목표는 `resource-pack`이 README의 일반 ZIP URL이고, `resource-pack-sha1`이 `dcabf514b5ef4809e30ba583b1775f9d4cac11d7`인 상태다. 서비스가 OS 부팅 때만 한 번 실행되는지, Minecraft 시작 전에 매번 실행되는지 구분한다. README의 “부팅 때”라는 문구만으로 매 재시작 동기화를 단정할 수 없다.

운영 서버 재시작은 접속자에게 영향을 주므로 관리자의 정상 점검 시간에 진행한다. 서비스 정의를 확인한 뒤 서버 중지 → 해시 동기화 → 설정 검사 → 서버 시작 순서를 지킨다. 이 문서는 서버를 자동 재시작하지 않는다. 서비스가 다운로드 실패/빈 값일 때 기존 유효 해시를 보존하는지도 확인한다.
새 접속 클라이언트에서 서버가 공지한 SHA-1·리소스팩 로딩 성공·두 열쇠 모습을 확인하고, `latest.log`의 다운로드/해시/리소스 로딩 오류를 확인한다. 캐시를 가진 기존 사용자도 시험한다. 테스트 계정에서 리소스팩 동의를 거절한 경우는 다운로드 실패와 구분한다.

## 8. 복구와 검증의 한계

- Linux PowerShell 7.6.7에서 준비·검증 도구의 정상/거부 경로 12개를 검사했다. [검사 기록](release-33-validation.txt)을 참고한다. Windows PowerShell 5.1에서 실제 키를 이용한 최종 검증은 별도로 필요하다.
- 배포 전 검사가 실패하면 push하지 않는다. 로컬 수정은 백업한 JSON/SIG 쌍으로 함께 복구한다.
- 이미 33을 신뢰한 사용자가 생긴 뒤 운영 manifest를 32로 되돌리면 rollback 방지에 걸린다. 문제가 있으면 **34 이상**의 새 서명 목록으로 검증된 ZIP을 다시 배포한다. ZIP/SHA-1/manifest/SIG를 일관되게 맞춘다. 이 일회성 33 복구 도구는 34 생성용이 아니다.
- loader는 manifest 확인이 연속 3회 실패하면 `verified` 캐시를 지우는 코드가 있다. 잘못된 쌍을 올려놓고 사용자에게 반복 실행을 시키지 않는다. 현재 ZIP 불일치만으로는 loader의 manifest 검증 실패가 발생하지 않는다.
- 이 조사에서 기존 서명 검증, 파일 해시, ZIP 내용, 수정 도구의 준비 및 거부 경로는 확인했다. 실제 개인키 서명, Windows 5.1 GUI 실행, 실제 서버 적용·클라이언트 렌더링은 수행하지 않았다. 위 PC/서버 시험을 마쳐야 운영 완료로 볼 수 있다.

## 근거 파일

- [조사 기준 커밋](https://github.com/spoemeo-code/elly-korean-patch/commit/4d3fcba72e690c5fd55232c361f9f402c697300f)
- [manifest.json](https://github.com/spoemeo-code/elly-korean-patch/blob/4d3fcba72e690c5fd55232c361f9f402c697300f/manifest.json), [manifest.sig](https://github.com/spoemeo-code/elly-korean-patch/blob/4d3fcba72e690c5fd55232c361f9f402c697300f/manifest.sig)
- [일반 ZIP](https://github.com/spoemeo-code/elly-korean-patch/blob/4d3fcba72e690c5fd55232c361f9f402c697300f/Elly-Korean-Patch.zip), [NoFont ZIP](https://github.com/spoemeo-code/elly-korean-patch/blob/4d3fcba72e690c5fd55232c361f9f402c697300f/Elly-Korean-Patch-NoFont.zip)
- [loader.ps1](https://github.com/spoemeo-code/elly-korean-patch/blob/4d3fcba72e690c5fd55232c361f9f402c697300f/loader.ps1#L39-L145)
- [gui-elly.ps1 설치](https://github.com/spoemeo-code/elly-korean-patch/blob/4d3fcba72e690c5fd55232c361f9f402c697300f/gui-elly.ps1#L783-L841), [최신 표시](https://github.com/spoemeo-code/elly-korean-patch/blob/4d3fcba72e690c5fd55232c361f9f402c697300f/gui-elly.ps1#L1405-L1440)
- [gui.ps1 NoFont 선택](https://github.com/spoemeo-code/elly-korean-patch/blob/4d3fcba72e690c5fd55232c361f9f402c697300f/gui.ps1#L35-L36)
- [README 서버 안내](https://github.com/spoemeo-code/elly-korean-patch/blob/4d3fcba72e690c5fd55232c361f9f402c697300f/README.md), [GitHub Release latest](https://github.com/spoemeo-code/elly-korean-patch/releases/tag/latest)
