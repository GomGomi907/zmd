# Code signing policy

## 현재 상태

zmd의 공개 Windows 릴리스는 현재 디지털 서명되지 않았습니다. 현재 SignPath Foundation 승인을 받지 못했으며 SignPath 서명도 활성화되지 않았습니다. 승인과 서명 활성화가 확인되기 전에는 릴리스를 서명된 것으로 표시하지 않습니다.

승인된 뒤 서명 릴리스에는 다음 고지를 사용합니다: “Free code signing provided by [SignPath.io](https://about.signpath.io/), certificate by [SignPath Foundation](https://signpath.org/).” 적용 조건은 [SignPath Foundation conditions for Open Source projects](https://signpath.org/terms.html)를 따릅니다.

## 담당 역할

- Author/committer: [GomGomi907](https://github.com/GomGomi907)
- Reviewer: [GomGomi907](https://github.com/GomGomi907). 외부 기여자의 변경은 병합 전에 사람이 검토합니다.
- Approver: [GomGomi907](https://github.com/GomGomi907). 모든 릴리스 서명 요청을 직접 검토하고 승인 또는 거절합니다.

저장소 또는 SignPath 접근 권한을 가진 사람은 두 서비스 모두에서 MFA를 사용해야 합니다. 역할이 추가되거나 변경되면 이 문서를 함께 갱신합니다.

## 서명 범위와 출처

zmd 소스와 빌드 스크립트는 OSI 승인 [MIT License](../LICENSE)로 공개되며, 릴리스에 프로젝트 관리자의 비공개 또는 상업적 이중 라이선스 구성요소를 포함하지 않습니다.

zmd 인증서로 서명할 수 있는 것은 이 저장소의 공개 소스와 빌드 스크립트로 GitHub Actions에서 만든 zmd Windows 실행 파일뿐입니다. 프로젝트가 관리하지 않는 제3자 바이너리를 zmd 산출물로 서명하지 않습니다. 운영체제의 system library는 실행 시 사용할 수 있지만 릴리스에 복사해 zmd 인증서로 서명하지 않습니다.

승인 후 릴리스 파이프라인은 GitHub가 호스팅하는 러너에서 unsigned artifact를 만들고 GitHub Actions artifact로 업로드한 뒤, [SignPath GitHub Trusted Build System](https://docs.signpath.io/trusted-build-systems/github)을 통해 그 artifact의 서명을 요청합니다. SignPath GitHub App과 origin verification으로 저장소, 커밋, 워크플로 출처를 검증합니다. 매 릴리스에는 approver의 수동 승인이 필요합니다.

Artifact configuration은 다음을 강제해야 합니다.

- 서명 대상은 zmd가 직접 빌드한 Windows 실행 파일입니다.
- Product Name은 `zmd`입니다.
- File Version과 Product Version은 해당 릴리스 버전과 일치합니다.
- 구조나 서명 범위가 바뀌면 설정을 검토하고 필요한 경우 버전이 지정된 새 artifact configuration을 사용합니다.

서명 완료 후 Authenticode 서명과 파일 메타데이터를 검증하고, 서명된 최종 파일에서 SHA-256을 생성한 뒤에만 공개합니다. 구체적인 절차는 [릴리스 운영](RELEASING.md)에 있습니다.

## 사용자 보호와 시스템 변경

zmd는 Markdown 문서를 로컬에서 읽으며 문서 내용을 업로드하지 않습니다. 실제 네트워크 요청과 외부 서비스는 [개인정보 안내](PRIVACY.md)에 공개합니다.

Windows 버전은 문서를 표시한 뒤 GitHub에 업데이트 확인 요청을 자동으로 보내며, 현재 이 확인만 끄는 앱 설정은 없습니다. 이 동작에 대해 설치 중 별도 고지나 비활성화 선택지가 필요한지는 SignPath Foundation 심사에서 확인하고, 요구되는 경우 서명 활성화 전에 구현과 문서를 갱신합니다.

Windows 설치 프로그램은 현재 사용자 계정의 `%LOCALAPPDATA%\Programs\zmd`에 실행 파일을 복사하고 파일 연결 정보를 현재 사용자 레지스트리에 등록합니다. 공개된 v0.3.3은 설치된 앱 제거 항목을 등록하지 않으므로 README의 수동 제거 안내를 따릅니다. 다음 릴리스는 설치된 앱 정보를 함께 등록하며, 제거 기능은 zmd 소유 파일과 등록만 제거하고 Markdown 문서는 삭제하지 않습니다. 자동 업데이트를 승인하면 설치된 실행 파일을 새 버전으로 교체합니다.

프로젝트는 악성 코드, 사용자 동의 없는 추가 소프트웨어, 보안 우회 기능을 릴리스에 포함하지 않습니다. 정책 위반 신고가 들어오면 빌드 출처와 릴리스 artifact를 조사하고 SignPath Foundation의 검증에 협조합니다.

## 릴리스 페이지 고지

각 Windows 다운로드 또는 GitHub Release 페이지는 `Code signing policy`라는 문구로 [이 문서의 공개 URL](https://github.com/GomGomi907/zmd/blob/main/docs/SIGNING.md)에 연결해야 합니다. 서명이 활성화되기 전에는 해당 릴리스가 unsigned임을 명시하고, 활성화된 뒤에는 실제 서명 여부를 해당 릴리스별로 명시합니다.
