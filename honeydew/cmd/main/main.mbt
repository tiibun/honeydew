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
      if state.screen == @app.Connect {
        { ..state, should_quit: true }
      } else {
        dispatch(state, key)
      }
    Enter =>
      match state.screen {
        @app.Connect => state.do_connect()
        @app.Main => dispatch(state, key) // Enter = newline in editor
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
    Tab =>
      match state.screen {
        @app.Connect => { ..state, conn_form: state.conn_form.handle_key(key) }
        @app.Main => {
          let next = panel_ring().set(state.focus).next().current()
          { ..state, focus: next }
        }
      }
    ShiftTab =>
      match state.screen {
        @app.Connect => { ..state, conn_form: state.conn_form.handle_key(key) }
        @app.Main => {
          let next = panel_ring().set(state.focus).prev().current()
          { ..state, focus: next }
        }
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
    _ => dispatch(state, key)
  }
}

///|
fn dispatch(state : @app.AppState, key : @terminal.Key) -> @app.AppState {
  match state.screen {
    @app.Connect => { ..state, conn_form: state.conn_form.handle_key(key) }
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
/// Recompute and apply the current-statement highlight on a TextArea.
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
/// The canonical focus order for the main screen panels.
fn panel_ring() -> @honeytui.FocusRing[@app.Panel] {
  @honeytui.FocusRing::new([@app.Schema, @app.Editor, @app.Results])
}

///|
/// Given terminal size and mouse click position, return which Panel was clicked.
/// Matches the layout computed by render_main:
///   row 1           = menu bar
///   row 2..rows-1   = main area
///   row rows        = status bar
///   col 1..schema_w = Schema, else right pane
///   right top 35%   = Editor, bottom 65% = Results
fn panel_at(cols : Int, rows : Int, mx : Int, my : Int) -> @app.Panel? {
  if my == 1 || my == rows {
    return None // menu bar or status bar
  }
  let content_h = rows - 2 // rows available for main area
  let schema_w = cols * 28 / 100
  if mx <= schema_w {
    return Some(@app.Schema)
  }
  // Right pane: content rows start at row 2
  let editor_h = content_h * 35 / 100
  if my < 2 + editor_h {
    return Some(@app.Editor)
  }
  Some(@app.Results)
}

///|
/// Execute the SQL statement at the cursor position.
async fn run_query_at_cursor(state : @app.AppState) -> @app.AppState {
  let text = state.sql_input.value()
  let pos = state.sql_input.cursor_pos()
  let (stmt, _, _) = current_statement(text, pos)
  if stmt == "" {
    return state
  }
  match state.conn {
    None => { ..state, status: "エラー: 接続されていません" }
    Some(conn) =>
      match conn.query(stmt) {
        Ok(result) => {
          let tbl = @widget.Table::new(result.columns, result.rows)
          let n = result.rows.length()
          let msg = if n == 1 { "1 行取得" } else { "\{n} 行取得" }
          { ..state, results: tbl, status: msg }
        }
        Err(msg) => { ..state, status: "エラー: \{msg}" }
      }
  }
}

///|
/// Find the `;`-delimited SQL statement that contains `cursor_pos`.
/// Returns `(statement, start_char, end_char)` where `end_char` is exclusive.
/// Ignores `;` inside single-quoted string literals.
/// Leading/trailing whitespace is stripped from the returned statement.
fn current_statement(text : String, cursor_pos : Int) -> (String, Int, Int) {
  let len = text.length()
  if len == 0 {
    return ("", 0, 0)
  }
  // Collect statement boundaries (positions just after each ';')
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
  // Find which segment contains cursor_pos
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
  // Strip the trailing ';' from segment end if present
  let raw_end = if seg_end < len && text[seg_end - 1] == ';' {
    seg_end - 1
  } else {
    seg_end
  }
  let raw = text[seg_start:raw_end].to_string()
  // Trim leading/trailing whitespace
  let trimmed = raw.trim().to_string()
  if trimmed == "" {
    return ("", seg_start, seg_start)
  }
  // Compute trimmed start/end within the original text
  let trim_start = seg_start + leading_spaces(raw)
  let trim_end = trim_start + trimmed.length()
  (trimmed, trim_start, trim_end)
}

///|
/// Count leading whitespace characters in a string.
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
/// Convert an absolute character position in `text` to a 0-indexed line number.
fn char_pos_to_line(text : String, char_pos : Int) -> Int {
  let mut line = 0
  for i = 0; i < char_pos && i < text.length(); i = i + 1 {
    if text[i] == '\n' {
      line = line + 1
    }
  }
  line
}
