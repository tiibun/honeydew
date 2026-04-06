///|
/// A multi-line text editing widget.
/// Stores its own state (lines, cursor) so it can be held in application state
/// and updated on each key event.
pub struct TextArea {
  lines : Array[String]
  /// 0-indexed line of the cursor.
  cursor_line : Int
  /// Char index within the current line (0 = before first char).
  cursor_col : Int
  /// First visible line (for vertical scrolling).
  scroll_top : Int
  /// Line range [start, end] (inclusive) to render with a highlight background.
  highlight : (Int, Int)?
  focused : Bool
  style : @style.Style
  block : Block?
}

///|
pub fn TextArea::new() -> TextArea {
  {
    lines: [""],
    cursor_line: 0,
    cursor_col: 0,
    scroll_top: 0,
    highlight: None,
    focused: false,
    style: @style.Style::default(),
    block: None,
  }
}

///|
pub fn TextArea::with_value(self : TextArea, text : String) -> TextArea {
  let lines = split_lines(text)
  let last = lines.length() - 1
  { ..self, lines, cursor_line: last, cursor_col: lines[last].length() }
}

///|
pub fn TextArea::style(self : TextArea, style : @style.Style) -> TextArea {
  { ..self, style, }
}

///|
pub fn TextArea::block(self : TextArea, block : Block) -> TextArea {
  { ..self, block: Some(block) }
}

///|
pub fn TextArea::focused(self : TextArea, focused : Bool) -> TextArea {
  { ..self, focused, }
}

///|
/// Set the highlighted line range [start_line, end_line] (inclusive, 0-indexed).
pub fn TextArea::with_highlight(
  self : TextArea,
  start_line : Int,
  end_line : Int,
) -> TextArea {
  { ..self, highlight: Some((start_line, end_line)) }
}

///|
pub fn TextArea::clear_highlight(self : TextArea) -> TextArea {
  { ..self, highlight: None }
}

///|
/// Return the full text content (lines joined by newlines).
pub fn TextArea::value(self : TextArea) -> String {
  self.lines.join("\n")
}

///|
/// Return the absolute character offset of the cursor in `value()`.
pub fn TextArea::cursor_pos(self : TextArea) -> Int {
  let mut pos = 0
  for i = 0; i < self.cursor_line; i = i + 1 {
    pos = pos + self.lines[i].length() + 1 // +1 for '\n'
  }
  pos + self.cursor_col
}

///|
/// Handle a key event and return an updated TextArea.
pub fn TextArea::handle_key(self : TextArea, key : @terminal.Key) -> TextArea {
  match key {
    Char(c) => self.insert_char(c)
    Enter => self.insert_newline()
    Backspace => self.delete_backward()
    Delete => self.delete_forward()
    Left => self.move_left()
    Right => self.move_right()
    Up => self.move_up()
    Down => self.move_down()
    Home => { ..self, cursor_col: 0 }
    End => { ..self, cursor_col: self.lines[self.cursor_line].length() }
    _ => self
  }
}

///|
fn TextArea::insert_char(self : TextArea, c : Char) -> TextArea {
  let line = self.lines[self.cursor_line]
  let left = line[:self.cursor_col].to_string()
  let right = line[self.cursor_col:].to_string()
  let new_line = "\{left}\{c}\{right}"
  let new_lines = copy_lines(self.lines)
  new_lines[self.cursor_line] = new_line
  { ..self, lines: new_lines, cursor_col: self.cursor_col + 1 }
}

///|
fn TextArea::insert_newline(self : TextArea) -> TextArea {
  let line = self.lines[self.cursor_line]
  let left = line[:self.cursor_col].to_string()
  let right = line[self.cursor_col:].to_string()
  let new_lines : Array[String] = []
  for i = 0; i < self.lines.length(); i = i + 1 {
    if i == self.cursor_line {
      new_lines.push(left)
      new_lines.push(right)
    } else {
      new_lines.push(self.lines[i])
    }
  }
  { ..self, lines: new_lines, cursor_line: self.cursor_line + 1, cursor_col: 0 }
}

///|
fn TextArea::delete_backward(self : TextArea) -> TextArea {
  if self.cursor_col > 0 {
    let line = self.lines[self.cursor_line]
    let left = line[:self.cursor_col - 1].to_string()
    let right = line[self.cursor_col:].to_string()
    let new_lines = copy_lines(self.lines)
    new_lines[self.cursor_line] = "\{left}\{right}"
    { ..self, lines: new_lines, cursor_col: self.cursor_col - 1 }
  } else if self.cursor_line > 0 {
    // Merge with previous line
    let prev = self.lines[self.cursor_line - 1]
    let curr = self.lines[self.cursor_line]
    let merged = "\{prev}\{curr}"
    let new_col = prev.length()
    let new_lines : Array[String] = []
    for i = 0; i < self.lines.length(); i = i + 1 {
      if i == self.cursor_line - 1 {
        new_lines.push(merged)
      } else if i == self.cursor_line {
        // skip – merged into previous
      } else {
        new_lines.push(self.lines[i])
      }
    }
    {
      ..self,
      lines: new_lines,
      cursor_line: self.cursor_line - 1,
      cursor_col: new_col,
    }
  } else {
    self
  }
}

