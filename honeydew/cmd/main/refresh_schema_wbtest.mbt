///|
// Tests for Ctrl+L schema refresh (TODO #4).

///|
async test "CtrlL on Main screen rebuilds schema tree" {
  @async.with_task_group(async fn(group) {
    let conn = match @sqlite.SqliteConn::open(":memory:") {
      Ok(c) => c
      Err(e) => fail("open failed: \{e}")
    }
    let state = {
      ..@app.AppState::new(group),
      screen: @app.Main,
      focus: @app.Schema,
      conn: Some(conn),
    }
    let after = handle_key(state, CtrlL)
    assert_true(after.screen is @app.Main)
    assert_true(after.status.contains("Schema refreshed"))
    conn.close()
  })
}

///|
async test "CtrlL on Connect screen does nothing" {
  @async.with_task_group(async fn(group) {
    let state = { ..@app.AppState::new(group), screen: @app.Connect }
    let before_status = state.status
    let after = handle_key(state, CtrlL)
    assert_true(after.screen is @app.Connect)
    assert_eq(after.status, before_status)
  })
}
