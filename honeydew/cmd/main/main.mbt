///|
fn main {
  @async.run_async_main(async fn() {
    let terminal = match @honeytui.Terminal::new() {
      Ok(t) => t
      Err(e) => {
        println("error: \{e}")
        return
      }
    }
    @async.with_task_group(async fn(group) {
      let mut state = @app.AppState::new(group)
      while !state.should_quit {
        terminal.draw(fn(frame) {
          match state.screen {
            @app.Connect => @ui.render_connect(frame, state)
            @app.Main => @ui.render_main(frame, state)
          }
        })
        if state.conn_lost {
          // Connection was lost — auto-reconnect using existing parameters.
          // The error status was already set; this draw showed it.
          // Now attempt reconnect (may block briefly for network connections).
          state = state.attempt_reconnect()
        } else if state.is_query_running() {
          // Non-blocking: poll for key with short timeout, then check query
          match
            @async.with_timeout_opt(50, async fn() { terminal.read_key() }) {
            Some(key) => state = handle_key(state, key)
            None => state = poll_running_query(state)
          }
        } else {
          let key = terminal.read_key()
          state = handle_key(state, key)
        }
      }
      terminal.restore()
      match state.conn {
        Some(conn) => conn.close()
        None => ()
      }
      group.return_immediately(()) catch {
        _ => ()
      }
    })
  })
}

///|
async fn handle_key(
  state : @app.AppState,
  key : @terminal.Key,
) -> @app.AppState {
  // Close help overlay on any key when it is open
  if state.show_help {
    return { ..state, show_help: false }
  }
  if state.show_error {
    return { ..state, show_error: false }
  }
  if key == CtrlE && state.screen == @app.Main && state.status.contains("Error") {
    return { ..state, show_error: true }
  }
  match key {
    CtrlC =>
      if state.is_query_running() {
        // Cancel the running query instead of quitting
        match state.conn {
          Some(conn) => conn.cancel()
          None => ()
        }
        { ..state, cancel_requested: true }
      } else {
        { ..state, should_quit: true }
      }
    CtrlQ => { ..state, should_quit: true }
    _ =>
      // Ignore all other keys while a query is running
      if state.is_query_running() {
        state
      } else {
        handle_key_idle(state, key)
      }
  }
}