///|
fn TextArea::delete_forward(self : TextArea) -> TextArea {
  let line = self.lines[self.cursor_line]
  if self.cursor_col < line.length() {
    let left = line[:self.cursor_col].to_string()
    let right = line[self.cursor_col + 1:].to_string()
    let new_lines = copy_lines(self.lines)
    new_lines[self.cursor_line] = "\{left}\{right}"
    { ..self, lines: new_lines }
  } else if self.cursor_line < self.lines.length() - 1 {
    // Merge next line into current
    let curr = self.lines[self.cursor_line]
    let next = self.lines[self.cursor_line + 1]
    let merged = "\{curr}\{next}"
    let new_lines : Array[String] = []
    for i = 0; i < self.lines.length(); i = i + 1 {
      if i == self.cursor_line {
        new_lines.push(merged)
      } else if i == self.cursor_line + 1 {
        // skip
      } else {
        new_lines.push(self.lines[i])
      }
    }
    { ..self, lines: new_lines }
  } else {
    self
  }
}

///|
fn TextArea::move_left(self : TextArea) -> TextArea {
  if self.cursor_col > 0 {
    { ..self, cursor_col: self.cursor_col - 1 }
  } else if self.cursor_line > 0 {
    let prev_len = self.lines[self.cursor_line - 1].length()
    { ..self, cursor_line: self.cursor_line - 1, cursor_col: prev_len }
  } else {
    self
  }
}

///|
fn TextArea::move_right(self : TextArea) -> TextArea {
  let line = self.lines[self.cursor_line]
  if self.cursor_col < line.length() {
    { ..self, cursor_col: self.cursor_col + 1 }
  } else if self.cursor_line < self.lines.length() - 1 {
    { ..self, cursor_line: self.cursor_line + 1, cursor_col: 0 }
  } else {
    self
  }
}

///|
fn TextArea::move_up(self : TextArea) -> TextArea {
  if self.cursor_line > 0 {
    let new_line = self.cursor_line - 1
    let new_col = min(self.cursor_col, self.lines[new_line].length())
    { ..self, cursor_line: new_line, cursor_col: new_col }
  } else {
    self
  }
}

///|
fn TextArea::move_down(self : TextArea) -> TextArea {
  if self.cursor_line < self.lines.length() - 1 {
    let new_line = self.cursor_line + 1
    let new_col = min(self.cursor_col, self.lines[new_line].length())
    { ..self, cursor_line: new_line, cursor_col: new_col }
  } else {
    self
  }
}

///|
pub impl Widget for TextArea with render(self, area, buf) {
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
  let height = inner.height
  // Ensure scroll keeps cursor visible
  let scroll_top = clamp_scroll(self.scroll_top, self.cursor_line, height)
  let visible_lines = min(self.lines.length() - scroll_top, height)
  let hl_style = @style.Style::default().bg(@style.Yellow).fg(@style.Black)
  for row = 0; row < visible_lines; row = row + 1 {
    let line_idx = scroll_top + row
    let line = self.lines[line_idx]
    let y = inner.y + row
    // Determine line style (highlight or normal)
    let line_style = match self.highlight {
      Some((s, e)) =>
        if line_idx >= s && line_idx <= e {
          hl_style
        } else {
          self.style
        }
      None => self.style
    }
    buf.set_string(inner.x, y, line, line_style)
  }
  // Render cursor when focused
  if self.focused {
    let cursor_row = self.cursor_line - scroll_top
    if cursor_row >= 0 && cursor_row < height {
      let line = self.lines[self.cursor_line]
      let cursor_cols = @buffer.str_display_width(
        line[:self.cursor_col].to_string(),
      )
      let cx = inner.x + cursor_cols
      if cx < inner.x + inner.width {
        let cursor_char = if self.cursor_col < line.length() {
          line[self.cursor_col:self.cursor_col + 1].to_string()
        } else {
          " "
        }
        let cursor_style = @style.Style::default()
          .fg(@style.Black)
          .bg(@style.White)
        buf.set(
          cx,
          inner.y + cursor_row,
          @buffer.Cell::new(cursor_char, cursor_style),
        )
      }
    }
  }
}

///|
fn split_lines(text : String) -> Array[String] {
  if text == "" {
    return [""]
  }
  let result : Array[String] = []
  let mut start = 0
  let len = text.length()
  for i = 0; i < len; i = i + 1 {
    if text[i] == '\n' {
      result.push(text[start:i].to_string())
      start = i + 1
    }
  }
  result.push(text[start:].to_string())
  result
}

///|
fn copy_lines(lines : Array[String]) -> Array[String] {
  let result : Array[String] = []
  for line in lines {
    result.push(line)
  }
  result
}

///|
fn clamp_scroll(scroll_top : Int, cursor_line : Int, height : Int) -> Int {
  if cursor_line < scroll_top {
    cursor_line
  } else if cursor_line >= scroll_top + height {
    cursor_line - height + 1
  } else {
    scroll_top
  }
}

///|
fn min(a : Int, b : Int) -> Int {
  if a < b {
    a
  } else {
    b
  }
}
