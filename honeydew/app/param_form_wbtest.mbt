///|
// ── parse_placeholders tests ──────────────────────────────────────────────────

///|
test "parse_placeholders: named :name params" {
  let labels = parse_placeholders(
    "SELECT * FROM t WHERE id = :id AND name = :name",
  )
  assert_eq(labels, [":id", ":name"])
}

///|
test "parse_placeholders: duplicate named params are deduplicated" {
  let labels = parse_placeholders("SELECT :x + :x, :y FROM t WHERE a = :x")
  assert_eq(labels, [":x", ":y"])
}

///|
test "parse_placeholders: $N positional params (PostgreSQL)" {
  let labels = parse_placeholders("SELECT $1, $2 FROM t WHERE id = $1")
  assert_eq(labels, ["$1", "$2"])
}

///|
test "parse_placeholders: ? positional params are not deduplicated" {
  let labels = parse_placeholders(
    "SELECT * FROM t WHERE a = ? AND b = ? AND c = ?",
  )
  assert_eq(labels, ["?1", "?2", "?3"])
}

///|
test "parse_placeholders: empty SQL returns empty list" {
  assert_eq(parse_placeholders(""), [])
}

///|
test "parse_placeholders: SQL without placeholders returns empty list" {
  assert_eq(parse_placeholders("SELECT 1"), [])
}

///|
test "parse_placeholders: skip placeholders inside string literals" {
  let labels = parse_placeholders("SELECT ':not_a_param' AS s, :real FROM t")
  assert_eq(labels, [":real"])
}

///|
test "parse_placeholders: skip placeholders inside double-quoted identifiers" {
  let labels = parse_placeholders("SELECT \":not\" AS x, :real FROM t")
  assert_eq(labels, [":real"])
}

///|
test "parse_placeholders: skip placeholders inside line comments" {
  let labels = parse_placeholders("SELECT :keep -- ignore :ignored\nFROM t")
  assert_eq(labels, [":keep"])
}

///|
test "parse_placeholders: skip placeholders inside block comments" {
  let labels = parse_placeholders("SELECT :keep /* :ignored */ FROM t")
  assert_eq(labels, [":keep"])
}

///|
test "parse_placeholders: :: cast operator is not a named param" {
  let labels = parse_placeholders("SELECT $1::INTEGER, :id FROM t")
  assert_eq(labels, ["$1", ":id"])
}

///|
test "parse_placeholders: {name} EF Core style params" {
  let labels = parse_placeholders(
    "SELECT * FROM t WHERE id = {id} AND name = {name}",
  )
  assert_eq(labels, ["{id}", "{name}"])
}

///|
test "parse_placeholders: {name} duplicate is deduplicated" {
  let labels = parse_placeholders("SELECT {x}, {x} + 1")
  assert_eq(labels, ["{x}"])
}

///|
test "parse_placeholders: incomplete braces are not matched" {
  // {abc without closing brace should not be a placeholder
  let labels = parse_placeholders("SELECT {abc, :real FROM t")
  assert_eq(labels, [":real"])
}

///|
test "substituted_sql: {name} params are replaced" {
  let sql = "SELECT * FROM books WHERE id = {id}"
  let form = ParamForm::new(sql, parse_placeholders(sql))
  let filled = { ..form, fields: [@widget.Input::new().with_value("42")] }
  assert_eq(filled.substituted_sql(), "SELECT * FROM books WHERE id = 42")
}

// ── substituted_sql tests ─────────────────────────────────────────────────────

///|
test "substituted_sql: named params are replaced" {
  let sql = "SELECT * FROM t WHERE id = :id AND name = :name"
  let form = ParamForm::new(sql, parse_placeholders(sql))
  let filled = {
    ..form,
    fields: [
      @widget.Input::new().with_value("42"),
      @widget.Input::new().with_value("Alice"),
    ],
  }
  assert_eq(
    filled.substituted_sql(),
    "SELECT * FROM t WHERE id = 42 AND name = Alice",
  )
}

///|
test "substituted_sql: duplicate :name tokens all replaced" {
  let sql = "SELECT :x, :x + 1"
  let form = ParamForm::new(sql, parse_placeholders(sql))
  let filled = { ..form, fields: [@widget.Input::new().with_value("99")] }
  assert_eq(filled.substituted_sql(), "SELECT 99, 99 + 1")
}

///|
test "substituted_sql: ? params replaced in order" {
  let sql = "INSERT INTO t (a, b) VALUES (?, ?)"
  let form = ParamForm::new(sql, parse_placeholders(sql))
  let filled = {
    ..form,
    fields: [
      @widget.Input::new().with_value("1"),
      @widget.Input::new().with_value("hello"),
    ],
  }
  assert_eq(filled.substituted_sql(), "INSERT INTO t (a, b) VALUES (1, hello)")
}

///|
test "substituted_sql: literal inside string is not substituted" {
  let sql = "SELECT ':not_replaced', :real"
  let form = ParamForm::new(sql, parse_placeholders(sql))
  let filled = { ..form, fields: [@widget.Input::new().with_value("42")] }
  assert_eq(filled.substituted_sql(), "SELECT ':not_replaced', 42")
}

///|
test "substituted_sql: empty value replaces placeholder with empty string" {
  let sql = "SELECT :x"
  let form = ParamForm::new(sql, parse_placeholders(sql))
  // Default field value is empty string
  assert_eq(form.substituted_sql(), "SELECT ")
}

// ── ParamForm::handle_key tests ───────────────────────────────────────────────

///|
test "ParamForm handle_key: Tab advances focus" {
  let sql = "SELECT :a, :b, :c"
  let form = ParamForm::new(sql, parse_placeholders(sql))
  assert_eq(form.focus_idx, 0)
  let f1 = form.handle_key(Tab)
  assert_eq(f1.focus_idx, 1)
  let f2 = f1.handle_key(Tab)
  assert_eq(f2.focus_idx, 2)
  let f3 = f2.handle_key(Tab) // wraps around
  assert_eq(f3.focus_idx, 0)
}

///|
test "ParamForm handle_key: ShiftTab retreats focus" {
  let sql = "SELECT :a, :b"
  let form = ParamForm::new(sql, parse_placeholders(sql))
  let f = form.handle_key(ShiftTab) // wrap back from 0 → 1
  assert_eq(f.focus_idx, 1)
}
