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
  let block = @widget.Block::new().borders(@widget.Borders::all()).title("hi")
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
  let para = @widget.Paragraph::new("hi").block(
    @widget.Block::new().borders(@widget.Borders::all()),
  )
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

// ── Tree widget ────────────────────────────────────────────────────────────

///|
test "Tree starts with selection 0 and root has no data" {
  let t = @widget.Tree::new([
    @widget.TreeItem::node("db", 0),
    @widget.TreeItem::leaf("table1", 1, "table1"),
  ])
  assert_eq(t.selected_data(), None) // root node has no payload
}

///|
test "Tree visible_count reflects expand state" {
  let t = @widget.Tree::new([
    @widget.TreeItem::node("db", 0),
    @widget.TreeItem::node("Tables", 1),
    @widget.TreeItem::leaf("t1", 2, "t1"),
    @widget.TreeItem::leaf("t2", 2, "t2"),
  ])
  // All expanded by default: all 4 items visible.
  assert_eq(t.visible_count(), 4)
}

///|
test "Tree collapsed root hides all children" {
  let t = @widget.Tree::new([
    @widget.TreeItem::collapsed_node("db", 0),
    @widget.TreeItem::node("Tables", 1),
    @widget.TreeItem::leaf("t1", 2, "t1"),
  ])
  assert_eq(t.visible_count(), 1) // only root
}

///|
test "Tree collapsed group hides its leaves but shows siblings" {
  let t = @widget.Tree::new([
    @widget.TreeItem::node("db", 0),
    @widget.TreeItem::collapsed_node("Tables", 1),
    @widget.TreeItem::leaf("t1", 2, "t1"),
    @widget.TreeItem::node("Views", 1),
    @widget.TreeItem::leaf("v1", 2, "v1"),
  ])
  // db, Tables (collapsed), Views, v1 — but NOT t1
  assert_eq(t.visible_count(), 4)
}

///|
test "Tree Down moves to next visible item and returns its data" {
  let t = @widget.Tree::new([
    @widget.TreeItem::node("db", 0),
    @widget.TreeItem::leaf("t1", 1, "t1"),
  ])
  let t2 = t.handle_key(Down)
  assert_eq(t2.selected_data(), Some("t1"))
}

///|
test "Tree Up does not go below 0" {
  let t = @widget.Tree::new([
    @widget.TreeItem::node("db", 0),
    @widget.TreeItem::leaf("t1", 1, "t1"),
  ])
  let t2 = t.handle_key(Up)
  assert_eq(t2.selected, 0)
}

///|
test "Tree Enter toggles root: collapse hides child" {
  let t = @widget.Tree::new([
    @widget.TreeItem::node("db", 0),
    @widget.TreeItem::leaf("t1", 1, "t1"),
  ])
  // Collapse root with Enter
  let t2 = t.handle_key(Enter)
  assert_eq(t2.visible_count(), 1)
  // Down should not move (only 1 visible item)
  let t3 = t2.handle_key(Down)
  assert_eq(t3.selected, 0)
}

///|
test "Tree Right expands collapsed node" {
  let t = @widget.Tree::new([
    @widget.TreeItem::collapsed_node("db", 0),
    @widget.TreeItem::leaf("t1", 1, "t1"),
  ])
  assert_eq(t.visible_count(), 1)
  let t2 = t.handle_key(Right)
  assert_eq(t2.visible_count(), 2)
}

///|
test "Tree Left on leaf moves to parent" {
  let t = @widget.Tree::new([
    @widget.TreeItem::node("db", 0),
    @widget.TreeItem::leaf("t1", 1, "t1"),
  ])
  // Go to leaf
  let t2 = t.handle_key(Down)
  assert_eq(t2.selected, 1)
  // Left on leaf → move to parent
  let t3 = t2.handle_key(Left)
  assert_eq(t3.selected, 0)
  assert_eq(t3.selected_data(), None) // parent has no data
}

///|
test "Tree Left on expanded node collapses it" {
  let t = @widget.Tree::new([
    @widget.TreeItem::node("db", 0),
    @widget.TreeItem::leaf("t1", 1, "t1"),
  ])
  // Root is expanded and selected; Left should collapse it.
  let t2 = t.handle_key(Left)
  assert_eq(t2.visible_count(), 1)
  assert_eq(t2.selected, 0)
}

///|
test "Tree renders icon and indentation" {
  let area = @layout.Rect::new(1, 1, 20, 5)
  let buf = @buffer.Buffer::new(area)
  let t = @widget.Tree::new([
    @widget.TreeItem::node("db", 0),
    @widget.TreeItem::leaf("t1", 1, "t1"),
  ])
  t.render(area, buf)
  // Row 0 starts with ▼ (expanded node icon)
  assert_eq(buf.get(1, 1).symbol, "▼")
  // Row 1 is indented 2 spaces then 2-space icon placeholder
  assert_eq(buf.get(1, 2).symbol, " ")
  assert_eq(buf.get(2, 2).symbol, " ")
  assert_eq(buf.get(3, 2).symbol, " ")
  assert_eq(buf.get(4, 2).symbol, " ")
  assert_eq(buf.get(5, 2).symbol, "t")
}

///|
test "Tree::replace_selected_children inserts lazy-loaded children under selected node" {
  let t = @widget.Tree::new([
    @widget.TreeItem::node("db", 0),
    @widget.TreeItem::node("Tables", 1),
    @widget.TreeItem::collapsed_node_with_data("users", 2, "table:users"),
  ])
  let selected = t.handle_key(Down).handle_key(Down)
  let expanded = selected.replace_selected_children([
    @widget.TreeItem::leaf("id : INTEGER", 3, "id"),
    @widget.TreeItem::leaf("INDEX users_name_idx", 3, "users_name_idx"),
  ])
  assert_eq(expanded.visible_count(), 5)
  assert_true(
    expanded.selected_item() is Some(item) &&
    item.label == "users" &&
    item.depth == 2 &&
    item.expandable &&
    item.expanded &&
    item.data == "table:users",
  )
}
