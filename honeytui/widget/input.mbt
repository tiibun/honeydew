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
}

///|
pub fn Input::new() -> Input {
  {
    value: "",
    cursor: 0,
    style: @style.Style::default(),
    block: None,
    focused: false,
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
  // Determine the visible window of the value (scroll so cursor is in view)
  let width = inner.width
  let vlen = self.value.length()
  let scroll = if self.cursor >= width { self.cursor - width + 1 } else { 0 }
  let visible = if vlen > scroll { self.value[scroll:].to_string() } else { "" }
  buf.set_string(inner.x, inner.y, visible, self.style)
  // Render cursor highlight when focused
  if self.focused {
    let cx = inner.x + self.cursor - scroll
    if cx >= inner.x && cx < inner.x + inner.width {
      let cursor_char = if self.cursor < vlen {
        self.value[self.cursor:self.cursor + 1].to_string()
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
