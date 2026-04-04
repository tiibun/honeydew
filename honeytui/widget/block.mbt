///|
/// Border style: which sides to draw.
pub struct Borders {
  top : Bool
  right : Bool
  bottom : Bool
  left : Bool
}

///|
pub fn Borders::all() -> Borders {
  { top: true, right: true, bottom: true, left: true }
}

///|
pub fn Borders::none() -> Borders {
  { top: false, right: false, bottom: false, left: false }
}

///|
/// A box with optional borders and an optional title.
pub struct Block {
  title : String
  borders : Borders
  border_style : @style.Style
  title_style : @style.Style
}

///|
pub fn Block::new() -> Block {
  {
    title: "",
    borders: Borders::none(),
    border_style: @style.Style::default(),
    title_style: @style.Style::default(),
  }
}

///|
pub fn Block::title(self : Block, title : String) -> Block {
  { ..self, title }
}

///|
pub fn Block::borders(self : Block, borders : Borders) -> Block {
  { ..self, borders }
}

///|
pub fn Block::border_style(self : Block, style : @style.Style) -> Block {
  { ..self, border_style: style }
}

///|
pub fn Block::title_style(self : Block, style : @style.Style) -> Block {
  { ..self, title_style: style }
}

///|
/// Return the inner rect (content area) after accounting for borders.
pub fn Block::inner(self : Block, area : @layout.Rect) -> @layout.Rect {
  let top = if self.borders.top { 1 } else { 0 }
  let bottom = if self.borders.bottom { 1 } else { 0 }
  let left = if self.borders.left { 1 } else { 0 }
  let right = if self.borders.right { 1 } else { 0 }
  let w = area.width - left - right
  let h = area.height - top - bottom
  @layout.Rect::new(
    area.x + left,
    area.y + top,
    if w > 0 { w } else { 0 },
    if h > 0 { h } else { 0 },
  )
}

///|
pub impl Widget for Block with render(self, area, buf) {
  if area.width < 2 || area.height < 2 {
    return
  }
  let x0 = area.x
  let y0 = area.y
  let x1 = area.x + area.width - 1
  let y1 = area.y + area.height - 1
  let bs = self.border_style
  // Corners and edges
  if self.borders.top && self.borders.left {
    buf.set(x0, y0, @buffer.Cell::new("┌", bs))
  }
  if self.borders.top && self.borders.right {
    buf.set(x1, y0, @buffer.Cell::new("┐", bs))
  }
  if self.borders.bottom && self.borders.left {
    buf.set(x0, y1, @buffer.Cell::new("└", bs))
  }
  if self.borders.bottom && self.borders.right {
    buf.set(x1, y1, @buffer.Cell::new("┘", bs))
  }
  // Top and bottom edges
  if self.borders.top || self.borders.bottom {
    for col = x0 + 1; col < x1; col = col + 1 {
      if self.borders.top {
        buf.set(col, y0, @buffer.Cell::new("─", bs))
      }
      if self.borders.bottom {
        buf.set(col, y1, @buffer.Cell::new("─", bs))
      }
    }
  }
  // Left and right edges
  if self.borders.left || self.borders.right {
    for row = y0 + 1; row < y1; row = row + 1 {
      if self.borders.left {
        buf.set(x0, row, @buffer.Cell::new("│", bs))
      }
      if self.borders.right {
        buf.set(x1, row, @buffer.Cell::new("│", bs))
      }
    }
  }
  // Title (drawn on the top border, left-aligned with one space padding)
  if self.title != "" && self.borders.top {
    let max_len = area.width - 2
    let t = if self.title.length() > max_len {
      self.title[:max_len].to_string()
    } else {
      self.title
    }
    buf.set_string(x0 + 1, y0, t, self.title_style)
  }
}
