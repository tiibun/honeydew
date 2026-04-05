///|
/// A `Frame` is passed to the draw closure each tick.
/// It holds the current buffer and exposes `render_widget`.
pub struct Frame {
  buf : @buffer.Buffer
}

///|
/// Return the full terminal area this frame covers.
pub fn Frame::size(self : Frame) -> @layout.Rect {
  self.buf.area
}

///|
/// Render `widget` into `area` within the current frame's buffer.
pub fn[W : @widget.Widget] Frame::render_widget(
  self : Frame,
  widget : W,
  area : @layout.Rect,
) -> Unit {
  widget.render(area, self.buf)
}

///|
/// `Terminal` owns the double buffer and raw-mode state.
/// Obtain one with `Terminal::new()`, then call `draw()` each frame.
pub struct Terminal {
  current : @buffer.Buffer
  previous : @buffer.Buffer
  raw : @terminal.RawMode
}

///|
/// Initialize the terminal: enter raw mode, alternate screen, hide cursor.
/// Returns an error string on failure.
pub fn Terminal::new() -> Result[Terminal, String] {
  let raw = match @terminal.RawMode::enter() {
    Ok(r) => r
    Err(e) => return Err(e)
  }
  let (cols, rows) = match @terminal.get_size() {
    Ok(s) => s
    Err(e) => {
      let _ = raw.exit()
      return Err(e)
    }
  }
  let area = @layout.Rect::new(1, 1, cols, rows)
  @terminal.write(@terminal.enter_alternate_screen())
  @terminal.write(@terminal.cursor_hide())
  @terminal.write(@terminal.clear_all())
  Ok({
    current: @buffer.Buffer::new(area),
    previous: @buffer.Buffer::new(area),
    raw,
  })
}

///|
/// Restore the terminal to its original state.
pub fn Terminal::restore(self : Terminal) -> Unit {
  @terminal.write(@terminal.cursor_show())
  @terminal.write(@terminal.leave_alternate_screen())
  let _ = self.raw.exit()
}

///|
/// Draw one frame. Clears the current buffer, calls `f` with a `Frame`,
/// then flushes only the changed cells to stdout.
pub fn Terminal::draw(self : Terminal, f : (Frame) -> Unit) -> Unit {
  self.current.clear()
  let frame = Frame::{ buf: self.current }
  f(frame)
  self.flush_diff()
  self.previous.copy_from(self.current)
}

///|
/// Write only the cells that changed since the last frame.
fn Terminal::flush_diff(self : Terminal) -> Unit {
  let changes = self.current.diff(self.previous)
  if changes.is_empty() {
    return
  }
  let out = StringBuilder::new()
  for change in changes {
    let (x, y, cell) = change
    out.write_string(@terminal.cursor_goto(x, y))
    out.write_string(cell.style.to_ansi())
    out.write_string(cell.symbol)
  }
  out.write_string(@terminal.reset())
  @terminal.write(out.to_string())
}

///|
/// Read a single key event (async).
pub async fn Terminal::read_key(self : Terminal) -> @terminal.Key {
  let _ = self
  @terminal.read_key()
}