///|
async fn handle_key_idle(
  state : @app.AppState,
  key : @terminal.Key,
) -> @app.AppState {
  if state.screen == @app.Main &&
    state.focus == @app.Editor &&
    state.file_prompt is Some(_) {
    return handle_file_prompt_key(state, key)
  }
  if state.screen == @app.Main &&
    state.focus == @app.Editor &&
    state.search_input is Some(_) {
    if state.search_editing {
      return handle_search_edit_key(state, key)
    }
    match key {
      Char('n') => return move_search_match(state, 1)
      Char('N') => return move_search_match(state, -1)
      Esc => return close_search(state)
      _ => ()
    }
  }
  match key {
    Char('?') => { ..state, show_help: true }
    Char('y') =>
      if state.screen == @app.Main && state.focus == @app.Results {
        state.copy_selected_result_cell()
      } else {
        dispatch(state, key)
      }
    Char('Y') =>
      if state.screen == @app.Main && state.focus == @app.Results {
        state.copy_selected_result_row()
      } else {
        dispatch(state, key)
      }
    Char('q') =>
      // 'q' quits only when profile list has focus; in the form it's text input
      if state.screen == @app.Connect && state.conn_panel == @app.ProfileList {
        { ..state, should_quit: true }
      } else {
        dispatch(state, key)
      }
    // ── Connect screen ──────────────────────────────────────────────
    Enter =>
      match state.screen {
        @app.Connect =>
          match state.conn_panel {
            @app.ProfileList => state.load_selected_profile()
            @app.Form => state.do_connect()
          }
        @app.Main =>
          if state.focus == @app.Schema {
            match state.schema_tree.selected_item() {
              // depth-2 expandable node = table or view: fill editor with SELECT
              Some(item) if item.depth == 2 && item.expandable => {
                let sql = "SELECT * FROM \{item.label} LIMIT 100"
                {
                  ..state,
                  sql_input: refresh_editor_highlight({
                    ..state,
                    sql_input: state.sql_input.with_value(sql),
                  }).sql_input,
                  focus: @app.Editor,
                }
              }
              _ => dispatch(state, key)
            }
          } else {
            dispatch(state, key)
          }
      }
    CtrlEnter =>
      match state.screen {
        @app.Connect => state
        @app.Main =>
          if state.focus == @app.Editor {
            run_query_at_cursor(state)
          } else {
            state
          }
      }
    CtrlX =>
      if state.screen == @app.Main && state.focus == @app.Editor {
        run_explain_at_cursor(state)
      } else {
        state
      }
    CtrlF =>
      if state.screen == @app.Main && state.focus == @app.Editor {
        open_search(state)
      } else {
        state
      }
    CtrlJ =>
      if state.screen == @app.Main {
        state.export_results_json()
      } else {
        state
      }
    CtrlO =>
      if state.screen == @app.Main && state.focus == @app.Editor {
        open_file_prompt(state)
      } else {
        state
      }
    F5 =>
      if state.screen == @app.Main && state.focus == @app.Editor {
        run_all_queries(state)
      } else {
        state
      }
    // Tab: advance through panels on Connect; switch panels on Main
    Tab =>
      match state.screen {
        @app.Connect =>
          match state.conn_panel {
            @app.ProfileList => switch_to_form(state, 0)
            @app.Form => {
              let total = state.conn_form.total_fields()
              if state.conn_form.focus_idx >= total - 1 {
                switch_to_profile_list(state)
              } else {
                { ..state, conn_form: state.conn_form.handle_key(key) }
              }
            }
          }
        @app.Main => {
          let next = panel_ring().set(state.focus).next().current()
          { ..state, focus: next }
        }
      }
    ShiftTab =>
      match state.screen {
        @app.Connect =>
          match state.conn_panel {
            @app.ProfileList =>
              switch_to_form(state, state.conn_form.total_fields() - 1)
            @app.Form =>
              if state.conn_form.focus_idx == 0 {
                switch_to_profile_list(state)
              } else {
                { ..state, conn_form: state.conn_form.handle_key(key) }
              }
          }
        @app.Main => {
          let next = panel_ring().set(state.focus).prev().current()
          { ..state, focus: next }
        }
      }
    // ↑/↓: navigate profile list or change DB kind in form
    Up | Down =>
      match state.screen {
        @app.Connect =>
          match state.conn_panel {
            @app.ProfileList => state.navigate_profiles(key)
            @app.Form => dispatch(state, key)
          }
        @app.Main => dispatch(state, key)
      }
    // Ctrl+S: save profile on Connect, export results on Main
    CtrlS =>
      match state.screen {
        @app.Connect => state.save_current_profile()
        @app.Main => state.export_results_csv()
      }
    // Ctrl+D: disconnect and return to Connect screen (Main screen only)
    CtrlD => if state.screen == @app.Main { state.disconnect() } else { state }
    // Ctrl+L: refresh schema tree (Main screen only)
    CtrlL =>
      if state.screen == @app.Main {
        state.refresh_schema()
      } else {
        state
      }
    // Transaction shortcuts (Main screen only)
    CtrlB =>
      if state.screen == @app.Main {
        state.begin_transaction()
      } else {
        state
      }
    CtrlM =>
      if state.screen == @app.Main {
        state.commit_transaction()
      } else {
        state
      }
    CtrlR =>
      if state.screen == @app.Main {
        state.rollback_transaction()
      } else {
        state
      }
    // d: delete selected profile (profile list only)
    Char('d') =>
      if state.screen == @app.Connect && state.conn_panel == @app.ProfileList {
        state.delete_selected_profile()
      } else {
        dispatch(state, key)
      }
    MouseClick(mx, my) =>
      if state.screen == @app.Main {
        let (cols, rows) = match @terminal.get_size() {
          Ok(s) => s
          Err(_) => (80, 24)
        }
        match panel_at(cols, rows, mx, my) {
          Some(panel) =>
            if panel == @app.Schema {
              let s2 = state.handle_schema_click(mx, my, cols, rows)
              { ..s2, focus: @app.Schema }
            } else if panel == @app.Results {
              let s2 = state.handle_results_click(mx, my, cols, rows)
              { ..s2, focus: @app.Results }
            } else {
              { ..state, focus: panel }
            }
          None => state
        }
      } else {
        state
      }
    Resize => state // redraw happens automatically on the next draw() call
    _ => dispatch(state, key)
  }
}

///|
fn should_load_schema_children(
  before : @widget.Tree,
  after : @widget.Tree,
) -> Bool {
  match (before.selected_item(), after.selected_item()) {
    (Some(prev), Some(next)) =>
      next.depth == 2 && next.expandable && next.expanded && !prev.expanded
    _ => false
  }
}

