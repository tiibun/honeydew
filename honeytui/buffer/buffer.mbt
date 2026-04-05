///|
/// A single terminal cell: one character and its style.
pub struct Cell {
  symbol : String
  style : @style.Style
} derive(Eq)

///|
pub fn Cell::new(symbol : String, style : @style.Style) -> Cell {
  { symbol, style }
}

///|
pub fn Cell::blank() -> Cell {
  { symbol: " ", style: @style.Style::default() }
}

///|
/// A 2D grid of cells covering a `Rect`.
/// Cells are stored in row-major order.
pub struct Buffer {
  area : @layout.Rect
  cells : Array[Cell]
}

///|
pub fn Buffer::new(area : @layout.Rect) -> Buffer {
  let size = area.width * area.height
  { area, cells: Array::make(size, Cell::blank()) }
}

///|
/// Convert (x, y) absolute terminal coordinates to a flat array index.
/// Returns None if the coordinate is outside the buffer area.
fn Buffer::index(self : Buffer, x : Int, y : Int) -> Int? {
  let col = x - self.area.x
  let row = y - self.area.y
  if col < 0 || col >= self.area.width || row < 0 || row >= self.area.height {
    None
  } else {
    Some(row * self.area.width + col)
  }
}

///|
pub fn Buffer::get(self : Buffer, x : Int, y : Int) -> Cell {
  match self.index(x, y) {
    Some(i) => self.cells[i]
    None => Cell::blank()
  }
}

///|
pub fn Buffer::set(self : Buffer, x : Int, y : Int, cell : Cell) -> Unit {
  match self.index(x, y) {
    Some(i) => self.cells[i] = cell
    None => ()
  }
}

///|
/// Returns the terminal display width of a character (1 or 2 columns).
/// CJK ideographs, Hiragana, Katakana, Hangul, and fullwidth forms are 2.
pub fn char_display_width(c : Char) -> Int {
  let cp = c.to_int()
  if (cp >= 0x1100 && cp <= 0x115F) ||
    cp == 0x2329 ||
    cp == 0x232A ||
    (cp >= 0x2E80 && cp <= 0x303E) ||
    (cp >= 0x3040 && cp <= 0x33FF) ||
    (cp >= 0x3400 && cp <= 0x4DBF) ||
    (cp >= 0x4E00 && cp <= 0xA4CF) ||
    (cp >= 0xAC00 && cp <= 0xD7AF) ||
    (cp >= 0xF900 && cp <= 0xFAFF) ||
    (cp >= 0xFE10 && cp <= 0xFE1F) ||
    (cp >= 0xFE30 && cp <= 0xFE6F) ||
    (cp >= 0xFF00 && cp <= 0xFF60) ||
    (cp >= 0xFFE0 && cp <= 0xFFE6) ||
    (cp >= 0x1B000 && cp <= 0x1B0FF) ||
    (cp >= 0x20000 && cp <= 0x2FFFD) ||
    (cp >= 0x30000 && cp <= 0x3FFFD) {
    2
  } else {
    1
  }
}

///|
/// Returns the terminal display width (columns) of a string.
pub fn str_display_width(s : String) -> Int {
  let mut w = 0
  for c in s.iter() {
    w = w + char_display_width(c)
  }
  w
}

///|
/// Truncate `s` so its display width does not exceed `max_cols`.
pub fn truncate_to_width(s : String, max_cols : Int) -> String {
  let mut cols = 0
  let mut end = 0
  for c in s.iter() {
    let w = char_display_width(c)
    if cols + w > max_cols {
      break
    }
    cols = cols + w
    end = end + 1
  }
  if end >= s.length() {
    s
  } else {
    s[:end].to_string()
  }
}

///|
/// Write a styled string starting at (x, y), advancing x by each char's display width.
/// Wide characters (width=2) also blank their second cell to prevent stale content.
/// Stops at the right edge of the buffer.
pub fn Buffer::set_string(
  self : Buffer,
  x : Int,
  y : Int,
  text : String,
  style : @style.Style,
) -> Unit {
  let max_x = self.area.x + self.area.width
  let mut cur_x = x
  for ch in text.iter() {
    if cur_x >= max_x {
      break
    }
    let w = char_display_width(ch)
    self.set(cur_x, y, { symbol: ch.to_string(), style })
    if w == 2 && cur_x + 1 < max_x {
      self.set(cur_x + 1, y, { symbol: " ", style })
    }
    cur_x = cur_x + w
  }
}

///|
/// Compare this buffer against `previous` and return only the cells that changed,
/// as a list of (x, y, Cell) tuples.
pub fn Buffer::diff(
  self : Buffer,
  previous : Buffer,
) -> Array[(Int, Int, Cell)] {
  let changes = []
  let same_size = previous.area.width == self.area.width &&
    previous.area.height == self.area.height
  for row = 0; row < self.area.height; row = row + 1 {
    for col = 0; col < self.area.width; col = col + 1 {
      let i = row * self.area.width + col
      let curr = self.cells[i]
      let prev = if same_size { previous.cells[i] } else { Cell::blank() }
      if curr != prev {
        changes.push((self.area.x + col, self.area.y + row, curr))
      }
    }
  }
  changes
}

///|
/// Reset every cell to blank.
pub fn Buffer::clear(self : Buffer) -> Unit {
  for i = 0; i < self.cells.length(); i = i + 1 {
    self.cells[i] = Cell::blank()
  }
}

///|
/// Copy all cells from `src` into `self`. Buffers must have the same dimensions.
pub fn Buffer::copy_from(self : Buffer, src : Buffer) -> Unit {
  let len = self.cells.length().min(src.cells.length())
  for i = 0; i < len; i = i + 1 {
    self.cells[i] = src.cells[i]
  }
}
