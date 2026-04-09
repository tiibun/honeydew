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
  match key {
    CtrlC | CtrlQ => { ..state, should_quit: true }
    Char('?') => { ..state, show_help: true }
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
    // Tab: advance through panels on Connect; switch panels on Main
    Tab =>
      match state.screen {
        @app.Connect =>
          match state.conn_panel {
            @app.ProfileList =>
              {
                ..state,
                conn_panel: @app.Form,
                conn_form: { ..state.conn_form, focus_idx: 0 },
                status: @app.connect_status(@app.Form),
              }
            @app.Form => {
              let total = state.conn_form.total_fields()
              if state.conn_form.focus_idx >= total - 1 {
                {
                  ..state,
                  conn_panel: @app.ProfileList,
                  status: @app.connect_status(@app.ProfileList),
                }
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
              {
                ..state,
                conn_panel: @app.Form,
                conn_form: {
                  ..state.conn_form,
                  focus_idx: state.conn_form.total_fields() - 1,
                },
                status: @app.connect_status(@app.Form),
              }
            @app.Form =>
              if state.conn_form.focus_idx == 0 {
                {
                  ..state,
                  conn_panel: @app.ProfileList,
                  status: @app.connect_status(@app.ProfileList),
                }
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
    // Ctrl+S: save current form as a profile
    CtrlS =>
      if state.screen == @app.Connect {
        state.save_current_profile()
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
          Some(panel) => { ..state, focus: panel }
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
          { ..state, schema_list: state.schema_list.handle_key(key) }
        @app.Editor => {
          let new_input = state.sql_input.handle_key(key)
          let highlighted = apply_highlight(new_input)
          { ..state, sql_input: highlighted }
        }
        @app.Results => { ..state, results: state.results.handle_key(key) }
      }
  }
}

///|
fn apply_highlight(ta : @widget.TextArea) -> @widget.TextArea {
  let text = ta.value()
  let pos = ta.cursor_pos()
  let (_, start_char, end_char) = current_statement(text, pos)
  if start_char == end_char {
    ta.clear_highlight()
  } else {
    let start_line = char_pos_to_line(text, start_char)
    let end_line = char_pos_to_line(text, end_char - 1)
    ta.with_highlight(start_line, end_line)
  }
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
  match state.conn {
    None => { ..state, status: "Error: not connected" }
    Some(conn) =>
      match conn.query(stmt) {
        Ok(result) => {
          let tbl = @widget.Table::new(result.columns, result.rows)
          let n = result.rows.length()
          let msg = if n == 1 { "1 row fetched" } else { "\{n} rows fetched" }
          { ..state, results: tbl, status: msg }
        }
        Err(msg) => { ..state, status: "Error: \{msg}" }
      }
  }
}

///|
fn current_statement(text : String, cursor_pos : Int) -> (String, Int, Int) {
  let len = text.length()
  if len == 0 {
    return ("", 0, 0)
  }
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

///|
fn char_pos_to_line(text : String, char_pos : Int) -> Int {
  let mut line = 0
  for i = 0; i < char_pos && i < text.length(); i = i + 1 {
    if text[i] == '\n' {
      line = line + 1
    }
  }
  line
}
