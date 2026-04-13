///|
test "sql_highlight_lines empty string returns one empty segment list" {
  let lines = sql_highlight_lines("")
  assert_eq(lines.length(), 1)
  assert_eq(lines[0], ([] : Array[(String, @style.Style)]))
}

///|
test "push_styled_segment ignores empty string" {
  // Verify that passing "" to push_styled_segment is a no-op
  let segs : Array[(String, @style.Style)] = []
  push_styled_segment(segs, "", @style.Style::default())
  assert_eq(segs.length(), 0)
}

///|
test "scan_string_literal handles escaped single quote ''" {
  // SQL escapes a single quote by doubling it: 'it''s'
  let (end, closed) = scan_string_literal("'it''s'", 0)
  assert_eq(closed, true)
  assert_eq(end, 7)
}

///|
test "sql_highlight_lines colors keywords strings and comments" {
  let lines = sql_highlight_lines("SELECT 'hi' -- note")
  let keyword_style = sql_keyword_style()
  let string_style = sql_string_style()
  let comment_style = sql_comment_style()
  assert_eq(lines.length(), 1)
  assert_eq(lines[0], [
    ("SELECT", keyword_style),
    (" ", @style.Style::default()),
    ("'hi'", string_style),
    (" ", @style.Style::default()),
    ("-- note", comment_style),
  ])
}

///|
test "sql_highlight_lines continues string literal across lines" {
  // String opened on line 1, closed on line 2
  let lines = sql_highlight_lines("WHERE x = 'hello\nworld'")
  let string_style = sql_string_style()
  let keyword_style = sql_keyword_style()
  assert_eq(lines.length(), 2)
  // line 1: keyword + plain + unclosed string
  assert_eq(lines[0], [
    ("WHERE", keyword_style),
    (" x = ", @style.Style::default()),
    ("'hello", string_style),
  ])
  // line 2: continuation in StringLiteral mode, string closes here
  assert_eq(lines[1], [("world'", string_style)])
}

///|
test "sql_highlight_lines keeps block comments across lines" {
  let lines = sql_highlight_lines("/* note\nstill */\nSELECT")
  let comment_style = sql_comment_style()
  let keyword_style = sql_keyword_style()
  assert_eq(lines.length(), 3)
  assert_eq(lines[0], [("/* note", comment_style)])
  assert_eq(lines[1], [("still */", comment_style)])
  assert_eq(lines[2], [("SELECT", keyword_style)])
}