///|
/// Convert DB rows for display: replace null_value sentinels with "NULL".
fn display_rows(rows : Array[Array[String]]) -> Array[Array[String]] {
  rows.map(fn(row) {
    row.map(fn(cell) { if cell == @db.null_value { "NULL" } else { cell } })
  })
}

///|
fn null_cell_style() -> @style.Style {
  @style.Style::default().fg(@style.BrightBlack).add_modifier(@style.italic)
}

///|
fn result_cell_styles(
  rows : Array[Array[String]],
) -> Array[Array[@style.Style?]] {
  rows.map(fn(row) {
    row.map(fn(cell) {
      if cell == @db.null_value {
        Some(null_cell_style())
      } else {
        None
      }
    })
  })
}

///|
fn result_table(result : @db.QueryResult) -> @widget.Table {
  @widget.Table::new(result.columns, display_rows(result.rows)).with_cell_styles(
    result_cell_styles(result.rows),
  )
}

///|
fn switch_to_form(state : @app.AppState, focus_idx : Int) -> @app.AppState {
  {
    ..state,
    conn_panel: @app.Form,
    conn_form: { ..state.conn_form, focus_idx, },
    status: @app.connect_status(@app.Form),
  }
}

///|
fn switch_to_profile_list(state : @app.AppState) -> @app.AppState {
  {
    ..state,
    conn_panel: @app.ProfileList,
    status: @app.connect_status(@app.ProfileList),
  }
}

///|
async fn dispatch(state : @app.AppState, key : @terminal.Key) -> @app.AppState {
  match state.screen {
    @app.Connect =>
      match state.conn_panel {
        @app.ProfileList => state
        @app.Form => { ..state, conn_form: state.conn_form.handle_key(key) }
      }
    @app.Main =>
      match state.focus {
        @app.Schema =>
          if key == Right || key == Char(' ') {
            let next_tree = state.schema_tree.handle_key(key)
            let next_state = { ..state, schema_tree: next_tree }
            if should_load_schema_children(state.schema_tree, next_tree) {
              next_state.lazy_expand_schema_selection()
            } else {
              next_state
            }
          } else {
            { ..state, schema_tree: state.schema_tree.handle_key(key) }
          }
        @app.Editor =>
          if key == Up && state.sql_input.cursor_line_index() == 0 {
            let recalled = state.recall_prev_query()
            refresh_editor_highlight(recalled)
          } else if key == Down &&
            state.sql_input.cursor_line_index() ==
            state.sql_input.line_count() - 1 {
            let recalled = state.recall_next_query()
            refresh_editor_highlight(recalled)
          } else {
            let new_input = state.sql_input.handle_key(key)
            let next_state = if is_edit_key(key) {
              state.clear_query_history_nav()
            } else {
              state
            }
            refresh_editor_highlight({ ..next_state, sql_input: new_input })
          }
        @app.Results => { ..state, results: state.results.handle_key(key) }
      }
  }
}

///|
fn is_edit_key(key : @terminal.Key) -> Bool {
  match key {
    Char(_) | Enter | Backspace | Delete => true
    _ => false
  }
}

///|
fn apply_highlight(ta : @widget.TextArea) -> @widget.TextArea {
  ta.clear_highlight().with_styled_lines(sql_highlight_lines(ta.value()))
}

///|
fn refresh_editor_highlight(state : @app.AppState) -> @app.AppState {
  match state.search_input {
    Some(input) => {
      let matches = find_search_matches(state.sql_input.value(), input.value())
      let next_state = {
        ..state,
        search_matches: matches,
        search_match_index: normalize_search_match_index(
          state.search_match_index,
          matches.length(),
        ),
      }
      let focused_input = apply_search_to_textarea(
        next_state.sql_input,
        next_state,
      )
      { ..next_state, sql_input: focused_input }
    }
    None => { ..state, sql_input: apply_highlight(state.sql_input) }
  }
}

///|
fn open_search(state : @app.AppState) -> @app.AppState {
  let input = match state.search_input {
    Some(existing) => existing.focused(true)
    None => @widget.Input::new().focused(true)
  }
  refresh_editor_highlight({
    ..state,
    search_input: Some(input),
    search_editing: true,
  })
}

