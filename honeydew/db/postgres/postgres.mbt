///|
/// A handle to an open PostgreSQL client connection.
pub struct PgConn {
  client : @pg.Client
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
) -> (PgConn, @pg.Connection) {
  let pwd_opt : String? = if password == "" { None } else { Some(password) }
  let cfg = @pg.Config::new(host, user~, database~, password?=pwd_opt, port~)
  let (client, connection) = @pg.connect(cfg)
  ({ client, }, connection)
}

///|
pub fn PgConn::close(self : PgConn) -> Unit {
  self.client.close()
}

///|
/// Execute a SQL statement and return all result rows as strings.
pub async fn PgConn::query(
  self : PgConn,
  sql : String,
) -> Result[@db.QueryResult, String] {
  let stream = self.client.simple_query(sql) catch {
    err => return Err(err.to_string())
  }
  let mut columns : Array[String] = []
  let rows : Array[Array[String]] = []
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
                None => "NULL"
                Some(s) => s
              }
            }),
          )
          continue stream.next()
        }
        @pg.SimpleQueryMessage::CommandComplete(_) => continue stream.next()
      }
  }
  Ok({ columns, rows })
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
