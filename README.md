# zmd

`zmd` is a Zig-first, ultra-light Markdown viewer experiment.

The current milestone is intentionally tiny: a single executable that opens a local `.md` file in a readable, non-editing native viewer window.

## 시작하기

zmd는 문서를 편집하지 않고 빠르게 읽기 위한 가벼운 Markdown 뷰어입니다.

1. [최신 릴리스](https://github.com/GomGomi907/zmd/releases/latest)에서 Windows 설치 파일 `zmd-setup-windows-x86_64.exe`를 내려받아 실행합니다.
2. Markdown 파일을 열 때 **연결 프로그램 → zmd**를 선택합니다. 기본 앱으로 쓰려면 Windows에서 항상 이 앱을 사용하도록 선택하세요.

### 읽기 도구

- **밝은 테마 / 어두운 테마:** `Ctrl` + `Shift` + `T`, 또는 창 왼쪽 위 아이콘의 메뉴. Windows 고대비 모드가 켜져 있으면 고대비 설정이 우선 적용됩니다.
- **확대 / 축소:** `Ctrl` + `+` / `Ctrl` + `-`, 또는 `Ctrl` + 마우스 휠. `Ctrl` + `0`으로 원래 크기로 돌아갑니다.
- **업데이트:** 문서를 표시한 뒤 백그라운드에서 새 버전을 확인합니다. 업데이트가 있으면 창을 닫을 때만 설치 여부를 묻고, 승인하면 추가 창 없이 업데이트합니다.

Windows 설치 파일은 현재 디지털 서명되지 않았습니다. 서명 적용을 준비하고 있으며, 최신 상태는 아래 [Code signing policy](#code-signing-policy)에서 확인할 수 있습니다.

문제가 생기면 [이슈 등록](https://github.com/GomGomi907/zmd/issues/new/choose)에서 증상을 알려 주세요. 문서 내용이나 개인 정보를 첨부할 필요는 없습니다.

## Principles

- Viewer-only: read and display Markdown; do not edit.
- Single executable first: avoid heavyweight runtimes.
- Fast and small over easy: development speed is not a decision driver.
- Zig-first for personal learning value, bounded by the output goals.
- Honest Markdown coverage: document gaps instead of pretending full compliance.

## Build

This project targets Zig `0.16.0`.
Maintainers can find the release checklist in [docs/RELEASING.md](docs/RELEASING.md).

```sh
zig build test
zig build -Doptimize=ReleaseSmall
```

The executable is installed under `zig-out/bin/`:

- Linux: `zig-out/bin/zmd`
- Windows: `zig-out/bin/zmd.exe`
- Windows installer: `zig-out/bin/zmd-setup.exe`

Windows builds default to the GUI subsystem so double-click/open-with usage does not need a terminal. For stdout smoke tests, build the console variant:

```sh
zig build -Dwindows-console=true -Doptimize=ReleaseSmall
```

Cross-target examples:

```sh
zig build -Dtarget=x86_64-linux -Doptimize=ReleaseSmall
zig build -Dtarget=x86_64-windows -Doptimize=ReleaseSmall
```

## Usage

```sh
zmd --help
zmd --version
zmd path/to/file.md          # native read-only viewer window
zmd --dump path/to/file.md   # terminal render for tests/pipes
zmd --install-file-association
zmd --uninstall-file-association
```

For Windows release distribution, ship `zmd-setup.exe`. The installer is the same self-contained app binary under a setup filename: it copies itself to `%LOCALAPPDATA%\Programs\zmd\zmd.exe` and registers zmd as a Markdown "Open with" app for the current user. The portable `zmd.exe` remains useful for direct CLI/viewer use.

The next release will show the version under **About zmd...** in the window's system menu and will register zmd under Windows **Settings → Apps → Installed apps**, where it can be removed. For existing installations upgraded automatically, the entry is added in the background after the updated app next opens a document. These changes are not yet in the published v0.3.3 release.

To uninstall the current Windows release, close zmd, run the installed executable with `--uninstall-file-association` to remove its registration, and delete `%LOCALAPPDATA%\Programs\zmd\zmd.exe`. This does not delete your Markdown files. zmd does not yet appear in Windows **Settings → Apps → Installed apps**.

## Code signing policy

Windows releases are currently unsigned. The project is preparing free code signing provided by [SignPath.io](https://about.signpath.io/), certificate by [SignPath Foundation](https://signpath.org/). Signing is subject to acceptance and has not yet been enabled.

The project maintainer, [GomGomi907](https://github.com/GomGomi907), is responsible for changes, review of external contributions, and approval of signing requests.

zmd opens local documents without uploading their contents. On Windows, after displaying a document, it contacts GitHub to check for newer releases. If you approve an update when closing the viewer, zmd downloads the release and its checksum. These requests disclose your IP address and ordinary network request information to GitHub and its delivery providers; see the [GitHub privacy statement](https://docs.github.com/en/site-policy/privacy-policies/github-privacy-statement).

## Platform UI

- Windows: direct Win32 window with a read-only `RICHEDIT50W` control. Markdown source is converted to RTF before display, so common formatting is visible immediately in viewer mode.
- Windows reading controls: press `Ctrl` + `+` or `Ctrl` + `-`, or use `Ctrl` + mouse wheel, to zoom; press `Ctrl` + `0` to reset. The viewer scales its layout for the current monitor's DPI.
- Windows themes: press `Ctrl` + `Shift` + `T` or use the window's system menu to switch between light and dark themes. Windows high-contrast mode takes precedence automatically.
- Windows updates: zmd checks for a newer release in the background after showing the document. If one is available, it asks on exit whether to update; the update runs without opening another window.
- Linux: runtime-loaded X11 window. It needs an X11/Xwayland session with `libX11.so.6` available.
- Windows file association: run `zig-out/bin/zmd.exe --install-file-association` to register `zmd` as a Markdown "Open with" app for the current user. Then choose `zmd` from Windows "Open with..." and select "Always" to make `.md` files open with `zmd` and display the embedded zmd document icon. Run `zig-out/bin/zmd.exe --uninstall-file-association` to remove zmd's registration keys.

## Current Markdown coverage

The std-only renderer currently handles enough common syntax for first-pass reading:

- ATX (`#`) headings including empty marker-only headings, optional closing `#` markers, blockquote/list container recognition, and Setext (`===`/`---`) headings with indentation, contiguous-underline guards, and blockquote/list container recognition including multiline container titles, tab-padded blockquote/list Setext underlines, and ordered-list paragraph interruption guards inside blockquotes
- paragraphs, including soft continuation of indented lines that cannot interrupt paragraphs
- Korean-style outline lines beginning with `○` and a space are displayed as separate paragraphs (a zmd extension to Markdown); ordinary soft-wrapped text still joins normally
- LF/CRLF/CR line endings, soft line coalescing, and Markdown hard line breaks including trailing-backslash markers inside list/blockquote containers
- unordered and ordered lists (`1.` and `1)` markers, up-to-three-space top-level marker indentation, 1-9 digit ordered marker limit, preserving source numbering, and paragraph-interruption start-number guard in paragraphs/list items/quoted list items, and non-1 sibling markers after existing list items, and non-1 list starts after blank lines in containers), including simple nested indentation with CommonMark-style tab-stop boundaries, continuation lines, paragraph lazy continuations, and multiline inline spans and link/image labels across soft continuations
- GFM-style task list markers in the Windows formatted viewer, including multiline inline spans and hardbreak preservation
- blockquotes, including nested quotes, simple quoted lists, quoted continuation indentation, tab-padding normalization, paragraph lazy continuations, ordered-list paragraph interruption guards, and multiline inline spans and link/image labels across quoted/list soft continuations
- thematic breaks with the required three-or-more marker characters, including list/blockquote container rendering
- backtick and tilde fenced code blocks with matching close-fence length/type, indentation guards/content stripping, backtick-info-string validation, and inert rendering/reference-definition scanning inside list/blockquote containers, plus top-level indented code blocks
- inline code, including multi-backtick code spans with unmatched-run literal preservation and multiline code-span backslash preservation, code-span line-ending normalization/boundary trimming, and whitespace-only multiline spans
- basic emphasis, strong emphasis, intraword asterisk emphasis, combined strong+emphasis, and strikethrough in the Windows formatted viewer, with delimiter boundary, invalid-closer skipping, escaped strong closer fallback, and ASCII punctuation guards
- inline links with balanced/escaped and inline-rendered labels, nested-link label guards, balanced/escaped/angle-bracket/entity-decoded destinations with escaped angle-bracket delimiters and nested-angle guards, inline destination/title validation with quoted-title parenthesis handling that preserves invalid unbracketed spaces and missing title separators literally, reference-style links with escaped/whitespace-normalized, common/special Unicode case-folded including Latin Extended-A and Greek tonos folds, and multiline labels, 999-byte label limit, and escaped/entity-decoded destinations on the same or following line plus validated same-line or next-line titles with or without indentation, including title lines inside quote/list containers and preserving list markers after hidden list-item definitions including quoted-list definitions, blank continuations, heading continuations, and fenced-code continuations, and raw-HTML continuations, while preserving quoted paragraphs after complete same-line-title definitions and malformed following-title lines, including definitions inside blockquote/list containers including multiline labels, non-interrupting paragraph semantics, and ignoring definitions inside inert blocks, plus angle-bracket URI autolinks with target-byte validation and validated email autolinks
- CommonMark-style backslash escapes for ASCII punctuation inline Markdown markers
- inline delimiter handling that preserves underscore/strikethrough intraword identifiers like `snake_case` and `abc~~def~~ghi`, supports intraword asterisk emphasis, and preserves whitespace-only delimiter literals
- basic/common plus CommonMark sample, Latin-1, Greek/math, typography/symbol, URL, and selected rare HTML5 named entity decoding, and numeric HTML entity decoding with CommonMark digit limits, HTML5 C1 remapping, invalid numeric references as replacement characters, and overlength numeric refs preserved literally
- UTF-8/Unicode text through RTF Unicode escapes in the Windows formatted viewer, including UTF-8 BOM at file start and NUL replacement handling
- GFM-style tables rendered as bordered, aligned grids in the Windows formatted viewer, including inline formatting, escaped pipes, header styling, alternating row shading, and left/center/right column alignment; preserved as readable text in terminal and Linux output
- inline, full/collapsed reference, and shortcut reference image syntax, with local PNG, JPEG, and BMP content embedded in the Windows viewer, paths resolved relative to the Markdown file (including percent-encoded paths), proportional downscaling for the viewer surface, resize-end/debounced adaptation to the available window space without enlarging beyond the source or a comfortable display cap, and readable alt-text placeholders when a file is missing or unsupported
- block-start raw HTML lines as inert readable text
- multi-line HTML comments, processing instructions, uppercase declarations, CDATA blocks, complete-tag type-7 blocks with paragraph non-interruption, and common raw HTML blocks including the CommonMark type-6 block-level tag list with blank-line termination and blockquote/list plus nested quoted-list/ordered-list container inertness and type-1 closing-tag and comment/CDATA closing-marker termination plus lowercase declaration non-block handling plus type-7 paragraph non-interruption as inert readable text

## Known limitations

- This is not a full CommonMark/GFM implementation.
- Table grids are currently available only in the Windows formatted viewer; terminal and minimal Linux output preserve their readable Markdown text.
- Remote images, SVG, animated GIF, and image display in the minimal Linux X11 viewer are not yet supported; they remain readable alt-text placeholders.
- HTML blocks/tags are shown as inert readable text rather than interpreted markup.
- Footnotes and many edge cases are not yet fully rendered.
- Linux GUI text rendering is intentionally minimal X11 drawing; Unicode shaping and rich layout are not implemented yet.
- Windows cannot be forced to change the default app by this executable; the user must choose "Always" in the Windows "Open with..." flow.

If lightweight/single-executable constraints materially erode Markdown support, that tradeoff should be reported and optimized before accepting the gap.
