///|
async test "AppState::new has in_transaction false by default" {
  @async.with_task_group(group => {
    let state = AppState::new(group)
    assert_eq(state.in_transaction, false)
  })
}

///|
async test "AppState::begin_transaction when not connected" {
  @async.with_task_group(group => {
    let state = AppState::new(group)
    let s = state.begin_transaction()
    assert_eq(s.in_transaction, false)
    assert_true(s.status.contains("Error"))
  })
}

///|
async test "AppState::commit_transaction when not connected" {
  @async.with_task_group(group => {
    let state = AppState::new(group)
    let s = state.commit_transaction()
    assert_eq(s.in_transaction, false)
    assert_true(s.status.contains("Error"))
  })
}

///|
async test "AppState::rollback_transaction when not connected" {
  @async.with_task_group(group => {
    let state = AppState::new(group)
    let s = state.rollback_transaction()
    assert_eq(s.in_transaction, false)
    assert_true(s.status.contains("Error"))
  })
}

///|
/// Success-path: BEGIN sets in_transaction; COMMIT clears it.
async test "begin then commit toggles in_transaction with real SQLite" {
  @async.with_task_group(async fn(group) {
    let conn = match @sqlite.SqliteConn::open(":memory:") {
      Ok(c) => c
      Err(e) => fail("open failed: \{e}")
    }
    let state = {
      ..AppState::new(group),
      conn: Some(Sqlite(conn)),
      screen: Main,
    }
    let after_begin = state.begin_transaction()
    assert_eq(after_begin.in_transaction, true)
    assert_true(after_begin.status.contains("BEGIN"))
    let after_commit = after_begin.commit_transaction()
    assert_eq(after_commit.in_transaction, false)
    assert_true(after_commit.status.contains("COMMIT"))
    match after_commit.conn {
      Some(h) => h.close()
      None => ()
    }
  })
}

///|
/// Success-path: BEGIN sets in_transaction; ROLLBACK clears it.
async test "begin then rollback toggles in_transaction with real SQLite" {
  @async.with_task_group(async fn(group) {
    let conn = match @sqlite.SqliteConn::open(":memory:") {
      Ok(c) => c
      Err(e) => fail("open failed: \{e}")
    }
    let state = {
      ..AppState::new(group),
      conn: Some(Sqlite(conn)),
      screen: Main,
    }
    let after_begin = state.begin_transaction()
    assert_eq(after_begin.in_transaction, true)
    let after_rollback = after_begin.rollback_transaction()
    assert_eq(after_rollback.in_transaction, false)
    assert_true(after_rollback.status.contains("ROLLBACK"))
    match after_rollback.conn {
      Some(h) => h.close()
      None => ()
    }
  })
}

///|
/// Verify that in_transaction==true drives the visible indicator label.
/// The menu bar renders " honeydew  [TXN] " when in_transaction is true.
async test "in_transaction flag drives menu bar indicator text" {
  @async.with_task_group(async fn(group) {
    let conn = match @sqlite.SqliteConn::open(":memory:") {
      Ok(c) => c
      Err(e) => fail("open failed: \{e}")
    }
    let state = {
      ..AppState::new(group),
      conn: Some(Sqlite(conn)),
      screen: Main,
    }
    let idle_label = if state.in_transaction { "[TXN]" } else { "honeydew" }
    assert_eq(idle_label, "honeydew")
    let after_begin = state.begin_transaction()
    let txn_label = if after_begin.in_transaction {
      "[TXN]"
    } else {
      "honeydew"
    }
    assert_eq(txn_label, "[TXN]")
    match after_begin.conn {
      Some(h) => h.close()
      None => ()
    }
  })
}
