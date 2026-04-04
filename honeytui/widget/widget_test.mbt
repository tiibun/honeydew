///|
test "Block::inner with all borders" {
  let area = @layout.Rect::new(1, 1, 20, 10)
  let block = @widget.Block::new().borders(@widget.Borders::all())
  let inner = block.inner(area)
  assert_eq(inner.x, 2)
  assert_eq(inner.y, 2)
  assert_eq(inner.width, 18)
  assert_eq(inner.height, 8)
}

///|
test "Block::inner with no borders" {
  let area = @layout.Rect::new(1, 1, 20, 10)
  let block = @widget.Block::new().borders(@widget.Borders::none())
  let inner = block.inner(area)
  assert_eq(inner.x, 1)
  assert_eq(inner.y, 1)
  assert_eq(inner.width, 20)
  assert_eq(inner.height, 10)
}

///|
test "Block renders border corners" {
  let area = @layout.Rect::new(1, 1, 10, 5)
  let buf = @buffer.Buffer::new(area)
  let block = @widget.Block::new().borders(@widget.Borders::all())
  block.render(area, buf)
  assert_eq(buf.get(1, 1).symbol, "┌")
  assert_eq(buf.get(10, 1).symbol, "┐")
  assert_eq(buf.get(1, 5).symbol, "└")
  assert_eq(buf.get(10, 5).symbol, "┘")
}

///|
test "Block renders top edge" {
  let area = @layout.Rect::new(1, 1, 10, 5)
  let buf = @buffer.Buffer::new(area)
  let block = @widget.Block::new().borders(@widget.Borders::all())
  block.render(area, buf)
  assert_eq(buf.get(2, 1).symbol, "─")
  assert_eq(buf.get(9, 1).symbol, "─")
}

///|
test "Block renders title on top border" {
  let area = @layout.Rect::new(1, 1, 20, 5)
  let buf = @buffer.Buffer::new(area)
  let block = @widget.Block::new()
    .borders(@widget.Borders::all())
    .title("hi")
  block.render(area, buf)
  assert_eq(buf.get(2, 1).symbol, "h")
  assert_eq(buf.get(3, 1).symbol, "i")
}

///|
test "Paragraph renders text" {
  let area = @layout.Rect::new(1, 1, 20, 5)
  let buf = @buffer.Buffer::new(area)
  let para = @widget.Paragraph::new("hello")
  para.render(area, buf)
  assert_eq(buf.get(1, 1).symbol, "h")
  assert_eq(buf.get(5, 1).symbol, "o")
}

///|
test "Paragraph with block renders inside border" {
  let area = @layout.Rect::new(1, 1, 20, 5)
  let buf = @buffer.Buffer::new(area)
  let para = @widget.Paragraph::new("hi")
    .block(@widget.Block::new().borders(@widget.Borders::all()))
  para.render(area, buf)
  // Text starts inside the border (x=2, y=2)
  assert_eq(buf.get(2, 2).symbol, "h")
  assert_eq(buf.get(3, 2).symbol, "i")
}

///|
test "Paragraph multiline wraps correctly" {
  let area = @layout.Rect::new(1, 1, 20, 5)
  let buf = @buffer.Buffer::new(area)
  let para = @widget.Paragraph::new("line1\nline2")
  para.render(area, buf)
  assert_eq(buf.get(1, 1).symbol, "l") // line1
  assert_eq(buf.get(1, 2).symbol, "l") // line2
}
