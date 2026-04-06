///|
/// Which database type to connect to.
pub(all) enum DbKind {
  Sqlite
  Postgres
  Mysql
}

///|
pub fn DbKind::label(self : DbKind) -> String {
  match self {
    Sqlite => "SQLite"
    Postgres => "PostgreSQL"
    Mysql => "MySQL"
  }
}

///|
/// Which panel has keyboard focus on the main screen.
pub(all) enum Panel {
  Schema
  Editor
  Results
} derive(Eq)

///|
/// Which screen is currently displayed.
pub(all) enum Screen {
  Connect
  Main
} derive(Eq)

///|
/// State for the connection form.
pub(all) struct ConnForm {
  kind_idx : Int
  host : @widget.Input
  port : @widget.Input
  database : @widget.Input
  username : @widget.Input
  password : @widget.Input
  /// Which field index (0 = DB kind, 1‥N = text fields) has focus.
  focus_idx : Int
  error : String
}

///|
pub fn ConnForm::new() -> ConnForm {
  {
    kind_idx: 0,
    host: @widget.Input::new().with_value("localhost"),
    port: @widget.Input::new().with_value(""),
    database: @widget.Input::new().with_value(":memory:"),
    username: @widget.Input::new().with_value(""),
    password: @widget.Input::new().with_value(""),
    focus_idx: 1,
    error: "",
  }
}

///|
/// Number of text fields for the current DB kind.
/// SQLite = 1 (path), others = 5.
pub fn ConnForm::field_count(self : ConnForm) -> Int {
  match self.kind_idx {
    0 => 1
    _ => 5
  }
}

///|
pub fn ConnForm::handle_key(self : ConnForm, key : @terminal.Key) -> ConnForm {
  match key {
    Tab => {
      // focus_idx: 0 = kind selector, 1..field_count = text fields
      let total = self.field_count() + 1
      { ..self, focus_idx: (self.focus_idx + 1) % total, error: "" }
    }
    ShiftTab => {
      let total = self.field_count() + 1
      { ..self, focus_idx: (self.focus_idx + total - 1) % total, error: "" }
    }
    Up | Down =>
      if self.focus_idx == 0 {
        let n = 3
        let next_kind = match key {
          Up => (self.kind_idx + n - 1) % n
          _ => (self.kind_idx + 1) % n
        }
        let default_port = match next_kind {
          1 => "5432"
          2 => "3306"
          _ => ""
        }
        let default_db = match next_kind {
          0 => ":memory:"
          _ => "testdb"
        }
        {
          ..self,
          kind_idx: next_kind,
          port: @widget.Input::new().with_value(default_port),
          database: @widget.Input::new().with_value(default_db),
          error: "",
        }
      } else {
        self
      }
    _ => self.route_key_to_field(key)
  }
}

///|
fn ConnForm::route_key_to_field(
  self : ConnForm,
  key : @terminal.Key,
) -> ConnForm {
  let fi = self.focus_idx - 1 // 0-based field index
  match self.kind_idx {
    0 =>
      // SQLite: only field is database path
      if fi == 0 {
        { ..self, database: self.database.handle_key(key) }
      } else {
        self
      }
    _ =>
      match fi {
        0 => { ..self, host: self.host.handle_key(key) }
        1 => { ..self, port: self.port.handle_key(key) }
        2 => { ..self, database: self.database.handle_key(key) }
        3 => { ..self, username: self.username.handle_key(key) }
        4 => { ..self, password: self.password.handle_key(key) }
        _ => self
      }
  }
}

///|
/// A handle to an active database connection (enum over the three backends).
pub(all) enum DbHandle {
  Sqlite(@sqlite.SqliteConn)
  Postgres(@postgres.PgConn)
  Mysql(@mysql.MysqlConn)
}

