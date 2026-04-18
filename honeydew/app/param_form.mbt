///|
priv enum PlaceholderScanMode {
  Normal
  StringLiteral
  DoubleQuoted
  Backtick
  BlockComment
  LineComment
}

///|
/// State for the parameterized-query input form.
/// One Input widget is created for each unique placeholder extracted from the SQL.
pub(all) struct ParamForm {
  /// Original SQL statement with placeholder tokens still present.
  original_sql : String
  /// Optional prefix prepended to the substituted SQL on submit (e.g. "EXPLAIN ").
  sql_prefix : String
  /// Display labels for each unique placeholder: ":name", "$1", "?1", …
  labels : Array[String]
  /// One Input widget per label, in the same order.
  fields : Array[@widget.Input]
  /// Index of the currently focused field.
  focus_idx : Int
}

///|
/// Create a new ParamForm for the given SQL and its placeholder labels.
pub fn ParamForm::new(sql : String, labels : Array[String]) -> ParamForm {
  let fields : Array[@widget.Input] = labels.map(fn(label) {
    @widget.Input::new().with_placeholder(label)
  })
  { original_sql: sql, sql_prefix: "", labels, fields, focus_idx: 0 }
}

///|
/// Return a copy of this form with `prefix` prepended to the substituted SQL on submit.
/// Used by EXPLAIN to wrap the substituted statement.
pub fn ParamForm::with_sql_prefix(self : ParamForm, prefix : String) -> ParamForm {
  { ..self, sql_prefix: prefix }
}

///|
/// Handle a key event, routing character/edit keys to the focused field and
/// Tab/ShiftTab to advance or retreat focus.
pub fn ParamForm::handle_key(
  self : ParamForm,
  key : @terminal.Key,
) -> ParamForm {
  let n = self.fields.length()
  if n == 0 {
    return self
  }
  match key {
    Tab => { ..self, focus_idx: (self.focus_idx + 1) % n }
    ShiftTab => { ..self, focus_idx: (self.focus_idx + n - 1) % n }
    _ => {
      let fi = self.focus_idx
      let new_fields = self.fields.copy()
      new_fields[fi] = self.fields[fi].handle_key(key).focused(true)
      { ..self, fields: new_fields }
    }
  }
}

///|
/// Build the substituted SQL (with optional prefix) by replacing each
/// placeholder token with the value typed in the corresponding field.
pub fn ParamForm::substituted_sql(self : ParamForm) -> String {
  let values : Array[String] = self.fields.map(fn(f) { f.value() })
  self.sql_prefix + substitute_params(self.original_sql, self.labels, values)
}

// ── Shared SQL scanner ────────────────────────────────────────────────────────

///|
/// Scan `sql` for placeholder tokens, skipping tokens inside string literals
/// and comments.  Calls one of three callbacks for each region:
///
/// - `on_verbatim(start, end)` — verbatim text span [start, end)
/// - `on_named(label, start, end)` — named token `:name`, `$N`, or `{x}` at [start, end)
/// - `on_question(occurrence, start, end)` — `?` token (1-based) at [start, end)
///
/// `parse_placeholders` and `substitute_params` are both built on this scanner.
fn scan_sql_tokens(
  sql : String,
  on_verbatim : (Int, Int) -> Unit,
  on_named : (String, Int, Int) -> Unit,
  on_question : (Int, Int, Int) -> Unit,
) -> Unit {
  let len = sql.length()
  let mut i = 0
  let mut mode = PlaceholderScanMode::Normal
  let mut question_count = 0
  // Start of the current verbatim run; placeholders break the run.
  // Text in non-Normal modes (string literals, comments) stays verbatim.
  let mut run_start = 0
  while i < len {
    match mode {
      Normal => {
        let c = sql[i]
        if c == '\'' {
          mode = StringLiteral
          i = i + 1
        } else if c == '"' {
          mode = DoubleQuoted
          i = i + 1
        } else if c == '`' {
          mode = Backtick
          i = i + 1
        } else if c == '-' && i + 1 < len && sql[i + 1] == '-' {
          mode = LineComment
          i = i + 2
        } else if c == '/' && i + 1 < len && sql[i + 1] == '*' {
          mode = BlockComment
          i = i + 2
        } else if c == ':' &&
          i + 1 < len &&
          ph_is_ident_start(sql[i + 1]) &&
          !(i > 0 && sql[i - 1] == ':') {
          // :name placeholder — but not the second ':' of a '::' cast operator
          let token_start = i
          let name_start = i + 1
          let mut j = name_start
          while j < len && ph_is_ident_char(sql[j]) {
            j = j + 1
          }
          let label = ":" + sql[name_start:j].to_string()
          on_verbatim(run_start, token_start)
          on_named(label, token_start, j)
          run_start = j
          i = j
        } else if c == '$' && i + 1 < len && ph_is_digit(sql[i + 1]) {
          // $N placeholder (PostgreSQL style)
          let token_start = i
          let num_start = i + 1
          let mut j = num_start
          while j < len && ph_is_digit(sql[j]) {
            j = j + 1
          }
          let label = "$" + sql[num_start:j].to_string()
          on_verbatim(run_start, token_start)
          on_named(label, token_start, j)
          run_start = j
          i = j
        } else if c == '?' {
          // ? positional placeholder (JDBC / SQLite / MySQL style)
          let token_start = i
          question_count = question_count + 1
          on_verbatim(run_start, token_start)
          on_question(question_count, token_start, token_start + 1)
          run_start = token_start + 1
          i = i + 1
        } else if c == '{' && i + 1 < len && ph_is_ident_start(sql[i + 1]) {
          // {name} placeholder (EF Core FromSqlInterpolated style)
          let token_start = i
          let name_start = i + 1
          let mut j = name_start
          while j < len && ph_is_ident_char(sql[j]) {
            j = j + 1
          }
          if j < len && sql[j] == '}' {
            let label = "{" + sql[name_start:j].to_string() + "}"
            on_verbatim(run_start, token_start)
            on_named(label, token_start, j + 1)
            run_start = j + 1
            i = j + 1
          } else {
            i = i + 1
          }
        } else {
          i = i + 1
        }
      }
      StringLiteral =>
        if sql[i] == '\'' {
          if i + 1 < len && sql[i + 1] == '\'' {
            i = i + 2
          } else {
            mode = Normal
            i = i + 1
          }
        } else {
          i = i + 1
        }
      DoubleQuoted =>
        if sql[i] == '"' {
          if i + 1 < len && sql[i + 1] == '"' {
            i = i + 2
          } else {
            mode = Normal
            i = i + 1
          }
        } else {
          i = i + 1
        }
      Backtick =>
        if sql[i] == '`' {
          if i + 1 < len && sql[i + 1] == '`' {
            i = i + 2
          } else {
            mode = Normal
            i = i + 1
          }
        } else {
          i = i + 1
        }
      BlockComment =>
        if sql[i] == '*' && i + 1 < len && sql[i + 1] == '/' {
          mode = Normal
          i = i + 2
        } else {
          i = i + 1
        }
      LineComment => {
        if sql[i] == '\n' {
          mode = Normal
        }
        i = i + 1
      }
    }
  }
  on_verbatim(run_start, len)
}

