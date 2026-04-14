///|
/// Build a collapsible Tree widget for the given DB handle.
/// Structure: root (db name) → "Tables" group → individual table entries.
pub async fn build_schema_tree(
  handle : &@db.DbConn,
  db_label : String,
) -> @widget.Tree {
  let items : Array[@widget.TreeItem] = []
  items.push(@widget.TreeItem::node(db_label, 0))
  let tables = match handle.tables() {
    Ok(t) => t
    Err(_) => []
  }
  if tables.length() > 0 {
    items.push(@widget.TreeItem::node("Tables", 1))
    for t in tables {
      items.push(@widget.TreeItem::collapsed_node_with_data(t, 2, "table:\{t}"))
    }
  }
  let views = match handle.views() {
    Ok(v) => v
    Err(_) => []
  }
  if views.length() > 0 {
    items.push(@widget.TreeItem::node("Views", 1))
    for v in views {
      items.push(@widget.TreeItem::collapsed_node_with_data(v, 2, "view:\{v}"))
    }
  }
  let routines = match handle.routines() {
    Ok(r) => r
    Err(_) => []
  }
  if routines.length() > 0 {
    items.push(@widget.TreeItem::node("Routines", 1))
    for routine in routines {
      items.push(@widget.TreeItem::leaf(routine, 2, "routine:\{routine}"))
    }
  }
  @widget.Tree::new(items)
}

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
pub(all) struct SearchMatch {
  line : Int
  col : Int
  length : Int
} derive(Eq, Show)

///|
pub let schema_width_percent : Int = 28

///|
pub let editor_height_percent : Int = 35

///|
pub let results_height_percent : Int = 65

///|
/// Which screen is currently displayed.
pub(all) enum Screen {
  Connect
  Main
} derive(Eq)

///|
/// Which panel has focus on the Connect screen.
pub(all) enum ConnPanel {
  ProfileList
  Form
} derive(Eq)

///|
/// State for the connection form.
/// focus_idx: 0 = profile name, 1 = DB kind, 2..N+1 = connection text fields.
pub(all) struct ConnForm {
  name : @widget.Input
  kind_idx : Int
  host : @widget.Input
  port : @widget.Input
  database : @widget.Input
  username : @widget.Input
  password : @widget.Input
  connect_timeout_secs : @widget.Input
  tls_enabled : Bool
  ca_cert_path : @widget.Input
  client_cert_path : @widget.Input
  client_key_path : @widget.Input
  focus_idx : Int
  error : String
}

///|
pub fn ConnForm::new() -> ConnForm {
  {
    name: @widget.Input::new(),
    kind_idx: 0,
    host: @widget.Input::new().with_value("localhost"),
    port: @widget.Input::new().with_value(""),
    database: @widget.Input::new().with_value(":memory:"),
    username: @widget.Input::new().with_value(""),
    password: @widget.Input::new().with_value(""),
    connect_timeout_secs: @widget.Input::new().with_value("10"),
    tls_enabled: false,
    ca_cert_path: @widget.Input::new().with_value(""),
    client_cert_path: @widget.Input::new().with_value(""),
    client_key_path: @widget.Input::new().with_value(""),
    focus_idx: 1,
    error: "",
  }
}

///|
/// Number of connection text fields (excluding name and DB-kind row).
/// SQLite = 1 (path only), others = 10.
pub fn ConnForm::field_count(self : ConnForm) -> Int {
  match self.kind_idx {
    0 => 1
    _ => 10
  }
}

///|
/// Total items in the form tab order: name + kind + connection fields.
pub fn ConnForm::total_fields(self : ConnForm) -> Int {
  self.field_count() + 2
}

