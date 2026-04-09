///|
/// A single-line text input widget.
/// Holds its own state (value + cursor position) so it can be stored
/// in an application's state struct and updated on each key event.
pub struct Input {
  value : String
  /// Byte/char index of the cursor (0 = before first character).
  cursor : Int
  style : @style.Style
  block : Block?
  /// When true, the cursor is rendered as a highlighted cell.
  focused : Bool
  /// When true, the value is displayed as asterisks (password mode).
  mask : Bool
}

///|
pub fn Input::new() -> Input {
  {
    value: "",
    cursor: 0,
    style: @style.Style::default(),
    block: None,
    focused: false,
    mask: false,
  }
}

///|
pub fn Input::with_value(self : Input, value : String) -> Input {
  { ..self, value, cursor: value.length() }
}

///|
pub fn Input::style(self : Input, style : @style.Style) -> Input {
  { ..self, style, }
}

///|
pub fn Input::block(self : Input, block : Block) -> Input {
  { ..self, block: Some(block) }
}

///|
pub fn Input::focused(self : Input, focused : Bool) -> Input {
  { ..self, focused, }
}

///|
/// Enable or disable password masking (displays `*` in place of actual characters).
pub fn Input::masked(self : Input, mask : Bool) -> Input {
  { ..self, mask, }
}

///|
/// Return the current text value.
pub fn Input::value(self : Input) -> String {
  self.value
}

///|
/// Handle a key event and return an updated Input.
pub fn Input::handle_key(self : Input, key : @terminal.Key) -> Input {
  match key {
    Char(c) => {
      let left = self.value[:self.cursor].to_string()
      let right = self.value[self.cursor:].to_string()
      let new_value = "\{left}\{c}\{right}"
      { ..self, value: new_value, cursor: self.cursor + 1 }
    }
    Backspace =>
      if self.cursor == 0 {
        self
      } else {
        let left = self.value[:self.cursor - 1].to_string()
        let right = self.value[self.cursor:].to_string()
        { ..self, value: "\{left}\{right}", cursor: self.cursor - 1 }
      }
    Delete =>
      if self.cursor >= self.value.length() {
        self
      } else {
        let left = self.value[:self.cursor].to_string()
        let right = self.value[self.cursor + 1:].to_string()
        { ..self, value: "\{left}\{right}" }
      }
    Left =>
      { ..self, cursor: if self.cursor > 0 { self.cursor - 1 } else { 0 } }
    Right => {
      let max = self.value.length()
      { ..self, cursor: if self.cursor < max { self.cursor + 1 } else { max } }
    }
    Home => { ..self, cursor: 0 }
    End => { ..self, cursor: self.value.length() }
    _ => self
  }
}

///|
pub impl Widget for Input with render(self, area, buf) {
  let inner = match self.block {
    Some(b) => {
      b.render(area, buf)
      b.inner(area)
    }
    None => area
  }
  if inner.width == 0 || inner.height == 0 {
    return
  }
  let width = inner.width
  // Build the display value (masked or plain).
  let dv = if self.mask {
    let sb = StringBuilder::new()
    for _ in 0..<self.value.length() {
      sb.write_char('*')
    }
    sb.to_string()
  } else {
    self.value
  }
  // Compute display column of the cursor (in display columns, not code units).
  let cursor_cols = @buffer.str_display_width(dv[:self.cursor].to_string())
  // Scroll so that cursor is always visible (in display columns).
  let scroll_cols = if cursor_cols >= width {
    cursor_cols - width + 1
  } else {
    0
  }
  // Convert scroll_cols (display cols) to a char index for slicing.
  let scroll = display_to_char_index(dv, scroll_cols)
  let visible = if dv.length() > scroll { dv[scroll:].to_string() } else { "" }
  buf.set_string(inner.x, inner.y, visible, self.style)
  // Render cursor highlight when focused
  if self.focused {
    let cx = inner.x + cursor_cols - scroll_cols
    if cx >= inner.x && cx < inner.x + inner.width {
      let cursor_char = if self.cursor < dv.length() {
        dv[self.cursor:self.cursor + 1].to_string()
      } else {
        " "
      }
      let cursor_style = @style.Style::default()
        .fg(@style.Black)
        .bg(@style.White)
      buf.set(cx, inner.y, @buffer.Cell::new(cursor_char, cursor_style))
    }
  }
}

///|
/// Return the char index in `s` at which the cumulative display width
/// first reaches or exceeds `display_cols`. Used for scroll offset conversion.
fn display_to_char_index(s : String, display_cols : Int) -> Int {
  let mut cols = 0
  let mut idx = 0
  for c in s.iter() {
    if cols >= display_cols {
      break
    }
    cols = cols + @buffer.char_display_width(c)
    idx = idx + 1
  }
  idx
}
