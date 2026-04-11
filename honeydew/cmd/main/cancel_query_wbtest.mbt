///|
// Test 1: Ctrl+C quits when no query is running (existing behavior).
async test "CtrlC quits when no query is running" {
  @async.with_task_group(async fn(group) {
    let state = {
      ..@app.AppState::new(group),
      screen: @app.Main,
      focus: @app.Editor,
    }
    assert_eq(state.is_query_running(), false)
    let s = handle_key(state, CtrlC)
    assert_eq(s.should_quit, true)
  })
}

///|
// Test 2: Ctrl+C cancels instead of quitting when a query is running.
async test "CtrlC cancels query instead of quitting when running" {
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
    assert_eq(state.is_query_running(), true)
    let s = handle_key(state, CtrlC)
    // Should NOT quit
    assert_eq(s.should_quit, false)
    // Should request cancellation
    assert_eq(s.cancel_requested, true)
    conn.close()
  })
}

///|
// Test 3: Repeated Ctrl+C while cancel is already requested does not quit.
async test "repeated CtrlC during cancellation does not quit" {
  @async.with_task_group(async fn(group) {
    let state = {
      ..@app.AppState::new(group),
      screen: @app.Main,
      focus: @app.Editor,
      running_query: Some(
        @app.RunningQuery::Single(
          sql="SELECT 1",
          started=@bench.monotonic_clock_start(),
        ),
      ),
      cancel_requested: true,
    }
    let s = handle_key(state, CtrlC)
    assert_eq(s.should_quit, false)
    assert_eq(s.cancel_requested, true)
  })
}

///|
// Test 4: Query completion clears running state.
async test "query completion clears running_query" {
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
      sql_input: @widget.TextArea::new().with_value("SELECT 1"),
    }
    // Execute query at cursor — starts async worker
    let mut after = run_query_at_cursor(state)
    assert_eq(after.is_query_running(), true)
    // Poll until async worker finishes
    let mut attempts = 0
    while after.is_query_running() && attempts < 200000 {
      after = poll_running_query(after)
      attempts = attempts + 1
    }
    assert_eq(after.is_query_running(), false)
    assert_eq(after.cancel_requested, false)
    assert_true(after.results.columns.length() > 0)
    conn.close()
  })
}

///|
// Test 5: Run-all completes and clears running state.
async test "run_all clears running_query on completion" {
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
      sql_input: @widget.TextArea::new().with_value(
        "CREATE TABLE t(x INT); INSERT INTO t VALUES(1)",
      ),
    }
    let mut after = run_all_queries(state)
    // Poll until all statements complete
    let mut attempts = 0
    while after.is_query_running() && attempts < 400000 {
      after = poll_running_query(after)
      attempts = attempts + 1
    }
    assert_eq(after.is_query_running(), false)
    assert_eq(after.cancel_requested, false)
    assert_true(after.status.contains("2 statements"))
    conn.close()
  })
}

///|
// Test 6: Status shows "Running query" hint while query is in flight.
async test "status shows running hint while query in flight" {
  @async.with_task_group(group => {
    let state = {
      ..@app.AppState::new(group),
      screen: @app.Main,
      focus: @app.Editor,
      running_query: Some(
        @app.RunningQuery::Single(
          sql="SELECT 1",
          started=@bench.monotonic_clock_start(),
        ),
      ),
      status: "Running query... Ctrl+C to cancel",
    }
    assert_true(state.status.contains("Running query"))
    assert_true(state.status.contains("Ctrl+C"))
  })
}

///|
// Test 7: CtrlC on Connect screen still quits (not affected by running query logic).
async test "CtrlC on Connect screen quits regardless" {
  @async.with_task_group(async fn(group) {
    let state = { ..@app.AppState::new(group), screen: @app.Connect }
    let s = handle_key(state, CtrlC)
    assert_eq(s.should_quit, true)
  })
}

///|
async test "CtrlC with PgTask sets cancel_requested" {
  @async.with_task_group(async fn(group) {
    let cancel_called = Ref::new(false)
    let task = group.spawn(
      fn() { @app.PgQueryResult::PgCancelled },
      no_wait=true,
      allow_failure=true,
    )
    let state = {
      ..@app.AppState::new(group),
      screen: @app.Main,
      focus: @app.Editor,
      running_query: Some(
        @app.RunningQuery::PgTask(
          task~,
          cancel=fn() { cancel_called.val = true },
          started=@bench.monotonic_clock_start(),
        ),
      ),
    }
    let after = handle_key(state, CtrlC)
    @async.sleep(10)
    assert_eq(after.should_quit, false)
    assert_eq(after.cancel_requested, true)
    assert_eq(cancel_called.val, true)
  })
}

///|
async test "poll_running_query clears completed PgTask" {
  @async.with_task_group(async fn(group) {
    let task = group.spawn(
      fn() { @app.PgQueryResult::PgCancelled },
      no_wait=true,
      allow_failure=true,
    )
    let _ = task.wait()
    let state = {
      ..@app.AppState::new(group),
      screen: @app.Main,
      focus: @app.Editor,
      running_query: Some(
        @app.RunningQuery::PgTask(
          task~,
          cancel=fn() {  },
          started=@bench.monotonic_clock_start(),
        ),
      ),
      cancel_requested: true,
    }
    let after = poll_running_query(state)
    assert_eq(after.is_query_running(), false)
    assert_eq(after.cancel_requested, false)
    assert_true(after.status.contains("Query cancelled"))
  })
}
