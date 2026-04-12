///|
/// Integration test for the MySQL async worker. Skips when MySQL is unavailable.

///|
test "mysql async_start and poll completes for simple query" {
  let conn = match
    @db_mysql.MysqlConn::connect(
      "127.0.0.1", 3306, "testdb", "testuser", "testpass",
    ) {
    Ok(c) => c
    Err(_) => return
  }
  assert_true(conn.async_start("SELECT 1 AS one"))
  let status = wait_for_async_status(conn)
  if status == 3 {
    let result = conn.async_result(false)
    conn.close()
    match result {
      Err(e) => fail("async_result failed: \{e}")
      _ => fail("expected async MySQL query to succeed")
    }
  }
  assert_eq(status, 2)
  let result = match conn.async_result(false) {
    Ok(r) => r
    Err(e) => {
      conn.close()
      fail("async_result failed: \{e}")
    }
  }
  assert_eq(result.columns, ["one"])
  assert_eq(result.rows, [["1"]])
  conn.close()
}

///|
fn wait_for_async_status(conn : @db_mysql.MysqlConn) -> Int {
  let start = @bench.monotonic_clock_start()
  let timeout_us = 1_000_000.0
  let mut status = conn.async_poll()
  while status == 1 && @bench.monotonic_clock_end(start) < timeout_us {
    usleep(1_000)
    status = conn.async_poll()
  }
  status
}

///|
extern "c" fn usleep(usec : Int) -> Unit = "usleep"
