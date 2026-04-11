///|
test "query_result_status prefers affected rows for write statements" {
  let result : @db.QueryResult = {
    columns: [],
    rows: [],
    affected_rows: Some(3),
  }
  assert_eq(query_result_status(result), "3 rows affected")
}
