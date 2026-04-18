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

// ── Placeholder history tests ─────────────────────────────────────────────────

///|
test "with_initial_values: pre-fills fields from history" {
  let sql = "SELECT * FROM t WHERE id = :id AND name = :name"
  let form = ParamForm::new(sql, parse_placeholders(sql))
  let history = [(":id", "42"), (":name", "Alice")]
  let filled = form.with_initial_values(history)
  assert_eq(filled.fields[0].value(), "42")
  assert_eq(filled.fields[1].value(), "Alice")
}

///|
test "with_initial_values: leaves fields empty when label not in history" {
  let sql = "SELECT :x, :y"
  let form = ParamForm::new(sql, parse_placeholders(sql))
  let history = [(":x", "10")]
  let filled = form.with_initial_values(history)
  assert_eq(filled.fields[0].value(), "10")
  assert_eq(filled.fields[1].value(), "") // :y not in history
}

///|
test "with_initial_values: empty history leaves all fields empty" {
  let sql = "SELECT :a"
  let form = ParamForm::new(sql, parse_placeholders(sql))
  let filled = form.with_initial_values([])
  assert_eq(filled.fields[0].value(), "")
}

///|
test "save_to_history: adds new entries to empty history" {
  let sql = "SELECT :id, :name"
  let form = ParamForm::new(sql, parse_placeholders(sql))
  let form = {
    ..form,
    fields: [
      @widget.Input::new().with_value("7"),
      @widget.Input::new().with_value("Bob"),
    ],
  }
  let hist = form.save_to_history([])
  assert_eq(hist.length(), 2)
  let (k0, v0) = hist[0]
  assert_eq(k0, ":id")
  assert_eq(v0, "7")
  let (k1, v1) = hist[1]
  assert_eq(k1, ":name")
  assert_eq(v1, "Bob")
}

///|
test "save_to_history: updates existing entries" {
  let sql = "SELECT :x"
  let form = ParamForm::new(sql, parse_placeholders(sql))
  let form = { ..form, fields: [@widget.Input::new().with_value("new")] }
  let old_hist : Array[(String, String)] = [(":x", "old"), (":y", "other")]
  let hist = form.save_to_history(old_hist)
  assert_eq(hist.length(), 2)
  let (k0, v0) = hist[0]
  assert_eq(k0, ":x")
  assert_eq(v0, "new")
  let (k1, v1) = hist[1]
  assert_eq(k1, ":y")
  assert_eq(v1, "other")
}

// ── apply_snapshot tests ──────────────────────────────────────────────────────

///|
test "apply_snapshot: applies matching entries and leaves others unchanged" {
  let sql = "SELECT :id, :name, :limit"
  let form = ParamForm::new(sql, parse_placeholders(sql))
  // Pre-fill :limit so we can verify it stays unchanged
  let form = {
    ..form,
    fields: [
      @widget.Input::new().with_value(""),
      @widget.Input::new().with_value(""),
      @widget.Input::new().with_value("50"),
    ],
  }
  let snap : @config.ParamSnapshot = {
    name: "test",
    entries: [(":id", "99"), (":name", "Eve")],
  }
  let applied = form.apply_snapshot(snap)
  assert_eq(applied.fields[0].value(), "99")
  assert_eq(applied.fields[1].value(), "Eve")
  assert_eq(applied.fields[2].value(), "50") // unchanged
}

///|
test "apply_snapshot: unknown snapshot labels are silently ignored" {
  let sql = "SELECT :x"
  let form = ParamForm::new(sql, parse_placeholders(sql))
  let snap : @config.ParamSnapshot = {
    name: "misc",
    entries: [(":y", "foo"), (":z", "bar")],
  }
  let applied = form.apply_snapshot(snap)
  assert_eq(applied.fields[0].value(), "") // :x not in snapshot → unchanged
}

///|
test "apply_snapshot: overwrites existing field values" {
  let sql = "SELECT :x"
  let form = ParamForm::new(sql, parse_placeholders(sql))
  let form = { ..form, fields: [@widget.Input::new().with_value("old")] }
  let snap : @config.ParamSnapshot = { name: "snap", entries: [(":x", "new")] }
  let applied = form.apply_snapshot(snap)
  assert_eq(applied.fields[0].value(), "new")
}

///|
test "round-trip: save then restore values" {
  let sql = "SELECT * FROM orders WHERE user_id = :user_id AND status = :status"
  let labels = parse_placeholders(sql)
  let form1 = ParamForm::new(sql, labels)
  let form1 = {
    ..form1,
    fields: [
      @widget.Input::new().with_value("123"),
      @widget.Input::new().with_value("active"),
    ],
  }
  let hist = form1.save_to_history([])
  let form2 = ParamForm::new(sql, labels).with_initial_values(hist)
  assert_eq(form2.fields[0].value(), "123")
  assert_eq(form2.fields[1].value(), "active")
}
