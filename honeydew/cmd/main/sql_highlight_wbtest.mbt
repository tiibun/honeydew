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
test "sql_highlight_lines keeps block comments across lines" {
  let lines = sql_highlight_lines("/* note\nstill */\nSELECT")
  let comment_style = sql_comment_style()
  let keyword_style = sql_keyword_style()
  assert_eq(lines.length(), 3)
  assert_eq(lines[0], [("/* note", comment_style)])
  assert_eq(lines[1], [("still */", comment_style)])
  assert_eq(lines[2], [("SELECT", keyword_style)])
}
