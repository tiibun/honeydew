///|
test "explain_prefix uses analyze for PostgreSQL" {
  assert_eq(explain_prefix(1), "EXPLAIN ANALYZE ")
  assert_eq(explain_prefix(0), "EXPLAIN ")
}

///|
async test "CtrlX runs EXPLAIN for the statement at the cursor" {
  @async.with_task_group(async fn(group) {
    let conn = match @sqlite.SqliteConn::open(":memory:") {
      Ok(c) => c
      Err(e) => fail("open failed: \{e}")
    }
    let state = {
      ..@app.AppState::new(group),
      screen: @app.Main,
      focus: @app.Editor,
      conn: Some(conn),
      sql_input: @widget.TextArea::new().with_value("SELECT 1;\nSELECT 2"),
    }
    let after = handle_key(state, CtrlX)
    assert_true(after.is_query_running())
    match after.running_query {
      Some(@app.RunningQuery::Single(sql~, started~)) => {
        let _ = started
        assert_eq(sql, "EXPLAIN SELECT 2")
      }
      _ => fail("expected single running query")
    }
    conn.close()
  })
}
