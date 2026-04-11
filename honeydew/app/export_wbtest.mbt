///|
async test "AppState::export_results_csv reports empty results" {
  @async.with_task_group(group => {
    let state = AppState::new(group)
    let next = state.export_results_csv()
    assert_eq(next.status, "No results to export")
  })
}
