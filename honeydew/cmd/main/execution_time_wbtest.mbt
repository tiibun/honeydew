///|
test "with_execution_time appends milliseconds" {
  assert_eq(
    with_execution_time("3 rows affected", 42000.0),
    "3 rows affected (42 ms)",
  )
}
