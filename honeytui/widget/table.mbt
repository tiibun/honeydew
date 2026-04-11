///|
/// A table widget for displaying query results with a header row.
/// Supports vertical scrolling (row_offset) and horizontal scrolling
/// (col_offset, measured in columns not pixels).
pub struct Table {
  columns : Array[String]
  rows : Array[Array[String]]
  selected_row : Int
  selected_col : Int
  row_offset : Int
  col_offset : Int
  block : Block?
  header_style : @style.Style
  selected_style : @style.Style
  style : @style.Style
}

///|
pub fn Table::new(
  columns : Array[String],
  rows : Array[Array[String]],
) -> Table {
  {
    columns,
    rows,
    selected_row: 0,
    selected_col: 0,
    row_offset: 0,
    col_offset: 0,
    block: None,
    header_style: @style.Style::default()
    .fg(@style.Yellow)
    .add_modifier(@style.bold),
    selected_style: @style.Style::default().fg(@style.Black).bg(@style.Cyan),
    style: @style.Style::default(),
  }
}

///|
pub fn Table::block(self : Table, block : Block) -> Table {
  { ..self, block: Some(block) }
}

///|
pub fn Table::header_style(self : Table, style : @style.Style) -> Table {
  { ..self, header_style: style }
}

///|
pub fn Table::selected_style(self : Table, style : @style.Style) -> Table {
  { ..self, selected_style: style }
}

///|
pub fn Table::selected_cell(self : Table) -> String? {
  if self.selected_row < 0 || self.selected_row >= self.rows.length() {
    return None
  }
  let row = self.rows[self.selected_row]
  if self.selected_col < 0 || self.selected_col >= row.length() {
    None
  } else {
    Some(row[self.selected_col])
  }
}

///|
/// Handle key events for navigation.
pub fn Table::handle_key(self : Table, key : @terminal.Key) -> Table {
  let nrows = self.rows.length()
  let ncols = self.columns.length()
  match key {
    Up | Char('k') => {
      let s = if self.selected_row > 0 { self.selected_row - 1 } else { 0 }
      let off = if s < self.row_offset { s } else { self.row_offset }
      { ..self, selected_row: s, row_offset: off }
    }
    Down | Char('j') => {
      let s = if self.selected_row < nrows - 1 {
        self.selected_row + 1
      } else {
        self.selected_row
      }
      { ..self, selected_row: s }
    }
    Left => {
      let c = if self.selected_col > 0 { self.selected_col - 1 } else { 0 }
      let off = if c < self.col_offset { c } else { self.col_offset }
      { ..self, selected_col: c, col_offset: off }
    }
    Right => {
      let max_col = if ncols > 0 { ncols - 1 } else { 0 }
      let c = if self.selected_col < max_col {
        self.selected_col + 1
      } else {
        self.selected_col
      }
      { ..self, selected_col: c }
    }
    Home => { ..self, selected_row: 0, row_offset: 0 }
    End => { ..self, selected_row: if nrows > 0 { nrows - 1 } else { 0 } }
    _ => self
  }
}

///|
pub impl Widget for Table with render(self, area, buf) {
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
  let ncols = self.columns.length()
  if ncols == 0 {
    return
  }
  let col_offset = adjust_col_offset(
    self.columns,
    self.rows,
    self.col_offset,
    self.selected_col,
    inner.width,
  )
  // Compute visible columns starting from col_offset
  let visible_cols = compute_col_widths(
    self.columns,
    self.rows,
    col_offset,
    inner.width,
  )
  // Header row
  render_row(
    buf,
    inner.x,
    inner.y,
    inner.width,
    self.columns,
    col_offset,
    visible_cols,
    self.header_style,
    None,
    self.selected_style,
  )
  // Data rows (inner.height - 1 rows available after header)
  let row_area_h = inner.height - 1
  if row_area_h <= 0 {
    return
  }
  let nrows = self.rows.length()
  // Adjust row_offset so selected_row is visible
  let row_offset = if self.selected_row >= self.row_offset + row_area_h {
    self.selected_row - row_area_h + 1
  } else {
    self.row_offset
  }
  for i = 0; i < row_area_h && row_offset + i < nrows; i = i + 1 {
    let row_idx = row_offset + i
    let row = self.rows[row_idx]
    render_row(
      buf,
      inner.x,
      inner.y + 1 + i,
      inner.width,
      row,
      col_offset,
      visible_cols,
      self.style,
      if row_idx == self.selected_row {
        Some(self.selected_col)
      } else {
        None
      },
      self.selected_style,
    )
  }
}

