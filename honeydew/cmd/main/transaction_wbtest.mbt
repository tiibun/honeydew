///|
async test "handle_key CtrlB on Main screen calls begin_transaction (no conn → error)" {
  @async.with_task_group(group => {
    let state = {
      ..@app.AppState::new(group),
      screen: @app.Main,
      focus: @app.Editor,
    }
    let s = handle_key(state, CtrlB)
    assert_eq(s.in_transaction, false)
    assert_true(s.status.contains("Error"))
  })
}

///|
// CtrlR guard fires before connection check: not in transaction → warning, not error.
async test "handle_key CtrlR on Main screen with no txn gives guard warning" {
  @async.with_task_group(group => {
    let state = {
      ..@app.AppState::new(group),
      screen: @app.Main,
      focus: @app.Editor,
    }
    let s = handle_key(state, CtrlR)
    assert_eq(s.in_transaction, false)
    assert_true(s.status.contains("Not in a transaction"))
  })
}

///|
// CtrlM guard fires before connection check: not in transaction → warning, not error.
async test "handle_key CtrlM on Main screen with no txn gives guard warning" {
  @async.with_task_group(group => {
    let state = {
      ..@app.AppState::new(group),
      screen: @app.Main,
      focus: @app.Editor,
    }
    let s = handle_key(state, CtrlM)
    assert_eq(s.in_transaction, false)
    assert_true(s.status.contains("Not in a transaction"))
  })
}

///|
// CtrlB guard fires when already in a transaction.
async test "handle_key CtrlB when already in transaction gives guard warning" {
  @async.with_task_group(group => {
    let state = {
      ..@app.AppState::new(group),
      screen: @app.Main,
      focus: @app.Editor,
      in_transaction: true,
    }
    let s = handle_key(state, CtrlB)
    assert_eq(s.in_transaction, true)
    assert_true(s.status.contains("Already in a transaction"))
  })
}

///|
async test "handle_key CtrlB on Connect screen does nothing" {
  @async.with_task_group(group => {
    let state = { ..@app.AppState::new(group), screen: @app.Connect }
    let s = handle_key(state, CtrlB)
    assert_eq(s.in_transaction, false)
    assert_true(s.screen == @app.Connect)
  })
}

///|
/// Manually typing BEGIN via run_query_at_cursor syncs in_transaction to true.
async test "run_query_at_cursor with BEGIN syncs in_transaction" {
  @async.with_task_group(group => {
    let conn = match @sqlite.SqliteConn::open(":memory:") {
      Ok(c) => c
      Err(e) => fail("open failed: \{e}")
    }
    let state = {
      ..@app.AppState::new(group),
      screen: @app.Main,
      focus: @app.Editor,
      conn: Some(conn),
      sql_input: @widget.TextArea::new().with_value("BEGIN"),
    }
    let mut after = run_query_at_cursor(state)
    let mut attempts = 0
    while after.is_query_running() && attempts < 200000 {
      after = poll_running_query(after)
      attempts = attempts + 1
    }
    assert_eq(after.in_transaction, true)
    match after.conn {
      Some(h) => h.close()
      None => ()
    }
  })
}

///|
/// Manually typing COMMIT via run_query_at_cursor syncs in_transaction to false.
async test "run_query_at_cursor with COMMIT after BEGIN syncs in_transaction" {
  @async.with_task_group(group => {
    let conn = match @sqlite.SqliteConn::open(":memory:") {
      Ok(c) => c
      Err(e) => fail("open failed: \{e}")
    }
    let state = {
      ..@app.AppState::new(group),
      screen: @app.Main,
      focus: @app.Editor,
      conn: Some(conn),
      sql_input: @widget.TextArea::new().with_value("BEGIN"),
    }
    let mut after_begin = run_query_at_cursor(state)
    let mut attempts = 0
    while after_begin.is_query_running() && attempts < 200000 {
      after_begin = poll_running_query(after_begin)
      attempts = attempts + 1
    }
    assert_eq(after_begin.in_transaction, true)
    let mut after_commit = run_query_at_cursor({
      ..after_begin,
      sql_input: @widget.TextArea::new().with_value("COMMIT"),
    })
    attempts = 0
    while after_commit.is_query_running() && attempts < 200000 {
      after_commit = poll_running_query(after_commit)
      attempts = attempts + 1
    }
    assert_eq(after_commit.in_transaction, false)
    match after_commit.conn {
      Some(h) => h.close()
      None => ()
    }
  })
}
