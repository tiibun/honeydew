///|
test "Placement centers a fixed overlay" {
  let area = @layout.Rect::new(1, 1, 80, 24)
  let rect = @layout.Placement::new(@layout.Fixed(20), @layout.Fixed(8))
    .anchor(@layout.Center, @layout.Middle)
    .resolve(area)
  assert_eq(rect, @layout.Rect::new(31, 9, 20, 8))
}

///|
test "Placement anchors to the bottom-right with margins" {
  let area = @layout.Rect::new(1, 1, 80, 24)
  let rect = @layout.Placement::new(@layout.Fixed(18), @layout.Fixed(5))
    .anchor(@layout.Right, @layout.Bottom)
    .margin(2, 1)
    .resolve(area)
  assert_eq(rect, @layout.Rect::new(61, 19, 18, 5))
}

///|
test "Placement clamps oversized overlays into the parent rect" {
  let area = @layout.Rect::new(1, 1, 10, 4)
  let rect = @layout.Placement::new(@layout.AtMost(20), @layout.AtMost(10))
    .anchor(@layout.Center, @layout.Middle)
    .resolve(area)
  assert_eq(rect, @layout.Rect::new(1, 1, 10, 4))
}

///|
test "Placement resolves percentages after margins" {
  let area = @layout.Rect::new(1, 1, 100, 20)
  let rect = @layout.Placement::new(@layout.Percent(50), @layout.Fill)
    .anchor(@layout.Left, @layout.Top)
    .margin(2, 1)
    .resolve(area)
  assert_eq(rect, @layout.Rect::new(3, 2, 48, 18))
}
