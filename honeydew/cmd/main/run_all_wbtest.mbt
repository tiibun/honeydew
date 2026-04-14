///|
// Tests for all_statements() SQL splitting and F5 run-all behaviour.

///|
test "all_statements splits on semicolons" {
  inspect(
    all_statements("SELECT 1; SELECT 2; SELECT 3"),
    content=(
      #|["SELECT 1", "SELECT 2", "SELECT 3"]
    ),
  )
}

///|
test "all_statements single statement without semicolon" {
  inspect(
    all_statements("SELECT 1"),
    content=(
      #|["SELECT 1"]
    ),
  )
}

///|
test "all_statements ignores semicolon inside single-quoted string" {
  inspect(
    all_statements("SELECT ';' AS s; SELECT 1"),
    content=(
      #|["SELECT ';' AS s", "SELECT 1"]
    ),
  )
}

///|
test "all_statements ignores semicolons inside comments" {
  inspect(
    all_statements(
      (
        #|-- comment;
        #|SELECT 1;
        #|/* keep; together */
        #|SELECT 2
        #|
      ),
    ),
    content=(
      #|["-- comment;\nSELECT 1", "/* keep; together */\nSELECT 2"]
    ),
  )
}

///|
test "all_statements ignores semicolons inside quoted identifiers" {
  inspect(
    all_statements(
      (
        #|SELECT "my;col" FROM t;
        #|SELECT `other;col` FROM t
        #|
      ),
    ),
    content=(
      #|["SELECT \"my;col\" FROM t", "SELECT `other;col` FROM t"]
    ),
  )
}

///|
test "all_statements empty string returns empty array" {
  inspect(
    all_statements(""),
    content=(
      #|[]
    ),
  )
}

///|
test "all_statements trims whitespace and skips blank segments" {
  inspect(
    all_statements("  SELECT 1 ;  ;  SELECT 2  "),
    content=(
      #|["SELECT 1", "SELECT 2"]
    ),
  )
}

///|
async test "F5 starts run_all when editor has multiple statements" {
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
      sql_input: @widget.TextArea::new().with_value("SELECT 1; SELECT 2"),
    }
    let after = handle_key(state, F5)
    assert_true(after.is_query_running())
    assert_true(after.status.contains("Running statement"))
    conn.close()
  })
}

///|
async test "F5 on empty editor does nothing" {
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
    }
    let after = handle_key(state, F5)
    assert_eq(after.is_query_running(), false)
    conn.close()
  })
}
