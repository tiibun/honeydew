///|
test "Buffer get on blank cell" {
  let area = @layout.Rect::new(1, 1, 10, 5)
  let buf = @buffer.Buffer::new(area)
  let cell = buf.get(1, 1)
  assert_eq(cell.symbol, " ")
}

///|
test "Buffer set and get" {
  let area = @layout.Rect::new(1, 1, 10, 5)
  let buf = @buffer.Buffer::new(area)
  let style = @style.Style::default().fg(@style.Red)
  buf.set(3, 2, @buffer.Cell::new("X", style))
  let cell = buf.get(3, 2)
  assert_eq(cell.symbol, "X")
  assert_eq(cell.style, style)
}

///|
test "Buffer set out of bounds is ignored" {
  let area = @layout.Rect::new(1, 1, 10, 5)
  let buf = @buffer.Buffer::new(area)
  // Should not panic
  buf.set(99, 99, @buffer.Cell::new("!", @style.Style::default()))
  assert_eq(buf.get(99, 99).symbol, " ")
}

///|
test "Buffer set_string writes characters" {
  let area = @layout.Rect::new(1, 1, 20, 5)
  let buf = @buffer.Buffer::new(area)
  let style = @style.Style::default()
  buf.set_string(1, 1, "hello", style)
  assert_eq(buf.get(1, 1).symbol, "h")
  assert_eq(buf.get(2, 1).symbol, "e")
  assert_eq(buf.get(5, 1).symbol, "o")
  assert_eq(buf.get(6, 1).symbol, " ") // next cell is blank
}

///|
test "Buffer set_string clips at right edge" {
  let area = @layout.Rect::new(1, 1, 5, 3)
  let buf = @buffer.Buffer::new(area)
  buf.set_string(3, 1, "hello", @style.Style::default())
  // area covers x=1..5, starting at x=3: fits 'h','e','l' (x=3,4,5)
  assert_eq(buf.get(3, 1).symbol, "h")
  assert_eq(buf.get(5, 1).symbol, "l")
}

///|
test "Buffer diff returns changed cells" {
  let area = @layout.Rect::new(1, 1, 10, 5)
  let prev = @buffer.Buffer::new(area)
  let curr = @buffer.Buffer::new(area)
  curr.set(2, 2, @buffer.Cell::new("A", @style.Style::default()))
  let changes = curr.diff(prev)
  assert_eq(changes.length(), 1)
  let (x, y, cell) = changes[0]
  assert_eq(x, 2)
  assert_eq(y, 2)
  assert_eq(cell.symbol, "A")
}

///|
test "Buffer diff no changes" {
  let area = @layout.Rect::new(1, 1, 10, 5)
  let buf = @buffer.Buffer::new(area)
  let changes = buf.diff(buf)
  assert_eq(changes.length(), 0)
}

///|
test "Buffer set inherits bg from existing cell when new bg is Default" {
  let area = @layout.Rect::new(0, 0, 5, 1)
  let buf = @buffer.Buffer::new(area)
  // Paint a black background.
  let bg_style = @style.Style::default().bg(@style.Black)
  buf.set(0, 0, @buffer.Cell::new(" ", bg_style))
  // Write text with fg only (bg = Default) — should inherit Black.
  let fg_style = @style.Style::default().fg(@style.White)
  buf.set(0, 0, @buffer.Cell::new("A", fg_style))
  let cell = buf.get(0, 0)
  assert_eq(cell.symbol, "A")
  assert_eq(cell.style.fg, @style.White)
  assert_eq(cell.style.bg, @style.Black)
}

///|
test "Buffer set does not inherit bg when new bg is explicit" {
  let area = @layout.Rect::new(0, 0, 5, 1)
  let buf = @buffer.Buffer::new(area)
  buf.set(
    0,
    0,
    @buffer.Cell::new(" ", @style.Style::default().bg(@style.Black)),
  )
  buf.set(0, 0, @buffer.Cell::new("A", @style.Style::default().bg(@style.Red)))
  assert_eq(buf.get(0, 0).style.bg, @style.Red)
}

///|
test "Buffer clear resets all cells" {
  let area = @layout.Rect::new(1, 1, 10, 5)
  let buf = @buffer.Buffer::new(area)
  buf.set(3, 3, @buffer.Cell::new("Z", @style.Style::default()))
  buf.clear()
  assert_eq(buf.get(3, 3).symbol, " ")
}
