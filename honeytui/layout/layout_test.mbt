///|
test "Rect::right and bottom" {
  let r = @layout.Rect::new(1, 1, 10, 5)
  assert_eq(r.right(), 11)
  assert_eq(r.bottom(), 6)
}

///|
test "Rect::inner removes border" {
  let r = @layout.Rect::new(1, 1, 20, 10)
  let inner = r.inner(1)
  assert_eq(inner.x, 2)
  assert_eq(inner.y, 2)
  assert_eq(inner.width, 18)
  assert_eq(inner.height, 8)
}

///|
test "Rect::inner too small returns zero" {
  let r = @layout.Rect::new(1, 1, 2, 2)
  let inner = r.inner(1)
  assert_eq(inner.width, 0)
  assert_eq(inner.height, 0)
}

///|
test "Layout vertical split equal halves" {
  let area = @layout.Rect::new(1, 1, 80, 24)
  let chunks = @layout.Layout::new(@layout.Vertical, [
    @layout.Percentage(50),
    @layout.Percentage(50),
  ]).split(area)
  assert_eq(chunks.length(), 2)
  assert_eq(chunks[0].y, 1)
  assert_eq(chunks[0].height, 12)
  assert_eq(chunks[1].y, 13)
  assert_eq(chunks[1].height, 12)
}

///|
test "Layout horizontal split" {
  let area = @layout.Rect::new(1, 1, 80, 24)
  let chunks = @layout.Layout::new(@layout.Horizontal, [
    @layout.Percentage(30),
    @layout.Percentage(70),
  ]).split(area)
  assert_eq(chunks.length(), 2)
  assert_eq(chunks[0].x, 1)
  assert_eq(chunks[0].width, 24)
  assert_eq(chunks[1].x, 25)
  // Last chunk gets the remainder
  assert_eq(chunks[1].width, 56)
}

///|
test "Layout Length constraint" {
  let area = @layout.Rect::new(1, 1, 80, 24)
  let chunks = @layout.Layout::new(@layout.Vertical, [
    @layout.Length(3),
    @layout.Length(18),
    @layout.Length(3),
  ]).split(area)
  assert_eq(chunks[0].height, 3)
  assert_eq(chunks[1].height, 18)
  assert_eq(chunks[2].height, 3)
}

///|
test "Layout with margin" {
  let area = @layout.Rect::new(1, 1, 80, 24)
  let chunks = @layout.Layout::new(@layout.Vertical, [@layout.Percentage(100)])
    .margin(2)
    .split(area)
  assert_eq(chunks[0].x, 3)
  assert_eq(chunks[0].y, 3)
  assert_eq(chunks[0].width, 76)
  assert_eq(chunks[0].height, 20)
}

///|
test "Layout empty constraints" {
  let area = @layout.Rect::new(1, 1, 80, 24)
  let chunks = @layout.Layout::new(@layout.Vertical, []).split(area)
  assert_eq(chunks.length(), 0)
}
