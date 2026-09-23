# Elly Korean Patch

마인크래프트 모드 한글 번역 리소스팩입니다.

## 서버에 붙이는 법 (서버장만, 최초 1회)

서버 폴더의 `server.properties` 를 열고 아래 두 줄을 넣은 뒤 서버를 재시작하세요.
이미 `resource-pack=` 줄이 있으면 그 줄만 바꾸면 됩니다.

```properties
resource-pack=https://raw.githubusercontent.com/spoemeo-code/elly-korean-patch/main/Elly-Korean-Patch.zip
resource-pack-sha1=<아래 주소에 적힌 값>
```

해시는 이 주소에서 항상 최신 값을 받을 수 있습니다:
`https://raw.githubusercontent.com/spoemeo-code/elly-korean-patch/main/Elly-Korean-Patch.zip.sha1`

**해시를 비워두면 안 됩니다.** 비워두면 클라이언트가 주소만 보고 "예전에 받은 것 그대로
쓰자"고 판단해서, 번역을 갱신해도 플레이어에게 새 파일이 가지 않습니다.
마인크래프트 서버가 직접 이렇게 경고합니다:

> You specified a resource pack without providing a sha1 hash.
> Pack will be updated on the client only if you change the name of the pack.

번역이 갱신되면 해시도 바뀌므로, 서버장이 매번 손으로 고치지 않으려면 서버가 켜질 때
위 `.sha1` 주소를 읽어 `server.properties` 에 채워 넣게 해 두는 것이 좋습니다.
(엘리 서버는 `mc-patch-sha.service` 가 부팅 때 이 일을 합니다.)

플레이어는 아무것도 설치하지 않아도 됩니다. 접속하면 리소스팩을 받겠냐는 창이 한 번
뜨고, 받으면 끝입니다. 받기 싫으면 "아니요"를 눌러도 됩니다.

## 갱신

번역이 바뀌면 이 저장소의 `Elly-Korean-Patch.zip` 과 `Elly-Korean-Patch.zip.sha1` 이
함께 교체됩니다. 주소와 파일 이름은 바뀌지 않습니다.

## 파일

| | |
|---|---|
| `Elly-Korean-Patch.zip` | 배포용 리소스팩 (서버가 이 파일을 내려줍니다) |