///|
fn adjust_col_offset(
  columns : Array[String],
  rows : Array[Array[String]],
  col_offset : Int,
  selected_col : Int,
  available : Int,
) -> Int {
  let base = if selected_col < col_offset { selected_col } else { col_offset }
  let visible = compute_col_widths(columns, rows, base, available)
  if is_visible_column(visible, selected_col) {
    base
  } else {
    selected_col
  }
}

///|
fn is_visible_column(
  visible_cols : Array[(Int, Int)],
  selected_col : Int,
) -> Bool {
  for _, item in visible_cols {
    let (col_idx, _) = item
    if col_idx == selected_col {
      return true
    }
  }
  false
}

///|
/// Compute column widths for display, starting at col_offset,
/// fitting within `available` characters total.
/// Returns Array of (col_index, display_width).
fn compute_col_widths(
  columns : Array[String],
  rows : Array[Array[String]],
  col_offset : Int,
  available : Int,
) -> Array[(Int, Int)] {
  let result = []
  let mut used = 0
  let ncols = columns.length()
  for i = col_offset; i < ncols && used < available; i = i + 1 {
    // Column width = max of header and all cell values, capped at 30
    let mut w = columns[i].length()
    for row in rows {
      if i < row.length() {
        let cw = row[i].length()
        if cw > w {
          w = cw
        }
      }
    }
    if w > 30 {
      w = 30
    }
    if w < 3 {
      w = 3
    }
    // Add separator (│) unless first column
    let sep = if result.length() > 0 { 1 } else { 0 }
    if used + sep + w > available {
      w = available - used - sep
    }
    if w <= 0 {
      break
    }
    used = used + sep + w
    result.push((i, w))
  }
  result
}

///|
/// Render a single row of cells into the buffer.
fn render_row(
  buf : @buffer.Buffer,
  x : Int,
  y : Int,
  width : Int,
  values : Array[String],
  col_offset : Int,
  visible_cols : Array[(Int, Int)],
  style : @style.Style,
  selected_col : Int?,
  selected_style : @style.Style,
) -> Unit {
  let sep_style = @style.Style::default().fg(@style.BrightBlack)
  let mut cx = x
  let end_x = x + width
  for idx = 0; idx < visible_cols.length(); idx = idx + 1 {
    let (col_idx, col_w) = visible_cols[idx]
    // Separator
    if idx > 0 && cx < end_x {
      buf.set(cx, y, @buffer.Cell::new("│", sep_style))
      cx = cx + 1
    }
    // Cell value
    let raw = if col_idx < values.length() { values[col_idx] } else { "" }
    let cell_text = if raw.length() > col_w {
      raw[:col_w].to_string()
    } else {
      let pad = col_w - raw.length()
      "\{raw}\{String::make(pad, ' ')}"
    }
    let cell_style = match selected_col {
      Some(selected) => if col_idx == selected { selected_style } else { style }
      None => style
    }
    buf.set_string(cx, y, cell_text, cell_style)
    cx = cx + col_w
  }
  // Fill remaining width with spaces (clears stale content)
  while cx < end_x {
    buf.set(cx, y, @buffer.Cell::new(" ", style))
    cx = cx + 1
  }
  let _ = col_offset
}
