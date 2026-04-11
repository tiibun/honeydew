///|
async test "AppState::new has in_transaction false by default" {
  @async.with_task_group(group => {
    let state = AppState::new(group)
    assert_eq(state.in_transaction, false)
  })
}

///|
// Guard: commit/rollback short-circuit before checking connection when no txn.
async test "AppState::commit_transaction guard fires when not in transaction" {
  @async.with_task_group(group => {
    let state = AppState::new(group)
    let s = state.commit_transaction()
    assert_eq(s.in_transaction, false)
    assert_true(s.status.contains("Not in a transaction"))
  })
}

///|
async test "AppState::rollback_transaction guard fires when not in transaction" {
  @async.with_task_group(group => {
    let state = AppState::new(group)
    let s = state.rollback_transaction()
    assert_eq(s.in_transaction, false)
    assert_true(s.status.contains("Not in a transaction"))
  })
}

///|
// Guard: begin short-circuits when already in a transaction.
async test "AppState::begin_transaction guard fires when already in transaction" {
  @async.with_task_group(group => {
    let state = { ..AppState::new(group), in_transaction: true }
    let s = state.begin_transaction()
    assert_eq(s.in_transaction, true)
    assert_true(s.status.contains("Already in a transaction"))
  })
}

///|
// "Not connected" paths require bypassing the guard (in_transaction must match).
async test "AppState::begin_transaction when not connected" {
  @async.with_task_group(group => {
    let state = AppState::new(group) // in_transaction: false → guard not hit
    let s = state.begin_transaction()
    assert_eq(s.in_transaction, false)
    assert_true(s.status.contains("Error"))
  })
}

///|
async test "AppState::commit_transaction when in transaction but not connected" {
  @async.with_task_group(group => {
    let state = { ..AppState::new(group), in_transaction: true }
    let s = state.commit_transaction()
    assert_eq(s.in_transaction, true) // unchanged on error
    assert_true(s.status.contains("Error"))
  })
}

///|
async test "AppState::rollback_transaction when in transaction but not connected" {
  @async.with_task_group(group => {
    let state = { ..AppState::new(group), in_transaction: true }
    let s = state.rollback_transaction()
    assert_eq(s.in_transaction, true) // unchanged on error
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
/// Verify that `menu_bar_left_label` reflects the transaction state.
async test "menu_bar_left_label returns correct label for transaction state" {
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
    assert_true(state.menu_bar_left_label().contains("honeydew"))
    assert_true(!state.menu_bar_left_label().contains("[TXN]"))
    let after_begin = state.begin_transaction()
    assert_true(after_begin.menu_bar_left_label().contains("[TXN]"))
    match after_begin.conn {
      Some(h) => h.close()
      None => ()
    }
  })
}

///|
/// Verify that `menu_bar_left_label` includes the database name when connected.
async test "menu_bar_left_label shows db kind and name when connected" {
  @async.with_task_group(group => {
    let conn = match @sqlite.SqliteConn::open(":memory:") {
      Ok(c) => c
      Err(e) => fail("open failed: \{e}")
    }
    let state = {
      ..AppState::new(group),
      conn: Some(Sqlite(conn)),
      conn_form: {
        ..ConnForm::new(),
        database: @widget.Input::new().with_value("mydb.db"),
      },
      screen: Main,
    }
    let label = state.menu_bar_left_label()
    assert_true(label.contains("SQLite"))
    assert_true(label.contains("mydb.db"))
    match state.conn {
      Some(h) => h.close()
      None => ()
    }
  })
}

///|
/// Verify that `menu_bar_left_label` shows no db info when not connected.
async test "menu_bar_left_label shows no db info when not connected" {
  @async.with_task_group(group => {
    let state = AppState::new(group)
    let label = state.menu_bar_left_label()
    assert_true(label.contains("honeydew"))
    assert_false(label.contains("SQLite"))
    assert_false(label.contains("["))
  })
}

///|
/// `stmt_opens_txn` classifies statements correctly.
test "stmt_opens_txn recognises BEGIN and START TRANSACTION" {
  assert_eq(stmt_opens_txn("BEGIN"), true)
  assert_eq(stmt_opens_txn("begin"), true)
  assert_eq(stmt_opens_txn("BEGIN DEFERRED"), true)
  assert_eq(stmt_opens_txn("START TRANSACTION"), true)
  assert_eq(stmt_opens_txn("start transaction"), true)
  assert_eq(stmt_opens_txn("  BEGIN  "), true)
  assert_eq(stmt_opens_txn("COMMIT"), false)
  assert_eq(stmt_opens_txn("ROLLBACK"), false)
  assert_eq(stmt_opens_txn("SELECT 1"), false)
  assert_eq(stmt_opens_txn("BEGINNERS SELECT"), false)
}

///|
/// `stmt_closes_txn` classifies statements correctly.
test "stmt_closes_txn recognises COMMIT and ROLLBACK" {
  assert_eq(stmt_closes_txn("COMMIT"), true)
  assert_eq(stmt_closes_txn("commit"), true)
  assert_eq(stmt_closes_txn("COMMIT WORK"), true)
  assert_eq(stmt_closes_txn("ROLLBACK"), true)
  assert_eq(stmt_closes_txn("rollback"), true)
  assert_eq(stmt_closes_txn("ROLLBACK TO SAVEPOINT sp"), false)
  assert_eq(stmt_closes_txn("ROLLBACK TO sp"), false)
  assert_eq(stmt_closes_txn("rollback to savepoint sp"), false)
  assert_eq(stmt_closes_txn("BEGIN"), false)
  assert_eq(stmt_closes_txn("SELECT 1"), false)
  assert_eq(stmt_closes_txn("ROLLBACKUP"), false)
}

///|
/// `sync_txn_flag_for_stmt` updates the flag for transaction statements.
async test "sync_txn_flag_for_stmt updates in_transaction correctly" {
  @async.with_task_group(group => {
    let idle = AppState::new(group)
    assert_eq(idle.in_transaction, false)
    let after_begin = idle.sync_txn_flag_for_stmt("BEGIN")
    assert_eq(after_begin.in_transaction, true)
    let after_commit = after_begin.sync_txn_flag_for_stmt("COMMIT")
    assert_eq(after_commit.in_transaction, false)
    let after_begin2 = after_commit.sync_txn_flag_for_stmt("START TRANSACTION")
    assert_eq(after_begin2.in_transaction, true)
    let after_rollback = after_begin2.sync_txn_flag_for_stmt("ROLLBACK")
    assert_eq(after_rollback.in_transaction, false)
    // Non-transaction statement must not change the flag.
    let after_select = after_rollback.sync_txn_flag_for_stmt("SELECT 1")
    assert_eq(after_select.in_transaction, false)
  })
}
