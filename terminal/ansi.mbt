///|
/// ANSI escape sequence helpers.
/// All functions return strings to be written to stdout.

///|
/// Move cursor to (col, row), 1-indexed.
pub fn cursor_goto(col : Int, row : Int) -> String {
  "\u001b[\{row};\{col}H"
}

///|
/// Hide the cursor.
pub fn cursor_hide() -> String {
  "\u001b[?25l"
}

///|
/// Show the cursor.
pub fn cursor_show() -> String {
  "\u001b[?25h"
}

///|
/// Clear the entire screen.
pub fn clear_all() -> String {
  "\u001b[2J"
}

///|
/// Clear from cursor to end of line.
pub fn clear_eol() -> String {
  "\u001b[K"
}

///|
/// Reset all attributes (color, bold, etc.).
pub fn reset() -> String {
  "\u001b[0m"
}

///|
/// Enter the alternate screen buffer.
pub fn enter_alternate_screen() -> String {
  "\u001b[?1049h"
}

///|
/// Leave the alternate screen buffer.
pub fn leave_alternate_screen() -> String {
  "\u001b[?1049l"
}