///|
fn close_search(state : @app.AppState) -> @app.AppState {
  {
    ..refresh_editor_highlight({
      ..state,
      search_input: None,
      search_matches: [],
      search_match_index: 0,
      search_editing: false,
    }),
    search_input: None,
    search_matches: [],
    search_match_index: 0,
    search_editing: false,
  }
}

///|
fn open_file_prompt(state : @app.AppState) -> @app.AppState {
  {
    ..state,
    file_prompt: Some(@widget.Input::new().focused(true)),
    status: "Open SQL file: type a path and press Enter",
    show_error: false,
  }
}

///|
fn handle_file_prompt_key(
  state : @app.AppState,
  key : @terminal.Key,
) -> @app.AppState {
  match key {
    Esc =>
      {
        ..state,
        file_prompt: None,
        status: "Load SQL canceled",
        show_error: false,
      }
    Enter =>
      match state.file_prompt {
        Some(input) =>
          match state.load_sql_file(input.value()) {
            Ok(text) =>
              {
                ..refresh_editor_highlight({
                  ..state,
                  file_prompt: None,
                  sql_input: state.sql_input.with_value(text),
                }),
                file_prompt: None,
                status: "Loaded SQL from \{input.value()}",
                show_error: false,
              }
            Err(msg) =>
              {
                ..state,
                file_prompt: None,
                status: "Error: \{msg}",
                show_error: false,
              }
          }
        None => state
      }
    _ =>
      match state.file_prompt {
        Some(input) =>
          { ..state, file_prompt: Some(input.handle_key(key).focused(true)) }
        None => state
      }
  }
}

///|
fn handle_search_edit_key(
  state : @app.AppState,
  key : @terminal.Key,
) -> @app.AppState {
  match key {
    Esc => close_search(state)
    Enter =>
      match state.search_input {
        Some(input) =>
          {
            ..refresh_editor_highlight({
              ..state,
              search_input: Some(input.focused(false)),
              search_editing: false,
            }),
            search_editing: false,
          }
        None => state
      }
    _ =>
      match state.search_input {
        Some(input) => {
          let next_input = input.handle_key(key).focused(true)
          let next_state = refresh_editor_highlight({
            ..state,
            search_input: Some(next_input),
            search_match_index: 0,
          })
          move_search_match_to_current(next_state)
        }
        None => state
      }
  }
}

///|
fn move_search_match(state : @app.AppState, delta : Int) -> @app.AppState {
  let count = state.search_matches.length()
  if count == 0 {
    return state
  }
  let idx = (state.search_match_index + delta + count) % count
  move_search_match_to_current({ ..state, search_match_index: idx })
}

///|
fn move_search_match_to_current(state : @app.AppState) -> @app.AppState {
  if state.search_matches.length() == 0 {
    return refresh_editor_highlight(state)
  }
  let idx = normalize_search_match_index(
    state.search_match_index,
    state.search_matches.length(),
  )
  let m = state.search_matches[idx]
  refresh_editor_highlight({
    ..state,
    search_match_index: idx,
    sql_input: state.sql_input.with_cursor(m.line, m.col),
  })
}

///|
fn apply_search_to_textarea(
  ta : @widget.TextArea,
  state : @app.AppState,
) -> @widget.TextArea {
  let active_idx = if state.search_matches.length() == 0 {
    -1
  } else {
    normalize_search_match_index(
      state.search_match_index,
      state.search_matches.length(),
    )
  }
  ta
  .clear_highlight()
  .with_styled_lines(
    highlight_search_matches(
      split_lines(ta.value()),
      state.search_matches,
      active_idx,
    ),
  )
}

///|
fn highlight_search_matches(
  lines : Array[String],
  matches : Array[@app.SearchMatch],
  active_idx : Int,
) -> Array[Array[(String, @style.Style)]] {
  let base = sql_highlight_lines(lines.join("\n"))
  let highlighted : Array[Array[(String, @style.Style)]] = []
  for i, line in lines {
    let line_matches : Array[@app.SearchMatch] = []
    for match_idx, m in matches {
      if m.line == i {
        line_matches.push({
          ..m,
          length: if match_idx == active_idx {
            -m.length
          } else {
            m.length
          },
        })
      }
    }
    highlighted.push(apply_line_search_styles(line, base[i], line_matches))
  }
  highlighted
}

