///|
test "Table::selected_cell follows horizontal selection" {
  let table = @widget.Table::new(["id", "name"], [["1", "Ada"]]).handle_key(
    Right,
  )
  assert_eq(table.selected_cell(), Some("Ada"))
}

///|
test "Table renders selected cell style" {
  let area = @layout.Rect::new(1, 1, 10, 3)
  let buf = @buffer.Buffer::new(area)
  let table = @widget.Table::new(["id", "name"], [["1", "Ada"]]).handle_key(
    Right,
  )
  table.render(area, buf)
  let selected_style = @style.Style::default().fg(@style.Black).bg(@style.Cyan)
  assert_eq(buf.get(5, 2).style, selected_style)
  assert_eq(buf.get(1, 2).style, @style.Style::default())
}