// ── Placeholder parsing ───────────────────────────────────────────────────────

///|
/// Extract placeholder labels from a SQL statement, skipping tokens inside
/// string literals and comments.  Returns a list of labels in first-occurrence
/// order with named/positional tokens deduplicated:
///
/// - `:name`   → label ":name"   (one entry per unique name)
/// - `$N`      → label "$N"      (one entry per unique N)
/// - `?`       → labels "?1", "?2", … (one entry per occurrence, not deduplicated)
/// - `{name}`  → label "{name}"  (one entry per unique name)
pub fn parse_placeholders(sql : String) -> Array[String] {
  let labels : Array[String] = []
  scan_sql_tokens(
    sql,
    fn(_start, _end) { () },
    fn(label, _start, _end) {
      if !ph_labels_contain(labels, label) {
        labels.push(label)
      }
    },
    fn(occurrence, _start, _end) { labels.push("?\{occurrence}") },
  )
  labels
}

// ── Substitution ──────────────────────────────────────────────────────────────

///|
/// Replace each placeholder token in `sql` with the corresponding entry from
/// `values` (indexed by position in `labels`).  Tokens inside string literals
/// and comments are left untouched.  Verbatim text is written as runs rather
/// than character-by-character for efficiency.
fn substitute_params(
  sql : String,
  labels : Array[String],
  values : Array[String],
) -> String {
  let result = StringBuilder::new()
  scan_sql_tokens(
    sql,
    fn(start, end) { result.write_string(sql[start:end].to_string()) },
    fn(label, _start, _end) {
      result.write_string(ph_find_value(labels, values, label, label))
    },
    fn(occurrence, _start, _end) {
      let q_label = "?\{occurrence}"
      result.write_string(ph_find_value(labels, values, q_label, "?"))
    },
  )
  result.to_string()
}

// ── Internal helpers ──────────────────────────────────────────────────────────

///|
// String[i] returns UInt16 in MoonBit. These helpers accept UInt16 so the
// caller can pass s[i] directly without an explicit conversion.
fn ph_is_ident_start(c : UInt16) -> Bool {
  (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_'
}

///|
fn ph_is_ident_char(c : UInt16) -> Bool {
  ph_is_ident_start(c) || (c >= '0' && c <= '9')
}

///|
fn ph_is_digit(c : UInt16) -> Bool {
  c >= '0' && c <= '9'
}

///|
fn ph_labels_contain(labels : Array[String], target : String) -> Bool {
  for label in labels {
    if label == target {
      return true
    }
  }
  false
}

///|
fn ph_find_value(
  labels : Array[String],
  values : Array[String],
  target : String,
  fallback : String,
) -> String {
  for i = 0; i < labels.length(); i = i + 1 {
    if labels[i] == target {
      return values[i]
    }
  }
  fallback
}
