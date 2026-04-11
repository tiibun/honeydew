///|
async test "handle_key recalls previous query and restores draft" {
  @async.with_task_group(async fn(group) {
    let state = {
      ..@app.AppState::new(group),
      screen: @app.Main,
      focus: @app.Editor,
      query_history: ["SELECT 1"],
      sql_input: @widget.TextArea::new().with_value("draft"),
    }
    let previous = handle_key(state, Up)
    assert_eq(previous.sql_input.value(), "SELECT 1")
    let restored = handle_key(previous, Down)
    assert_eq(restored.sql_input.value(), "draft")
  })
}
