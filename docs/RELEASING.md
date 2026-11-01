# 릴리스 운영

Windows 사용자는 GitHub의 최신 정식 릴리스에서 업데이트를 확인합니다. 릴리스 자산의 파일 이름과 SHA-256 형식은 기존 버전의 업데이터가 사용하므로 유지해야 합니다.

## 새 버전 준비

1. `build.zig`의 `app_version`과 `build.zig.zon`의 `.version`을 같은 버전으로 변경합니다. Windows 실행 파일의 버전 정보와 앱의 버전 확인에도 이 값이 사용됩니다.
2. `zig build test`를 실행하고, Windows에서 `zig build -Dtarget=x86_64-windows -Dcpu=baseline -Doptimize=ReleaseSmall`로 설치 파일을 빌드합니다.
3. 검토와 CI를 거쳐 변경 사항을 `main`에 반영하고, 그 커밋에 같은 버전의 `v` 태그를 만들어 올립니다. 예를 들어 두 버전 값이 `0.3.4`이면 태그는 `v0.3.4`입니다.
4. GitHub Actions에서 **Release**를 `main` 기준으로 수동 실행하고 버전을 입력합니다. 태그만 올려서는 릴리스가 게시되지 않습니다. 워크플로는 태그가 현재 `main` 커밋과 일치하는지 확인합니다. `v*` 태그는 생성 후 수정·삭제가 차단되므로 태그를 만들기 전에 커밋과 버전을 확인합니다.
5. SignPath에서 서명 요청을 수동 승인하고, GitHub Actions 결과와 공개된 릴리스의 설치 파일 및 체크섬을 확인합니다. 기존 설치본의 자동 업데이트는 정식 릴리스만 확인합니다.

릴리스 설치 파일은 Windows x86-64의 일반적인 CPU에서 실행할 수 있도록 `-Dcpu=baseline`으로 빌드합니다. 공개 릴리스의 `zmd-setup-windows-x86_64.exe`와 `zmd-setup-windows-x86_64.exe.sha256`은 서로 같은 빌드여야 합니다.

## Windows 코드 서명

현재 공개된 릴리스는 서명되지 않았습니다. 현재 SignPath Foundation 승인을 받지 못했습니다. 승인 후 서비스와 연결되기 전에는 서명된 것으로 표시하지 않으며 이 워크플로로 새 릴리스를 게시할 수 없습니다. 저장소 운영 규칙은 [Code signing policy](SIGNING.md), 네트워크 사용은 [개인정보 안내](PRIVACY.md)를 따릅니다.

서명 연동이 활성화된 뒤의 릴리스 순서는 다음과 같습니다.

1. GitHub가 호스팅하는 러너에서 테스트와 릴리스 빌드를 수행합니다.
2. 빌드한 설치 파일을 GitHub Actions artifact로 먼저 업로드하고, 해당 artifact ID와 고정된 SignPath 프로젝트·서명 정책·artifact configuration 식별자로 서명을 요청합니다.
3. 지정된 approver가 각 릴리스 서명 요청을 SignPath에서 수동 승인합니다. 이 승인은 자동화하거나 생략하지 않습니다.
4. SignPath가 반환한 파일의 Authenticode 서명, 게시자, 제품명 `zmd`, File/Product Version 일치 여부를 확인합니다.
5. **서명된 최종 파일**의 SHA-256을 새로 생성합니다. 서명 전 파일의 체크섬을 재사용하지 않습니다.
6. 서명된 설치 파일과 그 체크섬만 GitHub Release에 게시하고, 릴리스 본문에 `Code signing policy`라는 문구와 [공개 정책 URL](https://github.com/GomGomi907/zmd/blob/main/docs/SIGNING.md)을 넣습니다.

SignPath 연결에는 GitHub Actions secret `SIGNPATH_API_TOKEN`과 repository variables `SIGNPATH_ORGANIZATION_ID`, `SIGNPATH_PROJECT_SLUG`, `SIGNPATH_SIGNING_POLICY_SLUG`, `SIGNPATH_ARTIFACT_CONFIGURATION_SLUG`가 필요합니다. 승인 후 발급받은 값을 등록하며, 식별자는 승인된 SignPath 설정과 정확히 일치시킵니다. 값이 없거나 서명 검증이 실패하면 공개 릴리스를 만들지 않습니다. GitHub.com Trusted Build System과 SignPath GitHub App을 연결해 저장소·커밋·워크플로 출처를 검증하며, artifact configuration은 GitHub Actions artifact의 ZIP 루트에 있는 `zmd-setup-windows-x86_64.exe`만 서명하고 제품명과 버전을 제한해야 합니다. SignPath 승인 대기는 최대 150분이며, 시간이 지나면 승인 여부를 확인한 뒤 워크플로를 다시 실행해야 합니다.

SignPath의 release-signing 허용 브랜치는 보호된 `main`으로 제한합니다. 별도 릴리스 브랜치는 필수가 아니며 여러 버전 계열을 동시에 유지해야 할 때 추가할 수 있습니다. 각 서명 요청은 사람이 승인해야 합니다.

서명 관련 GitHub 및 SignPath 계정은 MFA를 사용합니다. 외부 기여는 [기여 안내](../CONTRIBUTING.md)에 따라 사람이 검토한 뒤 병합하며, 빌드·릴리스·서명 설정 변경은 특히 출처 검증 경계를 바꾸지 않는지 확인합니다.

서명만으로 백신의 격리나 오진이 사라진다고 보장할 수 없습니다. 설치 차단이 보고되면 배포 파일의 버전과 SHA-256, 진단 결과를 확인하고 해당 보안 제품 업체에 검토를 요청합니다.