///|
pub fn ConnForm::handle_key(self : ConnForm, key : @terminal.Key) -> ConnForm {
  match key {
    Tab => {
      let total = self.total_fields()
      { ..self, focus_idx: (self.focus_idx + 1) % total, error: "" }
    }
    ShiftTab => {
      let total = self.total_fields()
      { ..self, focus_idx: (self.focus_idx + total - 1) % total, error: "" }
    }
    Up | Down =>
      if self.focus_idx == 1 {
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
          connect_timeout_secs: @widget.Input::new().with_value("10"),
          tls_enabled: false,
          ca_cert_path: @widget.Input::new().with_value(""),
          client_cert_path: @widget.Input::new().with_value(""),
          client_key_path: @widget.Input::new().with_value(""),
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
  match self.focus_idx {
    0 => { ..self, name: self.name.handle_key(key) }
    1 => self
    fi => {
      let field_fi = fi - 2 // 0-based connection field index
      match self.kind_idx {
        0 =>
          if field_fi == 0 {
            { ..self, database: self.database.handle_key(key) }
          } else {
            self
          }
        _ =>
          match field_fi {
            0 => { ..self, host: self.host.handle_key(key) }
            1 => { ..self, port: self.port.handle_key(key) }
            2 => { ..self, database: self.database.handle_key(key) }
            3 => { ..self, username: self.username.handle_key(key) }
            4 => { ..self, password: self.password.handle_key(key) }
            5 =>
              {
                ..self,
                connect_timeout_secs: self.connect_timeout_secs.handle_key(key),
              }
            6 =>
              if key == Enter || key == Char(' ') {
                { ..self, tls_enabled: !self.tls_enabled }
              } else {
                self
              }
            7 => { ..self, ca_cert_path: self.ca_cert_path.handle_key(key) }
            8 =>
              {
                ..self,
                client_cert_path: self.client_cert_path.handle_key(key),
              }
            9 =>
              { ..self, client_key_path: self.client_key_path.handle_key(key) }
            _ => self
          }
      }
    }
  }
}

///|
/// Returns true when a query is currently being executed.
pub fn AppState::is_query_running(self : AppState) -> Bool {
  self.running_query is Some(_)
}

///|
/// Describes a running query job for the async query state machine.
pub(all) enum RunningQuery {
  /// A single statement execution (Ctrl+Enter).
  Single(sql~ : String, started~ : @bench.Timestamp)
  /// Sequential run-all execution (F5).
  RunAll(
    stmts~ : Array[String],
    current_idx~ : Int,
    started~ : @bench.Timestamp,
    partial_results~ : @widget.Table,
    total_rows~ : Int,
    total_affected~ : Int,
    has_affected~ : Bool,
    stmt_count~ : Int,
    in_txn~ : Bool
  )
}

///|
/// Top-level application state.
pub(all) struct AppState {
  screen : Screen
  conn : &@db.DbConn?
  conn_form : ConnForm
  conn_panel : ConnPanel
  profiles : Array[@config.ConnProfile]
  profile_idx : Int
  schema_tree : @widget.Tree
  sql_input : @widget.TextArea
  query_history : Array[String]
  history_index : Int?
  history_draft : String?
  results : @widget.Table
  search_input : @widget.Input?
  search_matches : Array[SearchMatch]
  search_match_index : Int
  search_editing : Bool
  file_prompt : @widget.Input?
  focus : Panel
  status : String
  should_quit : Bool
  show_help : Bool
  show_error : Bool
  in_transaction : Bool
  running_query : RunningQuery?
  cancel_requested : Bool
  conn_lost : Bool
  group : @async.TaskGroup[Unit]
}

///|
pub fn AppState::new(group : @async.TaskGroup[Unit]) -> AppState {
  let profiles = @config.load_profiles()
  {
    screen: Connect,
    conn: None,
    conn_form: ConnForm::new(),
    conn_panel: if profiles.length() > 0 {
      ProfileList
    } else {
      Form
    },
    profiles,
    profile_idx: if profiles.length() > 0 {
      0
    } else {
      -1
    },
    schema_tree: @widget.Tree::new([]),
    sql_input: @widget.TextArea::new(),
    query_history: [],
    history_index: None,
    history_draft: None,
    results: @widget.Table::new([], []),
    search_input: None,
    search_matches: [],
    search_match_index: 0,
    search_editing: false,
    file_prompt: None,
    focus: Editor,
    status: connect_status(
      if profiles.length() > 0 {
        ProfileList
      } else {
        Form
      },
    ),
    should_quit: false,
    show_help: false,
    show_error: false,
    in_transaction: false,
    running_query: None,
    cancel_requested: false,
    conn_lost: false,
    group,
  }
}

///|
/// Return just the profile names (for rendering the left panel).
pub fn AppState::profile_names(self : AppState) -> Array[String] {
  let names : Array[String] = []
  for p in self.profiles {
    names.push(p.name)
  }
  names
}

///|
/// Navigate the profile list with ↑/↓.
pub fn AppState::navigate_profiles(
  self : AppState,
  key : @terminal.Key,
) -> AppState {
  let n = self.profiles.length()
  if n == 0 {
    return self
  }
  let new_idx = match key {
    Up => if self.profile_idx <= 0 { n - 1 } else { self.profile_idx - 1 }
    Down => (self.profile_idx + 1) % n
    _ => self.profile_idx
  }
  { ..self, profile_idx: new_idx }
}

///|
/// Load the currently selected profile into the connection form.
pub fn AppState::load_selected_profile(self : AppState) -> AppState {
  let n = self.profiles.length()
  if self.profile_idx < 0 || self.profile_idx >= n {
    return { ..self, conn_panel: Form }
  }
  let p = self.profiles[self.profile_idx]
  let password = @config.keyring_get(p.name)
  let port_str = if p.port > 0 {
    p.port.to_string()
  } else {
    default_port_str(p.kind_idx)
  }
  let new_form = {
    name: @widget.Input::new().with_value(p.name),
    kind_idx: p.kind_idx,
    host: @widget.Input::new().with_value(p.host),
    port: @widget.Input::new().with_value(port_str),
    database: @widget.Input::new().with_value(p.database),
    username: @widget.Input::new().with_value(p.username),
    password: @widget.Input::new().with_value(password),
    connect_timeout_secs: @widget.Input::new().with_value(
      p.connect_timeout_secs.to_string(),
    ),
    tls_enabled: p.tls_enabled,
    ca_cert_path: @widget.Input::new().with_value(p.ca_cert_path),
    client_cert_path: @widget.Input::new().with_value(p.client_cert_path),
    client_key_path: @widget.Input::new().with_value(p.client_key_path),
    focus_idx: 2,
    error: "",
  }
  {
    ..self,
    conn_form: new_form,
    conn_panel: Form,
    status: connect_status(Form),
  }
}

///|
/// Save the current form as a profile (create or update by name).
pub fn AppState::save_current_profile(self : AppState) -> AppState {
  let form = self.conn_form
  let name = form.name.value()
  if name == "" {
    return { ..self, conn_form: { ..form, error: "Profile name is required" } }
  }
  let profile : @config.ConnProfile = {
    name,
    kind_idx: form.kind_idx,
    host: form.host.value(),
    port: str_to_int(form.port.value(), default_port_int(form.kind_idx)),
    database: form.database.value(),
    username: form.username.value(),
    tls_enabled: form.tls_enabled,
    ca_cert_path: form.ca_cert_path.value(),
    client_cert_path: form.client_cert_path.value(),
    client_key_path: form.client_key_path.value(),
    connect_timeout_secs: parse_connect_timeout_secs(
      form.connect_timeout_secs.value(),
    ),
  }
  let mut existing_idx = -1
  for i = 0; i < self.profiles.length(); i = i + 1 {
    if self.profiles[i].name == name {
      existing_idx = i
      break
    }
  }
  let new_profiles = self.profiles.copy()
  if existing_idx >= 0 {
    new_profiles[existing_idx] = profile
  } else {
    new_profiles.push(profile)
  }
  @config.save_profiles(new_profiles)
  @config.keyring_set(name, form.password.value())
  let new_idx = if existing_idx >= 0 {
    existing_idx
  } else {
    new_profiles.length() - 1
  }
  {
    ..self,
    profiles: new_profiles,
    profile_idx: new_idx,
    conn_form: { ..form, error: "" },
    status: "Saved: \{name}",
  }
}

///|
/// Delete the currently selected profile (and its keyring entry).
pub fn AppState::delete_selected_profile(self : AppState) -> AppState {
  let n = self.profiles.length()
  if self.profile_idx < 0 || self.profile_idx >= n {
    return self
  }
  let name = self.profiles[self.profile_idx].name
  @config.keyring_delete(name)
  let new_profiles = self.profiles.copy()
  let _ = new_profiles.remove(self.profile_idx)
  @config.save_profiles(new_profiles)
  let new_idx = if new_profiles.length() == 0 {
    -1
  } else if self.profile_idx >= new_profiles.length() {
    new_profiles.length() - 1
  } else {
    self.profile_idx
  }
  let new_panel = if new_profiles.length() == 0 { Form } else { ProfileList }
  {
    ..self,
    profiles: new_profiles,
    profile_idx: new_idx,
    conn_panel: new_panel,
    status: "Deleted: \{name}",
  }
}

///|
/// Attempt to connect using the current ConnForm values.
pub async fn AppState::do_connect(self : AppState) -> AppState {
  let form = self.conn_form
  let timeout_ms = connect_timeout_millis(form.connect_timeout_secs.value())
  let result : Result[&@db.DbConn, String] = match form.kind_idx {
    0 => {
      let path = form.database.value()
      match @sqlite.SqliteConn::open(path) {
        Ok(c) => Ok(c)
        Err(e) => Err(e)
      }
    }
    1 => {
      if has_custom_cert_paths(form) {
        return {
          ..self,
          conn_form: {
            ..form,
            error: "PostgreSQL certificate paths are not supported by the current driver",
          },
        }
      }
      let port = str_to_int(form.port.value(), 5432)
      match
        @async.with_timeout_opt(timeout_ms, async fn() {
          let (conn, connection) = @postgres.PgConn::connect(
            form.host.value(),
            port,
            form.database.value(),
            form.username.value(),
            form.password.value(),
            form.tls_enabled,
            self.group,
          ) catch {
            err => return Err(err.to_string())
          }
          self.group.spawn_bg(
            async fn() { connection.run() },
            allow_failure=true,
          )
          Ok(conn)
        }) {
        Some(Ok(conn)) => Ok(conn)
        Some(Err(msg)) => Err(msg)
        None =>
          Err(
            "Connection timed out after \{parse_connect_timeout_secs(form.connect_timeout_secs.value())}s",
          )
      }
    }
    _ => {
      if form.tls_enabled || has_custom_cert_paths(form) {
        return {
          ..self,
          conn_form: {
            ..form,
            error: "MySQL TLS is not supported by the current driver",
          },
        }
      }
      let port = str_to_int(form.port.value(), 3306)
      match
        @async.with_timeout_opt(timeout_ms, async fn() {
          Ok(
            @moon_mysql_db.MoonMysqlConn::connect(
              form.host.value(),
              port,
              form.database.value(),
              form.username.value(),
              form.password.value(),
              self.group,
            ),
          ) catch {
            e => Err(e.to_string())
          }
        }) {
        Some(Ok(conn)) => Ok(conn)
        Some(Err(msg)) => Err(msg)
        None =>
          Err(
            "Connection timed out after \{parse_connect_timeout_secs(form.connect_timeout_secs.value())}s",
          )
      }
    }
  }
  match result {
    Ok(handle) => {
      let db_label = form.database.value()
      let tree = build_schema_tree(handle, db_label)
      {
        ..self,
        conn: Some(handle),
        screen: Main,
        schema_tree: tree,
        focus: Editor,
        status: "Tab=switch panel  Ctrl+Enter=run  Ctrl+X=EXPLAIN  Ctrl+S=export  Ctrl+D=disconnect  Ctrl+Q=quit",
      }
    }
    Err(msg) => { ..self, conn_form: { ..form, error: msg } }
  }
}

///|
/// Re-query the database for the current table list and rebuild the schema tree.
pub async fn AppState::refresh_schema(self : AppState) -> AppState {
  match self.conn {
    None => { ..self, status: "Error: not connected", show_error: false }
    Some(conn) => {
      let db_label = self.conn_form.database.value()
      let tree = build_schema_tree(conn, db_label)
      {
        ..self,
        schema_tree: tree,
        status: "Schema refreshed",
        show_error: false,
      }
    }
  }
}

///|
/// Attempt to reconnect to the database using the current ConnForm parameters.
/// Called automatically when a connection-loss error is detected.
/// On success, stays on the Main screen with a fresh connection.
/// On failure, stays on Main with an error status so the user can use Ctrl+D.
pub async fn AppState::attempt_reconnect(self : AppState) -> AppState {
  match self.conn {
    Some(conn) => conn.close()
    None => ()
  }
  let state = { ..self, conn: None, conn_lost: false }
  let connected = state.do_connect()
  if connected.conn is Some(_) {
    { ..connected, status: "Reconnected successfully" }
  } else {
    let err = connected.conn_form.error
    {
      ..connected,
      status: "Reconnect failed: \{err}. Use Ctrl+D to go back to Connect screen.",
      show_error: false,
    }
  }
}

///|
/// Close the current connection and return to the Connect screen.
pub fn AppState::disconnect(self : AppState) -> AppState {
  match self.conn {
    Some(conn) => conn.close()
    None => ()
  }
  let conn_panel = if self.profiles.length() > 0 { ProfileList } else { Form }
  {
    ..self,
    conn: None,
    screen: Connect,
    conn_panel,
    schema_tree: @widget.Tree::new([]),
    results: @widget.Table::new([], []),
    search_input: None,
    search_matches: [],
    search_match_index: 0,
    search_editing: false,
    file_prompt: None,
    running_query: None,
    cancel_requested: false,
    conn_lost: false,
    in_transaction: false,
    status: connect_status(conn_panel),
    show_error: false,
  }
}

///|
pub fn AppState::export_results_csv(self : AppState) -> AppState {
  if self.results.columns.length() == 0 {
    return { ..self, status: "No results to export", show_error: false }
  }
  match @config.export_results_csv(self.results.columns, self.results.rows) {
    Ok(path) => { ..self, status: "Exported CSV to \{path}", show_error: false }
    Err(msg) => { ..self, status: "Error: \{msg}", show_error: false }
  }
}

///|
pub fn AppState::export_results_json(self : AppState) -> AppState {
  if self.results.columns.length() == 0 {
    return { ..self, status: "No results to export", show_error: false }
  }
  match @config.export_results_json(self.results.columns, self.results.rows) {
    Ok(path) =>
      { ..self, status: "Exported JSON to \{path}", show_error: false }
    Err(msg) => { ..self, status: "Error: \{msg}", show_error: false }
  }
}

///|
pub fn AppState::load_sql_file(
  self : AppState,
  path : String,
) -> Result[String, String] {
  let _ = self
  @config.read_text_file(path)
}

///|
pub fn AppState::record_query_history(
  self : AppState,
  query : String,
) -> AppState {
  let trimmed = query.trim().to_string()
  if trimmed == "" {
    return self.clear_query_history_nav()
  }
  let history = self.query_history.copy()
  let last = history.length() - 1
  if last < 0 || history[last] != trimmed {
    history.push(trimmed)
  }
  { ..self, query_history: history, history_index: None, history_draft: None }
}

///|
pub fn AppState::recall_prev_query(self : AppState) -> AppState {
  let count = self.query_history.length()
  if count == 0 {
    return self
  }
  match self.history_index {
    Some(idx) => {
      let next_idx = if idx > 0 { idx - 1 } else { 0 }
      {
        ..self,
        history_index: Some(next_idx),
        sql_input: self.sql_input.with_value(self.query_history[next_idx]),
      }
    }
    None => {
      let next_idx = count - 1
      {
        ..self,
        history_index: Some(next_idx),
        history_draft: Some(self.sql_input.value()),
        sql_input: self.sql_input.with_value(self.query_history[next_idx]),
      }
    }
  }
}

///|
pub fn AppState::recall_next_query(self : AppState) -> AppState {
  match self.history_index {
    None => self
    Some(idx) =>
      if idx + 1 < self.query_history.length() {
        let next_idx = idx + 1
        {
          ..self,
          history_index: Some(next_idx),
          sql_input: self.sql_input.with_value(self.query_history[next_idx]),
        }
      } else {
        let draft = match self.history_draft {
          Some(value) => value
          None => ""
        }
        {
          ..self,
          history_index: None,
          history_draft: None,
          sql_input: self.sql_input.with_value(draft),
        }
      }
  }
}

///|
pub fn AppState::clear_query_history_nav(self : AppState) -> AppState {
  { ..self, history_index: None, history_draft: None }
}

// ── Transaction-classification helpers ────────────────────────────────────────

///|
// Uppercase the first `n` characters of `s` (ASCII letters only).
fn to_upper_ascii_prefix(s : String, n : Int) -> String {
  let sb = StringBuilder::new()
  let mut i = 0
  for c in s.iter() {
    if i >= n {
      break
    }
    sb.write_char(
      if c >= 'a' && c <= 'z' {
        Int::unsafe_to_char(c.to_int() - 32)
      } else {
        c
      },
    )
    i = i + 1
  }
  sb.to_string()
}

///|
// Returns true when `stmt` (trimmed) begins with `upper_keyword` (already
// uppercase) followed by a non-identifier character or end of string.
// This avoids false positives such as "ROLLBACKUP" matching "ROLLBACK".
fn stmt_starts_with_keyword(stmt : String, upper_keyword : String) -> Bool {
  let klen = upper_keyword.length()
  if stmt.length() < klen {
    return false
  }
  if to_upper_ascii_prefix(stmt, klen) != upper_keyword {
    return false
  }
  match stmt.get_char(klen) {
    None => true
    Some(c) =>
      !(c is ('A'..='Z') || c is ('a'..='z') || c is ('0'..='9') || c == '_')
  }
}

///|
/// Returns `true` when `stmt`, if executed successfully, would *open* a
/// transaction: `BEGIN [DEFERRED|IMMEDIATE|EXCLUSIVE]` or `START TRANSACTION`.
pub fn stmt_opens_txn(stmt : String) -> Bool {
  let s = stmt.trim().to_string()
  stmt_starts_with_keyword(s, "BEGIN") ||
  stmt_starts_with_keyword(s, "START TRANSACTION")
}

///|
/// Returns `true` when `stmt`, if executed successfully, would *close* a
/// transaction: `COMMIT [WORK|TRANSACTION]` or bare `ROLLBACK`.
pub fn stmt_closes_txn(stmt : String) -> Bool {
  let s = stmt.trim().to_string()
  if stmt_starts_with_keyword(s, "COMMIT") {
    return true
  }
  // ROLLBACK TO [SAVEPOINT] rolls back to a savepoint but stays inside the
  // transaction. Only a bare ROLLBACK (or ROLLBACK WORK / ROLLBACK TRANSACTION)
  // ends the transaction.
  if stmt_starts_with_keyword(s, "ROLLBACK") {
    return !stmt_starts_with_keyword(s, "ROLLBACK TO")
  }
  false
}

///|
/// Update `in_transaction` based on a successfully-executed statement.
/// Call this after every successful query execution to keep the flag in sync
/// when the user issues BEGIN / COMMIT / ROLLBACK directly in the editor.
pub fn AppState::sync_txn_flag_for_stmt(
  self : AppState,
  stmt : String,
) -> AppState {
  if stmt_opens_txn(stmt) {
    { ..self, in_transaction: true }
  } else if stmt_closes_txn(stmt) {
    { ..self, in_transaction: false }
  } else {
    self
  }
}

///|
/// Returns the left-side text for the menu bar.
/// Shows the connected database kind and name when on the Main screen.
/// Appends `[TXN]` when a transaction is active.
pub fn AppState::menu_bar_left_label(self : AppState) -> String {
  let db_info = match self.conn {
    None => ""
    Some(_) => {
      let kind = match self.conn_form.kind_idx {
        0 => "SQLite"
        1 => "PG"
        _ => "MySQL"
      }
      let db = self.conn_form.database.value()
      " [\{kind}:\{db}]"
    }
  }
  if self.in_transaction {
    " honeydew\{db_info}  [TXN] "
  } else {
    " honeydew\{db_info} "
  }
}

///|
/// Issue BEGIN to the database and mark the session as in-transaction.
/// Reports a clear status (without touching the database) when already inside
/// a transaction.
pub async fn AppState::begin_transaction(self : AppState) -> AppState {
  if self.in_transaction {
    return {
      ..self,
      status: "Already in a transaction — use Ctrl+M to COMMIT or Ctrl+R to ROLLBACK",
      show_error: false,
    }
  }
  match self.conn {
    None => { ..self, status: "Error: not connected", show_error: false }
    Some(conn) =>
      match (conn.query("BEGIN") catch { err => Err(err.to_string()) }) {
        Ok(_) =>
          {
            ..self,
            in_transaction: true,
            status: "Transaction started (BEGIN)",
            show_error: false,
          }
        Err(msg) => { ..self, status: "Error: \{msg}", show_error: false }
      }
  }
}

///|
/// Issue COMMIT to the database and clear the in-transaction flag.
/// Reports a clear status (without touching the database) when not inside
/// a transaction.
pub async fn AppState::commit_transaction(self : AppState) -> AppState {
  if !self.in_transaction {
    return {
      ..self,
      status: "Not in a transaction — use Ctrl+B to BEGIN",
      show_error: false,
    }
  }
  match self.conn {
    None => { ..self, status: "Error: not connected", show_error: false }
    Some(conn) =>
      match (conn.query("COMMIT") catch { err => Err(err.to_string()) }) {
        Ok(_) =>
          {
            ..self,
            in_transaction: false,
            status: "Transaction committed (COMMIT)",
            show_error: false,
          }
        Err(msg) => { ..self, status: "Error: \{msg}", show_error: false }
      }
  }
}

///|
/// Issue ROLLBACK to the database and clear the in-transaction flag.
/// Reports a clear status (without touching the database) when not inside
/// a transaction.
pub async fn AppState::rollback_transaction(self : AppState) -> AppState {
  if !self.in_transaction {
    return {
      ..self,
      status: "Not in a transaction — use Ctrl+B to BEGIN",
      show_error: false,
    }
  }
  match self.conn {
    None => { ..self, status: "Error: not connected", show_error: false }
    Some(conn) =>
      match (conn.query("ROLLBACK") catch { err => Err(err.to_string()) }) {
        Ok(_) =>
          {
            ..self,
            in_transaction: false,
            status: "Transaction rolled back (ROLLBACK)",
            show_error: false,
          }
        Err(msg) => { ..self, status: "Error: \{msg}", show_error: false }
      }
  }
}

///|
pub fn AppState::copy_selected_result_cell(self : AppState) -> AppState {
  match self.results.selected_cell() {
    Some(value) =>
      match @config.copy_to_clipboard(value) {
        Ok(_) =>
          { ..self, status: "Copied cell to clipboard", show_error: false }
        Err(msg) => { ..self, status: "Error: \{msg}", show_error: false }
      }
    None => { ..self, status: "No cell selected", show_error: false }
  }
}

///|
pub fn AppState::copy_selected_result_row(self : AppState) -> AppState {
  match self.results.selected_row() {
    Some(row) =>
      match @config.copy_to_clipboard(row.join("\t")) {
        Ok(_) =>
          { ..self, status: "Copied row to clipboard", show_error: false }
        Err(msg) => { ..self, status: "Error: \{msg}", show_error: false }
      }
    None => { ..self, status: "No row selected", show_error: false }
  }
}

///|
/// Return the table name of the currently selected schema-tree item,
/// or None when the selection is on a header node (root or group).
pub fn AppState::selected_schema_table(self : AppState) -> String? {
  self.schema_tree.selected_data()
}

///|
/// Handle a mouse click inside the schema (Objects) panel.
/// `term_cols` and `term_rows` are the current terminal dimensions.
/// Computes the panel's outer area from the layout geometry and delegates to
/// `Tree::handle_click`, which toggles expandable nodes and selects leaves.
pub async fn AppState::handle_schema_click(
  self : AppState,
  mx : Int,
  my : Int,
  term_cols : Int,
  term_rows : Int,
) -> AppState {
  // Replicate the layout geometry from render_main:
  //   Row 1          : menu bar
  //   Row 2..rows-1  : main content
  //   Row rows       : status bar
  //   Column 1..schema_w : schema panel (schema_width_percent of total width)
  let schema_w = term_cols * schema_width_percent / 100
  let schema_area = @layout.Rect::new(1, 2, schema_w, term_rows - 2)
  let clicked_tree = self.schema_tree.handle_click(mx, my, schema_area)
  if should_lazy_expand(self.schema_tree, clicked_tree) {
    do_lazy_expand_schema_selection({ ..self, schema_tree: clicked_tree })
  } else {
    { ..self, schema_tree: clicked_tree }
  }
}

///|
pub fn AppState::handle_results_click(
  self : AppState,
  mx : Int,
  my : Int,
  term_cols : Int,
  term_rows : Int,
) -> AppState {
  let schema_w = term_cols * schema_width_percent / 100
  let content_h = term_rows - 2
  let editor_h = content_h * editor_height_percent / 100
  let results_area = @layout.Rect::new(
    schema_w + 1,
    2 + editor_h,
    term_cols - schema_w,
    content_h - editor_h,
  )
  { ..self, results: self.results.handle_click(mx, my, results_area) }
}

///|
/// Return the status bar hint string for the Connect screen.
pub fn connect_status(panel : ConnPanel) -> String {
  match panel {
    ProfileList => "Tab=switch  Enter=load  Ctrl+S=save  d=delete  q=quit"
    Form => "Tab=switch  Enter=connect  Ctrl+S=save  Ctrl+Q=quit"
  }
}

///|
fn should_lazy_expand(before : @widget.Tree, after : @widget.Tree) -> Bool {
  match (before.selected_item(), after.selected_item()) {
    (Some(prev), Some(next)) =>
      next.depth == 2 && next.expandable && next.expanded && !prev.expanded
    _ => false
  }
}

///|
async fn do_lazy_expand_schema_selection(state : AppState) -> AppState {
  match (state.conn, state.schema_tree.selected_item()) {
    (Some(conn), Some(item)) =>
      match schema_item_kind_and_name(item) {
        Some((kind, name)) =>
          match load_schema_children(conn, kind, name) {
            Ok(children) =>
              {
                ..state,
                schema_tree: state.schema_tree.replace_selected_children(
                  children,
                ),
                status: "Loaded schema details for \{name}",
                show_error: false,
              }
            Err(msg) => { ..state, status: "Error: \{msg}", show_error: false }
          }
        None => state
      }
    _ => state
  }
}

///|
fn schema_item_kind_and_name(item : @widget.TreeItem) -> (String, String)? {
  if item.depth != 2 || item.data == "" {
    return None
  }
  if item.data.has_prefix("table:") {
    return Some(("table", item.data[6:].to_string()))
  }
  if item.data.has_prefix("view:") {
    return Some(("view", item.data[5:].to_string()))
  }
  None
}

///|
async fn load_schema_children(
  conn : &@db.DbConn,
  kind : String,
  name : String,
) -> Result[Array[@widget.TreeItem], String] {
  let items : Array[@widget.TreeItem] = []
  let columns = match conn.columns(name) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  for col in columns {
    items.push(
      @widget.TreeItem::leaf("\{col.name} : \{col.col_type}", 3, col.name),
    )
  }
  if kind == "table" {
    let indexes = match conn.indexes(name) {
      Ok(v) => v
      Err(e) => return Err(e)
    }
    for index_name in indexes {
      items.push(@widget.TreeItem::leaf("INDEX \{index_name}", 3, index_name))
    }
    let triggers = match conn.triggers(name) {
      Ok(v) => v
      Err(e) => return Err(e)
    }
    for trigger_name in triggers {
      items.push(
        @widget.TreeItem::leaf("TRIGGER \{trigger_name}", 3, trigger_name),
      )
    }
  }
  Ok(items)
}

///|
pub async fn AppState::lazy_expand_schema_selection(
  self : AppState,
) -> AppState {
  do_lazy_expand_schema_selection(self)
}

///|
fn connect_timeout_millis(value : String) -> Int {
  parse_connect_timeout_secs(value) * 1000
}

///|
fn parse_connect_timeout_secs(value : String) -> Int {
  let parsed = str_to_int(value, 10)
  if parsed > 0 {
    parsed
  } else {
    10
  }
}

///|
fn has_custom_cert_paths(form : ConnForm) -> Bool {
  form.ca_cert_path.value() != "" ||
  form.client_cert_path.value() != "" ||
  form.client_key_path.value() != ""
}

///|
fn default_port_str(kind_idx : Int) -> String {
  match kind_idx {
    1 => "5432"
    2 => "3306"
    _ => ""
  }
}

///|
fn default_port_int(kind_idx : Int) -> Int {
  match kind_idx {
    1 => 5432
    2 => 3306
    _ => 0
  }
}

///|
/// Parse a decimal integer string; return `default` on failure.
pub fn str_to_int(s : String, default : Int) -> Int {
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