///|
fn apply_line_search_styles(
  line : String,
  segments : Array[(String, @style.Style)],
  matches : Array[@app.SearchMatch],
) -> Array[(String, @style.Style)] {
  if matches.length() == 0 {
    return segments
  }
  let styles = line_styles(line, segments)
  for m in matches {
    let match_len = if m.length < 0 { -m.length } else { m.length }
    let style = if m.length < 0 {
      active_search_style()
    } else {
      search_style()
    }
    let end = min_int(m.col + match_len, styles.length())
    for i = m.col; i < end; i = i + 1 {
      styles[i] = style
    }
  }
  if line == "" {
    return []
  }
  let result : Array[(String, @style.Style)] = []
  let mut start = 0
  let mut current = styles[0]
  for i = 1; i < line.length(); i = i + 1 {
    if styles[i] != current {
      result.push((line[start:i].to_string(), current))
      start = i
      current = styles[i]
    }
  }
  result.push((line[start:].to_string(), current))
  result
}

///|
fn line_styles(
  line : String,
  segments : Array[(String, @style.Style)],
) -> Array[@style.Style] {
  let styles : Array[@style.Style] = []
  for _, segment in segments {
    let (text, style) = segment
    for _ in 0..<text.length() {
      styles.push(style)
    }
  }
  while styles.length() < line.length() {
    styles.push(@style.Style::default())
  }
  styles
}

///|
fn search_style() -> @style.Style {
  @style.Style::default().bg(@style.BrightBlack).fg(@style.White)
}

///|
fn active_search_style() -> @style.Style {
  @style.Style::default().bg(@style.Yellow).fg(@style.Black)
}

///|
fn min_int(a : Int, b : Int) -> Int {
  if a < b {
    a
  } else {
    b
  }
}

///|
fn normalize_search_match_index(idx : Int, count : Int) -> Int {
  if count <= 0 {
    0
  } else if idx < 0 {
    0
  } else if idx >= count {
    count - 1
  } else {
    idx
  }
}

///|
fn find_search_matches(
  text : String,
  query : String,
) -> Array[@app.SearchMatch] {
  if query == "" {
    return []
  }
  let matches : Array[@app.SearchMatch] = []
  let lines = split_lines(text)
  for line_idx, line in lines {
    let qlen = query.length()
    let mut col = 0
    while col + qlen <= line.length() {
      if line[col:col + qlen].to_string() == query {
        matches.push({ line: line_idx, col, length: qlen })
      }
      col += 1
    }
  }
  matches
}

///|
fn split_lines(text : String) -> Array[String] {
  if text == "" {
    return [""]
  }
  let lines : Array[String] = []
  let mut start = 0
  for i = 0; i < text.length(); i = i + 1 {
    if text[i] == '\n' {
      lines.push(text[start:i].to_string())
      start = i + 1
    }
  }
  lines.push(text[start:].to_string())
  lines
}

///|
fn panel_ring() -> @honeytui.FocusRing[@app.Panel] {
  @honeytui.FocusRing::new([@app.Schema, @app.Editor, @app.Results])
}

///|
fn panel_at(cols : Int, rows : Int, mx : Int, my : Int) -> @app.Panel? {
  if my == 1 || my == rows {
    return None
  }
  let content_h = rows - 2
  let schema_w = cols * @app.schema_width_percent / 100
  if mx <= schema_w {
    return Some(@app.Schema)
  }
  let editor_h = content_h * @app.editor_height_percent / 100
  if my < 2 + editor_h {
    return Some(@app.Editor)
  }
  Some(@app.Results)
}

///|
fn run_query_at_cursor(state : @app.AppState) -> @app.AppState {
  let text = state.sql_input.value()
  let pos = state.sql_input.cursor_pos()
  let (stmt, _, _) = current_statement(text, pos)
  start_single_query(state, stmt)
}

///|
fn explain_prefix(kind_idx : Int) -> String {
  if kind_idx == 1 {
    "EXPLAIN ANALYZE "
  } else {
    "EXPLAIN "
  }
}

///|
fn run_explain_at_cursor(state : @app.AppState) -> @app.AppState {
  let text = state.sql_input.value()
  let pos = state.sql_input.cursor_pos()
  let (stmt, _, _) = current_statement(text, pos)
  if stmt == "" {
    return state
  }
  start_single_query(state, explain_prefix(state.conn_form.kind_idx) + stmt)
}

///|
fn start_single_query(state : @app.AppState, stmt : String) -> @app.AppState {
  if stmt == "" {
    return state
  }
  let state = state.record_query_history(stmt)
  match state.conn {
    None => { ..state, status: "Error: not connected", show_error: false }
    Some(conn) => {
      let started = @bench.monotonic_clock_start()
      ignore(conn.async_start(stmt))
      {
        ..state,
        running_query: Some(@app.RunningQuery::Single(sql=stmt, started~)),
        cancel_requested: false,
        status: "Running query... Ctrl+C to cancel",
        show_error: false,
      }
    }
  }
}

