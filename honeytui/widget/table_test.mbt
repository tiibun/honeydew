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

///|
test "Table::selected_row returns the current row" {
  let table = @widget.Table::new(["id", "name"], [["1", "Ada"], ["2", "Bob"]]).handle_key(
    Down,
  )
  assert_eq(table.selected_row(), Some(["2", "Bob"]))
}

///|
test "Table renders custom cell styles" {
  let area = @layout.Rect::new(1, 1, 10, 3)
  let buf = @buffer.Buffer::new(area)
  let dim_style = @style.Style::default()
    .fg(@style.BrightBlack)
    .add_modifier(@style.italic)
  let table = @widget.Table::new(["value"], [["selected"], ["NULL"]]).with_cell_styles([
      [None],
      [Some(dim_style)],
    ],
  )
  table.render(area, buf)
  assert_eq(buf.get(1, 3).style, dim_style)
}

///|
test "Table::handle_click selects clicked cell" {
  let area = @layout.Rect::new(1, 1, 14, 5)
  let table = @widget.Table::new(["id", "name"], [["1", "Ada"], ["2", "Bob"]]).block(
    @widget.Block::new().borders(@widget.Borders::all()),
  )
  let clicked = table.handle_click(6, 4, area)
  assert_eq(clicked.selected_cell(), Some("Bob"))
}
