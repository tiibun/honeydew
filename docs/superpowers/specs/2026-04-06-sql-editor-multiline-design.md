# SQL Editor: Multi-line Editing & Statement Execution

Date: 2026-04-06

## Overview

Upgrade the SQL editor panel from a single-line `Input` widget to a multi-line `TextArea` widget. Add per-statement execution (Ctrl+Enter) and visual highlighting of the current SQL statement.

## Requirements

1. **Enter** inserts a newline in the SQL editor.
2. **Ctrl+Enter** executes the SQL statement at the cursor position.
3. Execution runs only the statement under the cursor, delimited by `;`.
4. The current statement is highlighted (yellow background) whenever the cursor moves.

## Key Binding

| Key | Terminal sequence (kitty) | Action |
|---|---|---|
| Enter | `0x0D` | Insert newline |
| Ctrl+Enter | `ESC [13;5u` → `[27,91,49,51,59,53,117]` | Execute current statement |

Ctrl+Enter is supported in Ghostty, WezTerm, Windows Terminal 1.18+. In unsupported terminals it falls back to Enter (inserts newline only).

## Architecture

### 1. `honeytui/terminal/key.mbt`

Add `CtrlEnter` variant to `Key` enum. Decode `ESC [13;5u` in `Key::from_bytes`.

### 2. `honeytui/widget/textarea.mbt` (new)

```
pub struct TextArea {
  lines       : Array[String]
  cursor_line : Int           // 0-indexed
  cursor_col  : Int           // char index within the line
  scroll_top  : Int           // first visible line
  highlight   : (Int, Int)?   // (start_line, end_line) inclusive, for current statement
  focused     : Bool
  style       : Style
  block       : Block?
}
```

Key operations:
- `Char(c)` — insert at cursor
- `Enter` — split line at cursor
- `Backspace` — delete char left; if at col 0 merge with previous line
- `Delete` — delete char right; if at end of line merge with next line
- `Left/Right` — move cursor (wrap across lines)
- `Up/Down` — move cursor vertically
- `Home/End` — start/end of current line
- `value() -> String` — lines joined with `\n`
- `cursor_pos() -> Int` — absolute char offset in `value()`
- `with_highlight(start_line, end_line) -> TextArea` — set highlight range

Rendering: each line rendered separately. Lines in the highlight range use `Style::bg(Yellow)`. Cursor cell rendered as `Black` on `White`.

### 3. SQL Statement Detection (`honeydew/cmd/main/main.mbt`)

```
fn current_statement(text: String, cursor_pos: Int) -> (String, Int, Int)
```

- Walk `text` to find the `;`-delimited statement that contains `cursor_pos`.
- Returns `(statement_text, start_char, end_char)`.
- Strips leading/trailing whitespace from the returned statement.
- Ignores `;` inside single-quoted strings.

To compute `(start_line, end_line)` for `TextArea::with_highlight`:
- Count `\n` occurrences before `start_char` and `end_char`.

### 4. `honeydew/app/state.mbt`

- Replace `sql_input: @widget.Input` with `sql_input: @widget.TextArea`.
- Update `AppState::new` initializer.
- Update status hint: `"Tab=パネル切替  Ctrl+Enter=実行  q=終了"`.

### 5. `honeydew/cmd/main/main.mbt`

- `Enter` in Editor → dispatch to TextArea (inserts newline).
- `CtrlEnter` in Editor → `run_query_at_cursor(state)`.
- After every cursor-moving key in Editor → recompute highlight and call `with_highlight`.
- `run_query_at_cursor`: calls `current_statement`, executes that SQL via `DbHandle::query`.

### 6. `honeydew/ui/main_screen.mbt`

- Render `state.sql_input` as `TextArea` (already a `Widget`).

## Error Handling

- Empty statement → no-op (no query issued).
- SQL error → display in status bar (existing behavior, no crash).
- `;` inside string literals: basic handling — scan for `'...'` and skip `;` inside them.

## Testing

- Unit test `current_statement()` for: single statement, multiple statements, cursor at boundary, trailing `;`, statement inside quotes.
- Existing 56 tests must continue to pass.
