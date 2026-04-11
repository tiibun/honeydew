///|
async test "run_query_at_cursor records executed statement" {
  @async.with_task_group(async fn(group) {
    let state = {
      ..@app.AppState::new(group),
      screen: @app.Main,
      focus: @app.Editor,
      sql_input: @widget.TextArea::new().with_value("SELECT 1"),
    }
    let next = run_query_at_cursor(state)
    assert_eq(next.query_history, ["SELECT 1"])
  })
}
