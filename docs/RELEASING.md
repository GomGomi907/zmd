# 릴리스 운영

Windows 사용자는 GitHub의 최신 정식 릴리스에서 업데이트를 확인합니다. 릴리스 자산의 파일 이름과 SHA-256 형식은 기존 버전의 업데이터가 사용하므로 유지해야 합니다.

## 새 버전 준비

1. `build.zig`의 `app_version`과 `build.zig.zon`의 `.version`을 같은 버전으로 변경합니다. Windows 실행 파일의 버전 정보와 앱의 버전 확인에도 이 값이 사용됩니다.
2. `zig build test`를 실행하고, Windows에서 `zig build -Dtarget=x86_64-windows -Dcpu=baseline -Doptimize=ReleaseSmall`로 설치 파일을 빌드합니다.
3. 변경 사항을 커밋하고 같은 버전의 `v` 태그를 올립니다. 예를 들어 두 버전 값이 `0.3.4`이면 태그는 `v0.3.4`입니다.
4. GitHub Actions의 **Release** 결과와 공개된 릴리스의 설치 파일 및 체크섬을 확인합니다. 기존 설치본의 자동 업데이트는 정식 릴리스만 확인합니다.

릴리스 설치 파일은 Windows x86-64의 일반적인 CPU에서 실행할 수 있도록 `-Dcpu=baseline`으로 빌드합니다. 공개 릴리스의 `zmd-setup-windows-x86_64.exe`와 `zmd-setup-windows-x86_64.exe.sha256`은 서로 같은 빌드여야 합니다.

## Windows 코드 서명

현재 릴리스는 서명되지 않았습니다. SignPath Foundation의 신청과 심사가 끝나고 서비스와 연결되기 전에는 서명된 것으로 표시하지 않습니다. 저장소 운영 규칙은 [Code signing policy](SIGNING.md), 네트워크 사용은 [개인정보 안내](PRIVACY.md)를 따릅니다.

SignPath가 활성화되면 릴리스 순서는 다음과 같습니다.

1. GitHub가 호스팅하는 러너에서 테스트와 릴리스 빌드를 수행합니다.
2. 빌드한 설치 파일을 GitHub Actions artifact로 먼저 업로드하고, 해당 artifact ID와 고정된 SignPath 프로젝트·서명 정책·artifact configuration 식별자로 서명을 요청합니다.
3. 지정된 approver가 각 릴리스 서명 요청을 SignPath에서 수동 승인합니다. 이 승인은 자동화하거나 생략하지 않습니다.
4. SignPath가 반환한 파일의 Authenticode 서명, 게시자, 제품명 `zmd`, File/Product Version 일치 여부를 확인합니다.
5. **서명된 최종 파일**의 SHA-256을 새로 생성합니다. 서명 전 파일의 체크섬을 재사용하지 않습니다.
6. 서명된 설치 파일과 그 체크섬만 GitHub Release에 게시하고, 릴리스 본문에 `Code signing policy`라는 문구와 [공개 정책 URL](https://github.com/GomGomi907/zmd/blob/main/docs/SIGNING.md)을 넣습니다.

SignPath 연결에는 전용 CI 제출자 토큰, organization ID, project slug, signing policy slug, artifact configuration slug가 필요합니다. 토큰만 GitHub Actions secret으로 보관하고, 나머지 식별자는 승인된 SignPath 설정과 정확히 일치시킵니다. GitHub.com Trusted Build System과 SignPath GitHub App을 연결해 저장소·커밋·워크플로 출처를 검증하며, artifact configuration은 zmd가 직접 빌드한 실행 파일만 서명하고 제품명과 버전을 제한해야 합니다.

서명 관련 GitHub 및 SignPath 계정은 MFA를 사용합니다. 외부 기여는 [기여 안내](../CONTRIBUTING.md)에 따라 사람이 검토한 뒤 병합하며, 빌드·릴리스·서명 설정 변경은 특히 출처 검증 경계를 바꾸지 않는지 확인합니다.

서명만으로 백신의 격리나 오진이 사라진다고 보장할 수 없습니다. 설치 차단이 보고되면 배포 파일의 버전과 SHA-256, 진단 결과를 확인하고 해당 보안 제품 업체에 검토를 요청합니다.
