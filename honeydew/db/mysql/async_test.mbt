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
  let mut attempts = 0
  while conn.async_poll() == 1 && attempts < 100000 {
    attempts = attempts + 1
  }
  let status = conn.async_poll()
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
