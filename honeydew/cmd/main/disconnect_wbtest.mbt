///|
// Tests for Ctrl+D disconnect (TODO #3).

///|
async test "CtrlD on Main screen returns to Connect and closes connection" {
  @async.with_task_group(async fn(group) {
    let conn = match @sqlite.SqliteConn::open(":memory:") {
      Ok(c) => c
      Err(e) => fail("open failed: \{e}")
    }
    let state = {
      ..@app.AppState::new(group),
      screen: @app.Main,
      focus: @app.Editor,
      conn: Some(@app.DbHandle::Sqlite(conn)),
      in_transaction: true,
    }
    let after = handle_key(state, CtrlD)
    assert_true(after.screen is @app.Connect)
    assert_true(after.conn is None)
    assert_eq(after.in_transaction, false)
    assert_eq(after.is_query_running(), false)
  })
}

///|
async test "CtrlD on Connect screen does nothing" {
  @async.with_task_group(async fn(group) {
    let state = { ..@app.AppState::new(group), screen: @app.Connect }
    let after = handle_key(state, CtrlD)
    assert_true(after.screen is @app.Connect)
  })
}

///|
async test "CtrlD while query is running is ignored" {
  @async.with_task_group(async fn(group) {
    let conn = match @sqlite.SqliteConn::open(":memory:") {
      Ok(c) => c
      Err(e) => fail("open failed: \{e}")
    }
    let state = {
      ..@app.AppState::new(group),
      screen: @app.Main,
      focus: @app.Editor,
      conn: Some(@app.DbHandle::Sqlite(conn)),
      running_query: Some(
        @app.RunningQuery::Single(
          sql="SELECT 1",
          started=@bench.monotonic_clock_start(),
        ),
      ),
    }
    let after = handle_key(state, CtrlD)
    // Still on Main, still running
    assert_true(after.screen is @app.Main)
    assert_true(after.is_query_running())
    conn.close()
  })
}
