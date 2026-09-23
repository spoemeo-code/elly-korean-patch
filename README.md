# Elly Korean Patch

마인크래프트 모드 한글 번역 리소스팩입니다.

## 서버에 붙이는 법 (서버장만, 최초 1회)

서버 폴더의 `server.properties` 를 열고 아래 두 줄을 넣은 뒤 서버를 재시작하세요.
이미 `resource-pack=` 줄이 있으면 그 줄만 바꾸면 됩니다.

```properties
resource-pack=https://raw.githubusercontent.com/spoemeo-code/elly-korean-patch/main/elly-korean-patch.zip
resource-pack-sha1=
```

`resource-pack-sha1` 은 **비워두세요.** 여기에 해시를 적으면 번역이 갱신될 때마다
서버장이 그 값을 다시 고쳐야 합니다. 비워두면 접속할 때마다 최신 파일을 받아오므로
서버 설정을 두 번 다시 건드릴 필요가 없습니다. 파일은 1MB 남짓이라 부담이 없습니다.

플레이어는 아무것도 설치하지 않아도 됩니다. 접속하면 리소스팩을 받겠냐는 창이 한 번
뜨고, 받으면 끝입니다.

## 갱신

번역이 바뀌면 이 저장소의 `elly-korean-patch.zip` 만 교체됩니다.
주소는 바뀌지 않으므로 서버 설정은 그대로 두면 됩니다.
플레이어는 다음 접속부터 새 번역을 보게 됩니다.

## 파일

| | |
|---|---|
| `elly-korean-patch.zip` | 배포용 리소스팩 (서버가 이 파일을 내려줍니다) |
