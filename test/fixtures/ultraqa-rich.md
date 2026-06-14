# zmd UltraQA Rendering Fixture

This paragraph checks **bold text**, *italic text*, `inline code`, ~~strike text~~, and [a visible link](https://example.com/zmd).

## Lists

- plain bullet item
- [x] completed task item
- [ ] pending task item
1. ordered first item
2. ordered second item with **bold** inside

> Blockquote should be indented, gray, and italic enough to differ from normal paragraphs.

---

## Code block

```zig
const std = @import("std");
pub fn main() void {
    std.debug.print("hello zmd\n", .{});
}
```

## Table

| Feature | Expected visual signal |
| --- | --- |
| Heading | much larger bold title |
| Link | blue underlined label plus URL |
| Inline code | monospace highlighted span |

![Alt text for image](./missing-image.png)

한글과 Unicode: Markdown 뷰어 ✓ 빠르고 가볍게.
