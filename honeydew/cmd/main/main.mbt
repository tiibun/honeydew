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
        let key = terminal.read_key()
        state = handle_key(state, key)
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
  match key {
    CtrlC | CtrlQ => { ..state, should_quit: true }
    Char('?') => { ..state, show_help: true }
    Char('e') =>
      if state.screen == @app.Main && state.status.contains("Error") {
        { ..state, show_error: true }
      } else {
        dispatch(state, key)
      }
    Char('y') =>
      if state.screen == @app.Main && state.focus == @app.Results {
        state.copy_selected_result_cell()
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
        @app.Main => dispatch(state, key)
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
fn dispatch(state : @app.AppState, key : @terminal.Key) -> @app.AppState {
  match state.screen {
    @app.Connect =>
      match state.conn_panel {
        @app.ProfileList => state
        @app.Form => { ..state, conn_form: state.conn_form.handle_key(key) }
      }
    @app.Main =>
      match state.focus {
        @app.Schema =>
          { ..state, schema_tree: state.schema_tree.handle_key(key) }
        @app.Editor =>
          if key == Up && state.sql_input.cursor_line_index() == 0 {
            let recalled = state.recall_prev_query()
            { ..recalled, sql_input: apply_highlight(recalled.sql_input) }
          } else if key == Down &&
            state.sql_input.cursor_line_index() ==
            state.sql_input.line_count() - 1 {
            let recalled = state.recall_next_query()
            { ..recalled, sql_input: apply_highlight(recalled.sql_input) }
          } else {
            let new_input = state.sql_input.handle_key(key)
            let highlighted = apply_highlight(new_input)
            let next_state = if is_edit_key(key) {
              state.clear_query_history_nav()
            } else {
              state
            }
            { ..next_state, sql_input: highlighted }
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
fn panel_ring() -> @honeytui.FocusRing[@app.Panel] {
  @honeytui.FocusRing::new([@app.Schema, @app.Editor, @app.Results])
}

///|
fn panel_at(cols : Int, rows : Int, mx : Int, my : Int) -> @app.Panel? {
  if my == 1 || my == rows {
    return None
  }
  let content_h = rows - 2
  let schema_w = cols * 28 / 100
  if mx <= schema_w {
    return Some(@app.Schema)
  }
  let editor_h = content_h * 35 / 100
  if my < 2 + editor_h {
    return Some(@app.Editor)
  }
  Some(@app.Results)
}

///|
async fn run_query_at_cursor(state : @app.AppState) -> @app.AppState {
  let text = state.sql_input.value()
  let pos = state.sql_input.cursor_pos()
  let (stmt, _, _) = current_statement(text, pos)
  if stmt == "" {
    return state
  }
  let state = state.record_query_history(stmt)
  match state.conn {
    None => { ..state, status: "Error: not connected", show_error: false }
    Some(conn) => {
      let started = @bench.monotonic_clock_start()
      match (conn.query(stmt) catch { err => Err(err.to_string()) }) {
        Ok(result) => {
          let tbl = @widget.Table::new(result.columns, result.rows)
          {
            ..state,
            results: tbl,
            status: with_execution_time(
              query_result_status(result),
              @bench.monotonic_clock_end(started),
            ),
            show_error: false,
          }
        }
        Err(msg) =>
          {
            ..state,
            status: with_execution_time(
              "Error: \{msg}",
              @bench.monotonic_clock_end(started),
            ),
            show_error: false,
          }
      }
    }
  }
}

///|
async fn run_all_queries(state : @app.AppState) -> @app.AppState {
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
      let mut last_result = @widget.Table::new([], [])
      let mut total_rows = 0
      let mut total_affected = 0
      let mut has_affected_rows = false
      let mut stmt_count = 0
      let mut error : String? = None
      for stmt in stmts {
        match (conn.query(stmt) catch { err => Err(err.to_string()) }) {
          Ok(result) => {
            last_result = @widget.Table::new(result.columns, result.rows)
            total_rows = total_rows + result.rows.length()
            match result.affected_rows {
              Some(n) => {
                total_affected = total_affected + n
                has_affected_rows = true
              }
              None => ()
            }
            stmt_count = stmt_count + 1
          }
          Err(msg) => {
            error = Some(msg)
            break
          }
        }
      }
      match error {
        Some(msg) =>
          {
            ..state,
            status: with_execution_time(
              "Error: \{msg}",
              @bench.monotonic_clock_end(started),
            ),
            show_error: false,
          }
        None => {
          let msg = run_all_status(
            stmt_count, total_rows, total_affected, has_affected_rows,
          )
          {
            ..state,
            results: last_result,
            status: with_execution_time(
              msg,
              @bench.monotonic_clock_end(started),
            ),
            show_error: false,
          }
        }
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
fn find_statement_boundaries(text : String) -> Array[Int] {
  let len = text.length()
  let boundaries : Array[Int] = [0]
  let mut in_quote = false
  for i = 0; i < len; i = i + 1 {
    let c = text[i]
    if c == '\'' {
      in_quote = !in_quote
    } else if c == ';' && !in_quote {
      boundaries.push(i + 1)
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
