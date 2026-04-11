///|
async test "AppState::new has in_transaction false by default" {
  @async.with_task_group(group => {
    let state = AppState::new(group)
    assert_eq(state.in_transaction, false)
  })
}

///|
async test "AppState::begin_transaction when not connected" {
  @async.with_task_group(group => {
    let state = AppState::new(group)
    let s = state.begin_transaction()
    assert_eq(s.in_transaction, false)
    assert_true(s.status.contains("Error"))
  })
}

///|
async test "AppState::commit_transaction when not connected" {
  @async.with_task_group(group => {
    let state = AppState::new(group)
    let s = state.commit_transaction()
    assert_eq(s.in_transaction, false)
    assert_true(s.status.contains("Error"))
  })
}

///|
async test "AppState::rollback_transaction when not connected" {
  @async.with_task_group(group => {
    let state = AppState::new(group)
    let s = state.rollback_transaction()
    assert_eq(s.in_transaction, false)
    assert_true(s.status.contains("Error"))
  })
}
