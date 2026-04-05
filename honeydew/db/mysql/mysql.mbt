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
  let hb = str_to_bytes(host)
  let db = str_to_bytes(database)
  let ub = str_to_bytes(user)
  let pb = str_to_bytes(password)
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
  let sql_bytes = str_to_bytes(sql)
  let res_id = hd_mysql_exec(self.id, sql_bytes, sql_bytes.length())
  if res_id < 0 {
    return Err(mysql_errmsg(self.id))
  }
  let buf : FixedArray[Byte] = FixedArray::make(4096, b'\x00')
  let nrows = hd_mysql_nrows(res_id)
  let ncols = hd_mysql_nfields(res_id)
  let columns : Array[String] = []
  for col = 0; col < ncols; col = col + 1 {
    let n = hd_mysql_fname(res_id, col, buf, buf.length())
    columns.push(if n > 0 { fixed_bytes_to_str(buf, n) } else { "" })
  }
  let rows : Array[Array[String]] = []
  for row = 0; row < nrows; row = row + 1 {
    let r = []
    for col = 0; col < ncols; col = col + 1 {
      let n = hd_mysql_getvalue(res_id, row, col, buf, buf.length())
      r.push(if n >= 0 { fixed_bytes_to_str(buf, n) } else { "NULL" })
    }
    rows.push(r)
  }
  hd_mysql_result_free(res_id)
  Ok({ columns, rows })
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
    fixed_bytes_to_str(buf, n)
  } else {
    "unknown MySQL error"
  }
}

///|
fn str_to_bytes(str : String) -> Bytes {
  let res : Array[Byte] = []
  let len = str.length()
  let mut i = 0
  while i < len {
    let mut c = str.code_unit_at(i).to_int()
    if 0xD800 <= c && c <= 0xDBFF {
      c -= 0xD800
      i = i + 1
      let l = str.code_unit_at(i).to_int() - 0xDC00
      c = (c << 10) + l + 0x10000
    }
    if c < 0x80 {
      res.push(c.to_byte())
    } else if c < 0x800 {
      res.push((0xC0 | (c >> 6)).to_byte())
      res.push((0x80 | (c & 0x3F)).to_byte())
    } else if c < 0x10000 {
      res.push((0xE0 | (c >> 12)).to_byte())
      res.push((0x80 | ((c >> 6) & 0x3F)).to_byte())
      res.push((0x80 | (c & 0x3F)).to_byte())
    } else {
      res.push((0xF0 | (c >> 18)).to_byte())
      res.push((0x80 | ((c >> 12) & 0x3F)).to_byte())
      res.push((0x80 | ((c >> 6) & 0x3F)).to_byte())
      res.push((0x80 | (c & 0x3F)).to_byte())
    }
    i = i + 1
  }
  Bytes::from_array(res)
}

///|
fn fixed_bytes_to_str(buf : FixedArray[Byte], len : Int) -> String {
  let sb = StringBuilder::new()
  let mut i = 0
  while i < len {
    let b0 = buf[i].to_int() & 0xFF
    if b0 < 0x80 {
      sb.write_char(Int::unsafe_to_char(b0))
      i = i + 1
    } else if b0 < 0xE0 && i + 1 < len {
      let b1 = buf[i + 1].to_int() & 0xFF
      let cp = ((b0 & 0x1F) << 6) | (b1 & 0x3F)
      sb.write_char(Int::unsafe_to_char(cp))
      i = i + 2
    } else if b0 < 0xF0 && i + 2 < len {
      let b1 = buf[i + 1].to_int() & 0xFF
      let b2 = buf[i + 2].to_int() & 0xFF
      let cp = ((b0 & 0x0F) << 12) | ((b1 & 0x3F) << 6) | (b2 & 0x3F)
      sb.write_char(Int::unsafe_to_char(cp))
      i = i + 3
    } else if i + 3 < len {
      let b1 = buf[i + 1].to_int() & 0xFF
      let b2 = buf[i + 2].to_int() & 0xFF
      let b3 = buf[i + 3].to_int() & 0xFF
      let cp = ((b0 & 0x07) << 18) |
        ((b1 & 0x3F) << 12) |
        ((b2 & 0x3F) << 6) |
        (b3 & 0x3F)
      sb.write_char(Int::unsafe_to_char(cp))
      i = i + 4
    } else {
      i = i + 1
    }
  }
  sb.to_string()
}
