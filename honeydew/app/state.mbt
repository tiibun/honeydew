///|
/// Build a collapsible Tree widget for the given DB handle.
/// Structure: root (db name) → "Tables" group → individual table entries.
pub async fn build_schema_tree(
  handle : DbHandle,
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
      items.push(@widget.TreeItem::leaf(t, 2, t))
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
    focus_idx: 1,
    error: "",
  }
}

///|
/// Number of connection text fields (excluding name and DB-kind row).
/// SQLite = 1 (path only), others = 5.
pub fn ConnForm::field_count(self : ConnForm) -> Int {
  match self.kind_idx {
    0 => 1
    _ => 5
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
            _ => self
          }
      }
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
  conn_panel : ConnPanel
  profiles : Array[@config.ConnProfile]
  profile_idx : Int
  schema_tree : @widget.Tree
  sql_input : @widget.TextArea
  query_history : Array[String]
  history_index : Int?
  history_draft : String?
  results : @widget.Table
  focus : Panel
  status : String
  should_quit : Bool
  show_help : Bool
  show_error : Bool
  in_transaction : Bool
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
      let db_label = form.database.value()
      let tree = build_schema_tree(handle, db_label)
      {
        ..self,
        conn: Some(handle),
        screen: Main,
        schema_tree: tree,
        focus: Editor,
        status: "Tab=switch panel  Ctrl+Enter=run  Ctrl+S=export  Ctrl+Q=quit",
      }
    }
    Err(msg) => { ..self, conn_form: { ..form, error: msg } }
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

///|
/// Issue BEGIN to the database and mark the session as in-transaction.
pub async fn AppState::begin_transaction(self : AppState) -> AppState {
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
pub async fn AppState::commit_transaction(self : AppState) -> AppState {
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
pub async fn AppState::rollback_transaction(self : AppState) -> AppState {
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
pub fn AppState::handle_schema_click(
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
  //   Column 1..schema_w : schema panel (28% of total width)
  let schema_w = term_cols * 28 / 100
  let schema_area = @layout.Rect::new(1, 2, schema_w, term_rows - 2)
  { ..self, schema_tree: self.schema_tree.handle_click(mx, my, schema_area) }
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
