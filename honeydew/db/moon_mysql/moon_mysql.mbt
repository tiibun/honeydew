///|
/// A handle to an open MySQL connection using pure-MoonBit moon_mysql.
pub struct MoonMysqlConn {
  conn : @mysql_conn.Connection
  group : @async.TaskGroup[Unit]
  mut running_task : @async.Task[Result[@db.QueryResult, String]]?
  mut last_result : Result[@db.QueryResult, String]?
}

///|
/// Connect to a MySQL/MariaDB server via the pure-MoonBit wire protocol.
/// Returns (MoonMysqlConn, ()) — no background connection.run() needed.
pub fn MoonMysqlConn::connect(
  host : String,
  port : Int,
  database : String,
  user : String,
  password : String,
  group : @async.TaskGroup[Unit],
) -> MoonMysqlConn raise {
  let opts = @mysql_conn.ConnectOptions::new(
    host~,
    port~,
    user~,
    password~,
    database~,
  )
  let conn = @mm.connect(opts)
  { conn, group, running_task: None, last_result: None }
}

///|
pub fn MoonMysqlConn::close(self : MoonMysqlConn) -> Unit {
  self.conn.close()
}

///|
/// Kick off a non-blocking query in a background task.
pub fn MoonMysqlConn::async_start(self : MoonMysqlConn, sql : String) -> Bool {
  let task = self.group.spawn(fn() { self.do_query(sql) })
  self.running_task = Some(task)
  self.last_result = None
  true
}

///|
/// Poll the background task. Returns 0=idle, 1=running, 2=done, 3=error.
pub fn MoonMysqlConn::async_poll(self : MoonMysqlConn) -> Int {
  match self.running_task {
    None => 0
    Some(task) =>
      try task.try_wait() catch {
        e => {
          self.last_result = Some(Err(e.to_string()))
          self.running_task = None
          return 3
        }
      } noraise {
        None => 1
        Some(result) => {
          self.last_result = Some(result)
          self.running_task = None
          2
        }
      }
  }
}

///|
pub fn MoonMysqlConn::async_result(
  self : MoonMysqlConn,
  _is_write : Bool,
) -> Result[@db.QueryResult, String] {
  match self.last_result {
    Some(r) => r
    None => Err("no result available")
  }
}

///|
pub fn MoonMysqlConn::async_cancel(self : MoonMysqlConn) -> Unit {
  // moon_mysql does not expose cancellation; ignore
  let _ = self
}

///|
pub fn MoonMysqlConn::query(
  self : MoonMysqlConn,
  sql : String,
) -> Result[@db.QueryResult, String] {
  self.do_query(sql)
}

///|
pub fn MoonMysqlConn::tables(
  self : MoonMysqlConn,
) -> Result[Array[String], String] {
  match
    self.query(
      "SELECT table_name FROM information_schema.tables WHERE table_schema=database() AND table_type='BASE TABLE' ORDER BY table_name",
    ) {
    Ok(r) =>
      Ok(r.rows.map(fn(row) { if row.length() > 0 { row[0] } else { "" } }))
    Err(e) => Err(e)
  }
}

///|
pub fn MoonMysqlConn::views(
  self : MoonMysqlConn,
) -> Result[Array[String], String] {
  match
    self.query(
      "SELECT table_name FROM information_schema.tables WHERE table_schema=database() AND table_type='VIEW' ORDER BY table_name",
    ) {
    Ok(r) =>
      Ok(r.rows.map(fn(row) { if row.length() > 0 { row[0] } else { "" } }))
    Err(e) => Err(e)
  }
}

///|
pub fn MoonMysqlConn::columns(
  self : MoonMysqlConn,
  table : String,
) -> Result[Array[@db.ColumnInfo], String] {
  match
    self.query(
      "SELECT COLUMN_NAME, COLUMN_TYPE FROM information_schema.COLUMNS WHERE TABLE_NAME='\{table}' ORDER BY ORDINAL_POSITION",
    ) {
    Ok(r) =>
      Ok(
        r.rows.map(fn(row) {
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
pub impl @db.DbConn for MoonMysqlConn with async_start(self, sql) {
  self.async_start(sql)
}

///|
pub impl @db.DbConn for MoonMysqlConn with async_poll(self) {
  self.async_poll()
}

///|
pub impl @db.DbConn for MoonMysqlConn with async_result(self, is_write) {
  self.async_result(is_write)
}

///|
pub impl @db.DbConn for MoonMysqlConn with query(self, sql) {
  self.query(sql)
}

///|
pub impl @db.DbConn for MoonMysqlConn with tables(self) {
  self.tables()
}

///|
pub impl @db.DbConn for MoonMysqlConn with views(self) {
  self.views()
}

///|
pub impl @db.DbConn for MoonMysqlConn with columns(self, table) {
  self.columns(table)
}

///|
pub impl @db.DbConn for MoonMysqlConn with close(self) {
  self.close()
}

///|
pub impl @db.DbConn for MoonMysqlConn with cancel(self) {
  self.async_cancel()
}

///|
fn MoonMysqlConn::do_query(
  self : MoonMysqlConn,
  sql : String,
) -> Result[@db.QueryResult, String] {
  let is_write = @db.is_write_statement(sql)
  if is_write {
    try @mysql_proto.execute(self.conn, sql) catch {
      e => Err(e.to_string())
    } noraise {
      ok =>
        Ok({
          columns: [],
          rows: [],
          affected_rows: Some(ok.affected_rows.to_int()),
        })
    }
  } else {
    try @mysql_proto.query(self.conn, sql) catch {
      e => Err(e.to_string())
    } noraise {
      rs => Ok(result_set_to_query_result(rs))
    }
  }
}

///|
fn result_set_to_query_result(rs : @mysql_proto.ResultSet) -> @db.QueryResult {
  let columns = rs.columns.map(fn(c) { c.name })
  let rows = rs.rows.map(fn(row) {
    let @mysql_proto.Row(vals) = row
    vals.map(fn(v) { value_to_string(v) })
  })
  { columns, rows, affected_rows: None }
}

///|
fn value_to_string(v : @mysql_types.Value) -> String {
  match v {
    Null => @db.null_value
    Int(n) => n.to_string()
    UInt(n) => n.to_string()
    Float(f) => f.to_string()
    Text(s) => s
    Bytes(b) => b.to_string()
    Date(year~, month~, day~) => "\{year}-\{zero_pad(month)}-\{zero_pad(day)}"
    Time(negative~, days~, hours~, minutes~, seconds~, microseconds~) => {
      let sign = if negative { "-" } else { "" }
      let total_hours = days * 24 + hours
      "\{sign}\{zero_pad(total_hours)}:\{zero_pad(minutes)}:\{zero_pad(seconds)}\{micros_suffix(microseconds)}"
    }
    DateTime(year~, month~, day~, hours~, minutes~, seconds~, microseconds~) =>
      "\{year}-\{zero_pad(month)}-\{zero_pad(day)} \{zero_pad(hours)}:\{zero_pad(minutes)}:\{zero_pad(seconds)}\{micros_suffix(microseconds)}"
  }
}

///|
fn zero_pad(n : Int) -> String {
  if n < 10 {
    "0\{n}"
  } else {
    n.to_string()
  }
}

///|
fn micros_suffix(us : Int) -> String {
  if us == 0 {
    ""
  } else {
    ".\{us}"
  }
}