///|
fn run_all_queries(state : @app.AppState) -> @app.AppState {
  let text = state.sql_input.value()
  let stmts = all_statements(text)
  if stmts.length() == 0 {
    return state
  }
  let state = state.record_query_history(text.trim().to_string())
  match state.conn {
    None => { ..state, status: "Error: not connected", show_error: false }
    Some(conn) => {
      let started = @bench.monotonic_clock_start()
      let first_sql = stmts[0]
      let total = stmts.length()
      ignore(conn.async_start(first_sql))
      {
        ..state,
        running_query: Some(
          @app.RunningQuery::RunAll(
            stmts~,
            current_idx=0,
            started~,
            partial_results=@widget.Table::new([], []),
            total_rows=0,
            total_affected=0,
            has_affected=false,
            stmt_count=0,
            in_txn=state.in_transaction,
          ),
        ),
        cancel_requested: false,
        status: "Running statement 1/\{total}... Ctrl+C to cancel",
        show_error: false,
      }
    }
  }
}

///|
fn query_result_status(result : @db.QueryResult) -> String {
  match result.affected_rows {
    Some(n) => affected_rows_status(n)
    None => {
      let n = result.rows.length()
      if n == 1 {
        "1 row fetched"
      } else {
        "\{n} rows fetched"
      }
    }
  }
}

///|
/// Poll the backend for async query completion.
/// Handles Single and RunAll variants of RunningQuery.
fn poll_running_query(state : @app.AppState) -> @app.AppState {
  let rq = match state.running_query {
    Some(rq) => rq
    None => return state
  }
  let conn = match state.conn {
    Some(c) => c
    None => return { ..state, running_query: None }
  }
  let poll_status = conn.async_poll()
  // 1 = still running
  if poll_status == 1 {
    return state
  }
  match rq {
    Single(sql~, started~) => finish_single(state, conn, sql, started)
    RunAll(
      stmts~,
      current_idx=idx,
      started~,
      partial_results~,
      total_rows~,
      total_affected~,
      has_affected~,
      stmt_count~,
      in_txn~
    ) =>
      finish_run_all_step(
        state, conn, stmts, idx, started, partial_results, total_rows, total_affected,
        has_affected, stmt_count, in_txn,
      )
  }
}

///|
/// Finish a single async query (poll_status != 1).
fn finish_single(
  state : @app.AppState,
  conn : &@db.DbConn,
  sql : String,
  started : @bench.Timestamp,
) -> @app.AppState {
  let is_write = @db.is_write_statement(sql)
  match conn.async_result(is_write) {
    Ok(result) =>
      if state.cancel_requested {
        {
          ..state,
          running_query: None,
          cancel_requested: false,
          status: with_execution_time(
            "Query cancelled",
            @bench.monotonic_clock_end(started),
          ),
          show_error: false,
        }
      } else {
        let tbl = result_table(result)
        let next = {
          ..state,
          results: tbl,
          running_query: None,
          cancel_requested: false,
          status: with_execution_time(
            query_result_status(result),
            @bench.monotonic_clock_end(started),
          ),
          show_error: false,
        }
        next.sync_txn_flag_for_stmt(sql)
      }
    Err(msg) => {
      let cancelled = state.cancel_requested
      let lost = !cancelled && is_connection_lost(msg)
      let status = if cancelled {
        "Query cancelled"
      } else if lost {
        "Connection lost — reconnecting..."
      } else {
        "Error: \{msg}"
      }
      {
        ..state,
        running_query: None,
        cancel_requested: false,
        conn_lost: lost,
        status: with_execution_time(status, @bench.monotonic_clock_end(started)),
        show_error: false,
      }
    }
  }
}

