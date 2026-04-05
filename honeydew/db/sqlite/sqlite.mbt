///|
/// A handle to an open SQLite database connection.
pub struct SqliteConn {
  id : Int
}

///|
/// Open a SQLite database at `path` (use `:memory:` for an in-memory DB).
pub fn SqliteConn::open(path : String) -> Result[SqliteConn, String] {
  let bytes = @db.str_to_bytes(path)
  let id = hd_sqlite_open(bytes, bytes.length())
  if id < 0 {
    return Err("failed to open SQLite database: \{path}")
  }
  Ok({ id, })
}

///|
/// Close the connection and release resources.
pub fn SqliteConn::close(self : SqliteConn) -> Unit {
  hd_sqlite_close(self.id)
}

///|
/// Execute a SQL statement and return the result rows.
/// Non-SELECT statements (INSERT/UPDATE/DELETE) return an empty QueryResult.
pub fn SqliteConn::query(
  self : SqliteConn,
  sql : String,
) -> Result[@db.QueryResult, String] {
  let sql_bytes = @db.str_to_bytes(sql)
  let stmt_id = hd_sqlite_prepare(self.id, sql_bytes, sql_bytes.length())
  if stmt_id < 0 {
    return Err(errmsg(self.id))
  }
  let columns : Array[String] = []
  let rows : Array[Array[String]] = []
  let buf : FixedArray[Byte] = FixedArray::make(4096, b'\x00')
  let first = hd_sqlite_step(stmt_id)
  if first == 100 {
    // SQLITE_ROW — read column names from first row
    let ncols = hd_sqlite_column_count(stmt_id)
    for col = 0; col < ncols; col = col + 1 {
      let n = hd_sqlite_column_name(stmt_id, col, buf, buf.length())
      columns.push(if n > 0 { @db.fixed_bytes_to_str(buf, n) } else { "" })
    }
    // Collect first row
    rows.push(read_row(stmt_id, ncols, buf))
    // Collect remaining rows
    while hd_sqlite_step(stmt_id) == 100 {
      rows.push(read_row(stmt_id, ncols, buf))
    }
  } else if first < 0 {
    hd_sqlite_finalize(stmt_id)
    return Err(errmsg(self.id))
  }
  // first == 101 (SQLITE_DONE) means no rows (e.g. INSERT/UPDATE)
  hd_sqlite_finalize(stmt_id)
  Ok({ columns, rows })
}

///|
/// List all user-defined tables in the database.
pub fn SqliteConn::tables(self : SqliteConn) -> Result[Array[String], String] {
  match
    self.query(
      "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name",
    ) {
    Ok(result) =>
      Ok(
        result.rows.map(fn(row) { if row.length() > 0 { row[0] } else { "" } }),
      )
    Err(e) => Err(e)
  }
}

///|
/// List columns of a table with their declared types.
pub fn SqliteConn::columns(
  self : SqliteConn,
  table : String,
) -> Result[Array[@db.ColumnInfo], String] {
  // PRAGMA table_info: cid | name | type | notnull | dflt_value | pk
  match self.query("PRAGMA table_info(\{table})") {
    Ok(result) =>
      Ok(
        result.rows.map(fn(row) {
          {
            name: if row.length() > 1 {
              row[1]
            } else {
              ""
            },
            col_type: if row.length() > 2 {
              row[2]
            } else {
              ""
            },
          }
        }),
      )
    Err(e) => Err(e)
  }
}

///|
fn read_row(
  stmt_id : Int,
  ncols : Int,
  buf : FixedArray[Byte],
) -> Array[String] {
  let row = []
  for col = 0; col < ncols; col = col + 1 {
    let n = hd_sqlite_column_text(stmt_id, col, buf, buf.length())
    row.push(if n >= 0 { @db.fixed_bytes_to_str(buf, n) } else { "NULL" })
  }
  row
}

///|
fn errmsg(conn_id : Int) -> String {
  let buf : FixedArray[Byte] = FixedArray::make(512, b'\x00')
  let n = hd_sqlite_errmsg(conn_id, buf, buf.length())
  if n > 0 {
    @db.fixed_bytes_to_str(buf, n)
  } else {
    "unknown SQLite error"
  }
}
