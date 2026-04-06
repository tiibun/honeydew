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
  // Close help overlay on any key when it is open (? or Esc close it, others are swallowed)
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
        @app.Main =>
          if state.focus == @app.Editor {
            run_query(state)
          } else {
            dispatch(state, key)
          }
      }
    Tab =>
      match state.screen {
        @app.Connect => { ..state, conn_form: state.conn_form.handle_key(key) }
        @app.Main => cycle_focus(state)
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
        @app.Editor => { ..state, sql_input: state.sql_input.handle_key(key) }
        @app.Results => { ..state, results: state.results.handle_key(key) }
      }
  }
}

///|
fn cycle_focus(state : @app.AppState) -> @app.AppState {
  let next = match state.focus {
    @app.Schema => @app.Editor
    @app.Editor => @app.Results
    @app.Results => @app.Schema
  }
  { ..state, focus: next }
}

///|
async fn run_query(state : @app.AppState) -> @app.AppState {
  let sql = state.sql_input.value()
  if sql == "" {
    return state
  }
  match state.conn {
    None => { ..state, status: "接続されていません" }
    Some(conn) =>
      match conn.query(sql) {
        Ok(result) => {
          let tbl = @widget.Table::new(result.columns, result.rows)
          let n = result.rows.length()
          { ..state, results: tbl, status: "\{n}行取得" }
        }
        Err(msg) => { ..state, status: "エラー: \{msg}" }
      }
  }
}
