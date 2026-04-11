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
