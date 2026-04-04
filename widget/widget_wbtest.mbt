///|
test "wrap_text short line unchanged" {
  let lines = wrap_text("hello", 20)
  assert_eq(lines, ["hello"])
}

///|
test "wrap_text respects newlines" {
  let lines = wrap_text("foo\nbar\nbaz", 20)
  assert_eq(lines, ["foo", "bar", "baz"])
}

///|
test "wrap_text wraps long line at word boundary" {
  let lines = wrap_text("one two three four", 9)
  assert_eq(lines, ["one two", "three", "four"])
}

///|
test "wrap_text empty string" {
  let lines = wrap_text("", 20)
  assert_eq(lines, [""])
}
