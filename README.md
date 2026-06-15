# zmd

`zmd` is a Zig-first, ultra-light Markdown viewer experiment.

The current milestone is intentionally tiny: a single executable that opens a local `.md` file in a readable, non-editing native viewer window.

## Principles

- Viewer-only: read and display Markdown; do not edit.
- Single executable first: avoid heavyweight runtimes.
- Fast and small over easy: development speed is not a decision driver.
- Zig-first for personal learning value, bounded by the output goals.
- Honest Markdown coverage: document gaps instead of pretending full compliance.

## Build

This project targets Zig `0.16.0`.

```sh
zig build test
zig build -Doptimize=ReleaseSmall
```

The executable is installed under `zig-out/bin/`:

- Linux: `zig-out/bin/zmd`
- Windows: `zig-out/bin/zmd.exe`

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
```

## Platform UI

- Windows: direct Win32 window with a read-only `RICHEDIT50W` control. Markdown source is converted to RTF before display, so common formatting is visible immediately in viewer mode.
- Linux: runtime-loaded X11 window. It needs an X11/Xwayland session with `libX11.so.6` available.
- File association installers are not included yet. Use the OS "Open with..." flow and point `.md` files at the built `zmd` executable.

## Current Markdown coverage

The std-only renderer currently handles enough common syntax for first-pass reading:

- ATX (`#`) headings including empty marker-only headings, optional closing `#` markers, blockquote/list container recognition, and Setext (`===`/`---`) headings with indentation, contiguous-underline guards, and blockquote/list container recognition including multiline container titles, tab-padded blockquote/list Setext underlines, and ordered-list paragraph interruption guards inside blockquotes
- paragraphs, including soft continuation of indented lines that cannot interrupt paragraphs
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
- tables preserved as readable text
- inline, full/collapsed reference, and shortcut reference image syntax as a readable placeholder with inline-rendered alt text that strips nested link destinations
- block-start raw HTML lines as inert readable text
- multi-line HTML comments, processing instructions, uppercase declarations, CDATA blocks, complete-tag type-7 blocks with paragraph non-interruption, and common raw HTML blocks including the CommonMark type-6 block-level tag list with blank-line termination and blockquote/list plus nested quoted-list/ordered-list container inertness and type-1 closing-tag and comment/CDATA closing-marker termination plus lowercase declaration non-block handling plus type-7 paragraph non-interruption as inert readable text

## Known limitations

- This is not a full CommonMark/GFM implementation.
- Tables are preserved textually rather than laid out as grid widgets.
- Images are shown as placeholders instead of decoded image content.
- HTML blocks/tags are shown as inert readable text rather than interpreted markup.
- Footnotes and many edge cases are not yet fully rendered.
- Linux GUI text rendering is intentionally minimal X11 drawing; Unicode shaping and rich layout are not implemented yet.
- OS-level file association is manual for now; the app already accepts a file path as its first argument.

If lightweight/single-executable constraints materially erode Markdown support, that tradeoff should be reported and optimized before accepting the gap.
