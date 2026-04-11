///|
/// A handle to an open MySQL connection.
pub struct MysqlConn {
  id : Int
}

///|
pub fn MysqlConn::connect(
  host : String,
  port : Int,
  database : String,
  user : String,
  password : String,
) -> Result[MysqlConn, String] {
  let hb = @db.str_to_bytes(host)
  let db = @db.str_to_bytes(database)
  let ub = @db.str_to_bytes(user)
  let pb = @db.str_to_bytes(password)
  let id = hd_mysql_connect(
    hb,
    hb.length(),
    port,
    db,
    db.length(),
    ub,
    ub.length(),
    pb,
    pb.length(),
  )
  if id < 0 {
    return Err("failed to connect to MySQL: \{host}:\{port}/\{database}")
  }
  Ok({ id, })
}

///|
pub fn MysqlConn::close(self : MysqlConn) -> Unit {
  hd_mysql_close(self.id)
}

///|
pub fn MysqlConn::query(
  self : MysqlConn,
  sql : String,
) -> Result[@db.QueryResult, String] {
  let sql_bytes = @db.str_to_bytes(sql)
  let res_id = hd_mysql_exec(self.id, sql_bytes, sql_bytes.length())
  if res_id < 0 {
    return Err(mysql_errmsg(self.id))
  }
  let affected_rows = if @db.is_write_statement(sql) {
    Some(hd_mysql_affected_rows(self.id))
  } else {
    None
  }
  let buf : FixedArray[Byte] = FixedArray::make(4096, b'\x00')
  let nrows = hd_mysql_nrows(res_id)
  let ncols = hd_mysql_nfields(res_id)
  let columns : Array[String] = []
  for col = 0; col < ncols; col = col + 1 {
    let n = hd_mysql_fname(res_id, col, buf, buf.length())
    columns.push(if n > 0 { @db.fixed_bytes_to_str(buf, n) } else { "" })
  }
  let rows : Array[Array[String]] = []
  for row = 0; row < nrows; row = row + 1 {
    let r = []
    for col = 0; col < ncols; col = col + 1 {
      let n = hd_mysql_getvalue(res_id, row, col, buf, buf.length())
      r.push(if n >= 0 { @db.fixed_bytes_to_str(buf, n) } else { "NULL" })
    }
    rows.push(r)
  }
  hd_mysql_result_free(res_id)
  Ok({ columns, rows, affected_rows })
}

///|
pub fn MysqlConn::tables(self : MysqlConn) -> Result[Array[String], String] {
  match self.query("SHOW TABLES") {
    Ok(result) =>
      Ok(
        result.rows.map(fn(row) { if row.length() > 0 { row[0] } else { "" } }),
      )
    Err(e) => Err(e)
  }
}

///|
pub fn MysqlConn::columns(
  self : MysqlConn,
  table : String,
) -> Result[Array[@db.ColumnInfo], String] {
  match
    self.query(
      "SELECT COLUMN_NAME, COLUMN_TYPE FROM information_schema.COLUMNS WHERE TABLE_NAME='\{table}' ORDER BY ORDINAL_POSITION",
    ) {
    Ok(result) =>
      Ok(
        result.rows.map(fn(row) {
          {
            name: if row.length() > 0 {
              row[0]
            } else {
              ""
            },
            col_type: if row.length() > 1 {
              row[1]
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
fn mysql_errmsg(conn_id : Int) -> String {
  let buf : FixedArray[Byte] = FixedArray::make(512, b'\x00')
  let n = hd_mysql_errmsg(conn_id, buf, buf.length())
  if n > 0 {
    @db.fixed_bytes_to_str(buf, n)
  } else {
    "unknown MySQL error"
  }
}
