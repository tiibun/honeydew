///|
async test "AppState::record_query_history skips empty and duplicate entries" {
  @async.with_task_group(group => {
    let state = AppState::new(group)
      .record_query_history("")
      .record_query_history("SELECT 1")
      .record_query_history("SELECT 1")
      .record_query_history("SELECT 2")
    assert_eq(state.query_history, ["SELECT 1", "SELECT 2"])
  })
}
