///|
async test "handle_key CtrlB on Main screen calls begin_transaction (no conn → error)" {
  @async.with_task_group(async fn(group) {
    let state = {
      ..@app.AppState::new(group),
      screen: @app.Main,
      focus: @app.Editor,
    }
    let s = handle_key(state, CtrlB)
    assert_eq(s.in_transaction, false)
    assert_true(s.status.contains("Error"))
  })
}

///|
async test "handle_key CtrlR on Main screen calls rollback_transaction (no conn → error)" {
  @async.with_task_group(async fn(group) {
    let state = {
      ..@app.AppState::new(group),
      screen: @app.Main,
      focus: @app.Editor,
    }
    let s = handle_key(state, CtrlR)
    assert_eq(s.in_transaction, false)
    assert_true(s.status.contains("Error"))
  })
}

///|
async test "handle_key CtrlM on Main screen calls commit_transaction (no conn → error)" {
  @async.with_task_group(async fn(group) {
    let state = {
      ..@app.AppState::new(group),
      screen: @app.Main,
      focus: @app.Editor,
    }
    let s = handle_key(state, CtrlM)
    assert_eq(s.in_transaction, false)
    assert_true(s.status.contains("Error"))
  })
}

///|
async test "handle_key CtrlB on Connect screen does nothing" {
  @async.with_task_group(async fn(group) {
    let state = { ..@app.AppState::new(group), screen: @app.Connect }
    let s = handle_key(state, CtrlB)
    assert_eq(s.in_transaction, false)
    assert_true(s.screen == @app.Connect)
  })
}
