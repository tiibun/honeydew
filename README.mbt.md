# honeydew

A TUI (Terminal User Interface) library for [MoonBit](https://moonbitlang.com), inspired by [Ratatui](https://ratatui.rs).

Built from scratch as a learning project.

## Features

- Buffer-based rendering with diff updates (only changed cells are redrawn)
- ANSI color and style support (foreground, background, bold, italic, etc.)
- Flexbox-inspired layout system (horizontal/vertical splits)
- Widget trait for composable UI components
- Raw mode terminal input

## Quick Start

```moonbit
fn main {
  let terminal = @honeydew.Terminal::new()
  terminal.draw(fn(frame) {
    let area = frame.size()
    let widget = @widget.Paragraph::new("Hello, honeydew!")
    frame.render_widget(widget, area)
  })
}
```

## Package Structure

| Package | Description |
|---|---|
| `tiibun/honeydew/terminal` | Raw mode, ANSI escape codes (C FFI) |
| `tiibun/honeydew/style` | Colors and text modifiers |
| `tiibun/honeydew/layout` | Rect and layout splitting |
| `tiibun/honeydew/buffer` | Cell buffer and diff rendering |
| `tiibun/honeydew/widget` | Widget trait and built-in widgets |
| `tiibun/honeydew` | Public API: Terminal, Frame |

## Examples

| Example | Description |
|---|---|
| `examples/hello` | Hello World |
| `examples/counter` | Counter with keyboard input |

## Design

See [DESIGN.md](DESIGN.md) for architecture details.

## License

Apache-2.0
