///|
/// Integration tests for the SQLite async worker (background thread execution).

///|
test "sqlite async_start and poll completes for simple query" {
  let conn = match @db_sqlite.SqliteConn::open(":memory:") {
    Ok(c) => c
    Err(e) => fail("open failed: \{e}")
  }
  let _ = conn.query("CREATE TABLE t(x INT)")
  let _ = conn.query("INSERT INTO t VALUES(1)")
  let _ = conn.query("INSERT INTO t VALUES(2)")
  let started = conn.async_start("SELECT x FROM t ORDER BY x")
  inspect(started, content="true")
  // Poll until done (should be nearly instant for in-memory)
  let mut attempts = 0
  while @db_sqlite.async_poll() == 1 && attempts < 100000 {
    attempts = attempts + 1
  }
  let status = @db_sqlite.async_poll()
  inspect(status, content="2")
  let result = match conn.async_result(false) {
    Ok(r) => r
    Err(e) => fail("async_result failed: \{e}")
  }
  assert_eq(result.columns, ["x"])
  assert_eq(result.rows.length(), 2)
  assert_eq(result.rows[0][0], "1")
  assert_eq(result.rows[1][0], "2")
  conn.close()
}

///|
test "sqlite async interrupt cancels a long query" {
  let conn = match @db_sqlite.SqliteConn::open(":memory:") {
    Ok(c) => c
    Err(e) => fail("open failed: \{e}")
  }
  // Recursive CTE of ~5M rows (~0.4s on typical hardware) keeps the worker
  // busy long enough for interrupt() to fire during sqlite3_step.
  let sql =
    #|WITH RECURSIVE cnt(x) AS (
    #|  VALUES(0) UNION ALL SELECT x+1 FROM cnt WHERE x < 5000000
    #|) SELECT sum(x) FROM cnt
  assert_true(conn.async_start(sql))
  // Repeatedly interrupt until the worker finishes —
  // a single interrupt() may fire before sqlite3_step begins.
  let mut attempts = 0
  while @db_sqlite.async_poll() == 1 && attempts < 2000000 {
    conn.interrupt()
    attempts = attempts + 1
  }
  let status = @db_sqlite.async_poll()
  inspect(status, content="3") // ASYNC_ERROR (interrupted)
  let result = conn.async_result(false)
  assert_true(result is Err(_))
  match result {
    Err(msg) => assert_true(msg.contains("interrupt"))
    _ => fail("expected error")
  }
  conn.close()
}

///|
test "sqlite async write query reports affected rows" {
  let conn = match @db_sqlite.SqliteConn::open(":memory:") {
    Ok(c) => c
    Err(e) => fail("open failed: \{e}")
  }
  let _ = conn.query("CREATE TABLE t(x INT)")
  let _ = conn.query("INSERT INTO t VALUES(1)")
  assert_true(conn.async_start("UPDATE t SET x = 2"))
  let mut attempts = 0
  while @db_sqlite.async_poll() == 1 && attempts < 100000 {
    attempts = attempts + 1
  }
  assert_true(@db_sqlite.async_poll() == 2)
  let result = match conn.async_result(true) {
    Ok(r) => r
    Err(e) => fail("async_result failed: \{e}")
  }
  assert_eq(result.affected_rows, Some(1))
  conn.close()
}
