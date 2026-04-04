///|
/// A complete text style: foreground color, background color, and modifiers.
pub struct Style {
  fg : Color
  bg : Color
  modifiers : Modifier
} derive(Eq, Show)

///|
/// The default style: terminal default colors, no modifiers.
pub fn Style::default() -> Style {
  { fg: Default, bg: Default, modifiers: Modifier::empty() }
}

///|
/// Set the foreground color.
pub fn Style::fg(self : Style, color : Color) -> Style {
  { ..self, fg: color }
}

///|
/// Set the background color.
pub fn Style::bg(self : Style, color : Color) -> Style {
  { ..self, bg: color }
}

///|
/// Add a modifier (can be chained).
pub fn Style::add_modifier(self : Style, m : Modifier) -> Style {
  { ..self, modifiers: self.modifiers.or(m) }
}

///|
/// Render this style as an ANSI SGR escape sequence string.
/// e.g. "\u001b[1;31;42m"
pub fn Style::to_ansi(self : Style) -> String {
  let parts = []
  parts.push("0") // reset first
  for code in self.modifiers.sgr_codes() {
    parts.push(code)
  }
  parts.push(self.fg.fg_code())
  parts.push(self.bg.bg_code())
  let joined = parts.join(";")
  "\u001b[\{joined}m"
}
