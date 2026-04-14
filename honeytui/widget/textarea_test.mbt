///|
test "TextArea renders styled segments" {
  let area = @layout.Rect::new(1, 1, 20, 3)
  let buf = @buffer.Buffer::new(area)
  let keyword_style = @style.Style::default()
    .fg(@style.Yellow)
    .add_modifier(@style.bold)
  let string_style = @style.Style::default().fg(@style.Green)
  let ta = @widget.TextArea::new()
    .with_value("SELECT 'x'")
    .with_styled_lines([
      [
        ("SELECT", keyword_style),
        (" ", @style.Style::default()),
        ("'x'", string_style),
      ],
    ])
  ta.render(area, buf)
  assert_eq(buf.get(1, 1).symbol, "S")
  assert_eq(buf.get(1, 1).style, keyword_style)
  assert_eq(buf.get(8, 1).symbol, "'")
  assert_eq(buf.get(8, 1).style, string_style)
}

///|
test "TextArea renders line numbers when enabled" {
  let area = @layout.Rect::new(1, 1, 8, 2)
  let buf = @buffer.Buffer::new(area)
  let ta = @widget.TextArea::new().with_value("a\nbb").show_line_numbers(true)
  ta.render(area, buf)
  assert_eq(buf.get(1, 1).symbol, "1")
  assert_eq(buf.get(3, 1).symbol, "a")
  assert_eq(buf.get(1, 2).symbol, "2")
  assert_eq(buf.get(3, 2).symbol, "b")
}

///|
test "TextArea::with_cursor moves the cursor to a specific line and column" {
  let ta = @widget.TextArea::new().with_value("alpha\nbeta").with_cursor(0, 2)
  assert_eq(ta.cursor_pos(), 2)
  let moved = ta.with_cursor(1, 3)
  assert_eq(moved.cursor_pos(), 9)
}
