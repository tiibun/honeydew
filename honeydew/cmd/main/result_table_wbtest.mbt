///|
test "result_cell_styles marks SQL NULL sentinel distinctly" {
  let styles = result_cell_styles([[@db.null_value, "NULL"]])
  assert_true(styles[0][0] is Some(_))
  assert_eq(styles[0][1], None)
}
