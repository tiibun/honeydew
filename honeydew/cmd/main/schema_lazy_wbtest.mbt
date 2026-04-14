///|
async test "Right on a table node lazy-loads columns, indexes, and triggers" {
  @async.with_task_group(async fn(group) {
    let conn = match @sqlite.SqliteConn::open(":memory:") {
      Ok(c) => c
      Err(e) => fail("open failed: \{e}")
    }
    ignore(conn.query("CREATE TABLE users (id INTEGER, name TEXT)"))
    ignore(conn.query("CREATE INDEX users_name_idx ON users(name)"))
    ignore(
      conn.query(
        "CREATE TRIGGER users_touch AFTER INSERT ON users BEGIN UPDATE users SET name = NEW.name WHERE id = NEW.id; END",
      ),
    )
    let state = {
      ..@app.AppState::new(group),
      screen: @app.Main,
      focus: @app.Schema,
      conn: Some(conn),
      schema_tree: @app.build_schema_tree(conn, "main"),
    }
    let selected_table = state.schema_tree.handle_key(Down).handle_key(Down)
    let after = handle_key({ ..state, schema_tree: selected_table }, Right)

    assert_true(after.schema_tree.visible_count() >= 5)
    let item1 = after.schema_tree.handle_key(Down).selected_item()
    let item2 = after.schema_tree
      .handle_key(Down)
      .handle_key(Down)
      .selected_item()
    let item3 = after.schema_tree
      .handle_key(Down)
      .handle_key(Down)
      .handle_key(Down)
      .selected_item()
    assert_true(item1 is Some(item) && item.label.contains("id : INTEGER"))
    assert_true(item2 is Some(item) && item.label.contains("name : TEXT"))
    assert_true(
      item3 is Some(item) && item.label.contains("INDEX users_name_idx"),
    )
    conn.close()
  })
}
