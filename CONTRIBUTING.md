# zmd 기여 안내

zmd는 가볍고 간편한 읽기 전용 Markdown 뷰어라는 범위를 유지합니다. 변경 제안은 기존 구조와 단일 실행 파일 우선 원칙을 따르고, 새 의존성이나 사용자 절차를 추가하기 전에 필요성을 설명해 주세요.

## 변경 제출

1. 변경과 관련된 테스트를 추가하거나 갱신합니다.
2. `zig build test`와 해당 플랫폼의 `zig build -Doptimize=ReleaseSmall`을 실행합니다.
3. 변경 목적, 사용자에게 보이는 동작, 검증 결과를 pull request에 적습니다.

외부 기여자의 변경은 [GomGomi907](https://github.com/GomGomi907)가 사람이 직접 검토한 뒤 병합합니다. 작성자 본인의 테스트만으로 리뷰를 대체하지 않습니다.

`main` 브랜치에는 pull request 승인 1건과 Windows·Linux CI 통과가 요구됩니다. 소유자인 관리자는 긴급 수정과 직접 유지보수를 위해 이 규칙을 우회할 수 있으며, 외부 기여 검토와 서명 요청 승인은 여전히 수행합니다.

빌드, GitHub Actions, 릴리스, 업데이트, 설치 또는 서명 관련 변경은 공개 소스에서 최종 artifact까지의 출처 검증에 영향을 줄 수 있습니다. 이런 변경은 [Code signing policy](docs/SIGNING.md)와 [릴리스 운영](docs/RELEASING.md)을 함께 확인하고, 서명 대상·메타데이터·승인 절차를 약화하지 않아야 합니다.

## 보안과 개인정보

일반적인 버그와 기능 제안은 [GitHub Issues](https://github.com/GomGomi907/zmd/issues)를 사용합니다. 현재 저장소에는 비공개 취약점 신고 기능이 활성화되어 있지 않으므로, 공개 이슈에 실제 개인 문서, 사용자 경로, 민감한 로그 또는 개인정보를 게시하지 마세요.

저장소나 SignPath 역할을 부여받는 구성원은 두 서비스에서 MFA를 사용해야 합니다. 역할 변경은 [Code signing policy](docs/SIGNING.md)의 담당자 목록에도 반영합니다.