///|
/// Handle completion of one step in a run-all sequence, then either advance
/// to the next statement or finish.
fn finish_run_all_step(
  state : @app.AppState,
  conn : &@db.DbConn,
  stmts : Array[String],
  idx : Int,
  started : @bench.Timestamp,
  partial_results : @widget.Table,
  total_rows : Int,
  total_affected : Int,
  has_affected : Bool,
  stmt_count : Int,
  in_txn : Bool,
) -> @app.AppState {
  let sql = stmts[idx]
  let is_write = @db.is_write_statement(sql)
  match conn.async_result(is_write) {
    Ok(_) if state.cancel_requested =>
      {
        ..state,
        in_transaction: in_txn,
        results: partial_results,
        running_query: None,
        cancel_requested: false,
        status: with_execution_time(
          "Cancelled after \{stmt_count}/\{stmts.length()} statements",
          @bench.monotonic_clock_end(started),
        ),
        show_error: false,
      }
    Ok(result) => {
      let new_partial = result_table(result)
      let new_total_rows = total_rows + result.rows.length()
      let mut new_total_affected = total_affected
      let mut new_has_affected = has_affected
      match result.affected_rows {
        Some(n) => {
          new_total_affected = new_total_affected + n
          new_has_affected = true
        }
        None => ()
      }
      let new_stmt_count = stmt_count + 1
      let mut new_in_txn = in_txn
      if @app.stmt_opens_txn(sql) {
        new_in_txn = true
      } else if @app.stmt_closes_txn(sql) {
        new_in_txn = false
      }
      let next_idx = idx + 1
      if state.cancel_requested || next_idx >= stmts.length() {
        // All done (or cancelled between statements)
        let status = if state.cancel_requested {
          "Cancelled after \{new_stmt_count}/\{stmts.length()} statements"
        } else {
          run_all_status(
            new_stmt_count, new_total_rows, new_total_affected, new_has_affected,
          )
        }
        {
          ..state,
          in_transaction: new_in_txn,
          results: new_partial,
          running_query: None,
          cancel_requested: false,
          status: with_execution_time(
            status,
            @bench.monotonic_clock_end(started),
          ),
          show_error: false,
        }
      } else {
        // Start the next statement
        let next_sql = stmts[next_idx]
        if conn.async_start(next_sql) {
          let total = stmts.length()
          let display_idx = next_idx + 1
          {
            ..state,
            in_transaction: new_in_txn,
            running_query: Some(
              @app.RunningQuery::RunAll(
                stmts~,
                current_idx=next_idx,
                started~,
                partial_results=new_partial,
                total_rows=new_total_rows,
                total_affected=new_total_affected,
                has_affected=new_has_affected,
                stmt_count=new_stmt_count,
                in_txn=new_in_txn,
              ),
            ),
            status: "Running statement \{display_idx}/\{total}... Ctrl+C to cancel",
          }
        } else {
          // Can't start async — shouldn't happen mid-sequence, treat as done
          let status = run_all_status(
            new_stmt_count, new_total_rows, new_total_affected, new_has_affected,
          )
          {
            ..state,
            in_transaction: new_in_txn,
            results: new_partial,
            running_query: None,
            cancel_requested: false,
            status: with_execution_time(
              status,
              @bench.monotonic_clock_end(started),
            ),
            show_error: false,
          }
        }
      }
    }
    Err(msg) => {
      let cancelled = state.cancel_requested
      let lost = !cancelled && is_connection_lost(msg)
      let status = if cancelled {
        "Cancelled after \{stmt_count}/\{stmts.length()} statements"
      } else if lost {
        "Connection lost — reconnecting..."
      } else {
        "Error: \{msg}"
      }
      {
        ..state,
        in_transaction: in_txn,
        running_query: None,
        cancel_requested: false,
        conn_lost: lost,
        status: with_execution_time(status, @bench.monotonic_clock_end(started)),
        show_error: false,
      }
    }
  }
}

///|
fn run_all_status(
  stmt_count : Int,
  total_rows : Int,
  total_affected : Int,
  has_affected_rows : Bool,
) -> String {
  if total_rows == 0 && has_affected_rows {
    if stmt_count == 1 {
      affected_rows_status(total_affected)
    } else {
      "\{stmt_count} statements executed, \{total_affected} rows affected"
    }
  } else if has_affected_rows {
    "\{stmt_count} statements executed, \{total_rows} row(s) fetched, \{total_affected} rows affected"
  } else if stmt_count == 1 {
    "\{total_rows} row(s)"
  } else {
    "\{stmt_count} statements executed, \{total_rows} row(s) total"
  }
}

///|
fn affected_rows_status(n : Int) -> String {
  if n == 1 {
    "1 row affected"
  } else {
    "\{n} rows affected"
  }
}

///|
fn with_execution_time(status : String, elapsed_us : Double) -> String {
  let elapsed_ms = ((elapsed_us + 500.0) / 1000.0).to_int()
  "\{status} (\{elapsed_ms} ms)"
}

