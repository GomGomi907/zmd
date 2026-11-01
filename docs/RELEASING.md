# 릴리스 운영

Windows 사용자는 GitHub의 최신 정식 릴리스에서 업데이트를 확인합니다. 릴리스 자산의 파일 이름과 SHA-256 형식은 기존 버전의 업데이터가 사용하므로 유지해야 합니다.

## 새 버전 준비

1. `build.zig`의 `app_version`과 `build.zig.zon`의 `.version`을 같은 버전으로 변경합니다. Windows 실행 파일의 버전 정보와 앱의 버전 확인에도 이 값이 사용됩니다.
2. `zig build test`를 실행하고, Windows에서 `zig build -Dtarget=x86_64-windows -Dcpu=baseline -Doptimize=ReleaseSmall`로 설치 파일을 빌드합니다.
3. 변경 사항을 커밋하고 같은 버전의 `v` 태그를 올립니다. 예를 들어 두 버전 값이 `0.3.4`이면 태그는 `v0.3.4`입니다.
4. GitHub Actions의 **Release** 결과와 공개된 릴리스의 설치 파일 및 체크섬을 확인합니다. 기존 설치본의 자동 업데이트는 정식 릴리스만 확인합니다.

릴리스 설치 파일은 Windows x86-64의 일반적인 CPU에서 실행할 수 있도록 `-Dcpu=baseline`으로 빌드합니다. 공개 릴리스의 `zmd-setup-windows-x86_64.exe`와 `zmd-setup-windows-x86_64.exe.sha256`은 서로 같은 빌드여야 합니다.

## Windows 코드 서명

현재 릴리스는 서명되지 않았습니다. SignPath Foundation의 신청과 심사가 끝나고 서비스와 연결되기 전에는 서명된 것으로 표시하지 않습니다. 승인을 받은 후에는 빌드 산출물을 서명하고 서명을 확인한 다음, **서명된 최종 파일**의 SHA-256을 생성해 게시합니다. SignPath 무료 인증서는 릴리스마다 지정된 승인자의 수동 승인이 필요합니다.

서명만으로 백신의 격리나 오진이 사라진다고 보장할 수 없습니다. 설치 차단이 보고되면 배포 파일의 버전과 SHA-256, 진단 결과를 확인하고 해당 보안 제품 업체에 검토를 요청합니다.
