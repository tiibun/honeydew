///|
/// A handle to an open PostgreSQL client connection.
pub struct PgConn {
  client : @pg.Client
  cancel_token : @pg.CancelToken
  group : @async.TaskGroup[Unit]
  mut running_task : @async.Task[Result[@db.QueryResult, String]]?
  mut last_result : Result[@db.QueryResult, String]?
}

///|
/// Connect to a PostgreSQL database asynchronously.
/// Returns (PgConn, Connection); the caller must spawn connection.run() as a
/// background task before using the returned PgConn.
pub async fn PgConn::connect(
  host : String,
  port : Int,
  database : String,
  user : String,
  password : String,
  group : @async.TaskGroup[Unit],
) -> (PgConn, @pg.Connection) {
  let pwd_opt : String? = if password == "" { None } else { Some(password) }
  let cfg = @pg.Config::new(host, user~, database~, password?=pwd_opt, port~)
  let (client, connection) = @pg.connect(cfg)
  (
    {
      client,
      cancel_token: client.cancel_token(),
      group,
      running_task: None,
      last_result: None,
    },
    connection,
  )
}

///|
pub fn PgConn::close(self : PgConn) -> Unit {
  self.client.close()
}

///|
/// Start a non-blocking query in a background task. Always returns true.
pub fn PgConn::async_start(self : PgConn, sql : String) -> Bool {
  let task = self.group.spawn(async fn() {
    self.query(sql) catch {
      err => Err(pg_error_message(err))
    }
  })
  self.running_task = Some(task)
  self.last_result = None
  true
}

///|
/// Poll the background task. Returns 0=idle, 1=running, 2=done, 3=error.
pub fn PgConn::async_poll(self : PgConn) -> Int {
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
/// Collect the result after async_poll returns non-1.
pub fn PgConn::async_result(
  self : PgConn,
  _is_write : Bool,
) -> Result[@db.QueryResult, String] {
  match self.last_result {
    Some(r) => r
    None => Err("no result available")
  }
}

///|
/// Request cancellation of the in-flight query.
pub fn PgConn::interrupt(self : PgConn) -> Unit {
  let token = self.cancel_token
  self.group.spawn_bg(async fn() { token.cancel() }, allow_failure=true)
}

///|
fn pg_error_message(err : Error) -> String {
  match err {
    @pg.ClientError::Database(db_err) => db_err.message
    @pg.ClientError::Authentication(msg) => msg
    @pg.ClientError::Closed(msg) => msg
    @pg.ClientError::Protocol(msg) => msg
    @pg.ClientError::Ssl(msg) => msg
    @pg.ClientError::Encode(msg) => msg
    @pg.ClientError::Decode(msg) => msg
    @pg.ClientError::WrongType(msg) => msg
    @pg.ClientError::ColumnNotFound(msg) => msg
    @pg.ClientError::RowCount(msg) => msg
    @pg.ClientError::UnexpectedMessage(msg) => msg
    _ => err.to_string()
  }
}

///|
/// Execute a SQL statement and return all result rows as strings.
pub async fn PgConn::query(
  self : PgConn,
  sql : String,
) -> Result[@db.QueryResult, String] {
  let stream = self.client.simple_query(sql) catch {
    err => return Err(pg_error_message(err))
  }
  let mut columns : Array[String] = []
  let rows : Array[Array[String]] = []
  let mut affected_rows : Int? = None
  try {
    loop stream.next() {
      None => break
      Some(msg) =>
        match msg {
          @pg.SimpleQueryMessage::RowDescription(cols) => {
            columns = cols
            continue stream.next()
          }
          @pg.SimpleQueryMessage::Row(row) => {
            rows.push(
              row.values.map(fn(v) {
                match v {
                  None => @db.null_value
                  Some(s) => s
                }
              }),
            )
            continue stream.next()
          }
          @pg.SimpleQueryMessage::CommandComplete(tag) => {
            affected_rows = parse_affected_rows(tag)
            continue stream.next()
          }
        }
    }
  } catch {
    err => return Err(pg_error_message(err))
  }
  Ok({ columns, rows, affected_rows })
}

///|
/// List all user-defined tables in the public schema.
pub async fn PgConn::tables(self : PgConn) -> Result[Array[String], String] {
  match
    self.query(
      "SELECT tablename FROM pg_tables WHERE schemaname='public' ORDER BY tablename",
    ) {
    Ok(result) =>
      Ok(
        result.rows.map(fn(row) { if row.length() > 0 { row[0] } else { "" } }),
      )
    Err(e) => Err(e)
  }
}

///|
pub async fn PgConn::views(self : PgConn) -> Result[Array[String], String] {
  match
    self.query(
      "SELECT viewname FROM pg_views WHERE schemaname='public' ORDER BY viewname",
    ) {
    Ok(result) =>
      Ok(
        result.rows.map(fn(row) { if row.length() > 0 { row[0] } else { "" } }),
      )
    Err(e) => Err(e)
  }
}

///|
fn parse_affected_rows(tag : String) -> Int? {
  if !@db.is_write_statement(tag) {
    return None
  }
  let mut end = tag.length() - 1
  while end >= 0 && is_ascii_digit(tag, end) {
    end -= 1
  }
  if end == tag.length() - 1 {
    None
  } else {
    Some(parse_ascii_int(tag[end + 1:].to_string()))
  }
}

///|
fn is_ascii_digit(s : String, idx : Int) -> Bool {
  let c = s[idx].to_int()
  c >= '0'.to_int() && c <= '9'.to_int()
}

///|
fn parse_ascii_int(s : String) -> Int {
  let mut value = 0
  for c in s.iter() {
    value = value * 10 + (c.to_int() - '0'.to_int())
  }
  value
}

///|
/// List columns of a table with their declared types.
pub async fn PgConn::columns(
  self : PgConn,
  table : String,
) -> Result[Array[@db.ColumnInfo], String] {
  match
    self.query(
      "SELECT column_name, data_type FROM information_schema.columns WHERE table_name='\{table}' ORDER BY ordinal_position",
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
pub impl @db.DbConn for PgConn with async_start(self, sql) {
  self.async_start(sql)
}

///|
pub impl @db.DbConn for PgConn with async_poll(self) {
  self.async_poll()
}

///|
pub impl @db.DbConn for PgConn with async_result(self, is_write) {
  self.async_result(is_write)
}

///|
pub impl @db.DbConn for PgConn with query(self, sql) {
  self.query(sql)
}

///|
pub impl @db.DbConn for PgConn with tables(self) {
  self.tables()
}

///|
pub impl @db.DbConn for PgConn with views(self) {
  self.views()
}

///|
pub impl @db.DbConn for PgConn with columns(self, table) {
  self.columns(table)
}

///|
pub impl @db.DbConn for PgConn with close(self) {
  self.close()
}

///|
pub impl @db.DbConn for PgConn with cancel(self) {
  self.interrupt()
}
