///|
// Tests for Enter on schema tree auto-filling SELECT query (TODO #7).

///|
async test "Enter on table node fills editor with SELECT and focuses editor" {
  @async.with_task_group(async fn(group) {
    let conn = match @sqlite.SqliteConn::open(":memory:") {
      Ok(c) => c
      Err(e) => fail("open failed: \{e}")
    }
    // Create a table so the schema tree has something
    ignore(conn.query("CREATE TABLE users (id INTEGER, name TEXT)"))
    let state = {
      ..@app.AppState::new(group),
      screen: @app.Main,
      focus: @app.Schema,
      conn: Some(conn),
      schema_tree: @app.build_schema_tree(conn, "main"),
    }
    // Navigate to the table node: root is selected initially; Down moves to
    // "Tables" group; Down again moves to "users"
    let s1 = { ..state, schema_tree: state.schema_tree.handle_key(Down) }
    let s2 = { ..s1, schema_tree: s1.schema_tree.handle_key(Down) }
    let after = handle_key(s2, Enter)
    assert_true(after.focus is @app.Editor)
    assert_true(after.sql_input.value().contains("SELECT * FROM users"))
    assert_true(after.sql_input.value().contains("LIMIT 100"))
    conn.close()
  })
}

///|
async test "Enter on group node (Tables) toggles expand without filling editor" {
  @async.with_task_group(async fn(group) {
    let conn = match @sqlite.SqliteConn::open(":memory:") {
      Ok(c) => c
      Err(e) => fail("open failed: \{e}")
    }
    ignore(conn.query("CREATE TABLE t(x INT)"))
    let state = {
      ..@app.AppState::new(group),
      screen: @app.Main,
      focus: @app.Schema,
      conn: Some(conn),
      schema_tree: @app.build_schema_tree(conn, "main"),
    }
    // Navigate Down once: selects the "Tables" group node (depth 1)
    let s1 = { ..state, schema_tree: state.schema_tree.handle_key(Down) }
    let after = handle_key(s1, Enter)
    // Focus should stay on Schema (not Editor)
    assert_true(after.focus is @app.Schema)
    // Editor should be empty
    assert_eq(after.sql_input.value(), "")
    conn.close()
  })
}
