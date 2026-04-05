///|
/// A widget that renders a block of text, with optional word-wrap and scroll.
pub struct Paragraph {
  text : String
  style : @style.Style
  block : Block?
  scroll : Int
}

///|
pub fn Paragraph::new(text : String) -> Paragraph {
  { text, style: @style.Style::default(), block: None, scroll: 0 }
}

///|
pub fn Paragraph::style(self : Paragraph, style : @style.Style) -> Paragraph {
  { ..self, style, }
}

///|
pub fn Paragraph::block(self : Paragraph, block : Block) -> Paragraph {
  { ..self, block: Some(block) }
}

///|
/// Scroll down by `lines` lines.
pub fn Paragraph::scroll(self : Paragraph, lines : Int) -> Paragraph {
  { ..self, scroll: lines }
}

///|
pub impl Widget for Paragraph with render(self, area, buf) {
  // Render the surrounding block and get the inner area for text
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
  // Word-wrap the text into lines fitting inner.width
  let lines = wrap_text(self.text, inner.width)
  let mut row = inner.y
  let end_row = inner.y + inner.height
  for i = self.scroll; i < lines.length() && row < end_row; i = i + 1 {
    buf.set_string(inner.x, row, lines[i], self.style)
    row = row + 1
  }
}

///|
/// Split `text` into lines of at most `width` display columns, respecting newlines.
fn wrap_text(text : String, width : Int) -> Array[String] {
  let result = []
  let src_lines = text.split("\n")
  for src_line in src_lines {
    let line = src_line.to_string()
    if @buffer.str_display_width(line) <= width {
      result.push(line)
    } else {
      // Break long lines at word boundaries or hard-wrap
      let words = line.split(" ")
      let mut current = StringBuilder::new()
      let mut current_cols = 0
      for word in words {
        let w = word.to_string()
        let wcols = @buffer.str_display_width(w)
        if current_cols == 0 {
          current.write_string(w)
          current_cols = wcols
        } else if current_cols + 1 + wcols <= width {
          current.write_char(' ')
          current.write_string(w)
          current_cols = current_cols + 1 + wcols
        } else {
          result.push(current.to_string())
          current = StringBuilder::new()
          current.write_string(w)
          current_cols = wcols
        }
      }
      if current_cols > 0 {
        result.push(current.to_string())
      }
    }
  }
  result
}
