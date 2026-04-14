///|
async test "CtrlF opens editor search and n/N move between matches" {
  @async.with_task_group(async fn(group) {
    let state = {
      ..@app.AppState::new(group),
      screen: @app.Main,
      focus: @app.Editor,
      sql_input: @widget.TextArea::new().with_value(
        "SELECT 1;\nSELECT 2;\nSELECT 3",
      ),
    }
    let opened = handle_key(state, CtrlF)
    assert_true(opened.search_input is Some(_))

    let s1 = handle_key(opened, Char('S'))
    let s2 = handle_key(s1, Char('E'))
    let s3 = handle_key(s2, Char('L'))
    let s4 = handle_key(s3, Char('E'))
    let searched = handle_key(s4, Char('C'))

    assert_eq(searched.search_matches.length(), 3)
    assert_eq(searched.search_match_index, 0)
    assert_eq(searched.sql_input.cursor_pos(), 0)
    assert_true(searched.search_editing)

    let browsing = handle_key(searched, Enter)
    assert_true(!browsing.search_editing)

    let next = handle_key(browsing, Char('n'))
    assert_eq(next.search_match_index, 1)
    assert_eq(next.sql_input.cursor_pos(), 10)

    let prev = handle_key(next, Char('N'))
    assert_eq(prev.search_match_index, 0)
    assert_eq(prev.sql_input.cursor_pos(), 0)
  })
}

///|
async test "Esc closes editor search and clears matches" {
  @async.with_task_group(async fn(group) {
    let state = {
      ..@app.AppState::new(group),
      screen: @app.Main,
      focus: @app.Editor,
      sql_input: @widget.TextArea::new().with_value("SELECT 1;\nSELECT 2"),
    }
    let opened = handle_key(state, CtrlF)
    let s1 = handle_key(opened, Char('S'))
    let s2 = handle_key(s1, Char('E'))
    let s3 = handle_key(s2, Char('L'))
    let s4 = handle_key(s3, Char('E'))
    let searched = handle_key(s4, Char('C'))

    let closed = handle_key(searched, Esc)
    assert_true(closed.search_input is None)
    assert_eq(closed.search_matches, [])
  })
}
