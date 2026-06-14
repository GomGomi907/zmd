# zmd

`zmd` is a Zig-first, ultra-light Markdown viewer experiment.

The first milestone is intentionally tiny: a single executable that opens a local `.md` file and renders a readable, non-editing terminal view. Native GUI/file association is a follow-up milestone, not hidden scope for this first slice.

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

Cross-target examples:

```sh
zig build -Dtarget=x86_64-linux -Doptimize=ReleaseSmall
zig build -Dtarget=x86_64-windows -Doptimize=ReleaseSmall
```

## Usage

```sh
zmd --help
zmd --version
zmd path/to/file.md
```

## Current Markdown coverage

The std-only renderer currently handles enough common syntax for first-pass reading:

- headings
- paragraphs
- unordered and ordered lists
- blockquotes
- fenced code blocks
- inline code marker stripping
- basic emphasis marker stripping
- links as `text <url>`
- tables preserved as readable text

## Known limitations

- This is not a full CommonMark/GFM implementation.
- Tables are preserved textually rather than laid out.
- Nested lists, images, HTML blocks, footnotes, task lists, and many edge cases are not yet fully rendered.
- This first slice is terminal-based; native GUI and file association remain future milestones.

If lightweight/single-executable constraints materially erode Markdown support, that tradeoff should be reported and optimized before accepting the gap.
