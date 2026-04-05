///|
/// Integration tests for SQLite. These run against an in-memory database
/// and require libsqlite3 to be installed.

///|
test "sqlite open and close in-memory" {
  let conn = match @db_sqlite.SqliteConn::open(":memory:") {
    Ok(c) => c
    Err(e) => fail("open failed: \{e}")
  }
  conn.close()
}

///|
test "sqlite create table and query" {
  let conn = match @db_sqlite.SqliteConn::open(":memory:") {
    Ok(c) => c
    Err(e) => fail("open failed: \{e}")
  }
  let _ = conn.query(
    "CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT, email TEXT)",
  )
  let _ = conn.query(
    "INSERT INTO users VALUES (1, 'Alice', 'alice@example.com')",
  )
  let _ = conn.query("INSERT INTO users VALUES (2, 'Bob', 'bob@example.com')")
  let result = match conn.query("SELECT * FROM users ORDER BY id") {
    Ok(r) => r
    Err(e) => fail("query failed: \{e}")
  }
  assert_eq(result.columns.length(), 3)
  assert_eq(result.rows.length(), 2)
  assert_eq(result.rows[0][1], "Alice")
  assert_eq(result.rows[1][1], "Bob")
  conn.close()
}

///|
test "sqlite tables" {
  let conn = match @db_sqlite.SqliteConn::open(":memory:") {
    Ok(c) => c
    Err(e) => fail("open failed: \{e}")
  }
  let _ = conn.query("CREATE TABLE foo (x INT)")
  let _ = conn.query("CREATE TABLE bar (y TEXT)")
  let tables = match conn.tables() {
    Ok(t) => t
    Err(e) => fail("tables failed: \{e}")
  }
  assert_eq(tables.length(), 2)
  conn.close()
}

///|
test "sqlite columns" {
  let conn = match @db_sqlite.SqliteConn::open(":memory:") {
    Ok(c) => c
    Err(e) => fail("open failed: \{e}")
  }
  let _ = conn.query(
    "CREATE TABLE products (id INTEGER, name TEXT, price REAL)",
  )
  let cols = match conn.columns("products") {
    Ok(c) => c
    Err(e) => fail("columns failed: \{e}")
  }
  assert_eq(cols.length(), 3)
  assert_eq(cols[0].name, "id")
  assert_eq(cols[0].col_type, "INTEGER")
  assert_eq(cols[1].name, "name")
  conn.close()
}
