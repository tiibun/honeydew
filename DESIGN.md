# honeydew Design Document

## Overview

honeydew is a TUI library for MoonBit targeting the **native backend**.
It follows Ratatui's architecture: a double-buffered renderer where only
changed cells are written to stdout on each frame.

## Architecture

```
┌─────────────────────────────────────────┐
│               Application               │
│  terminal.draw(fn(frame) { ... })       │
└──────────────────┬──────────────────────┘
                   │
          ┌────────▼────────┐
          │    Terminal      │  owns two Buffers (current / previous)
          │                  │  drives the event loop
          └────────┬─────────┘
                   │ creates
          ┌────────▼─────────┐
          │      Frame        │  borrows the current Buffer
          │                   │  exposes render_widget()
          └────────┬──────────┘
                   │ calls
          ┌────────▼──────────┐
          │  Widget::render()  │  writes Cells into the Buffer
          └────────┬───────────┘
                   │
          ┌────────▼──────────┐
          │  Buffer::diff()    │  compares current vs previous
          └────────┬───────────┘
                   │
          ┌────────▼──────────┐
          │  ANSI stdout       │  only redraws changed cells
          └───────────────────┘
```

## Packages

### `tiibun/honeydew/terminal`

Low-level terminal control via C FFI.

Responsibilities:
- Enter/exit raw mode (`tcgetattr` / `tcsetattr` on POSIX)
- Read raw bytes from stdin (keyboard input)
- Generate ANSI escape sequences (cursor movement, colors, clear screen)

Key types:
- `RawMode` — RAII guard: enters raw mode on creation, restores on drop
- `Key` — enum of recognized key events (Char, Enter, Backspace, Ctrl, Arrow, Esc, ...)

### `tiibun/honeydew/style`

Color and text modifier definitions. No FFI, pure MoonBit.

Key types:
- `Color` — `Default | Black | Red | Green | Yellow | Blue | Magenta | Cyan | White | Rgb(Int, Int, Int) | Ansi256(Int)`
- `Modifier` — bitflag enum: `Bold | Dim | Italic | Underline | Blink | Reverse | Hidden | StrikeThrough`
- `Style` — `{ fg: Color, bg: Color, modifiers: Modifier }`

### `tiibun/honeydew/layout`

Geometry and layout splitting. No FFI, pure MoonBit.

Key types:
- `Rect` — `{ x: Int, y: Int, width: Int, height: Int }`
- `Direction` — `Horizontal | Vertical`
- `Constraint` — `Percentage(Int) | Length(Int) | Min(Int) | Max(Int)`
- `Layout` — builder for splitting a `Rect` into sub-`Rect`s

Example:
```moonbit
let chunks = Layout::default()
  .direction(Vertical)
  .constraints([Percentage(50), Percentage(50)])
  .split(frame.size())
// chunks[0] = top half, chunks[1] = bottom half
```

### `tiibun/honeydew/buffer`

Double-buffered rendering. No FFI, pure MoonBit.

Key types:
- `Cell` — `{ symbol: String, style: Style }`
- `Buffer` — 2D array of `Cell` indexed by `(x, y)` within a `Rect`

Key operations:
- `Buffer::new(area)` — create a blank buffer
- `Buffer::get(x, y)` — get a cell
- `Buffer::set(x, y, cell)` — set a cell
- `Buffer::set_string(x, y, text, style)` — write a styled string
- `Buffer::diff(other)` — return list of `(x, y, Cell)` that changed

### `tiibun/honeydew/widget`

Widget trait and built-in widgets. Depends on `buffer`, `style`, `layout`.

Core trait:
```moonbit
trait Widget {
  render(Self, Rect, Buffer) -> Unit
}
```

Built-in widgets (initial set):
- `Block` — bordered box with optional title
- `Paragraph` — text with wrapping and scroll
- `List` — scrollable list of items
- `Gauge` — progress bar

### `tiibun/honeydew` (root)

Public API surface. Depends on all sub-packages.

Key types:
- `Terminal` — owns the double buffer and `RawMode`; provides `draw()`
- `Frame` — passed to the draw closure; provides `render_widget()` and `size()`

## Rendering Loop

```
loop {
  let event = terminal.poll_event()   // blocking read from stdin
  match event {
    Key(k) => app.handle_key(k)
    Resize(w, h) => terminal.resize(w, h)
  }
  terminal.draw(fn(frame) { app.render(frame) })
  if app.should_quit { break }
}
```

## C FFI Plan

MoonBit's native backend allows calling C functions directly.
The following C functions are needed:

| C function | Purpose |
|---|---|
| `tcgetattr` | Save original terminal settings |
| `tcsetattr` | Restore / set raw mode flags |
| `read` | Read one byte from stdin (fd 0) |
| `ioctl(TIOCGWINSZ)` | Get terminal window size |

These will be wrapped in a small C stub file (`terminal/terminal_stub.c`)
and declared with `extern "C"` in MoonBit.

## Implementation Order

1. `terminal/` — ANSI codes + raw mode (C FFI)
2. `style/` — Color, Modifier, Style
3. `layout/` — Rect, Constraint, Layout
4. `buffer/` — Cell, Buffer, diff
5. `widget/` — Widget trait + Block + Paragraph
6. root — Terminal, Frame
7. `examples/hello` — smoke test
8. `examples/counter` — keyboard input demo
