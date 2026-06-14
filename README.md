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

- Windows: direct Win32 window with a read-only native `EDIT` control.
- Linux: runtime-loaded X11 window. It needs an X11/Xwayland session with `libX11.so.6` available.
- File association installers are not included yet. Use the OS "Open with..." flow and point `.md` files at the built `zmd` executable.

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
- Linux GUI text rendering is intentionally minimal X11 drawing; Unicode shaping and rich layout are not implemented yet.
- OS-level file association is manual for now; the app already accepts a file path as its first argument.

If lightweight/single-executable constraints materially erode Markdown support, that tradeoff should be reported and optimized before accepting the gap.
