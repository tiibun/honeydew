///|
test "is_connection_lost: postgres server closed" {
  assert_true(is_connection_lost("server closed the connection unexpectedly"))
}

///|
test "is_connection_lost: mysql gone away" {
  assert_true(is_connection_lost("MySQL server has gone away"))
}

///|
test "is_connection_lost: mysql lost connection" {
  assert_true(
    is_connection_lost("Lost connection to MySQL server during query"),
  )
}

///|
test "is_connection_lost: broken pipe" {
  assert_true(is_connection_lost("write: broken pipe"))
}

///|
test "is_connection_lost: connection reset" {
  assert_true(is_connection_lost("connection reset by peer"))
}

///|
test "is_connection_lost: no connection to the server" {
  assert_true(is_connection_lost("no connection to the server"))
}

///|
test "is_connection_lost: syntax error is not a lost connection" {
  assert_false(is_connection_lost("syntax error at or near SELECT"))
}

///|
test "is_connection_lost: unknown table is not a lost connection" {
  assert_false(is_connection_lost("Table 'mydb.users' doesn't exist"))
}

///|
test "is_connection_lost: empty string is not a lost connection" {
  assert_false(is_connection_lost(""))
}
