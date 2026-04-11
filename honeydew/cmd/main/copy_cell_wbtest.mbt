///|
async test "handle_key reports when there is no selected cell to copy" {
  @async.with_task_group(async fn(group) {
    let state = {
      ..@app.AppState::new(group),
      screen: @app.Main,
      focus: @app.Results,
    }
    let next = handle_key(state, Char('y'))
    assert_eq(next.status, "No cell selected")
  })
}