///|
pub async fn DbHandle::query(
  self : DbHandle,
  sql : String,
) -> Result[@db.QueryResult, String] {
  match self {
    Sqlite(c) => c.query(sql)
    Postgres(c) => c.query(sql)
    Mysql(c) => c.query(sql)
  }
}

///|
pub async fn DbHandle::tables(self : DbHandle) -> Result[Array[String], String] {
  match self {
    Sqlite(c) => c.tables()
    Postgres(c) => c.tables()
    Mysql(c) => c.tables()
  }
}

///|
pub async fn DbHandle::columns(
  self : DbHandle,
  table : String,
) -> Result[Array[@db.ColumnInfo], String] {
  match self {
    Sqlite(c) => c.columns(table)
    Postgres(c) => c.columns(table)
    Mysql(c) => c.columns(table)
  }
}

///|
pub fn DbHandle::close(self : DbHandle) -> Unit {
  match self {
    Sqlite(c) => c.close()
    Postgres(c) => c.close()
    Mysql(c) => c.close()
  }
}

///|
/// Top-level application state.
pub(all) struct AppState {
  screen : Screen
  conn : DbHandle?
  conn_form : ConnForm
  schema_items : Array[String]
  schema_list : @widget.List
  sql_input : @widget.Input
  results : @widget.Table
  focus : Panel
  status : String
  should_quit : Bool
  show_help : Bool
  group : @async.TaskGroup[Unit]
}

///|
pub fn AppState::new(group : @async.TaskGroup[Unit]) -> AppState {
  {
    screen: Connect,
    conn: None,
    conn_form: ConnForm::new(),
    schema_items: [],
    schema_list: @widget.List::new([]),
    sql_input: @widget.Input::new(),
    results: @widget.Table::new([], []),
    focus: Editor,
    status: "Tab=切替  Enter=接続  q=終了",
    should_quit: false,
    show_help: false,
    group,
  }
}

///|
/// Attempt to connect using the current ConnForm values.
/// For PostgreSQL, spawns the connection background task.
pub async fn AppState::do_connect(self : AppState) -> AppState {
  let form = self.conn_form
  let result : Result[DbHandle, String] = match form.kind_idx {
    0 => {
      let path = form.database.value()
      match @sqlite.SqliteConn::open(path) {
        Ok(c) => Ok(Sqlite(c))
        Err(e) => Err(e)
      }
    }
    1 => {
      let port = str_to_int(form.port.value(), 5432)
      let (conn, connection) = @postgres.PgConn::connect(
        form.host.value(),
        port,
        form.database.value(),
        form.username.value(),
        form.password.value(),
      ) catch {
        err => return { ..self, conn_form: { ..form, error: err.to_string() } }
      }
      self.group.spawn_bg(async fn() { connection.run() }, allow_failure=true)
      Ok(Postgres(conn))
    }
    _ => {
      let port = str_to_int(form.port.value(), 3306)
      match
        @mysql.MysqlConn::connect(
          form.host.value(),
          port,
          form.database.value(),
          form.username.value(),
          form.password.value(),
        ) {
        Ok(c) => Ok(Mysql(c))
        Err(e) => Err(e)
      }
    }
  }
  match result {
    Ok(handle) => {
      let tables = match handle.tables() {
        Ok(t) => t
        Err(_) => []
      }
      let list = @widget.List::new(tables)
      {
        ..self,
        conn: Some(handle),
        screen: Main,
        schema_items: tables,
        schema_list: list,
        focus: Editor,
        status: "Tab=パネル切替  Enter=実行  q=終了",
      }
    }
    Err(msg) => { ..self, conn_form: { ..form, error: msg } }
  }
}

///|
/// Parse a decimal integer string; return `default` on failure.
fn str_to_int(s : String, default : Int) -> Int {
  if s.length() == 0 {
    return default
  }
  let mut n = 0
  for c in s.iter() {
    let d = c.to_int() - 48
    if d < 0 || d > 9 {
      return default
    }
    n = n * 10 + d
  }
  n
}