///|
/// Returns true when an error message indicates that the database connection
/// was lost (as opposed to a SQL or application-level error).
fn is_connection_lost(msg : String) -> Bool {
  let u = msg.to_upper()
  u.contains("SERVER CLOSED THE CONNECTION") ||
  u.contains("LOST CONNECTION") ||
  u.contains("SERVER HAS GONE AWAY") ||
  u.contains("BROKEN PIPE") ||
  u.contains("CONNECTION RESET") ||
  u.contains("NO CONNECTION TO THE SERVER") ||
  u.contains("CONNECTION CLOSED") ||
  u.contains("CONNECTION REFUSED")
}

///|
fn find_statement_boundaries(text : String) -> Array[Int] {
  let len = text.length()
  let boundaries : Array[Int] = [0]
  let mut i = 0
  let mut mode = Normal
  while i < len {
    match mode {
      Normal =>
        if starts_with_two(text, i, '-'.to_int(), '-'.to_int()) {
          mode = LineComment
          i += 2
        } else if starts_with_two(text, i, '/'.to_int(), '*'.to_int()) {
          mode = BlockComment
          i += 2
        } else if text[i] == '\'' {
          mode = StringLiteral
          i += 1
        } else if text[i] == '"' {
          mode = DoubleQuotedIdentifier
          i += 1
        } else if text[i] == '`' {
          mode = BacktickIdentifier
          i += 1
        } else {
          if text[i] == ';' {
            boundaries.push(i + 1)
          }
          i += 1
        }
      StringLiteral =>
        if text[i] == '\'' {
          if i + 1 < len && text[i + 1] == '\'' {
            i += 2
          } else {
            mode = Normal
            i += 1
          }
        } else {
          i += 1
        }
      DoubleQuotedIdentifier =>
        if text[i] == '"' {
          if i + 1 < len && text[i + 1] == '"' {
            i += 2
          } else {
            mode = Normal
            i += 1
          }
        } else {
          i += 1
        }
      BacktickIdentifier =>
        if text[i] == '`' {
          if i + 1 < len && text[i + 1] == '`' {
            i += 2
          } else {
            mode = Normal
            i += 1
          }
        } else {
          i += 1
        }
      BlockComment =>
        if starts_with_two(text, i, '*'.to_int(), '/'.to_int()) {
          mode = Normal
          i += 2
        } else {
          i += 1
        }
      LineComment => {
        if text[i] == '\n' {
          mode = Normal
        }
        i += 1
      }
    }
  }
  boundaries.push(len)
  boundaries
}

///|
fn all_statements(text : String) -> Array[String] {
  if text.length() == 0 {
    return []
  }
  let boundaries = find_statement_boundaries(text)
  let len = text.length()
  let result = []
  for i = 0; i + 1 < boundaries.length(); i = i + 1 {
    let s = boundaries[i]
    let e = boundaries[i + 1]
    let raw_end = if e > 0 && e <= len && text[e - 1] == ';' {
      e - 1
    } else {
      e
    }
    let stmt = text[s:raw_end].to_string().trim().to_string()
    if stmt != "" {
      result.push(stmt)
    }
  }
  result
}

///|
fn current_statement(text : String, cursor_pos : Int) -> (String, Int, Int) {
  let len = text.length()
  if len == 0 {
    return ("", 0, 0)
  }
  let boundaries = find_statement_boundaries(text)
  let mut seg_start = 0
  let mut seg_end = len
  for i = 0; i + 1 < boundaries.length(); i = i + 1 {
    let s = boundaries[i]
    let e = boundaries[i + 1]
    if cursor_pos >= s && cursor_pos <= e {
      seg_start = s
      seg_end = e
      break
    }
  }
  let raw_end = if seg_end < len && text[seg_end - 1] == ';' {
    seg_end - 1
  } else {
    seg_end
  }
  let raw = text[seg_start:raw_end].to_string()
  let trimmed = raw.trim().to_string()
  if trimmed == "" {
    return ("", seg_start, seg_start)
  }
  let trim_start = seg_start + leading_spaces(raw)
  let trim_end = trim_start + trimmed.length()
  (trimmed, trim_start, trim_end)
}

///|
fn leading_spaces(s : String) -> Int {
  let mut i = 0
  for c in s.iter() {
    if c == ' ' || c == '\t' || c == '\n' || c == '\r' {
      i = i + 1
    } else {
      break
    }
  }
  i
}
