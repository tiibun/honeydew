///|
async test "handle_key exports results on CtrlS from main screen" {
  @async.with_task_group(async fn(group) {
    let state = { ..@app.AppState::new(group), screen: @app.Main }
    let next = handle_key(state, @terminal.CtrlS)
    assert_eq(next.status, "No results to export")
  })
}
